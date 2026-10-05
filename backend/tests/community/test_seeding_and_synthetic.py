"""Seeded community configuration (migration snapshot = ``registries.json``; ``seed.py`` sync and drift refusal) and
synthetic league members (P-01): deterministic idempotent seed, seats left for learners, XP once per 30-minute slot
through the ordinary ledger, never befriended, tracked or counted in metrics, and refused in production."""

from __future__ import annotations

import re
from collections import Counter
from datetime import timedelta

import pytest
from pydantic import ValidationError
from sqlalchemy import func, select, text

from app.config import Environment, Settings
from app.models import LeagueMember, User, XpEvent
from app.runtime import Resources
from app.services.community import friends, leagues, seeding, synthetic
from app.services.learning import xp
from app.services.metrics import _eligible
from tests.community.support import MIDWEEK, earn, league_of, make_user

pytestmark = pytest.mark.integration


async def test_migration_snapshot_equals_the_registry(resources: Resources) -> None:
    async with resources.sessionmaker() as db, db.begin():
        assert await seeding.sync_registries(db) == {"league_tiers": 0, "achievements": 0}


async def test_sync_updates_from_the_registry_and_refuses_removed_keys(resources: Resources) -> None:
    async with resources.sessionmaker() as db, db.begin():
        await db.execute(text("UPDATE achievements SET target = 99 WHERE achievement_key = 'seeker'"))
        await db.execute(text("UPDATE league_tiers SET name = '{\"ar\": \"x\", \"en\": \"x\"}' "
                              "WHERE tier_key = 'tier_star'"))
    async with resources.sessionmaker() as db, db.begin():
        assert await seeding.sync_registries(db) == {"league_tiers": 1, "achievements": 1}
        assert await db.scalar(text("SELECT target FROM achievements WHERE achievement_key = 'seeker'")) == 5
    async with resources.sessionmaker() as db:
        with pytest.raises(seeding.RegistryDrift, match="retired"):
            async with db.begin():
                await db.execute(text("INSERT INTO achievements (achievement_key, position, title, description, "
                                      "counter, target) VALUES ('retired', 99, '{}', '{}', 'lessons_completed', 1)"))
                await seeding.sync_registries(db)


def test_synthetic_members_data_file() -> None:
    members = synthetic.members()
    assert len(members) == 60 == 4 * synthetic.PER_LEAGUE                        # SEED_AND_IMPORT §15
    assert len({m["key"] for m in members}) == 60 and len({m["display_name"] for m in members}) == 60
    assert len({synthetic.member_id(m["key"]) for m in members}) == 60
    assert all(0 <= m["active_hours"][0] < m["active_hours"][1] <= 24 and m["weekly_xp"] > 0 for m in members)
    assert all(re.fullmatch(r"usr_[0-9A-HJKMNP-TV-Z]{26}", synthetic.member_id(m["key"])) for m in members)


async def test_seed_is_idempotent_and_never_touches_real_learners(resources: Resources) -> None:
    real = await make_user(resources, id=synthetic.member_id("member_02"), display_name="Real Learner")
    async with resources.sessionmaker() as db, db.begin():
        assert await synthetic.seed(db) == 60
    async with resources.sessionmaker() as db, db.begin():
        assert await synthetic.seed(db) == 60
    async with resources.sessionmaker() as db:
        assert await db.scalar(select(func.count()).select_from(User).where(User.is_synthetic.is_(True))) == 59
        kept = await db.get(User, real)
        assert kept is not None and kept.display_name == "Real Learner" and not kept.is_synthetic
        assert await db.scalar(select(func.count()).select_from(User).where(
            User.is_synthetic.is_(True), User.email.is_not(None))) == 0              # no credentials: no sign-in


