"""Helpers for community tests: synthetic learners created directly and XP granted through the real ledger."""

from __future__ import annotations

from datetime import UTC, datetime
from typing import Any

from sqlalchemy import select

from app.db.ids import new_id
from app.models import LeagueMember, User
from app.runtime import Resources
from app.services.learning import xp

# Wednesday 2026-10-07 12:00 Asia/Riyadh: inside the league week that starts Sunday 2026-10-04 00:00 Riyadh.
MIDWEEK = datetime(2026, 10, 7, 9, 0, tzinfo=UTC)


async def make_user(resources: Resources, **fields: Any) -> str:
    values: dict[str, Any] = {"display_name": "Seeker 7", "avatar_key": "traveler_03", "role": "learner",
                              "language": "en", "track": "explorer", "daily_goal_minutes": 10,
                              "timezone": "Asia/Riyadh", "onboarding_completed": True, "private_profile": False}
    values.update(fields)
    user_id = values.pop("id", None) or new_id("usr")
    async with resources.sessionmaker() as db, db.begin():
        db.add(User(id=user_id, **values))
    return str(user_id)


async def earn(resources: Resources, user_id: str, amount: int, at: datetime = MIDWEEK, *,
               ref: str | None = None) -> bool:
    """One ``lesson_complete`` grant of ``amount`` XP through :func:`xp.grant` (which assigns the league)."""
    async with resources.sessionmaker() as db, db.begin():
        user = await db.get(User, user_id)
        assert user is not None
        return await xp.grant(db, user, "lesson_complete", amount, "test", ref or new_id("ses"), at)


async def league_of(resources: Resources, user_id: str, at: datetime = MIDWEEK) -> str | None:
    async with resources.sessionmaker() as db:
        return await db.scalar(select(LeagueMember.league_id).where(
            LeagueMember.user_id == user_id, LeagueMember.week_key == xp.week_key(at)))



async def signed_in(resources: Resources, **fields: Any) -> tuple[str, dict[str, str]]:
    """A learner with a real auth session (avoids the per-address guest sign-up limit in bulk tests)."""
    from app.services.platform import auth_sessions

    uid = await make_user(resources, **fields)
    async with resources.sessionmaker() as db, db.begin():
        user = await db.get(User, uid)
        assert user is not None
        token = await auth_sessions.create_session(db, resources.settings, user)
    return uid, {"Authorization": f"Bearer {token}"}
