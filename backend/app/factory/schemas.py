"""Output shapes of the factory's model calls. Each is a contract model or a closed stage model derived from the
handoff's stage table (factory §13.1); ``scripts/export_llm_schemas.py`` writes them to ``app/llm/json_schemas``.

Exports use the structured-output subset: a discriminated union becomes ``anyOf`` (the discriminator stays a
required ``enum`` field, so every branch is still unambiguous) and a single-value literal becomes a one-item
``enum``. The stage code re-validates every output with the pydantic model itself.
"""

from __future__ import annotations

from collections.abc import Callable
from typing import Any

from app.contract import models as C
from app.factory import stage_models as S


def _subset(node: Any) -> Any:
    if isinstance(node, dict):
        out = {}
        for key, value in node.items():
            if key == "discriminator":
                continue
            if key == "oneOf":
                key = "anyOf"
            out[key] = _subset(value)
        if "const" in out:
            out["enum"] = [out.pop("const")]
        return out
    if isinstance(node, list):
        return [_subset(v) for v in node]
    return node


def _schema(model: Any, title: str) -> dict[str, Any]:
    schema: dict[str, Any] = _subset(model.model_json_schema())
    schema["title"] = title
    return schema


EXPORTS: dict[str, Callable[[], dict[str, Any]]] = {
    "factory_plan": lambda: _schema(C.LessonPlan, "factory_plan"),
    "factory_decompose": lambda: _schema(S.Decomposition, "factory_decompose"),
    "factory_retrieve": lambda: _schema(S.RetrievalPlan, "factory_retrieve"),
    "factory_verify": lambda: _schema(S.Verification, "factory_verify"),
    "factory_write": lambda: _schema(S.WriterDraft, "factory_write"),
    "factory_exercises": lambda: _schema(S.ExerciseSet, "factory_exercises"),
    "factory_glossary": lambda: _schema(S.Glossary, "factory_glossary"),
    "factory_localize": lambda: _schema(S.Localization, "factory_localize"),
    "factory_review": lambda: _schema(S.ModelReview, "factory_review"),
}
