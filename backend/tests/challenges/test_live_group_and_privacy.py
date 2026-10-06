"""Four-player revision 10 flow, grace/absence, immutable public scores and account deletion."""

from __future__ import annotations

import asyncio
import json
from datetime import timedelta

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import func, select

from app.contract import FIXTURES_DIR
from app.contract import models as C
from app.models import DuelAnswer, DuelLiveEvent, User, XpEvent
from app.runtime import Resources
from app.services.challenges import coordinator, live
from app.services.platform import deletion
from tests.challenges import live_support as L
from tests.challenges import support as S

pytestmark = pytest.mark.integration


async def test_four_player_script_timeout_reconnect_tied_winners(world: tuple[TestClient, Resources]) -> None:
    _, r = world
    room = await L.make(r, humans=4, preset="group")
    started = await room.status()
    assert started.starts_at is not None
    await room.pulse(started.starts_at)
    actual = []
    for index in range(3):
        q = await room.question(index)
        assert q.issued_at is not None and q.deadline_at == q.issued_at + timedelta(seconds=10)
        key = await S.key(r, room.duel_id, index)
        exercise = (await room.state(0, q.issued_at))["data"]["live"]["question"]["exercise"]
        wrong = S.wrong(key, exercise)
        if index == 0:
            await live.close_connection(r, room.tickets[2], room.connections[2], q.issued_at + timedelta(seconds=4))
            await room.pulse(q.issued_at + timedelta(seconds=4))
            timings = [(0, 5, key), (1, 5, key), (3, 7.1, wrong)]
            end = q.issued_at + timedelta(seconds=7.1)
        elif index == 1:
            timings = [(0, 3, key), (1, 3, key), (2, 6, key), (3, 9, key)]
            end = q.issued_at + timedelta(seconds=9)
        else:
            timings = [(0, 4, wrong), (1, 6, wrong), (2, 8, key)]
            end = q.deadline_at + timedelta(microseconds=1)
        for seat, delay, answer in timings:
            await room.send(seat, "answer", {"question_index": index, "answer": answer},
                            q.issued_at + timedelta(seconds=delay))
        await room.pulse(end)
        result = (await room.state(0, end))["data"]["live"]["results_so_far"][-1]
        C.WQuestionResult.model_validate(result)
        actual.append(result)
        if index == 0:
            room.connections[2] = await live.open_connection(r, room.tickets[2], q.issued_at + timedelta(seconds=8))
            restored = (await room.state(2, q.issued_at + timedelta(seconds=8)))["data"]["live"]
            assert restored["phase"] == "result" and restored["my_answer"] == {"answer": None, "locked": True}
        closed = await room.question(index)
        assert closed.reveal_until is not None
        for seat in range(4):
            await room.send(seat, "ping", {}, closed.reveal_until)
        await room.pulse(closed.reveal_until)
    expected = json.loads((FIXTURES_DIR / "challenges" / "group_ws_script.json").read_text(encoding="utf-8"))
    expected_results = [e["data"] for e in expected if e["type"] == "question_result"]
    assert [[(p["correct"], p["elapsed_ms"], p["points"]) for p in e["players"]] for e in actual] == [
        [(p["correct"], p["elapsed_ms"], p["points"]) for p in e["players"]] for e in expected_results]
    final = await room.status()
    assert final.result is not None
    assert final.result["winner_user_ids"] == room.users[:2] and not final.result["is_draw"]
    assert [(p["rank"], p["points"]) for p in final.result["scores"]] == [(1, 260), (1, 260), (3, 230), (4, 105)]
    assert [p.xp_awarded for p in await L.players(r, room.duel_id)] == [15, 15, 4, 4]


async def test_grace_expiry_keeps_earned_points_but_remaining_zero(world: tuple[TestClient, Resources]) -> None:
    _, r = world
    room = await L.make(r, humans=2, preset="group")
    start = (await room.status()).starts_at
    assert start is not None
    await room.pulse(start)
    key = await S.key(r, room.duel_id, 0)
    for seat in range(2):
        await room.send(seat, "answer", {"question_index": 0, "answer": key}, start + timedelta(seconds=1))
    await room.pulse(start + timedelta(seconds=1))
    await live.close_connection(r, room.tickets[1], room.connections[1], start + timedelta(seconds=1))
    q = await room.question(0)
    assert q.reveal_until is not None
    await room.pulse(q.reveal_until)
    await room.pulse(start + timedelta(seconds=11))
    assert (await L.players(r, room.duel_id))[1].status == "left"
    room.connections[1] = await live.open_connection(r, room.tickets[1], start + timedelta(seconds=12))
    state = (await room.state(1, start + timedelta(seconds=12)))["data"]["live"]
    assert state["my_answer"] == {"answer": None, "locked": True}
    await room.send(1, "answer", {"question_index": 1, "answer": await S.key(r, room.duel_id, 1)},
                    start + timedelta(seconds=12))
    for index in (1, 2):
        q = await room.question(index)
        assert q.issued_at is not None
        moment = max(start + timedelta(seconds=12), q.issued_at + timedelta(seconds=1))
        await room.send(0, "answer", {"question_index": index, "answer": await S.key(r, room.duel_id, index)}, moment)
        await room.pulse(moment)
        q = await room.question(index)
        assert q.reveal_until is not None
        await room.pulse(q.reveal_until)
    async with r.sessionmaker() as db:
        rows = (await db.execute(select(DuelAnswer).where(DuelAnswer.duel_id == room.duel_id,
            DuelAnswer.user_id == room.users[1]).order_by(DuelAnswer.question_index))).scalars().all()
        assert rows[0].points == 145 and all(a.points == 0 and a.elapsed_ms == 0 for a in rows[1:])
        assert not (await db.get(User, room.users[1])).deleted_at
    scores = (await room.status()).result
    assert scores is not None and scores["scores"][1]["points"] == 145


