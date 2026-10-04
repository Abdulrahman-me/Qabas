"""Operational liveness/readiness probes. Not part of the public contract (excluded from OpenAPI)."""

from __future__ import annotations

import asyncio
from typing import Any

from fastapi import APIRouter
from fastapi.responses import JSONResponse
from sqlalchemy import text

from app.api.deps import ResourcesDep

router = APIRouter(prefix="/health", include_in_schema=False)
CHECK_TIMEOUT_S = 3.0


@router.get("/live")
async def live() -> dict[str, str]:
    return {"status": "ok"}


@router.get("/ready")
async def ready(resources: ResourcesDep) -> JSONResponse:
    async def database() -> None:
        async with resources.engine.connect() as conn:
            await conn.execute(text("SELECT 1"))

    async def redis() -> None:
        await resources.redis.ping()

    checks: dict[str, Any] = {}
    for name, check in (("database", database), ("redis", redis)):
        try:
            await asyncio.wait_for(check(), CHECK_TIMEOUT_S)
            checks[name] = "ok"
        except Exception as exc:  # report the failing dependency, never its connection string
            checks[name] = f"unavailable ({type(exc).__name__})"
    ok = all(v == "ok" for v in checks.values())
    return JSONResponse({"status": "ready" if ok else "unavailable", "checks": checks},
                        status_code=200 if ok else 503)
