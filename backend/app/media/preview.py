"""Asset-bearing inspection renderer. Never evidence of Flutter parity or a capability release.

The injectable ScenePreviewer boundary is shared by this renderer and the future normative Flutter CLI.
Authoring still uses the full contract grammar. Inspection renders are explicitly preview_only at publication.
"""

from __future__ import annotations

import asyncio
import base64
import io
import math
import time
from collections.abc import Sequence
from fractions import Fraction
from typing import Any
from xml.sax.saxutils import escape

import av
import resvg_py
from PIL import Image

from app.media import scenes
from app.media.codecs import webp
from app.media.errors import MediaInvalid
from app.media.types import RenderedFile, RenderedScene


def inspection_svg(
    manifest: dict[str, Any], assets: dict[str, bytes], state: dict[str, Any], ms: int, reduced: bool = False
) -> str:
    helper = scenes.checker()
    definitions: list[str] = []
    palette = manifest["palette"]
    values = {name: item["default"] for name, item in manifest["states"].items()} | state
    clock = manifest["reduced_motion"]["still_time_ms"] if reduced else ms
    layers = {layer["id"]: layer for layer in helper.walk(manifest["layers"])}

    def color(token: str) -> str:
        value: str = palette[token]
        if value.startswith("token:"):
            raise MediaInvalid("inspection renderer needs resolved release design tokens")
        return escape(value, {'"': "&quot;"})

    def paint(fill: Any, name: str) -> str:
        if not fill:
            return "none"
        if isinstance(fill, str):
            return color(fill)
        stops = "".join(f'<stop offset="{s["at"]}" stop-color="{color(s["color"])}"/>' for s in fill["stops"])
        if fill["gradient"] == "linear":
            (x1, y1), (x2, y2) = fill["from"], fill["to"]
            definitions.append(
                f'<linearGradient id="{name}" gradientUnits="userSpaceOnUse" '
                f'x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">{stops}</linearGradient>'
            )
        else:
            cx, cy = fill["center"]
            definitions.append(
                f'<radialGradient id="{name}" gradientUnits="userSpaceOnUse" '
                f'cx="{cx}" cy="{cy}" r="{fill["radius"]}">{stops}</radialGradient>'
            )
        return f"url(#{name})"

    def geometry(layer: dict[str, Any], fill: str, stroke: str = "") -> str:
        kind = layer["type"]
        if kind == "rect":
            corner = min(layer.get("corner", 0), layer["w"] / 2, layer["h"] / 2)
            return (
                f'<rect x="{layer["x"]}" y="{layer["y"]}" width="{layer["w"]}" height="{layer["h"]}" '
                f'rx="{corner}" fill="{fill}" {stroke}/>'
            )
        if kind == "ellipse":
            return (
                f'<ellipse cx="{layer["x"]}" cy="{layer["y"]}" rx="{layer["rx"]}" ry="{layer["ry"]}" '
                f'fill="{fill}" {stroke}/>'
            )
        if kind == "path":
            return f'<path d="{escape(layer["d"])}" fill="{fill}" {stroke}/>'
        if kind == "asset":
            asset = next(a for a in manifest["assets"] if a["asset_id"] == layer["asset_id"])
            raw = assets[asset["url"]]
            encoded = base64.b64encode(raw).decode()
            return (
                f'<image href="data:{asset["mime_type"]};base64,{encoded}" x="{layer["x"]}" '
                f'y="{layer["y"]}" width="{layer["w"]}" height="{layer["h"]}"/>'
            )
        return ""

    def node(layer: dict[str, Any]) -> str:
        props = {
            "opacity": layer.get("opacity", 1),
            **{
                key: layer.get("transform", {}).get(key, default)
                for key, default in (("x", 0), ("y", 0), ("rotation", 0), ("scale", 1))
            },
        }
        fill = layer.get("fill")
        for rule in layer.get("state_rules", []):
            if helper.holds(rule["when"], values):
                for key, value in rule["set"].items():
                    if key == "fill":
                        fill = value
                    else:
                        props[key] = value
        # Reduced motion samples tracks at the specified still time; it does not drop them.
        for track in layer.get("tracks", []):
            if track.get("active_when") and not helper.holds(track["active_when"], values):
                continue
            value = helper.track_value(track, clock)
            prop = track["property"]
            if prop in {"translate_x", "translate_y", "rotation"}:
                props[{"translate_x": "x", "translate_y": "y"}.get(prop, prop)] += value
            else:
                props[prop] *= value
        props["opacity"] = min(1, max(0, props["opacity"]))
        ox, oy = (layer.get("transform", {}).get(key, 0) for key in ("origin_x", "origin_y"))
        transform = (
            f"translate({props['x']},{props['y']}) translate({ox},{oy}) "
            f"rotate({props['rotation']}) scale({props['scale']}) translate({-ox},{-oy})"
        )
        stroke = layer.get("stroke")
        stroke_attr = (
            (
                f'stroke="{color(stroke)}" stroke-width="{layer.get("stroke_width", 1)}" '
                'stroke-linecap="round" stroke-linejoin="round"'
            )
            if stroke
            else ""
        )
        if layer["type"] == "group":
            inner = "".join(node(child) for child in layer.get("children", []))
        elif layer["type"] == "sparkles":
            seed = layer["seed"] & 0xFFFFFFFF
            circles = []

            def random_value() -> float:
                nonlocal seed
                seed = (1664525 * seed + 1013904223) & 0xFFFFFFFF
                return float(seed) / 4294967296

            for _ in range(layer["count"]):
                x = layer["x"] + random_value() * layer["w"]
                y = layer["y"] + random_value() * layer["h"]
                phase = random_value()
                alpha = 0.4 + 0.6 * abs(math.sin(math.pi * (clock / 2000 + phase)))
                circles.append(
                    f'<circle cx="{x}" cy="{y}" r="{2 + 2 * phase}" '
                    f'fill="{paint(fill, layer["id"])}" opacity="{alpha}"/>'
                )
            inner = "".join(circles)
        else:
            inner = geometry(layer, paint(fill, f"paint_{layer['id']}"), stroke_attr)
        if layer.get("clip"):
            reference = layer["clip"]
            source = layers[reference] if isinstance(reference, str) else layers[reference["layer_id"]]
            clip_id = f"clip_{layer['id']}"
            definitions.append(f'<clipPath id="{clip_id}">{geometry(source, "white")}</clipPath>')
            inner = f'<g clip-path="url(#{clip_id})">{inner}</g>'
        return f'<g transform="{transform}" opacity="{props["opacity"]}">{inner}</g>'

    body = "".join(node(layer) for layer in manifest["layers"])
    box = manifest["view_box"]
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{box["width"]}" height="{box["height"]}" '
        f'viewBox="0 0 {box["width"]} {box["height"]}"><defs>{"".join(definitions)}</defs>{body}</svg>'
    )


