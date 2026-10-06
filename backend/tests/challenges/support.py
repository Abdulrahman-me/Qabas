"""Helpers for challenge tests: learners and friendships created directly, duels driven through the services with
explicit server times, and server-side keys read only to play correctly in tests."""

from __future__ import annotations

from datetime import datetime, timedelta
from typing import Any

from sqlalchemy import select

from app.contract import models as C
from app.models import Duel, DuelPlayer, DuelQuestion, ExerciseVersion, Friendship, User
from app.runtime import Resources
from app.services.challenges import duels, play, results
from app.services.community.friends import pair
from tests.community.support import make_user, signed_in

__all__ = ["make_user", "signed_in"]


async def befriend(resources: Resources, a: str, b: str) -> None:
    x, y = pair(a, b)
    async with resources.sessionmaker() as db, db.begin():
        db.add(Friendship(user_a=x, user_b=y))


async def user(resources: Resources, user_id: str) -> User:
    async with resources.sessionmaker() as db:
        found = await db.get(User, user_id)
        assert found is not None
        return found


async def create(resources: Resources, creator: str, now: datetime, *, preset: str = "duel",
                 opponent_type: str = "friend", friends: list[str] | None = None, bot_fill: bool = False) -> str:
    body = C.DuelCreate(preset=preset, opponent_type=opponent_type,  # type: ignore[arg-type]
                        friend_user_ids=friends or [], bot_fill=bot_fill)
    async with resources.sessionmaker() as db, db.begin():
        me = await db.get(User, creator)
        assert me is not None
        return (await duels.create(db, me, body, now)).id


async def accept(resources: Resources, uid: str, duel_id: str, now: datetime) -> None:
    async with resources.sessionmaker() as db, db.begin():
        me = await db.get(User, uid)
        assert me is not None
        await duels.accept(db, me, duel_id, now)


async def decline(resources: Resources, uid: str, duel_id: str, now: datetime) -> None:
    async with resources.sessionmaker() as db, db.begin():
        me = await db.get(User, uid)
        assert me is not None
        await duels.decline(db, me, duel_id, now)


async def to_async(resources: Resources, uid: str, duel_id: str, now: datetime) -> None:
    async with resources.sessionmaker() as db, db.begin():
        me = await db.get(User, uid)
        assert me is not None
        await duels.switch_async(db, me, duel_id, now)


async def next_q(resources: Resources, uid: str, duel_id: str, now: datetime, lang: str = "en") -> dict[str, Any]:
    async with resources.sessionmaker() as db, db.begin():
        me = await db.get(User, uid)
        assert me is not None
        return await play.next_question(db, me, duel_id, lang, now)


async def answer(resources: Resources, uid: str, duel_id: str, index: int, value: Any, now: datetime,
                 lang: str = "en") -> dict[str, Any]:
    async with resources.sessionmaker() as db, db.begin():
        me = await db.get(User, uid)
        assert me is not None
        body = C.AsyncAnswer.model_validate({"question_index": index, "answer": value})
        return await play.answer(db, me, duel_id, body, value, lang, now)


async def key(resources: Resources, duel_id: str, index: int) -> dict[str, Any]:
    """The private key of a question (test-only server read, to answer correctly)."""
    async with resources.sessionmaker() as db:
        q = (await db.execute(select(DuelQuestion).where(DuelQuestion.duel_id == duel_id, DuelQuestion.user_id.is_(
            None), DuelQuestion.question_index == index))).scalar_one()
        version = await db.get(ExerciseVersion, (q.exercise_id, q.exercise_version))
        assert version is not None
        return dict(version.answer_key)


def wrong(value: dict[str, Any], exercise: dict[str, Any]) -> dict[str, Any]:
    if "value" in value:
        return {"value": not value["value"]}
    return {"option_id": next(o["option_id"] for o in exercise["payload"]["options"]
                              if o["option_id"] != value["option_id"])}


async def play_all(resources: Resources, uid: str, duel_id: str, start: datetime, *, correct: set[int],
                   answer_after: timedelta = timedelta(seconds=3)) -> datetime:
    """Play every question: correct on the given indexes, wrong otherwise; returns the time after the last answer."""
    now = start
    count = 7
    for index in range(count):
        served = await next_q(resources, uid, duel_id, now)
        assert served["question_index"] == index
        now += answer_after
        right = await key(resources, duel_id, index)
        await answer(resources, uid, duel_id, index, right if index in correct else wrong(right, served["exercise"]),
                     now)
        now += timedelta(seconds=1)
    return now


async def load(resources: Resources, duel_id: str) -> tuple[Duel, list[DuelPlayer]]:
    async with resources.sessionmaker() as db:
        duel = await db.get(Duel, duel_id)
        assert duel is not None
        return duel, await duels.players_of(db, duel_id)


async def finish(resources: Resources, duel_id: str, now: datetime) -> bool:
    async with resources.sessionmaker() as db, db.begin():
        duel = (await db.execute(select(Duel).where(Duel.id == duel_id).with_for_update())).scalar_one()
        return await results.finish(db, duel, now)
