"""Redis cache for provider responses (SOURCE_ADAPTERS §12; D-91).

Key = tool + adapter version + SHA-256 of the canonical JSON of the arguments. The cached value is the provider
response itself (payload, its SHA-256 and the original retrieval time), so a record rebuilt from the cache carries
the same provenance as the live one. The TTL comes from the provider policy; a TTL of 0 (terms pending) means the
cache is neither read nor written. Published/cited text is never served from here: it lives in ``sources``.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import datetime
from typing import Any

import redis.asyncio as aioredis

from app.sources.records import canonical_json, sha256_text


@dataclass(frozen=True)
class CachedResponse:
    data: Any
    sha256: str
    retrieved_at: datetime


class SourceCache:
    def __init__(self, redis: aioredis.Redis, prefix: str) -> None:
        self.redis = redis
        self.prefix = prefix

    def key(self, tool: str, version: str, arguments: dict[str, Any]) -> str:
        return f"{self.prefix}:src:{tool}:{version}:{sha256_text(canonical_json(arguments))}"

    async def get(self, tool: str, version: str, arguments: dict[str, Any], ttl: int) -> CachedResponse | None:
        if ttl <= 0:
            return None
        raw = await self.redis.get(self.key(tool, version, arguments))
        if raw is None:
            return None
        value = json.loads(raw)
        return CachedResponse(value["data"], value["sha256"], datetime.fromisoformat(value["retrieved_at"]))

    async def put(self, tool: str, version: str, arguments: dict[str, Any], ttl: int,
                  response: CachedResponse) -> None:
        if ttl <= 0:
            return
        value = {"data": response.data, "sha256": response.sha256, "retrieved_at": response.retrieved_at.isoformat()}
        await self.redis.set(self.key(tool, version, arguments), json.dumps(value, ensure_ascii=False), ex=ttl)
