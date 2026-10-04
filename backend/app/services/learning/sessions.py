"""Sessions (backend §6.2, API §6.5): create, resume and abandon.

* **Snapshot:** everything served (``objectives``, ``items``, ``completion``, ``sources``, ``terms`` and the
  header fields) is stored in ``sessions.items_snapshot`` with the language and variant, and every later read
  returns it unchanged. ``served_exercises`` pins the immutable exercise version of every served exercise and
  ``served_scenes`` every scene version, so a newer publication never changes an active session.
* **One active session** per (user, kind, lesson/unit, review mode): creating it again returns the existing one
  (200) - including after a track change - and a concurrent duplicate loses the unique-index race and returns
  the winner.
* **Lesson access:** published, in the learner's journey (open unit of the track) or ``404``; an unmet
  prerequisite is ``409 prerequisite_unmet`` with the Soft Lock data. The entry surface is never an input.
* **Assessments:** ``pretest`` ``min(8, pool)`` (pool >= 6), ``unit_test`` ``min(12, pool)`` (pool >= 9), from the
  unit's current published pools, shuffled at serve time, never repeating an item.
* **Reviews:** ``cards``/``quick`` selection (``review.py``); nothing to serve -> ``409 nothing_to_review``.
* **History redaction:** ``immediate`` -> results with the stored evaluation; ``end`` -> ``hidden`` while active,
  results (no evaluation) after finish; ``none`` -> always ``hidden``. Grading never uses the redacted view.
* Answer keys, misconception maps and duel flags never enter a snapshot: exercises are projected to the
  learner ``Exercise`` model, which has no such fields.
"""

from __future__ import annotations

import copy
import random
from dataclasses import dataclass
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import Settings
from app.content import catalog
from app.content.projection import (
    counts,
    project_source_records,
    project_sources,
    reader_blocks,
    referenced_source_ids,
    resolve_items,
    session_source_ids,
)
from app.content.store import load_package, scene_refs
from app.contract import contextual
from app.contract import models as C
from app.db.ids import new_id
from app.errors import ApiError, ErrorCode
from app.i18n import SESSION_TITLES
from app.models import ExerciseVersion, LearnerUnit, LearningSession, SessionAnswer, User
from app.services.learning import review
from app.services.learning import terms as glossary
from app.services.learning.journey import JourneyView, has_guide, load_view, soft_lock_details
from app.services.platform.auth_sessions import utcnow
from app.services.users import iso

FEEDBACK_MODE = {"lesson": "immediate", "review": "immediate", "pretest": "none", "unit_test": "end"}
ASSESSMENT = {"pretest": (6, 8), "unit_test": (9, 12)}   # (pool minimum, served maximum), backend §6.2
QUICK_TIME_LIMIT_MS = 20_000
SNAPSHOT_FIELDS = ("title", "subtitle", "lesson_type", "reviewed_by", "lesson_version", "objectives", "counts",
                   "source_count", "total_exercises", "items", "completion", "sources", "terms")
_shuffle = random.SystemRandom()


class SessionIntegrityError(RuntimeError):
    """Published data that cannot be served as a valid session (a publication invariant was broken)."""


@dataclass
class Served:
    snapshot: dict[str, Any]
    served_exercises: list[dict[str, Any]]
    served_scenes: list[dict[str, Any]]
    variant: str
    unit_id: str | None
    lesson_id: str | None = None
    lesson_version_id: Any = None


# ======================================================================================================= create

async def create(db: AsyncSession, settings: Settings, user: User, request: C.SessionCreate,
                 lang: str) -> tuple[C.Session, bool]:
    """Start a session, or return the learner's active one for the same key. Returns (session, created)."""
    async with db.begin():
        existing = await _active(db, user.id, request)
        if existing is not None:
            return await _to_contract(db, existing), False
        view = await load_view(db, user)
        if request.kind == "lesson":
            served = await _serve_lesson(db, view, request.lesson_id or "", lang)
        elif request.kind == "review":
            served = await _serve_review(db, view, request.mode or "", lang)
        else:
            served = await _serve_assessment(db, view, request.kind, request.unit_id or "", lang)
        session = LearningSession(
            id=new_id("ses"), user_id=user.id, kind=request.kind, mode=request.mode, lesson_id=served.lesson_id,
            lesson_version_id=served.lesson_version_id, unit_id=served.unit_id,
            feedback_mode=FEEDBACK_MODE[request.kind], language=lang, variant=served.variant,
            items_snapshot=served.snapshot, served_exercises=served.served_exercises,
            served_scenes=served.served_scenes, contract_revision=settings.contract_revision, started_at=utcnow())
        _check_composition(session)
        try:
            async with db.begin_nested():
                db.add(session)
                await db.flush()
        except IntegrityError:
            winner = await _active(db, user.id, request)  # a concurrent request created it first
            if winner is None:
                raise
            return await _to_contract(db, winner), False
        if served.unit_id is not None:
            await _mark_unit_started(db, user.id, served.unit_id)
        return await _to_contract(db, session), True


