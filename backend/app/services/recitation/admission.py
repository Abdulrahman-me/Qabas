"""Back-pressure for the ``asr`` pool (backend §8, AD-22): a bounded set of admitted jobs across API instances.

Each admitted check holds one slot in a Redis sorted set (scored by Redis server time) until its wait ends. Slots
older than the longest possible wait are reclaimed, so a crashed API instance cannot leak capacity. When the set
is full the request is refused at once with ``retry_after_ms`` (time until the oldest job's wait ends), never
queued indefinitely.
"""

from __future__ import annotations

import uuid
from dataclasses import dataclass

import redis.asyncio as aioredis

ADMIT = """
local key, limit, stale_ms, wait_ms, job = KEYS[1], tonumber(ARGV[1]), tonumber(ARGV[2]), tonumber(ARGV[3]), ARGV[4]
local t = redis.call('TIME')
local now = tonumber(t[1]) * 1000 + math.floor(tonumber(t[2]) / 1000)
redis.call('ZREMRANGEBYSCORE', key, '-inf', now - stale_ms)
if redis.call('ZCARD', key) >= limit then
  local oldest = redis.call('ZRANGE', key, 0, 0, 'WITHSCORES')
  local retry = wait_ms
  if oldest[2] then retry = tonumber(oldest[2]) + wait_ms - now end
  return {0, retry}
end
redis.call('ZADD', key, now, job)
redis.call('PEXPIRE', key, stale_ms)
return {1, 0}
"""
MIN_RETRY_MS = 1000


@dataclass(frozen=True)
class Admission:
    admitted: bool
    job: str
    retry_after_ms: int


class AsrCapacity:
    def __init__(self, redis: aioredis.Redis, key: str, *, limit: int, wait_seconds: float) -> None:
        self.redis, self.key, self.limit = redis, key, limit
        self.wait_ms = int(wait_seconds * 1000)
        self.stale_ms = self.wait_ms + 5000

    async def admit(self) -> Admission:
        job = uuid.uuid4().hex
        admitted, retry = await self.redis.eval(ADMIT, 1, self.key, str(self.limit),  # type: ignore[misc]
                                                str(self.stale_ms), str(self.wait_ms), job)
        return Admission(bool(admitted), job, max(MIN_RETRY_MS, int(retry)) if not admitted else 0)

    async def release(self, job: str) -> None:
        await self.redis.zrem(self.key, job)
