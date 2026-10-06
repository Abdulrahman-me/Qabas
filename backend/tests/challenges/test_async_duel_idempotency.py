"""Async duels (API §6.10 rev 10 normative idempotency and timing; backend §11.4): the switch after 60 s, idempotent
``next``, answers recorded once and replayed, ``out_of_order``, timeouts and late answers, the friend accepting into
async, results when both finish, the 24 h close with forfeit and abandonment, decline as forfeit, and races."""

from __future__ import annotations

import asyncio
import json
from datetime import timedelta

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import func, select, text

from app.models import DuelAnswer, XpEvent
from app.runtime import Resources
from app.services.challenges import duels
from app.services.platform.auth_sessions import utcnow
from tests.challenges import support as S

pytestmark = pytest.mark.integration
S60 = timedelta(seconds=61)


async def pair(resources: Resources) -> tuple[str, str]:
    a, b = await S.make_user(resources), await S.make_user(resources)
    await S.befriend(resources, a, b)
    return a, b


async def started(resources: Resources) -> tuple[str, str, str, object]:
    a, b = await pair(resources)
    t0 = utcnow()
    duel_id = await S.create(resources, a, t0, friends=[b])
    await S.to_async(resources, a, duel_id, t0 + S60)
    return a, b, duel_id, t0 + S60


async def test_switch_rules(world: tuple[TestClient, Resources]) -> None:
    _, resources = world
    a, b = await pair(resources)
    t0 = utcnow()
    duel_id = await S.create(resources, a, t0, friends=[b])
    with pytest.raises(Exception, match="Wait a minute"):
        await S.to_async(resources, a, duel_id, t0 + timedelta(seconds=59))
    with pytest.raises(Exception, match="Only the challenger"):
        await S.to_async(resources, b, duel_id, t0 + S60)
    await S.to_async(resources, a, duel_id, t0 + S60)
    await S.to_async(resources, a, duel_id, t0 + S60 + timedelta(seconds=5))     # repeated switch: same duel
    duel, players = await S.load(resources, duel_id)
    assert (duel.mode, duel.status) == ("async", "in_progress")
    assert duel.expires_at == t0 + S60 + timedelta(hours=24)
    assert [p.status for p in players] == ["joined", "invited"]
    bot_duel = await S.create(resources, a, t0, opponent_type="bot")
    with pytest.raises(Exception, match="cannot be played later"):
        await S.to_async(resources, a, bot_duel, t0 + S60)


async def test_next_is_idempotent_and_answers_record_once(world: tuple[TestClient, Resources]) -> None:
    _, resources = world
    a, _, duel_id, t = await started(resources)
    first = await S.next_q(resources, a, duel_id, t)
    again = await S.next_q(resources, a, duel_id, t + timedelta(seconds=10))   # before the deadline: same question
    assert first == again and first["question_index"] == 0 and first["total"] == 7
    assert first["exercise"]["time_limit_ms"] == 15000
    issued = first["issued_at"]
    served = json.dumps(first)
    assert not any(word in served for word in ('"answer_key"', '"correct"', '"is_correct"', '"duel_eligible"',
                                                '"correct_answer"', '"option_misconceptions"'))
    right = await S.key(resources, duel_id, 0)
    with pytest.raises(Exception, match="current question"):
        await S.answer(resources, a, duel_id, 1, right, t + timedelta(seconds=4))  # not the current index
    response = await S.answer(resources, a, duel_id, 0, right, t + timedelta(seconds=4))
    assert response["correct"] is True and response["points"] == 100 + 100 * 11000 // 15000   # floor(73.3) = 73
    assert response["correct_answer"] == right and response["total_points"] == 173 and response["finished"] is False
    # A repeat (even with a different body or later) replays the stored response; the index is answered once.
    assert await S.answer(resources, a, duel_id, 0, S.wrong(right, first["exercise"]), t + timedelta(seconds=9)) \
        == response
    async with resources.sessionmaker() as db:
        assert await db.scalar(select(func.count()).select_from(DuelAnswer)) == 1
    second = await S.next_q(resources, a, duel_id, t + timedelta(seconds=5))
    assert second["question_index"] == 1 and second["issued_at"] != issued


