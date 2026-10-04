"""Idempotency keys, the outbox relay and rate limits against the real database and Redis."""

from __future__ import annotations

import asyncio
import json
from datetime import timedelta
from typing import Any

import pytest
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import Settings
from app.errors import ApiError
from app.models import OutboxEvent
from app.runtime import Resources
from app.services.platform import idempotency, outbox
from app.services.platform.rate_limits import PROFILES, FailureCounter, Limit, RateLimiter
from tests.api.helpers import aexecute

pytestmark = pytest.mark.integration


async def make_user(url: str, user_id: str = "usr_idem") -> str:
    await aexecute(url, "INSERT INTO users (id, display_name, avatar_key, timezone) "
                        "VALUES ($1, 'U', 'traveler_01', 'UTC')",
            user_id)
    return user_id


# --- idempotency ------------------------------------------------------------------------------------

def test_key_validation() -> None:
    assert idempotency.parse_key(None, required=False) is None
    with pytest.raises(ApiError):
        idempotency.parse_key(None, required=True)
    with pytest.raises(ApiError):
        idempotency.parse_key("not-a-uuid", required=False)
    assert idempotency.parse_key("3F2504E0-4F89-41D3-9A0C-0305E82C3301", required=True) == (
        "3f2504e0-4f89-41d3-9a0c-0305e82c3301")


def test_fingerprint_is_canonical() -> None:
    a = idempotency.fingerprint("post", "/v1/x", {"b": 1, "a": [1, 2]})
    assert a == idempotency.fingerprint("POST", "/v1/x", {"a": [1, 2], "b": 1})
    assert a != idempotency.fingerprint("POST", "/v1/x", {"a": [2, 1], "b": 1})


async def _create_once(resources: Resources, user_id: str, key: str, body: dict[str, Any],
                       calls: list[int]) -> idempotency.StoredResponse:
    async def create() -> tuple[int, dict[str, Any]]:
        calls.append(1)
        await asyncio.sleep(0.05)  # widen the race window for the concurrency test
        return 201, {"created": len(calls)}

    async with resources.sessionmaker() as db:
        return await idempotency.run_idempotent(
            db, user_id=user_id, key=key, request_hash=idempotency.fingerprint("POST", "/v1/x", body),
            ttl=timedelta(hours=24), create=create)


async def test_same_key_and_body_replays(resources: Resources) -> None:
    user_id = await make_user(resources.settings.database_url)
    calls: list[int] = []
    first = await _create_once(resources, user_id, "k1", {"a": 1}, calls)
    second = await _create_once(resources, user_id, "k1", {"a": 1}, calls)
    assert (first.status, first.body, first.replayed) == (201, {"created": 1}, False)
    assert (second.status, second.body, second.replayed) == (201, {"created": 1}, True)
    assert len(calls) == 1


async def test_same_key_different_body_conflicts(resources: Resources) -> None:
    user_id = await make_user(resources.settings.database_url)
    await _create_once(resources, user_id, "k1", {"a": 1}, [])
    with pytest.raises(ApiError) as exc:
        await _create_once(resources, user_id, "k1", {"a": 2}, [])
    assert exc.value.code == "idempotency_conflict" and exc.value.status_code == 409


async def test_concurrent_duplicates_create_once(resources: Resources) -> None:
    user_id = await make_user(resources.settings.database_url)
    calls: list[int] = []
    results = await asyncio.gather(*[_create_once(resources, user_id, "k-race", {"a": 1}, calls) for _ in range(5)])
    assert len(calls) == 1
    assert {json.dumps(r.body) for r in results} == {json.dumps({"created": 1})}
    assert sum(not r.replayed for r in results) == 1


async def test_failed_create_stores_nothing(resources: Resources) -> None:
    user_id = await make_user(resources.settings.database_url)

    async def failing() -> tuple[int, dict[str, Any]]:
        raise RuntimeError("upstream failed")

    async with resources.sessionmaker() as db:
        with pytest.raises(RuntimeError):
            await idempotency.run_idempotent(db, user_id=user_id, key="k-fail", request_hash="a" * 64,
                                             ttl=timedelta(hours=24), create=failing)
    calls: list[int] = []
    retried = await _create_once(resources, user_id, "k-fail", {"a": 1}, calls)
    assert not retried.replayed and len(calls) == 1


async def test_expired_keys_are_reusable_and_purged(resources: Resources) -> None:
    url = resources.settings.database_url
    user_id = await make_user(url)
    await _create_once(resources, user_id, "k-old", {"a": 1}, [])
    await aexecute(url, "UPDATE idempotency_keys SET created_at = now() - interval '25 hours'")
    calls: list[int] = []
    again = await _create_once(resources, user_id, "k-old", {"a": 2}, calls)  # different body is fine now
    assert not again.replayed and len(calls) == 1
    await aexecute(url, "UPDATE idempotency_keys SET created_at = now() - interval '25 hours'")
    async with resources.sessionmaker() as db, db.begin():
        assert await idempotency.purge_expired(db, timedelta(hours=24)) == 1


# --- outbox -------------------------------------------------------------------------------------------

