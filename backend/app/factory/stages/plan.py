"""Stage 1 ``plan`` — Curriculum Architect (factory §13.1; curriculum: positions vs prerequisites, lesson types,
completeness and depth; AD-29, AD-30, AD-34, AD-35).

Code assembles everything the Architect may use from the database: the slot and its unit, the concept graph with
exactly the concepts this slot may introduce and the concepts it may require, the plans of lessons published in
the unit, the unit context of the most recent lessons (patterns, technique sequences, openings, exercise families,
block and visual kinds) and the unit's misconceptions. The model's plan must be a contract ``LessonPlan``; code then
checks it against that context (errors are retried with the issues as feedback; warnings go to the Gate 1
reviewer). A unit without registered concepts is a curriculum blocker (O-12, D-87): the stage refuses before any
model call rather than letting generation invent concepts.
"""

from __future__ import annotations

from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.factory.errors import StageBlocked, StageOutputInvalid
from app.factory.orchestrator import RunSnapshot, StageContext, StageResult
from app.models import Concept, CurriculumSlot, Exercise, Lesson, LessonVersion, Misconception, Unit

UNIT_CONTEXT_LESSONS = 3
FOUNDATIONAL_UNITS = (0, 1)


def _position(units: dict[str, Unit], unit_id: str, index: int) -> tuple[int, int]:
    return units[unit_id].index, index


async def plan_context(db: AsyncSession, run: RunSnapshot) -> dict[str, Any]:
    units = {u.id: u for u in (await db.execute(select(Unit))).scalars()}
    unit = units[run.unit_id]
    slots = {s.lesson_id: s for s in (await db.execute(select(CurriculumSlot))).scalars()}
    slot = slots[run.lesson_id]
    here = _position(units, run.unit_id, run.position_index)
    concepts = list((await db.execute(select(Concept).order_by(Concept.id))).scalars())

    def earlier(lesson_id: str | None) -> bool:
        owner = slots.get(lesson_id or "")
        return owner is not None and _position(units, owner.unit_id, owner.index) < here

    may_introduce = [c for c in concepts if c.unit_id == run.unit_id
                     and c.introduced_by_lesson_id in (None, run.lesson_id)]
    may_require = [c for c in concepts if earlier(c.introduced_by_lesson_id)
                   and set(unit.tracks) <= set(units[c.unit_id].tracks)]

    published = []
    rows = (await db.execute(select(Lesson, LessonVersion).join(
        LessonVersion, (LessonVersion.lesson_id == Lesson.id) & (LessonVersion.version == Lesson.current_version))
        .where(Lesson.unit_id == run.unit_id).order_by(Lesson.index))).all()
    exercise_types = {e.id: e.type for e in (await db.execute(select(Exercise).where(
        Exercise.lesson_id.in_([lesson.id for lesson, _ in rows])))).scalars()} if rows else {}
    for lesson, version in rows:
        plan = version.plan or {}
        variant: dict[str, Any] = next(iter((version.content.get("ar") or {}).values()), {})
        blocks: list[dict[str, Any]] = variant.get("blocks", [])
        steps = (plan.get("lesson_arc") or {}).get("steps", [])
        published.append({
            "lesson_id": lesson.id, "index": lesson.index, "is_this_slot": lesson.id == run.lesson_id,
            "title": plan.get("title"), "primary_learning_outcome": plan.get("primary_learning_outcome"),
            "central_question": plan.get("central_question"),
            "introduced_concept_ids": plan.get("introduced_concept_ids", []), "new_terms": plan.get("new_terms", []),
            "arc_pattern": (plan.get("lesson_arc") or {}).get("pattern"),
            "techniques": [s.get("technique") for s in steps],
            "opening": steps[0].get("technique") if steps else None,
            "block_types": [b.get("type") for b in blocks],
            "visual_kinds": sorted({str(b["visual"].get("kind")) for b in blocks if isinstance(b.get("visual"), dict)}),
            "exercise_types": [exercise_types.get(str(b.get("exercise_id"))) for b in blocks
                               if b.get("type") == "exercise"]})
    before = [p for p in published if p["index"] < run.position_index]
    misconceptions = list((await db.execute(select(Misconception).where(
        Misconception.unit_id == run.unit_id).order_by(Misconception.id))).scalars())
    return {
        "unit": {"unit_id": unit.id, "index": unit.index, "tracks": list(unit.tracks), "title": unit.title},
        "slot": {"lesson_id": slot.lesson_id, "position_index": slot.index, "working_title": slot.working_title,
                 "focus": slot.focus},
        "concept_graph": [{"concept_id": c.id, "unit_id": c.unit_id, "title": c.title,
                           "prerequisite_ids": list(c.prerequisite_ids),
                           "introduced_by_lesson_id": c.introduced_by_lesson_id} for c in concepts],
        "may_introduce": [c.id for c in may_introduce],
        "may_require": [c.id for c in may_require],
        "unit_has_concepts": any(c.unit_id == run.unit_id for c in concepts),
        "published_lessons_in_unit": published,
        "unit_context": before[-UNIT_CONTEXT_LESSONS:],
        "misconceptions": [{"misconception_id": m.id, "concept_id": m.concept_id, "title": m.title}
                           for m in misconceptions],
    }


