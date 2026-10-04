"""``POST /sessions/{id}/answers`` (API §6.5, backend §6.3): replay first, then validate, grade and apply.

Processing order (normative):
  1. authenticate (route dependency);
  2. load the session; another learner's or a missing session is ``404``;
  3. read only ``exercise_id`` and ``is_retry``; a recorded identity replays the stored, mode-permitted response
     and changes nothing, whatever the rest of the body says (also after finish or abandon);
  4. otherwise lock the session row and look again (a concurrent duplicate that lost the race replays the
     winner); a finished session is ``409 session_finished``, an abandoned one ``409 session_not_active``;
  5. the exercise must have been served; a retry must be eligible (``409 retry_not_allowed``) and a first
     attempt must follow authored order (``409 out_of_order``);
  6. validate the full body against the served exercise (``400 validation_error``);
  7. grade against the pinned exercise version, apply mastery/misconception/recitation-XP effects, store the
     issued evaluation and the attempt - one transaction.

Feedback modes: ``immediate`` returns the full evaluation; ``none``/``end`` return only
``{exercise_id, recorded: true}``. The full evaluation is always stored, and grading and adaptation always use
the private result.
"""

from __future__ import annotations

import hashlib
import logging
from decimal import Decimal
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.contract import contextual
from app.errors import ApiError, ErrorCode
from app.models import (
    Concept,
    ExerciseVersion,
    LearningSession,
    LessonVersion,
    Misconception,
    RecitationCheckRecord,
    SessionAnswer,
    User,
)
from app.services.learning import adaptation, grading, progress, xp
from app.services.learning.grading import Identity
from app.services.learning.locking import learner_lock
from app.services.platform.auth_sessions import utcnow

log = logging.getLogger("qabas.answers")

RECITATION_XP = xp.AMOUNTS["recitation_passed"]


class AnswerIntegrityError(RuntimeError):
    """Served or pinned data that can't be graded (a publication or session invariant was broken)."""


async def submit(db: AsyncSession, user: User, session_id: str, body: Any) -> dict[str, Any]:
    async with db.begin():
        session = await db.get(LearningSession, session_id)
        if session is None or session.user_id != user.id:
            raise ApiError(ErrorCode.not_found, "Session was not found.")
        identity = grading.parse_identity(body)
        stored = await _recorded(db, session.id, identity)
        if stored is not None:
            return _replay(session, stored, body)

        session = (await db.execute(select(LearningSession).where(LearningSession.id == session_id)
                                    .with_for_update().execution_options(populate_existing=True))).scalar_one()
        stored = await _recorded(db, session.id, identity)
        if stored is not None:
            return _replay(session, stored, body)
        if session.status == "finished":
            raise ApiError(ErrorCode.session_finished, "This session is already finished.")
        if session.status != "active":
            raise ApiError(ErrorCode.session_not_active, "This session is no longer active.")
        await learner_lock(db, user.id)

        exercises = [b["exercise"] for b in session.items_snapshot["items"] if b["type"] == "exercise"]
        served = {e["exercise_id"]: e for e in exercises}
        exercise = served.get(identity.exercise_id)
        if exercise is None:
            raise grading.invalid("This exercise was not served in this session.", field="exercise_id")
        firsts = {r.exercise_id: r for r in (await db.execute(select(SessionAnswer).where(
            SessionAnswer.session_id == session.id, SessionAnswer.is_retry.is_(False)))).scalars()}
        if identity.is_retry:
            _check_retry(session, exercise, firsts.get(identity.exercise_id))
        else:
            missing = [e["exercise_id"] for e in exercises[:list(served).index(identity.exercise_id)]
                       if e["exercise_id"] not in firsts]
            if missing:
                raise ApiError(ErrorCode.out_of_order, "Answer the earlier exercises first.",
                               {"exercise_id": missing[0]})

        submitted = grading.validate_submission(exercise, body, session.kind)
        return await _grade_and_record(db, user, session, exercise, submitted)


async def _recorded(db: AsyncSession, session_id: str, identity: Identity) -> SessionAnswer | None:
    return (await db.execute(select(SessionAnswer).where(
        SessionAnswer.session_id == session_id, SessionAnswer.exercise_id == identity.exercise_id,
        SessionAnswer.is_retry.is_(identity.is_retry)))).scalar_one_or_none()


