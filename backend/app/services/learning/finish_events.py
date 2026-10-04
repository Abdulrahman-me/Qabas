"""The ``session.finished`` outbox consumer (backend "Transactions and effects", AD-11, AD-24).

A finish reports its own effects (score, XP, streak, quests, FSRS, terms, unlocks) synchronously. The event
carries only the effects the response does not report: achievements (Phase 18), league standings (Phase 18)
and metrics aggregates (Phase 15). Those phases register a *subscriber* here; this consumer fans the event
out, and each subscriber claims its own effect key, so redelivery or a crash mid-way never applies an effect
twice.

Until a subscriber exists the event completes without work (decision D-77). Nothing is lost: achievement
counters, league XP and metrics are derived from authoritative tables (``learner_lessons``, ``xp_events``,
``sessions``, ...; backend §10.3, §10.7), so a subscriber introduced later backfills from those tables
instead of depending on old events. Without this consumer every finish event would fail and be retried
forever.
"""

from __future__ import annotations

from collections.abc import Awaitable, Callable

from sqlalchemy.ext.asyncio import AsyncSession

from app.models import OutboxEvent
from app.services.platform import outbox

KIND = "session.finished"
Subscriber = Callable[[AsyncSession, OutboxEvent], Awaitable[None]]
SUBSCRIBERS: dict[str, Subscriber] = {}


def subscriber(name: str) -> Callable[[Subscriber], Subscriber]:
    """Register a downstream effect of a finished session under a stable name (its effect-key prefix)."""

    def register(func: Subscriber) -> Subscriber:
        if name in SUBSCRIBERS and SUBSCRIBERS[name] is not func:
            raise RuntimeError(f"duplicate session.finished subscriber {name}")
        SUBSCRIBERS[name] = func
        return func

    return register


@outbox.consumer(KIND)
async def dispatch(db: AsyncSession, event: OutboxEvent) -> None:
    for name in sorted(SUBSCRIBERS):
        if await outbox.apply_effect(db, effect_key=f"{name}:{event.event_key}", event_key=event.event_key):
            await SUBSCRIBERS[name](db, event)
