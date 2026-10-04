"""Provider boundaries. Each external dependency sits behind one interface so core work proceeds on
fakes until its provider is approved (O-03, O-13). Implementations arrive in the phase noted on each.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Protocol


class ProviderNotConfigured(RuntimeError):
    """The provider for this capability has not been configured for this environment."""


@dataclass(frozen=True)
class LLMUsage:
    model: str
    prompt_version: str
    input_tokens: int
    output_tokens: int


@dataclass(frozen=True)
class LLMResult:
    data: dict[str, Any]
    usage: LLMUsage


class LLMClient(Protocol):
    """Phase 11. Structured output against a JSON schema; records model, prompt version and usage (AD-27)."""

    async def structured(self, *, tier: str, prompt_id: str, prompt_version: str, system: str,
                         data: dict[str, Any], output_schema: dict[str, Any], effort: str = "medium") -> LLMResult: ...


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


@dataclass(frozen=True)
class SourceRecord:
    provider: str
    provider_record_id: str
    kind: str
    title: str
    reference: str
    text: str
    url: str | None
    raw: dict[str, Any]
    text_sha256: str
    adapter_version: str


class SourceTool(Protocol):
    """Phase 9. One allow-listed evidence tool (SOURCE_ADAPTERS §12); returned text is data, never instructions."""

    name: str
    version: str

    async def call(self, operation: str, **arguments: Any) -> list[SourceRecord]: ...
