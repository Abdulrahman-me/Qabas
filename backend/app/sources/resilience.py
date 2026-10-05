"""Timeouts, retries with jitter and a circuit breaker for every external source (operations §19, SOURCE_ADAPTERS §12).

* Timeouts: 5 s connect, 15 s read/write/pool.
* Retries: 2, with full jitter (``uniform(0, min(cap, base·2^attempt))``), only for transport errors, timeouts,
  429 and 5xx. Other 4xx answers are definite and are not retried; a malformed body is not retried either.
* Breaker (per provider, per process, D-90): opens after 5 consecutive failed calls for 60 s, then lets one
  half-open trial through; success closes it, failure re-opens it. While open, calls fail at once.
"""

from __future__ import annotations

import asyncio
import json
import random
import time
from collections.abc import Awaitable, Callable, Mapping
from dataclasses import dataclass, field
from enum import StrEnum
from typing import Any

import httpx

from app.sources.errors import AuthenticationRejected, ProviderResponseInvalid, RecordNotFound, UpstreamUnavailable

CONNECT_TIMEOUT = 5.0
READ_TIMEOUT = 15.0
RETRIES = 2
BREAKER_THRESHOLD = 5
BREAKER_OPEN_SECONDS = 60.0


def default_timeout() -> httpx.Timeout:
    return httpx.Timeout(READ_TIMEOUT, connect=CONNECT_TIMEOUT)


class BreakerState(StrEnum):
    closed = "closed"
    open = "open"
    half_open = "half_open"


@dataclass
class CircuitBreaker:
    provider: str
    threshold: int = BREAKER_THRESHOLD
    open_seconds: float = BREAKER_OPEN_SECONDS
    clock: Callable[[], float] = time.monotonic
    failures: int = 0
    opened_at: float | None = None
    trial_in_flight: bool = False

    @property
    def state(self) -> BreakerState:
        if self.opened_at is None:
            return BreakerState.closed
        if self.clock() - self.opened_at >= self.open_seconds:
            return BreakerState.half_open
        return BreakerState.open

    def before_call(self) -> None:
        state = self.state
        if state is BreakerState.open or (state is BreakerState.half_open and self.trial_in_flight):
            raise UpstreamUnavailable(self.provider, "circuit open after repeated failures")
        if state is BreakerState.half_open:
            self.trial_in_flight = True

    def record_success(self) -> None:
        self.failures, self.opened_at, self.trial_in_flight = 0, None, False

    def record_failure(self) -> None:
        self.failures += 1
        if self.trial_in_flight or self.failures >= self.threshold:
            self.opened_at, self.trial_in_flight = self.clock(), False


_BREAKERS: dict[str, CircuitBreaker] = {}


def breaker_for(provider: str) -> CircuitBreaker:
    """The process-wide breaker of a provider (every adapter instance for it shares the state)."""
    if provider not in _BREAKERS:
        _BREAKERS[provider] = CircuitBreaker(provider)
    return _BREAKERS[provider]


@dataclass
class RetryPolicy:
    retries: int = RETRIES
    base_seconds: float = 0.25
    cap_seconds: float = 2.0
    rng: random.Random = field(default_factory=random.Random)
    sleep: Callable[[float], Awaitable[None]] = asyncio.sleep

    def delay(self, attempt: int) -> float:
        return self.rng.uniform(0.0, min(self.cap_seconds, self.base_seconds * 2 ** attempt))


@dataclass(frozen=True)
class Response:
    status: int
    data: Any
    body: bytes


class _Retryable(Exception):
    def __init__(self, reason: str) -> None:
        super().__init__(reason)
        self.reason = reason


class ProviderHttp:
    """HTTP access to one provider with the common resilience rules. Returns parsed JSON and the exact bytes."""

    def __init__(self, provider: str, base_url: str, *, headers: Mapping[str, str] | None = None,
                 transport: httpx.AsyncBaseTransport | None = None, breaker: CircuitBreaker | None = None,
                 retry: RetryPolicy | None = None, timeout: httpx.Timeout | None = None) -> None:
        self.provider = provider
        self.breaker = breaker or breaker_for(provider)
        self.retry = retry or RetryPolicy()
        self._client = httpx.AsyncClient(base_url=base_url, headers=dict(headers or {}), transport=transport,
                                         timeout=timeout or default_timeout(), follow_redirects=False)

    async def aclose(self) -> None:
        await self._client.aclose()

    async def get_json(self, path: str, params: Mapping[str, Any] | None = None, *,
                       headers: Mapping[str, str] | None = None,
                       validate: Callable[[Any], None] | None = None) -> Response:
        return await self.request("GET", path, params=params, headers=headers, validate=validate)

    async def request(self, method: str, path: str, *, params: Mapping[str, Any] | None = None,
                      headers: Mapping[str, str] | None = None, data: Mapping[str, str] | None = None,
                      auth: httpx.Auth | None = None, validate: Callable[[Any], None] | None = None) -> Response:
        self.breaker.before_call()
        try:
            return await self._request(method, path, params=params, headers=headers, data=data,
                                       auth=auth, validate=validate)
        finally:
            # Success and failure already settled the breaker. Anything else (cancellation, an unexpected
            # exception) is not evidence about the provider, but must never keep a half-open slot (F-81).
            self.breaker.trial_in_flight = False

    async def _request(self, method: str, path: str, *, params: Mapping[str, Any] | None,
                       headers: Mapping[str, str] | None, data: Mapping[str, str] | None,
                       auth: httpx.Auth | None, validate: Callable[[Any], None] | None) -> Response:
        last = ""
        for attempt in range(self.retry.retries + 1):
            if attempt:
                await self.retry.sleep(self.retry.delay(attempt - 1))
            try:
                response = await self._client.request(method, path, params=params, headers=headers,
                                                      data=data, auth=auth)
                result = self._interpret(response)
                if validate is not None:
                    validate(result.data)
            except _Retryable as exc:
                last = exc.reason
                continue
            except httpx.TimeoutException as exc:
                last = f"timeout ({type(exc).__name__})"
                continue
            except httpx.TransportError as exc:
                last = f"transport error ({type(exc).__name__})"
                continue
            except RecordNotFound:
                self.breaker.record_success()   # a definite answer: the provider is healthy
                raise
            except (ProviderResponseInvalid, UpstreamUnavailable):
                self.breaker.record_failure()
                raise
            self.breaker.record_success()
            return result
        self.breaker.record_failure()
        raise UpstreamUnavailable(self.provider, f"{last} after {self.retry.retries + 1} attempts")

    def _interpret(self, response: httpx.Response) -> Response:
        status = response.status_code
        if status == 429 or status >= 500:
            raise _Retryable(f"HTTP {status}")
        if status == 404:
            raise RecordNotFound(self.provider, "record not found")
        if status == 401:
            raise AuthenticationRejected(self.provider, "HTTP 401 (credentials or access refused)")
        if status == 403:
            raise UpstreamUnavailable(self.provider, f"HTTP {status} (credentials or access refused)")
        if status >= 400:
            raise ProviderResponseInvalid(self.provider, f"HTTP {status}")
        if not 200 <= status < 300:
            raise ProviderResponseInvalid(self.provider, f"unexpected HTTP {status}; redirects are not followed")
        body = response.content
        try:
            data = json.loads(body)
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise ProviderResponseInvalid(self.provider, f"response is not JSON ({exc.__class__.__name__})") from exc
        return Response(status, data, body)
