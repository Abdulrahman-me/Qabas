"""Curriculum seeding, version-aware content import and approval-gated publication.

* :func:`apply_curriculum` makes the database match ``curriculum.yaml``: idempotent, and it refuses (never
  repairs) changes that would move an occupied slot, drop a unit or slot that holds a lesson, or change the
  tracks of a unit with published lessons.
* :func:`import_package` stores a validated lesson package as a new **unpublished** lesson version. Identical
  content (same digest as the latest version) is a no-op; changed content becomes a new version. Published
  and pinned versions are never touched (and the database refuses to change them).
* :func:`publish` makes a stored version learner-eligible in one transaction: it re-validates against the
  database (prerequisites introduced by earlier published lessons in every track; each concept introduced
  once), requires the approval record bound to the exact content digest (or, for test fixtures only, a
  dev/test environment), upserts the canonical sources/terms/misconceptions and writes ``published_at`` last.

Authoring state and learner eligibility stay distinct: only published versions referenced by
``lessons.current_version`` are ever served.
"""

from __future__ import annotations

import uuid
from dataclasses import dataclass, field
from datetime import UTC, datetime
from typing import Any

from sqlalchemy import func, null, select, text, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import Settings
from app.content import catalog
from app.content.curriculum import Curriculum, CurriculumError
from app.content.package import LANGS, ExerciseRecord, LessonPackage, content_digest, sentences_of
from app.content.projection import xp_for
from app.content.validation import (
    PRETEST_POOL_MIN,
    UNIT_TEST_POOL_MIN,
    ContentValidationError,
    Context,
    Issue,
    require_valid,
)
from app.contract import CONTRACT_REVISION
from app.contract import models as C
from app.models import (
    Claim,
    Concept,
    CurriculumSlot,
    Exercise,
    ExerciseVersion,
    Lesson,
    LessonVersion,
    Misconception,
    ReviewDecision,
    SceneVersion,
    SentenceRecord,
    Source,
    Term,
    Unit,
    User,
)

LEARNER_EXERCISE_FIELDS = set(C.Exercise.model_fields)
FIXTURE_REVIEWER = "test fixture"


def _now() -> datetime:
    return datetime.now(UTC)


# ======================================================================================= curriculum

@dataclass
class SeedReport:
    created: dict[str, int] = field(default_factory=lambda: {"units": 0, "slots": 0, "concepts": 0})
    updated: dict[str, int] = field(default_factory=lambda: {"units": 0, "slots": 0, "concepts": 0})
    removed: dict[str, int] = field(default_factory=lambda: {"slots": 0, "concepts": 0})

    @property
    def changed(self) -> bool:
        return any(sum(d.values()) for d in (self.created, self.updated, self.removed))


async def apply_curriculum(db: AsyncSession, cur: Curriculum) -> SeedReport:
    """Make the curriculum tables match ``cur``; the caller owns the transaction."""
    report = SeedReport()
    await _apply_units(db, cur, report)
    await _apply_slots(db, cur, report)
    await _apply_concepts(db, cur, report)
    return report


async def _apply_units(db: AsyncSession, cur: Curriculum, report: SeedReport) -> None:
    units = {u.id: u for u in (await db.execute(select(Unit))).scalars()}
    published_units = set((await db.execute(
        select(Lesson.unit_id).where(Lesson.current_version.is_not(None)).distinct())).scalars())
    wanted = {u.unit_id for u in cur.units}
    problems = [f"unit {unit_id} exists in the database but not in the curriculum file"
                for unit_id in sorted(set(units) - wanted)]
    for spec in cur.units:
        guide = None if spec.guide is None else {lang: {t: g.model_dump(mode="json") for t, g in by.items()}
                                                 for lang, by in spec.guide.items()}
        values = {"index": spec.index, "title": spec.title, "subtitle": spec.subtitle, "art_key": spec.art_key,
                  "guide": guide, "tracks": list(spec.tracks), "pass_percent": spec.pass_percent}
        row = units.get(spec.unit_id)
        if row is None:
            db.add(Unit(id=spec.unit_id, coming_soon=True, **values))
            report.created["units"] += 1
            continue
        if sorted(row.tracks) != sorted(spec.tracks) and spec.unit_id in published_units:
            problems.append(f"{spec.unit_id}: tracks cannot change while the unit has published lessons")
        if row.index != spec.index and spec.unit_id in published_units:
            problems.append(f"{spec.unit_id}: index cannot change while the unit has published lessons")
        changed = {k: v for k, v in values.items() if getattr(row, k) != v}
        if changed:
            for key, value in changed.items():
                setattr(row, key, value)
            report.updated["units"] += 1
    if problems:
        raise CurriculumError(problems)
    await db.flush()
    await refresh_unit_availability(db)


