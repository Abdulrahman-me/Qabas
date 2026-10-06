"""Durable live protocol, pinned deterministic scoring and native crash/race recovery."""

from __future__ import annotations

import asyncio
import json
from datetime import timedelta

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import func, select, text

from app.contract import models as C
from app.models import DuelAnswer, DuelLiveEvent, XpEvent
from app.runtime import Resources, redis_key
from app.services.challenges import bot, coordinator, live, play
from tests.challenges import live_support as L
from tests.challenges import support as S
from tests.support.db import expect_sqlstate

pytestmark = pytest.mark.integration


async def test_full_bot_duel_seven_pinned_questions_and_single_result(world: tuple[TestClient, Resources]) -> None:
    _, r = world
    room = await L.make(r)
    started = await room.status()
    assert started.phase == "countdown" and started.starts_at == room.start + timedelta(seconds=4)
    now = started.starts_at
    assert now is not None
    await room.pulse(now)
    bot_expected = []
    for index in range(7):
        q = await room.question(index)
        assert q.issued_at is not None and q.deadline_at == q.issued_at + timedelta(seconds=15)
        public = await room.state(0, q.issued_at)
        C.WsEvent.model_validate(public)
        assert public["data"]["live"]["question"]["question_index"] == index
        assert "answer_key" not in json.dumps(public) and "correct_answer" not in json.dumps(
            public["data"]["live"]["question"])
        chosen = await S.key(r, room.duel_id, index)
        await room.send(0, "answer", {"question_index": index, "answer": chosen}, q.issued_at + timedelta(seconds=1))
        locked = (await room.state(0, q.issued_at + timedelta(seconds=1)))["data"]["live"]
        assert locked["my_answer"] == {"answer": chosen, "locked": True}
        async with r.sessionmaker() as db:
            version = await play._version(db, room.duel_id, index)
            expected = bot.answer(room.duel_id, index, bot.BOT_IDS[0],
                play._exercise(version, started, "en"), version.answer_key)
        bot_expected.append(expected)
        close = q.issued_at + timedelta(milliseconds=expected.elapsed_ms)
        await room.pulse(close)
        result = (await room.state(0, close))["data"]["live"]
        assert result["phase"] == "result" and len(result["results_so_far"]) == index + 1
        C.WQuestionResult.model_validate(result["results_so_far"][-1])
        closed = await room.question(index)
        assert closed.deadline_at == q.deadline_at and closed.reveal_until is not None
        now = closed.reveal_until
        await room.send(0, "ping", {}, now)
        await room.pulse(now)
    final = await room.status()
    assert final.status == "finished" and final.phase == "finished"
    assert final.result is not None and final.result["winner_user_ids"] == room.users
    async with r.sessionmaker() as db:
        rows = (await db.execute(select(DuelAnswer).where(DuelAnswer.duel_id == room.duel_id,
            DuelAnswer.user_id == bot.BOT_IDS[0]).order_by(DuelAnswer.question_index))).scalars().all()
        assert [(a.answer, a.correct, a.elapsed_ms) for a in rows] == [
            (e.answer, e.correct, e.elapsed_ms) for e in bot_expected]
        assert await db.scalar(select(func.count()).select_from(XpEvent).where(XpEvent.ref_id == room.duel_id)) == 1
        assert await db.scalar(select(func.count()).select_from(DuelLiveEvent).where(
            DuelLiveEvent.duel_id == room.duel_id, DuelLiveEvent.kind == "finished")) == 1
        phases = (await db.execute(select(DuelLiveEvent.kind, DuelLiveEvent.data).where(
            DuelLiveEvent.duel_id == room.duel_id,
            DuelLiveEvent.kind.in_(("countdown", "question", "question_result", "finished")))
            .order_by(DuelLiveEvent.id))).all()
        assert [(kind, data.get("question_index")) for kind, data in phases] == [
            ("countdown", None), *[(kind, i) for i in range(7) for kind in ("question", "question_result")],
            ("finished", None)]
    assert await room.pulse(now + timedelta(seconds=1)) is False
    state = (await room.state(0, now))["data"]
    assert state["duel"]["result"]["xp_awarded"] == 15 and "ticket=" not in state["duel"]["ws_url"]


