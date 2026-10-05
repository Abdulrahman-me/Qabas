"""Regenerate media before review, never after publication; archive the previously reviewed draft."""

from __future__ import annotations

import uuid
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.errors import ApiError, ErrorCode
from app.factory import pipeline
from app.factory.gates import _active_reviewer
from app.factory.orchestrator import Dispatcher
from app.models import FactoryRun
from app.services.platform.auth_sessions import utcnow


async def request(
    sessionmaker: async_sessionmaker[AsyncSession],
    dispatcher: Dispatcher,
    *,
    run_id: str,
    scene_id: str,
    reviewer_id: str,
    reason: str | None,
) -> None:
    async with sessionmaker() as db, db.begin():
        await _active_reviewer(db, reviewer_id)
        run = await db.get(FactoryRun, run_id, with_for_update=True)
        if run is None:
            raise ApiError(ErrorCode.not_found, "Factory run was not found.")
        if run.status != "awaiting_gate2":
            raise ApiError(ErrorCode.run_not_at_gate, "Media regeneration requires Gate 2.")
        draft = pipeline.current_draft(run.artifacts)
        assert isinstance(draft, dict)
        visual = next((v for v in draft["visuals"] if v["scene_id"] == scene_id), None)
        if visual is None:
            raise ApiError(ErrorCode.not_found, "Draft visual was not found.")
        if visual["origin"] == "builtin":
            raise ApiError(ErrorCode.validation_error, "Compiled built-in visuals cannot be regenerated.")
        first = "scene_author" if visual["origin"] == "generated_scene" else "visuals"
        rewritten = set(pipeline.ORDER[pipeline.ORDER.index(first) :])
        previous: dict[str, Any] = {s: run.artifacts[s] for s in rewritten if s in run.artifacts}
        history = [
            *run.artifacts.get("media_revisions", []),
            {
                "review_digest": run.review_digest,
                "qa_report": run.qa_report,
                "artifacts": previous,
                "reason": reason,
                "reviewer_id": reviewer_id,
                "requested_at": utcnow().isoformat(),
            },
        ]
        selection = next(
            (
                s
                for s in run.artifacts.get("visuals", {}).get("output", {}).get("selections", [])
                if s["brief_id"] == scene_id
            ),
            None,
        )
        run.artifacts = {
            **{k: v for k, v in run.artifacts.items() if k not in rewritten},
            "media_previous": previous,
            "media_revisions": history,
            "media_regeneration": {
                "id": uuid.uuid4().hex,
                "scene_id": scene_id,
                "group": selection["group"] if selection else None,
                "reason": reason,
                "origin": visual["origin"],
            },
        }
        run.stages = [
            {**s, "status": "pending", "started_at": None, "finished_at": None} if s["stage"] in rewritten else s
            for s in run.stages
        ]
        run.stage_timings = {k: v for k, v in run.stage_timings.items() if k not in rewritten}
        run.status, run.stage, run.attempt = "running", first, 1
        run.review_digest, run.qa_report, run.review_started_at, run.review_finished_at = None, None, None, None
        run.attempts = [
            *run.attempts,
            {
                "stage": first,
                "attempt": 1,
                "event": "media_regeneration_requested",
                "scene_id": scene_id,
                "reason": reason,
                "at": utcnow().isoformat(),
            },
        ]
    dispatcher.send(run_id, first, 1)
