from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class Closed(BaseModel):
    model_config = ConfigDict(extra="forbid")


class Alt(Closed):
    ar: str = Field(min_length=1)
    en: str = Field(min_length=1)


class Selection(Closed):
    brief_id: str
    purpose: str = Field(min_length=1)
    kind: Literal["builtin", "image", "scene", "none"]
    key: Literal["river_house", "workplace", "day_arc", "pillars"] | None
    params_json: str
    point_params_json: list[str] | None
    group: str = Field(min_length=1)
    image_brief: str
    figures: list[str]
    alt: Alt
    map: bool


class VisualSelection(Closed):
    visuals: list[Selection]
    issues: list[str]


class ImagePrompt(Closed):
    prompt: str = Field(min_length=1, max_length=12000)


class ArtworkBrief(Closed):
    asset_id: str
    brief: str = Field(min_length=1)
    width: int = Field(gt=0, le=4096)
    height: int = Field(gt=0, le=4096)


class AuthoredScene(Closed):
    manifest_json: str
    artwork: list[ArtworkBrief]


class VisualAudit(Closed):
    passed: bool
    issues: list[str]
