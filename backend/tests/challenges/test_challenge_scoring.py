"""Challenge scoring and results (backend §11, §10.1; API §6.10): the shared ``challenge_points``, ranking with the
response-time tie-break and shared ranks, rank-1 XP for every winner, bots and forfeits without XP, the daily reward
cap, quests and the day, ``challenges_won``/``quickLight`` from authoritative duel results, and a finish race."""

from __future__ import annotations

import asyncio
from datetime import timedelta

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import func, select, text

from app.contract import models as C
from app.models import Duel, DuelAnswer, LearnerAchievement, Quest, XpEvent
from app.runtime import Resources
from app.services.challenges import bot, results
from app.services.challenges.duels import PRESETS
from app.services.learning import xp
from app.services.platform import outbox
from app.services.platform.auth_sessions import utcnow
from tests.challenges import support as S

DUEL = C.DuelConfig.model_validate(PRESETS["duel"])
GROUP = C.DuelConfig.model_validate(PRESETS["group"])


def test_shared_points_follow_the_presets() -> None:
    assert C.challenge_points(True, 7500, DUEL) == 150 and C.challenge_points(True, 7499, DUEL) == 149   # floor
    assert C.challenge_points(True, 500, GROUP) == 103                     # half_up: 2.5 → 3 (not banker's)
    assert C.challenge_points(True, 0, DUEL) == 100 and C.challenge_points(False, 15000, DUEL) == 0
    assert C.challenge_points(True, -5, GROUP) == 100


def standing(uid: str, points: int, ms: int, *, forfeited: bool = False) -> results.Standing:
    return results.Standing(user_id=uid, is_bot=False, forfeited=forfeited, points=points, correct=1, correct_ms=ms,
                            played_ms=ms)


def test_ranking_ties_and_forfeits() -> None:
    ranks = results.rank([standing("a", 300, 9000), standing("b", 300, 8000), standing("c", 100, 1000)])
    assert ranks == {"b": 1, "a": 2, "c": 3}                                # equal points: faster correct answers
    shared = results.rank([standing("a", 300, 8000), standing("b", 300, 8000), standing("c", 50, 1)])
    assert shared == {"a": 1, "b": 1, "c": 3}                                # still tied: shared rank
    assert results.rank([standing("a", 999, 1, forfeited=True), standing("b", 0, 0)]) == {"b": 1, "a": 2}
    assert results.reason_for("duel", 1, True) == "duel_draw" and results.reason_for("duel", 2, False) == "duel_loss"
    assert [results.reason_for("group", r, False) for r in (1, 2, 3, 4)] == [
        "group_rank_1", "group_rank_2", "group_rank_other", "group_rank_other"]


def test_bot_is_deterministic_and_plausible() -> None:
    exercise = {"payload": {"options": [{"option_id": f"o{i}"} for i in range(4)]}}
    key = {"option_id": "o2"}
    first = [bot.answer("duel_X", i, bot.BOT_IDS[0], exercise, key) for i in range(400)]
    assert first == [bot.answer("duel_X", i, bot.BOT_IDS[0], exercise, key) for i in range(400)]   # reproducible
    accuracy = sum(a.correct for a in first) / len(first)
    assert 0.63 < accuracy < 0.77
    assert all(1500 <= a.elapsed_ms <= 14000 for a in first)
    median = sorted(a.elapsed_ms for a in first)[200]
    assert 5000 < median < 7000
    assert all(a.answer == key for a in first if a.correct)
    assert all(a.answer["option_id"] in {"o0", "o1", "o3"} for a in first if not a.correct)
    tf = bot.answer("duel_X", 0, bot.BOT_IDS[1], {"payload": {}}, {"value": True})
    assert tf.answer == ({"value": True} if tf.correct else {"value": False})