def _replay(session: LearningSession, stored: SessionAnswer, body: dict[str, Any]) -> dict[str, Any]:
    """The stored response the feedback mode allows; the request body is never re-graded (API §6.5)."""
    if body.get("answer", stored.answer) != stored.answer:
        log.info("answer replay with a different body", extra={"session_id": session.id,
                                                               "exercise_id": stored.exercise_id,
                                                               "is_retry": stored.is_retry})
    return response(session, stored.evaluation)


def response(session: LearningSession, evaluation: dict[str, Any]) -> dict[str, Any]:
    if session.feedback_mode == "immediate":
        return evaluation
    return grading.recorded_only(evaluation["exercise_id"])


def _check_retry(session: LearningSession, exercise: dict[str, Any], first: SessionAnswer | None) -> None:
    """A retry identity not yet recorded is allowed only for an incorrect first attempt of a retryable type in
    a lesson session (correct, neutral and hidden-mode outcomes are not retried)."""
    if (session.kind != "lesson" or exercise["type"] in grading.NOT_RETRYABLE or first is None
            or first.correct is not False):
        raise ApiError(ErrorCode.retry_not_allowed, "This exercise can't be retried.")


async def _grade_and_record(db: AsyncSession, user: User, session: LearningSession, exercise: dict[str, Any],
                            submitted: dict[str, Any]) -> dict[str, Any]:
    now = utcnow()
    exercise_id, is_retry, answer = exercise["exercise_id"], submitted["is_retry"], submitted["answer"]
    version_no = next((e["version"] for e in session.served_exercises if e["exercise_id"] == exercise_id), None)
    version = await db.get(ExerciseVersion, (exercise_id, version_no)) if version_no is not None else None
    if version is None or version.published_at is None:
        raise AnswerIntegrityError(f"{session.id}: no pinned published version for {exercise_id}")
    stored = version.content["languages"][session.language]
    feedback = stored["feedback"]
    key = version.answer_key or None

    passed = None
    if exercise["type"] == "recite_verse" and isinstance(answer, dict) and "check_id" in answer:
        passed = await _bound_check(db, user, exercise, answer["check_id"])
    graded = grading.grade(exercise, answer, key, feedback, recitation_passed=passed)

    # Mastery: concepts ascending (lock order: session -> concepts -> misconceptions).
    rule = grading.mastery_rule(exercise, submitted, session.kind, graded.correct)
    changes: list[dict[str, Any]] = []
    before_values: dict[str, Decimal] = {}
    if rule not in ("none", "retry_incorrect"):
        rows = await adaptation.lock_concepts(db, user.id, exercise["concept_ids"])
        titles = await _concept_titles(db, exercise["concept_ids"], session.language)
        for concept_id in exercise["concept_ids"]:
            row = rows[concept_id]
            before = Decimal(row.mastery)
            after = grading.mastery_after(before, rule)
            before_values[concept_id] = before
            row.mastery = after
            changes.append({"concept_id": concept_id, "title": titles[concept_id],
                            "before": grading.report(before), "after": grading.report(after)})

    plan = adaptation.plan_misconceptions(answer, graded.correct, is_retry, dict(version.option_misconceptions),
                                          version.targets_misconception_id)
    shown = None
    transitions: dict[str, Any] = {"activated": [], "resolved": [], "titles": {}}
    if plan.related and not is_retry and graded.correct is not None:
        rows_m = await adaptation.lock_misconceptions(db, user.id, sorted(plan.related), set(plan.evidence))
        states = {m: r.status for m, r in rows_m.items()}
        shown = adaptation.apply_misconceptions(plan, rows_m, graded.correct, now)
        for m, row_m in rows_m.items():
            if row_m.status != states[m] and row_m.status in ("active", "resolved"):
                transitions["activated" if row_m.status == "active" else "resolved"].append(m)
                card = await _misconception_card(db, version, m, session.language)
                transitions["titles"][m] = card["title"]

    xp_awarded = 0
    if exercise["type"] == "recite_verse" and graded.correct is True and not is_retry:
        granted = await xp.grant(db, user, "recitation_passed", RECITATION_XP, "session_exercise",
                                 f"{session.id}:{exercise_id}", now, reward_key=f"exercise:{exercise_id}")
        xp_awarded = RECITATION_XP if granted else 0
        if granted:
            day = xp.local_date(now, user.timezone)
            quests = await progress.quests(db, user, day)
            for quest in quests:
                if quest.kind == "recite_verse" and quest.completed_at is None:
                    quest.progress += 1
            daily = await progress.day_row(db, user, day)
            await progress.refresh_xp(db, user, day, daily)

    evaluation = grading.evaluation(
        exercise, graded, feedback, list(version.source_ids),
        misconception=await _misconception_card(db, version, shown, session.language) if shown else None,
        mastery_changes=changes, xp_awarded=xp_awarded)
    _self_check(exercise, submitted, session.kind, evaluation, before_values, key, passed)
    db.add(SessionAnswer(session_id=session.id, exercise_id=exercise_id, exercise_version=version.version,
                         answer=answer, correct=graded.correct, elapsed_ms=submitted["elapsed_ms"],
                         is_retry=is_retry, misconception_id=shown, evaluation=evaluation,
                         misconception_changes=transitions, recorded_at=now))
    await db.flush()
    return response(session, evaluation)


