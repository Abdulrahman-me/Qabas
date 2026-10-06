"""Model policy (``content/llm/models.yaml``): O-03 approval, declared capabilities and confirmed prices."""

from __future__ import annotations

from functools import lru_cache
from pathlib import Path
from typing import Literal

import yaml
from pydantic import BaseModel, ConfigDict, model_validator

from app.config import BACKEND_DIR, Environment, Settings
from app.llm.errors import LLMNotConfigured

MODELS = BACKEND_DIR / "content" / "llm" / "models.yaml"
EffortLevel = Literal["low", "medium", "high", "xhigh", "max"]


class Capabilities(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    effort: list[EffortLevel] | None
    adaptive_thinking: bool | None
    structured_outputs: bool


class Prices(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    input: float | None
    output: float | None
    cache_write: float | None
    cache_read: float | None

    @property
    def complete(self) -> bool:
        return None not in (self.input, self.output, self.cache_write, self.cache_read)


class ModelPolicy(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    id: str
    role: str
    provider: Literal["anthropic", "openai"] = "anthropic"
    status: Literal["pending", "approved"]
    evaluated_by: str | None
    evaluated_on: str | None
    report: str | None
    capabilities: Capabilities
    price_per_mtok: Prices

    @model_validator(mode="after")
    def _approved(self) -> ModelPolicy:
        if self.status == "approved" and not (self.evaluated_by and self.evaluated_on and self.report):
            raise ValueError(f"{self.id}: approval names the evaluator, date and report (O-03)")
        if not self.capabilities.structured_outputs:
            raise ValueError(f"{self.id}: structured outputs are required by every call")
        return self


@lru_cache
def load_models(path: Path = MODELS) -> dict[str, ModelPolicy]:
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    if data.get("schema") != "qabas.llm_models/1":
        raise ValueError(f"{path}: unknown schema")
    return {key: ModelPolicy(id=key, **value) for key, value in data["models"].items()}


def model_policy(model_id: str, settings: Settings) -> ModelPolicy:
    """The configured model's policy; unknown models are refused everywhere, unapproved ones in production."""
    policy = load_models().get(model_id)
    if policy is None:
        raise LLMNotConfigured(f"model {model_id!r} is not declared in content/llm/models.yaml")
    if settings.app_env is Environment.production and policy.status != "approved":
        raise LLMNotConfigured(f"model {model_id!r} is not approved for production yet (O-03 evaluation)")
    return policy