async def _active(db: AsyncSession, user_id: str, request: C.SessionCreate) -> LearningSession | None:
    query = select(LearningSession).where(LearningSession.user_id == user_id, LearningSession.status == "active",
                                          LearningSession.kind == request.kind)
    if request.kind == "lesson":
        query = query.where(LearningSession.lesson_id == request.lesson_id)
    elif request.kind == "review":
        query = query.where(LearningSession.mode == request.mode)
    else:
        query = query.where(LearningSession.unit_id == request.unit_id)
    return (await db.execute(query)).scalar_one_or_none()


async def _mark_unit_started(db: AsyncSession, user_id: str, unit_id: str) -> None:
    """A unit is ``in_progress`` once any of its sessions started (backend §6.1)."""
    statement = pg_insert(LearnerUnit).values(user_id=user_id, unit_id=unit_id, started_at=utcnow())
    await db.execute(statement.on_conflict_do_update(  # concurrent starts in one unit must not collide
        index_elements=[LearnerUnit.user_id, LearnerUnit.unit_id],
        set_={"started_at": func.coalesce(LearnerUnit.started_at, statement.excluded.started_at)}))


def _not_found(what: str) -> ApiError:
    return ApiError(ErrorCode.not_found, f"{what} was not found.")


# --- lesson ------------------------------------------------------------------------------------------------

async def _serve_lesson(db: AsyncSession, view: JourneyView, lesson_id: str, lang: str) -> Served:
    lesson = view.lesson(lesson_id)
    if lesson is None:
        raise _not_found("Lesson")
    if view.lesson_state(lesson) == "locked":
        raise ApiError(ErrorCode.prerequisite_unmet, "Start with an earlier lesson first.",
                       soft_lock_details(view, lesson))
    lesson_version = await catalog.current_version(db, lesson_id)
    if lesson_version is None:
        raise _not_found("Lesson")
    package = await load_package(db, lesson_version.id)
    variant = view.variant_of(lesson)
    content = package.variants[lang][variant]  # type: ignore[index]
    dumped = content.model_dump(mode="json")
    items = resolve_items(package, lang, variant)
    pins = catalog.pinned_exercise_versions(lesson_version)
    served_exercises = [{"exercise_id": b["exercise"]["exercise_id"], "version": pins[b["exercise"]["exercise_id"]]}
                        for b in items if b["type"] == "exercise"]
    sources = project_sources(package, items)
    snapshot = _snapshot(
        title=content.title, subtitle=content.subtitle, lesson_type=lesson.lesson_type,
        reviewed_by=lesson_version.reviewed_by, lesson_version=lesson_version.version,
        objectives=dumped["objectives"], items=items, completion=dumped["completion"], sources=sources,
        terms=await glossary.cards_for(db, view.user, view.track, lang, items, dumped["objectives"],
                                    dumped["completion"]))
    return Served(snapshot=snapshot, served_exercises=served_exercises, served_scenes=_scenes(items),
                  variant=variant, unit_id=lesson.unit_id, lesson_id=lesson.lesson_id,
                  lesson_version_id=lesson_version.id)


# --- pretest / unit test -----------------------------------------------------------------------------------

async def _serve_assessment(db: AsyncSession, view: JourneyView, kind: str, unit_id: str, lang: str) -> Served:
    unit = view.unit(unit_id)
    if unit is None or unit.coming_soon:
        raise _not_found("Unit")
    minimum, maximum = ASSESSMENT[kind]
    pool = await catalog.pool(db, [unit_id], (kind,))
    if len(pool) < minimum:  # D-38 keeps such units coming soon
        raise SessionIntegrityError(f"{unit_id}: {kind} pool has {len(pool)} items, needs {minimum}")
    chosen = _shuffle.sample(pool, k=min(maximum, len(pool)))
    return await _exercise_session(db, view, [(i.exercise_id, i.version) for i in chosen], lang,
                                   title=SESSION_TITLES[kind][lang], unit_id=unit_id)


