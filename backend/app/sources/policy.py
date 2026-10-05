"""Provider policy (``content/sources/providers.yaml``): roles, the O-03 live gate and cache terms (D-91)."""

from __future__ import annotations

from functools import lru_cache
from pathlib import Path
from typing import Any, Literal

import yaml
from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.config import BACKEND_DIR, Environment, Settings
from app.sources.errors import ProviderNotConfigured

PROVIDERS = BACKEND_DIR / "content" / "sources" / "providers.yaml"
DAY = 86_400


class CachePolicy(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    ttl_days: float = Field(ge=0, allow_inf_nan=False)
    terms: Literal["pending", "confirmed", "no_cache"]
    confirmed_by: str | None

    @model_validator(mode="after")
    def _confirmed(self) -> CachePolicy:
        if self.terms != "pending" and not self.confirmed_by:
            raise ValueError("cache terms other than pending must name who confirmed them")
        return self


class ProviderPolicy(BaseModel):
    model_config = ConfigDict(extra="allow", frozen=True)

    id: str
    name: str
    role: list[Literal["authority", "capability"]]
    contract_provider: str | None
    adapter: str
    credentials: list[str]
    live: Literal["pending", "approved"]
    live_confirmed_by: str | None
    cache: CachePolicy

    @model_validator(mode="after")
    def _approved(self) -> ProviderPolicy:
        if self.live == "approved" and not self.live_confirmed_by:
            raise ValueError(f"{self.id}: live approval must name who confirmed it (O-03)")
        return self

    @property
    def cache_ttl_seconds(self) -> int:
        """§12's default applies only once the provider's terms are confirmed; pending terms cache nothing."""
        return int(self.cache.ttl_days * DAY) if self.cache.terms == "confirmed" else 0

    def require_live(self, settings: Settings) -> None:
        if settings.app_env is Environment.production and self.live != "approved":
            raise ProviderNotConfigured(self.id, "live use is not approved for production yet (O-03)")

    def option(self, key: str) -> Any:
        return (self.model_extra or {}).get(key)


@lru_cache
def load_policies(path: Path = PROVIDERS) -> dict[str, ProviderPolicy]:
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    if data.get("schema") != "qabas.source_providers/1":
        raise ValueError(f"{path}: unknown schema")
    return {key: ProviderPolicy(id=key, **value) for key, value in data["providers"].items()}


def policy(provider: str) -> ProviderPolicy:
    return load_policies()[provider]
