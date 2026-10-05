"""OAuth and current search are mocked; content formats replay public v4 recordings."""

import asyncio
import json
from typing import Any

import httpx
import pytest
from pydantic import SecretStr

from app.config import Environment, Settings
from app.sources.errors import OperationUnsupported, ProviderNotConfigured, UpstreamUnavailable
from app.sources.providers.quran_foundation import QuranFoundation
from app.sources.resilience import CircuitBreaker, ProviderHttp
from tests.sources.transport import RecordedTransport


def foundation(settings: Settings, handler: Any) -> QuranFoundation:
    transport = httpx.MockTransport(handler)
    settings = settings.model_copy(update={"quran_foundation_client_id": "test-client",
                                           "quran_foundation_client_secret": SecretStr("test-secret"),
                                           "quran_foundation_auth_url": "https://auth.test/oauth2/token"})
    kwargs = {"transport": transport, "breaker": CircuitBreaker("quran_com")}
    return QuranFoundation(settings, ProviderHttp("quran_com", "https://content.test/api/v4", **kwargs),
                           oauth=ProviderHttp("quran_com", "https://auth.test/oauth2/token", **kwargs),
                           search_http=ProviderHttp("quran_com", "https://search.test", **kwargs))


async def test_scoped_tokens_are_reused_and_never_stored(settings: Settings) -> None:
    recorded = RecordedTransport("quran_com", prefix="/api/v4")
    scopes = []

    async def handler(request: httpx.Request) -> httpx.Response:
        if request.url.host == "auth.test":
            assert request.url.path == "/oauth2/token"
            assert request.headers["authorization"].startswith("Basic ")
            scope = dict(httpx.QueryParams(request.content.decode()))["scope"]
            scopes.append(scope)
            return httpx.Response(200, json={"access_token": f"test-token-{scope}", "expires_in": 3600,
                                             "token_type": "Bearer"})
        scope = "search" if request.url.host == "search.test" else "content"
        assert request.headers["x-auth-token"] == f"test-token-{scope}"
        assert request.headers["x-client-id"] == "test-client"
        if scope == "search":
            assert request.url.path == "/api/v1/search" and request.url.params["get_text"] == "1"
            return httpx.Response(200, json={"pagination": {}, "result": {"navigation": [], "verses": [
                {"key": "112:1", "result_type": "ayah", "name": "neutral discovery preview"}]}})
        return await recorded.handle_async_request(request)

    adapter = foundation(settings, handler)
    try:
        records = await asyncio.gather(*(adapter.get(112, 1, 7) for _ in range(3)))
        assert scopes == ["content"]
        assert records[0].data["audio"]["segments"][0] == [0, 1, 30, 390]
        assert [p.role for p in records[0].parts] == ["metadata", "audio", "timing"]
        reciters = await adapter.reciters()
        assert reciters and reciters[0].data["id"]
        search = await adapter.search("neutral")
        assert scopes == ["content", "search"] and search[0].parts[0].role == "search"
        assert "test-token" not in json.dumps(records[0].raw()) + json.dumps(search[0].raw())
        with pytest.raises(OperationUnsupported):
            await adapter.translation(language="en")
    finally:
        await adapter.aclose()
    assert not adapter._tokens


@pytest.mark.parametrize("status", [401, 403])
async def test_only_one_401_refresh_and_no_403_retry(status: int, settings: Settings) -> None:
    calls, tokens = [], []

    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.host == "auth.test":
            tokens.append(request)
            return httpx.Response(200, json={"access_token": f"token-{len(tokens)}", "expires_in": 3600,
                                             "token_type": "Bearer"})
        calls.append(request)
        return httpx.Response(status)

    adapter = foundation(settings, handler)
    try:
        with pytest.raises(UpstreamUnavailable):
            await adapter.get(112, 1, 7)
        assert len(calls) == len(tokens) == (2 if status == 401 else 1)
    finally:
        await adapter.aclose()


@pytest.mark.parametrize("env", [Environment.test, Environment.production])
async def test_no_secrets_or_live_approval_never_calls_network(env: Environment) -> None:
    def forbidden(request: httpx.Request) -> httpx.Response:
        raise AssertionError("unexpected network")
    config = Settings(_env_file=None, app_env=env, auth_token_pepper=SecretStr("test-pepper-" * 4),
                      storage_signing_key=SecretStr("test-signing-key"))
    adapter = QuranFoundation.create(config, transport=httpx.MockTransport(forbidden))
    try:
        with pytest.raises(ProviderNotConfigured):
            await adapter.get(112, 1, 7)
    finally:
        await adapter.aclose()
