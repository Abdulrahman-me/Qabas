"""Operational liveness/readiness probes. Not part of the public contract (excluded from OpenAPI)."""

from __future__ import annotations

import asyncio
from typing import Any

import asyncpg
import redis.asyncio as aioredis
from fastapi import APIRouter
from fastapi.responses import JSONResponse

from app.config import get_settings

router = APIRouter(prefix="/health", include_in_schema=False)
CHECK_TIMEOUT_S = 3.0


def asyncpg_dsn(sqlalchemy_url: str) -> str:
    """``postgresql+asyncpg://...`` (SQLAlchemy form) -> ``postgresql://...`` for asyncpg."""
    return sqlalchemy_url.replace("postgresql+asyncpg://", "postgresql://", 1)


async def _check_database() -> None:
    conn = await asyncpg.connect(asyncpg_dsn(get_settings().database_url), timeout=CHECK_TIMEOUT_S)
    try:
        await conn.fetchval("SELECT 1")
    finally:
        await conn.close()


async def _check_redis() -> None:
    client = aioredis.Redis.from_url(get_settings().redis_url, socket_timeout=CHECK_TIMEOUT_S)
    try:
        await client.ping()
    finally:
        await client.aclose()


@router.get("/live")
async def live() -> dict[str, str]:
    return {"status": "ok"}


@router.get("/ready")
async def ready() -> JSONResponse:
    checks: dict[str, Any] = {}
    for name, check in (("database", _check_database), ("redis", _check_redis)):
        try:
            await asyncio.wait_for(check(), CHECK_TIMEOUT_S + 1)
            checks[name] = "ok"
        except Exception as exc:  # report the failing dependency, never its connection string
            checks[name] = f"unavailable ({type(exc).__name__})"
    ok = all(v == "ok" for v in checks.values())
    return JSONResponse({"status": "ready" if ok else "unavailable", "checks": checks},
                        status_code=200 if ok else 503)
