"""API side of the ``asr`` hand-off: publish the job, wait (without blocking the event loop) for its result.

The audio travels once, inside the task message, base64-encoded; the message is acknowledged on receipt (so a
broker never re-delivers audio) and expires after the wait, so a job no worker picked up in time is discarded
rather than processed late. The worker does not use Celery's result backend: it writes the transcription to a
per-job Redis key that lives a few seconds and is deleted as soon as the API reads it, so neither audio nor
transcripts linger (API §3.7; operations retention). Task arguments are never logged (``argsrepr``).
"""

from __future__ import annotations

import asyncio
import base64
import json
import time
import uuid

import redis.asyncio as aioredis

from app.config import Settings
from app.runtime import redis_key
from app.services.recitation.audio import Container, DecodeError
from app.services.recitation.engine import Transcription
from app.services.recitation.service import AsrUnavailable

TASK = "asr.transcribe"
RESULT_TTL_SECONDS = 30
POLL_SECONDS = 0.05


def result_key(settings: Settings, job: str) -> str:
    return redis_key(settings, "asr", "result", job)


def parse_result(raw: bytes | str) -> Transcription:
    value = json.loads(raw)
    if "error" in value:
        if value["error"] in ("undecodable", "too_long"):
            raise DecodeError(value["error"])
        raise AsrUnavailable(value["error"])
    return Transcription(str(value["text"]), int(value["segments"]), value["avg_logprob"])


class CeleryTranscriber:
    def __init__(self, redis: aioredis.Redis, settings: Settings) -> None:
        self.redis, self.settings = redis, settings

    async def transcribe(self, data: bytes, container: Container, *, timeout: float) -> Transcription:
        from app.workers.celery_app import celery_app

        job = uuid.uuid4().hex
        key = result_key(self.settings, job)
        payload = base64.b64encode(data).decode("ascii")
        try:
            await asyncio.to_thread(celery_app.send_task, TASK, args=[job, payload, container.mime], task_id=job,
                                    queue="asr", expires=timeout, ignore_result=True, argsrepr="(<redacted>)",
                                    kwargsrepr="{}")
        except Exception as exc:  # broker unreachable: the client retries or skips
            raise AsrUnavailable("broker unavailable") from exc
        deadline = time.monotonic() + timeout
        try:
            while time.monotonic() < deadline:
                raw = await self.redis.getdel(key)
                if raw is not None:
                    return parse_result(raw)
                await asyncio.sleep(POLL_SECONDS)
        finally:
            await self.redis.delete(key)
        raise AsrUnavailable("timed out")
