"""AD-23 ownerless-room recovery; APIs own steady-state coordination, beat guarantees a durable fallback."""

from __future__ import annotations

from app.services.challenges import coordinator
from app.services.platform.auth_sessions import utcnow
from app.workers.celery_app import celery_app
from app.workers.tasks_maintenance import run_with_resources


@celery_app.task(name="maintenance.recover_live_challenges")
def recover_live_challenges() -> int:
    return run_with_resources(lambda r: coordinator.recover(r, utcnow()))


celery_app.conf.beat_schedule.update({
    "live-challenge-recovery": {"task": "maintenance.recover_live_challenges", "schedule": 1.0},
})