async def test_takeover_preserves_deadline_lock_and_reveal(world: tuple[TestClient, Resources]) -> None:
    _, r = world
    room = await L.make(r, humans=2)
    start = (await room.status()).starts_at
    assert start is not None
    await room.pulse(start)
    q = await room.question(0)
    await room.send(0, "answer", {"question_index": 0, "answer": await S.key(r, room.duel_id, 0)},
                    start + timedelta(seconds=2))
    await room.lease.release(r)
    replacement = await coordinator.acquire(r, room.duel_id)
    assert replacement is not None and replacement.epoch > room.lease.epoch
    with pytest.raises(coordinator.LeaseLost):
        await coordinator.tick(r, room.lease, start + timedelta(seconds=3))
    room.lease = replacement
    await room.pulse(start + timedelta(seconds=3))
    restored = (await room.state(0, start + timedelta(seconds=3)))["data"]["live"]
    assert restored["deadline_at"] == q.deadline_at.isoformat().replace("+00:00", "Z")
    assert restored["my_answer"]["locked"] and restored["totals"][0]["points"] == 0
    assert (await room.state(1, start))["data"]["live"]["my_answer"] is None
    assert q.deadline_at is not None
    await room.pulse(q.deadline_at + timedelta(microseconds=1))
    closed = await room.question(0)
    await room.lease.release(r)
    third = await coordinator.acquire(r, room.duel_id)
    assert third is not None
    room.lease = third
    await room.pulse(q.deadline_at + timedelta(seconds=1))
    assert (await room.question(0)).reveal_until == closed.reveal_until
    assert (await room.question(1)).issued_at is None


async def test_redis_epoch_loss_cannot_reuse_persisted_fence(world: tuple[TestClient, Resources]) -> None:
    _, r = world
    room = await L.make(r, humans=2)
    old = room.lease
    await r.redis.delete(old.owner_key(r), redis_key(r.settings, "duel", room.duel_id, "epoch"))
    new = await coordinator.acquire(r, room.duel_id)
    assert new is not None and new.epoch > old.epoch
    assert not await old.renew(r)
    await old.release(r)
    assert await new.valid(r)
    with pytest.raises(coordinator.LeaseLost):
        await coordinator.tick(r, old, room.start)


async def test_only_one_concurrent_coordinator_claims(world: tuple[TestClient, Resources]) -> None:
    _, r = world
    room = await L.make(r, ready=False)
    await room.lease.release(r)
    owners = await asyncio.gather(*(coordinator.acquire(r, room.duel_id) for _ in range(8)))
    assert sum(o is not None for o in owners) == 1


async def test_database_rejects_old_epoch_phase_timing_event_and_bot(world: tuple[TestClient, Resources]) -> None:
    _, r = world
    room = await L.make(r)
    old = room.lease
    start = (await room.status()).starts_at
    assert start is not None
    await room.pulse(start)
    await old.release(r)
    new = await coordinator.acquire(r, room.duel_id)
    assert new is not None
    async with r.engine.begin() as conn:
        await conn.execute(text("SELECT set_config('qabas.coordinator_epoch', :e, true)"), {"e": str(old.epoch)})
        await expect_sqlstate(conn, "QB008", "UPDATE duels SET phase = 'result' WHERE id=:d", {"d": room.duel_id})
        await expect_sqlstate(conn, "QB008", "UPDATE duel_questions SET closed_at=now(), reveal_until=now() "
                              "WHERE duel_id=:d AND question_index=0", {"d": room.duel_id})
        await expect_sqlstate(conn, "QB008", "INSERT INTO duel_live_events (duel_id,event_key,kind,data,epoch,"
            "recorded_at) VALUES (:d,'stale','finished','{}',:e,now())", {"d": room.duel_id, "e": old.epoch})
        await expect_sqlstate(conn, "QB008", "INSERT INTO duel_answers (duel_id,user_id,question_index,answer,correct,"
            "received_at,elapsed_ms,points) VALUES (:d,:u,0,NULL,false,now(),0,0)",
            {"d": room.duel_id, "u": bot.BOT_IDS[0]})


