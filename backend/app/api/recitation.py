"""Recitation checks (API §6.6). Audio is processed transiently and never stored or returned (API §3.7).

The multipart body is read with a hard size cap and parsed entirely in memory: Starlette would otherwise spool a
file part larger than 1 MB to a temporary file on disk.
"""

from __future__ import annotations

from collections.abc import AsyncGenerator
from typing import Annotated, Any

from fastapi import APIRouter, Depends, Request
from starlette.datastructures import UploadFile
from starlette.formparsers import MultiPartException, MultiPartParser

from app.api.deps import CurrentLearner, DbDep, RedisDep, SettingsDep
from app.contract import models as C
from app.errors import ApiError, ErrorCode
from app.services.platform import idempotency
from app.services.platform.rate_limits import RateLimiter
from app.services.recitation import audio, service
from app.services.recitation.transport import CeleryTranscriber

router = APIRouter(prefix="/recitation", tags=["recitation"])

FORM_OVERHEAD = 64 * 1024          # boundaries and the small text fields
MAX_BODY = audio.MAX_BYTES + FORM_OVERHEAD
FIELDS = ("surah", "ayah", "word_start", "word_end", "exercise_id")

OPENAPI = {"requestBody": {"required": True, "content": {"multipart/form-data": {"schema": {
    "type": "object", "required": ["audio", "surah", "ayah"],
    "properties": {"audio": {"type": "string", "format": "binary"}, "surah": {"type": "integer"},
                   "ayah": {"type": "integer"}, "word_start": {"type": "integer"},
                   "word_end": {"type": "integer"}, "exercise_id": {"type": "string"}}}}}}}


def _too_large() -> ApiError:
    return ApiError(ErrorCode.payload_too_large, "Recitation audio is limited to 30 seconds and 5 MB.",
                    {"field": "audio", "max_bytes": audio.MAX_BYTES, "max_seconds": audio.MAX_SECONDS})


async def _body(request: Request) -> bytes:
    declared = request.headers.get("content-length")
    if declared is not None and declared.isdigit() and int(declared) > MAX_BODY:
        raise _too_large()
    chunks, size = [], 0
    async for chunk in request.stream():
        size += len(chunk)
        if size > MAX_BODY:
            raise _too_large()
        chunks.append(chunk)
    return b"".join(chunks)


def _int(value: Any, field: str, *, required: bool) -> int | None:
    if value is None or value == "":
        if required:
            raise ApiError(ErrorCode.validation_error, f"{field} is required.", {"field": field})
        return None
    if not isinstance(value, str) or not value.strip().lstrip("-").isdigit():
        raise ApiError(ErrorCode.validation_error, f"{field} must be an integer.", {"field": field})
    return int(value)


async def _form(request: Request, body: bytes) -> tuple[service.CheckRequest, bytes]:
    if not request.headers.get("content-type", "").startswith("multipart/form-data"):
        raise ApiError(ErrorCode.validation_error, "Send the recitation as multipart/form-data.", {"field": "body"})

    async def stream() -> AsyncGenerator[bytes, None]:
        yield body

    parser = MultiPartParser(request.headers, stream(), max_files=1, max_fields=len(FIELDS))
    parser.spool_max_size = MAX_BODY        # keep the file part in memory (never on disk)
    try:
        form = await parser.parse()
    except MultiPartException as exc:
        raise ApiError(ErrorCode.validation_error, "The multipart body is malformed.", {"field": "body"}) from exc
    try:
        upload = form.get("audio")
        if not isinstance(upload, UploadFile):
            raise ApiError(ErrorCode.validation_error, "audio is required.", {"field": "audio"})
        data = await upload.read()
        values = {name: form.get(name) for name in FIELDS}
        exercise_id = values["exercise_id"]
        if exercise_id is not None and (not isinstance(exercise_id, str) or not exercise_id.startswith("ex_")):
            raise ApiError(ErrorCode.validation_error, "exercise_id is not an exercise ID.", {"field": "exercise_id"})
        request_fields = service.CheckRequest(
            surah=_int(values["surah"], "surah", required=True) or 0,
            ayah=_int(values["ayah"], "ayah", required=True) or 0,
            word_start=_int(values["word_start"], "word_start", required=False),
            word_end=_int(values["word_end"], "word_end", required=False),
            exercise_id=exercise_id or None)
    finally:
        await form.close()
    return request_fields, data


def get_transcriber(redis: RedisDep, settings: SettingsDep) -> service.Transcriber:
    """The asr worker hand-off (tests override this dependency with an in-process engine)."""
    return CeleryTranscriber(redis, settings)


TranscriberDep = Annotated[service.Transcriber, Depends(get_transcriber)]


@router.post("/checks", response_model=C.RecitationCheck, openapi_extra=OPENAPI,
             responses={503: {"description": "The asr pool is at capacity or did not answer in time "
                                             "(`details.retry_after_ms`)"}})
async def create_check(request: Request, user: CurrentLearner, db: DbDep, redis: RedisDep,
                       settings: SettingsDep, transcriber: TranscriberDep) -> Any:
    """Check one recitation of a verse or word segment. Requires ``Idempotency-Key``."""
    key = idempotency.parse_key(request.headers.get(idempotency.HEADER), required=True)
    assert key is not None
    await RateLimiter(redis, settings).hit("recitation_check", user.id)
    body = await _body(request)
    fields, data = await _form(request, body)
    del body
    return await service.check(db, redis, settings, user, fields, data, key, transcriber)
