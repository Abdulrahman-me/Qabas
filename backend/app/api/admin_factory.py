"""Reviewer console: factory runs and the two gates (API §6.11; factory §14). Every route requires an
authenticated, active ``reviewer`` (``403 forbidden`` otherwise).

The run projection is the contract ``FactoryRun`` only: plan, draft (previews, claims with evidence, sentence roles,
arc map, exercises with keys, glossary, misconceptions, visuals), QA report, stage statuses, error and
``review_digest``. Prompts, model call records, raw provider responses and source-record internals stay in the
run row and are never exposed, even to reviewers.
"""

from __future__ import annotations

from datetime import timedelta
from typing import Annotated, Any

from fastapi import APIRouter, Depends, Request
from fastapi.responses import JSONResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import CurrentReviewer, DbDep, RedisDep, RequestLanguage, ResourcesDep, SettingsDep
from app.contract import models as C
from app.errors import ApiError, ErrorCode
from app.factory import gates, regenerate
from app.factory.gate2 import ScriptureAuthority, decide_gate2
from app.factory.orchestrator import Dispatcher
from app.factory.runs import create_run, to_contract
from app.media.objects import review_projection
from app.models import CurriculumSlot, FactoryRun
from app.services.learning.profile import PAGE_DEFAULT, page_args
from app.services.platform import idempotency
from app.services.platform.auth_sessions import utcnow
from app.services.platform.rate_limits import RateLimiter

router = APIRouter(prefix="/admin/factory", tags=["reviewer-console"])
IDEMPOTENCY_TTL = timedelta(hours=24)


def get_dispatcher() -> Dispatcher:
    from app.workers.tasks_factory import CeleryDispatcher
    return CeleryDispatcher()


def get_scripture_authority() -> ScriptureAuthority:
    return ScriptureAuthority()


DispatcherDep = Annotated[Dispatcher, Depends(get_dispatcher)]
AuthorityDep = Annotated[ScriptureAuthority, Depends(get_scripture_authority)]


async def _run(db: AsyncSession, run_id: str) -> FactoryRun:
    run = await db.get(FactoryRun, run_id)
    if run is None:
        raise ApiError(ErrorCode.not_found, "Factory run was not found.")
    return run


@router.post("/runs", status_code=201, response_model=C.FactoryRun)
async def start(request: Request, body: C.RunCreate, user: CurrentReviewer, db: DbDep, redis: RedisDep,
                settings: SettingsDep, dispatcher: DispatcherDep) -> Any:
    """Start the factory for the curriculum slot at (``unit_id``, ``position_index``). Accepts
    ``Idempotency-Key``: a retried request returns the original ``201`` and never starts a second run."""
    key = idempotency.parse_key(request.headers.get(idempotency.HEADER), required=False)
    await RateLimiter(redis, settings).hit("factory_run", user.id)

    async def create() -> tuple[int, dict[str, Any]]:
        slot = (await db.execute(select(CurriculumSlot).where(CurriculumSlot.unit_id == body.unit_id,
                                                              CurriculumSlot.index == body.position_index))
                ).scalar_one_or_none()
        if slot is None:
            raise ApiError(ErrorCode.validation_error, "No curriculum lesson slot at this unit position.",
                           {"field": "position_index"})
        run = await create_run(db, settings, reviewer=user, lesson_id=slot.lesson_id, lesson_type=body.lesson_type,
                               brief=body.brief)
        return 201, to_contract(run)

    if key is None:
        async with db.begin():
            _, projected = await create()
        dispatcher.send(projected["run_id"], "plan", 1)
        return JSONResponse(projected, status_code=201)
    stored = await idempotency.run_idempotent(
        db, user_id=user.id, key=key, ttl=IDEMPOTENCY_TTL, create=create,
        request_hash=idempotency.fingerprint("POST", "/admin/factory/runs", body.model_dump(mode="json")))
    if not stored.replayed:
        dispatcher.send(stored.body["run_id"], "plan", 1)
    return JSONResponse(stored.body, status_code=stored.status)