def check_plan(plan: dict[str, Any], lesson_type: str, context: dict[str, Any]) -> tuple[list[str], list[str]]:
    """Code checks of a contract-valid plan against the curriculum context: (errors, warnings)."""
    errors, warnings = [], []
    if plan["lesson_type"] != lesson_type:
        errors.append(f"lesson_type must be the requested {lesson_type}, not {plan['lesson_type']}")
    for concept_id in plan["introduced_concept_ids"]:
        if concept_id not in context["may_introduce"]:
            errors.append(f"introduced concept {concept_id} is not a concept this slot may introduce")
    for concept_id in plan["prerequisite_concept_ids"]:
        if concept_id not in context["may_require"]:
            errors.append(f"prerequisite {concept_id} is not introduced by a published lesson at an earlier "
                          "curriculum position serving every track of this lesson")
    known = {m["misconception_id"] for m in context["misconceptions"]}
    for target in plan["target_misconceptions"]:
        if target.get("misconception_id") is not None and target["misconception_id"] not in known:
            errors.append(f"target misconception {target['misconception_id']} does not exist in this unit")
    if context["unit"]["index"] in FOUNDATIONAL_UNITS and plan["depth_profile"] != "foundational":
        errors.append("every lesson of Units 0 and 1 is planned with depth_profile foundational")
    if plan["estimated_minutes"] > 12:
        warnings.append("estimated duration above about 12 minutes: check whether the lesson holds more than one "
                        "outcome (never an automatic split)")
    if plan["lesson_type"] == "concept" and len(plan["new_terms"]) > 2:
        warnings.append("a concept lesson with more than two new terms")
    recent = context["unit_context"]
    pattern = plan["lesson_arc"]["pattern"].strip().lower()
    if recent and (recent[-1].get("arc_pattern") or "").strip().lower() == pattern:
        warnings.append("same arc pattern as the previous lesson of the unit")
    opening = plan["lesson_arc"]["steps"][0]["technique"]
    if len(recent) >= 2 and all(r.get("opening") == opening for r in recent[-2:]):
        warnings.append("same opening technique three lessons running")
    return errors, warnings


async def run(ctx: StageContext) -> StageResult:
    async with ctx.sessionmaker() as db:
        context = await plan_context(db, ctx.run)
    if not context["unit_has_concepts"]:
        raise StageBlocked("concepts_unregistered", f"{ctx.run.unit_id} has no registered concepts: concept "
                           "registration is part of the curriculum review (O-12, D-87), not of generation")
    data = {"brief": ctx.run.brief, "requested_lesson_type": ctx.run.lesson_type, **context,
            "previous_attempt_issues": ctx.run.previous_issues}
    result = await ctx.llm.structured("factory_plan", data, ledger=ctx.ledger, call_key=ctx.call_key)
    plan = result.data
    errors, warnings = check_plan(plan, ctx.run.lesson_type, context)
    if errors:
        raise StageOutputInvalid("plan_invalid", errors)
    return StageResult(output={"plan": plan, "warnings": warnings}, inputs=data, plan=plan,
                       notes={"warnings": warnings})
