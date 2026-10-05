"""Creating factory runs and projecting them to the contract ``FactoryRun`` (API §6.11 shapes; endpoints: Phase 13)."""

from __future__ import annotations

from typing import Any

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.config import Settings
from app.contract import models as C
from app.db.ids import new_id
from app.errors import ApiError, ErrorCode
from app.factory import pipeline
from app.factory.orchestrator import Dispatcher
from app.models import CurriculumSlot, FactoryRun, User

BRIEF_MAX = 4000
LESSON_TYPES = ("concept", "story", "practice")


async def create_run(db: AsyncSession, settings: Settings, *, reviewer: User, lesson_id: str, lesson_type: str,
                     brief: str, budget_tokens: int | None = None) -> FactoryRun:
    """A new run for the slot of ``lesson_id`` (it creates or revises that slot's single lesson). The caller
    commits and then dispatches ``plan`` (see :func:`start_run`)."""
    if reviewer.role != "reviewer" or reviewer.deactivated_at is not None or reviewer.deleted_at is not None:
        raise ApiError(ErrorCode.forbidden, "Only an active reviewer starts factory runs.")
    if lesson_type not in LESSON_TYPES:
        raise ApiError(ErrorCode.validation_error, "lesson_type is concept, story or practice.",
                       {"field": "lesson_type"})
    if not brief.strip() or len(brief) > BRIEF_MAX:
        raise ApiError(ErrorCode.validation_error, f"The brief is 1-{BRIEF_MAX} characters.", {"field": "brief"})
    slot = (await db.execute(select(CurriculumSlot).where(CurriculumSlot.lesson_id == lesson_id))).scalar_one_or_none()
    if slot is None:
        raise ApiError(ErrorCode.validation_error, "This lesson is not a curriculum slot.", {"field": "lesson_id"})
    run = FactoryRun(id=new_id("run"), unit_id=slot.unit_id, lesson_id=slot.lesson_id, position_index=slot.index,
                     lesson_type=lesson_type, brief=brief, status="running", stage="plan", attempt=1,
                     stages=pipeline.initial_stages(), artifacts={}, stage_timings={}, attempts=[],
                     cost={"calls": []}, budget_tokens=budget_tokens or settings.factory_run_budget_tokens,
                     created_by=reviewer.id)
    try:
        async with db.begin_nested():   # a duplicate is discarded with its savepoint; the session stays usable
            db.add(run)
            await db.flush()
    except IntegrityError:
        raise ApiError(ErrorCode.validation_error, "This curriculum slot already has an active factory run.",
                       {"field": "lesson_id"}) from None
    return run


async def start_run(sessionmaker: async_sessionmaker[AsyncSession], settings: Settings, dispatcher: Dispatcher,
                    **arguments: Any) -> str:
    async with sessionmaker() as db, db.begin():
        run = await create_run(db, settings, **arguments)
        run_id = run.id
    dispatcher.send(run_id, "plan", 1)
    return run_id


def to_contract(run: FactoryRun) -> dict[str, Any]:
    """The contract ``FactoryRun`` (validated); ``draft`` appears once a draft exists (factory stages 5-10)."""
    published = ({"lesson_id": run.published_lesson_id, "version": run.published_version}
                 if run.published_lesson_id is not None else None)
    body = {"run_id": run.id, "unit_id": run.unit_id, "lesson_type": run.lesson_type, "brief": run.brief,
            "status": run.status, "stage": run.stage, "stages": run.stages, "plan": run.plan,
            "draft": pipeline.current_draft(run.artifacts), "qa_report": run.qa_report, "error": run.error,
            "review_digest": run.review_digest, "published": published}
    projected: dict[str, Any] = C.FactoryRun.model_validate(body).model_dump(mode="json")
    return projected
