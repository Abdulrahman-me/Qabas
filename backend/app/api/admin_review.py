"""Reviewer console: blind tests and metrics (API §6.11; factory §14; Phase 15). Reviewer-only (``403``)."""

from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Response

from app.api.deps import CurrentReviewer, DbDep, RequestLanguage
from app.contract import models as C
from app.services import blind_test, metrics

router = APIRouter(prefix="/admin", tags=["reviewer-console"])


@router.get("/blind-test/next", response_model=C.BlindPair, responses={204: {"description": "No pairs remain"}})
async def next_pair(user: CurrentReviewer, db: DbDep, lang: RequestLanguage) -> Any:
    """The next pair this reviewer has not answered, as previews; ``204`` when none remain."""
    async with db.begin():
        pair = await blind_test.next_pair(db, reviewer_id=user.id, lang=lang)
    return pair if pair is not None else Response(status_code=204)


@router.post("/blind-test/{pair_id}", status_code=204, response_class=Response)
async def answer(pair_id: str, body: C.BlindAnswer, user: CurrentReviewer, db: DbDep) -> Response:
    async with db.begin():
        await blind_test.answer(db, reviewer_id=user.id, pair_id=pair_id, body=body)
    return Response(status_code=204)


@router.get("/metrics", response_model=C.Metrics)
async def get_metrics(user: CurrentReviewer, db: DbDep, lang: RequestLanguage) -> Any:
    async with db.begin():
        return await metrics.metrics(db, lang)
