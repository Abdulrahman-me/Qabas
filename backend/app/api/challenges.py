"""Challenges over REST (API §6.10; endpoints keep the ``/duels`` path). Live play is the WebSocket (Phase 20)."""

from __future__ import annotations

import json
from datetime import timedelta
from typing import Any

from fastapi import APIRouter, Request, Response
from pydantic import ValidationError
from starlette.responses import JSONResponse

from app.api.deps import CurrentLearner, DbDep, RedisDep, RequestLanguage, SettingsDep
from app.contract import models as C
from app.errors import ApiError, ErrorCode
from app.services.challenges import duels, play
from app.services.learning.profile import PAGE_DEFAULT
from app.services.platform import idempotency
from app.services.platform.auth_sessions import utcnow
from app.services.platform.rate_limits import RateLimiter

router = APIRouter(prefix="/duels", tags=["challenges"])


def ws_base(request: Request) -> str:
    """The WebSocket origin of this API (``wss`` behind TLS). Phase 20 adds the single-use ticket."""
    base = str(request.base_url).rstrip("/")
    return "wss" + base[len("https"):] if base.startswith("https") else "ws" + base[len("http"):]


@router.post("", status_code=201, response_model=C.Duel)
async def create(body: C.DuelCreate, request: Request, user: CurrentLearner, db: DbDep, redis: RedisDep,
                 settings: SettingsDep, lang: RequestLanguage) -> Any:
    key = idempotency.parse_key(request.headers.get(idempotency.HEADER), required=False)
    base = ws_base(request)

    async def action() -> tuple[int, dict[str, Any]]:
        await RateLimiter(redis, settings).hit("duel_create", user.id)
        duel = await duels.create(db, user, body, utcnow())
        return 201, (await duels.project(db, duel, user, lang, base)).model_dump(mode="json")

    if key:
        request_hash = idempotency.fingerprint("POST", request.url.path, body.model_dump(mode="json"))
        stored = await idempotency.run_idempotent(db, user_id=user.id, key=key, request_hash=request_hash,
                                                  ttl=timedelta(hours=settings.idempotency_ttl_hours), create=action)
        return JSONResponse(stored.body, status_code=stored.status)
    async with db.begin():
        return (await action())[1]


@router.get("/invitations", response_model=C.EXPORTED["InvitationPage"])
async def invitations(user: CurrentLearner, db: DbDep, cursor: str | None = None, limit: int = PAGE_DEFAULT) -> Any:
    async with db.begin():
        return await duels.invitations(db, user, cursor, limit, utcnow())


@router.get("", response_model=C.EXPORTED["DuelPage"])
async def history(request: Request, user: CurrentLearner, db: DbDep, lang: RequestLanguage,
                  cursor: str | None = None, limit: int = PAGE_DEFAULT) -> Any:
    async with db.begin():
        return await duels.history(db, user, cursor, limit, lang, ws_base(request), utcnow())


@router.get("/{duel_id}", response_model=C.Duel)
async def get(duel_id: str, request: Request, user: CurrentLearner, db: DbDep, lang: RequestLanguage) -> C.Duel:
    async with db.begin():
        duel, _ = await duels.locked(db, duel_id, user, utcnow())
        return await duels.project(db, duel, user, lang, ws_base(request))


@router.post("/{duel_id}/accept", response_model=C.Duel)
async def accept(duel_id: str, request: Request, user: CurrentLearner, db: DbDep, lang: RequestLanguage) -> C.Duel:
    async with db.begin():
        duel = await duels.accept(db, user, duel_id, utcnow())
        return await duels.project(db, duel, user, lang, ws_base(request))


@router.post("/{duel_id}/decline", status_code=204, response_class=Response)
async def decline(duel_id: str, user: CurrentLearner, db: DbDep) -> Response:
    async with db.begin():
        await duels.decline(db, user, duel_id, utcnow())
    return Response(status_code=204)


@router.post("/{duel_id}/async", response_model=C.Duel)
async def to_async(duel_id: str, request: Request, user: CurrentLearner, db: DbDep, lang: RequestLanguage) -> C.Duel:
    async with db.begin():
        duel = await duels.switch_async(db, user, duel_id, utcnow())
        return await duels.project(db, duel, user, lang, ws_base(request))


@router.post("/{duel_id}/async/next", response_model=C.AsyncNext)
async def async_next(duel_id: str, user: CurrentLearner, db: DbDep, redis: RedisDep, settings: SettingsDep,
                     lang: RequestLanguage) -> Any:
    await RateLimiter(redis, settings).hit("session_answer", user.id)
    async with db.begin():
        return await play.next_question(db, user, duel_id, lang, utcnow())


ANSWER_BODY = {"requestBody": {"required": True, "content": {"application/json": {
    "schema": {"$ref": "#/components/schemas/AsyncAnswer"}}}}}


@router.post("/{duel_id}/async/answer", response_model=C.AsyncAnswerResp, openapi_extra=ANSWER_BODY)
async def async_answer(duel_id: str, request: Request, user: CurrentLearner, db: DbDep, redis: RedisDep,
                       settings: SettingsDep, lang: RequestLanguage) -> Any:
    """The body is read raw: the answer is graded exactly as sent, without union coercion."""
    await RateLimiter(redis, settings).hit("session_answer", user.id)
    try:
        body = json.loads(await request.body())
        parsed = C.AsyncAnswer.model_validate(body)
    except (json.JSONDecodeError, UnicodeDecodeError, ValidationError):
        raise ApiError(ErrorCode.validation_error, "The answer does not match the expected format.",
                       {"field": "answer"}) from None
    async with db.begin():
        return await play.answer(db, user, duel_id, parsed, body["answer"], lang, utcnow())