async def test_commit_before_failed_broadcast_recovers_once(world: tuple[TestClient, Resources],
                                                           monkeypatch: pytest.MonkeyPatch) -> None:
    _, r = world
    room = await L.make(r, humans=2)
    start = (await room.status()).starts_at
    assert start is not None

    async def outage(*args: object) -> None:
        raise ConnectionError("recorded pubsub failure")

    with monkeypatch.context() as m:
        m.setattr(live, "notify", outage)
        with pytest.raises(ConnectionError):
            await room.pulse(start)
    assert (await room.question(0)).issued_at == start
    await room.lease.release(r)
    replacement = await coordinator.acquire(r, room.duel_id)
    assert replacement is not None
    room.lease = replacement
    await room.pulse(start + timedelta(seconds=1))
    async with r.sessionmaker() as db:
        assert await db.scalar(select(func.count()).select_from(DuelLiveEvent).where(
            DuelLiveEvent.duel_id == room.duel_id, DuelLiveEvent.event_key == "question:0")) == 1


async def test_simultaneous_answers_duplicate_devices_and_exact_deadline(world: tuple[TestClient, Resources]) -> None:
    _, r = world
    room = await L.make(r, humans=2)
    start = (await room.status()).starts_at
    assert start is not None
    await room.pulse(start)
    q = await room.question(0)
    assert q.deadline_at is not None
    chosen = await S.key(r, room.duel_id, 0)
    other = await live.open_connection(r, room.tickets[0], start)
    await asyncio.gather(room.send(0, "answer", {"question_index": 0, "answer": chosen}, q.deadline_at),
        live.message(r, room.tickets[0], other, {"type": "answer", "data": {"question_index": 0, "answer": chosen}},
                     q.deadline_at),
        room.send(1, "answer", {"question_index": 0, "answer": chosen}, q.deadline_at))
    await room.send(0, "answer", {"question_index": 0, "answer": {"option_id": "changed-invalid"}}, q.deadline_at)
    await room.send(0, "answer", {"question_index": 6, "answer": chosen}, q.deadline_at)
    async with r.sessionmaker() as db:
        rows = await live.answers(db, room.duel_id)
        assert len(rows) == 2 and all(a.points == 100 and a.correct for a in rows)
    await room.pulse(q.deadline_at)
    assert (await room.status()).phase == "result"


async def test_late_answer_is_ignored_and_timeout_zero(world: tuple[TestClient, Resources]) -> None:
    _, r = world
    room = await L.make(r, humans=2)
    start = (await room.status()).starts_at
    assert start is not None
    await room.pulse(start)
    q = await room.question(0)
    assert q.deadline_at is not None
    await room.send(0, "answer", {"question_index": 0, "answer": await S.key(r, room.duel_id, 0)},
                    q.deadline_at + timedelta(microseconds=1))
    await room.pulse(q.deadline_at + timedelta(microseconds=1))
    async with r.sessionmaker() as db:
        rows = await live.answers(db, room.duel_id)
        assert len(rows) == 2 and all(a.answer is None and a.points == 0 for a in rows)


async def test_empty_connected_quorum_respects_reconnect_grace(world: tuple[TestClient, Resources]) -> None:
    _, r = world
    room = await L.make(r, humans=2)
    start = (await room.status()).starts_at
    assert start is not None
    await room.pulse(start)
    for i in range(2):
        await live.close_connection(r, room.tickets[i], room.connections[i], start + timedelta(seconds=1))
    await room.pulse(start + timedelta(seconds=2))
    assert (await room.status()).phase == "question"
    room.connections[0] = await live.open_connection(r, room.tickets[0], start + timedelta(seconds=3))
    state = (await room.state(0, start + timedelta(seconds=3)))["data"]["live"]
    assert state["my_answer"] is None and state["question"]["question_index"] == 0


async def test_connection_replacement_does_not_disconnect_other_device(world: tuple[TestClient, Resources]) -> None:
    _, r = world
    room = await L.make(r, humans=2)
    other = await live.open_connection(r, room.tickets[0], room.start)
    await live.close_connection(r, room.tickets[0], room.connections[0], room.start)
    await room.pulse(room.start + timedelta(seconds=1))
    players = await L.players(r, room.duel_id)
    assert players[0].disconnected_at is None
    await live.close_connection(r, room.tickets[0], other, room.start + timedelta(seconds=2))
    assert (await L.players(r, room.duel_id))[0].disconnected_at == room.start + timedelta(seconds=2)