# --- review ------------------------------------------------------------------------------------------------

async def _serve_review(db: AsyncSession, view: JourneyView, mode: str, lang: str) -> Served:
    now = utcnow()
    chosen = (await review.select_cards(db, view, now) if mode == "cards"
              else await review.select_quick(db, view, now, lang))
    if not chosen:
        raise ApiError(ErrorCode.nothing_to_review, "There is nothing to review yet.")
    return await _exercise_session(db, view, [(i.exercise_id, i.version) for i in chosen], lang,
                                   title=SESSION_TITLES[f"review_{mode}"][lang], unit_id=None,
                                   time_limit_ms=QUICK_TIME_LIMIT_MS if mode == "quick" else None)


async def _exercise_session(db: AsyncSession, view: JourneyView, keys: list[tuple[str, int]], lang: str, *,
                            title: str, unit_id: str | None, time_limit_ms: int | None = None) -> Served:
    """An exercises-only session: no objectives, no completion (backend §6.2)."""
    versions = await catalog.exercise_versions(db, keys)
    items = []
    for n, key in enumerate(keys, start=1):
        exercise = learner_exercise(versions[key], lang)
        if time_limit_ms is not None:
            exercise["time_limit_ms"] = time_limit_ms  # quick review is timed at 20 s (backend §6.2)
        items.append({"block_id": f"blk_q{n}", "type": "exercise", "exercise": exercise})
    records = await catalog.sources(db, session_source_ids(items))
    snapshot = _snapshot(title=title, subtitle=None, lesson_type=None, reviewed_by=None, lesson_version=None,
                         objectives=[], items=items, completion=None,
                         sources=project_source_records(records, items),
                         terms=await glossary.cards_for(db, view.user, view.track, lang, items))
    return Served(snapshot=snapshot, served_exercises=[{"exercise_id": e, "version": v} for e, v in keys],
                  served_scenes=_scenes(items), variant=view.track, unit_id=unit_id)


def learner_exercise(version: ExerciseVersion, lang: str) -> dict[str, Any]:
    """The learner ``Exercise`` of a stored version: no key, misconception map or duel flag."""
    stored = version.content["languages"][lang]["exercise"]
    projected: dict[str, Any] = C.Exercise.model_validate(stored).model_dump(mode="json")
    return projected


# --- snapshot helpers --------------------------------------------------------------------------------------

def _snapshot(*, title: str, subtitle: str | None, lesson_type: str | None, reviewed_by: str | None,
              lesson_version: int | None, objectives: list[Any], items: list[dict[str, Any]],
              completion: dict[str, Any] | None, sources: list[dict[str, Any]],
              terms: dict[str, dict[str, Any]]) -> dict[str, Any]:
    tally = counts(items)
    return {"title": title, "subtitle": subtitle, "lesson_type": lesson_type, "reviewed_by": reviewed_by,
            "lesson_version": lesson_version, "objectives": objectives, "counts": tally,
            "source_count": sum(1 for s in sources if s["displayed"]), "total_exercises": tally["exercises"],
            "items": items, "completion": completion, "sources": sources, "terms": terms}


def _scenes(items: list[dict[str, Any]]) -> list[dict[str, Any]]:
    found: list[dict[str, Any]] = []
    for ref in scene_refs(items):
        pin = {"scene_id": ref["scene_id"], "version": ref["version"]}
        if pin not in found:
            found.append(pin)
    return found


def _check_composition(session: LearningSession) -> None:
    body = {**session.items_snapshot, "kind": session.kind, "mode": session.mode,
            "feedback_mode": session.feedback_mode}
    errors = contextual.session_composition_errors(body)
    if errors:
        raise SessionIntegrityError(f"invalid {session.kind} composition: {'; '.join(errors)}")


# ======================================================================================================= read

async def get(db: AsyncSession, user: User, session_id: str) -> C.Session:
    session = await db.get(LearningSession, session_id)
    if session is None or session.user_id != user.id:
        raise _not_found("Session")  # never reveal another learner's session
    return await _to_contract(db, session)


