"""Maintenance queue tasks. Outbox relay, purge and cleanup jobs are added in Phase 3."""

from __future__ import annotations

from app.workers.celery_app import celery_app


@celery_app.task(name="maintenance.ping")
def ping() -> str:
    """Worker liveness probe used by tests and operators."""
    return "pong"
