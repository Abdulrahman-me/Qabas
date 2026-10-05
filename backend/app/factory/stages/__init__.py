"""All production Factory stage executors in contract order (factory §13.1)."""

from __future__ import annotations

from app.factory.orchestrator import Executor
from app.factory.stages import decompose, exercises, glossary, localize, media, plan, qa, retrieve, verify, write

EXECUTORS: dict[str, Executor] = {
    "plan": plan.run,
    "decompose": decompose.run,
    "retrieve": retrieve.run,
    "verify_evidence": verify.run,
    "write": write.run,
    "exercises": exercises.run,
    "glossary": glossary.run,
    "localize": localize.run,
    "visuals": media.visuals,
    "scene_author": media.scene_author,
    "scene_render": media.scene_render,
    "narration": media.narration,
    "qa": qa.run,
}