async def test_timeouts_and_late_answers_score_zero(world: tuple[TestClient, Resources]) -> None:
    _, resources = world
    a, _, duel_id, t = await started(resources)
    await S.next_q(resources, a, duel_id, t)
    # No answer before the deadline: the next call records a 0-point timeout and issues the following question.
    served = await S.next_q(resources, a, duel_id, t + timedelta(seconds=15, milliseconds=1))
    assert served["question_index"] == 1
    timeout = await S.answer(resources, a, duel_id, 0, None, t + timedelta(seconds=40))   # replay of the timeout
    assert (timeout["correct"], timeout["points"]) == (False, 0)
    right = await S.key(resources, duel_id, 1)
    issued = t + timedelta(seconds=15, milliseconds=1)
    late = await S.answer(resources, a, duel_id, 1, right, issued + timedelta(seconds=15, milliseconds=1))
    assert (late["correct"], late["points"]) == (False, 0)                           # after deadline_at: 0
    await S.next_q(resources, a, duel_id, issued + timedelta(seconds=16))
    exact = await S.answer(resources, a, duel_id, 2, await S.key(resources, duel_id, 2),
                           issued + timedelta(seconds=16) + timedelta(seconds=15))   # exactly at the deadline
    assert exact["correct"] is True and exact["points"] == 100                       # 0 ms left: base points only
    await S.next_q(resources, a, duel_id, issued + timedelta(seconds=40))
    explicit = await S.answer(resources, a, duel_id, 3, None, issued + timedelta(seconds=41))
    assert (explicit["correct"], explicit["points"]) == (False, 0)
    async with resources.sessionmaker() as db:
        rows = (await db.execute(select(DuelAnswer).order_by(DuelAnswer.question_index))).scalars().all()
    assert rows[0].answer is None and rows[0].elapsed_ms == 15000


async def test_both_finish_and_results_reward_once(world: tuple[TestClient, Resources]) -> None:
    _, resources = world
    a, b, duel_id, t = await started(resources)
    end = await S.play_all(resources, a, duel_id, t, correct={0, 1, 2, 3, 4})
    duel, _ = await S.load(resources, duel_id)
    assert duel.status == "in_progress"                                      # waiting for the friend
    with pytest.raises(Exception, match="Accept the challenge first"):
        await S.next_q(resources, b, duel_id, end)
    await S.accept(resources, b, duel_id, end)
    await S.accept(resources, b, duel_id, end + timedelta(seconds=1))         # repeated accept is harmless
    await S.play_all(resources, b, duel_id, end + timedelta(minutes=5), correct={0, 1})
    duel, players = await S.load(resources, duel_id)
    assert duel.status == "finished" and duel.result is not None
    assert duel.result["winner_user_ids"] == [a] and duel.result["is_draw"] is False
    assert [(s["user_id"], s["rank"], s["correct"]) for s in duel.result["scores"]] == [(a, 1, 5), (b, 2, 2)]
    assert [p.xp_awarded for p in players] == [15, 4]
    async with resources.sessionmaker() as db:
        grants = sorted((await db.execute(select(XpEvent.user_id, XpEvent.reason).where(
            XpEvent.ref_type == "duel"))).all())
        assert grants == sorted([(a, "duel_win"), (b, "duel_loss")])
        assert await db.scalar(text("SELECT count(*) FROM outbox_events WHERE kind = 'duel.finished'")) == 1
        assert await db.scalar(text("SELECT count(*) FROM league_members")) == 2   # XP placed both in leagues
    assert await S.finish(resources, duel_id, end + timedelta(minutes=9)) is False   # results are written once
    with pytest.raises(Exception, match="no more questions"):
        await S.next_q(resources, a, duel_id, end + timedelta(minutes=10))
    replay = await S.answer(resources, a, duel_id, 6, None, end + timedelta(minutes=10))
    assert replay["finished"] is True                                        # answered index still replays


async def test_friend_forfeits_at_24_hours(world: tuple[TestClient, Resources]) -> None:
    _, resources = world
    a, b, duel_id, t = await started(resources)
    await S.play_all(resources, a, duel_id, t, correct={0})
    await S.accept(resources, b, duel_id, t + timedelta(hours=1))
    await S.play_all(resources, b, duel_id, t + timedelta(hours=1), correct=set(range(7)))  # better, but...
    duel, _ = await S.load(resources, duel_id)
    assert duel.status == "finished"                                         # (both finished: normal ranking)
    a2, b2, duel2, t2 = await started(resources)
    await S.play_all(resources, a2, duel2, t2, correct={0})
    await S.accept(resources, b2, duel2, t2 + timedelta(hours=1))
    await S.next_q(resources, b2, duel2, t2 + timedelta(hours=1))           # the friend starts but never finishes
    assert await duels.sweep(resources.sessionmaker, t2 + timedelta(hours=23)) == 0
    assert await duels.sweep(resources.sessionmaker, t2 + timedelta(hours=24)) == 1
    assert await duels.sweep(resources.sessionmaker, t2 + timedelta(hours=25)) == 0          # once
    duel2_row, players = await S.load(resources, duel2)
    assert duel2_row.result is not None and duel2_row.result["winner_user_ids"] == [a2]
    assert [(p.forfeited, p.xp_awarded) for p in players] == [(False, 15), (True, 0)]