async def _apply_slots(db: AsyncSession, cur: Curriculum, report: SeedReport) -> None:
    lesson_ids = set((await db.execute(select(Lesson.id))).scalars())
    slots = {s.lesson_id: s for s in (await db.execute(select(CurriculumSlot))).scalars()}
    wanted = {s.lesson_id: (u.unit_id, i, s) for u, i, s in cur.slots()}
    moved = {lesson_id for lesson_id, slot in slots.items()
             if (target := wanted.get(lesson_id)) is None or (target[0], target[1]) != (slot.unit_id, slot.index)}
    problems = [f"{lesson_id}: the slot holds a lesson and cannot be moved or removed"
                for lesson_id in sorted(moved & lesson_ids)]
    if problems:
        raise CurriculumError(problems)
    for lesson_id in moved:  # empty slots only: delete, then re-create at their new position below
        await db.delete(slots.pop(lesson_id))
        report.removed["slots"] += 1 if lesson_id not in wanted else 0
    await db.flush()
    for lesson_id, (unit_id, index, spec) in wanted.items():
        title = spec.working_title.model_dump(exclude_none=True)
        focus = spec.focus.model_dump(exclude_none=True) if spec.focus else None
        row = slots.get(lesson_id)
        if row is None:
            db.add(CurriculumSlot(lesson_id=lesson_id, unit_id=unit_id, index=index, working_title=title, focus=focus))
            report.created["slots"] += 1
        elif (row.working_title, row.focus) != (title, focus):
            row.working_title, row.focus = title, focus
            report.updated["slots"] += 1
    await db.flush()


async def _apply_concepts(db: AsyncSession, cur: Curriculum, report: SeedReport) -> None:
    concepts = {c.id: c for c in (await db.execute(select(Concept))).scalars()}
    wanted = {c.concept_id: c for c in cur.concepts}
    problems = []
    for concept_id, row in concepts.items():
        if concept_id in wanted:
            continue
        if row.introduced_by_lesson_id is not None or await _concept_referenced(db, concept_id):
            problems.append(f"{concept_id}: concept is used by content and cannot be removed")
        else:
            await db.delete(row)
            report.removed["concepts"] += 1
    for concept_id, spec in wanted.items():
        values = {"unit_id": spec.unit_id, "title": spec.title, "prerequisite_ids": list(spec.prerequisite_ids)}
        existing = concepts.get(concept_id)
        if existing is None:
            db.add(Concept(id=concept_id, **values))
            report.created["concepts"] += 1
            continue
        if existing.unit_id != spec.unit_id and existing.introduced_by_lesson_id is not None:
            problems.append(f"{concept_id}: an introduced concept cannot move to another unit")
        changed = {k: v for k, v in values.items() if getattr(existing, k) != v}
        if changed:
            for key, value in changed.items():
                setattr(existing, key, value)
            report.updated["concepts"] += 1
    if problems:
        raise CurriculumError(problems)
    await db.flush()


async def _concept_referenced(db: AsyncSession, concept_id: str) -> bool:
    lesson_ref = await db.scalar(select(func.count()).select_from(Lesson).where(
        Lesson.prerequisite_concept_ids.any(concept_id) | Lesson.introduced_concept_ids.any(concept_id)))  # type: ignore[arg-type]
    exercise_ref = await db.scalar(select(func.count()).select_from(Exercise).where(
        Exercise.concept_ids.any(concept_id)))  # type: ignore[arg-type]
    return bool(lesson_ref or exercise_ref)


