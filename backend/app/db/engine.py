"""Async engine and session factory."""

from __future__ import annotations

from collections.abc import AsyncIterator
from functools import lru_cache

from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession, async_sessionmaker, create_async_engine

from app.config import get_settings


def make_engine(url: str, **kwargs: object) -> AsyncEngine:
    return create_async_engine(
        url,
        pool_pre_ping=True,
        connect_args={"server_settings": {"application_name": "qabas", "timezone": "UTC"}},
        **kwargs,
    )


@lru_cache
def get_engine() -> AsyncEngine:
    return make_engine(get_settings().database_url)


@lru_cache
def get_sessionmaker() -> async_sessionmaker[AsyncSession]:
    return async_sessionmaker(get_engine(), expire_on_commit=False)


async def db_session() -> AsyncIterator[AsyncSession]:
    """FastAPI dependency: one session per request; callers commit explicitly."""
    async with get_sessionmaker()() as session:
        yield session
