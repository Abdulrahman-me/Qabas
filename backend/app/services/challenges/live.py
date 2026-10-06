"""Live transport transactions and private projections (API section 8).

All writes serialize on the existing duel row. Human answers use the existing pinned deterministic grader;
neither a socket nor Redis can create a challenge, change timing, reveal a future key or grant rewards.
"""

from __future__ import annotations

import hashlib
import json
import uuid
from collections.abc import Awaitable
from datetime import datetime, timedelta
from typing import Any, cast

from sqlalchemy import func, select, text
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.contract import contextual
from app.contract import models as C
from app.errors import ApiError, ErrorCode
from app.models import Duel, DuelAnswer, DuelConnection, DuelLiveEvent, DuelPlayer, DuelQuestion, User
from app.runtime import Resources, redis_key
from app.services.challenges import duels, play, results, tickets


def timestamp(value: datetime) -> str:
    """Preserve the exact persisted instant; second rounding would alter a live deadline."""
    return value.isoformat().replace("+00:00", "Z")


IDLE = timedelta(seconds=30)
GRACE = timedelta(seconds=10)


async def append(db: AsyncSession, duel: Duel, kind: str, event_key: str, data: dict[str, Any], now: datetime,
                 epoch: int | None = None) -> int | None:
    return (await db.execute(insert(DuelLiveEvent).values(
        duel_id=duel.id, kind=kind, event_key=event_key, data=data, recorded_at=now, epoch=epoch)
        .on_conflict_do_nothing(index_elements=[DuelLiveEvent.duel_id, DuelLiveEvent.event_key])
        .returning(DuelLiveEvent.id))).scalar_one_or_none()


async def questions(db: AsyncSession, duel_id: str) -> list[DuelQuestion]:
    return list((await db.execute(select(DuelQuestion).where(DuelQuestion.duel_id == duel_id,
        DuelQuestion.user_id.is_(None)).order_by(DuelQuestion.question_index))).scalars())


async def answers(db: AsyncSession, duel_id: str) -> list[DuelAnswer]:
    return list((await db.execute(select(DuelAnswer).where(DuelAnswer.duel_id == duel_id)
                                  .order_by(DuelAnswer.question_index, DuelAnswer.user_id))).scalars())


async def authorize(db: AsyncSession, duel_id: str, user_id: str) -> tuple[Duel, DuelPlayer]:
    duel = await db.scalar(select(Duel).where(Duel.id == duel_id).with_for_update())
    me = await db.get(DuelPlayer, (duel_id, user_id)) if duel is not None else None
    if duel is None or me is None or me.is_bot:
        raise ApiError(ErrorCode.forbidden, "Challenge access denied.")
    if duel.mode != "live" or me.status == "declined" or (duel.status in ("ready", "in_progress", "finished")
                                                         and me.status == "invited"):
        raise duels.not_joinable("not_participating")
    return duel, me


async def active_connections(db: AsyncSession, duel_id: str, now: datetime) -> list[DuelConnection]:
    return list((await db.execute(select(DuelConnection).where(DuelConnection.duel_id == duel_id,
        DuelConnection.closed_at.is_(None), DuelConnection.expires_at > now))).scalars())


async def open_connection(r: Resources, ticket: tickets.Ticket, now: datetime) -> uuid.UUID:
    async with r.sessionmaker() as db, db.begin():
        await tickets.principal(db, ticket, r.settings, now, touch=True)
        duel, me = await authorize(db, ticket.duel_id, ticket.user_id)
        # Deletion/revocation may commit while the duel lock is awaited; refresh the principal afterward.
        await tickets.principal(db, ticket, r.settings, now)
        # Different from the learner reward lock; all connects for a learner serialize without reversing it.
        await db.execute(text("SELECT pg_advisory_xact_lock(hashtextextended(:key, 0))"),
                         {"key": f"live-connections:{me.user_id}"})
        count = await db.scalar(select(func.count()).select_from(DuelConnection).where(
            DuelConnection.user_id == me.user_id, DuelConnection.closed_at.is_(None), DuelConnection.expires_at > now))
        if int(count or 0) >= r.settings.live_ws_max_connections:
            raise ApiError(ErrorCode.rate_limited, "Too many challenge connections.")
        previous = await active_connections(db, duel.id, now)
        if not any(c.user_id == me.user_id for c in previous):
            # A crashed process cannot grant a fresh grace period by waiting to notice its expired socket.
            if me.disconnected_at is None:
                ended = await db.scalar(select(func.max(DuelConnection.expires_at)).where(
                    DuelConnection.duel_id == duel.id, DuelConnection.user_id == me.user_id,
                    DuelConnection.closed_at.is_(None), DuelConnection.expires_at <= now))
                me.disconnected_at = ended
            if me.disconnected_at is not None:
                if duel.phase is not None and now >= me.disconnected_at + GRACE:
                    me.status = "left"
                else:
                    await append(db, duel, "input.reconnected", f"reconnect:{uuid.uuid4()}",
                                 {"user_id": me.user_id}, now)
                    me.disconnected_at = None
        cid = uuid.uuid4()
        db.add(DuelConnection(id=cid, duel_id=duel.id, user_id=me.user_id, auth_session_id=ticket.session_id,
                              connected_at=now, expires_at=now + IDLE))
        if duel.live_connected_at is None:
            duel.live_connected_at = now
        return cid


