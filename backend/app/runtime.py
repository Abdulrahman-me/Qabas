"""Per-process resources (database engine, Redis, object storage), created in the app lifespan.

Created inside the running event loop and disposed on shutdown, so pooled connections never
cross event loops (one API process, one test client, one worker task each get their own).
"""

from __future__ import annotations

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from dataclasses import dataclass

import redis.asyncio as aioredis
from fastapi import FastAPI
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession, async_sessionmaker

from app.config import Settings
from app.db.engine import make_engine
from app.services.platform import deletion
from app.services.platform.storage import ObjectStorage, build_storage


@dataclass
class Resources:
    settings: Settings
    engine: AsyncEngine
    sessionmaker: async_sessionmaker[AsyncSession]
    redis: aioredis.Redis
    storage: ObjectStorage

    @classmethod
    def create(cls, settings: Settings, **engine_kwargs: object) -> Resources:
        engine = make_engine(settings.database_url, **engine_kwargs)
        return cls(
            settings=settings,
            engine=engine,
            sessionmaker=async_sessionmaker(engine, expire_on_commit=False),
            redis=aioredis.Redis.from_url(settings.redis_url, decode_responses=False),
            storage=build_storage(settings),
        )

    async def close(self) -> None:
        await self.redis.aclose()
        await self.engine.dispose()


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    resources = Resources.create(app.state.settings)
    app.state.resources = resources
    deletion.configure_storage(resources.storage)
    try:
        yield
    finally:
        await resources.close()


def redis_key(settings: Settings, *parts: str) -> str:
    return ":".join((settings.redis_key_prefix, *parts))