async def live(resources: Resources, duel_id: str, user_id: str, index: int, correct: bool, elapsed: int,
               config: C.DuelConfig) -> None:
    """Record one live answer as the Phase 20 coordinator will (server times, shared points)."""
    now = utcnow()
    async with resources.sessionmaker() as db, db.begin():
        db.add(DuelAnswer(duel_id=duel_id, user_id=user_id, question_index=index, answer=None, correct=correct,
                          received_at=now, elapsed_ms=elapsed,
                          points=C.challenge_points(correct, config.time_limit_ms - elapsed, config)))


async def test_group_with_bots_shared_winners_and_rank_xp(world: tuple[TestClient, Resources]) -> None:
    _, resources = world
    a, b, c = [await S.make_user(resources) for _ in range(3)]
    for friend in (b, c):
        await S.befriend(resources, a, friend)
    t = utcnow()
    duel_id = await S.create(resources, a, t, preset="group", opponent_type="friends", friends=[b, c], bot_fill=True)
    await S.accept(resources, b, duel_id, t + timedelta(seconds=5))
    await S.decline(resources, c, duel_id, t + timedelta(seconds=6))         # all responded: starts with a bot seat
    duel, players = await S.load(resources, duel_id)
    assert duel.status == "ready" and [(p.user_id, p.is_bot) for p in players if p.status == "joined"] == [
        (a, False), (b, False), (bot.BOT_IDS[0], True)]
    for index in range(3):                                                  # a and b tie exactly; the bot is slower
        await live(resources, duel_id, a, index, True, 4000, GROUP)
        await live(resources, duel_id, b, index, True, 4000, GROUP)
        await live(resources, duel_id, bot.BOT_IDS[0], index, index == 0, 9000, GROUP)
    assert await S.finish(resources, duel_id, t + timedelta(minutes=1))
    duel, players = await S.load(resources, duel_id)
    assert duel.result is not None
    assert sorted(duel.result["winner_user_ids"]) == sorted([a, b]) and duel.result["is_draw"] is False
    assert [(s["user_id"], s["rank"]) for s in duel.result["scores"]] == [(a, 1), (b, 1), (bot.BOT_IDS[0], 3)]
    by = {p.user_id: p.xp_awarded for p in players}
    assert (by[a], by[b], by[bot.BOT_IDS[0]], by[c]) == (15, 15, 0, None)    # every rank-1 player gets rank-1 XP
    async with resources.sessionmaker() as db:
        reasons = dict((await db.execute(select(XpEvent.user_id, XpEvent.reason).where(
            XpEvent.ref_type == "duel"))).all())
        assert reasons == {a: "group_rank_1", b: "group_rank_1"}
        assert await db.scalar(select(func.count()).select_from(XpEvent).where(XpEvent.user_id == bot.BOT_IDS[0])) \
            == 0
        day = await db.scalar(text("SELECT qualifying FROM daily_activity WHERE user_id = :u"), {"u": a})
        assert day is True                                                   # a finished challenge qualifies the day


async def test_draw_and_daily_reward_cap(world: tuple[TestClient, Resources]) -> None:
    _, resources = world
    a = await S.make_user(resources)
    t = utcnow()
    awarded = []
    for _ in range(results.REWARDED_PER_DAY + 2):
        duel_id = await S.create(resources, a, t, opponent_type="bot")
        for index in range(7):
            await live(resources, duel_id, a, index, True, 5000, DUEL)
            await live(resources, duel_id, bot.BOT_IDS[0], index, True, 5000, DUEL)   # identical: a draw
        assert await S.finish(resources, duel_id, t + timedelta(minutes=2))
        duel, players = await S.load(resources, duel_id)
        assert duel.result is not None and duel.result["is_draw"] is True
        awarded.append(players[0].xp_awarded)
    assert awarded == [8] * results.REWARDED_PER_DAY + [0, 0]               # anti-farming: 5 rewarded per day
    async with resources.sessionmaker() as db:
        assert await db.scalar(select(func.count()).select_from(XpEvent).where(
            XpEvent.reason == "duel_draw")) == results.REWARDED_PER_DAY


