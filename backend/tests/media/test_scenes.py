"""QUALITY §18.1 ``test_scenes.py``: the scene validator rejects unreleased capabilities, out-of-range states, limit
violations, a missing fallback and a wrong fallback proportion. Publication immutability of scene versions and
pinned sessions are covered at the database level (tests/db/test_constraints.py
``test_published_scene_version_and_assets_are_immutable``) and by the version-pinning tests."""

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


def visual(**changes: Any) -> dict[str, Any]:
    body = {"kind": "scene", "key": None, "version": None, "params": {"beat": 0, "focus": -1}, "image": None,
            "scene": {"scene_id": "scn_x", "version": 1, "schema_version": "qabas.scene/1",
                      "url": "https://cdn.qabas.app/media/scenes/scn_x/v1/m.scene.json",
                      "mime_type": "application/json", "sha256": "a" * 64,
                      "view_box": {"width": 1600, "height": 1000}, "required_capabilities": ["scene/1"]},
            "fallback_image": {"url": "https://cdn.qabas.app/media/f.webp", "mime_type": "image/webp",
                               "width": 1600, "height": 1000},
            "fallback_params": {"beat": 0, "focus": -1}, "alt": "مشهد", "overlays": []}
    return body | changes


def test_the_production_registry_releases_nothing_so_publication_validation_refuses_the_scene() -> None:
    assert scenes.released() == []                                     # O-02: no capability release yet
    found = scenes.validate(MANIFEST, {}, publication=True)
    assert any("released" in error or "proposed" in error for error in found), found
    authoring = scenes.validate(MANIFEST, {})                          # authoring checks the full grammar
    assert not any("released" in error or "proposed" in error for error in authoring)


@pytest.mark.parametrize("params", [{"beat": 3}, {"focus": -2}, {"beat": "1"}, {"weather": 1}])
def test_out_of_range_or_unknown_states_are_rejected(params: dict[str, Any]) -> None:
    with pytest.raises(MediaInvalid):
        scenes.state(MANIFEST, params)


def test_limit_violations_are_rejected() -> None:
    manifest = copy.deepcopy(MANIFEST)
    manifest["assets"] = [{**manifest["assets"][0], "asset_id": f"a{i}"} for i in range(12)]
    found = scenes.validate(manifest, {})
    assert found, "twelve assets exceed the schema's eight-asset limit"


def test_a_scene_visual_needs_its_fallback_and_the_view_box_proportion() -> None:
    C.Visual.model_validate(visual())
    with pytest.raises(ValidationError, match="fallback_image"):
        C.Visual.model_validate(visual(fallback_image=None))
    with pytest.raises(ValidationError, match="proportion"):
        C.Visual.model_validate(visual(fallback_image={"url": "https://cdn.qabas.app/media/f.webp",
                                                        "mime_type": "image/webp", "width": 1000, "height": 1000}))
    with pytest.raises(ValidationError, match="fallback_params"):
        C.Visual.model_validate(visual(fallback_params=None))
