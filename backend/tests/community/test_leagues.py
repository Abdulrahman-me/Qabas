"""Leagues (backend §10.3, API §6.9): Riyadh weeks, assignment on the first XP of the week under the per-(week, tier)
lock (a real race), ranking and ties from the XP ledger, privacy masking, ``/me/stats``, the idempotent week-end
promotion with no demotion, and who never joins."""

from __future__ import annotations

import asyncio
from collections import Counter
from datetime import UTC, datetime, timedelta

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import func, select, text

from app.config import Settings
from app.contract import models as C
from app.models import League, LeagueMember, LeaguePromotion, LearnerTier, User
from app.runtime import Resources
from app.services.community import leagues
from app.services.learning import xp
from app.services.platform.auth_sessions import utcnow
from tests.community.support import MIDWEEK, earn, league_of, make_user
from tests.learning.conftest import learner, user_id

pytestmark = pytest.mark.integration


def test_league_week_is_sunday_to_saturday_in_riyadh() -> None:
    start = leagues.week_start(MIDWEEK)
    assert start == datetime(2026, 10, 3, 21, 0, tzinfo=UTC)                 # Sunday 00:00 Asia/Riyadh
    assert leagues.week_end(MIDWEEK) == datetime(2026, 10, 10, 21, 0, tzinfo=UTC)
    # The whole week shares one key, the minute before it belongs to the previous week.
    assert {xp.week_key(start), xp.week_key(start + timedelta(days=7, seconds=-1))} == {xp.week_key(MIDWEEK)}
    assert xp.week_key(start - timedelta(seconds=1)) == leagues.previous_week_key(MIDWEEK) != xp.week_key(MIDWEEK)
    assert leagues.week_start(start) == start and leagues.week_start(start - timedelta(seconds=1)) == start - \
        timedelta(days=7)
    assert leagues.league_id("2026-W41", 2, 7) == "lg_2026w41_2_07"


async def test_first_xp_of_the_week_assigns_a_league_once(resources: Resources) -> None:
    uid = await make_user(resources)
    assert await league_of(resources, uid) is None
    assert await earn(resources, uid, 10)
    first = await league_of(resources, uid)
    assert first is not None and first.startswith("lg_")
    await earn(resources, uid, 10)
    assert await league_of(resources, uid) == first                           # one league per learner per week
    async with resources.sessionmaker() as db:
        tier = await db.get(LearnerTier, uid)
        assert tier is not None and tier.tier_key == "tier_lantern"           # every learner starts at index 0
    # A zero-XP grant does not place anyone; next week is a new league.
    other = await make_user(resources)
    async with resources.sessionmaker() as db, db.begin():
        user = await db.get(User, other)
        assert user is not None
        await xp.grant(db, user, "quest_complete", 0, "quest", "0", MIDWEEK)
    assert await league_of(resources, other) is None
    await earn(resources, uid, 5, MIDWEEK + timedelta(days=7))
    assert await league_of(resources, uid, MIDWEEK + timedelta(days=7)) not in (None, first)


async def test_concurrent_first_xp_never_overfills_a_league(resources: Resources) -> None:
    ids = [await make_user(resources) for _ in range(45)]
    results = await asyncio.gather(*(earn(resources, uid, 10) for uid in ids))
    assert all(results)
    async with resources.sessionmaker() as db:
        sizes = Counter((await db.execute(select(LeagueMember.league_id))).scalars())
        leagues_made = (await db.execute(select(League).order_by(League.seq))).scalars().all()
    assert sorted(sizes.values(), reverse=True) == [20, 20, 5]
    assert sum(sizes.values()) == 45 and len(leagues_made) == 3
    assert [lg.seq for lg in leagues_made] == [1, 2, 3]
    mine = await league_of(resources, ids[0])
    other = next(lg.id for lg in leagues_made if lg.id != mine)
    async with resources.sessionmaker() as db:
        with pytest.raises(Exception, match="uq_league_members_user_id_week_key"):
            async with db.begin():
                db.add(LeagueMember(league_id=other, user_id=ids[0], week_key=xp.week_key(MIDWEEK)))


