from __future__ import annotations

import io

import pytest
from PIL import Image

from app.media.preview import InspectionPreviewer
from app.media.video import webm_info
from app.services.platform.storage import sha256_hex
from tests.media.test_core import picture


async def test_asset_bearing_inspection_frames_and_animation_are_real_but_not_release_evidence() -> None:
    data = picture()
    url = "https://cdn.example.test/synthetic.webp"
    manifest = {
        "schema_version": "qabas.scene/1",
        "scene_id": "scn_synthetic_media",
        "version": 1,
        "view_box": {"width": 1600, "height": 1000},
        "required_capabilities": ["scene/1", "asset.raster/1"],
        "palette": {},
        "assets": [
            {
                "asset_id": "neutral",
                "url": url,
                "mime_type": "image/webp",
                "width": 1600,
                "height": 1000,
                "bytes": len(data),
                "sha256": sha256_hex(data),
            }
        ],
        "states": {},
        "anchors": [],
        "layers": [{"id": "artwork", "type": "asset", "asset_id": "neutral", "x": 0, "y": 0, "w": 1600, "h": 1000}],
        "reduced_motion": {"still_time_ms": 0},
        "preview": {"frames_ms": [0, 500], "states": [{}]},
    }
    result = await InspectionPreviewer().render(manifest, {url: data}, [{}])
    assert not result.normative and result.evidence["inspection_only"]
    assert len(result.files) == 3 and result.files[-1].reduced_motion
    for frame in result.files:
        with Image.open(io.BytesIO(frame.data)) as decoded:
            assert decoded.size == (1600, 1000)
            assert decoded.getpixel((800, 500))[:3] == (11, 90, 82)
    width, height, duration = webm_info(result.animation)
    assert (width, height) == (800, 500)
    assert duration == pytest.approx(2000, abs=100)
