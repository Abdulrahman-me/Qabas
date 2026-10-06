"""Bounded curriculum admission, using the existing Factory run/worker/gate path.

Inventory is read-only. Admission never chooses a religious lesson type or approves a
gate; the operator supplies the type. Existing content/runs are skipped, not replaced.
"""
from __future__ import annotations

from typing import Any

from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import Settings
from app.content.curriculum import Curriculum
from app.errors import ApiError, ErrorCode
from app.factory import pipeline, runs
from app.llm.errors import LLMNotConfigured
from app.llm.models import model_policy
from app.models import CurriculumSlot, FactoryRun, LessonVersion, User


def preflight(settings: Settings) -> None:
    if not settings.anthropic_api_key or not settings.anthropic_api_key.get_secret_value():
        raise LLMNotConfigured("Factory generation requires configured ANTHROPIC_API_KEY (O-03).")
    for identifier in (settings.llm_model_strong, settings.llm_model_fast):
        model_policy(identifier, settings)


async def inventory(db: AsyncSession, curriculum: Curriculum) -> dict[str, Any]:
    slots = {s.lesson_id: s for s in (await db.execute(select(CurriculumSlot))).scalars()}
    versions = list((await db.execute(select(LessonVersion).where(
        LessonVersion.origin != "test_fixture"))).scalars())
    factory = list((await db.execute(select(FactoryRun).order_by(FactoryRun.created_at, FactoryRun.id))).scalars())
    items: list[dict[str, Any]] = []
    for unit, _, slot in curriculum.slots():
        content = [v for v in versions if v.lesson_id == slot.lesson_id]
        existing = [r for r in factory if r.lesson_id == slot.lesson_id]
        rows: list[dict[str, Any]] = []
        for run in existing:
            qa = (run.qa_report or {}).get("issues", [])
            state = run.status
            if state == "running":
                stage = next(s for s in run.stages if s["stage"] == run.stage)
                state = "queued" if stage["status"] == "pending" else "generating"
            rows.append({"run_id": run.id, "status": run.status, "operator_status": state,
                         "stage": run.stage, "attempt": run.attempt, "error": run.error,
                         "has_draft": pipeline.current_draft(run.artifacts) is not None,
                         "review_digest": run.review_digest, "qa_issues": qa})
        items.append({"unit_id": unit.unit_id, "slot": slot.slot, "lesson_id": slot.lesson_id,
                      "working_title": slot.working_title.model_dump(), "registered": slot.lesson_id in slots,
                      "has_real_content": bool(content),
                      "reviewed": any(v.reviewed_by is not None for v in content),
                      "published": any(v.published_at is not None for v in content),
                      "scaffold_only": not content and not existing,
                      "runs": rows,
                      "blockers": [] if content or existing else ["no_authored_or_generated_package"],
                      "publication_readiness": "published" if any(v.published_at for v in content)
                      else "requires_normal_gate2_validation"})
    return {"schema": "qabas.curriculum_inventory/1", "slots": items,
            "totals": {"slots": len(items), "real_lessons": sum(i["has_real_content"] for i in items),
                       "published": sum(i["published"] for i in items),
                       "reviewed": sum(i["reviewed"] for i in items),
                       "factory_runs": sum(len(i["runs"]) for i in items),
                       "awaiting_review": sum(r["status"] in ("awaiting_gate1", "awaiting_gate2")
                                              for i in items for r in i["runs"])}}


async def admit(db: AsyncSession, settings: Settings, curriculum: Curriculum, *, reviewer: User,
                unit_id: str, lesson_type: str, limit: int = 1) -> list[FactoryRun]:
    """One unit, at most four running batch candidates. Caller commits then dispatches.

The advisory lock and existing unique active-slot constraint arbitrate concurrent
operators. A failed run needs the existing explicit operator recovery path.
"""
    if not 1 <= limit <= 4:
        raise ValueError("batch limit must be 1-4")
    if reviewer.role != "reviewer" or reviewer.deactivated_at is not None or reviewer.deleted_at is not None:
        raise ApiError(ErrorCode.forbidden, "Only an active reviewer starts curriculum batches.")
    unit = curriculum.unit(unit_id)
    preflight(settings)  # fail before any DB mutation, never enqueue 93 doomed model calls
    await db.execute(text("SELECT pg_advisory_xact_lock(hashtextextended(:key, 0))"),
                     {"key": "factory:curriculum-batch"})
    factory = list((await db.execute(select(FactoryRun))).scalars())
    available = max(0, min(limit, 4 - sum(r.status == "running" for r in factory)))
    occupied = {r.lesson_id for r in factory}
    occupied.update((await db.execute(select(LessonVersion.lesson_id))).scalars())
    created: list[FactoryRun] = []
    for slot in unit.lessons:
        if slot.lesson_id in occupied or len(created) >= available:
            continue
        brief = (f"Curriculum slot {slot.slot}. Working title: {slot.working_title.en}. "
                 f"Working focus: {slot.focus.en if slot.focus else slot.working_title.en}. "
                 "Prepare a bilingual reviewable plan using the registered curriculum and trusted sources. "
                 "Preserve both human review gates, source verification, visual safety and publication blockers. "
                 "Working curriculum copy is not scholarly approval.")
        created.append(await runs.create_run(db, settings, reviewer=reviewer, lesson_id=slot.lesson_id,
                                             lesson_type=lesson_type, brief=brief))
    return created
