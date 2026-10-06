"""Weekly leagues (backend §10.3, API §6.9 ``GET /leagues/current``).

* **Week:** Sunday 00:00 → Saturday 23:59:59 Asia/Riyadh for everyone (``xp.week_key``, D-60).
* **Assignment:** a learner joins a league on their first XP of the week, from inside :func:`xp.grant`, so every
  XP source (finish, recitation, quests, later challenges) assigns in the same transaction as the grant. The
  league of (``week_key``, ``tier_key``) with fewer than :data:`LEAGUE_SIZE` members is chosen (or created) under
  a per-(week, tier) advisory lock, so concurrent first-XP events cannot overfill one; the database allows one
  league per learner per week.
* **Standings:** ``xp_week`` is the sum of the member's ``xp_events`` for the week; rank by ``xp_week`` desc,
  ties by the earlier last XP time (then by id, so the order is total and stable).
* **Promotion:** at week end the top ``promotion_zone_size`` ranks with XP move up one tier; no demotion; the top
  tier keeps its members. One ``league_promotions`` row per week makes the job idempotent; it runs from the beat
  job and, as a safety net, before the first assignment of a new week, so nobody is placed in the new week with
  last week's tier.
* **Privacy:** other learners see a ``private_profile`` member as the localized "Traveler" with the default avatar.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, time, timedelta

from sqlalchemy import and_, func, select, text, update
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.contract import models as C
from app.errors import ApiError, ErrorCode
from app.models import League, LeagueMember, LeaguePromotion, LeagueTier, LearnerTier, User, XpEvent
from app.registries import default_avatar_key, registries
from app.services.learning.xp import LEAGUE_ZONE, week_key
from app.services.users import iso

LEAGUE_SIZE = 20


# ------------------------------------------------------------------------------------------- weeks

def week_start(at: datetime) -> datetime:
    """Sunday 00:00 Asia/Riyadh of the league week containing ``at`` (timezone-aware)."""
    day = at.astimezone(LEAGUE_ZONE).date()
    sunday = day - timedelta(days=(day.weekday() + 1) % 7)
    return datetime.combine(sunday, time(), LEAGUE_ZONE)


def week_end(at: datetime) -> datetime:
    """The first instant of the next week (exclusive end)."""
    return week_start(at) + timedelta(days=7)


def previous_week_key(at: datetime) -> str:
    return week_key(week_start(at) - timedelta(seconds=1))


def league_id(key: str, tier_index: int, seq: int) -> str:
    year, week = key.split("-W")
    return f"lg_{year}w{week}_{tier_index}_{seq:02d}"


def eligible(user: User) -> bool:
    """Leagues are for learners; the challenge bot and deleted accounts never join, synthetic members are placed
    only by the synthetic fill (P-01)."""
    return user.role == "learner" and not user.is_bot and not user.is_synthetic and user.deleted_at is None


async def _xact_lock(db: AsyncSession, key: str) -> None:
    await db.execute(text("SELECT pg_advisory_xact_lock(hashtextextended(:k, 0))"), {"k": key})


# ------------------------------------------------------------------------------------------- tiers

async def tiers(db: AsyncSession) -> list[LeagueTier]:
    return list((await db.execute(select(LeagueTier).order_by(LeagueTier.index))).scalars())


async def tier_of(db: AsyncSession, user_id: str) -> LeagueTier:
    """The learner's tier; every learner starts at index 0 (the row is created on first use)."""
    first = (await db.execute(select(LeagueTier).order_by(LeagueTier.index).limit(1))).scalar_one()
    await db.execute(insert(LearnerTier).values(user_id=user_id, tier_key=first.tier_key)
                     .on_conflict_do_nothing(index_elements=[LearnerTier.user_id]))
    return (await db.execute(select(LeagueTier).join(LearnerTier, LearnerTier.tier_key == LeagueTier.tier_key)
                             .where(LearnerTier.user_id == user_id))).scalar_one()