# =========================================================================================== import

@dataclass(frozen=True)
class ImportResult:
    lesson_version_id: uuid.UUID
    version: int
    created: bool


async def _context(db: AsyncSession, unit: Unit, *, allow_placeholder_media: bool) -> Context:
    return Context(
        unit_tracks=list(unit.tracks),
        known_terms=set((await db.execute(select(Term.id))).scalars()),
        known_sources=set((await db.execute(select(Source.id))).scalars()),
        known_misconceptions=set((await db.execute(select(Misconception.id))).scalars()),
        known_concepts=set((await db.execute(select(Concept.id))).scalars()),
        allow_placeholder_media=allow_placeholder_media,
        allow_timed_items=allow_placeholder_media,   # the same fixture-only allowance (D-29, D-61)
    )


def _fail(*messages: str) -> ContentValidationError:
    return ContentValidationError([Issue("placement", m) for m in messages])


async def _slot_and_unit(db: AsyncSession, package: LessonPackage) -> tuple[CurriculumSlot, Unit]:
    slot = await db.get(CurriculumSlot, package.lesson_id)
    if slot is None:
        raise _fail(f"{package.lesson_id} is not a curriculum slot (content/curriculum.yaml)")
    if (slot.unit_id, slot.index) != (package.unit_id, package.index):
        raise _fail(f"{package.lesson_id} sits at {slot.unit_id} position {slot.index}, "
                    f"not {package.unit_id} position {package.index}")
    unit = await db.get(Unit, slot.unit_id)
    assert unit is not None
    return slot, unit


def _exercise_version_content(record: ExerciseRecord) -> dict[str, Any]:
    return {
        "languages": {lang: {"exercise": record.exercise[lang].model_dump(mode="json", include=LEARNER_EXERCISE_FIELDS),
                             "feedback": record.feedback[lang].model_dump(mode="json")} for lang in LANGS},
        "targets_misconception_id": record.targets_misconception_id,
    }


