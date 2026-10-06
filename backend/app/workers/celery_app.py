"""Celery application: queues, routing and reliability defaults (SYSTEM_ARCHITECTURE §3.1).

Tasks are idempotent and acknowledged late, so a crashed worker's task is redelivered.
Run on Windows dev with ``--pool=solo`` (or ``threads``); prefork is Linux-only.

    celery -A app.workers.celery_app worker -Q maintenance,factory,media --pool=solo
    celery -A app.workers.celery_app worker -Q asr --pool=solo --prefetch-multiplier=1
    celery -A app.workers.celery_app beat
"""

from __future__ import annotations

from celery import Celery
from kombu import Queue

from app.config import get_settings

QUEUES = ("maintenance", "factory", "media", "raqeeb", "asr", "embeddings")

settings = get_settings()
celery_app = Celery("qabas", broker=settings.redis_url, backend=settings.redis_url,
                    include=["app.workers.tasks_maintenance", "app.workers.tasks_asr", "app.workers.tasks_factory",
                             "app.workers.tasks_raqeeb", "app.workers.tasks_embeddings",
                             "app.workers.tasks_community"])
celery_app.conf.update(
    task_queues=[Queue(name) for name in QUEUES],
    task_default_queue="maintenance",
    # Route by task-name prefix: "factory.*" -> factory queue, etc.
    task_routes={f"{name}.*": {"queue": name} for name in QUEUES},
    task_acks_late=True,
    task_reject_on_worker_lost=True,
    worker_prefetch_multiplier=1,
    task_serializer="json",
    result_serializer="json",
    accept_content=["json"],
    result_expires=3600,
    timezone="UTC",
    enable_utc=True,
    broker_connection_retry_on_startup=True,
    # Periodic jobs (outbox relay, sweepers, league promotion, ...) are registered by their phases.
    beat_schedule={},
)