async def close_connection(r: Resources, ticket: tickets.Ticket, cid: uuid.UUID, now: datetime) -> None:
    async with r.sessionmaker() as db, db.begin():
        duel = await db.scalar(select(Duel).where(Duel.id == ticket.duel_id).with_for_update())
        conn = await db.get(DuelConnection, cid)
        if duel is None or conn is None or conn.closed_at is not None:
            return
        conn.closed_at = now
        await db.flush()
        if duel.status not in duels.OPEN:
            return
        me = await db.get(DuelPlayer, (duel.id, ticket.user_id))
        active = await active_connections(db, duel.id, now)
        if me is not None and me.status != "left" and not any(c.user_id == me.user_id for c in active) \
                and me.disconnected_at is None:
            me.disconnected_at = min(now, conn.expires_at)
            await append(db, duel, "input.disconnected", f"disconnect:{cid}", {"user_id": me.user_id}, now)


async def record(db: AsyncSession, duel: Duel, me: DuelPlayer, question: DuelQuestion,
                 answer: dict[str, Any] | None, now: datetime, *, absent: bool = False) -> bool:
    """One accepted answer; coordinator-only null/bot rows are fenced by the database trigger."""
    assert question.issued_at is not None and question.deadline_at is not None
    if await db.get(DuelAnswer, (duel.id, me.user_id, question.question_index)) is not None:
        return False
    version = await play._version(db, duel.id, question.question_index)
    exercise = play._exercise(version, duel, "ar")
    if answer is not None:
        try:
            contextual.validate_answer(exercise, answer, special=False)
        except ValueError:
            raise ApiError(ErrorCode.validation_error, "The answer does not match this question.") from None
    correct = answer is not None and bool(contextual.grade_answer(exercise, {"answer": answer}, version.answer_key))
    received = question.issued_at if absent else (question.deadline_at if answer is None else now)
    points = C.challenge_points(correct, play._ms(question.deadline_at - received),
                                C.DuelConfig.model_validate(duel.config)) if correct else 0
    saved = await db.execute(insert(DuelAnswer).values(
        duel_id=duel.id, user_id=me.user_id, question_index=question.question_index, answer=answer,
        correct=correct, received_at=received, elapsed_ms=play._ms(received - question.issued_at), points=points)
        .on_conflict_do_nothing(index_elements=[DuelAnswer.duel_id, DuelAnswer.user_id, DuelAnswer.question_index])
        .returning(DuelAnswer.user_id))
    return saved.scalar_one_or_none() is not None


async def message(r: Resources, ticket: tickets.Ticket, cid: uuid.UUID, frame: dict[str, Any], now: datetime) -> None:
    async with r.sessionmaker() as db, db.begin():
        await tickets.principal(db, ticket, r.settings, now, touch=True)
        duel, me = await authorize(db, ticket.duel_id, ticket.user_id)
        await tickets.principal(db, ticket, r.settings, now)
        conn = await db.get(DuelConnection, cid)
        if conn is None or conn.user_id != ticket.user_id or conn.duel_id != ticket.duel_id \
                or conn.auth_session_id != ticket.session_id or conn.closed_at is not None or conn.expires_at <= now:
            raise tickets.unauthorized()
        conn.expires_at = now + IDLE
        if frame["type"] == "ready" and me.ready_at is None and me.status in ("joined", "invited"):
            me.ready_at = now
            await append(db, duel, "input.ready", f"ready:{me.user_id}", {"user_id": me.user_id}, now)
        elif frame["type"] == "answer":
            data = frame["data"]
            if duel.status != "in_progress" or duel.phase != "question" or me.status != "joined":
                return
            rows = await questions(db, duel.id)
            current = next((q for q in rows if q.issued_at is not None and q.closed_at is None), None)
            if current is None or current.question_index != data["question_index"]:
                return
            assert current.issued_at is not None and current.deadline_at is not None
            if now < current.issued_at or now > current.deadline_at:
                return
            if await record(db, duel, me, current, data["answer"], now):
                await append(db, duel, "input.answered", f"answer:{me.user_id}:{current.question_index}",
                             {"user_id": me.user_id, "question_index": current.question_index}, now)
    await notify(r, ticket.duel_id)