async def test_standings_rank_by_weekly_xp_then_earlier_last_xp(resources: Resources) -> None:
    a, b, c = [await make_user(resources, display_name=n) for n in ("Seeker 1", "Seeker 2", "Seeker 3")]
    await earn(resources, a, 30, MIDWEEK)
    await earn(resources, b, 20, MIDWEEK - timedelta(hours=2))
    await earn(resources, b, 10, MIDWEEK - timedelta(hours=1))               # 30 too, but reached it earlier
    await earn(resources, c, 5, MIDWEEK)
    async with resources.sessionmaker() as db:
        me = await db.get(User, a)
        assert me is not None
        league = await leagues.current(db, me, "en", MIDWEEK)
    assert [(m.user_id, m.rank, m.xp_week) for m in league.members] == [(b, 1, 30), (a, 2, 30), (c, 3, 5)]
    assert league.my_rank == 2 and league.tier.tier_key == "tier_lantern" and league.tier.index == 0
    assert league.tier.name == "Lantern League" and not league.tier.is_top_tier and league.demotion is False
    assert league.week_start == "2026-10-03T21:00:00Z" and league.week_end == "2026-10-10T20:59:59Z"
    assert league.ends_in_seconds == int((leagues.week_end(MIDWEEK) - MIDWEEK).total_seconds())
    assert league.promotion_zone_size == 5 and all(m.in_promotion_zone for m in league.members)


async def test_private_members_are_masked_for_others_only(resources: Resources) -> None:
    private = await make_user(resources, display_name="Wayfarer 12", avatar_key="traveler_09", private_profile=True)
    public = await make_user(resources, display_name="Pilgrim 4", avatar_key="traveler_05")
    for uid in (private, public):
        await earn(resources, uid, 10)
    async with resources.sessionmaker() as db:
        viewer = await db.get(User, public)
        owner = await db.get(User, private)
        assert viewer is not None and owner is not None
        seen = {m.user_id: m for m in (await leagues.current(db, viewer, "ar", MIDWEEK)).members}
        own = {m.user_id: m for m in (await leagues.current(db, owner, "en", MIDWEEK)).members}
    assert (seen[private].display_name, seen[private].avatar_key) == ("مسافر", "traveler_01")
    assert (seen[public].display_name, seen[public].avatar_key) == ("Pilgrim 4", "traveler_05")
    assert seen[public].is_me and not seen[private].is_me
    assert (own[private].display_name, own[private].avatar_key) == ("Wayfarer 12", "traveler_09")
    dumped = C.League.model_validate((await _current(resources, public)).model_dump()).model_dump_json()
    assert "Wayfarer" not in dumped and "traveler_09" not in dumped


async def _current(resources: Resources, uid: str) -> C.League:
    async with resources.sessionmaker() as db:
        user = await db.get(User, uid)
        assert user is not None
        return await leagues.current(db, user, "en", MIDWEEK)


async def test_bots_synthetic_reviewers_and_deleted_users_never_join(resources: Resources) -> None:
    ids = [await make_user(resources, is_bot=True), await make_user(resources, is_synthetic=True),
           await make_user(resources, deleted_at=MIDWEEK)]
    for uid in ids:
        await earn(resources, uid, 10)
        assert await league_of(resources, uid) is None


async def test_week_end_promotion_is_idempotent_without_demotion(resources: Resources) -> None:
    last_week = MIDWEEK - timedelta(days=7)
    learners = [await make_user(resources) for _ in range(8)]
    for index, uid in enumerate(learners):
        await earn(resources, uid, 100 - index * 10, last_week)                # ranks 1..8 in order
    top = await make_user(resources)
    async with resources.sessionmaker() as db, db.begin():
        db.add(LearnerTier(user_id=top, tier_key="tier_dawn"))
    await earn(resources, top, 500, last_week)
    async with resources.sessionmaker() as db, db.begin():
        assert await leagues.promote_pending(db, last_week) == {}           # the week has not ended yet
    async with resources.sessionmaker() as db, db.begin():
        done = await leagues.promote_pending(db, MIDWEEK)
    assert done == {xp.week_key(last_week): 5}
    async with resources.sessionmaker() as db:
        tiers = dict((await db.execute(select(LearnerTier.user_id, LearnerTier.tier_key))).all())
    assert [tiers[u] for u in learners] == ["tier_beacon"] * 5 + ["tier_lantern"] * 3   # no demotion below
    assert tiers[top] == "tier_dawn"                                         # the top tier keeps its members
    async with resources.sessionmaker() as db, db.begin():
        assert await leagues.promote_pending(db, MIDWEEK) == {}             # once per week_key
    async with resources.sessionmaker() as db:
        assert await db.scalar(select(func.count()).select_from(LeaguePromotion)) == 1
        tiers_again = dict((await db.execute(select(LearnerTier.user_id, LearnerTier.tier_key))).all())
    assert tiers_again == tiers
    # This week the promoted learners play in the Beacon league, counting only this week's XP.
    await earn(resources, learners[0], 10)
    async with resources.sessionmaker() as db:
        league = await db.get(League, await league_of(resources, learners[0]))
        assert league is not None and league.tier_key == "tier_beacon"
    assert [(m.user_id, m.xp_week) for m in (await _current(resources, learners[0])).members] == [(learners[0], 10)]