async def test_fill_leaves_seats_for_learners_and_grants_slot_xp_once(resources: Resources) -> None:
    async with resources.sessionmaker() as db, db.begin():
        await synthetic.seed(db)
    first = await make_user(resources)
    await earn(resources, first, 10)
    async with resources.sessionmaker() as db, db.begin():
        assert await synthetic.fill(db, MIDWEEK) == 15
    async with resources.sessionmaker() as db, db.begin():
        assert await synthetic.fill(db, MIDWEEK) == 0                                # topped up already
    joiners = [await make_user(resources) for _ in range(4)]                       # 1 + 15 + 4 = 20
    for uid in joiners:
        await earn(resources, uid, 10)
    assert {await league_of(resources, uid) for uid in joiners} == {await league_of(resources, first)}
    sixth = await make_user(resources)
    await earn(resources, sixth, 10)
    assert await league_of(resources, sixth) != await league_of(resources, first)    # the league is full (20)
    async with resources.sessionmaker() as db:
        sizes = Counter((await db.execute(select(LeagueMember.league_id))).scalars())
        seated = set((await db.execute(select(LeagueMember.user_id).join(User).where(
            User.is_synthetic.is_(True)))).scalars())
    assert sorted(sizes.values()) == [1, 20] and len(seated) == 15
    # XP for synthetic members: once per member per slot, the same on every run, in the ordinary ledger.
    busy = MIDWEEK.replace(hour=17, minute=10)                                       # 20:10 Riyadh
    granted = []
    for _ in range(2):
        async with resources.sessionmaker() as db, db.begin():
            granted.append(await synthetic.grant_xp(db, busy))
    assert granted[0] > 0 and granted[1] == 0
    slot = int(busy.timestamp()) // synthetic.SLOT_SECONDS
    expected = set()
    for m in synthetic.members():
        uid = synthetic.member_id(m["key"])
        award = synthetic.award_for(m, uid, slot, busy) if uid in seated else None
        if award is not None:
            expected.add((uid, award[1], str(slot)))
    async with resources.sessionmaker() as db:
        rows = set((await db.execute(select(XpEvent.user_id, XpEvent.xp, XpEvent.ref_id).where(
            XpEvent.ref_type == "synthetic_slot"))).all())
    assert rows == expected


async def test_synthetic_members_are_excluded_everywhere(resources: Resources) -> None:
    async with resources.sessionmaker() as db, db.begin():
        await synthetic.seed(db)
        member = await db.get(User, synthetic.member_id("member_01"))
        assert member is not None
        assert not friends.can_befriend(member) and not leagues.eligible(member)
        assert member.id not in set((await db.execute(_eligible())).scalars())     # metrics population


def test_production_refuses_synthetic_members() -> None:
    with pytest.raises(ValidationError, match="P-01"):
        Settings(app_env=Environment.production, synthetic_league_members=True, auth_token_pepper="p" * 32,
                 storage_signing_key="k" * 32, _env_file=None)  # type: ignore[call-arg, arg-type]
    staging = Settings(app_env=Environment.staging, synthetic_league_members=True, auth_token_pepper="p" * 32,
                       storage_signing_key="k" * 32, _env_file=None)  # type: ignore[call-arg, arg-type]
    assert staging.synthetic_league_members and not Settings(_env_file=None).synthetic_league_members  # type: ignore[call-arg]


def test_activity_profile_respects_active_hours() -> None:
    profile = {"weekly_xp": 10_000, "active_hours": [17, 22]}
    inside, outside = MIDWEEK.replace(hour=15), MIDWEEK.replace(hour=3)              # 18:00 / 06:00 Riyadh
    assert synthetic.award_for(profile, "usr_x", 1, inside) is not None              # chance capped at 1
    assert synthetic.award_for(profile, "usr_x", 1, outside) is None
    quiet = {"weekly_xp": 1, "active_hours": [17, 22]}
    hits = sum(synthetic.award_for(quiet, "usr_x", s, inside) is not None for s in range(2000))
    assert hits < 40
    assert xp.week_key(MIDWEEK + timedelta(minutes=30)) == xp.week_key(MIDWEEK)