async def test_public_scores_survive_private_answer_purge_and_names_mask_immediately(
        world: tuple[TestClient, Resources]) -> None:
    api, r = world
    room = await L.make(r, humans=2, preset="group")
    start = (await room.status()).starts_at
    assert start is not None
    await room.pulse(start)
    for index in range(3):
        q = await room.question(index)
        assert q.issued_at is not None
        for seat in range(2):
            await room.send(seat, "answer", {"question_index": index, "answer": await S.key(r, room.duel_id, index)},
                            q.issued_at + timedelta(seconds=1))
        await room.pulse(q.issued_at + timedelta(seconds=1))
        q = await room.question(index)
        assert q.reveal_until is not None
        await room.pulse(q.reveal_until)
    before = (await room.state(0, start + timedelta(minutes=1)))["data"]["live"]
    assert api.delete("/v1/me", headers=room.headers[1]).status_code == 204
    rest = api.get(f"/v1/duels/{room.duel_id}", headers=room.headers[0] | {"Accept-Language": "en"}).json()
    assert rest["players"][1]["display_name"] == "Deleted learner"
    async with r.sessionmaker() as db, db.begin():
        await deletion.purge_user(db, r.storage, room.users[1])
    after = (await room.state(0, start + timedelta(minutes=2)))["data"]["live"]
    assert after["totals"] == before["totals"] and after["results_so_far"] == before["results_so_far"]
    async with r.sessionmaker() as db:
        assert await db.scalar(select(func.count()).select_from(DuelAnswer).where(
            DuelAnswer.user_id == room.users[1])) == 0


async def test_deleted_account_stops_live_game_without_rewards(world: tuple[TestClient, Resources]) -> None:
    api, r = world
    room = await L.make(r, humans=2)
    start = (await room.status()).starts_at
    assert start is not None
    await room.pulse(start)
    assert api.delete("/v1/me", headers=room.headers[1]).status_code == 204
    assert await room.pulse(start + timedelta(seconds=1)) is False
    final = await room.status()
    assert final.status == "expired" and final.result is None
    async with r.sessionmaker() as db:
        assert await db.scalar(select(func.count()).select_from(XpEvent).where(XpEvent.ref_id == room.duel_id)) == 0


async def test_final_answer_race_and_failed_result_transaction_are_recoverable(world: tuple[TestClient, Resources],
                                                                            monkeypatch: pytest.MonkeyPatch) -> None:
    _, r = world
    room = await L.make(r, humans=2, preset="group")
    start = (await room.status()).starts_at
    assert start is not None
    await room.pulse(start)
    for index in range(3):
        q = await room.question(index)
        assert q.issued_at is not None
        key = await S.key(r, room.duel_id, index)
        moment = q.issued_at + timedelta(seconds=1)
        await asyncio.gather(*(room.send(s, "answer", {"question_index": index, "answer": key}, moment)
                               for s in range(2)))
        await asyncio.gather(room.pulse(moment), room.pulse(moment))
        q = await room.question(index)
        assert q.reveal_until is not None
        if index < 2:
            await room.pulse(q.reveal_until)
    original = coordinator.Lease.check
    checks = 0

    async def lose_before_commit(self: coordinator.Lease, res: Resources) -> None:
        nonlocal checks
        checks += 1
        if checks == 2:
            await res.redis.delete(self.owner_key(res))
        await original(self, res)

    with monkeypatch.context() as m:
        m.setattr(coordinator.Lease, "check", lose_before_commit)
        with pytest.raises(coordinator.LeaseLost):
            await room.pulse(q.reveal_until)
    assert (await room.status()).status == "in_progress"
    async with r.sessionmaker() as db:
        assert await db.scalar(select(func.count()).select_from(XpEvent).where(XpEvent.ref_id == room.duel_id)) == 0
    replacement = await coordinator.acquire(r, room.duel_id)
    assert replacement is not None
    room.lease = replacement
    await room.pulse(q.reveal_until)
    await room.pulse(q.reveal_until)
    async with r.sessionmaker() as db:
        assert await db.scalar(select(func.count()).select_from(XpEvent).where(XpEvent.ref_id == room.duel_id)) == 2
        assert await db.scalar(select(func.count()).select_from(DuelLiveEvent).where(
            DuelLiveEvent.duel_id == room.duel_id, DuelLiveEvent.kind == "finished")) == 1


async def test_beat_claims_ownerless_question_without_resetting_time(world: tuple[TestClient, Resources]) -> None:
    _, r = world
    room = await L.make(r, humans=2)
    start = (await room.status()).starts_at
    assert start is not None
    await room.pulse(start)
    q = await room.question(0)
    assert q.deadline_at is not None
    await room.lease.release(r)
    assert await coordinator.recover(r, q.deadline_at + timedelta(microseconds=1)) == 1
    closed = await room.question(0)
    assert closed.deadline_at == q.deadline_at and closed.closed_at is not None
    assert (await room.status()).phase == "result"
