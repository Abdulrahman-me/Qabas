"""Maintenance queue: outbox relay, account purge (via the relay), expiry and cleanup jobs."""

from __future__ import annotations

import asyncio
from collections.abc import Awaitable, Callable
from datetime import timedelta

from sqlalchemy.pool import NullPool

from app.config import get_settings
from app.raqeeb import worker as raqeeb_worker
from app.runtime import Resources
from app.services import metrics
from app.services.learning import finish_events
from app.services.platform import auth_sessions, deletion, idempotency, outbox
from app.workers.celery_app import celery_app

# Importing a consumer module registers its outbox consumers with the relay.
CONSUMER_MODULES = (deletion, finish_events, metrics, raqeeb_worker)


def run_with_resources[T](job: Callable[[Resources], Awaitable[T]]) -> T:
    """Run an async job with resources created (and disposed) in this task's own event loop."""

    async def main() -> T:
        resources = Resources.create(get_settings(), poolclass=NullPool)
        deletion.configure_storage(resources.storage)
        try:
            return await job(resources)
        finally:
            await resources.close()

    return asyncio.run(main())


@celery_app.task(name="maintenance.ping")
def ping() -> str:
    """Worker liveness probe used by tests and operators."""
    return "pong"


@celery_app.task(name="maintenance.outbox_relay")
def outbox_relay() -> int:
    return run_with_resources(lambda r: outbox.relay(r.sessionmaker))


@celery_app.task(name="maintenance.purge_idempotency_keys")
def purge_idempotency_keys() -> int:
    async def job(r: Resources) -> int:
        async with r.sessionmaker() as db, db.begin():
            return await idempotency.purge_expired(db, timedelta(hours=r.settings.idempotency_ttl_hours))

    return run_with_resources(job)


@celery_app.task(name="maintenance.expire_guest_sessions")
def expire_guest_sessions() -> int:
    async def job(r: Resources) -> int:
        async with r.sessionmaker() as db, db.begin():
            return await auth_sessions.expire_inactive_guest_sessions(db, r.settings)

    return run_with_resources(job)


SCHEDULE = {
    "outbox-relay": {"task": "maintenance.outbox_relay", "schedule": 5.0},
    "raqeeb-sweeper": {"task": "maintenance.sweep_raqeeb_messages", "schedule": 10.0},
    "raqeeb-private-cleanup": {"task": "maintenance.raqeeb_private_cleanup", "schedule": 3600.0},
    "purge-idempotency-keys": {"task": "maintenance.purge_idempotency_keys", "schedule": 3600.0},
    "expire-guest-sessions": {"task": "maintenance.expire_guest_sessions", "schedule": 86400.0},
}
celery_app.conf.beat_schedule.update(SCHEDULE)