async def import_package(db: AsyncSession, package: LessonPackage, *, origin: str, run_id: str | None = None,
                         allow_placeholder_media: bool = False,
                         edited_sentences: frozenset[tuple[str, str, str]] = frozenset()) -> ImportResult:
    """Store ``package`` as the next unpublished version of its lesson (caller owns the transaction).

    ``edited_sentences`` holds the (lang, variant, sentence_id) a Gate 2 reviewer edited (factory §13.6:
    ``edited_by_reviewer``). Versions of one lesson are numbered under a transaction-scoped lock on the lesson,
    so a factory publication and a gold import of the same slot can never claim the same version number."""
    if origin not in ("factory", "gold_import", "test_fixture"):
        raise ValueError(f"unknown content origin {origin!r}")
    if allow_placeholder_media and origin != "test_fixture":
        raise ValueError("fixture allowances apply only to test-fixture content (D-29)")
    await db.execute(text("SELECT pg_advisory_xact_lock(hashtextextended(:k, 0))"),
                     {"k": f"lesson_version:{package.lesson_id}"})
    _slot, unit = await _slot_and_unit(db, package)
    ctx = await _context(db, unit, allow_placeholder_media=allow_placeholder_media)
    unregistered = sorted((set(package.plan.introduced_concept_ids) | set(package.plan.prerequisite_concept_ids)
                           | {c for e in package.exercises for c in e.concept_ids}) - ctx.known_concepts)
    if unregistered:
        raise _fail(f"concepts are not in the curriculum concept graph: {unregistered}")
    require_valid(package, ctx)

    digest = package.digest()
    latest = (await db.execute(select(LessonVersion).where(LessonVersion.lesson_id == package.lesson_id)
                               .order_by(LessonVersion.version.desc()).limit(1))).scalar_one_or_none()
    if latest is not None and latest.content_sha256 == digest:
        return ImportResult(latest.id, latest.version, created=False)

    lesson = await db.get(Lesson, package.lesson_id)
    if lesson is None:
        db.add(Lesson(id=package.lesson_id, unit_id=package.unit_id, index=package.index,
                      lesson_type=package.plan.lesson_type, estimated_minutes=package.plan.estimated_minutes,
                      xp=xp_for(package)))
        await db.flush()

    exercise_versions: dict[str, int] = {}
    for record in package.exercises:
        exercise_versions[record.exercise_id] = await _store_exercise(db, package, record)

    version = (latest.version + 1) if latest else 1
    lesson_version = LessonVersion(
        lesson_id=package.lesson_id, version=version, run_id=run_id, origin=origin,
        plan=package.plan.model_dump(mode="json"),
        arc_map={"steps": [row.model_dump(mode="json") for row in package.arc_map]},
        content={
            "variants": {lang: {v: c.model_dump(mode="json") for v, c in by.items()}
                         for lang, by in package.variants.items()},
            "glossary": [t.model_dump(mode="json") for t in package.glossary],
            "misconceptions": [m.model_dump(mode="json") for m in package.misconceptions],
            "sources": [s.model_dump(mode="json") for s in package.sources],
            # A list, not an object: JSONB does not keep key order and the package's exercise order is content.
            "exercise_versions": [{"exercise_id": e, "version": v} for e, v in exercise_versions.items()],
        },
        content_sha256=digest, contract_revision=CONTRACT_REVISION, scene_schema="qabas.scene/1",
    )
    db.add(lesson_version)
    await db.flush()
    for version_row in (await db.execute(select(ExerciseVersion).where(
            ExerciseVersion.lesson_version_id.is_(None),
            ExerciseVersion.exercise_id.in_(list(exercise_versions))))).scalars():
        if exercise_versions.get(version_row.exercise_id) == version_row.version:
            version_row.lesson_version_id = lesson_version.id
    for claim in package.claims:      # an absent reasoning is SQL NULL, never JSON null (F-112)
        db.add(Claim(lesson_version_id=lesson_version.id, id=claim.claim_id, text=claim.text, status=claim.status,
                     basis=claim.basis, evidence=[e.model_dump(mode="json") for e in claim.evidence],
                     reasoning=claim.reasoning.model_dump(mode="json") if claim.reasoning else null()))
    roles = {row.sentence_id: row for row in package.sentence_map}
    for lang, variant in package.variant_keys():
        seen: set[str] = set()
        for block in package.variants[lang][variant].blocks:
            for sentence in sentences_of(block):
                sid = sentence["sentence_id"]
                if sid in seen:
                    continue
                seen.add(sid)
                row = roles[sid]
                db.add(SentenceRecord(lesson_version_id=lesson_version.id, lang=lang, variant=variant, id=sid,
                                      role=row.role, claim_ids=list(row.claim_ids),
                                      edited_by_reviewer=(lang, variant, sid) in edited_sentences))
    await db.flush()
    return ImportResult(lesson_version.id, version, created=True)


