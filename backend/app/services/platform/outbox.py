"""Transactional outbox and relay (AD-11, AD-24).

Producers call :func:`enqueue` inside the transaction that causes the effect, so an event exists
exactly when its cause committed. Only effects a response does not report go through the outbox
(achievements, league standings, metrics, memory cleanup, account purge).

The relay claims one due event at a time with ``FOR UPDATE SKIP LOCKED`` (many relays can run
concurrently without double-processing), runs its consumer in the same transaction and marks it
processed. A failing consumer is rolled back to a savepoint, and the event is retried with
exponential backoff. Consumers make each effect idempotent with :func:`apply_effect`, so
redelivery after a crash is harmless.
"""

from __future__ import annotations

import logging
from collections.abc import Awaitable, Callable
from datetime import datetime, timedelta
from typing import Any

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.models import EffectLedger, OutboxEvent
from app.services.platform.auth_sessions import utcnow

log = logging.getLogger("qabas.outbox")

Consumer = Callable[[AsyncSession, OutboxEvent], Awaitable[None]]
CONSUMERS: dict[str, Consumer] = {}

MAX_BACKOFF = timedelta(hours=1)


def consumer(kind: str) -> Callable[[Consumer], Consumer]:
    """Register the consumer for an event kind (one consumer per kind)."""

    def register(func: Consumer) -> Consumer:
        if kind in CONSUMERS and CONSUMERS[kind] is not func:
            raise RuntimeError(f"duplicate outbox consumer for {kind}")
        CONSUMERS[kind] = func
        return func

    return register


async def enqueue(db: AsyncSession, *, event_key: str, kind: str, payload: dict[str, Any],
                  available_at: datetime | None = None) -> bool:
    """Write an event in the caller's transaction. Re-enqueueing the same key is a no-op."""
    values: dict[str, Any] = {"event_key": event_key, "kind": kind, "payload": payload}
    if available_at is not None:
        values["available_at"] = available_at
    result = await db.execute(insert(OutboxEvent).values(**values).on_conflict_do_nothing(
        index_elements=[OutboxEvent.event_key]))
    return bool(result.rowcount)  # type: ignore[attr-defined]


async def apply_effect(db: AsyncSession, *, effect_key: str, event_key: str) -> bool:
    """Claim an effect; True the first time (apply it now), False if it was already applied."""
    result = await db.execute(insert(EffectLedger).values(effect_key=effect_key, event_key=event_key)
                              .on_conflict_do_nothing(index_elements=[EffectLedger.effect_key]))
    return bool(result.rowcount)  # type: ignore[attr-defined]


def backoff(attempts: int) -> timedelta:
    return min(timedelta(seconds=2 ** min(attempts, 12)), MAX_BACKOFF)


async def relay_one(sessionmaker: async_sessionmaker[AsyncSession]) -> bool:
    """Process one due event; returns False when nothing is due."""
    async with sessionmaker() as db, db.begin():
        now = utcnow()
        event = (await db.execute(
            select(OutboxEvent)
            .where(OutboxEvent.processed_at.is_(None), OutboxEvent.available_at <= now)
            .order_by(OutboxEvent.available_at, OutboxEvent.id)
            .limit(1).with_for_update(skip_locked=True)
        )).scalar_one_or_none()
        if event is None:
            return False
        handler = CONSUMERS.get(event.kind)
        try:
            if handler is None:
                raise LookupError(f"no consumer registered for {event.kind!r}")
            async with db.begin_nested():
                await handler(db, event)
        except Exception as exc:
            event.attempts += 1
            event.available_at = now + backoff(event.attempts)
            event.last_error = f"{type(exc).__name__}: {exc}"[:2000]
            log.warning("outbox event failed", extra={"event_key": event.event_key, "kind": event.kind,
                                                      "attempts": event.attempts})
            return True
        event.processed_at = utcnow()
        return True


async def relay(sessionmaker: async_sessionmaker[AsyncSession], *, max_events: int = 500) -> int:
    """Drain due events (bounded per run); returns how many were processed or retried."""
    count = 0
    while count < max_events and await relay_one(sessionmaker):
        count += 1
    return count
