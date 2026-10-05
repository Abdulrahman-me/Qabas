"""Failure classification, bounded retries and per-provider circuit recovery."""

import asyncio
import random
from typing import Any

import httpx
import pytest

from app.sources.errors import ProviderResponseInvalid, RecordNotFound, UpstreamUnavailable
from app.sources.resilience import BreakerState, CircuitBreaker, ProviderHttp, RetryPolicy, default_timeout


@pytest.mark.parametrize("failure", [429, 500, 503, "timeout", "transport"])
async def test_transient_failures_retry_twice_with_bounded_jitter(failure: Any) -> None:
    calls, sleeps = [], []

    async def sleep(delay: float) -> None:
        sleeps.append(delay)

    def handler(request: httpx.Request) -> httpx.Response:
        calls.append(request)
        if failure == "timeout":
            raise httpx.ReadTimeout("untrusted upstream details", request=request)
        if failure == "transport":
            raise httpx.ConnectError("untrusted upstream details", request=request)
        return httpx.Response(failure)

    breaker = CircuitBreaker("test")
    http = ProviderHttp("test", "https://example.test", transport=httpx.MockTransport(handler), breaker=breaker,
                        retry=RetryPolicy(rng=random.Random(12), sleep=sleep))  # noqa: S311 - deterministic jitter test
    try:
        with pytest.raises(UpstreamUnavailable, match="after 3 attempts"):
            await http.get_json("/record")
        assert len(calls) == 3 and len(sleeps) == 2
        assert 0 <= sleeps[0] <= .25 and 0 <= sleeps[1] <= .5
        assert breaker.failures == 1
        assert calls[0].extensions["timeout"] == {"connect": 5., "read": 15., "write": 15., "pool": 15.}
    finally:
        await http.aclose()


@pytest.mark.parametrize(("status", "content", "error"), [
    (404, b"", RecordNotFound), (400, b"{}", ProviderResponseInvalid),
    (401, b"{}", UpstreamUnavailable), (403, b"{}", UpstreamUnavailable),
    (200, b"not json", ProviderResponseInvalid), (204, b"", ProviderResponseInvalid),
    (302, b"{}", ProviderResponseInvalid),
])
async def test_definite_or_malformed_responses_are_not_retried(status: int, content: bytes, error: type) -> None:
    calls = []

    def handler(request: httpx.Request) -> httpx.Response:
        calls.append(request)
        return httpx.Response(status, content=content)

    breaker = CircuitBreaker("test")
    http = ProviderHttp("test", "https://example.test", transport=httpx.MockTransport(handler), breaker=breaker)
    try:
        with pytest.raises(error):
            await http.get_json("/record")
        assert len(calls) == 1 and breaker.failures == (0 if status == 404 else 1)
    finally:
        await http.aclose()


async def test_breaker_opens_after_five_calls_then_one_half_open_trial() -> None:
    clock, calls, state = [0.], [], [False]
    trial = asyncio.Event()
    release = asyncio.Event()

    async def handler(request: httpx.Request) -> httpx.Response:
        calls.append(request)
        if state[0]:
            trial.set()
            await release.wait()
            return httpx.Response(200, json={"ok": True})
        return httpx.Response(503)

    breaker = CircuitBreaker("test", clock=lambda: clock[0])
    http = ProviderHttp("test", "https://example.test", transport=httpx.MockTransport(handler), breaker=breaker,
                        retry=RetryPolicy(retries=0))
    try:
        for _ in range(5):
            with pytest.raises(UpstreamUnavailable):
                await http.get_json("/")
        assert breaker.state is BreakerState.open
        with pytest.raises(UpstreamUnavailable, match="circuit open"):
            await http.get_json("/")
        assert len(calls) == 5
        clock[0] = 60.
        state[0] = True
        task = asyncio.create_task(http.get_json("/"))
        await trial.wait()
        with pytest.raises(UpstreamUnavailable):
            await http.get_json("/")
        release.set()
        await task
        assert len(calls) == 6 and breaker.state is BreakerState.closed and breaker.failures == 0
        assert default_timeout().connect == 5
    finally:
        await http.aclose()


async def test_malformed_shape_counts_toward_breaker_without_retry() -> None:
    breaker = CircuitBreaker("test")
    http = ProviderHttp("test", "https://example.test", breaker=breaker,
                        transport=httpx.MockTransport(lambda r: httpx.Response(200, json={})))

    def invalid(data: Any) -> None:
        raise ProviderResponseInvalid("test", "missing record")

    try:
        for _ in range(5):
            with pytest.raises(ProviderResponseInvalid):
                await http.get_json("/", validate=invalid)
        assert breaker.state is BreakerState.open
    finally:
        await http.aclose()


async def test_cancelled_half_open_trial_releases_slot() -> None:
    breaker = CircuitBreaker("cancel-test", opened_at=0, failures=5, clock=lambda: 60.)
    entered = asyncio.Event()

    async def handler(request: httpx.Request) -> httpx.Response:
        entered.set()
        await asyncio.Event().wait()
        return httpx.Response(200, json={})

    http = ProviderHttp("cancel-test", "https://fixture.test", breaker=breaker,
                        transport=httpx.MockTransport(handler))
    try:
        task = asyncio.create_task(http.get_json("/"))
        await entered.wait()
        task.cancel()
        with pytest.raises(asyncio.CancelledError):
            await task
        assert not breaker.trial_in_flight and breaker.failures == 5
        breaker.before_call()
        assert breaker.trial_in_flight
        breaker.record_failure()
        assert breaker.state is BreakerState.open
    finally:
        await http.aclose()
