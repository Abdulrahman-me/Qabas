"""Complete production stage order (factory §13.1, contract RunStage); every media stage is resumable.

Missing approvals/providers fail closed. QA and Gate 2 enforce media publication readiness.
"""

from __future__ import annotations

from typing import Literal

from app.contract import models as C
from app.db.enums import RUN_STAGE

Stage = Literal["plan", "decompose", "retrieve", "verify_evidence", "write", "exercises", "glossary", "localize",
                "visuals", "scene_author", "scene_render", "narration", "qa"]
ORDER: tuple[str, ...] = tuple(RUN_STAGE)
MEDIA_STAGES = frozenset({"visuals", "scene_author", "scene_render", "narration"})
MAX_ATTEMPTS = 3                       # the first attempt and two retries
GATE_AFTER = {"plan": "awaiting_gate1", "qa": "awaiting_gate2"}

assert tuple(C.RunStage.__args__) == ORDER


def next_stage(stage: str) -> str | None:
    """The next production stage, or None after ``qa``."""
    index = ORDER.index(stage) + 1
    return ORDER[index] if index < len(ORDER) else None


def initial_stages() -> list[dict[str, object]]:
    return [{"stage": s, "status": "pending", "started_at": None,
             "finished_at": None} for s in ORDER]


def current_draft(artifacts: dict[str, object]) -> object | None:
    """The reviewer ``Draft`` of a run: built by ``qa`` from the accepted artifacts, reviewed at Gate 2."""
    qa = artifacts.get("qa")
    output = qa.get("output") if isinstance(qa, dict) else None
    return output.get("draft") if isinstance(output, dict) else None