async def test_win_advances_the_win_challenge_quest(world: tuple[TestClient, Resources]) -> None:
    _, resources = world
    a = await S.make_user(resources)
    me = await S.user(resources, a)
    async with resources.sessionmaker() as db, db.begin():   # today's quest set includes "win a challenge"
        db.add(Quest(user_id=a, local_date=xp.local_date(utcnow(), me.timezone), slot=1, kind="win_challenge",
                     goal=1, reward_xp=15))
    t = utcnow()
    duel_id = await S.create(resources, a, t, opponent_type="bot")
    for index in range(7):
        await live(resources, duel_id, a, index, True, 2000, DUEL)
        await live(resources, duel_id, bot.BOT_IDS[0], index, False, 9000, DUEL)
    await S.finish(resources, duel_id, t + timedelta(minutes=2))
    async with resources.sessionmaker() as db:
        quest = (await db.execute(select(Quest).where(Quest.user_id == a, Quest.kind == "win_challenge"))).scalar_one()
        assert quest.progress == 1 and quest.completed_at is not None
        assert await db.scalar(select(func.count()).select_from(XpEvent).where(
            XpEvent.user_id == a, XpEvent.reason == "quest_complete", XpEvent.xp == 15)) == 1


async def test_quick_light_counts_live_wins_against_friends_only(world: tuple[TestClient, Resources]) -> None:
    _, resources = world
    a, b = await S.make_user(resources), await S.make_user(resources)
    await S.befriend(resources, a, b)
    t = utcnow()
    bot_duel = await S.create(resources, a, t, opponent_type="bot")
    for index in range(7):
        await live(resources, bot_duel, a, index, True, 1000, DUEL)
    await S.finish(resources, bot_duel, t + timedelta(minutes=1))
    friend_duel = await S.create(resources, a, t + timedelta(minutes=2), friends=[b])
    await S.accept(resources, b, friend_duel, t + timedelta(minutes=2, seconds=5))
    for index in range(7):
        await live(resources, friend_duel, a, index, True, 1000, DUEL)
        await live(resources, friend_duel, b, index, index < 3, 5000, DUEL)
    await S.finish(resources, friend_duel, t + timedelta(minutes=3))
    await outbox.relay(resources.sessionmaker)
    async with resources.sessionmaker() as db:
        mine = await db.get(LearnerAchievement, (a, "quickLight"))
        theirs = await db.get(LearnerAchievement, (b, "quickLight"))
        assert mine is not None and mine.progress == 1 and mine.unlocked_at is not None   # the bot win did not count
        assert theirs is not None and theirs.progress == 0 and theirs.unlocked_at is None


async def test_concurrent_finish_writes_one_result(world: tuple[TestClient, Resources]) -> None:
    _, resources = world
    a = await S.make_user(resources)
    t = utcnow()
    duel_id = await S.create(resources, a, t, opponent_type="bot")
    for index in range(7):
        await live(resources, duel_id, a, index, True, 3000, DUEL)
    outcomes = await asyncio.gather(*(S.finish(resources, duel_id, t + timedelta(minutes=1)) for _ in range(6)))
    assert sorted(outcomes) == [False] * 5 + [True]
    async with resources.sessionmaker() as db:
        assert await db.scalar(select(func.count()).select_from(XpEvent).where(XpEvent.ref_type == "duel")) == 1
        assert await db.scalar(text("SELECT count(*) FROM outbox_events WHERE kind = 'duel.finished'")) == 1
    async with resources.sessionmaker() as db:
        with pytest.raises(Exception, match="is closed"):
            async with db.begin():
                await db.execute(text("UPDATE duels SET status = 'ready' WHERE id = :d"), {"d": duel_id})
    async with resources.sessionmaker() as db:
        with pytest.raises(Exception, match="is closed"):
            async with db.begin():
                await db.execute(text("UPDATE duels SET result = '{}'::jsonb WHERE id = :d"), {"d": duel_id})
    async with resources.sessionmaker() as db:
        duel = await db.get(Duel, duel_id)
        assert duel is not None and duel.phase == "finished"