async def notify(r: Resources, duel_id: str) -> None:
    # The journal was committed before this wakeup. Lost Redis delivery is recovered by the polling tail.
    await r.redis.publish(redis_key(r.settings, "duel", duel_id, "events"), b"changed")


def event(kind: str, data: dict[str, Any]) -> dict[str, Any]:
    result: dict[str, Any] = C.WsEvent.model_validate({"type": kind, "data": data}).model_dump(mode="json")
    return result


async def question_data(db: AsyncSession, duel: Duel, q: DuelQuestion, lang: str) -> dict[str, Any]:
    assert q.issued_at is not None and q.deadline_at is not None
    version = await play._version(db, duel.id, q.question_index)
    result: dict[str, Any] = C.WQuestion.model_validate({
        "question_index": q.question_index, "total": duel.config["question_count"],
        "exercise": play._exercise(version, duel, lang), "issued_at": timestamp(q.issued_at),
        "deadline_at": timestamp(q.deadline_at)}).model_dump(mode="json")
    return result


def totals(players: list[DuelPlayer], rows: list[DuelAnswer], through: int) -> list[dict[str, Any]]:
    return [{"user_id": p.user_id, "points": sum(a.points for a in rows if a.user_id == p.user_id
                                                and a.question_index <= through)}
            for p in results.participants(players)]


async def question_result(db: AsyncSession, duel: Duel, q: DuelQuestion, players: list[DuelPlayer],
                          rows: list[DuelAnswer], lang: str) -> dict[str, Any]:
    assert q.closed_at is not None
    version = await play._version(db, duel.id, q.question_index)
    coordinates = q.result_snapshot if q.result_snapshot is not None else result_coordinates(players, rows,
                                                                                           q.question_index)
    result: dict[str, Any] = C.WQuestionResult.model_validate({
        "question_index": q.question_index, "correct_answer": version.answer_key,
        "explanation": version.content["languages"][lang]["feedback"]["explanation"],
        **coordinates,
    }).model_dump(mode="json")
    return result


def result_coordinates(players: list[DuelPlayer], rows: list[DuelAnswer], index: int) -> dict[str, Any]:
    """Published game scores, with no raw selected answers or personal profile data."""
    by = {a.user_id: a for a in rows if a.question_index == index}
    return {"players": [C.WPlayerResult.model_validate({"user_id": p.user_id, "correct": by[p.user_id].correct,
        "elapsed_ms": by[p.user_id].elapsed_ms, "points": by[p.user_id].points}).model_dump(mode="json")
        for p in results.participants(players)], "totals": totals(players, rows, index)}


async def finished(db: AsyncSession, duel: Duel, me: DuelPlayer, lang: str) -> dict[str, Any]:
    summary = []
    for q in await questions(db, duel.id):
        if q.closed_at is None:
            continue
        version = await play._version(db, duel.id, q.question_index)
        local = version.content["languages"][lang]
        summary.append({"question_index": q.question_index, "prompt": local["exercise"]["prompt"],
                        "correct_answer": version.answer_key, "explanation": local["feedback"]["explanation"]})
    return event("finished", {"result": results.result_for(duel, me), "summary": summary})


