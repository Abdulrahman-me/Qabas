"""Raqeeb text/private-attachment endpoints (API §3.7/§6.8)."""

from __future__ import annotations

from datetime import timedelta
from typing import Any

from fastapi import APIRouter, Request, Response
from sqlalchemy import select
from starlette.responses import JSONResponse

from app.api.deps import CurrentLearner, DbDep, RedisDep, RequestLanguage, ResourcesDep, SettingsDep
from app.contract import models as C
from app.errors import ApiError, ErrorCode
from app.models import RaqeebMessage
from app.raqeeb import intake, service
from app.services.platform import idempotency
from app.services.platform.auth_sessions import utcnow
from app.services.platform.rate_limits import RateLimiter

router = APIRouter(prefix="/raqeeb", tags=["raqeeb"])
OPENAPI = {"requestBody": {"required": True, "content": {"multipart/form-data": {"schema": {
    "type": "object", "properties": {"text": {"type": "string", "maxLength": 2000},
        "audio": {"type": "string", "format": "binary"},
        "images": {"type": "array", "items": {"type": "string", "format": "binary"}},
        "document": {"type": "string", "format": "binary"}}}}}}}


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
async def detail(conversation_id: str, user: CurrentLearner, db: DbDep, resources: ResourcesDep) -> Any:
    async with db.begin():
        result = await service.detail(db, user.id, conversation_id)
        result["messages"] = [await intake.refresh(db, m, user.id, resources.storage, resources.settings)
                              for m in result["messages"]]
        return result


@router.post("/conversations/{conversation_id}/messages", status_code=202, response_model=C.PostMessageResp,
             openapi_extra=OPENAPI)
async def submit(conversation_id: str, request: Request, user: CurrentLearner, db: DbDep,
                 redis: RedisDep, settings: SettingsDep, resources: ResourcesDep) -> Any:
    key = idempotency.parse_key(request.headers.get(idempotency.HEADER), required=True)
    assert key is not None
    payload = await intake.parse(request)
    request_hash = idempotency.fingerprint("POST", request.url.path, payload.identity())

    async def rate_limit() -> None:
        await RateLimiter(redis, settings).hit("raqeeb_message", user.id)

    async def action() -> tuple[int, dict[str, Any]]:
        if not payload.uploads:
            return await service.submit(db, user, conversation_id, payload.text, rate_limit)
        # Preflight before any private write. Admission still repeats owner/status checks under its locks.
        # Idempotency has already rejected changed-body replays; rate bounds upload work too.
        await service.conversation(db, user.id, conversation_id)
        processing = await db.scalar(select(RaqeebMessage.id).where(
            RaqeebMessage.conversation_id == conversation_id, RaqeebMessage.status == "processing",
            RaqeebMessage.created_at > utcnow() - timedelta(seconds=service.DEADLINE)))
        if processing:
            raise ApiError(ErrorCode.answer_in_progress, "An answer is already in progress.")
        await rate_limit()
        ids = await intake.prepare(resources, user.id, key, request_hash, payload.uploads)

        async def already_limited() -> None:
            return None

        status, result = await service.submit(db, user, conversation_id, payload.text, already_limited,
                                               attachment_ids=ids, settings=settings)
        result["user_message"] = await intake.refresh(db, result["user_message"], user.id,
                                                       resources.storage, settings)
        return status, result

    stored = await idempotency.run_idempotent(db, user_id=user.id, key=key,
        request_hash=request_hash,
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
