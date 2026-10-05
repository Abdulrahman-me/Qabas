"""``POST /recitation/checks`` (API §6.6, backend §8).

Order of work, cheapest and most definite first, with no ASR work for a request that can only fail:

1. size (``413``), signature (``415``), the reference against the canonical mushaf (``400``) - in the API process;
2. ``Idempotency-Key``: a stored response for this key is replayed (same fingerprint) or refused (``409``);
3. with ``exercise_id``: the caller's active session must serve that ``recite_verse`` exercise for the same verse,
   range and expected text (else ``409 recitation_check_mismatch``, the same answer whether or not it exists);
4. admission to the bounded ``asr`` pool (``503 upstream_unavailable`` + ``retry_after_ms`` at capacity);
5. the ``asr`` worker decodes and transcribes in memory (≤ 15 s wait, else ``503``); the audio is discarded on
   every path and never stored or logged;
6. alignment, localized message and ``audio_segment`` (from the served exercise's verified reciter timings);
7. the check and its response are stored with the key in one transaction (concurrent duplicates converge).

Expected words always come from the canonical mushaf (Phase 9, D-88), never from the request or a provider.
"""

from __future__ import annotations

import hashlib
import logging
from dataclasses import dataclass
from datetime import timedelta
from typing import Any, Protocol

import redis.asyncio as aioredis
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import Settings
from app.contract import models as C
from app.db.ids import new_id
from app.errors import ApiError, ErrorCode
from app.models import IdempotencyKey, LearningSession, RecitationCheckRecord, User
from app.runtime import redis_key
from app.services.platform import idempotency
from app.services.platform.auth_sessions import utcnow
from app.services.recitation import align, audio, messages
from app.services.recitation.admission import AsrCapacity
from app.services.recitation.engine import Transcription
from app.sources.mushaf import Mushaf, MushafError, Passage, ReferenceNotFound, get_mushaf
from app.sources.normalize import normalize_ar

log = logging.getLogger(__name__)
PATH = "/recitation/checks"


class AsrUnavailable(Exception):
    """The worker did not answer in time or failed; the client may retry or skip (``503``)."""


class Transcriber(Protocol):
    async def transcribe(self, data: bytes, container: audio.Container, *, timeout: float) -> Transcription:
        """Raises ``audio.DecodeError`` for unusable audio and ``AsrUnavailable`` for worker trouble."""
        ...


@dataclass(frozen=True)
class CheckRequest:
    surah: int
    ayah: int
    word_start: int | None
    word_end: int | None
    exercise_id: str | None


def _unavailable(message: str, retry_after_ms: int) -> ApiError:
    return ApiError(ErrorCode.upstream_unavailable, message, {"retry_after_ms": retry_after_ms})


def resolve(mushaf: Mushaf, request: CheckRequest) -> Passage:
    """The canonical verse or segment; any out-of-range reference is ``400 validation_error`` (§8 step 4)."""
    if (request.word_start is None) != (request.word_end is None):
        raise ApiError(ErrorCode.validation_error, "word_start and word_end are sent together or not at all.",
                       {"field": "word_start" if request.word_start is None else "word_end"})
    try:
        return mushaf.get(request.surah, request.ayah, word_start=request.word_start, word_end=request.word_end)
    except ReferenceNotFound:
        field = "word_start" if request.word_start is not None and 1 <= request.surah <= 114 else "ayah"
        if not 1 <= request.surah <= 114:
            field = "surah"
        raise ApiError(ErrorCode.validation_error, "This verse or word range does not exist.",
                       {"field": field}) from None


async def _served_exercise(db: AsyncSession, user: User, exercise_id: str, passage: Passage,
                           digest: str) -> dict[str, Any]:
    """The ``recite_verse`` exercise the caller is being served now, matching this verse and text; otherwise the
    same ``409`` whether the exercise is unknown, foreign or different (no existence is revealed)."""
    sessions = (await db.execute(select(LearningSession).where(
        LearningSession.user_id == user.id, LearningSession.status == "active"))).scalars()
    for session in sessions:
        for item in session.items_snapshot.get("items", []):
            exercise = item.get("exercise") if item.get("type") == "exercise" else None
            if not exercise or exercise.get("exercise_id") != exercise_id or exercise.get("type") != "recite_verse":
                continue
            payload = exercise["payload"]
            if ((payload["surah"], payload["ayah"], payload["word_start"], payload["word_end"])
                    == (passage.surah, passage.ayah_start, passage.word_start, passage.word_end)
                    and align.expected_text_digest(payload["text_uthmani"]) == digest):
                return dict(payload)
    raise ApiError(ErrorCode.recitation_check_mismatch, "This recitation doesn't match the verse of this exercise.")


def _segments(passage: Passage, payload: dict[str, Any] | None) -> dict[int, dict[str, Any]]:
    """Expected word index -> the served clip's timing for that word (§8 step 8). Only the verified, published
    exercise audio is used; without it every ``audio_segment`` is null and the client plays the whole clip."""
    clip = (payload or {}).get("audio")
    if not isinstance(clip, dict) or not clip.get("words"):
        return {}
    timings = {(w["ayah"], w["position"]): w for w in clip["words"]}
    out = {}
    for index, word in enumerate(passage.words):
        timing = timings.get((word.ayah, word.position))
        if timing is not None:
            out[index] = {"url": clip["url"], "start_ms": timing["start_ms"], "end_ms": timing["end_ms"]}
    return out


