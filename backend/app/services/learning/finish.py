"""Session finish: session-first locking, atomic reported effects, immutable result replay."""

from datetime import datetime
from decimal import ROUND_HALF_UP, Decimal
from typing import Any

from pydantic import ValidationError
from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.content import catalog
from app.contract import models as C
from app.errors import ApiError, ErrorCode
from app.models import (
    Concept,
    LearnerConcept,
    LearnerLesson,
    LearnerTerm,
    LearnerUnit,
    LearningSession,
    Misconception,
    SessionAnswer,
    Term,
    Unit,
    User,
)
from app.services.adaptive import planner
from app.services.learning import adaptation, finish_events, grading, progress, spaced, xp
from app.services.learning.journey import load_view
from app.services.learning.locking import learner_lock
from app.services.learning.sessions import SessionIntegrityError
from app.services.platform.auth_sessions import utcnow
from app.services.platform.outbox import enqueue


def score(rows: list[SessionAnswer]) -> dict[str, int]:
    total = len(rows)
    correct = sum(r.correct is True for r in rows)
    percent = int((Decimal(correct * 100) / total).quantize(Decimal(1), rounding=ROUND_HALF_UP)) if total else 0
    return {"correct": correct, "total": total, "percent": percent}


async def finish(db: AsyncSession, user: User, session_id: str, body: Any) -> dict[str, Any]:
    async with db.begin():
        session = (await db.execute(select(LearningSession).where(LearningSession.id == session_id)
                                    .with_for_update().execution_options(populate_existing=True))).scalar_one_or_none()
        if session is None or session.user_id != user.id:
            raise ApiError(ErrorCode.not_found, "Session was not found.")
        if session.status == "finished":
            assert session.result_snapshot is not None
            return session.result_snapshot
        if session.status != "active":
            raise ApiError(ErrorCode.session_not_active, "This session is no longer active.")
        rows = list((await db.execute(select(SessionAnswer).where(SessionAnswer.session_id == session.id)
                                     .order_by(SessionAnswer.id))).scalars())
        exercises = {b["exercise"]["exercise_id"]: b["exercise"] for b in session.items_snapshot["items"]
                     if b["type"] == "exercise"}
        firsts = {r.exercise_id: r for r in rows if not r.is_retry}
        missing = [eid for eid in exercises if eid not in firsts]
        if missing:
            raise ApiError(ErrorCode.out_of_order, "Answer every exercise before finishing.",
                           {"missing_exercise_ids": missing})
        try:
            requested = C.FinishReq.model_validate(body).duration_ms
        except ValidationError:
            raise ApiError(ErrorCode.validation_error, "A duration_ms integer is required.",
                           {"field": "duration_ms"}) from None
        if session.learning_snapshot is None:
            raise SessionIntegrityError("legacy active session lacks an authoritative learning-start snapshot")
        await learner_lock(db, user.id)
        now = utcnow()
        duration = max(0, min(requested, max(0, int((now - session.started_at).total_seconds() * 1000))))
        concept_ids = sorted({c for e in exercises.values() for c in e["concept_ids"]})
        # Term-linked concepts are locked too, before any term row.
        term_ids = list(session.items_snapshot["terms"])
        term_records = list((await db.execute(select(Term).where(Term.id.in_(term_ids)))).scalars())
        if {t.id for t in term_records} != set(term_ids):
            raise SessionIntegrityError("session contains a term without a canonical registry record")
        term_concepts = session.learning_snapshot.get("term_concepts", {})
        if set(term_concepts) != set(term_ids):
            raise SessionIntegrityError("session term concept bindings are incomplete")
        concept_ids = sorted(set(concept_ids) | {c for c in term_concepts.values() if c})
        concepts = await adaptation.lock_concepts(db, user.id, concept_ids)
        changes: dict[str, set[str]] = {"activated": set(), "resolved": set()}
        misconception_titles = {}
        for row in rows:
            for kind in changes:
                changes[kind].update((row.misconception_changes or {}).get(kind, []))
            misconception_titles.update((row.misconception_changes or {}).get("titles", {}))
        await adaptation.lock_misconceptions(db, user.id, sorted(changes["activated"] | changes["resolved"]), set())
        before_view = await load_view(db, user)
        locked_before = {lsn.lesson_id for lessons in before_view.lessons.values() for lsn in lessons
                         if before_view.unmet_introducers(lsn)}
        units_locked = {u.id for u in before_view.units if not u.coming_soon and before_view.unit_state(u) == "locked"}
        graded = [r for r in firsts.values() if r.correct is not None
                  and exercises[r.exercise_id]["scoring"]["accuracy"]]
        result_score = score(graded)
        perfect = bool(graded) and all(r.correct is True for r in graded)
        layers: dict[str, Any] = {"understanding": None, "applying": None, "remembering": None}
        for source, target in (("understand", "understanding"), ("apply", "applying")):
            layer_rows = [r for r in graded if exercises[r.exercise_id]["scoring"]["layer"] == source]
            if layer_rows:
                layers[target] = score(layer_rows)
        summary = await mastery_summary(db, session, rows, concepts)
        grants, events, passed = await completion(db, user, session, result_score["percent"], perfect, now)
        # A due opportunity is consumed once even when cards and quick sessions overlap.
        review_due = False
        if session.kind != "pretest":
            for cid, rating in spaced.ratings(exercises, rows).items():
                concept_row = concepts[cid]
                due = (session.learning_snapshot or {}).get("due", {}).get(cid)
                if (due is not None and datetime.fromisoformat(due.replace("Z", "+00:00")) <= session.started_at
                        and concept_row.due_at is not None and concept_row.due_at <= session.started_at
                        and (concept_row.last_reviewed_at is None
                             or concept_row.last_reviewed_at <= session.started_at)):
                    review_due = True
                spaced.update(concept_row, rating, now)
        if session.kind == "review" and review_due:
            key = f"review:{xp.local_date(now, user.timezone)}"
            if await xp.grant(db, user, "review_complete", xp.AMOUNTS["review_complete"], "session", session.id,
                              now, reward_key=key):
                grants.append({"reason": "review_complete", "xp": xp.AMOUNTS["review_complete"]})
                events["complete_review"] = 1
        recitation_xp = sum(r.evaluation["xp_awarded"] for r in rows)
        if recitation_xp:
            grants.append({"reason": "recitation_passed", "xp": recitation_xp})
        mastered = await promote_terms(db, user, concepts, term_records, term_concepts,
                                        session.items_snapshot["terms"], session.language)
        day = xp.local_date(now, user.timezone)
        daily = await progress.day_row(db, user, day)
        extended = not daily.qualifying
        daily.qualifying = True
        daily.duration_ms += min(duration, 20 * 60_000)
        daily.minutes = daily.duration_ms // 60_000
        met = daily.minutes >= user.daily_goal_minutes
        if met and await xp.grant(db, user, "daily_goal_met", xp.AMOUNTS["daily_goal_met"], "local_date",
                                  day.isoformat(), now):
            grants.append({"reason": "daily_goal_met", "xp": xp.AMOUNTS["daily_goal_met"]})
        grants += await progress.advance_quests(db, user, now, events)
        await progress.refresh_xp(db, user, day, daily)
        # Flush learning facts while the session is still active. Set all terminal fields together at the end.
        await db.flush()
        streak = await progress.streak(db, user, day)
        after_view = await load_view(db, user)
        unlocked = [{"type": "lesson", "id": lsn.lesson_id, "title": after_view.title(lsn, session.language)}
                    for lessons in after_view.lessons.values() for lsn in lessons
                    if lsn.lesson_id in locked_before and not after_view.unmet_introducers(lsn)]
        unlocked += [{"type": "unit", "id": u.id, "title": u.title[session.language][after_view.track]}
                     for u in after_view.units if u.id in units_locked and after_view.unit_state(u) != "locked"]
        step = await planner.next_step(db, user, lang=session.language)
        review_items = [{"exercise_id": eid, **{k: firsts[eid].evaluation[k]
                         for k in ("correct", "correct_answer", "explanation", "source_ids")}} for eid in exercises]
        titles = {m.id: m.title[session.language] for m in (await db.execute(select(Misconception).where(
            Misconception.id.in_(changes["activated"] | changes["resolved"])))).scalars()}
        titles.update(misconception_titles)
        result = C.SessionResult.model_validate({
            "session_id": session.id, "kind": session.kind, "score": result_score, "passed": passed,
            "xp": {"total": sum(g["xp"] for g in grants), "breakdown": grants}, "duration_ms": duration,
            "layers": layers, "streak": {"current": streak.current, "extended_today": extended},
            "daily_goal": {"minutes": user.daily_goal_minutes, "minutes_today": daily.minutes, "met": met},
            "mastery_summary": summary, "terms_mastered": mastered,
            "misconceptions": {k: [{"misconception_id": m, "title": titles[m]} for m in sorted(ids)]
                               for k, ids in changes.items()}, "unlocked": unlocked,
            "review_items": review_items if session.kind == "unit_test" else None,
            "next_step": step.model_dump(mode="json")}).model_dump(mode="json")
        session.status, session.finished_at = "finished", now
        session.duration_ms, session.result_snapshot = duration, result
        await enqueue(db, event_key=f"session:{session.id}:finished", kind=finish_events.KIND,
                      payload={"session_id": session.id, "user_id": user.id})
        await db.flush()
        return dict(result)


