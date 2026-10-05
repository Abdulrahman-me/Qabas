"""Bounded stdio bridge to an explicitly approved, digest-pinned renderer executable.

This is an integration interface, not a claim that the external Flutter scene_preview tool has been delivered.
The bridge launcher maps this JSON protocol to that tool. CI uses a synthetic launcher; no secrets are inherited.
"""

from __future__ import annotations

import asyncio
import base64
import json
import os
from collections.abc import Sequence
from pathlib import Path
from typing import Any

from pydantic import BaseModel, ConfigDict, Field

from app.config import Settings
from app.media.errors import MediaInvalid, MediaNotConfigured, MediaUnavailable
from app.media.objects import encode
from app.media.policy import POLICY, approved, policy
from app.media.types import RenderedFile, RenderedScene, ScenePreviewer


class Frame(BaseModel):
    model_config = ConfigDict(extra="forbid")
    name: str
    data_base64: str
    mime_type: str
    width: int = Field(gt=0, le=4096)
    height: int = Field(gt=0, le=4096)
    state: dict[str, Any]
    time_ms: int = Field(ge=0)
    reduced_motion: bool


class Output(BaseModel):
    model_config = ConfigDict(extra="forbid")
    files: list[Frame] = Field(min_length=1, max_length=500)
    animation_base64: str
    duration_ms: int = Field(gt=0, le=30000)
    renderer_version: str
    timing: dict[str, Any]
    normative: bool
    evidence: dict[str, Any]


class CommandPreviewer:
    def __init__(
        self,
        argv: list[str],
        *,
        timeout: float,
        executable_sha256: str,
        renderer_version: str,
        launcher_sha256: str | None = None,
    ) -> None:
        from app.services.platform.storage import sha256_hex

        if not argv or len(argv) > 10 or not all(isinstance(arg, str) and arg for arg in argv):
            raise MediaNotConfigured("scene preview command must be a bounded argv list")
        executable = Path(argv[0])
        if not executable.is_absolute() or not executable.is_file():
            raise MediaNotConfigured("scene preview executable must exist at an absolute path")
        if sha256_hex(executable.read_bytes()) != executable_sha256:
            raise MediaNotConfigured("scene preview executable differs from its approved digest")
        if launcher_sha256:
            if len(argv) != 2 or not Path(argv[1]).is_absolute() or not Path(argv[1]).is_file():
                raise MediaNotConfigured("scene preview bridge must be one approved launcher")
            if sha256_hex(Path(argv[1]).read_bytes()) != launcher_sha256:
                raise MediaNotConfigured("scene preview bridge differs from its approved digest")
        self.argv, self.timeout, self.renderer_version = argv, timeout, renderer_version
        self.executable_sha256, self.launcher_sha256 = executable_sha256, launcher_sha256

    async def render(
        self, manifest: dict[str, Any], assets: dict[str, bytes], states: Sequence[dict[str, Any]]
    ) -> RenderedScene:
        from app.services.platform.storage import sha256_hex
        if sha256_hex(Path(self.argv[0]).read_bytes()) != self.executable_sha256 or (
                self.launcher_sha256 and sha256_hex(Path(self.argv[1]).read_bytes()) != self.launcher_sha256):
            raise MediaNotConfigured("scene renderer executable/bridge changed since its approval")
        payload = encode(
            {
                "schema": "qabas.scene_preview_bridge/1",
                "manifest": manifest,
                "states": list(states),
                "assets": {url: base64.b64encode(raw).decode() for url, raw in assets.items()},
            }
        )
        if len(payload) > 25_000_000:
            raise MediaInvalid("scene preview input exceeds its byte limit")
        env = {
            key: value for key, value in os.environ.items() if key.upper() in {"SYSTEMROOT", "WINDIR", "TEMP", "TMP"}
        }
        process = await asyncio.create_subprocess_exec(
            *self.argv,
            stdin=asyncio.subprocess.PIPE,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.DEVNULL,
            env=env,
            creationflags=0x08000000 if os.name == "nt" else 0,  # CREATE_NO_WINDOW for worker helper processes
        )
        assert process.stdin is not None and process.stdout is not None

        async def exchange() -> bytes:
            async def send() -> None:
                assert process.stdin is not None
                process.stdin.write(payload)
                await process.stdin.drain()
                process.stdin.close()

            sending = asyncio.create_task(send())
            try:
                body = bytearray()
                assert process.stdout is not None
                while chunk := await process.stdout.read(65536):
                    body.extend(chunk)
                    if len(body) > 25_000_000:
                        raise MediaInvalid("scene preview output exceeds its byte limit")
                await sending
                await process.wait()
                if process.returncode != 0:
                    raise MediaUnavailable("scene preview process failed")
                return bytes(body)
            finally:
                if not sending.done():
                    sending.cancel()
                    await asyncio.gather(sending, return_exceptions=True)

        try:
            raw = await asyncio.wait_for(exchange(), self.timeout)
        except TimeoutError as exc:
            raise MediaUnavailable("scene preview process timed out") from exc
        finally:
            if process.returncode is None:
                process.kill()
                await process.wait()
        try:
            value = Output.model_validate_json(raw)
            if value.renderer_version != self.renderer_version:
                raise MediaInvalid("preview renderer version differs from its approved identity")
            files = tuple(
                RenderedFile(
                    file.name,
                    base64.b64decode(file.data_base64, validate=True),
                    file.mime_type,
                    file.width,
                    file.height,
                    file.state,
                    file.time_ms,
                    file.reduced_motion,
                )
                for file in value.files
            )
            animation = base64.b64decode(value.animation_base64, validate=True)
        except ValueError as exc:
            raise MediaInvalid("scene preview returned malformed output") from exc
        return RenderedScene(
            files, animation, value.duration_ms, value.renderer_version, value.timing, value.normative, value.evidence
        )


def configured(settings: Settings) -> ScenePreviewer:
    if settings.scene_preview_command is None:
        from app.media.preview import InspectionPreviewer

        return InspectionPreviewer()
    document = policy(settings.media_policy_path or POLICY)
    if document.get("fixture_only") and not settings.is_dev_like:
        raise MediaNotConfigured("synthetic renderer approval cannot enable production or staging")
    entry = document.get("renderer", {})
    approved(entry, "normative scene preview renderer/release")
    try:
        argv = json.loads(settings.scene_preview_command)
        return CommandPreviewer(
            argv,
            timeout=settings.media_timeout_seconds,
            executable_sha256=entry["executable_sha256"],
            renderer_version=entry["renderer_version"],
            launcher_sha256=entry.get("launcher_sha256"),
        )
    except (ValueError, KeyError, TypeError) as exc:
        raise MediaNotConfigured("invalid scene preview bridge configuration") from exc
