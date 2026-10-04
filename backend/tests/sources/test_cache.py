"""Pending terms never touch Redis; confirmed terms use scoped expiring keys."""

from typing import Any

import pytest

from app.runtime import Resources
from app.sources.cache import CachedResponse, SourceCache
from app.sources.policy import CachePolicy, policy
from app.sources.records import utcnow


class ForbiddenRedis:
    def __getattr__(self, key: str) -> Any:
        raise AssertionError("cache with pending terms touched Redis")


async def test_pending_terms_neither_read_nor_write() -> None:
    cache = SourceCache(ForbiddenRedis(), "test")  # type: ignore[arg-type]
    for provider in ("quran_com", "quranenc", "hadeethenc", "islamhouse", "dorar", "tafsir_center"):
        ttl = policy(provider).cache_ttl_seconds
        assert ttl == 0
        assert await cache.get(provider, "v1", {}, ttl) is None
        await cache.put(provider, "v1", {}, ttl, CachedResponse({}, "digest", utcnow()))


@pytest.mark.integration
async def test_cache_keys_hits_and_expiry(resources: Resources) -> None:
    cache = SourceCache(resources.redis, "source-test")
    response = CachedResponse({"text": "neutral fixture"}, "digest", utcnow())
    arguments = {"b": 2, "a": 1}
    ttl = policy("dorar").model_copy(update={
        "cache": CachePolicy(ttl_days=7, terms="confirmed", confirmed_by="test reviewer")}).cache_ttl_seconds
    assert ttl == 604800
    await cache.put("tool", "v1", arguments, ttl, response)
    assert await cache.get("tool", "v1", {"a": 1, "b": 2}, ttl) == response
    assert await cache.get("other", "v1", arguments, ttl) is None
    assert await cache.get("tool", "v2", arguments, ttl) is None
    assert await cache.get("tool", "v1", {"a": 3, "b": 2}, ttl) is None
    key = cache.key("tool", "v1", arguments)
    assert 604798 <= await resources.redis.ttl(key) <= 604800
    # Force expiration in Redis without sleeping; expired entries must be misses.
    await resources.redis.pexpireat(key, 1)
    assert await cache.get("tool", "v1", arguments, ttl) is None
