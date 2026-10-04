"""Registries agree with the contract (backend §6.5 test_registry_parity, SEED_AND_IMPORT §15)."""

from __future__ import annotations

import json
import re
import typing
from pathlib import Path

import yaml

from app.contract import VENDOR_ROOT, models
from app.registries import REGISTRIES_PATH, registries

VISUAL_REGISTRY = Path(__file__).resolve().parents[2] / "content" / "visual_registry.yaml"
API_DOC = VENDOR_ROOT / "03_API" / "API_REQUIREMENTS.md"


def test_visual_registry_keys_versions_params_match_contract() -> None:
    reg = yaml.safe_load(VISUAL_REGISTRY.read_text(encoding="utf-8"))
    assert set(reg["keys"]) == set(models.BUILTIN_PARAMS)
    contract_keys = set(typing.get_args(typing.get_args(models.Visual.model_fields["key"].annotation)[0]))
    assert set(reg["keys"]) == contract_keys
    for key, spec in reg["keys"].items():
        assert spec["versions"] == [1]
        expected = models.BUILTIN_PARAMS[key]
        assert set(spec["params"]) == set(expected), key
        for name, (low, high) in expected.items():
            assert (spec["params"][name]["min"], spec["params"][name]["max"]) == (low, high), (key, name)


def _api_proportions() -> dict[str, float]:
    """The per-use proportions of API §5.5d, read from the vendored specification."""
    section = API_DOC.read_text(encoding="utf-8").split("### 5.5d")[1].split("### 5.5e")[0]
    rows = {}
    for line in section.splitlines():
        match = re.match(r"\|\s*(.+?)\s*\|\s*(.+?)\s*\|\s*\*\*([0-9.]+)\*\*", line)
        if match:
            rows[(match.group(1), match.group(2))] = float(match.group(3))
    return {
        "hook": rows[("`hook.visual`", "any built-in")],
        "story_beat": rows[("`story` beat `visual`", "any built-in")],
        "teach.river_house": rows[("`teach.visual`", "`river_house`, `pillars`")],
        "teach.pillars": rows[("`teach.visual`", "`river_house`, `pillars`")],
        "teach.workplace": rows[("`teach.visual`", "`workplace`")],
        "teach.day_arc": rows[("`teach.visual`", "`day_arc`")],
        "map_place_hotspots": rows[("`map_place` with `presentation: hotspots`", "any built-in")],
        "categorize_day_arc": rows[("`categorize` with `presentation: day_arc` (the arc above the slots)",
                                    "`day_arc` (implicit)")],
        "visual_block": rows[("`visual` block, `predict.visual`", "any built-in")],
        "predict": rows[("`visual` block, `predict.visual`", "any built-in")],
    }


def test_visual_registry_proportions_match_api() -> None:
    uses = yaml.safe_load(VISUAL_REGISTRY.read_text(encoding="utf-8"))["uses"]
    flat = {}
    for use, value in uses.items():
        if isinstance(value, dict):
            flat.update({f"{use}.{key}": v for key, v in value.items()})
        else:
            flat[use] = value
    assert flat == _api_proportions()


def test_unit_art_is_the_compiled_art_set() -> None:
    assert set(registries()["unit_art"]["keys"]) == set(models.EXERCISE_ART)


def test_goal_anchors_match_the_contract_template() -> None:
    template = json.loads((VENDOR_ROOT / "03_API" / "contract_revision10" / "contract" / "registries.template.json")
                          .read_text(encoding="utf-8"))
    assert registries()["goal_anchors"]["keys"] == template["goal_anchors"]["keys"]


def test_league_tiers_and_achievements() -> None:
    tiers = registries()["league_tiers"]["tiers"]
    assert [t["tier_key"] for t in tiers] == ["tier_lantern", "tier_beacon", "tier_star", "tier_dawn"]
    assert [t["index"] for t in tiers] == [0, 1, 2, 3] and [t["is_top_tier"] for t in tiers] == [False] * 3 + [True]
    achievements = registries()["achievements"]["items"]
    counters = {"raqeeb_questions", "lessons_completed", "units_completed", "longest_streak", "terms_mastered",
                "misconceptions_resolved", "challenges_won", "recitations_passed", "reviews_completed",
                "perfect_lessons"}
    assert len(achievements) == 8 and all(a["counter"] in counters and a["target"] >= 1 for a in achievements)
    assert {a["achievement_key"] for a in achievements} >= {"firstStep", "seeker"}
    seeker = next(a for a in achievements if a["achievement_key"] == "seeker")
    assert (seeker["counter"], seeker["target"]) == ("raqeeb_questions", 5)  # "Ask Raqeeb 5 questions"
    assert REGISTRIES_PATH.exists()
