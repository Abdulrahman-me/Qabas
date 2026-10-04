"""Alembic environment (async engine). Migrations are forward-only expand/contract steps (data model)."""

from __future__ import annotations

import asyncio

from alembic import context
from sqlalchemy.engine import Connection

import app.models  # noqa: F401  (registers every table)
from app.config import get_settings
from app.db.base import Base
from app.db.engine import make_engine

config = context.config
target_metadata = Base.metadata


def database_url() -> str:
    x_args = context.get_x_argument(as_dictionary=True)
    return x_args.get("db_url") or config.attributes.get("db_url") or get_settings().database_url


def run_migrations_offline() -> None:
    context.configure(url=database_url(), target_metadata=target_metadata, literal_binds=True,
                      compare_type=True, transaction_per_migration=True)
    with context.begin_transaction():
        context.run_migrations()


def _run(connection: Connection) -> None:
    context.configure(connection=connection, target_metadata=target_metadata, compare_type=True,
                      transaction_per_migration=True)
    with context.begin_transaction():
        context.run_migrations()


async def run_migrations_online() -> None:
    engine = make_engine(database_url())
    async with engine.connect() as connection:
        # Fail fast instead of queueing behind application locks during a deploy.
        await connection.exec_driver_sql("SET lock_timeout = '5s'")
        await connection.run_sync(_run)
        await connection.commit()
    await engine.dispose()


if context.is_offline_mode():
    run_migrations_offline()
else:
    asyncio.run(run_migrations_online())
