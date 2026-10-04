"""Replay provider recordings and reject mismatches without live access."""

import json
import logging
from typing import Any

import httpx
import pytest
from pydantic import SecretStr

from app.config import Environment, Settings
from app.sources.errors import OperationUnsupported, ProviderNotConfigured, ProviderResponseInvalid, RecordNotFound
from app.sources.providers.dorar import Dorar
from app.sources.providers.hadeethenc import HadeethEnc
from app.sources.providers.islamhouse import IslamHouse
from app.sources.providers.quranenc import QuranEnc
from app.sources.resilience import CircuitBreaker, ProviderHttp
from tests.sources.transport import RecordedTransport, recording


async def test_quranenc_translation_preserves_catalogue_version(settings: Settings) -> None:
    adapter = QuranEnc.create(settings, transport=RecordedTransport("quranenc", prefix="/api/v1"))
    try:
        record = await adapter.translation(4, 103, "english_saheeh", "en")
        assert record.provider_record_id == "english_saheeh:4:103"
        assert record.parts[0].version and record.data["arabic_text"]
        assert record.raw()["response"]["catalogue"]["translations"]
        assert len(record.text_sha256) == 64
        with pytest.raises(RecordNotFound):
            key = recording("quranenc", "aya_unknown_key.json")["request"]["path"].split("/")[3]
            await adapter.translation(4, 103, key, "en")
        with pytest.raises(OperationUnsupported):
            await adapter.call("invent_source")
    finally:
        await adapter.aclose()


async def test_hadeethenc_english_joins_arabic_provenance(settings: Settings) -> None:
    adapter = HadeethEnc.create(settings, transport=RecordedTransport("hadeethenc", prefix="/api/v1"))
    try:
        record = await adapter.get("2962", "en")
        assert record.data["reference_ar"] and record.data["grade_ar"]
        assert record.data["text_ar"] != record.text
        assert [part.role for part in record.parts] == ["text_authority", "translation"]
        assert record.data["grade_source"] == "HadeethEnc"
        with pytest.raises(RecordNotFound):
            missing = recording("hadeethenc", "one_missing_ar.json")["request"]["query"]["id"]
            await adapter.get(str(missing), "ar")
        with pytest.raises(OperationUnsupported):
            await adapter.search("anything", "en")
    finally:
        await adapter.aclose()


async def test_dorar_all_operations_keep_grades_separate_from_sharh(settings: Settings) -> None:
    adapter = Dorar.create(settings, transport=RecordedTransport("dorar"))
    try:
        record = await adapter.get("JIDbtVSz")
        assert record.data["grade_category"] == "authentic"
        assert record.data["grader"] and record.data["number_or_page"]
        alternate = await adapter.alternate("m5AGKRFc")
        assert alternate.provider_record_id != "m5AGKRFc"
        explanation = await adapter.sharh("74201")
        assert explanation.kind == "book" and "grade_label" not in explanation.data
        search = recording("dorar", "search_innama.json")["request"]["query"]
        entries = await adapter.search(search["value"])
        assert entries and entries[0].retrieval.operation == "search"
    finally:
        await adapter.aclose()


async def test_islamhouse_recording_and_missing_item(settings: Settings, caplog: Any) -> None:
    settings = settings.model_copy(update={"islamhouse_api_key": SecretStr("fixture-key")})
    adapter = IslamHouse.create(settings, transport=RecordedTransport("islamhouse", prefix="/v3/fixture-key"))
    try:
        caplog.set_level(logging.INFO, logger="httpx")
        record = await adapter.get_item("2839210", "ar")
        assert record.kind == "book" and record.data["authors"] and record.data["attachments"]
        assert "fixture-key" not in json.dumps(record.raw()) + caplog.text
        with pytest.raises(RecordNotFound):
            await adapter.get_item("999999999", "ar")
        with pytest.raises(OperationUnsupported):
            await adapter.search("anything", "ar")
    finally:
        await adapter.aclose()


@pytest.mark.parametrize("adapter_class,operation,arguments", [
    (QuranEnc, "translation", {"surah": 4, "ayah": 103, "translation_key": "key", "language": "en"}),
    (HadeethEnc, "get", {"hadith_id": "1", "language": "ar"}),
    (Dorar, "get", {"hadith_id": "1"}),
    (IslamHouse, "get_item", {"item_id": "1", "language": "ar"}),
])
async def test_production_pending_gate_prevents_network(adapter_class: Any, operation: str,
                                                       arguments: dict[str, Any]) -> None:
    def forbidden(request: httpx.Request) -> httpx.Response:
        raise AssertionError("O-03 pending provider attempted live access")
    adapter = adapter_class.create(Settings(app_env=Environment.production), transport=httpx.MockTransport(forbidden))
    try:
        with pytest.raises(ProviderNotConfigured, match="O-03"):
            await adapter.call(operation, **arguments)
    finally:
        await adapter.aclose()


@pytest.mark.parametrize("adapter_class,operation,arguments", [
    (QuranEnc, "translation", {"surah": 4, "ayah": 103, "translation_key": "key", "language": "en"}),
    (HadeethEnc, "get", {"hadith_id": "1", "language": "ar"}),
    (Dorar, "get", {"hadith_id": "1"}),
])
async def test_malformed_adapter_payload_opens_breaker(adapter_class: Any, operation: str,
                                                      arguments: dict[str, Any], settings: Settings) -> None:
    breaker = CircuitBreaker(adapter_class.provider)
    http = ProviderHttp(adapter_class.provider, "https://fixture.test", breaker=breaker,
                        transport=httpx.MockTransport(lambda request: httpx.Response(200, json={})))
    adapter = adapter_class(settings, http)
    try:
        for _ in range(5):
            with pytest.raises(ProviderResponseInvalid):
                await adapter.call(operation, **arguments)
        assert breaker.failures == 5
    finally:
        await adapter.aclose()