async def _store_exercise(db: AsyncSession, package: LessonPackage, record: ExerciseRecord) -> int:
    ar = record.exercise["ar"]
    row = await db.get(Exercise, record.exercise_id)
    if row is None:
        db.add(Exercise(id=record.exercise_id, lesson_id=package.lesson_id, unit_id=package.unit_id,
                        purpose=record.purpose, type=ar.type, concept_ids=list(ar.concept_ids)))
        await db.flush()
    else:
        if (row.type, row.purpose) != (ar.type, record.purpose):
            raise _fail(f"{record.exercise_id} is a {row.purpose} {row.type}; different content needs a new id")
        if row.lesson_id not in (None, package.lesson_id):
            raise _fail(f"{record.exercise_id} belongs to {row.lesson_id}")
        row.concept_ids = list(ar.concept_ids)
    content = _exercise_version_content(record)
    key = ar.answer_key.model_dump(mode="json") if ar.answer_key else None
    digest = content_digest({"content": content, "key": key,
                             "option_misconceptions": ar.option_misconceptions, "scoring": ar.scoring.model_dump(),
                             "framing": ar.framing.model_dump(mode="json") if ar.framing else None,
                             "source_ids": record.source_ids, "duel_eligible": ar.duel_eligible})
    latest = (await db.execute(select(ExerciseVersion).where(ExerciseVersion.exercise_id == record.exercise_id)
                               .order_by(ExerciseVersion.version.desc()).limit(1))).scalar_one_or_none()
    if latest is not None and latest.content_sha256 == digest:
        return latest.version
    version = (latest.version + 1) if latest else 1
    db.add(ExerciseVersion(
        exercise_id=record.exercise_id, version=version, content=content,
        scoring=ar.scoring.model_dump(mode="json"), framing=ar.framing.model_dump(mode="json") if ar.framing else None,
        answer_key=ar.answer_key.model_dump(mode="json") if ar.answer_key else {},
        option_misconceptions=dict(ar.option_misconceptions), source_ids=list(record.source_ids),
        duel_eligible=ar.duel_eligible, content_sha256=digest))
    await db.flush()
    return version


async def load_package(db: AsyncSession, lesson_version_id: uuid.UUID) -> LessonPackage:
    """Rebuild the exact package a stored lesson version was imported from."""
    lv = await db.get(LessonVersion, lesson_version_id)
    if lv is None:
        raise KeyError(f"no lesson version {lesson_version_id}")
    lesson = await db.get(Lesson, lv.lesson_id)
    assert lesson is not None
    claims = (await db.execute(select(Claim).where(Claim.lesson_version_id == lv.id))).scalars()
    sentences = (await db.execute(select(SentenceRecord).where(SentenceRecord.lesson_version_id == lv.id)
                                  .order_by(SentenceRecord.lang, SentenceRecord.variant))).scalars()
    # Order is content (it is part of the digest): rebuild it from where the sentences appear in the stored
    # variants, which is the order import_package wrote them, never from the table's physical row order (F-119).
    roles = {s.id: {"sentence_id": s.id, "role": s.role, "claim_ids": list(s.claim_ids)} for s in sentences}
    sentence_map: dict[str, dict[str, Any]] = {}
    for lang in LANGS:
        for variant in sorted(lv.content["variants"].get(lang, {})):
            for block in lv.content["variants"][lang][variant]["blocks"]:
                for sentence in sentences_of(block):
                    sentence_map.setdefault(sentence["sentence_id"], roles[sentence["sentence_id"]])
    exercises = []
    for exercise_id, version in catalog.pinned_exercise_versions(lv).items():
        ex = await db.get(Exercise, exercise_id)
        ev = await db.get(ExerciseVersion, (exercise_id, version))
        assert ex is not None and ev is not None
        exercises.append({
            "exercise_id": exercise_id, "purpose": ex.purpose,
            "exercise": {lang: {**ev.content["languages"][lang]["exercise"],
                                "answer_key": ev.answer_key or None, "option_misconceptions": ev.option_misconceptions,
                                "duel_eligible": ev.duel_eligible} for lang in LANGS},
            "feedback": {lang: ev.content["languages"][lang]["feedback"] for lang in LANGS},
            "targets_misconception_id": ev.content["targets_misconception_id"], "source_ids": list(ev.source_ids),
        })
    # Package order: claims and sentence map as imported; exercises in import order (dict order is preserved).
    claim_rows = sorted(claims, key=lambda c: c.id)
    return LessonPackage.model_validate({
        "lesson_id": lv.lesson_id, "unit_id": lesson.unit_id, "index": lesson.index, "plan": lv.plan,
        "variants": lv.content["variants"],
        "claims": [{"claim_id": c.id, "text": c.text, "status": c.status, "basis": c.basis, "evidence": c.evidence,
                    "reasoning": c.reasoning} for c in claim_rows],
        "sentence_map": list(sentence_map.values()), "arc_map": lv.arc_map["steps"] if lv.arc_map else [],
        "exercises": exercises, "glossary": lv.content["glossary"], "misconceptions": lv.content["misconceptions"],
        "sources": lv.content["sources"],
    })