class InspectionPreviewer:
    async def render(
        self, manifest: dict[str, Any], assets: dict[str, bytes], states: Sequence[dict[str, Any]]
    ) -> RenderedScene:
        return await asyncio.to_thread(self._render, manifest, assets, states)

    def _render(
        self, manifest: dict[str, Any], assets: dict[str, bytes], states: Sequence[dict[str, Any]]
    ) -> RenderedScene:
        found = scenes.validate(manifest, assets)
        if found:
            raise MediaInvalid("invalid inspection scene: " + "; ".join(found[:10]))
        box = manifest["view_box"]
        width = 1600
        height = round(width * box["height"] / box["width"])
        if height > 4096 or len(states) > 100:
            raise MediaInvalid("inspection preview exceeds its bounds")
        files = []
        elapsed = []

        def pixels(state: dict[str, Any], ms: int, reduced: bool) -> bytes:
            started = time.perf_counter()
            svg = inspection_svg(manifest, assets, state, ms, reduced)
            raw = resvg_py.svg_to_bytes(svg_string=svg, width=width, height=height, skip_system_fonts=True)
            elapsed.append((time.perf_counter() - started) * 1000)
            return webp(raw, "image/png", width, height, native=(width, height))

        for index, state in enumerate(states):
            scenes.state(manifest, state)
            for ms in manifest["preview"]["frames_ms"]:
                files.append(
                    RenderedFile(
                        f"frame_{index}_{ms}", pixels(state, ms, False), "image/webp", width, height, state, ms, False
                    )
                )
            still = manifest["reduced_motion"]["still_time_ms"]
            files.append(
                RenderedFile(
                    f"fallback_{index}", pixels(state, still, True), "image/webp", width, height, state, still, True
                )
            )
        output = io.BytesIO()
        rate, duration = 12, min(12000, max(2000, len(states) * 2000))
        with av.open(output, "w", format="webm") as container:
            stream = container.add_stream("libvpx-vp9", rate=rate)
            stream.width, stream.height, stream.pix_fmt = 800, round(height / 2), "yuv420p"
            stream.height += stream.height % 2
            stream.options = {"deadline": "realtime", "cpu-used": "8", "crf": "35"}
            for index in range(round(duration * rate / 1000)):
                ms = round(index * 1000 / rate)
                selected = states[min(len(states) - 1, ms * len(states) // duration)]
                raw = pixels(selected, ms, False)
                with Image.open(io.BytesIO(raw)) as image:
                    frame = av.VideoFrame.from_image(image.resize((stream.width, stream.height)))  # type: ignore[no-untyped-call]
                frame.pts, frame.time_base = index, Fraction(1, rate)
                for packet in stream.encode(frame):
                    container.mux(packet)
            for packet in stream.encode(None):
                container.mux(packet)
        ordered = sorted(elapsed)
        return RenderedScene(
            tuple(files),
            output.getvalue(),
            duration,
            f"inspection/resvg-{resvg_py.__version__};non-normative/1",
            {
                "build_raster_p95_ms": ordered[math.ceil(len(ordered) * 0.95) - 1],
                "first_frame_ms": elapsed[0],
                "device": "backend inspection; not Flutter reference-device evidence",
            },
            False,
            {
                "inspection_only": True,
                "transitions": "state cuts; not normative transition/parity evidence",
                "anchor_visibility": "unverified",
                "fallback_equality": "inspection pixels only",
            },
        )
