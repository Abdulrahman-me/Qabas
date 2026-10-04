"""Direct database helpers for API tests (synthetic data only)."""

from __future__ import annotations

import asyncio
import json
from typing import Any

import asyncpg

from tests.support.db import asyncpg_url


async def aquery(url: str, sql: str, *args: Any) -> list[asyncpg.Record]:
    """For async tests (already inside the event loop)."""
    conn = await asyncpg.connect(asyncpg_url(url))
    try:
        return list(await conn.fetch(sql, *args))
    finally:
        await conn.close()


async def aexecute(url: str, sql: str, *args: Any) -> None:
    await aquery(url, sql, *args)


def query(url: str, sql: str, *args: Any) -> list[asyncpg.Record]:
    """For synchronous tests (TestClient-based)."""
    return asyncio.run(aquery(url, sql, *args))


def execute(url: str, sql: str, *args: Any) -> None:
    query(url, sql, *args)


def execute_many(url: str, statements: list[tuple[str, tuple[Any, ...]]]) -> None:
    """Several statements over one connection, in one transaction."""

    async def main() -> None:
        conn = await asyncpg.connect(asyncpg_url(url))
        try:
            async with conn.transaction():
                for sql, args in statements:
                    await conn.execute(sql, *args)
        finally:
            await conn.close()

    asyncio.run(main())


def seed_units(url: str, *, unit0_coming_soon: bool = False, unit1_coming_soon: bool = False) -> None:
    """Unit 0 (Explorer-only) and Unit 1 (shared), as in the curriculum structure."""
    title = json.dumps({"ar": {"explorer": "وحدة"}, "en": {"explorer": "Unit"}})
    for unit_id, index, tracks, soon in (("unit_0", 0, ["explorer"], unit0_coming_soon),
                                         ("unit_1", 1, ["explorer", "new_muslim"], unit1_coming_soon)):
        execute(url, "INSERT INTO units (id, index, title, subtitle, tracks, coming_soon) "
                     "VALUES ($1, $2, $3::jsonb, $3::jsonb, $4, $5)", unit_id, index, title, tracks, soon)


def onboarding_body(**overrides: Any) -> dict[str, Any]:
    return {"track_choice": "undisclosed", "language": "ar", "familiarity": None, "daily_goal_minutes": 10,
            "private_profile": True, "goal_anchor": None, **overrides}


def bearer(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}
