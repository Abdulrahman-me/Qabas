"""Serialize a learner's reward/activity writes without changing the session-first row lock order."""

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession


async def learner_lock(db: AsyncSession, user_id: str) -> None:
    await db.execute(text("SELECT pg_advisory_xact_lock(hashtextextended(:key, 0))"),
                     {"key": f"learning:{user_id}"})