def _self_check(exercise: dict[str, Any], submitted: dict[str, Any], kind: str, evaluation: dict[str, Any],
                before: dict[str, Decimal], key: dict[str, Any] | None, passed: bool | None) -> None:
    """Re-verify the issued evaluation with the contract's own checker before it is stored."""
    try:
        contextual.validate_evaluation(exercise, submitted, kind, evaluation, before, private_key=key,
                                       recitation_passed=passed)
    except ValueError as exc:
        raise AnswerIntegrityError(f"{exercise['exercise_id']}: issued evaluation failed its check: {exc}") from exc


async def _bound_check(db: AsyncSession, user: User, exercise: dict[str, Any], check_id: str) -> bool:
    """The referenced recitation check must be the caller's and cover exactly the served range and text
    (API §6.6, backend §8 step 10); otherwise ``409 recitation_check_mismatch``."""
    payload = exercise["payload"]
    check = await db.get(RecitationCheckRecord, check_id)
    digest = hashlib.sha256(payload["text_uthmani"].encode()).hexdigest()
    if (check is None or check.user_id != user.id
            or (check.surah, check.ayah, check.word_start, check.word_end)
            != (payload["surah"], payload["ayah"], payload["word_start"], payload["word_end"])
            or check.checked_text_sha256 != digest):
        raise ApiError(ErrorCode.recitation_check_mismatch,
                       "This recitation check doesn't match the verse of this exercise.")
    return bool(check.passed)


async def _concept_titles(db: AsyncSession, concept_ids: list[str], lang: str) -> dict[str, str]:
    rows = await db.execute(select(Concept.id, Concept.title).where(Concept.id.in_(concept_ids)))
    titles = {concept_id: title[lang] for concept_id, title in rows}
    missing = [c for c in concept_ids if c not in titles]
    if missing:
        raise AnswerIntegrityError(f"concepts without a curriculum record: {missing}")
    return titles


async def _misconception_card(db: AsyncSession, version: ExerciseVersion, misconception_id: str,
                              lang: str) -> dict[str, Any]:
    """The remediation card as published with the exercise's lesson version (pinned, decision D-55); the
    registry record only when that version did not define it."""
    record = None
    if version.lesson_version_id is not None:
        lesson_version = await db.get(LessonVersion, version.lesson_version_id)
        if lesson_version is not None:
            record = next((m for m in lesson_version.content.get("misconceptions", [])
                           if m["misconception_id"] == misconception_id), None)
    if record is None:
        row = await db.get(Misconception, misconception_id)
        if row is None:
            raise AnswerIntegrityError(f"misconception {misconception_id} has no card")
        record = {"title": row.title, "card": row.card, "source_ids": list(row.source_ids)}
    return {"misconception_id": misconception_id, "title": record["title"][lang], "card": record["card"][lang],
            "source_ids": list(record["source_ids"])}
