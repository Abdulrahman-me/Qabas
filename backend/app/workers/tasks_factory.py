"""The ``factory`` queue: one task per (run, stage, attempt) (factory §13.1 stage execution).

    celery -A app.workers.celery_app worker -Q factory --pool=solo          # Windows dev

Tasks are acknowledged late, so a worker that dies mid-stage gets the same message redelivered; the orchestrator's
claim fences duplicates and stale messages, so a crash re-runs at most one stage. Model calls go through the
Phase 11 adapter only (``app.llm``) and sources only through the Phase 9 layer (``app.factory.evidence``); both
refuse unapproved models and providers in production (O-03).
"""

from __future__ import annotations

import uuid

from app.factory.evidence import live_tools
from app.factory.orchestrator import Orchestrator
from app.factory.pipeline import MEDIA_STAGES
from app.factory.stages import EXECUTORS
from app.llm.factory_client import factory_client
from app.media.service import MediaService
from app.runtime import Resources
from app.workers.celery_app import celery_app
from app.workers.tasks_maintenance import run_with_resources

TASK = "factory.run_stage"


class CeleryDispatcher:
    """Publishes the next stage only after the stage's transaction committed (the orchestrator calls it then)."""

    def send(self, run_id: str, stage: str, attempt: int, countdown: float = 0) -> None:
        celery_app.send_task(TASK, args=[run_id, stage, attempt], queue="media" if stage in MEDIA_STAGES else "factory",
                             countdown=countdown,
                             task_id=f"{run_id}:{stage}:{attempt}:{uuid.uuid4().hex[:8]}")


@celery_app.task(name=TASK)
def run_stage(run_id: str, stage: str, attempt: int) -> str:
    async def job(resources: Resources) -> str:
        media = MediaService(resources.storage)
        client = factory_client(resources.settings)
        orchestrator = Orchestrator(resources.sessionmaker, resources.settings, client,
                                    CeleryDispatcher(), EXECUTORS,
                                    services={"sources": live_tools(resources.settings), "media": media})
        try:
            return await orchestrator.run_stage(run_id, stage, attempt)
        finally:
            await media.aclose()
            await client.aclose()

    return run_with_resources(job)