async def state(db: AsyncSession, r: Resources, duel: Duel, me: DuelPlayer, viewer: User, lang: str, base: str,
                now: datetime) -> tuple[dict[str, Any], int]:
    """Read-through snapshot, private per viewer/language; caller holds the duel row lock.

    A DB-derived identity invalidates an old cache writer; Redis never authorizes a seat or changes state.
    Cursor and projection are captured in the same locked transaction, closing the connect/broadcast race.
    """
    players, qs, rows = await duels.players_of(db, duel.id), await questions(db, duel.id), await answers(db, duel.id)
    public = await duels.project(db, duel, viewer, lang, base)
    cursor = int(await db.scalar(select(func.max(DuelLiveEvent.id)).where(DuelLiveEvent.duel_id == duel.id)) or 0)
    stamp = hashlib.sha256(json.dumps({"status": duel.status, "phase": duel.phase, "epoch": duel.coordinator_epoch,
        "cursor": cursor, "result": duel.result, "public": public.model_dump(mode="json"),
        "players": [(p.user_id, p.status, p.xp_awarded, str(p.disconnected_at)) for p in players],
        "qs": [(q.question_index, str(q.issued_at), str(q.closed_at)) for q in qs],
        "answers": [(a.user_id, a.question_index) for a in rows]}, sort_keys=True).encode()).hexdigest()
    field = f"{me.user_id}:{lang}"
    cache_key = redis_key(r.settings, "duel", duel.id)
    cached = await cast(Awaitable[bytes | None], r.redis.hget(cache_key, field))
    if cached is not None:
        try:
            value = json.loads(cached)
            if value["stamp"] == stamp and value["viewer"] == me.user_id and value["base"] == base:
                body = value["state"]
                body["server_ts"] = timestamp(now)
                return event("state", body), cursor
        except (ValueError, TypeError, KeyError):
            pass
    live_state = None
    issued = [q for q in qs if q.issued_at is not None]
    current = issued[-1] if issued else None
    if duel.phase is not None and duel.status in ("in_progress", "finished"):
        index = current.question_index if current is not None else 0
        mine = next((a for a in rows if a.user_id == me.user_id and a.question_index == index), None)
        closed = [q for q in qs if q.closed_at is not None]
        last_closed = closed[-1].question_index if closed else -1
        locked = {"answer": mine.answer, "locked": True} if mine is not None else (
            {"answer": None, "locked": True} if me.status == "left" and duel.phase == "question" else None)
        deadline = None
        if duel.phase == "question" and current is not None:
            assert current.deadline_at is not None
            deadline = timestamp(current.deadline_at)
        live_state = {"phase": duel.phase, "question_index": index,
            "question": await question_data(db, duel, current, lang) if duel.phase == "question" and current else None,
            "deadline_at": deadline,
            "answered_user_ids": [a.user_id for a in rows if a.question_index == index and a.answer is not None],
            "my_answer": locked, "totals": (closed[-1].result_snapshot["totals"]
                if closed and closed[-1].result_snapshot is not None else totals(players, rows, last_closed)),
            "results_so_far": [await question_result(db, duel, q, players, rows, lang) for q in closed]}
    result = event("state", {"duel": public.model_dump(mode="json"), "server_ts": timestamp(now), "live": live_state})
    await cast(Awaitable[int], r.redis.hset(cache_key, field, json.dumps({
        "stamp": stamp, "viewer": me.user_id, "base": base, "state": result["data"]})))
    await r.redis.expire(cache_key, 60)
    return result, cursor


async def project_event(db: AsyncSession, r: Resources, duel: Duel, me: DuelPlayer, viewer: User,
                        item: DuelLiveEvent, lang: str, base: str, now: datetime) -> dict[str, Any] | None:
    kind, data = item.kind, item.data
    if kind == "answered":
        index = {"question_index": data["question_index"]}
        return event("answer_received", index) if data["user_id"] == me.user_id else event(
            "opponent_answered", {**index, "user_id": data["user_id"]})
    if kind in ("opponent_disconnected", "opponent_reconnected") and data["user_id"] == me.user_id:
        return None
    if kind == "question":
        if me.status == "left":
            return (await state(db, r, duel, me, viewer, lang, base, now))[0]
        q = await play._question(db, duel.id, data["question_index"], None)
        assert q is not None
        return event(kind, await question_data(db, duel, q, lang))
    if kind == "question_result":
        q = await play._question(db, duel.id, data["question_index"], None)
        assert q is not None
        return event(kind, await question_result(db, duel, q, await duels.players_of(db, duel.id),
                                                 await answers(db, duel.id), lang))
    if kind == "finished":
        return await finished(db, duel, me, lang)
    if kind == "state":
        if data.get("status") == "ready":
            public = (await duels.project(db, duel, viewer, lang, base)).model_dump(mode="json")
            public.update(status="ready", result=None)
            return event(kind, {"duel": public, "server_ts": timestamp(now), "live": None})
        return (await state(db, r, duel, me, viewer, lang, base, now))[0]
    return event(kind, data)
