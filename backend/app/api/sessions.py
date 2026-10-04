"""Sessions: start, resume, answer and abandon (API §6.5). Finish arrives in Phase 7."""

from __future__ import annotations

import json
from typing import Any

from fastapi import APIRouter, Request, Response

from app.api.deps import CurrentLearner, DbDep, RedisDep, RequestLanguage, SettingsDep
from app.contract import models as C
from app.errors import ApiError, ErrorCode
from app.services.learning import answers, sessions
from app.services.platform.rate_limits import RateLimiter

router = APIRouter(prefix="/sessions", tags=["sessions"])


@router.post("", status_code=201, response_model=C.Session,
             responses={200: {"model": C.Session, "description": "The learner's existing active session"}})
async def create_session(body: C.SessionCreate, response: Response, user: CurrentLearner, db: DbDep,
                         settings: SettingsDep, lang: RequestLanguage) -> C.Session:
    """A new session is ``201``; an existing active one for the same key is returned with ``200``."""
    session, created = await sessions.create(db, settings, user, body, lang)
    if not created:
        response.status_code = 200
    return session


@router.get("/{session_id}", response_model=C.Session)
async def get_session(session_id: str, user: CurrentLearner, db: DbDep) -> C.Session:
    """The stored snapshot with the answer history the feedback mode allows (resume)."""
    return await sessions.get(db, user, session_id)


@router.post("/{session_id}/abandon", status_code=204, response_class=Response)
async def abandon_session(session_id: str, user: CurrentLearner, db: DbDep) -> Response:
    await sessions.abandon(db, user, session_id)
    return Response(status_code=204)


ANSWER_BODY = {"requestBody": {"required": True, "content": {"application/json": {
    "schema": {"$ref": "#/components/schemas/AnswerSubmit"}}}}}


@router.post("/{session_id}/answers", response_model=C.AnswerEvaluation | C.AnswerRecorded,
             openapi_extra=ANSWER_BODY)
async def submit_answer(session_id: str, request: Request, user: CurrentLearner, db: DbDep, redis: RedisDep,
                        settings: SettingsDep) -> Any:
    """Grade one attempt. The body is read raw: a recorded attempt identity replays its stored response before
    the rest of the body is validated (API §6.5 processing order), so FastAPI must not parse it eagerly."""
    await RateLimiter(redis, settings).hit("session_answer", user.id)
    try:
        body = json.loads(await request.body())
    except (json.JSONDecodeError, UnicodeDecodeError):
        raise ApiError(ErrorCode.validation_error, "The request body must be JSON.", {"field": "body"}) from None
    return await answers.submit(db, user, session_id, body)
