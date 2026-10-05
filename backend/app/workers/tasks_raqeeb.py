"""The late-acknowledged raqeeb queue. Broker payloads contain opaque message IDs only."""

from app.raqeeb import worker
from app.workers.celery_app import celery_app
from app.workers.tasks_maintenance import run_with_resources


@celery_app.task(name="raqeeb.process_message")
def process_message(message_id: str) -> str:
    return run_with_resources(lambda resources: worker.process(resources, message_id))


@celery_app.task(name="maintenance.sweep_raqeeb_messages")
def sweep() -> int:
    return run_with_resources(worker.sweep)


@celery_app.task(name="maintenance.expire_raqeeb_message")
def expire_message(message_id: str) -> bool:
    return run_with_resources(lambda resources: worker.expire_deadline(resources, message_id))
