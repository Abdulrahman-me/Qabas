"""Factory stage executors by stage name (factory §13.1). A stage absent here is not runnable yet: the media
stages (``visuals``, ``scene_author``, ``scene_render``, ``narration``) are skipped until Phase 14 (D-129)."""

from __future__ import annotations

from app.factory.orchestrator import Executor
from app.factory.stages import decompose, exercises, glossary, localize, plan, qa, retrieve, verify, write

EXECUTORS: dict[str, Executor] = {
    "plan": plan.run,
    "decompose": decompose.run,
    "retrieve": retrieve.run,
    "verify_evidence": verify.run,
    "write": write.run,
    "exercises": exercises.run,
    "glossary": glossary.run,
    "localize": localize.run,
    "qa": qa.run,
}
