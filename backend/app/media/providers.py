"""Opt-in OpenAI image/speech transports behind the build-time provider protocols.

No provider/model is approved here. Approval, exact model, dimensions and voices come from media policy.
Only embedded response bytes are accepted; no provider-supplied URL is downloaded.
"""

from __future__ import annotations

import asyncio
import base64
import binascii
import random
from collections.abc import Sequence
from typing import Any

import httpx

from app.config import Settings
from app.media.audio import mp3_duration
from app.media.codecs import raster, webp
from app.media.errors import MediaInvalid, MediaNotConfigured, MediaRefused, MediaUnavailable
from app.media.policy import POLICY, provider_policy
from app.media.types import GeneratedMedia
from app.sources.errors import UpstreamUnavailable
from app.sources.resilience import breaker_for


class MediaHTTP:
    def __init__(self, settings: Settings, kind: str, *, client: httpx.AsyncClient | None = None) -> None:
        if getattr(settings, f"{kind}_provider") != "openai":
            raise MediaNotConfigured(f"no transport is implemented for the selected {kind} provider")
        self.entry = provider_policy(settings, kind, settings.media_policy_path or POLICY)
        secret = getattr(settings, f"{kind}_api_key")
        if secret is None or not secret.get_secret_value() or not self.entry.get("model"):
            raise MediaNotConfigured(f"{kind} credentials/model are missing")
        self.headers = {"Authorization": f"Bearer {secret.get_secret_value()}"}
        self.client = client or httpx.AsyncClient(
            base_url="https://api.openai.com/v1/",
            timeout=httpx.Timeout(settings.media_timeout_seconds, connect=5),
            follow_redirects=False,
        )
        self.breaker = breaker_for(f"media_openai_{kind}")

    async def aclose(self) -> None:
        await self.client.aclose()

    async def post(self, path: str, **kwargs: Any) -> httpx.Response:
        try:
            self.breaker.before_call()
        except UpstreamUnavailable as exc:
            raise MediaUnavailable("media provider circuit is open") from exc
        try:
            for attempt in range(3):
                try:
                    async with self.client.stream("POST", path, headers=self.headers, **kwargs) as response:
                        body = bytearray()
                        async for chunk in response.aiter_bytes():
                            body.extend(chunk)
                            if len(body) > 25_000_000:
                                raise MediaInvalid("media response exceeds byte limit")
                        result = httpx.Response(response.status_code, headers=response.headers, content=bytes(body))
                    if result.status_code == 400:
                        try:
                            code = result.json().get("error", {}).get("code")
                        except (ValueError, AttributeError, TypeError):
                            code = None
                        if code in {"content_policy_violation", "moderation_blocked"}:
                            raise MediaRefused("media provider refused the request")
                    if result.status_code == 429 or result.status_code >= 500:
                        raise MediaUnavailable("media provider is temporarily unavailable")
                    if result.status_code != 200:
                        raise MediaInvalid("media provider rejected the request")
                    return result
                except (httpx.TransportError, MediaUnavailable) as exc:
                    if attempt == 2:
                        raise MediaUnavailable("media provider request failed") from exc
                    await asyncio.sleep(random.uniform(0, 2**attempt))  # noqa: S311 (full jitter)
        except BaseException:
            self.breaker.record_failure()
            raise
        raise MediaUnavailable("media provider request failed")


class OpenAIImages(MediaHTTP):
    def __init__(self, settings: Settings, *, client: httpx.AsyncClient | None = None) -> None:
        super().__init__(settings, "image", client=client)

    async def generate(
        self, *, prompt: str, width: int, height: int, references: Sequence[bytes], request_key: str
    ) -> GeneratedMedia:
        size = self.entry.get("size")
        if size not in {"1024x1024", "1536x1024", "1024x1536"}:
            raise MediaNotConfigured("image model's supported native size needs confirmation")
        params = {"model": self.entry["model"], "prompt": prompt, "n": 1, "size": size, "output_format": "webp"}
        if references:
            normalized = []
            for raw in references:
                import io

                from PIL import Image

                try:
                    with Image.open(io.BytesIO(raw)) as reference:
                        mime = Image.MIME.get(reference.format or "", "")
                        dimensions = reference.size
                except (OSError, ValueError, Image.DecompressionBombError) as exc:
                    raise MediaInvalid("approved reference artwork is not a valid raster image") from exc
                normalized.append(webp(raw, mime, *dimensions, native=dimensions))
            result = await self.post(
                "images/edits",
                data={k: str(v) for k, v in params.items()},
                files=[("image[]", (f"reference_{i}.webp", raw, "image/webp")) for i, raw in enumerate(normalized)],
            )
        else:
            result = await self.post("images/generations", json=params)
        try:
            items = result.json()["data"]
            if len(items) != 1:
                raise ValueError("expected one image")
            raw = base64.b64decode(items[0]["b64_json"], validate=True)
            raster(raw, "image/webp", *(int(n) for n in size.split("x")))
        except (ValueError, KeyError, TypeError, binascii.Error) as exc:
            self.breaker.record_failure()
            raise MediaInvalid("image response has no valid embedded image") from exc
        except MediaInvalid:
            self.breaker.record_failure()
            raise
        self.breaker.record_success()
        return GeneratedMedia(
            raw,
            "image/webp",
            "openai",
            self.entry["model"],
            {
                "native_size": size,
                "target_size": [width, height],
                "request_key": request_key,
                "reference_count": len(references),
            },
            result.headers.get("x-request-id"),
        )


class OpenAISpeech(MediaHTTP):
    def __init__(self, settings: Settings, *, client: httpx.AsyncClient | None = None) -> None:
        super().__init__(settings, "tts", client=client)

    async def synthesize(self, *, text: str, language: str, request_key: str) -> GeneratedMedia:
        voice = self.entry.get("voices", {}).get(language)
        if not voice or language not in {"ar", "en"} or not text.strip() or len(text) > 4096:
            raise MediaNotConfigured("TTS voice/language or text length is unsupported")
        result = await self.post(
            "audio/speech", json={"model": self.entry["model"], "voice": voice, "input": text, "response_format": "mp3"}
        )
        if result.headers.get("content-type", "").split(";")[0] not in {"audio/mpeg", "audio/mp3"}:
            self.breaker.record_failure()
            raise MediaInvalid("TTS returned an unsupported format")
        try:
            mp3_duration(result.content)
        except MediaInvalid:
            self.breaker.record_failure()
            raise
        self.breaker.record_success()
        return GeneratedMedia(
            result.content,
            "audio/mpeg",
            "openai",
            self.entry["model"],
            {"voice": voice, "language": language, "request_key": request_key},
            result.headers.get("x-request-id"),
        )
