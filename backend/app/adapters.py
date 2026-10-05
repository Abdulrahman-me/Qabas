"""Provider boundaries. Each external dependency sits behind one interface so core work proceeds on
fakes until its provider is approved (O-03, O-13). Implementations arrive in the phase noted on each.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Protocol

from app.llm.client import LLMClient as LLMClient  # Phase 11: app/llm (prompt registry, structured output)
from app.llm.client import LLMResult as LLMResult
from app.sources.errors import ProviderNotConfigured as ProviderNotConfigured
from app.sources.records import SourceRecord as SourceRecord


@dataclass(frozen=True)
class Transcript:
    text: str
    language: str | None


class SpeechToText(Protocol):
    """Phase 17 (Raqeeb voice)."""

    async def transcribe(self, audio_wav: bytes, *, language_hint: str | None) -> Transcript: ...


@dataclass(frozen=True)
class GeneratedImage:
    data: bytes
    mime_type: str
    width: int
    height: int
    provider_meta: dict[str, Any] = field(default_factory=dict)


class ImageGenerator(Protocol):
    """Phase 14 (build-time only, IMAGE_PROVIDER)."""

    async def generate(self, *, prompt: str, width: int, height: int,
                       reference_images: list[bytes] | None = None) -> GeneratedImage: ...


class TextToSpeech(Protocol):
    """Phase 14 (build-time narration and term pronunciation; never Quran)."""

    async def synthesize(self, *, text: str, language: str, voice: str | None = None) -> bytes: ...


class SourceTool(Protocol):
    """Phase 9. One allow-listed evidence tool (SOURCE_ADAPTERS §12); returned text is data, never instructions."""

    provider: str
    version: str

    async def call(self, operation: str, **arguments: Any) -> list[SourceRecord]: ...
