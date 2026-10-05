"""Synthetic league members (backend §10.3, SEED_AND_IMPORT §15), only where ``SYNTHETIC_LEAGUE_MEMBERS=true``.

Production use is the open product decision P-01; the setting is refused in production (``app.config``). The 60
members of ``content/synthetic_league_members.json`` are seeded by ``scripts/seed.py`` as ``is_synthetic`` users
(no credentials, so they can never sign in, accept invites or be befriended) and are excluded from metrics and
achievements. The beat job (``community.synthetic_leagues``):

* fills each league of the current week with up to :data:`PER_LEAGUE` synthetic members, keeping
  ``LEAGUE_SIZE - PER_LEAGUE`` seats for learners (60 members = 15 for each of the four tiers' first leagues),
  under the same per-(week, tier) lock as learner assignment;
* grants their XP through the ordinary XP ledger, at most once per 30-minute slot per member (unique reference),
  following each member's weekly XP and active Asia/Riyadh hours, deterministically from (member, slot).
"""

from __future__ import annotations

import hashlib
import json
from datetime import datetime
from functools import cache
from pathlib import Path
from typing import Any

from sqlalchemy import func, select, text
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.ids import CROCKFORD
from app.models import League, LeagueMember, LeagueTier, User
from app.services.community.leagues import LEAGUE_SIZE
from app.services.learning import xp

MEMBERS_PATH = Path(__file__).resolve().parents[3] / "content" / "synthetic_league_members.json"
PER_LEAGUE = 15
SLOT_SECONDS = 1800
AWARDS = (("lesson_complete", 10), ("review_complete", 8))


@cache
def members() -> tuple[dict[str, Any], ...]:
    data: dict[str, Any] = json.loads(MEMBERS_PATH.read_text(encoding="utf-8"))
    return tuple(data["members"])


def member_id(key: str) -> str:
    """A stable ``usr_`` id per member key, so re-seeding updates instead of duplicating."""
    value = int.from_bytes(hashlib.sha256(f"qabas-synthetic-member:{key}".encode()).digest()[:17], "big")
    chars = []
    for _ in range(26):
        value, rem = divmod(value, 32)
        chars.append(CROCKFORD[rem])
    return "usr_" + "".join(chars)


@cache
def profiles() -> dict[str, dict[str, Any]]:
    return {member_id(m["key"]): m for m in members()}


async def seed(db: AsyncSession) -> int:
    """Create or update the synthetic members (idempotent). Never touches a non-synthetic user."""
    for m in members():
        values = {"display_name": m["display_name"], "avatar_key": m["avatar_key"], "language": m["language"],
                  "private_profile": m["private_profile"]}
        statement = insert(User).values(
            id=member_id(m["key"]), role="learner", track="explorer", daily_goal_minutes=10, timezone="Asia/Riyadh",
            onboarding_completed=True, is_synthetic=True, **values)
        await db.execute(statement.on_conflict_do_update(index_elements=[User.id], set_=values,
                                                         where=User.is_synthetic.is_(True)))
    return len(members())


def _unit(*parts: object) -> float:
    digest = hashlib.sha256(":".join(str(p) for p in parts).encode()).digest()
    return int.from_bytes(digest[:8], "big") / 2**64


def award_for(profile: dict[str, Any], user_id: str, slot: int, at: datetime) -> tuple[str, int] | None:
    """The XP this member earns in ``slot`` (None when inactive), deterministic from (member, slot)."""
    start, end = profile["active_hours"]
    if not start <= at.astimezone(xp.LEAGUE_ZONE).hour < end:
        return None
    active_slots_per_week = 7 * (end - start) * 3600 // SLOT_SECONDS
    average = sum(amount for _, amount in AWARDS) / len(AWARDS)
    chance = min(1.0, profile["weekly_xp"] / (average * active_slots_per_week))
    if _unit(user_id, slot, "active") >= chance:
        return None
    return AWARDS[int(_unit(user_id, slot, "kind") * len(AWARDS))]


async def fill(db: AsyncSession, now: datetime) -> int:
    key = xp.week_key(now)
    added = 0
    leagues = (await db.execute(select(League, LeagueTier.tier_key).join(LeagueTier).where(League.week_key == key)
                                .order_by(LeagueTier.index, League.seq))).all()
    for league, tier_key in leagues:
        await db.execute(text("SELECT pg_advisory_xact_lock(hashtextextended(:k, 0))"),
                         {"k": f"league:{key}:{tier_key}"})
        total, synthetic = (await db.execute(
            select(func.count(), func.count().filter(User.is_synthetic)).select_from(LeagueMember)
            .join(User, User.id == LeagueMember.user_id).where(LeagueMember.league_id == league.id))).one()
        need = min(PER_LEAGUE - int(synthetic), LEAGUE_SIZE - int(total))
        if need <= 0:
            continue
        placed = select(LeagueMember.user_id).where(LeagueMember.week_key == key)
        free = (await db.execute(
            select(User.id).where(User.is_synthetic.is_(True), User.deleted_at.is_(None), User.id.not_in(placed))
            .order_by(func.md5(User.id + key)).limit(need))).scalars().all()
        for user_id in free:
            await db.execute(insert(LeagueMember).values(league_id=league.id, user_id=user_id, week_key=key)
                             .on_conflict_do_nothing())
        added += len(free)
    return added


async def grant_xp(db: AsyncSession, now: datetime) -> int:
    slot = int(now.timestamp()) // SLOT_SECONDS
    seated = (await db.execute(select(User).join(LeagueMember, LeagueMember.user_id == User.id).where(
        LeagueMember.week_key == xp.week_key(now), User.is_synthetic.is_(True),
        User.deleted_at.is_(None)))).scalars().all()
    granted = 0
    for user in seated:
        profile = profiles().get(user.id)
        award = award_for(profile, user.id, slot, now) if profile else None
        if award is not None and await xp.grant(db, user, award[0], award[1], "synthetic_slot", str(slot), now):
            granted += 1
    return granted