@router.get("/runs", response_model=C.EXPORTED["RunPage"])
async def runs(user: CurrentReviewer, db: DbDep, lang: RequestLanguage, status: str | None = None,
               cursor: str | None = None, limit: int = PAGE_DEFAULT) -> Any:
    """Newest first; ``cursor`` is the last run id of the previous page."""
    page_args(cursor, limit, "run_")
    if status is not None and status not in C.RunStatus.__args__:
        raise ApiError(ErrorCode.validation_error, "Unknown run status.", {"field": "status"})
    query = select(FactoryRun).order_by(FactoryRun.id.desc()).limit(limit + 1)
    if status is not None:
        query = query.where(FactoryRun.status == status)
    if cursor is not None:
        query = query.where(FactoryRun.id < cursor)
    rows = list((await db.execute(query)).scalars())
    items = [{"run_id": r.id, "unit_id": r.unit_id, "lesson_type": r.lesson_type,
              "title": (r.plan or {}).get("title", {}).get(lang) if r.plan else None, "status": r.status,
              "stage": r.stage, "updated_at": r.updated_at.isoformat().replace("+00:00", "Z")} for r in rows[:limit]]
    return {"items": items, "next_cursor": rows[limit - 1].id if len(rows) > limit else None}


@router.get("/runs/{run_id}", response_model=C.FactoryRun)
async def get_run(run_id: str, user: CurrentReviewer, db: DbDep, resources: ResourcesDep) -> Any:
    """The run; while it awaits Gate 2 the first reviewer view records ``review_started_at`` (factory §13.6)."""
    async with db.begin():
        run = await _run(db, run_id)
        if run.status == "awaiting_gate2" and run.review_started_at is None:
            locked = await db.get(FactoryRun, run_id, with_for_update=True)
            assert locked is not None
            locked.review_started_at = locked.review_started_at or utcnow()
        projected = to_contract(run)
        objects = (run.artifacts.get("qa") or {}).get("output", {}).get("media_objects", [])
        return await review_projection(projected, objects, resources.storage,
                                       resources.settings.signed_url_ttl_seconds, published=run.status == "published")


@router.post("/runs/{run_id}/gate1", response_model=C.FactoryRun)
async def gate1(run_id: str, body: C.Gate1, user: CurrentReviewer, resources: ResourcesDep,
                dispatcher: DispatcherDep) -> Any:
    await gates.decide_gate1(resources.sessionmaker, dispatcher, run_id=run_id, reviewer_id=user.id, body=body)
    async with resources.sessionmaker() as db:
        return to_contract(await _run(db, run_id))


@router.post("/runs/{run_id}/gate2", response_model=C.FactoryRun)
async def gate2(run_id: str, body: C.Gate2, user: CurrentReviewer, resources: ResourcesDep,
                dispatcher: DispatcherDep, authority: AuthorityDep) -> Any:
    """``approve`` publishes in the same transaction or changes nothing (``400`` with ``details.issues``)."""
    await decide_gate2(resources.sessionmaker, resources.settings, dispatcher, run_id=run_id,
                      reviewer_id=user.id, body=body, authority=authority, storage=resources.storage)
    async with resources.sessionmaker() as db:
        run = await _run(db, run_id)
        records = (run.artifacts.get("qa") or {}).get("output", {}).get("media_objects", [])
        return await review_projection(to_contract(run), records, resources.storage,
                                       resources.settings.signed_url_ttl_seconds, published=run.status == "published")


@router.post("/runs/{run_id}/images/{scene_id}/regenerate", status_code=202, response_model=C.FactoryRun,
             openapi_extra={"requestBody": {"required": False, "content": {"application/json": {"schema": {
                 "type": "object", "additionalProperties": False, "properties": {
                     "reason": {"type": ["string", "null"], "maxLength": 4000}}}}}}})
async def regenerate_media(run_id: str, scene_id: str, user: CurrentReviewer, resources: ResourcesDep,
                           dispatcher: DispatcherDep, body: dict[str, str | None] | None = None) -> Any:
    if body and (set(body) - {"reason"} or len(body.get("reason") or "") > 4000):
        raise ApiError(ErrorCode.validation_error,
                       "Media regeneration accepts only an optional reason of <=4000 characters.")
    await regenerate.request(resources.sessionmaker, dispatcher, run_id=run_id, scene_id=scene_id,
                             reviewer_id=user.id, reason=body.get("reason") if body else None)
    async with resources.sessionmaker() as db:
        return to_contract(await _run(db, run_id))
