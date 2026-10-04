"""Shared app/server registries (``backend/content/registries.json``)."""

from __future__ import annotations

import json
from functools import cache
from pathlib import Path
from typing import Any

REGISTRIES_PATH = Path(__file__).resolve().parents[1] / "content" / "registries.json"


@cache
def registries() -> dict[str, Any]:
    data: dict[str, Any] = json.loads(REGISTRIES_PATH.read_text(encoding="utf-8"))
    return data


def selectable_avatar_keys() -> tuple[str, ...]:
    return tuple(a["avatar_key"] for a in registries()["avatars"]["selectable"])


def default_avatar_key() -> str:
    key: str = registries()["avatars"]["default"]
    return key


def goal_anchor_keys() -> frozenset[str]:
    return frozenset(k["goal_anchor"] for k in registries()["goal_anchors"]["keys"])


def guest_name_words(language: str) -> tuple[str, ...]:
    return tuple(registries()["guest_names"][language])


def guest_number_range() -> tuple[int, int]:
    low, high = registries()["guest_names"]["number_range"]
    return int(low), int(high)


def deleted_learner_name(language: str) -> str:
    name: str = registries()["deleted_learner"][language]
    return name
