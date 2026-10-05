"""Raqeeb text endpoints (API §6.8). Attachment processing is introduced in Phase 17."""

from __future__ import annotations

from collections.abc import AsyncGenerator
from datetime import timedelta
from typing import Any

from fastapi import APIRouter, Request, Response
from starlette.formparsers import MultiPartException, MultiPartParser
from starlette.responses import JSONResponse

from app.api.deps import CurrentLearner, DbDep, RedisDep, RequestLanguage, SettingsDep
from app.contract import models as C
from app.errors import ApiError, ErrorCode
from app.raqeeb import service
from app.services.platform import idempotency
from app.services.platform.rate_limits import RateLimiter

router = APIRouter(prefix="/raqeeb", tags=["raqeeb"])
OPENAPI = {"requestBody": {"required": True, "content": {"multipart/form-data": {"schema": {
    "type": "object", "properties": {"text": {"type": "string", "maxLength": 2000},
        "audio": {"type": "string", "format": "binary"},
        "images": {"type": "array", "items": {"type": "string", "format": "binary"}},
        "document": {"type": "string", "format": "binary"}}}}}}}


async def text_input(request: Request) -> str:
    if not request.headers.get("content-type", "").startswith("multipart/form-data"):
        raise ApiError(ErrorCode.validation_error, "Send multipart/form-data.")
    body = bytearray()
    async for chunk in request.stream():
        if len(body) + len(chunk) > 32 * 1024:
            raise ApiError(ErrorCode.payload_too_large, "Text input exceeds the message limit.")
        body.extend(chunk)

    async def stream() -> AsyncGenerator[bytes, None]:
        yield bytes(body)

    parser = MultiPartParser(request.headers, stream(), max_files=0, max_fields=1)
    try:
        form = await parser.parse()
    except MultiPartException:
        raise ApiError(ErrorCode.validation_error,
                       "Phase 16 accepts one text field; attachments require Phase 17.") from None
    try:
        fields = form.multi_items()
        if len(fields) != 1 or fields[0][0] != "text" or not isinstance(fields[0][1], str):
            raise ApiError(ErrorCode.validation_error, "A text message is required.")
        text = fields[0][1]
        if not text.strip() or len(text) > 2000:
            raise ApiError(ErrorCode.validation_error, "text must contain 1-2000 characters.", {"field": "text"})
        return text
    finally:
        await form.close()


@router.post("/conversations", status_code=201, response_model=C.Conversation)
async def create(body: C.ConvCreate, request: Request, user: CurrentLearner, db: DbDep,
                 settings: SettingsDep, lang: RequestLanguage) -> Any:
    key = idempotency.parse_key(request.headers.get(idempotency.HEADER), required=False)

    async def action() -> tuple[int, dict[str, Any]]:
        return await service.create(db, user, lang, body.context)

    if key:
        request_hash = idempotency.fingerprint("POST", request.url.path,
                                              body.model_dump(mode="json") | {"language": lang})
        stored = await idempotency.run_idempotent(db, user_id=user.id, key=key, request_hash=request_hash,
            ttl=timedelta(hours=settings.idempotency_ttl_hours), create=action)
        return JSONResponse(stored.body, status_code=stored.status)
    async with db.begin():
        return (await action())[1]


@router.get("/conversations", response_model=C.EXPORTED["ConversationPage"])
async def page(user: CurrentLearner, db: DbDep, cursor: str | None = None, limit: int = 20) -> Any:
    async with db.begin():
        return await service.page(db, user.id, cursor, limit)


@router.get("/conversations/{conversation_id}", response_model=C.ConvDetail)
async def detail(conversation_id: str, user: CurrentLearner, db: DbDep) -> Any:
    async with db.begin():
        return await service.detail(db, user.id, conversation_id)


@router.post("/conversations/{conversation_id}/messages", status_code=202, response_model=C.PostMessageResp,
             openapi_extra=OPENAPI)
async def submit(conversation_id: str, request: Request, user: CurrentLearner, db: DbDep,
                 redis: RedisDep, settings: SettingsDep) -> Any:
    key = idempotency.parse_key(request.headers.get(idempotency.HEADER), required=True)
    assert key is not None
    text = await text_input(request)

    async def rate_limit() -> None:
        await RateLimiter(redis, settings).hit("raqeeb_message", user.id)

    async def action() -> tuple[int, dict[str, Any]]:
        return await service.submit(db, user, conversation_id, text, rate_limit)

    stored = await idempotency.run_idempotent(db, user_id=user.id, key=key,
        request_hash=idempotency.fingerprint("POST", request.url.path, {"text": text}),
        ttl=timedelta(hours=settings.idempotency_ttl_hours), create=action)
    return JSONResponse(stored.body, status_code=stored.status)


@router.get("/messages/{message_id}", response_model=C.AssistantMessage)
async def get(message_id: str, user: CurrentLearner, db: DbDep) -> Any:
    async with db.begin():
        return service.project_message(await service.get_message(db, user.id, message_id))


@router.post("/messages/{message_id}/feedback", status_code=204, response_class=Response)
async def feedback(message_id: str, body: C.FeedbackReq, user: CurrentLearner, db: DbDep) -> Response:
    async with db.begin():
        await service.feedback(db, user.id, message_id, body)
    return Response(status_code=204)