async def mastery_summary(db: AsyncSession, session: LearningSession, rows: list[SessionAnswer],
                          concepts: dict[str, LearnerConcept]) -> list[dict[str, Any]]:
    practiced = list(dict.fromkeys(c["concept_id"] for r in rows for c in r.evaluation["mastery_changes"]))
    titles = {c.id: c.title[session.language] for c in (await db.execute(select(Concept).where(
        Concept.id.in_(practiced)))).scalars()}
    starts = dict((session.learning_snapshot or {}).get("mastery", {}))
    if any(cid not in starts for cid in practiced):
        raise SessionIntegrityError("session start mastery is missing a practiced concept")
    return [{"concept_id": cid, "title": titles[cid], "before": grading.report(Decimal(starts[cid])),
             "after": grading.report(Decimal(concepts[cid].mastery))} for cid in practiced]


async def completion(db: AsyncSession, user: User, session: LearningSession, percent: int,
                     perfect: bool, now: datetime) -> tuple[list[dict[str, Any]], dict[str, int], bool | None]:
    grants: list[dict[str, Any]] = []
    events: dict[str, int] = {}
    passed = None

    async def award(reason: str, key: str) -> bool:
        if await xp.grant(db, user, reason, xp.AMOUNTS[reason], "session", session.id, now, reward_key=key):
            grants.append({"reason": reason, "xp": xp.AMOUNTS[reason]})
            return True
        return False

    if session.kind == "lesson":
        await db.execute(insert(LearnerLesson).values(user_id=user.id, lesson_id=session.lesson_id)
                         .on_conflict_do_nothing())
        fact = (await db.execute(select(LearnerLesson).where(LearnerLesson.user_id == user.id,
                                LearnerLesson.lesson_id == session.lesson_id).with_for_update())).scalar_one()
        fact.completed_at = fact.completed_at or now
        fact.completed_session_id = fact.completed_session_id or session.id
        fact.best_percent = max(fact.best_percent or 0, percent)
        if await award("lesson_complete", f"lesson:{session.lesson_id}"):
            events["complete_lessons"] = 1
        if perfect and await award("lesson_perfect", f"lesson:{session.lesson_id}"):
            events["perfect_lesson"] = 1
    if session.unit_id is not None:
        await db.execute(insert(LearnerUnit).values(user_id=user.id, unit_id=session.unit_id)
                         .on_conflict_do_nothing())
        unit_fact = (await db.execute(select(LearnerUnit).where(LearnerUnit.user_id == user.id,
                         LearnerUnit.unit_id == session.unit_id).with_for_update())).scalar_one()
        unit = await db.get(Unit, session.unit_id)
        assert unit is not None
        published = [p for p in await catalog.published_lessons(db) if p.unit_id == unit.id]
        completed = set((await db.execute(select(LearnerLesson.lesson_id).where(
            LearnerLesson.user_id == user.id, LearnerLesson.completed_at.is_not(None)))).scalars())
        all_done = bool(published) and all(p.lesson_id in completed for p in published)
        if session.kind == "pretest" and unit_fact.pretest_taken_at is None:
            unit_fact.pretest_taken_at, unit_fact.pretest_percent = now, percent
            await award("pretest_complete", f"unit:{unit.id}")
        if session.kind == "unit_test":
            passed = percent >= (session.learning_snapshot or {}).get("pass_percent", unit.pass_percent)
            unit_fact.unit_test_best_percent = max(unit_fact.unit_test_best_percent or 0, percent)
            if all_done and unit_fact.first_post_percent is None:
                unit_fact.first_post_percent = percent
            if passed:
                unit_fact.unit_test_passed_at = unit_fact.unit_test_passed_at or now
                if not all_done and unit_fact.skipped_at is None and unit_fact.completed_at is None:
                    unit_fact.skipped_at = now
                await award("unit_test_passed", f"unit:{unit.id}")
        if all_done and unit_fact.unit_test_passed_at is not None:
            unit_fact.completed_at = unit_fact.completed_at or now
    return grants, events, passed


