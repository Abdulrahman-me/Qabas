"""``Idempotency-Key`` handling for creates (API §3.2, backend §5.2, AD-25).

The key row is written in the same transaction as the create it protects:

1. A transaction-scoped advisory lock on (user, key) serializes concurrent duplicates: the second
   request waits until the first commits or rolls back.
2. A stored, unexpired row with the same request fingerprint replays its response (same status).
   The same key with a different fingerprint is ``409 idempotency_conflict``.
3. Otherwise the create runs and its response is stored with the key, then everything commits.
   A failed create stores nothing, so the client can retry with the same key.
"""

from __future__ import annotations

import hashlib
import json
import uuid
from collections.abc import Awaitable, Callable
from dataclasses import dataclass
from datetime import timedelta
from typing import Any

from sqlalchemy import delete, func, select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.errors import ApiError, ErrorCode
from app.models import IdempotencyKey
from app.services.platform.auth_sessions import utcnow

HEADER = "Idempotency-Key"


@dataclass(frozen=True)
class StoredResponse:
    status: int
    body: dict[str, Any]
    replayed: bool


def parse_key(raw: str | None, *, required: bool) -> str | None:
    """Validate the header: a UUID (v4 recommended, API §3.2)."""
    if raw is None or not raw.strip():
        if required:
            raise ApiError(ErrorCode.validation_error, f"{HEADER} header is required.", {"field": HEADER})
        return None
    try:
        return str(uuid.UUID(raw.strip()))
    except ValueError:
        raise ApiError(ErrorCode.validation_error, f"{HEADER} must be a UUID.", {"field": HEADER}) from None


def fingerprint(method: str, path: str, body: Any) -> str:
    """Stable digest of the request: method, path and canonical JSON body (or multipart digest)."""
    canonical = json.dumps(body, sort_keys=True, separators=(",", ":"), ensure_ascii=False, default=str)
    return hashlib.sha256(f"{method.upper()}\n{path}\n{canonical}".encode()).hexdigest()


async def run_idempotent(
    db: AsyncSession,
    *,
    user_id: str,
    key: str,
    request_hash: str,
    ttl: timedelta,
    create: Callable[[], Awaitable[tuple[int, dict[str, Any]]]],
) -> StoredResponse:
    """Run ``create`` at most once per (user, key) within ``ttl``; ``create`` must not commit."""
    async with db.begin():
        await db.execute(text("SELECT pg_advisory_xact_lock(hashtextextended(:k, 0))"),
                         {"k": f"idem:{user_id}:{key}"})
        stored = (await db.execute(
            select(IdempotencyKey).where(IdempotencyKey.user_id == user_id, IdempotencyKey.key == key)
        )).scalar_one_or_none()
        if stored is not None and stored.created_at > utcnow() - ttl:
            if stored.request_hash != request_hash:
                raise ApiError(ErrorCode.idempotency_conflict,
                               "This Idempotency-Key was already used for a different request.")
            return StoredResponse(stored.response_status, stored.response_body, replayed=True)
        if stored is not None:  # expired: the key may be reused
            await db.delete(stored)
            await db.flush()
        status, body = await create()
        db.add(IdempotencyKey(user_id=user_id, key=key, request_hash=request_hash, response_status=status,
                              response_body=body))
    return StoredResponse(status, body, replayed=False)


async def purge_expired(db: AsyncSession, ttl: timedelta) -> int:
    result = await db.execute(delete(IdempotencyKey).where(IdempotencyKey.created_at < func.now() - ttl))
    return int(result.rowcount or 0)  # type: ignore[attr-defined]
