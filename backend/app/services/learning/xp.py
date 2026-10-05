"""XP grants (backend §10.1): one ``xp_events`` row per grant, unique per (user, reason, ref), so a retried or
concurrent request can never grant twice.

``week_key`` (backend §10.3) is the league week, which starts Sunday 00:00 Asia/Riyadh. It is written as the ISO
year-week of the Riyadh date shifted by one day, so Sunday through Saturday share one key (decision D-60).
``local_date`` is the learner's calendar day in their time zone at the moment of the grant; it is stored and
never recomputed after a time-zone change (backend §10.2).
"""

from __future__ import annotations

from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo

from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import User, XpEvent

LEAGUE_ZONE = ZoneInfo("Asia/Riyadh")
AMOUNTS = {"lesson_complete": 10, "lesson_perfect": 3, "recitation_passed": 3, "review_complete": 8,
           "pretest_complete": 5, "unit_test_passed": 20, "daily_goal_met": 2}


def week_key(at: datetime) -> str:
    shifted = at.astimezone(LEAGUE_ZONE).date() + timedelta(days=1)
    year, week, _ = shifted.isocalendar()
    return f"{year}-W{week:02d}"


def local_date(at: datetime, timezone: str) -> date:
    return at.astimezone(ZoneInfo(timezone)).date()


async def grant(db: AsyncSession, user: User, reason: str, xp: int, ref_type: str, ref_id: str,
                at: datetime, *, reward_key: str | None = None) -> bool:
    """Record a grant once; returns False when this (reason, ref) was already granted to the user.

    A learner's first XP of the week also places them in that week's league, in the same transaction
    (backend §10.3), whatever the XP source.
    """
    from app.services.community import leagues

    statement = pg_insert(XpEvent).values(
        user_id=user.id, reason=reason, xp=xp, ref_type=ref_type, ref_id=ref_id, week_key=week_key(at),
        local_date=local_date(at, user.timezone), created_at=at, reward_key=reward_key,
    ).on_conflict_do_nothing().returning(XpEvent.id)
    granted = (await db.execute(statement)).scalar_one_or_none() is not None
    if granted and xp > 0:
        await leagues.join(db, user, at)
    return granted
