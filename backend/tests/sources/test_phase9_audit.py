"""Phase 9.1 audit corrections: the authority/capability boundary at persistence, learner-facing canonical
citations, breaker trial release, definite IslamHouse answers and the O-03 gate ahead of the cache."""

from __future__ import annotations

import copy
from dataclasses import replace
from typing import Any

import httpx
import pytest
from pydantic import SecretStr

from app.config import Environment, Settings
from app.sources.cache import SourceCache
from app.sources.errors import CapabilityMismatch, OperationUnsupported, ProviderNotConfigured, RecordNotFound
from app.sources.policy import CachePolicy, policy
from app.sources.providers.dorar import Dorar
from app.sources.providers.islamhouse import IslamHouse
from app.sources.records import Part, Retrieval, SourceRecord, sha256_text, utcnow
from app.sources.resilience import BreakerState, CircuitBreaker, ProviderHttp, RetryPolicy
from app.sources.scripture import insert
from app.sources.store import citable, persist
from tests.sources.synthetic import mushaf
from tests.sources.transport import recording


def capability_record() -> SourceRecord:
    """What the Quran Foundation adapter returns: a provider's verse text, i.e. capability data."""
    canonical = mushaf().get(1, 1)
    return SourceRecord("quran_com", "1:1@7", "quran", "Quran Foundation", "1:1", canonical.text_uthmani,
                        "https://quran.com/1:1", "quran_foundation/1",
                        Retrieval("quran_com.get", "get", {}, {}, sha256_text("fixture"), utcnow()),
                        (Part("metadata", "quran_com", "1:1"), Part("audio", "quran_com", "1:1@7")), {})


async def test_capability_data_can_never_become_a_citable_source() -> None:
    canonical = insert(mushaf(), 1, (1, 1)).source
    assert citable(canonical)
    assert not citable(capability_record())
    # A provider without the authority role cannot borrow the mushaf part to pass as canonical scripture.
    forged = replace(capability_record(), parts=(Part("text_authority", "mushaf", "1:1"),))
    assert not citable(forged)
    with pytest.raises(CapabilityMismatch, match="capability data"):
        await persist(None, capability_record())  # type: ignore[arg-type]  # refused before any database use
    for provider in ("quranenc", "hadeethenc", "dorar", "islamhouse", "tafsir_center"):
        assert citable(replace(capability_record(), provider=provider, parts=()))


def test_canonical_citation_names_the_surah_and_edition_never_a_dataset_download() -> None:
    m = mushaf()
    single = insert(m, 2, (2, 2)).source
    assert single.title == f"سورة {m.surah(2).name_ar} — نص تجريبي"
    assert single.reference == f"{m.surah(2).name_ar}: 2"
    assert single.url == "https://quran.com/2/2"
    ranged = insert(m, 2, (1, 3)).source
    assert ranged.reference.endswith(": 1-3") and ranged.url == "https://quran.com/2/1-3"
    assert ranged.parts[0].provider == "mushaf" and ranged.parts[0].meta["dataset"] == "synthetic_test"


async def test_an_unexpected_exception_during_a_half_open_trial_releases_the_slot() -> None:
    now = [0.0]
    breaker = CircuitBreaker("fixture", clock=lambda: now[0])
    for _ in range(5):
        breaker.record_failure()
    now[0] += 60
    assert breaker.state is BreakerState.half_open
    http = ProviderHttp("fixture", "https://fixture.test", breaker=breaker, retry=RetryPolicy(retries=0),
                        transport=httpx.MockTransport(lambda request: httpx.Response(200, json={})))

    def unexpected(data: Any) -> None:
        raise OperationUnsupported("fixture", "not a provider failure")

    try:
        with pytest.raises(OperationUnsupported):
            await http.get_json("/x", validate=unexpected)
        assert not breaker.trial_in_flight
        assert (await http.get_json("/x")).data == {}          # the next trial is admitted and closes it
        assert breaker.state is BreakerState.closed
    finally:
        await http.aclose()


async def test_islamhouse_items_that_are_not_citable_text_are_definite_answers(settings: Settings) -> None:
    body = copy.deepcopy(recording("islamhouse", "item_2839210_ar.json")["response"]["body"])
    body["type"] = "videos"
    breaker = CircuitBreaker("islamhouse")
    settings = settings.model_copy(update={"islamhouse_api_key": SecretStr("fixture-key")})
    http = ProviderHttp("islamhouse", "https://fixture.test", breaker=breaker,
                        transport=httpx.MockTransport(lambda request: httpx.Response(200, json=body)))
    adapter = IslamHouse(settings, http)
    try:
        for _ in range(6):
            with pytest.raises(RecordNotFound, match="citable"):
                await adapter.get_item("2839210", "ar")
        assert breaker.failures == 0 and breaker.state is BreakerState.closed
    finally:
        await adapter.aclose()


class ForbiddenRedis:
    def __getattr__(self, key: str) -> Any:
        raise AssertionError("production read a provider cache without live approval")


async def test_production_never_serves_cached_provider_data_without_live_approval() -> None:
    production = Settings(_env_file=None, app_env=Environment.production,
                          auth_token_pepper=SecretStr("test-pepper-" * 4),
                          storage_signing_key=SecretStr("test-signing-key"))
    confirmed = policy("dorar").model_copy(update={
        "cache": CachePolicy(ttl_days=7, terms="confirmed", confirmed_by="test reviewer")})
    assert confirmed.cache_ttl_seconds > 0 and confirmed.live == "pending"

    def forbidden(request: httpx.Request) -> httpx.Response:
        raise AssertionError("live call")

    adapter = Dorar(production, ProviderHttp("dorar", "http://127.0.0.1:5000",
                                             transport=httpx.MockTransport(forbidden)),
                    cache=SourceCache(ForbiddenRedis(), "test"),  # type: ignore[arg-type]
                    provider_policy=confirmed)
    try:
        with pytest.raises(ProviderNotConfigured, match="O-03"):
            await adapter.get("JIDbtVSz")
    finally:
        await adapter.aclose()
