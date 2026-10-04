"""Read access to *published* content, shared by publication, unit availability and the learner services.

Everything here reads only current published versions: ``lessons.current_version`` and the exercise versions
that version pins. A learner never sees an unpublished version, and two callers can't disagree about what
"the unit's pretest pool" is (decisions D-38, D-41).
"""

from __future__ import annotations

import uuid
from dataclasses import dataclass
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Concept, Exercise, ExerciseVersion, Lesson, LessonVersion, Source, Term, Unit


@dataclass(frozen=True)
class PublishedLesson:
    """A lesson's current published version, with what the Roadmap needs from it."""

    lesson_id: str
    unit_id: str
    index: int
    lesson_type: str
    estimated_minutes: int
    xp: int
    standalone_eligible: bool
    prerequisite_concept_ids: tuple[str, ...]
    introduced_concept_ids: tuple[str, ...]
    variants: tuple[str, ...]
    version: int
    lesson_version_id: uuid.UUID
    titles: dict[str, dict[str, str]]  # {lang: {variant: title}}

    def title(self, lang: str, variant: str) -> str:
        return self.titles[lang][variant]


@dataclass(frozen=True)
class PoolItem:
    exercise_id: str
    version: int
    lesson_id: str
    purpose: str
    type: str
    concept_ids: tuple[str, ...]


async def published_lessons(db: AsyncSession, unit_ids: list[str] | None = None) -> list[PublishedLesson]:
    """Published lessons in curriculum order (unit index, lesson index)."""
    titles = {lang: {variant: LessonVersion.content["variants"][lang][variant]["title"].astext
                     for variant in ("explorer", "new_muslim")} for lang in ("ar", "en")}
    columns = [titles[lang][variant] for lang in ("ar", "en") for variant in ("explorer", "new_muslim")]
    query = (select(Lesson, LessonVersion.id, *columns)
             .join(LessonVersion, (LessonVersion.lesson_id == Lesson.id)
                   & (LessonVersion.version == Lesson.current_version))
             .join(Unit, Unit.id == Lesson.unit_id)
             .where(Lesson.current_version.is_not(None), LessonVersion.published_at.is_not(None))
             .order_by(Unit.index, Lesson.index))
    if unit_ids is not None:
        query = query.where(Lesson.unit_id.in_(unit_ids))
    found = []
    for lesson, lesson_version_id, ar_ex, ar_nm, en_ex, en_nm in await db.execute(query):
        raw = {"ar": {"explorer": ar_ex, "new_muslim": ar_nm}, "en": {"explorer": en_ex, "new_muslim": en_nm}}
        found.append(PublishedLesson(
            lesson_id=lesson.id, unit_id=lesson.unit_id, index=lesson.index, lesson_type=lesson.lesson_type,
            estimated_minutes=lesson.estimated_minutes, xp=lesson.xp, standalone_eligible=lesson.standalone_eligible,
            prerequisite_concept_ids=tuple(lesson.prerequisite_concept_ids),
            introduced_concept_ids=tuple(lesson.introduced_concept_ids), variants=tuple(lesson.variants),
            version=lesson.current_version, lesson_version_id=lesson_version_id,
            titles={lang: {v: t for v, t in by.items() if t is not None} for lang, by in raw.items()}))
    return found


async def current_version(db: AsyncSession, lesson_id: str) -> LessonVersion | None:
    """The lesson's current published version, or None when it has none."""
    row = await db.execute(select(LessonVersion).join(Lesson, (Lesson.id == LessonVersion.lesson_id)
                                                      & (Lesson.current_version == LessonVersion.version))
                           .where(Lesson.id == lesson_id, LessonVersion.published_at.is_not(None)))
    return row.scalar_one_or_none()


def pinned_exercise_versions(lesson_version: LessonVersion) -> dict[str, int]:
    """The exercise versions a lesson version pins, in package order (decision D-34)."""
    return {row["exercise_id"]: row["version"] for row in lesson_version.content["exercise_versions"]}


async def pool(db: AsyncSession, unit_ids: list[str], purposes: tuple[str, ...]) -> list[PoolItem]:
    """Exercises of the given purposes pinned by the *current published* versions of the units' lessons.

    An exercise that a newer lesson version dropped is no longer in any pool, even though its old version
    stays published for sessions that served it.
    """
    pinned: dict[str, tuple[int, str]] = {}
    rows = await db.execute(select(LessonVersion).join(Lesson, (Lesson.id == LessonVersion.lesson_id)
                                                       & (Lesson.current_version == LessonVersion.version))
                            .where(Lesson.unit_id.in_(unit_ids), LessonVersion.published_at.is_not(None)))
    for lesson_version in rows.scalars():
        for exercise_id, version in pinned_exercise_versions(lesson_version).items():
            pinned[exercise_id] = (version, lesson_version.lesson_id)
    if not pinned:
        return []
    exercises = await db.execute(select(Exercise).where(Exercise.id.in_(list(pinned)),
                                                        Exercise.purpose.in_(purposes)).order_by(Exercise.id))
    return [PoolItem(exercise_id=e.id, version=pinned[e.id][0], lesson_id=pinned[e.id][1], purpose=e.purpose,
                     type=e.type,
                     concept_ids=tuple(e.concept_ids)) for e in exercises.scalars()]


async def exercise_versions(db: AsyncSession, keys: list[tuple[str, int]]) -> dict[tuple[str, int], ExerciseVersion]:
    if not keys:
        return {}
    rows = await db.execute(select(ExerciseVersion).where(
        ExerciseVersion.published_at.is_not(None),
        ExerciseVersion.exercise_id.in_({k for k, _ in keys})))
    wanted = set(keys)
    return {(r.exercise_id, r.version): r for r in rows.scalars() if (r.exercise_id, r.version) in wanted}


async def sources(db: AsyncSession, source_ids: list[str]) -> dict[str, dict[str, Any]]:
    """Registry source records (contract ``Source`` fields without the display flags)."""
    if not source_ids:
        return {}
    rows = await db.execute(select(Source).where(Source.id.in_(source_ids)))
    return {s.id: {"source_id": s.id, "kind": s.kind, "provider": s.provider, "title": s.title,
                   "reference": s.reference, "excerpt": s.excerpt, "url": s.url} for s in rows.scalars()}


async def terms(db: AsyncSession, term_ids: list[str]) -> dict[str, Term]:
    if not term_ids:
        return {}
    return {t.id: t for t in (await db.execute(select(Term).where(Term.id.in_(term_ids)))).scalars()}


async def introducers(db: AsyncSession) -> dict[str, str]:
    """concept_id -> the lesson that introduces it (set once at publication)."""
    rows = await db.execute(select(Concept.id, Concept.introduced_by_lesson_id)
                            .where(Concept.introduced_by_lesson_id.is_not(None)))
    return {concept_id: str(lesson_id) for concept_id, lesson_id in rows}