@pytest.fixture
def recorder() -> Any:
    applied: list[str] = []
    attempts: dict[str, int] = {}

    async def record(db: AsyncSession, event: OutboxEvent) -> None:
        attempts[event.event_key] = attempts.get(event.event_key, 0) + 1
        if event.payload.get("fail"):
            raise ValueError("consumer failed")
        if await outbox.apply_effect(db, effect_key=f"effect:{event.payload['n']}", event_key=event.event_key):
            applied.append(event.event_key)

    outbox.CONSUMERS["test.record"] = record
    yield applied, attempts
    outbox.CONSUMERS.pop("test.record", None)


async def _enqueue(resources: Resources, key: str, payload: dict[str, Any]) -> bool:
    async with resources.sessionmaker() as db, db.begin():
        return await outbox.enqueue(db, event_key=key, kind="test.record", payload=payload)


async def test_enqueue_is_idempotent_and_relay_processes_once(resources: Resources, recorder: Any) -> None:
    applied, _ = recorder
    assert await _enqueue(resources, "e1", {"n": 1}) is True
    assert await _enqueue(resources, "e1", {"n": 1}) is False
    assert await outbox.relay(resources.sessionmaker) == 1
    assert await outbox.relay(resources.sessionmaker) == 0
    assert applied == ["e1"]


async def test_effects_apply_once_even_when_redelivered(resources: Resources, recorder: Any) -> None:
    applied, _ = recorder
    await _enqueue(resources, "e1", {"n": 7})
    await _enqueue(resources, "e2", {"n": 7})  # a redelivered/duplicate event for the same effect
    await outbox.relay(resources.sessionmaker)
    assert applied == ["e1"]


async def test_failing_consumer_backs_off_without_losing_the_event(resources: Resources, recorder: Any) -> None:
    applied, attempts = recorder
    await _enqueue(resources, "bad", {"n": 2, "fail": True})
    assert await outbox.relay(resources.sessionmaker) == 1
    async with resources.sessionmaker() as db:
        event = (await db.execute(select(OutboxEvent).where(OutboxEvent.event_key == "bad"))).scalar_one()
    assert event.processed_at is None and event.attempts == 1
    assert event.last_error == "ValueError: consumer failed" and event.available_at > event.created_at
    assert await outbox.relay(resources.sessionmaker) == 0  # not due yet (backoff)
    assert applied == [] and attempts == {"bad": 1}


async def test_unknown_kind_is_retried_not_dropped(resources: Resources) -> None:
    async with resources.sessionmaker() as db, db.begin():
        await outbox.enqueue(db, event_key="orphan", kind="test.nobody", payload={})
    await outbox.relay(resources.sessionmaker)
    async with resources.sessionmaker() as db:
        event = (await db.execute(select(OutboxEvent).where(OutboxEvent.event_key == "orphan"))).scalar_one()
    assert event.processed_at is None and "no consumer" in (event.last_error or "")


async def test_concurrent_relays_never_double_process(resources: Resources, recorder: Any) -> None:
    applied, attempts = recorder
    for i in range(30):
        await _enqueue(resources, f"c{i}", {"n": i})
    await asyncio.gather(*[outbox.relay(resources.sessionmaker) for _ in range(4)])
    assert sorted(applied) == sorted(f"c{i}" for i in range(30))
    assert set(attempts.values()) == {1}
    async with resources.sessionmaker() as db:
        pending = await db.scalar(text("SELECT count(*) FROM outbox_events WHERE processed_at IS NULL"))
    assert pending == 0


# --- rate limits ----------------------------------------------------------------------------------------

async def test_multi_bucket_limits_consume_atomically(resources: Resources, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setitem(PROFILES["default"], "test_scope", (Limit(3, 60), Limit(4, 86400)))
    limiter = RateLimiter(resources.redis, resources.settings)
    for _ in range(3):
        await limiter.hit("test_scope", "u1")
    with pytest.raises(ApiError) as exc:
        await limiter.hit("test_scope", "u1")
    assert exc.value.code == "rate_limited" and 0 < exc.value.details["retry_after_ms"] <= 20_000
    await limiter.hit("test_scope", "u2")  # identities are independent
    # The denied request consumed nothing from the daily bucket: the second bucket still has 1 left.
    tokens = await resources.redis.hget("qabas:rl:test_scope:1:u1", "tokens")
    assert tokens is not None and float(tokens) >= 1


async def test_failure_counter_locks_then_resets(resources: Resources) -> None:
    counter = FailureCounter(resources.redis, resources.settings, "test_lock", Limit(2, 60))
    await counter.check("acct")
    await counter.record_failure("acct")
    await counter.record_failure("acct")
    with pytest.raises(ApiError) as exc:
        await counter.check("acct")
    assert exc.value.details["retry_after_ms"] > 0
    await counter.reset("acct")
    await counter.check("acct")


def test_unknown_profile_is_a_startup_error(integration_settings: Settings) -> None:
    with pytest.raises(RuntimeError):
        RateLimiter(None, integration_settings.model_copy(update={"rate_limits_profile": "nope"}))  # type: ignore[arg-type]