# ====================================================================================== publication

@dataclass(frozen=True)
class Approval:
    """A Gate 2 approval (factory run) or Gate 2-equivalent approval (gold import): a ``review_decisions`` row
    bound to exactly this lesson version and its content digest (``published_digest``)."""

    decision_id: uuid.UUID


class FixtureApproval:
    """Test fixtures only: publishable outside production (D-29, D-84), never with real approval semantics."""


async def publish(db: AsyncSession, settings: Settings, lesson_version_id: uuid.UUID,
                  approval: Approval | FixtureApproval) -> None:
    """Publish one stored lesson version (caller owns the transaction; all-or-nothing)."""
    lv = (await db.execute(select(LessonVersion).where(LessonVersion.id == lesson_version_id)
                           .with_for_update())).scalar_one_or_none()
    if lv is None:
        raise KeyError(f"no lesson version {lesson_version_id}")
    if lv.published_at is not None:
        raise _fail(f"{lv.lesson_id} v{lv.version} is already published")
    newest = await db.scalar(select(func.max(LessonVersion.version)).where(LessonVersion.lesson_id == lv.lesson_id))
    if newest != lv.version:
        raise _fail(f"{lv.lesson_id} v{lv.version} is superseded by v{newest}; publish the latest version")

    fixture = isinstance(approval, FixtureApproval)
    if fixture:
        if lv.origin != "test_fixture" or not settings.allows_fixture_content:
            raise _fail("fixture approval applies only to test-fixture content outside production")
        reviewed_by = FIXTURE_REVIEWER
    else:
        if lv.origin == "test_fixture":
            raise _fail("test-fixture content is never published with a reviewer approval")
        reviewed_by = await _check_approval(db, lv, approval)

    package = await load_package(db, lv.id)
    if package.digest() != lv.content_sha256:
        raise _fail("stored content does not match its digest")
    _slot, unit = await _slot_and_unit(db, package)
    require_valid(package, await _context(db, unit, allow_placeholder_media=fixture))
    await _check_prerequisites(db, package, unit)
    await _check_scenes(db, package)

    await _upsert_sources(db, package)
    await _upsert_misconceptions(db, package)
    await _upsert_terms(db, package)
    now = _now()
    versions = catalog.pinned_exercise_versions(lv)
    for exercise_id, version in versions.items():
        ev = await db.get(ExerciseVersion, (exercise_id, version))
        assert ev is not None
        if ev.published_at is None:
            ev.targets_misconception_id = ev.content["targets_misconception_id"]
            ev.published_at = now
    await db.flush()
    for exercise_id, version in versions.items():
        await db.execute(update(Exercise).where(Exercise.id == exercise_id).values(current_version=version))
    for concept_id in package.plan.introduced_concept_ids:
        await db.execute(update(Concept).where(Concept.id == concept_id).values(introduced_by_lesson_id=lv.lesson_id))

    lv.reviewed_by = reviewed_by
    lv.published_at = now  # last write to the version (children first, D-22)
    await db.flush()
    variants = sorted({v for by in package.variants.values() for v in by})
    await db.execute(update(Lesson).where(Lesson.id == lv.lesson_id).values(
        current_version=lv.version, lesson_type=package.plan.lesson_type,
        estimated_minutes=package.plan.estimated_minutes, xp=xp_for(package),
        prerequisite_concept_ids=list(package.plan.prerequisite_concept_ids),
        introduced_concept_ids=list(package.plan.introduced_concept_ids),
        standalone_eligible=package.plan.standalone_eligible, variants=variants))
    await refresh_unit_availability(db)