# ------------------------------------------------------------------------------------------- assignment

async def join(db: AsyncSession, user: User, at: datetime) -> str | None:
    """Place ``user`` in a league for the week of ``at`` (no-op when already placed); returns the league id."""
    if not eligible(user):
        return None
    key = week_key(at)
    existing = await db.scalar(select(LeagueMember.league_id).where(LeagueMember.user_id == user.id,
                                                                    LeagueMember.week_key == key))
    if existing is not None:
        return existing
    await promote_pending(db, at)
    tier = await tier_of(db, user.id)
    await _xact_lock(db, f"league:{key}:{tier.tier_key}")
    members = (select(LeagueMember.league_id, func.count().label("n")).group_by(LeagueMember.league_id)
               .subquery())
    open_league = (await db.execute(
        select(League.id).outerjoin(members, members.c.league_id == League.id)
        .where(League.week_key == key, League.tier_key == tier.tier_key,
               func.coalesce(members.c.n, 0) < LEAGUE_SIZE)
        .order_by(League.seq).limit(1))).scalar_one_or_none()
    if open_league is None:
        seq = int(await db.scalar(select(func.coalesce(func.max(League.seq), 0)).where(
            League.week_key == key, League.tier_key == tier.tier_key)) or 0) + 1
        open_league = league_id(key, tier.index, seq)
        db.add(League(id=open_league, week_key=key, tier_key=tier.tier_key, seq=seq))
        await db.flush()
    placed = (await db.execute(insert(LeagueMember).values(league_id=open_league, user_id=user.id, week_key=key)
                               .on_conflict_do_nothing().returning(LeagueMember.league_id))).scalar_one_or_none()
    if placed is None:   # placed concurrently by another transaction of the same learner
        return await db.scalar(select(LeagueMember.league_id).where(LeagueMember.user_id == user.id,
                                                                    LeagueMember.week_key == key))
    return placed


# ------------------------------------------------------------------------------------------- standings

@dataclass(frozen=True)
class Standing:
    rank: int
    user: User
    xp_week: int


async def standings(db: AsyncSession, league: League) -> list[Standing]:
    rows = (await db.execute(
        select(User, func.coalesce(func.sum(XpEvent.xp), 0), func.max(XpEvent.created_at))
        .join(LeagueMember, LeagueMember.user_id == User.id)
        .outerjoin(XpEvent, and_(XpEvent.user_id == User.id, XpEvent.week_key == LeagueMember.week_key))
        .where(LeagueMember.league_id == league.id, User.deleted_at.is_(None))
        .group_by(User.id))).all()
    never = datetime.max.replace(tzinfo=LEAGUE_ZONE)
    ordered = sorted(rows, key=lambda r: (-int(r[1]), r[2] or never, r[0].id))
    return [Standing(rank=i, user=row[0], xp_week=int(row[1])) for i, row in enumerate(ordered, start=1)]


def in_zone(standing: Standing, tier: LeagueTier) -> bool:
    """Promotion zone: the top ``promotion_zone_size`` ranks that earned XP; the top tier has no promotion."""
    return not tier.is_top_tier and standing.rank <= tier.promotion_zone_size and standing.xp_week > 0


async def membership(db: AsyncSession, user_id: str, at: datetime) -> League | None:
    return (await db.execute(select(League).join(LeagueMember, LeagueMember.league_id == League.id).where(
        LeagueMember.user_id == user_id, LeagueMember.week_key == week_key(at)))).scalar_one_or_none()


def no_league() -> ApiError:
    return ApiError(ErrorCode.not_found, "No league yet this week; earn XP to join one.",
                    {"reason": "no_league_this_week"})


