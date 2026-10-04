"""Sessions: start, resume and abandon (API §6.5). Answers and finish arrive in Phases 6-7."""

from __future__ import annotations

from fastapi import APIRouter, Response

from app.api.deps import CurrentLearner, DbDep, RequestLanguage, SettingsDep
from app.contract import models as C
from app.services.learning import sessions

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