async def refresh_unit_availability(db: AsyncSession) -> dict[str, bool]:
    """Recompute ``units.coming_soon`` for every unit from what is published; return unit_id -> coming_soon.

    A unit opens to learners only when it can be completed (decisions D-38, D-41):
      * it has a published lesson;
      * its published pools can serve both assessments: >= 6 pretest and >= 9 unit-test items (backend §6.2,
        factory §13.3); and
      * every prerequisite of its published lessons is introduced by a lesson in an open unit, so a Soft Lock
        never points at a lesson the learner cannot see.
    Units are decided in curriculum order; prerequisites always sit at earlier positions (publication check).
    """
    units = list((await db.execute(select(Unit).order_by(Unit.index))).scalars())
    lessons = await catalog.published_lessons(db)
    introducers = await catalog.introducers(db)
    unit_of = {lesson.lesson_id: lesson.unit_id for lesson in lessons}
    supplied: dict[str, dict[str, int]] = {}
    for unit in units:
        items = await catalog.pool(db, [unit.id], ("pretest", "unit_test"))
        supplied[unit.id] = {purpose: sum(1 for i in items if i.purpose == purpose)
                             for purpose in ("pretest", "unit_test")}
    prerequisite_units = {unit.id: {unit_of.get(introducers.get(c, ""), "") for lesson in lessons
                                    if lesson.unit_id == unit.id for c in lesson.prerequisite_concept_ids}
                          for unit in units}
    lesson_counts = {unit.id: sum(1 for lesson in lessons if lesson.unit_id == unit.id) for unit in units}
    open_units = decide_open_units([u.id for u in units], lesson_counts, supplied, prerequisite_units)
    for unit in units:
        if unit.coming_soon == (unit.id in open_units):
            unit.coming_soon = unit.id not in open_units
    await db.flush()
    return {unit.id: unit.id not in open_units for unit in units}


def decide_open_units(unit_order: list[str], lesson_counts: dict[str, int], supplied: dict[str, dict[str, int]],
                      prerequisite_units: dict[str, set[str]]) -> set[str]:
    """The units that can open (D-38, D-41), deciding in curriculum order.

    ``prerequisite_units[u]`` holds the units whose lessons introduce the prerequisites of u's published lessons
    ("" for a prerequisite without a published introducer, which never opens).
    """
    open_units: set[str] = set()
    for unit_id in unit_order:
        pools_ok = (supplied[unit_id].get("pretest", 0) >= PRETEST_POOL_MIN
                    and supplied[unit_id].get("unit_test", 0) >= UNIT_TEST_POOL_MIN)
        reachable = prerequisite_units[unit_id] <= open_units | {unit_id}
        if lesson_counts[unit_id] > 0 and pools_ok and reachable:
            open_units.add(unit_id)
    return open_units


async def _check_approval(db: AsyncSession, lv: LessonVersion, approval: Approval | FixtureApproval) -> str:
    """One approval path for every origin (D-139): the decision names this version and its exact content digest.
    A gold approval reviewed that content digest itself; a factory approval reviewed the run's Gate 2 draft
    (``reviewed_digest`` = the run's ``review_digest``) and belongs to the run that produced this version."""
    assert isinstance(approval, Approval)
    decision = await db.get(ReviewDecision, approval.decision_id)
    bound = (decision is not None and decision.gate == 2 and decision.decision == "approve"
             and decision.lesson_version_id == lv.id and decision.published_digest == lv.content_sha256)
    if bound and decision is not None:
        if lv.origin == "factory":
            bound = lv.run_id is not None and decision.run_id == lv.run_id
        else:
            bound = decision.run_id is None and decision.reviewed_digest == lv.content_sha256
    if not bound or decision is None:
        raise _fail("publication needs a Gate 2 approval of exactly this content digest")
    reviewer = await db.get(User, decision.reviewer_id)
    if reviewer is None or reviewer.role != "reviewer" or reviewer.deactivated_at is not None:
        raise _fail("the approving reviewer is not an active reviewer")
    return reviewer.display_name


