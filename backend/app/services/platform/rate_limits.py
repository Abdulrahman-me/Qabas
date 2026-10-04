"""Rate limits and abuse controls (backend §5.1).

Token buckets in Redis, evaluated atomically by one Lua script over every bucket of a scope (for
example Raqeeb's 5/minute *and* 50/day): a request consumes from all of them only if all allow it.
Exceeding a limit raises ``429 rate_limited`` with ``details.retry_after_ms``. Failure counters
(reviewer lockout, invite-code guessing) are fixed windows that only failed attempts increase.
"""

from __future__ import annotations

from dataclasses import dataclass

import redis.asyncio as aioredis

from app.config import Settings
from app.errors import ApiError, ErrorCode
from app.runtime import redis_key


@dataclass(frozen=True)
class Limit:
    capacity: int
    period_seconds: int


# Defaults from backend §5.1; tune on real traffic (O-10). Scopes are attached by their phases.
PROFILES: dict[str, dict[str, tuple[Limit, ...]]] = {
    "default": {
        "auth_guest": (Limit(10, 3600),),                     # per client address
        "raqeeb_message": (Limit(5, 60), Limit(50, 86400)),   # per user
        "recitation_check": (Limit(20, 60),),
        "session_answer": (Limit(120, 60),),                  # answers and finish
        "friend_invite": (Limit(20, 86400),),
        "duel_create": (Limit(30, 3600),),
        "ws_message": (Limit(5, 1),),                         # per socket
        "factory_run": (Limit(20, 86400),),                   # per reviewer
    },
}

FAILURE_LIMITS: dict[str, Limit] = {
    "invite_accept_user": Limit(10, 3600),
    "invite_accept_address": Limit(100, 86400),
}

_BUCKETS_SCRIPT = """
local t = redis.call('TIME')
local now = tonumber(t[1]) * 1000 + math.floor(tonumber(t[2]) / 1000)
local n = #KEYS
local state = {}
local retry = 0
for i = 1, n do
  local capacity = tonumber(ARGV[2 * i - 1])
  local rate = capacity / tonumber(ARGV[2 * i])          -- tokens per millisecond
  local b = redis.call('HMGET', KEYS[i], 'tokens', 'ts')
  local tokens = tonumber(b[1])
  local ts = tonumber(b[2])
  if tokens == nil then tokens = capacity; ts = now end
  tokens = math.min(capacity, tokens + math.max(0, now - ts) * rate)
  state[i] = {tokens, capacity, rate}
  if tokens < 1 then
    retry = math.max(retry, math.ceil((1 - tokens) / rate))
  end
end
for i = 1, n do
  local tokens = state[i][1]
  if retry == 0 then tokens = tokens - 1 end
  redis.call('HSET', KEYS[i], 'tokens', tostring(tokens), 'ts', now)
  redis.call('PEXPIRE', KEYS[i], math.ceil(state[i][2] / state[i][3]) + 1000)
end
return retry
"""


def rate_limited(retry_after_ms: int) -> ApiError:
    seconds = max(1, -(-retry_after_ms // 1000))
    return ApiError(ErrorCode.rate_limited, "Too many requests. Please try again shortly.",
                    {"retry_after_ms": retry_after_ms}, headers={"Retry-After": str(seconds)})


class RateLimiter:
    def __init__(self, redis: aioredis.Redis, settings: Settings) -> None:
        if settings.rate_limits_profile not in PROFILES:
            raise RuntimeError(f"unknown RATE_LIMITS_PROFILE: {settings.rate_limits_profile}")
        self.redis = redis
        self.settings = settings
        self.limits = PROFILES[settings.rate_limits_profile]

    async def hit(self, scope: str, identity: str) -> None:
        """Consume one request for ``identity`` in ``scope``; raise 429 if any bucket is empty."""
        limits = self.limits[scope]
        keys = [redis_key(self.settings, "rl", scope, str(i), identity) for i in range(len(limits))]
        args: list[str] = []
        for limit in limits:
            args += [str(limit.capacity), str(limit.period_seconds * 1000)]
        retry = int(await self.redis.eval(_BUCKETS_SCRIPT, len(keys), *keys, *args))  # type: ignore[misc]
        if retry > 0:
            raise rate_limited(retry)


class FailureCounter:
    """Fixed-window counter of failed attempts (lockouts and guess limits)."""

    def __init__(self, redis: aioredis.Redis, settings: Settings, scope: str, limit: Limit) -> None:
        self.redis = redis
        self.settings = settings
        self.scope = scope
        self.limit = limit

    def _key(self, identity: str) -> str:
        return redis_key(self.settings, "fail", self.scope, identity)

    async def check(self, identity: str) -> None:
        """Raise 429 if ``identity`` has reached the failure limit in the current window."""
        key = self._key(identity)
        count = await self.redis.get(key)
        if count is not None and int(count) >= self.limit.capacity:
            ttl_ms = int(await self.redis.pttl(key))
            raise rate_limited(max(ttl_ms, 1000))

    async def record_failure(self, identity: str) -> None:
        key = self._key(identity)
        pipe = self.redis.pipeline()
        pipe.incr(key)
        pipe.expire(key, self.limit.period_seconds, nx=True)
        await pipe.execute()

    async def reset(self, identity: str) -> None:
        await self.redis.delete(self._key(identity))
