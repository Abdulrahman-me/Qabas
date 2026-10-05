"""The revision 10 scene grammar is the single authoring/publication authority."""

from __future__ import annotations

import copy
import importlib.util
import json
import math
import tempfile
from pathlib import Path
from typing import Any

from app.contract import CONTRACT_DIR, TOOLS_DIR
from app.media.errors import MediaInvalid
from app.media.objects import encode

REGISTRY_PATH = CONTRACT_DIR / "scene_capabilities.production.json"


def checker() -> Any:
    spec = importlib.util.spec_from_file_location("qabas_media_scene_checker", TOOLS_DIR / "scene_check.py")
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def registry() -> dict[str, Any]:
    value: dict[str, Any] = json.loads(REGISTRY_PATH.read_text("utf-8"))
    return value


def released() -> list[str]:
    return [c["id"] for c in registry()["capabilities"] if c["status"] == "released" and c.get("release_evidence")]


def validate(manifest: dict[str, Any], assets: dict[str, bytes], *, publication: bool = False) -> list[str]:
    reg = registry()
    if not publication:
        # Authoring may use the entire final grammar. This never changes the publication registry or claims release.
        reg = copy.deepcopy(reg)
        for item in reg["capabilities"]:
            item["status"] = "released"
    with tempfile.TemporaryDirectory(prefix="qabas-scene-check-") as directory:
        files = {}
        for index, (url, raw) in enumerate(assets.items()):
            path = Path(directory) / str(index)
            path.write_bytes(raw)
            files[url] = path
        result: list[str] = checker().check(
            manifest, encode(manifest), asset_files=files, publication=publication, registry=reg
        )
    return result


def state(manifest: dict[str, Any], params: dict[str, Any]) -> None:
    definitions = manifest["states"]
    if set(params) - set(definitions):
        raise MediaInvalid("scene occurrence contains an unknown state")
    for name, item in definitions.items():
        value = params.get(name, item["default"])
        kind = item["type"]
        if kind == "bool" and not isinstance(value, bool):
            raise MediaInvalid(f"scene state {name} must be a boolean")
        if kind == "enum" and value not in item["values"]:
            raise MediaInvalid(f"scene state {name} is not in its declared enum")
        if kind == "int" and (
            isinstance(value, bool) or not isinstance(value, int) or not item["min"] <= value <= item["max"]
        ):
            raise MediaInvalid(f"scene state {name} is outside its integer bounds")


def bindings(manifest: dict[str, Any], node: Any, expected_ref: dict[str, Any]) -> None:
    """Every occurrence uses the actual manifest identity and declared states/static graded anchors."""
    def walk(value: Any) -> None:
        if isinstance(value, dict):
            visual = value.get("visual", value if value.get("kind") == "scene" else {})
            ref = visual.get("scene") if isinstance(visual, dict) else None
            if isinstance(ref, dict) and (ref["scene_id"], ref["version"]) == (
                    expected_ref["scene_id"], expected_ref["version"]):
                if ref != expected_ref:
                    raise MediaInvalid("SceneRef metadata differs from the actual reviewed manifest")
                params = visual["params"]
                state(manifest, params)
                for point in value.get("points", []):
                    if point.get("visual_params") is not None:
                        state(manifest, {**params, **point["visual_params"]})
                interaction = value.get("interaction") or {}
                for binding in interaction.get("bindings", []):
                    state(manifest, {**params, **binding["set"]})
                for change in (interaction.get("after_evaluation") or {}).values():
                    if change is not None:
                        state(manifest, {**params, **change})
                anchors = {a["anchor_id"]: a for a in manifest["anchors"]}
                for pin in value.get("pins", []):
                    anchor = anchors.get(pin["anchor_id"])
                    if anchor is None:
                        raise MediaInvalid("graded hotspot has no static manifest anchor")
                    x = pin["x_pct"] * manifest["view_box"]["width"] / 100
                    y = pin["y_pct"] * manifest["view_box"]["height"] / 100
                    if math.hypot(x - anchor["x"], y - anchor["y"]) > anchor["radius"]:
                        raise MediaInvalid("graded hotspot is outside its static anchor radius")
            for child in value.values():
                walk(child)
        elif isinstance(value, list):
            for child in value:
                walk(child)
    walk(node)