def evaluate(passage: Passage, transcription: Transcription, language: str,
             segments: dict[int, dict[str, Any]]) -> dict[str, Any]:
    """The contract ``RecitationCheck`` body without its id (§8 steps 3-9)."""
    if transcription.unclear:
        words: list[dict[str, Any]] = []
        status, passed = "unclear", False
    else:
        expected = [w.text for w in passage.words]
        expected_norm = [normalize_ar(w) for w in expected]   # one token each (the mushaf loader guarantees it)
        heard, heard_norm = align.heard_tokens(transcription.text)
        words = []
        position = 0
        for step in align.align(expected_norm, heard_norm):
            if step.expected is None:
                assert step.heard is not None
                # An extra word is placed before the next expected word: it shares that word's index.
                words.append({"index": position, "expected": None, "result": "extra",
                              "heard": heard[step.heard], "audio_segment": None})
                continue
            position = step.expected + 1
            words.append({"index": step.expected, "expected": expected[step.expected], "result": step.result,
                          "heard": heard[step.heard] if step.heard is not None else None,
                          "audio_segment": segments.get(step.expected)})
        status = "evaluated"
        passed = not any(w["result"] in ("missing", "substituted") for w in words)
    summary = {k: sum(1 for w in words if w["result"] == k) for k in ("correct", "missing", "substituted", "extra")}
    return {"status": status, "passed": passed, "words": words, "summary": summary,
            "message": messages.message(language, status=status, passed=passed, words=words)}


async def _stored(db: AsyncSession, user: User, key: str, request_hash: str,
                  ttl: timedelta) -> idempotency.StoredResponse | None:
    """A read-only look at the key, so a client retry replays without spending ASR capacity."""
    async with db.begin():
        stored = (await db.execute(select(IdempotencyKey).where(
            IdempotencyKey.user_id == user.id, IdempotencyKey.key == key))).scalar_one_or_none()
    if stored is None or stored.created_at <= utcnow() - ttl:
        return None
    if stored.request_hash != request_hash:
        raise ApiError(ErrorCode.idempotency_conflict, "This Idempotency-Key was already used for a different request.")
    return idempotency.StoredResponse(stored.response_status, stored.response_body, replayed=True)


async def check(db: AsyncSession, redis: aioredis.Redis, settings: Settings, user: User, request: CheckRequest,
                data: bytes, key: str, transcriber: Transcriber, *, mushaf: Mushaf | None = None) -> dict[str, Any]:
    if not data:
        raise ApiError(ErrorCode.validation_error, "The audio file is empty.", {"field": "audio"})
    if len(data) > audio.MAX_BYTES:
        raise ApiError(ErrorCode.payload_too_large, "Recitation audio is limited to 30 seconds and 5 MB.",
                       {"field": "audio", "max_bytes": audio.MAX_BYTES, "max_seconds": audio.MAX_SECONDS})
    container = audio.sniff(data)
    if container is None:
        raise ApiError(ErrorCode.unsupported_media_type, "Send the recitation as AAC (m4a), Opus (webm), WAV or MP3.",
                       {"field": "audio", "accepted": ["audio/mp4", "audio/webm", "audio/wav", "audio/mpeg"]})
    try:
        canonical = mushaf or get_mushaf(settings)
    except MushafError:
        log.error("recitation checking needs the canonical mushaf; it is not installed or failed verification")
        raise _unavailable("Recitation checking is temporarily unavailable.", 60_000) from None
    passage = resolve(canonical, request)
    digest = align.expected_text_digest(passage.text_uthmani)

    ttl = timedelta(hours=settings.idempotency_ttl_hours)
    request_hash = idempotency.fingerprint("POST", PATH, {
        "surah": request.surah, "ayah": request.ayah, "word_start": request.word_start,
        "word_end": request.word_end, "exercise_id": request.exercise_id,
        "audio_sha256": hashlib.sha256(data).hexdigest()})
    replay = await _stored(db, user, key, request_hash, ttl)
    if replay is not None:
        return replay.body

    payload = None
    if request.exercise_id is not None:
        async with db.begin():
            payload = await _served_exercise(db, user, request.exercise_id, passage, digest)

    capacity = AsrCapacity(redis, redis_key(settings, "asr", "admitted"), limit=settings.asr_queue_max,
                           wait_seconds=settings.asr_timeout_seconds)
    admission = await capacity.admit()
    if not admission.admitted:
        raise _unavailable("Recitation checking is busy. Try again in a moment, or skip.", admission.retry_after_ms)
    try:
        transcription = await transcriber.transcribe(data, container, timeout=settings.asr_timeout_seconds)
    except audio.DecodeError as exc:
        if exc.reason == "too_long":
            raise ApiError(ErrorCode.payload_too_large, "Recitation audio is limited to 30 seconds and 5 MB.",
                           {"field": "audio", "max_bytes": audio.MAX_BYTES,
                            "max_seconds": audio.MAX_SECONDS}) from None
        raise ApiError(ErrorCode.unsupported_media_type, "This audio file could not be read.",
                       {"field": "audio"}) from None
    except AsrUnavailable:
        raise _unavailable("Recitation checking is busy. Try again in a moment, or skip.",
                           max(1000, int(settings.asr_timeout_seconds * 1000) // 3)) from None
    finally:
        await capacity.release(admission.job)

    body = evaluate(passage, transcription, user.language, _segments(passage, payload))

    async def create() -> tuple[int, dict[str, Any]]:
        check_id = new_id("rchk")
        result = C.RecitationCheck.model_validate({"check_id": check_id, **body}).model_dump(mode="json")
        db.add(RecitationCheckRecord(id=check_id, user_id=user.id, surah=passage.surah, ayah=passage.ayah_start,
                                     word_start=passage.word_start, word_end=passage.word_end,
                                     checked_text_sha256=digest, status=result["status"], passed=result["passed"],
                                     words=result["words"], summary=result["summary"]))
        await db.flush()
        return 200, result

    stored = await idempotency.run_idempotent(db, user_id=user.id, key=key, request_hash=request_hash, ttl=ttl,
                                              create=create)
    return stored.body
