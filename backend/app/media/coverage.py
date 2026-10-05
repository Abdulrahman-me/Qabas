"""Required preview states and exact renderer output coverage (Factory 13.8.4)."""

from __future__ import annotations

import json
from typing import Any

from app.content.package import content_digest
from app.media import scenes
from app.media.codecs import raster
from app.media.errors import MediaInvalid
from app.media.types import RenderedScene


def requested(manifest: dict[str, Any], occurrences: list[dict[str, Any]], content: Any) -> list[dict[str, Any]]:
    states = list(manifest["preview"]["states"])
    for item in occurrences:
        params = json.loads(item["params_json"])
        states.append(params)
        states.extend({**params, **json.loads(raw)} for raw in item["point_params_json"] or [])

    def walk(node: Any) -> None:
        if isinstance(node, dict):
            visual = node.get("visual", {})
            if isinstance(visual, dict) and (visual.get("scene") or {}).get("scene_id") == manifest["scene_id"]:
                params = visual["params"]
                states.append(params)
                interaction = node.get("interaction") or {}
                states.extend({**params, **binding["set"]} for binding in interaction.get("bindings", []))
                states.extend(
                    {**params, **value}
                    for value in (interaction.get("after_evaluation") or {}).values()
                    if value is not None
                )
            for value in node.values():
                walk(value)
        elif isinstance(node, list):
            for value in node:
                walk(value)

    walk(content)
    unique = {content_digest(value): value for value in states}
    for value in unique.values():
        scenes.state(manifest, value)
    return list(unique.values())


def validate(manifest: dict[str, Any], states: list[dict[str, Any]], rendered: RenderedScene) -> None:
    expected = {(content_digest(s), t, False) for s in states for t in manifest["preview"]["frames_ms"]}
    expected |= {(content_digest(s), manifest["reduced_motion"]["still_time_ms"], True) for s in states}
    actual = set()
    names = set()
    for frame in rendered.files:
        identity = (content_digest(frame.state), frame.time_ms, frame.reduced_motion)
        if identity in actual or frame.name in names:
            raise MediaInvalid("scene renderer returned duplicate preview frames")
        actual.add(identity)
        names.add(frame.name)
        if (frame.width, frame.height) != (manifest["view_box"]["width"], manifest["view_box"]["height"]):
            raise MediaInvalid("scene preview dimensions differ from the manifest view box")
        raster(frame.data, frame.mime_type, frame.width, frame.height)
    if actual != expected:
        raise MediaInvalid("scene renderer did not cover every required state/time and aligned fallback")
    if rendered.normative:
        timing = rendered.timing
        p95, first = timing.get("build_raster_p95_ms"), timing.get("first_frame_ms")
        if (
            not isinstance(p95, (int, float))
            or not isinstance(first, (int, float))
            or not 0 <= p95 <= 8
            or not 0 <= first <= 150
            or not timing.get("device")
        ):
            raise MediaInvalid("normative renderer lacks passing reference-device performance evidence")
        if not rendered.evidence.get("anchor_visibility_passed") or not rendered.evidence.get(
            "fallback_equality_passed"
        ):
            raise MediaInvalid("normative renderer lacks anchor visibility and fallback equality evidence")
