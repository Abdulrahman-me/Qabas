"""Gate decisions on factory runs (factory §13.1 Gate 1, §14; API §6.11 ``Gate1``; AD-13).

The decision service lives with the pipeline because a run can only continue past Gate 1 through it; Phase 13
exposes it at ``POST /admin/factory/runs/{id}/gate1`` and adds Gate 2. Rules: the run row is locked (the first
valid decision wins); a run not at the gate is ``409 run_not_at_gate``; a digest other than the run's current
``review_digest`` is ``409 review_stale``; only an active reviewer decides; an edited plan is re-validated with the
same code checks as the Architect's output (``400 validation_error``); the insert-only ``review_decisions`` row is
written in the same transaction as the run's new state.
"""

from __future__ import annotations

from typing import Any

from pydantic import ValidationError
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.contract import models as C
from app.errors import ApiError, ErrorCode
from app.factory.orchestrator import Dispatcher, RunSnapshot
from app.factory.stages import plan as plan_stage
from app.models import FactoryRun, ReviewDecision, User
from app.services.platform.auth_sessions import utcnow


async def _active_reviewer(db: AsyncSession, reviewer_id: str) -> User:
    reviewer = await db.get(User, reviewer_id)
    if reviewer is None or reviewer.role != "reviewer" or reviewer.deactivated_at is not None \
            or reviewer.deleted_at is not None:
        raise ApiError(ErrorCode.forbidden, "Only an active reviewer can decide at a gate.")
    return reviewer


async def decide_gate1(sessionmaker: async_sessionmaker[AsyncSession], dispatcher: Dispatcher, *, run_id: str,
                       reviewer_id: str, body: C.Gate1) -> dict[str, Any]:
    async with sessionmaker() as db, db.begin():
        await _active_reviewer(db, reviewer_id)
        run = await db.get(FactoryRun, run_id, with_for_update=True)
        if run is None:
            raise ApiError(ErrorCode.not_found, "Factory run was not found.")
        if run.status != "awaiting_gate1":
            raise ApiError(ErrorCode.run_not_at_gate, "This run is not waiting at Gate 1.")
        if body.review_digest != run.review_digest:
            raise ApiError(ErrorCode.review_stale, "The plan changed since you reviewed it; review it again.")
        edited = body.plan.model_dump(mode="json") if body.plan is not None else None
        if edited is not None:
            snapshot = RunSnapshot(run.id, run.unit_id, run.lesson_id, run.position_index, run.lesson_type,
                                   run.brief, run.stage, run.attempt, run.plan, dict(run.artifacts),
                                   run.budget_tokens, [], [])
            try:
                C.LessonPlan.model_validate(edited)
            except ValidationError as exc:
                raise ApiError(ErrorCode.validation_error, "The edited plan is not a valid LessonPlan.",
                               {"field": "plan", "errors": [e["msg"] for e in exc.errors()][:10]}) from None
            errors, _ = plan_stage.check_plan(edited, run.lesson_type, await plan_stage.plan_context(db, snapshot))
            if errors:
                raise ApiError(ErrorCode.validation_error, "The edited plan does not fit the curriculum.",
                               {"field": "plan", "errors": errors[:10]})
        decided_at = utcnow()
        db.add(ReviewDecision(run_id=run.id, gate=1, decision=body.decision, reviewer_id=reviewer_id,
                              reviewed_digest=body.review_digest, reason=body.reason,
                              edits={"plan": edited} if edited is not None else {}))
        run.gate1_decision = {"decision": body.decision, "reviewer_id": reviewer_id, "edited": edited is not None,
                              "reason": body.reason, "decided_at": decided_at.isoformat()}
        run.review_digest = None
        if body.decision == "approve":
            if edited is not None:
                run.plan = edited
            run.status, run.stage, run.attempt = "running", "decompose", 1
        else:
            run.status = "rejected"
        result = {"run_id": run.id, "status": run.status, "stage": run.stage}
    if body.decision == "approve":
        dispatcher.send(run_id, "decompose", 1)
    return result