async def _to_contract(db: AsyncSession, session: LearningSession) -> C.Session:
    rows = list((await db.execute(select(SessionAnswer).where(SessionAnswer.session_id == session.id)
                                  .order_by(SessionAnswer.id))).scalars())
    snapshot = {k: session.items_snapshot[k] for k in SNAPSHOT_FIELDS}
    return C.Session.model_validate({
        **copy.deepcopy(snapshot),
        "session_id": session.id, "kind": session.kind, "mode": session.mode, "status": session.status,
        "feedback_mode": session.feedback_mode, "unit_id": session.unit_id, "lesson_id": session.lesson_id,
        "started_at": iso(session.started_at),
        "answered_exercises": len({r.exercise_id for r in rows if not r.is_retry}),
        "answers": history(session, rows),
    })


def history(session: LearningSession, rows: list[SessionAnswer]) -> list[dict[str, Any]]:
    """The answer history the feedback mode allows (backend §6.2, API §6.5.5)."""
    visible = session.feedback_mode == "immediate" or (session.feedback_mode == "end"
                                                         and session.status == "finished")
    results = {True: "correct", False: "incorrect", None: "neutral"}
    return [{"exercise_id": r.exercise_id, "is_retry": r.is_retry,
             "result": results[r.correct] if visible else "hidden", "recorded_at": iso(r.recorded_at),
             "evaluation": r.evaluation if session.feedback_mode == "immediate" else None} for r in rows]


# ======================================================================================================= abandon

async def abandon(db: AsyncSession, user: User, session_id: str) -> None:
    """Idempotent for active/abandoned sessions; ``409 session_finished`` after finish (API §6.5)."""
    async with db.begin():
        session = (await db.execute(select(LearningSession).where(LearningSession.id == session_id)
                                    .with_for_update())).scalar_one_or_none()
        if session is None or session.user_id != user.id:
            raise _not_found("Session")
        if session.status == "finished":
            raise ApiError(ErrorCode.session_finished, "This session is already finished.")
        if session.status == "active":
            session.status = "abandoned"
            session.abandoned_at = utcnow()


# ======================================================================================================= reader

async def read_lesson(db: AsyncSession, user: User, lesson_id: str, lang: str) -> C.LessonRead:
    """``GET /lessons/{id}``: the reader projection of the current published version (S6, decision D-47)."""
    view = await load_view(db, user)
    lesson = view.lesson(lesson_id)
    if lesson is None:
        raise _not_found("Lesson")
    if view.lesson_state(lesson) == "locked":
        raise ApiError(ErrorCode.prerequisite_unmet, "Start with an earlier lesson first.",
                       soft_lock_details(view, lesson))
    lesson_version = await catalog.current_version(db, lesson_id)
    if lesson_version is None or lesson_version.reviewed_by is None:
        raise _not_found("Lesson")
    package = await load_package(db, lesson_version.id)
    variant = view.variant_of(lesson)
    content = package.variants[lang][variant]  # type: ignore[index]
    dumped = content.model_dump(mode="json")
    blocks = reader_blocks(resolve_items(package, lang, variant))
    sources = project_sources(package, blocks)
    return C.LessonRead.model_validate({
        "lesson_id": lesson.lesson_id, "unit_id": lesson.unit_id, "title": content.title,
        "subtitle": content.subtitle, "lesson_type": lesson.lesson_type, "reviewed_by": lesson_version.reviewed_by,
        "version": lesson_version.version, "objectives": dumped["objectives"],
        "source_count": sum(1 for s in sources if s["displayed"]), "blocks": blocks,
        "completion": dumped["completion"], "sources": sources,
        "terms": await glossary.cards_for(db, user, view.track, lang, blocks, dumped["objectives"],
                                       dumped["completion"])})


async def read_guide(db: AsyncSession, user: User, unit_id: str, lang: str) -> C.Guide:
    """``GET /units/{id}/guide`` in the learner's language and track framing (backend §6.1)."""
    view = await load_view(db, user)
    unit = view.unit(unit_id)
    if unit is None or not has_guide(unit, lang, view.track):
        raise _not_found("Guide")
    assert unit.guide is not None
    guide = unit.guide[lang][view.track]
    source_ids = referenced_source_ids(guide["sections"])
    records = await catalog.sources(db, source_ids)
    missing = [s for s in source_ids if s not in records]
    if missing:
        raise SessionIntegrityError(f"{unit_id} guide cites unregistered sources {missing}")
    return C.Guide.model_validate({
        "unit_id": unit.id, "title": guide["title"], "sections": guide["sections"],
        # Guide citations are sentence sources, not displayed evidence (no budget applies, decision D-48).
        "sources": [{**records[s], "displayed": False, "display_role": None} for s in source_ids],
        "terms": await glossary.cards_for(db, user, view.track, lang, guide["sections"])})
