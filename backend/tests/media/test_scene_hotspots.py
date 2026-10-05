"""QUALITY §18.1 ``test_scene_hotspots.py``: a pin moved off its anchor (same proportion), a state rule moving an
anchored layer, a fallback rendered at another state, and unknown or out-of-range bindings are all rejected before
publication (scene_check + contract models + the publication binding check)."""

from __future__ import annotations

import copy
import json
from typing import Any

import pytest
from pydantic import ValidationError

from app.contract import FIXTURES_DIR
from app.contract import models as C
from app.media import scenes
from app.media.errors import MediaInvalid

MANIFEST: dict[str, Any] = json.loads((FIXTURES_DIR / "scenes/asset_positive.scene.json").read_text("utf-8"))
REF = {"scene_id": MANIFEST["scene_id"], "version": MANIFEST["version"], "schema_version": "qabas.scene/1",
       "url": "https://cdn.qabas.app/media/scenes/x/v1/m.scene.json", "mime_type": "application/json",
       "sha256": "a" * 64, "view_box": MANIFEST["view_box"], "required_capabilities": MANIFEST["required_capabilities"]}


def exercise(pins: list[dict[str, Any]], *, params: dict[str, Any] | None = None,
             fallback_params: dict[str, Any] | None = None, interaction: Any = None) -> dict[str, Any]:
    params = params if params is not None else {"beat": 0, "focus": -1}
    return {"type": "map_place", "pins": pins, "interaction": interaction, "presentation": "hotspots",
            "question": [{"type": "text", "text": "أين البئر؟"}],
            "visual": {"kind": "scene", "key": None, "version": None, "params": params, "image": None,
                       "scene": REF, "alt": "مخيم", "overlays": [],
                       "fallback_image": {"url": "https://cdn.qabas.app/media/f.webp", "mime_type": "image/webp",
                                          "width": 1600, "height": 1000},
                       "fallback_params": fallback_params if fallback_params is not None else params}}


def pin(pin_id: str, anchor_id: str, dx: float = 0, dy: float = 0) -> dict[str, Any]:
    anchor = next(a for a in MANIFEST["anchors"] if a["anchor_id"] == anchor_id)
    return {"pin_id": pin_id, "anchor_id": anchor_id, "label": anchor_id, "radius_pct": None,
            "x_pct": 100 * (anchor["x"] + dx) / 1600, "y_pct": 100 * (anchor["y"] + dy) / 1000}


PINS = [pin("p1", "well"), pin("p2", "palm"), pin("p3", "tent")]


def test_pins_on_their_anchors_are_accepted() -> None:
    scenes.bindings(MANIFEST, {"payload": exercise(PINS)}, REF)


def test_a_pin_moved_off_its_anchor_is_rejected_even_with_the_same_proportion() -> None:
    moved = [pin("p1", "well", dx=200), *PINS[1:]]
    with pytest.raises(MediaInvalid, match="outside its static anchor radius"):
        scenes.bindings(MANIFEST, {"payload": exercise(moved)}, REF)
    with pytest.raises(MediaInvalid, match="no static manifest anchor"):
        scenes.bindings(MANIFEST, {"payload": exercise([{**PINS[0], "anchor_id": "door"}, *PINS[1:]])}, REF)


def test_a_state_rule_or_track_moving_an_anchored_layer_is_rejected() -> None:
    manifest = copy.deepcopy(MANIFEST)
    well = next(layer for layer in manifest["layers"] if layer["id"] == "well")
    well["state_rules"] = [{"when": {"focus": {"eq": 0}}, "set": {"x": 300}, "transition_ms": 300}]
    assert any("changes position by state" in error for error in scenes.validate(manifest, {}))
    tracked = copy.deepcopy(MANIFEST)
    body = next(layer for layer in tracked["layers"] if layer["id"] == "well")["children"][0]
    body["tracks"] = [{"property": "translate_x", "duration_ms": 1000, "easing": "linear", "loop": "ping_pong",
                       "keyframes": [{"t": 0, "v": 0}, {"t": 1, "v": 400}]}]
    assert any("beyond the decorative limit" in error for error in scenes.validate(tracked, {}))


def test_a_fallback_rendered_at_another_state_is_rejected() -> None:
    body = exercise(PINS, params={"beat": 1, "focus": -1}, fallback_params={"beat": 0, "focus": -1})
    with pytest.raises(ValidationError, match="authored state"):
        C.PMapPlace.model_validate({k: v for k, v in body.items() if k != "type"})


@pytest.mark.parametrize("change", [{"focus": 9}, {"lighting": 1}, {"beat": -1}])
def test_unknown_or_out_of_range_bindings_are_rejected(change: dict[str, Any]) -> None:
    interaction = {"bindings": [{"pin_id": "p1", "set": change}], "reset_on_deselect": True,
                   "after_evaluation": None}
    with pytest.raises(MediaInvalid):
        scenes.bindings(MANIFEST, {"payload": exercise(PINS, interaction=interaction)}, REF)
    after = {"bindings": [], "reset_on_deselect": False, "after_evaluation": {"correct": change, "incorrect": None}}
    with pytest.raises(MediaInvalid):
        scenes.bindings(MANIFEST, {"payload": exercise(PINS, interaction=after)}, REF)
