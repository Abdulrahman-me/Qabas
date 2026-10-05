from __future__ import annotations

from dataclasses import replace
from typing import Any

import pytest

from app.media import coverage
from app.media.errors import MediaInvalid
from app.media.types import RenderedFile, RenderedScene
from tests.media.test_core import picture


def manifest() -> dict[str, Any]:
    return {"scene_id": "scn_test", "view_box": {"width": 1600, "height": 1000},
            "states": {"focus": {"type": "int", "min": -1, "max": 2, "default": -1}},
            "preview": {"states": [{"focus": -1}], "frames_ms": [0, 500]},
            "reduced_motion": {"still_time_ms": 0}}


def test_required_states_include_points_bindings_and_both_evaluation_outcomes() -> None:
    states = coverage.requested(manifest(), [{"params_json": '{"focus": -1}',
        "point_params_json": ['{"focus": 0}']}], {"visual": {"scene": {"scene_id": "scn_test"},
        "params": {"focus": -1}}, "interaction": {"bindings": [{"set": {"focus": 1}}],
        "after_evaluation": {"correct": {"focus": 2}, "incorrect": None}}})
    assert states == [{"focus": -1}, {"focus": 0}, {"focus": 1}, {"focus": 2}]


@pytest.mark.parametrize("corruption", ["missing", "duplicate", "wrong_time", "wrong_pixels", "normative_claim"])
def test_renderer_cannot_substitute_incomplete_or_unverified_previews(corruption: str) -> None:
    files = tuple(RenderedFile(str(i), picture(), "image/webp", 1600, 1000, {"focus": -1}, t, reduced)
                  for i, (t, reduced) in enumerate([(0, False), (500, False), (0, True)]))
    rendered = RenderedScene(files, b"not used in coverage check", 1, "inspection", {}, False, {})
    coverage.validate(manifest(), [{"focus": -1}], rendered)
    if corruption == "missing":
        rendered = replace(rendered, files=files[:-1])
    elif corruption == "duplicate":
        rendered = replace(rendered, files=(*files, files[0]))
    elif corruption == "wrong_time":
        rendered = replace(rendered, files=(*files[:2], replace(files[2], time_ms=1)))
    elif corruption == "wrong_pixels":
        rendered = replace(rendered, files=(replace(files[0], data=b"fake"), *files[1:]))
    else:
        rendered = replace(rendered, normative=True)
    with pytest.raises(MediaInvalid):
        coverage.validate(manifest(), [{"focus": -1}], rendered)
