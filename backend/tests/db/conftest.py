"""Database tests on the real native PostgreSQL ``qabas_test`` database.

Session setup: drop and recreate the ``public`` schema, then migrate base -> head -> base -> head
(a downgrade/upgrade round trip on every run). Each test runs in a transaction that is rolled back;
expected failures run inside savepoints so the test can continue.
"""

from __future__ import annotations

import asyncio
from collections.abc import AsyncIterator, Iterator
from pathlib import Path
from typing import Any

import asyncpg
import pytest
from alembic import command
from alembic.config import Config
from sqlalchemy import text
from sqlalchemy.exc import DBAPIError
from sqlalchemy.ext.asyncio import AsyncConnection, AsyncEngine, AsyncSession

from app.config import get_settings
from app.db.engine import make_engine

pytestmark = pytest.mark.integration
BACKEND = Path(__file__).resolve().parents[2]


def resolve_test_database_url() -> str:
    settings = get_settings()
    url = settings.test_database_url or settings.database_url
    if not url.rstrip("/").rsplit("/", 1)[-1].endswith("_test"):
        raise RuntimeError(f"refusing to reset a non-test database: {url.rsplit('@', 1)[-1]}")
    return url


def alembic_config(url: str) -> Config:
    config = Config(str(BACKEND / "alembic.ini"))
    config.set_main_option("script_location", str(BACKEND / "migrations"))
    config.attributes["db_url"] = url
    return config


async def _reset_schema(url: str) -> None:
    conn = await asyncpg.connect(url.replace("postgresql+asyncpg://", "postgresql://", 1))
    try:
        await conn.execute("DROP SCHEMA IF EXISTS public CASCADE; CREATE SCHEMA public;")
    finally:
        await conn.close()


@pytest.fixture(scope="session")
def migrated_url() -> Iterator[str]:
    url = resolve_test_database_url()
    asyncio.run(_reset_schema(url))
    config = alembic_config(url)
    command.upgrade(config, "head")
    command.downgrade(config, "base")
    command.upgrade(config, "head")
    yield url


@pytest.fixture(scope="session")
async def engine(migrated_url: str) -> AsyncIterator[AsyncEngine]:
    eng = make_engine(migrated_url)
    yield eng
    await eng.dispose()


@pytest.fixture
async def conn(engine: AsyncEngine) -> AsyncIterator[AsyncConnection]:
    async with engine.connect() as connection:
        transaction = await connection.begin()
        try:
            yield connection
        finally:
            await transaction.rollback()


@pytest.fixture
async def session(conn: AsyncConnection) -> AsyncIterator[AsyncSession]:
    async with AsyncSession(bind=conn, join_transaction_mode="create_savepoint", expire_on_commit=False) as s:
        yield s


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


UNIQUE_VIOLATION = "23505"
CHECK_VIOLATION = "23514"
FK_VIOLATION = "23503"
NOT_NULL_VIOLATION = "23502"
IMMUTABLE = "QB001"
SET_ONCE = "QB002"
SESSION_GUARD = "QB003"
INSERT_ONLY = "QB004"
CURRENT_NOT_PUBLISHED = "QB005"
