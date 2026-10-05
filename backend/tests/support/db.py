"""Shared database test helpers (real native PostgreSQL ``qabas_test``)."""

from __future__ import annotations

from pathlib import Path
from typing import Any

import asyncpg
from alembic.config import Config
from sqlalchemy import text
from sqlalchemy.exc import DBAPIError
from sqlalchemy.ext.asyncio import AsyncConnection

from app.config import get_settings

BACKEND = Path(__file__).resolve().parents[2]

UNIQUE_VIOLATION = "23505"
CHECK_VIOLATION = "23514"
FK_VIOLATION = "23503"
NOT_NULL_VIOLATION = "23502"
IMMUTABLE = "QB001"
SET_ONCE = "QB002"
SESSION_GUARD = "QB003"
INSERT_ONLY = "QB004"
CURRENT_NOT_PUBLISHED = "QB005"


def resolve_test_database_url() -> str:
    settings = get_settings()
    url = settings.test_database_url or settings.database_url
    if not url.rstrip("/").rsplit("/", 1)[-1].endswith("_test"):
        raise RuntimeError(f"refusing to reset a non-test database: {url.rsplit('@', 1)[-1]}")
    return url


def asyncpg_url(url: str) -> str:
    return url.replace("postgresql+asyncpg://", "postgresql://", 1)


def alembic_config(url: str) -> Config:
    config = Config(str(BACKEND / "alembic.ini"))
    config.set_main_option("script_location", str(BACKEND / "migrations"))
    config.attributes["db_url"] = url
    return config


async def reset_schema(url: str) -> None:
    conn = await asyncpg.connect(asyncpg_url(url))
    try:
        await conn.execute("DROP SCHEMA IF EXISTS public CASCADE; CREATE SCHEMA public;")
    finally:
        await conn.close()


# Configuration rows inserted by migrations (registry snapshots) that every test expects to exist.
SEEDED_TABLES = frozenset({"league_tiers", "achievements"})


async def truncate_all(url: str) -> None:
    """Empty every application table that has rows (TRUNCATE fires no row triggers, so audit tables can
    be cleared), keeping the migration-seeded configuration. Probing first keeps per-test cleanup cheap when a
    test touched only a few tables."""
    conn = await asyncpg.connect(asyncpg_url(url))
    try:
        tables = [r["tablename"] for r in await conn.fetch(
            "SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename <> 'alembic_version'")
            if r["tablename"] not in SEEDED_TABLES]
        if not tables:
            return
        probe = " UNION ALL ".join(f"SELECT '{t}' AS t WHERE EXISTS (SELECT 1 FROM \"{t}\")" for t in tables)
        dirty = [r["t"] for r in await conn.fetch(probe)]
        if dirty:
            await conn.execute(f"TRUNCATE {', '.join(f'\"{t}\"' for t in dirty)} RESTART IDENTITY CASCADE")
    finally:
        await conn.close()


def sqlstate(exc: BaseException) -> str | None:
    """SQLSTATE of a database error raised through SQLAlchemy/asyncpg."""
    seen: list[BaseException] = []
    current: BaseException | None = exc
    while current is not None and current not in seen:
        seen.append(current)
        for attr in ("sqlstate", "pgcode"):
            value = getattr(current, attr, None)
            if isinstance(value, str):
                return value
        current = getattr(current, "orig", None) or current.__cause__
    return None


async def expect_sqlstate(conn: AsyncConnection, state: str, sql: str, params: dict[str, Any] | None = None) -> None:
    """Run ``sql`` in a savepoint and assert it fails with ``state``."""
    savepoint = await conn.begin_nested()
    try:
        await conn.execute(text(sql), params or {})
    except DBAPIError as exc:
        await savepoint.rollback()
        assert sqlstate(exc) == state, f"expected SQLSTATE {state}, got {sqlstate(exc)}: {exc.orig}"
        return
    await savepoint.rollback()
    raise AssertionError(f"expected SQLSTATE {state}, but the statement succeeded: {sql}")


async def run(conn: AsyncConnection, sql: str, params: dict[str, Any] | None = None) -> Any:
    return await conn.execute(text(sql), params or {})


CONTENT_TABLES = frozenset({
    "units", "curriculum_slots", "concepts", "lessons", "lesson_versions", "claims", "sentences", "exercises",
    "exercise_versions", "sources", "terms", "misconceptions", "scene_versions", "scene_assets", "alembic_version",
})


async def truncate_learner_state(url: str) -> None:
    """Empty every non-content table (users, sessions, learner state, platform rows), keeping the published
    curriculum, so one loaded curriculum serves many independent learner tests."""
    conn = await asyncpg.connect(asyncpg_url(url))
    try:
        # factory_runs is referenced by content (lesson_versions.run_id) and references users, so neither can be
        # truncated without the content: those two are emptied with DELETE after the other learner tables.
        kept = CONTENT_TABLES | SEEDED_TABLES | {"factory_runs", "users"}
        tables = [r["tablename"] for r in await conn.fetch(
            "SELECT tablename FROM pg_tables WHERE schemaname = 'public'") if r["tablename"] not in kept]
        if tables:
            await conn.execute(f"TRUNCATE {', '.join(f'\"{t}\"' for t in tables)} RESTART IDENTITY")
        await conn.execute("DELETE FROM factory_runs")
        await conn.execute("DELETE FROM users")
    finally:
        await conn.close()
