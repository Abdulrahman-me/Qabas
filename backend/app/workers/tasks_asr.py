"""The ``asr`` worker (backend §8, AD-22): restricted decode + faster-whisper, one model per process, prefetch 1.

    celery -A app.workers.celery_app worker -Q asr --pool=solo --prefetch-multiplier=1      # Windows dev
    celery -A app.workers.celery_app worker -Q asr --concurrency=<physical cores> --prefetch-multiplier=1

Needs the ``asr`` dependency group (faster-whisper, PyAV) and the converted model at ``RECITATION_MODEL_PATH``
(scripts/convert_recitation_model.py). Audio exists only in memory for the duration of one task; the result (text
and confidence only) goes to a short-lived Redis key for the waiting API request. Nothing is logged about the
audio or the transcript.
"""

from __future__ import annotations

import base64
import json
import logging
from typing import Any

import redis

from app.config import get_settings
from app.services.recitation import audio
from app.services.recitation.engine import Engine, FasterWhisperEngine
from app.services.recitation.transport import RESULT_TTL_SECONDS, TASK, result_key
from app.workers.celery_app import celery_app

log = logging.getLogger(__name__)
_ENGINE: Engine | None = None
_REDIS: redis.Redis | None = None


def engine() -> Engine:
    """Loaded once per worker process (§8)."""
    global _ENGINE
    if _ENGINE is None:
        _ENGINE = FasterWhisperEngine(get_settings().recitation_model_path)
    return _ENGINE


def _redis() -> redis.Redis:
    global _REDIS
    if _REDIS is None:
        _REDIS = redis.Redis.from_url(get_settings().redis_url)
    return _REDIS


def run(payload: str, mime: str, model: Engine) -> dict[str, Any]:
    """Decode and transcribe in memory; the audio never outlives this call."""
    container = next((c for c in audio.CONTAINERS if c.mime == mime), None)
    data = base64.b64decode(payload, validate=True)
    try:
        if container is None or audio.sniff(data) != container:
            return {"error": "undecodable"}
        pcm = audio.decode(data, container)
    except audio.DecodeError as exc:
        return {"error": exc.reason}
    finally:
        del data
    try:
        result = model.transcribe(pcm)
    finally:
        del pcm
    return {"text": result.text, "segments": result.segments, "avg_logprob": result.avg_logprob}


@celery_app.task(name=TASK, acks_late=False, ignore_result=True)
def transcribe(job: str, payload: str, mime: str) -> None:
    try:
        result = run(payload, mime, engine())
    except Exception:
        log.exception("recitation transcription failed")      # no audio, transcript or job content is logged
        result = {"error": "worker_failed"}
    _redis().set(result_key(get_settings(), job), json.dumps(result, ensure_ascii=False), ex=RESULT_TTL_SECONDS)