async def current(db: AsyncSession, user: User, lang: str, now: datetime) -> C.League:
    league = await membership(db, user.id, now)
    if league is None:
        raise no_league()
    tier = await db.get(LeagueTier, league.tier_key)
    assert tier is not None
    ranked = await standings(db, league)
    mine = next((s for s in ranked if s.user.id == user.id), None)
    if mine is None:
        raise no_league()
    masked = registries()["private_member"][lang]
    members = []
    for standing in ranked:
        me = standing.user.id == user.id
        public = me or not standing.user.private_profile
        name = standing.user.display_name if public else masked
        if standing.user.is_synthetic:
            # Revision 10 has no synthetic flag: disclose within the existing display_name,
            # including masked profiles. Never make simulated activity look like a real learner.
            label = registries()["training_opponent"][lang]
            name = f"{name} · {label}"
        members.append(C.LeagueMember(
            rank=standing.rank, user_id=standing.user.id,
            display_name=name, xp_week=standing.xp_week, is_me=me,
            avatar_key=standing.user.avatar_key if public else default_avatar_key(),
            in_promotion_zone=in_zone(standing, tier)))
    start, end = week_start(now), week_end(now)
    return C.League(league_id=league.id, week_start=iso(start), week_end=iso(end - timedelta(seconds=1)),
                    ends_in_seconds=max(0, int((end - now).total_seconds())), my_rank=mine.rank,
                    tier=C.Tier(tier_key=tier.tier_key, index=tier.index, name=tier.name[lang],
                                is_top_tier=tier.is_top_tier),
                    promotion_zone_size=tier.promotion_zone_size, demotion=False, members=members)


async def stats_league(db: AsyncSession, user: User, now: datetime) -> C.StatsLeague | None:
    """``/me/stats`` ``league``: null until the learner's first XP of the week."""
    league = await membership(db, user.id, now)
    if league is None:
        return None
    ranked = await standings(db, league)
    mine = next((s for s in ranked if s.user.id == user.id), None)
    return None if mine is None else C.StatsLeague(league_id=league.id, rank=mine.rank, size=len(ranked))


# ------------------------------------------------------------------------------------------- promotion

async def promote_week(db: AsyncSession, key: str, now: datetime) -> int | None:
    """Apply the week-end promotion of ``key`` once; returns the number promoted, or None if already applied.

    The caller holds the promotion lock (:func:`promote_pending`)."""
    if await db.get(LeaguePromotion, key) is not None:
        return None
    ordered = await tiers(db)
    by_key = {t.tier_key: t for t in ordered}
    promoted = 0
    for league in (await db.execute(select(League).where(League.week_key == key).order_by(League.id))).scalars():
        tier = by_key[league.tier_key]
        if tier.is_top_tier:
            continue
        upper = next(t for t in ordered if t.index > tier.index)
        for standing in await standings(db, league):
            if not in_zone(standing, tier) or not eligible(standing.user):
                continue
            result = await db.execute(update(LearnerTier).where(
                LearnerTier.user_id == standing.user.id, LearnerTier.tier_key == tier.tier_key).values(
                tier_key=upper.tier_key, promoted_at=now, promoted_week_key=key))
            promoted += int(result.rowcount or 0)  # type: ignore[attr-defined]
    db.add(LeaguePromotion(week_key=key, completed_at=now, promoted=promoted))
    await db.flush()
    return promoted


async def promote_pending(db: AsyncSession, at: datetime) -> dict[str, int]:
    """Promote every ended week that has leagues and no promotion record, oldest first (idempotent)."""
    current_key = week_key(at)
    pending = select(League.week_key).where(
        League.week_key < current_key,
        ~select(LeaguePromotion.week_key).where(LeaguePromotion.week_key == League.week_key).exists()).distinct()
    if (await db.execute(pending.limit(1))).first() is None:
        return {}
    await _xact_lock(db, "league-promotion")
    done: dict[str, int] = {}
    for key in sorted((await db.execute(pending)).scalars()):
        count = await promote_week(db, key, at)
        if count is not None:
            done[key] = count
    return done
