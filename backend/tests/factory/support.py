"""Factory test support: an inline dispatcher, reviewers, the orchestrator over the real database and a synthetic
plan built only from the fixture curriculum's own ids (no curriculum or religious content is authored here)."""

from __future__ import annotations

import copy
from dataclasses import dataclass, field
from typing import Any

from app.config import Settings
from app.factory.orchestrator import Executor, Orchestrator
from app.factory.stages import EXECUTORS
from app.llm.client import LLMClient
from app.models import User
from app.runtime import Resources
from app.services.platform import passwords

SLOT = "les_t2_1"                    # unit_test_2 (index 1, both tracks): introduces con_t2_1, may require con_t2_0


@dataclass
class InlineDispatcher:
    queue: list[tuple[str, str, int]] = field(default_factory=list)
    countdowns: list[float] = field(default_factory=list)

    def send(self, run_id: str, stage: str, attempt: int, countdown: float = 0) -> None:
        self.queue.append((run_id, stage, attempt))
        self.countdowns.append(countdown)


async def drive(orchestrator: Orchestrator, dispatcher: InlineDispatcher, *, until: str | None = None,
                limit: int = 30) -> list[str]:
    """Run queued stage messages in order (as workers would) until the queue is empty or ``until`` ran."""
    outcomes = []
    while dispatcher.queue and limit:
        run_id, stage, attempt = dispatcher.queue.pop(0)
        outcomes.append(await orchestrator.run_stage(run_id, stage, attempt))
        limit -= 1
        if stage == until:
            break
    return outcomes


async def reviewer(resources: Resources, *, user_id: str = "usr_factory_reviewer", active: bool = True) -> str:
    from datetime import UTC, datetime
    async with resources.sessionmaker() as db, db.begin():
        db.add(User(id=user_id, display_name="Reviewer", avatar_key="traveler_01", timezone="UTC", role="reviewer",
                    email=f"{user_id}@example.test", password_hash=passwords.hash_password("a long passphrase"),
                    onboarding_completed=True, deactivated_at=None if active else datetime.now(UTC)))
    return user_id


def orchestrator(resources: Resources, llm: LLMClient, dispatcher: InlineDispatcher,
                 executors: dict[str, Executor] | None = None, settings: Settings | None = None) -> Orchestrator:
    return Orchestrator(resources.sessionmaker, settings or resources.settings, llm, dispatcher,
                        EXECUTORS if executors is None else executors)


def text(label: str) -> dict[str, str]:
    return {"ar": f"نص تجريبي {label}", "en": f"Synthetic {label}"}


PLAN: dict[str, Any] = {
    "title": text("title"), "central_question": text("central question"),
    "primary_learning_outcome": text("outcome"), "supporting_understandings": [text("support")],
    "depth_profile": "foundational", "objectives": [text("objective")],
    "prerequisite_concept_ids": ["con_t2_0"], "introduced_concept_ids": ["con_t2_1"],
    "new_terms": [text("term")], "target_misconceptions": [], "lesson_type": "concept",
    "estimated_minutes": 8,
    "lesson_arc": {"pattern": "discovery", "rationale": text("rationale"), "steps": [
        {"step_id": "s1", "technique": "scenario", "experience": text("scenario"), "interactive": False},
        {"step_id": "s2", "technique": "prediction", "experience": text("prediction"), "interactive": True},
        {"step_id": "s3", "technique": "explanation", "experience": text("explanation"), "interactive": False},
        {"step_id": "s4", "technique": "practice", "experience": text("practice"), "interactive": True},
        {"step_id": "s5", "technique": "takeaway", "experience": text("takeaway"), "interactive": False}]},
    "reasoning_tools": [], "standalone_eligible": False, "content_budget": 4, "exercise_budget": 3}


def plan(**changes: Any) -> dict[str, Any]:
    value = copy.deepcopy(PLAN)
    value.update(changes)
    return value
