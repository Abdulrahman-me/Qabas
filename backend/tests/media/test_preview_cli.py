from __future__ import annotations

import base64
import json
import sys
from pathlib import Path
from typing import Any

import pytest

from app.media.errors import MediaInvalid, MediaNotConfigured, MediaUnavailable
from app.media.preview_cli import CommandPreviewer
from app.services.platform.storage import sha256_hex
from tests.media.test_core import picture


def bridge(tmp_path: Path, mode: str = "valid") -> CommandPreviewer:
    output = {
        "files": [
            {
                "name": "synthetic",
                "data_base64": base64.b64encode(picture()).decode(),
                "mime_type": "image/webp",
                "width": 1600,
                "height": 1000,
                "state": {},
                "time_ms": 0,
                "reduced_motion": True,
            }
        ],
        "animation_base64": "Zml4dHVyZQ==",
        "duration_ms": 1,
        "renderer_version": "synthetic/1",
        "timing": {},
        "normative": False,
        "evidence": {},
    }
    code = "import json, os, sys, time\nrequest=json.load(sys.stdin)\n"
    code += "assert request['schema']=='qabas.scene_preview_bridge/1'\n"
    code += "assert 'OPENAI_API_KEY' not in os.environ and 'ANTHROPIC_API_KEY' not in os.environ\n"
    if mode == "timeout":
        code += "time.sleep(10)\n"
    elif mode == "invalid":
        code += "print('not JSON')\n"
    else:
        code += f"print({json.dumps(json.dumps(output))})\n"
    launcher = tmp_path / "synthetic.py"
    launcher.write_text(code)
    return CommandPreviewer(
        [sys.executable, str(launcher)],
        timeout=1 if mode == "timeout" else 10,
        executable_sha256=sha256_hex(Path(sys.executable).read_bytes()),
        renderer_version="synthetic/1",
        launcher_sha256=sha256_hex(launcher.read_bytes()),
    )


async def test_stdio_bridge_passes_verified_assets_without_credentials(tmp_path: Path, monkeypatch: Any) -> None:
    monkeypatch.setenv("OPENAI_API_KEY", "test-secret-must-not-cross-process")
    monkeypatch.setenv("ANTHROPIC_API_KEY", "test-secret-must-not-cross-process")
    result = await bridge(tmp_path).render({}, {"https://cdn.qabas.app/fixture": picture()}, [{}])
    assert not result.normative and result.files[0].data == picture()


@pytest.mark.parametrize("mode,error", [("invalid", MediaInvalid), ("timeout", MediaUnavailable)])
async def test_stdio_bridge_is_bounded_and_malformed_output_is_rejected(tmp_path: Path, mode: str, error: Any) -> None:
    with pytest.raises(error):
        await bridge(tmp_path, mode).render({}, {}, [{}])


async def test_modified_renderer_launcher_is_rejected_before_execution(tmp_path: Path) -> None:
    previewer = bridge(tmp_path)
    Path(previewer.argv[1]).write_text("raise RuntimeError('should never execute')")
    with pytest.raises(MediaNotConfigured, match="changed"):
        await previewer.render({}, {}, [{}])
