"""Output shapes of the factory's model calls. Each is a contract model or a closed stage model derived from the
handoff's stage table (factory §13.1); ``scripts/export_llm_schemas.py`` writes them to ``app/llm/json_schemas``."""

from __future__ import annotations

from collections.abc import Callable
from typing import Any

from app.contract import models as C


def _schema(model: Any, title: str) -> dict[str, Any]:
    schema: dict[str, Any] = model.model_json_schema()
    schema["title"] = title
    return schema


EXPORTS: dict[str, Callable[[], dict[str, Any]]] = {
    "factory_plan": lambda: _schema(C.LessonPlan, "factory_plan"),
}
