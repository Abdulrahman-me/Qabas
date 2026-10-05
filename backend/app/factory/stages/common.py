"""Helpers shared by the factory stages: reading earlier accepted artifacts and validating model drafts.

A stage reads only what earlier stages *accepted* (``factory_runs.artifacts[stage].output``), never another
attempt's rejected output, so the exact version that proceeded is the one recorded with its digest.
"""

from __future__ import annotations

from typing import Any

from pydantic import BaseModel, ValidationError

from app.factory.errors import StageOutputInvalid
from app.factory.orchestrator import StageContext


def accepted(ctx: StageContext, stage: str) -> dict[str, Any]:
    entry = ctx.run.artifacts.get(stage)
    if not isinstance(entry, dict) or "output" not in entry:
        raise RuntimeError(f"stage {ctx.run.stage} needs the accepted {stage} artifact")
    output: dict[str, Any] = entry["output"]
    return output


def approved_plan(ctx: StageContext) -> dict[str, Any]:
    if ctx.run.plan is None:
        raise RuntimeError("the run has no approved plan")
    return ctx.run.plan


def parse[M: BaseModel](model: type[M], data: dict[str, Any], code: str) -> M:
    """The stage model's own validation (beyond the JSON schema): a failure is invalid output, retried."""
    try:
        return model.model_validate(data)
    except ValidationError as exc:
        raise StageOutputInvalid(code, [f"{'/'.join(map(str, e['loc']))}: {e['msg']}"
                                        for e in exc.errors()[:20]]) from exc


def require(errors: list[str], code: str) -> None:
    if errors:
        raise StageOutputInvalid(code, errors[:50])


def key_of(run_id: str) -> str:
    """A short run-scoped key for ids this run mints (exercises, terms, misconceptions)."""
    return run_id[-12:].lower()


def duplicates(values: list[str]) -> list[str]:
    seen, repeated = set(), []
    for value in values:
        if value in seen and value not in repeated:
            repeated.append(value)
        seen.add(value)
    return repeated
