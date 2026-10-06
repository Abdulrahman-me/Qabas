"""Async duel play (API §6.10 "Async fallback", rev 10 normative idempotency and timing).

* ``async/next`` returns the player's current question, issuing it once with server ``issued_at`` and
  ``deadline_at = issued_at + time_limit``. Until it is answered or its deadline passes every call returns the same
  question; it never skips ahead. A question whose deadline passed unanswered is recorded as a 0-point timeout
  before the next one is issued.
* ``async/answer`` records the current index once (primary key per duel, player and question) and replays the stored
  response for an answered index, even after the duel finished. Another index → ``409 out_of_order``.
  ``answer: null`` records a timeout; an answer received after ``deadline_at`` scores 0 and counts as a timeout.
* Grading is the deterministic key comparison of the pinned exercise version (never a model); points come from the
  contract's shared ``challenge_points`` with the server-measured remaining time. No key leaves the server before
  the player's answer is recorded. Challenge answers do not change mastery (they are not learning sessions).
* When both players are done (or the friend forfeited and the inviter is done) the results transaction runs in
  the same transaction as the last answer.
"""

from __future__ import annotations

from datetime import datetime, timedelta
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.contract import contextual
from app.contract import models as C
from app.errors import ApiError, ErrorCode
from app.models import Duel, DuelAnswer, DuelPlayer, DuelQuestion, ExerciseVersion, User
from app.services.challenges import duels, results
from app.services.learning.sessions import learner_exercise
from app.services.users import iso


def out_of_order(message: str = "Answer the current question.") -> ApiError:
    return ApiError(ErrorCode.out_of_order, message)


def _player(duel: Duel, players: list[DuelPlayer], user: User) -> DuelPlayer:
    me = next(p for p in players if p.user_id == user.id)
    if duel.mode != "async":
        raise duels.not_joinable("live", "This challenge is played live.")
    if me.seat > 1 or (me.seat == 1 and me.status != "joined"):
        raise duels.not_joinable("not_accepted", "Accept the challenge first.")
    return me


async def _question(db: AsyncSession, duel_id: str, index: int, user_id: str | None) -> DuelQuestion | None:
    condition = DuelQuestion.user_id.is_(None) if user_id is None else DuelQuestion.user_id == user_id
    return (await db.execute(select(DuelQuestion).where(
        DuelQuestion.duel_id == duel_id, DuelQuestion.question_index == index, condition))).scalar_one_or_none()


async def _version(db: AsyncSession, duel_id: str, index: int) -> ExerciseVersion:
    shared = await _question(db, duel_id, index, None)
    assert shared is not None
    version = await db.get(ExerciseVersion, (shared.exercise_id, shared.exercise_version))
    assert version is not None and version.published_at is not None
    return version


def _exercise(version: ExerciseVersion, duel: Duel, lang: str) -> dict[str, Any]:
    exercise = learner_exercise(version, lang)
    exercise["time_limit_ms"] = int(duel.config["time_limit_ms"])     # the challenge's limit (preset config)
    return exercise


