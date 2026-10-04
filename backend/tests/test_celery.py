from __future__ import annotations

from app.workers.celery_app import QUEUES, celery_app
from app.workers.tasks_maintenance import ping


def test_queues_and_reliability_defaults() -> None:
    conf = celery_app.conf
    assert {q.name for q in conf.task_queues} == set(QUEUES)
    assert conf.task_acks_late is True
    assert conf.task_reject_on_worker_lost is True
    assert conf.worker_prefetch_multiplier == 1


def test_routing_by_task_prefix() -> None:
    router = celery_app.amqp.router
    assert router.route({}, "factory.plan")["queue"].name == "factory"
    assert router.route({}, "asr.check")["queue"].name == "asr"
    assert router.route({}, "maintenance.ping")["queue"].name == "maintenance"


def test_ping_task_runs() -> None:
    assert ping.apply().get() == "pong"


def test_maintenance_jobs_are_scheduled() -> None:
    schedule = celery_app.conf.beat_schedule
    assert schedule["outbox-relay"]["task"] == "maintenance.outbox_relay"
    assert schedule["outbox-relay"]["schedule"] <= 10
    assert {"purge-idempotency-keys", "expire-guest-sessions"} <= schedule.keys()