async def test_first_xp_of_a_new_week_applies_the_pending_promotion_first(resources: Resources) -> None:
    last_week = MIDWEEK - timedelta(days=7)
    uid = await make_user(resources)
    await earn(resources, uid, 40, last_week)
    await earn(resources, uid, 10, MIDWEEK)                                  # no beat job ran in between
    async with resources.sessionmaker() as db:
        league = await db.get(League, await league_of(resources, uid))
        assert league is not None and league.tier_key == "tier_beacon"
        assert await db.get(LeaguePromotion, xp.week_key(last_week)) is not None


async def test_concurrent_promotions_apply_once(resources: Resources) -> None:
    last_week = MIDWEEK - timedelta(days=7)
    uid = await make_user(resources)
    await earn(resources, uid, 40, last_week)

    async def promote() -> dict[str, int]:
        async with resources.sessionmaker() as db, db.begin():
            return await leagues.promote_pending(db, MIDWEEK)

    results = await asyncio.gather(*(promote() for _ in range(5)))
    assert sorted(len(r) for r in results) == [0, 0, 0, 0, 1]
    async with resources.sessionmaker() as db:
        tier = await db.get(LearnerTier, uid)
        assert tier is not None and tier.tier_key == "tier_beacon" and tier.promoted_week_key == xp.week_key(last_week)


async def test_current_league_api_and_stats(learn_api: TestClient, curriculum_settings: Settings) -> None:
    api = learn_api
    headers = learner(api)
    missing = api.get("/v1/leagues/current", headers=headers)
    assert missing.status_code == 404
    assert missing.json()["error"]["code"] == "not_found"
    assert missing.json()["error"]["details"] == {"reason": "no_league_this_week"}
    assert api.get("/v1/me/stats", headers=headers).json()["league"] is None
    resources = Resources.create(curriculum_settings)
    try:
        await earn(resources, user_id(api, headers), 10, utcnow())
    finally:
        await resources.close()
    body = api.get("/v1/leagues/current", headers=headers | {"Accept-Language": "en"})
    assert body.status_code == 200, body.text
    league = C.League.model_validate(body.json())
    assert league.my_rank == 1 and [m.is_me for m in league.members] == [True] and league.members[0].xp_week == 10
    assert league.tier.name == "Lantern League"
    stats = api.get("/v1/me/stats", headers=headers).json()["league"]
    assert stats == {"league_id": league.league_id, "rank": 1, "size": 1}
    assert "email" not in body.text and "is_synthetic" not in body.text and "last_seen" not in body.text


async def test_deleted_learner_leaves_the_league(resources: Resources) -> None:
    from app.services.platform import deletion
    a, b = await make_user(resources), await make_user(resources)
    for uid in (a, b):
        await earn(resources, uid, 10)
    async with resources.sessionmaker() as db:
        user = await db.get(User, b)
    assert user is not None
    async with resources.sessionmaker() as db:
        await deletion.request_deletion(db, user, now=MIDWEEK)
    assert [m.user_id for m in (await _current(resources, a)).members] == [a]
    async with resources.sessionmaker() as db:
        assert await db.scalar(text("SELECT count(*) FROM league_members WHERE user_id = :u"), {"u": b}) == 0
