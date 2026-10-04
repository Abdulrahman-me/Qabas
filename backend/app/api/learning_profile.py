"""Learning profile and personal glossary (contract API §6.2, §6.7)."""

from typing import Any

from fastapi import APIRouter, Query, Response

from app.api.deps import CurrentLearner, DbDep, RequestLanguage
from app.contract import models as C
from app.services.learning import profile, progress, terms
from app.services.learning.locking import learner_lock
from app.services.platform.auth_sessions import utcnow

router = APIRouter(tags=["learning-profile"])


@router.get("/me/stats", response_model=C.Stats)
async def stats(user: CurrentLearner, db: DbDep) -> C.Stats:
    return await profile.stats(db, user)


@router.get("/me/activity", response_model=C.Activity)
async def activity(user: CurrentLearner, db: DbDep, from_: str | None = Query(None, alias="from"),
                   to: str | None = None) -> C.Activity:
    return await profile.activity(db, user, from_, to)


@router.get("/me/quests", response_model=C.Quests)
async def quests(user: CurrentLearner, db: DbDep, lang: RequestLanguage) -> C.Quests:
    async with db.begin():
        await learner_lock(db, user.id)
        return await progress.quest_response(db, user, lang, utcnow())


@router.get("/me/concepts", response_model=C.EXPORTED["ConceptPage"])
async def concepts(user: CurrentLearner, db: DbDep, lang: RequestLanguage,
                   cursor: str | None = None, limit: int = 30) -> Any:
    return await profile.concepts(db, user, lang, cursor, limit)


@router.get("/glossary", response_model=C.EXPORTED["GlossaryPage"])
async def glossary(user: CurrentLearner, db: DbDep, lang: RequestLanguage, state: str = "all",
                   cursor: str | None = None, limit: int = 30) -> Any:
    return await terms.page(db, user, lang, state, cursor, limit)


@router.get("/glossary/{term_id}", response_model=C.TermCard)
async def term(term_id: str, user: CurrentLearner, db: DbDep, lang: RequestLanguage) -> C.TermCard:
    return await terms.get_card(db, user, term_id, lang)


@router.post("/glossary/{term_id}/opened", status_code=204, response_class=Response)
async def opened(term_id: str, user: CurrentLearner, db: DbDep) -> Response:
    await terms.opened(db, user, term_id)
    return Response(status_code=204)