async def test_inviter_abandons_and_normal_ranking_applies(world: tuple[TestClient, Resources]) -> None:
    _, resources = world
    a, b, duel_id, t = await started(resources)
    await S.next_q(resources, a, duel_id, t)
    await S.answer(resources, a, duel_id, 0, await S.key(resources, duel_id, 0), t + timedelta(seconds=2))
    await S.accept(resources, b, duel_id, t + timedelta(minutes=1))
    await S.play_all(resources, b, duel_id, t + timedelta(minutes=1), correct={0, 1, 2})
    await duels.sweep(resources.sessionmaker, t + timedelta(hours=24, seconds=1))
    duel, players = await S.load(resources, duel_id)
    assert duel.result is not None and duel.result["winner_user_ids"] == [b]
    assert [(p.forfeited, p.xp_awarded) for p in players] == [(False, 4), (False, 15)]


async def test_decline_after_the_switch_is_a_forfeit(world: tuple[TestClient, Resources]) -> None:
    _, resources = world
    a, b, duel_id, t = await started(resources)
    await S.decline(resources, b, duel_id, t + timedelta(seconds=5))
    await S.decline(resources, b, duel_id, t + timedelta(seconds=6))          # idempotent
    duel, _ = await S.load(resources, duel_id)
    assert duel.status == "in_progress"                                      # the inviter still plays
    await S.play_all(resources, a, duel_id, t + timedelta(seconds=10), correct=set())
    duel, players = await S.load(resources, duel_id)
    assert duel.status == "finished" and duel.result is not None and duel.result["winner_user_ids"] == [a]
    assert [p.xp_awarded for p in players] == [15, 0]


async def test_concurrent_answers_and_nexts_record_once(world: tuple[TestClient, Resources]) -> None:
    _, resources = world
    a, _, duel_id, t = await started(resources)
    issued = await asyncio.gather(*(S.next_q(resources, a, duel_id, t) for _ in range(5)))
    assert len({json.dumps(i, sort_keys=True) for i in issued}) == 1
    right = await S.key(resources, duel_id, 0)
    responses = await asyncio.gather(*(S.answer(resources, a, duel_id, 0, right, t + timedelta(seconds=2))
                                       for _ in range(5)))
    assert len({json.dumps(r, sort_keys=True) for r in responses}) == 1
    async with resources.sessionmaker() as db:
        assert await db.scalar(select(func.count()).select_from(DuelAnswer)) == 1
        assert await db.scalar(text("SELECT count(*) FROM duel_questions WHERE user_id IS NOT NULL")) == 1
    async with resources.sessionmaker() as db:
        with pytest.raises(Exception, match="insert-only"):
            async with db.begin():
                await db.execute(text("UPDATE duel_answers SET points = 999"))


async def test_async_flow_over_http(world: tuple[TestClient, Resources]) -> None:
    api, resources = world
    a, ha = await S.signed_in(resources)
    b, hb = await S.signed_in(resources)
    await S.befriend(resources, a, b)
    created = api.post("/v1/duels", json={"preset": "duel", "opponent_type": "friend", "friend_user_ids": [b],
                                          "bot_fill": False}, headers=ha)
    assert created.status_code == 201, created.text
    duel_id = created.json()["duel_id"]
    assert api.post(f"/v1/duels/{duel_id}/async", headers=ha).json()["error"]["details"]["reason"] == "too_early"
    async with resources.sessionmaker() as db, db.begin():
        await db.execute(text("UPDATE duels SET created_at = created_at - interval '61 seconds', "
                              "expires_at = expires_at - interval '61 seconds' WHERE id = :d"), {"d": duel_id})
    switched = api.post(f"/v1/duels/{duel_id}/async", headers=ha)
    assert switched.status_code == 200 and (switched.json()["mode"], switched.json()["status"]) == ("async",
                                                                                                    "in_progress")
    invites = api.get("/v1/duels/invitations", headers=hb).json()
    assert [i["duel_id"] for i in invites["items"]] == [duel_id] and invites["items"][0]["from"]["user_id"] == a
    accepted = api.post(f"/v1/duels/{duel_id}/accept", headers=hb).json()
    assert (accepted["mode"], accepted["status"]) == ("async", "in_progress")
    question = api.post(f"/v1/duels/{duel_id}/async/next", headers=ha)
    assert question.status_code == 200 and "answer_key" not in question.text
    body = {"question_index": 0, "answer": await S.key(resources, duel_id, 0)}
    first = api.post(f"/v1/duels/{duel_id}/async/answer", json=body, headers=ha)
    assert first.status_code == 200 and first.json()["correct"] is True
    assert api.post(f"/v1/duels/{duel_id}/async/answer", json=body, headers=ha).json() == first.json()
    assert api.post(f"/v1/duels/{duel_id}/async/answer", json={"question_index": 3, "answer": None},
                    headers=ha).json()["error"]["code"] == "out_of_order"
    assert api.post(f"/v1/duels/{duel_id}/async/answer", json={"question_index": 0}, headers=ha).status_code == 400