async def promote_terms(db: AsyncSession, user: User, concepts: dict[str, LearnerConcept],
                        contained: list[Term], term_concepts: dict[str, str | None],
                        cards: dict[str, Any], lang: str) -> list[dict[str, str]]:
    ids = {t.id for t in contained}
    for tid in sorted(ids):
        await db.execute(insert(LearnerTerm).values(user_id=user.id, term_id=tid).on_conflict_do_nothing())
    records = {t.id: t for t in (await db.execute(select(Term).where(
        (Term.id.in_(ids)) | (Term.concept_id.in_(concepts))))).scalars()}
    rows = list((await db.execute(select(LearnerTerm).where(LearnerTerm.user_id == user.id,
                                 LearnerTerm.term_id.in_(records)).order_by(LearnerTerm.term_id)
                                 .with_for_update())).scalars())
    mastered = []
    for row in rows:
        if row.term_id in ids:
            row.exposures += 1
            if row.state == "new":
                row.state = "learning"
        cid = term_concepts.get(row.term_id) if row.term_id in ids else records[row.term_id].concept_id
        concept = concepts.get(cid or "")
        if row.state != "mastered" and row.exposures >= 2 and concept is not None and concept.mastery >= Decimal("0.8"):
            row.state = "mastered"
            text = cards[row.term_id]["text"] if row.term_id in cards else records[row.term_id].text[lang]
            mastered.append({"term_id": row.term_id, "text": text})
    return mastered
