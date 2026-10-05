"""``test_asr_backpressure`` (QUALITY §18.1; backend §8, AD-22): bounded admission with ``503`` + ``retry_after_ms``,
the ≤ 15 s wait, slot release on every path, crash-safe slot expiry, and the worker hand-off over Redis that leaves
neither audio nor transcripts behind."""

from __future__ import annotations

import asyncio
import json
from typing import Any

import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.runtime import Resources, redis_key
from app.services.recitation import audio, transport
from app.services.recitation.admission import AsrCapacity
from app.services.recitation.engine import Transcription
from app.services.recitation.service import AsrUnavailable
from app.workers import tasks_asr
from tests.learning.conftest import learner
from tests.recitation.conftest import post_check
from tests.recitation.support import NEUTRAL, FakeTranscriber, heard, wav

pytestmark = pytest.mark.integration
App = tuple[TestClient, Settings, FakeTranscriber]


def capacity(resources: Resources, limit: int = 2, wait: float = 15) -> AsrCapacity:
    return AsrCapacity(resources.redis, redis_key(resources.settings, "asr", "admitted"), limit=limit,
                       wait_seconds=wait)


async def test_admission_is_bounded_and_reports_when_to_retry(resources: Resources) -> None:
    gate = capacity(resources)
    first, second = await gate.admit(), await gate.admit()
    refused = await gate.admit()
    assert first.admitted and second.admitted and not refused.admitted
    assert 1000 <= refused.retry_after_ms <= 15_000
    await gate.release(first.job)
    assert (await gate.admit()).admitted


async def test_slots_of_a_crashed_instance_expire(resources: Resources) -> None:
    gate = capacity(resources, limit=1, wait=15)
    await resources.redis.zadd(gate.key, {"crashed-instance-job": 1})       # admitted long ago, never released
    assert (await gate.admit()).admitted


def test_at_capacity_the_endpoint_answers_503_at_once(recitation_app: App) -> None:
    client, settings, fake = recitation_app
    settings.asr_queue_max = 1
    headers = learner(client)

    async def occupy() -> str:
        resources = Resources.create(settings)
        try:
            return (await capacity(resources, limit=1).admit()).job
        finally:
            await resources.close()

    job = asyncio.run(occupy())
    busy = post_check(client, headers)
    assert busy.status_code == 503 and busy.json()["error"]["code"] == "upstream_unavailable"
    assert busy.json()["error"]["details"]["retry_after_ms"] >= 1000 and fake.calls == []

    async def release() -> None:
        resources = Resources.create(settings)
        try:
            await capacity(resources, limit=1).release(job)
        finally:
            await resources.close()

    asyncio.run(release())
    fake.answer = heard(" ".join(NEUTRAL[:2]))
    assert post_check(client, headers).status_code == 200


def test_a_worker_that_does_not_answer_in_time_is_503_and_the_slot_is_released(recitation_app: App) -> None:
    client, settings, fake = recitation_app
    settings.asr_timeout_seconds = 1
    settings.asr_queue_max = 1
    fake.delay = 5
    headers = learner(client)
    slow = post_check(client, headers)
    assert slow.status_code == 503 and slow.json()["error"]["details"]["retry_after_ms"] >= 1000
    fake.delay, fake.answer = 0, heard(" ".join(NEUTRAL[:2]))
    assert post_check(client, headers).status_code == 200                  # the slot was given back
    fake.answer = AsrUnavailable("worker failed")
    assert post_check(client, headers).status_code == 503


async def test_the_worker_hand_off_leaves_no_transcript_and_never_logs_audio(resources: Resources,
                                                                           monkeypatch: pytest.MonkeyPatch) -> None:
    sent: dict[str, Any] = {}

    def send_task(name: str, **options: Any) -> None:
        sent.update(name=name, **options)

    from app.workers.celery_app import celery_app
    monkeypatch.setattr(celery_app, "send_task", send_task)
    settings = resources.settings
    hand_off = transport.CeleryTranscriber(resources.redis, settings)

    async def worker() -> None:              # what tasks_asr.transcribe writes for the waiting request
        while "task_id" not in sent:
            await asyncio.sleep(0.01)
        await resources.redis.set(transport.result_key(settings, sent["task_id"]),
                                  json.dumps({"text": "ذهب", "segments": 1, "avg_logprob": -0.1}), ex=30)

    result, _ = await asyncio.gather(hand_off.transcribe(wav(0.2), audio.WAV, timeout=5), worker())
    assert result == Transcription("ذهب", 1, -0.1)
    assert sent["name"] == "asr.transcribe" and sent["queue"] == "asr" and sent["expires"] == 5
    assert sent["argsrepr"] == "(<redacted>)" and sent["kwargsrepr"] == "{}" and sent["ignore_result"] is True
    assert await resources.redis.exists(transport.result_key(settings, sent["task_id"])) == 0   # read and deleted

    sent.clear()
    with pytest.raises(AsrUnavailable):
        await hand_off.transcribe(wav(0.2), audio.WAV, timeout=0.3)         # nobody answers
    for error, raised in (("too_long", audio.DecodeError), ("undecodable", audio.DecodeError),
                          ("worker_failed", AsrUnavailable)):
        with pytest.raises(raised):
            transport.parse_result(json.dumps({"error": error}))


def test_the_worker_task_writes_a_short_lived_result(monkeypatch: pytest.MonkeyPatch,
                                                     integration_settings: Settings) -> None:
    written: dict[str, Any] = {}

    class Redis:
        def set(self, key: str, value: str, ex: int) -> None:
            written.update(key=key, value=json.loads(value), ex=ex)

    monkeypatch.setattr(tasks_asr, "_redis", lambda: Redis())
    monkeypatch.setattr(tasks_asr, "get_settings", lambda: integration_settings)
    monkeypatch.setattr(tasks_asr, "engine", lambda: (_ for _ in ()).throw(RuntimeError("model missing")))
    tasks_asr.transcribe("job1", "", "audio/wav")
    assert written["value"] == {"error": "worker_failed"} and written["ex"] == transport.RESULT_TTL_SECONDS
    assert written["key"] == transport.result_key(integration_settings, "job1")