async def _check_prerequisites(db: AsyncSession, package: LessonPackage, unit: Unit) -> None:
    """Backend §6.1 / factory §13.5: every prerequisite is introduced by a published lesson at an earlier
    curriculum position, available in every track this lesson serves; each concept is introduced once."""
    problems = []
    position = (unit.index, package.index)
    for concept_id in package.plan.prerequisite_concept_ids:
        concept = await db.get(Concept, concept_id)
        introducer = (await db.get(Lesson, concept.introduced_by_lesson_id)
                      if concept and concept.introduced_by_lesson_id else None)
        if introducer is None or introducer.current_version is None:
            problems.append(f"prerequisite {concept_id} is not introduced by a published lesson")
            continue
        introducer_unit = await db.get(Unit, introducer.unit_id)
        assert introducer_unit is not None
        if (introducer_unit.index, introducer.index) >= position:
            problems.append(f"prerequisite {concept_id} is introduced at a later curriculum position")
        if not set(unit.tracks) <= set(introducer_unit.tracks):
            problems.append(f"prerequisite {concept_id} is not available in every track this lesson serves")
    for concept_id in package.plan.introduced_concept_ids:
        concept = await db.get(Concept, concept_id)
        if concept is not None and concept.introduced_by_lesson_id not in (None, package.lesson_id):
            problems.append(f"{concept_id} is already introduced by {concept.introduced_by_lesson_id}")
    if problems:
        raise _fail(*problems)


async def _check_scenes(db: AsyncSession, package: LessonPackage) -> None:
    """Backend §6.5: a scene visual references a published scene version with the same manifest digest."""
    problems = []
    for lang, variant in package.variant_keys():
        for ref in scene_refs(package.variants[lang][variant].model_dump(mode="json")):
            row = await db.get(SceneVersion, (ref["scene_id"], ref["version"]))
            if row is None or row.status != "published":
                problems.append(f"scene {ref['scene_id']} v{ref['version']} is not a published scene version")
            elif row.sha256 != ref["sha256"]:
                problems.append(f"scene {ref['scene_id']} v{ref['version']}: "
                                "SceneRef sha256 differs from the stored manifest")
    if problems:
        raise _fail(*sorted(set(problems)))


def scene_refs(node: Any) -> list[dict[str, Any]]:
    found = []
    if isinstance(node, dict):
        if node.get("kind") == "scene" and isinstance(node.get("scene"), dict):
            found.append(node["scene"])
        for value in node.values():
            found += scene_refs(value)
    elif isinstance(node, list):
        for value in node:
            found += scene_refs(value)
    return found


async def _upsert_sources(db: AsyncSession, package: LessonPackage) -> None:
    for record in package.sources:
        row = await db.get(Source, record.source_id)
        values = record.model_dump(exclude={"source_id"})
        if row is None:
            db.add(Source(id=record.source_id, **values))
        elif any(getattr(row, k) != v for k, v in values.items()):
            raise _fail(f"source {record.source_id} already exists with different content; cite it unchanged "
                        "or give the new record its own id")


async def _upsert_misconceptions(db: AsyncSession, package: LessonPackage) -> None:
    for record in package.misconceptions:
        row = await db.get(Misconception, record.misconception_id)
        dumped = record.model_dump(mode="json")   # cards are Span models; the row stores JSON
        values = {"unit_id": package.unit_id, "concept_id": record.concept_id, "title": dumped["title"],
                  "card": dumped["card"], "source_ids": list(record.source_ids)}
        if row is None:
            db.add(Misconception(id=record.misconception_id, **values))
        else:
            for key, value in values.items():
                setattr(row, key, value)
    await db.flush()


async def _upsert_terms(db: AsyncSession, package: LessonPackage) -> None:
    for term in package.glossary:
        row = await db.get(Term, term.term_id)
        values = {"text": term.text.model_dump(), "arabic": term.arabic, "transliteration": term.transliteration,
                  "concept_id": term.concept_id, "lesson_id": term.lesson_id, "source_id": term.source_id,
                  "pronunciation_audio_url": term.pronunciation_audio_url,
                  "definition": term.definition.model_dump(mode="json"),
                  "example": term.example.model_dump(mode="json")}
        if row is None:
            db.add(Term(id=term.term_id, **values))
        else:
            for key, value in values.items():
                setattr(row, key, value)
    await db.flush()