def _ms(delta: timedelta) -> int:
    # Integer division preserves exact millisecond offsets (float 4.007 * 1000 may be 4006.999...).
    return max(0, delta // timedelta(milliseconds=1))


async def _record(db: AsyncSession, duel: Duel, me: DuelPlayer, issue: DuelQuestion, answer: dict[str, Any] | None,
                  lang: str, now: datetime) -> dict[str, Any]:
    version = await _version(db, duel.id, issue.question_index)
    exercise = _exercise(version, duel, lang)
    assert issue.issued_at is not None and issue.deadline_at is not None
    timed_out = answer is None or now > issue.deadline_at
    if answer is not None:
        try:
            contextual.validate_answer(exercise, answer, special=False)
        except ValueError:                                     # includes pydantic validation errors
            raise ApiError(ErrorCode.validation_error, "The answer does not match this question.",
                           {"field": "answer"}) from None
    key = version.answer_key
    correct = False if timed_out else bool(contextual.grade_answer(exercise, {"answer": answer}, key))
    received = min(now, issue.deadline_at) if answer is None else now
    elapsed = _ms(received - issue.issued_at)
    remaining = _ms(issue.deadline_at - now)
    points = C.challenge_points(correct, remaining, C.DuelConfig.model_validate(duel.config)) if correct else 0
    earlier = sum(r.points for r in await duels.answers_of(db, duel.id, me.user_id))
    finished = issue.question_index + 1 == int(duel.config["question_count"])
    body: dict[str, Any] = C.AsyncAnswerResp.model_validate({
        "question_index": issue.question_index, "correct": correct, "correct_answer": key, "points": points,
        "explanation": version.content["languages"][lang]["feedback"]["explanation"],
        "total_points": earlier + points, "finished": finished}).model_dump(mode="json")
    db.add(DuelAnswer(duel_id=duel.id, user_id=me.user_id, question_index=issue.question_index, answer=answer,
                      correct=correct, received_at=received, elapsed_ms=elapsed, points=points, response=body))
    await db.flush()
    if finished:
        me.completed_at = now
        await _maybe_finish(db, duel, now)
    return body


async def _maybe_finish(db: AsyncSession, duel: Duel, now: datetime) -> None:
    players = await duels.players_of(db, duel.id)
    inviter, friend = players[0], players[1]
    if inviter.completed_at is not None and (friend.completed_at is not None or friend.forfeited):
        await results.finish(db, duel, now)


async def next_question(db: AsyncSession, user: User, duel_id: str, lang: str, now: datetime) -> dict[str, Any]:
    duel, players = await duels.locked(db, duel_id, user, now)
    me = _player(duel, players, user)
    if duel.status != "in_progress" or me.completed_at is not None:
        raise duels.not_joinable("completed" if me.completed_at is not None else duel.status,
                                 "There are no more questions for you in this challenge.")
    count = int(duel.config["question_count"])
    while True:
        index = len(await duels.answers_of(db, duel.id, me.user_id))
        if index >= count:
            raise duels.not_joinable("completed", "There are no more questions for you in this challenge.")
        issue = await _question(db, duel.id, index, me.user_id)
        if issue is None:
            limit = timedelta(milliseconds=int(duel.config["time_limit_ms"]))
            pinned = await _version(db, duel.id, index)
            issue = DuelQuestion(duel_id=duel.id, question_index=index, user_id=me.user_id,
                                 exercise_id=pinned.exercise_id, exercise_version=pinned.version,
                                 issued_at=now, deadline_at=now + limit)
            db.add(issue)
            await db.flush()
        assert issue.deadline_at is not None and issue.issued_at is not None
        if now < issue.deadline_at:
            version = await _version(db, duel.id, index)
            served: dict[str, Any] = C.AsyncNext.model_validate({
                "question_index": index, "total": count, "exercise": _exercise(version, duel, lang),
                "issued_at": iso(issue.issued_at), "deadline_at": iso(issue.deadline_at)}).model_dump(mode="json")
            return served
        await _record(db, duel, me, issue, None, lang, now)                # a passed deadline is a timeout
        if duel.status != "in_progress" or me.completed_at is not None:
            raise duels.not_joinable("completed", "There are no more questions for you in this challenge.")


async def answer(db: AsyncSession, user: User, duel_id: str, body: C.AsyncAnswer, raw_answer: Any, lang: str,
                 now: datetime) -> dict[str, Any]:
    duel, players = await duels.locked(db, duel_id, user, now)
    me = _player(duel, players, user)
    stored = await db.get(DuelAnswer, (duel.id, me.user_id, body.question_index))
    if stored is not None:
        return dict(stored.response or {})                     # an answered index replays its response
    if duel.status != "in_progress" or me.completed_at is not None:
        raise out_of_order("This challenge has no open question for you.")
    current = len(await duels.answers_of(db, duel.id, me.user_id))
    issue = await _question(db, duel.id, current, me.user_id)
    if body.question_index != current or issue is None:
        raise out_of_order()
    return await _record(db, duel, me, issue, raw_answer, lang, now)
