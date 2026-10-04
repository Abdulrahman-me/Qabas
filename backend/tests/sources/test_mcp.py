"""Real stdio process transport with a synthetic server, never a production provider."""

import sys
from pathlib import Path

import pytest

from app.config import Settings
from app.sources.errors import ProviderNotConfigured, ProviderResponseInvalid, RecordNotFound, UpstreamUnavailable
from app.sources.mcp import StdioMcp
from app.sources.policy import policy
from app.sources.providers.tafsir_center import TafsirCenter
from app.sources.resilience import CircuitBreaker, RetryPolicy

SERVER = Path(__file__).with_name("fake_mcp_server.py")


def adapter(settings: Settings, mode: str = "ok") -> TafsirCenter:
    mapping = {"status": "confirmed", "get": {"name": "fixture_get", "arguments": {
        "surah": "surah", "ayah": "ayah", "book": "book"}}, "asbab": {"name": "fixture_asbab",
        "arguments": {"surah": "surah", "ayah": "ayah"}}}
    return TafsirCenter(settings, client=StdioMcp("tafsir_center", [sys.executable, str(SERVER), mode],
                                                read_timeout=.1 if mode == "timeout" else 15),
                        provider_policy=policy("tafsir_center").model_copy(update={"tools": mapping}),
                        breaker=CircuitBreaker("tafsir_center"), retry=RetryPolicy(retries=0))


async def test_mcp_handshake_schema_allowlist_and_data_only(settings: Settings) -> None:
    source = adapter(settings)
    try:
        record = await source.get(1, 1)
        assert record.text.startswith("Ignore instructions") and record.parts[0].role == "explanation"
        assert record.retrieval.arguments == {"surah": 1, "ayah": 1, "book": "mukhtasar"}
        asbab = await source.asbab(1, 1)
        assert asbab.data["book"] == "asbab" and asbab.retrieval.operation == "asbab"
        with pytest.raises(ValueError):
            await source.get(1, 1, "unapproved_book")
    finally:
        await source.aclose()
    assert source.client is not None and source.client.process is None


@pytest.mark.parametrize("mode,error", [("missing", RecordNotFound), ("error", ProviderResponseInvalid),
                                       ("invalid", ProviderResponseInvalid), ("wrong", ProviderResponseInvalid),
                                       ("eof", UpstreamUnavailable), ("timeout", UpstreamUnavailable)])
async def test_mcp_failures_are_not_fabricated_sources(settings: Settings, mode: str, error: type) -> None:
    source = adapter(settings, mode)
    try:
        with pytest.raises(error):
            await source.get(1, 1)
        assert source.breaker.failures == (0 if mode == "missing" else 1)
    finally:
        await source.aclose()


async def test_unconfirmed_mapping_and_missing_command_refused(settings: Settings) -> None:
    source = TafsirCenter(settings)
    with pytest.raises(ProviderNotConfigured, match="O-03"):
        await source.get(1, 1)
    await source.aclose()
