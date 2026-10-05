"""Stage order and which stages this phase runs (factory §13.1, contract ``RunStage``).

Stages 8-9 (``visuals``, ``scene_author``, ``scene_render``, ``narration``) belong to the visual and media
pipeline (Phase 14): until then a run records them as ``skipped`` and QA keeps the visual-readiness and
placeholder-media blockers that stop such a draft from passing Gate 2 (§13.4, D-129).
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
    """The stage that runs after ``stage`` (media stages are skipped), or None after ``qa``."""
    index = ORDER.index(stage) + 1
    while index < len(ORDER) and ORDER[index] in MEDIA_STAGES:
        index += 1
    return ORDER[index] if index < len(ORDER) else None


def initial_stages() -> list[dict[str, object]]:
    return [{"stage": s, "status": "skipped" if s in MEDIA_STAGES else "pending", "started_at": None,
             "finished_at": None} for s in ORDER]
