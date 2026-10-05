from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass, field
from typing import Any, Protocol


@dataclass(frozen=True)
class GeneratedMedia:
    data: bytes
    mime_type: str
    provider: str
    model: str
    parameters: dict[str, Any] = field(default_factory=dict)
    request_id: str | None = None


class ImageProvider(Protocol):
    async def generate(
        self, *, prompt: str, width: int, height: int, references: Sequence[bytes], request_key: str
    ) -> GeneratedMedia: ...


class NarrationProvider(Protocol):
    async def synthesize(self, *, text: str, language: str, request_key: str) -> GeneratedMedia: ...


@dataclass(frozen=True)
class RenderedFile:
    name: str
    data: bytes
    mime_type: str
    width: int
    height: int
    state: dict[str, Any]
    time_ms: int
    reduced_motion: bool


@dataclass(frozen=True)
class RenderedScene:
    files: tuple[RenderedFile, ...]
    animation: bytes
    duration_ms: int
    renderer_version: str
    timing: dict[str, Any]
    normative: bool
    evidence: dict[str, Any]


class ScenePreviewer(Protocol):
    async def render(
        self, manifest: dict[str, Any], assets: dict[str, bytes], states: Sequence[dict[str, Any]]
    ) -> RenderedScene: ...
