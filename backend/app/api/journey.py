"""Journey (Roadmap and Discover), next step, unit guides and the lesson reader (API §6.3-6.4)."""

from __future__ import annotations

from fastapi import APIRouter

from app.api.deps import CurrentLearner, DbDep, RequestLanguage
from app.contract import models as C
from app.services.adaptive import planner
from app.services.learning import sessions
from app.services.learning.journey import journey_response, load_view

router = APIRouter(tags=["journey"])


@router.get("/journey", response_model=C.Journey)
async def get_journey(user: CurrentLearner, db: DbDep, lang: RequestLanguage) -> C.Journey:
    """The learner's track path with derived states; Discover is the ``standalone_eligible`` lessons of it."""
    view = await load_view(db, user)
    _, current = await planner.plan(db, view, lang)
    return journey_response(view, lang, current)


@router.get("/journey/next", response_model=C.NextStep)
async def get_next_step(user: CurrentLearner, db: DbDep, lang: RequestLanguage) -> C.NextStep:
    return await planner.next_step(db, user, lang=lang)


@router.get("/units/{unit_id}/guide", response_model=C.Guide)
async def get_unit_guide(unit_id: str, user: CurrentLearner, db: DbDep, lang: RequestLanguage) -> C.Guide:
    return await sessions.read_guide(db, user, unit_id, lang)


@router.get("/lessons/{lesson_id}", response_model=C.LessonRead)
async def get_lesson(lesson_id: str, user: CurrentLearner, db: DbDep, lang: RequestLanguage) -> C.LessonRead:
    """Reader projection (S6): the session's blocks without exercises, for re-reading."""
    return await sessions.read_lesson(db, user, lesson_id, lang)
