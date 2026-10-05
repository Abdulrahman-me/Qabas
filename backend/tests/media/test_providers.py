from __future__ import annotations

import base64
from pathlib import Path
from typing import Any

import httpx
import pytest
import yaml
from pydantic import SecretStr

from app.config import Settings
from app.media.errors import MediaInvalid, MediaNotConfigured, MediaRefused, MediaUnavailable
from app.media.providers import OpenAIImages, OpenAISpeech
from app.sources.resilience import CircuitBreaker
from tests.media.test_core import audio, picture


@pytest.fixture
def configured(settings: Settings, tmp_path: Path) -> Settings:
    approval = {"status": "approved", "approved_by": "synthetic test", "approved_on": "2026-01-01"}
    path = tmp_path / "policy.yaml"
    path.write_text(
        yaml.safe_dump(
            {
                "schema": "qabas.media_policy/1",
                "fixture_only": True,
                "providers": {
                    "image": {
                        "openai": {**approval, "licence": approval, "model": "synthetic-image", "size": "1536x1024"}
                    },
                    "tts": {
                        "openai": {**approval, "licence": approval, "model": "synthetic-tts", "voices": {"ar": "test"}}
                    },
                },
            }
        )
    )
    return settings.model_copy(
        update={
            "media_policy_path": path,
            "image_provider": "openai",
            "image_api_key": SecretStr("synthetic-image-key"),
            "tts_provider": "openai",
            "tts_api_key": SecretStr("synthetic-speech-key"),
        }
    )


async def test_embedded_image_response_and_real_format(configured: Settings) -> None:
    requests = []

    def response(request: httpx.Request) -> httpx.Response:
        requests.append(request)
        return httpx.Response(200, json={"data": [{"b64_json": base64.b64encode(picture(1536, 1024)).decode()}]})

    async with httpx.AsyncClient(
        base_url="https://provider.example.test/v1/", transport=httpx.MockTransport(response)
    ) as http:
        provider = OpenAIImages(configured, client=http)
        provider.breaker = CircuitBreaker("test")
        result = await provider.generate(
            prompt="Neutral geometry", width=1600, height=1000, references=[], request_key="one"
        )
    assert result.data == picture(1536, 1024) and result.parameters["native_size"] == "1536x1024"
    assert requests[0].url.path == "/v1/images/generations" and len(requests) == 1


@pytest.mark.parametrize(
    "body",
    [
        {"data": [{"url": "https://unsafe.example.test/image"}]},
        {"data": [{"b64_json": "%%%"}]},
        {"data": []},
        {"data": [{"b64_json": base64.b64encode(b"not pixels").decode()}]},
    ],
)
async def test_malformed_image_never_becomes_an_asset(configured: Settings, body: Any) -> None:
    async with httpx.AsyncClient(
        base_url="https://provider.example.test/",
        transport=httpx.MockTransport(lambda request: httpx.Response(200, json=body)),
    ) as http:
        provider = OpenAIImages(configured, client=http)
        provider.breaker = CircuitBreaker("test")
        with pytest.raises(MediaInvalid):
            await provider.generate(prompt="Neutral", width=1600, height=1000, references=[], request_key="one")
        assert provider.breaker.failures == 1


async def test_refusal_is_never_retried_and_secrets_are_not_error_text(configured: Settings) -> None:
    calls = 0

    def refusal(request: httpx.Request) -> httpx.Response:
        nonlocal calls
        calls += 1
        return httpx.Response(400, json={"error": {"code": "content_policy_violation", "message": "secret echoed"}})

    async with httpx.AsyncClient(
        base_url="https://provider.example.test/", transport=httpx.MockTransport(refusal)
    ) as http:
        provider = OpenAIImages(configured, client=http)
        provider.breaker = CircuitBreaker("test")
        with pytest.raises(MediaRefused) as result:
            await provider.generate(prompt="Neutral", width=1600, height=1000, references=[], request_key="one")
    assert calls == 1 and "secret" not in str(result.value)


async def test_timeout_retries_are_bounded_and_open_circuit_prevents_calls(
    configured: Settings, monkeypatch: Any
) -> None:
    async def no_wait(delay: float) -> None:
        pass

    monkeypatch.setattr("app.media.providers.asyncio.sleep", no_wait)
    calls = 0

    def timeout(request: httpx.Request) -> httpx.Response:
        nonlocal calls
        calls += 1
        raise httpx.ReadTimeout("timeout", request=request)

    async with httpx.AsyncClient(
        base_url="https://provider.example.test/", transport=httpx.MockTransport(timeout)
    ) as http:
        provider = OpenAIImages(configured, client=http)
        provider.breaker = CircuitBreaker("test")
        for _ in range(5):
            with pytest.raises(MediaUnavailable):
                await provider.generate(prompt="Neutral", width=1600, height=1000, references=[], request_key="one")
        assert calls == 15
        with pytest.raises(MediaUnavailable, match="circuit"):
            await provider.generate(prompt="Neutral", width=1600, height=1000, references=[], request_key="one")
        assert calls == 15


async def test_tts_decodes_real_mp3_and_rejects_a_fake_header(configured: Settings) -> None:
    for raw, valid in ((audio(), True), (b"ID3fake", False)):
        async with httpx.AsyncClient(
            base_url="https://provider.example.test/",
            transport=httpx.MockTransport(
                lambda request, raw=raw: httpx.Response(200, content=raw, headers={"Content-Type": "audio/mpeg"})
            ),
        ) as http:
            provider = OpenAISpeech(configured, client=http)
            provider.breaker = CircuitBreaker("test")
            if valid:
                assert (
                    await provider.synthesize(text="Neutral narration", language="ar", request_key="one")
                ).data == raw
            else:
                with pytest.raises(MediaInvalid):
                    await provider.synthesize(text="Neutral narration", language="ar", request_key="one")


def test_credentials_do_not_override_pending_approval(settings: Settings) -> None:
    selected = settings.model_copy(update={"image_provider": "openai", "image_api_key": SecretStr("available")})
    with pytest.raises(MediaNotConfigured, match="pending"):
        OpenAIImages(selected)
