"""The learner's journey (backend §6.1, API §6.3): track membership, access, states and Soft Lock.

States are derived on every read from stored facts (decision D-21); nothing is pre-locked or pre-unlocked:

* **Track membership:** units whose ``tracks`` include the learner's track, in curriculum order. A
  ``coming_soon`` unit lists no lessons (D-38).
* **Prerequisites** are concepts. A concept is satisfied when the lesson that introduces it is completed (from
  any surface, track or variant) or that lesson's unit test was passed (unit ``completed``/``skipped``).
* **Lesson state:** ``completed`` > ``in_progress`` (an active lesson session) > ``locked`` (an unmet
  prerequisite; ``soft_lock`` names why and where to start) > ``available``. Curriculum position never gates.
* **Unit state:** ``locked`` when coming soon; ``completed``/``skipped`` once its unit test was passed (all
  lessons completed or not); ``in_progress`` once any of its sessions started; ``available`` when any lesson can
  be opened; else ``locked``. Units never wait for the previous unit.
"""

from __future__ import annotations

from dataclasses import dataclass, field

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.content import catalog
from app.content.catalog import PublishedLesson
from app.content.projection import select_variant
from app.contract import models as C
from app.models import LearnerLesson, LearnerUnit, LearningSession, Unit, User


class JourneyIntegrityError(RuntimeError):
    """Published curriculum data that the publication checks should have made impossible."""


@dataclass
class JourneyView:
    """Everything needed to answer "where is this learner?" for one track, read once per request."""

    user: User
    track: str
    units: list[Unit]
    lessons: dict[str, list[PublishedLesson]]          # unit_id -> published lessons (empty when coming soon)
    introducers: dict[str, str]                        # concept_id -> introducing lesson_id
    completed: set[str]                                # canonical lesson ids completed (any track/surface)
    unit_facts: dict[str, LearnerUnit]
    active_lessons: set[str]                           # lessons with an active lesson session
    _by_id: dict[str, PublishedLesson] = field(default_factory=dict)
    _all_published: dict[str, PublishedLesson] = field(default_factory=dict)

    # --- lookups ---------------------------------------------------------------------------------------------

    def lesson(self, lesson_id: str) -> PublishedLesson | None:
        """A lesson of this journey (published, in a unit of the track that is not coming soon)."""
        return self._by_id.get(lesson_id)

    def unit(self, unit_id: str) -> Unit | None:
        return next((u for u in self.units if u.id == unit_id), None)

    def variant_of(self, lesson: PublishedLesson) -> str:
        return select_variant(set(lesson.variants), self.track)

    def title(self, lesson: PublishedLesson, lang: str) -> str:
        return lesson.title(lang, self.variant_of(lesson))

    def unit_passed(self, unit_id: str) -> bool:
        fact = self.unit_facts.get(unit_id)
        return fact is not None and fact.unit_test_passed_at is not None

    # --- prerequisites ---------------------------------------------------------------------------------------

    def concept_satisfied(self, concept_id: str) -> bool:
        introducer = self.introducers.get(concept_id)
        if introducer is None:
            raise JourneyIntegrityError(f"prerequisite {concept_id} has no introducing lesson")
        lesson = self._all_published.get(introducer)
        if lesson is None:
            raise JourneyIntegrityError(f"prerequisite {concept_id} is introduced by unpublished {introducer}")
        return introducer in self.completed or self.unit_passed(lesson.unit_id)

    def unmet_introducers(self, lesson: PublishedLesson) -> list[PublishedLesson]:
        """Lessons introducing ``lesson``'s unmet prerequisites, in curriculum order."""
        found: dict[str, PublishedLesson] = {}
        for concept_id in lesson.prerequisite_concept_ids:
            if not self.concept_satisfied(concept_id):
                introducer = self.lesson(self.introducers[concept_id])
                if introducer is None:  # D-41 keeps such units closed; reaching here is a data error
                    raise JourneyIntegrityError(
                        f"{lesson.lesson_id}: prerequisite {concept_id} is introduced outside this journey")
                found[introducer.lesson_id] = introducer
        return sorted(found.values(), key=self.position)

    def position(self, lesson: PublishedLesson) -> tuple[int, int]:
        unit = self.unit(lesson.unit_id)
        assert unit is not None
        return unit.index, lesson.index

    def start_with(self, lesson: PublishedLesson, _seen: frozenset[str] = frozenset()) -> PublishedLesson | None:
        """The first lesson reached by following unmet prerequisites (earliest position first) whose own
        prerequisites are met (backend §6.1)."""
        for introducer in self.unmet_introducers(lesson):
            if introducer.lesson_id in _seen:
                continue
            if not self.unmet_introducers(introducer):
                return introducer
            deeper = self.start_with(introducer, _seen | {lesson.lesson_id})
            if deeper is not None:
                return deeper
        return None

    # --- states ----------------------------------------------------------------------------------------------

    def lesson_state(self, lesson: PublishedLesson) -> str:
        if lesson.lesson_id in self.completed:
            return "completed"
        if lesson.lesson_id in self.active_lessons:
            return "in_progress"
        if self.unmet_introducers(lesson):
            return "locked"
        return "available"

    def soft_lock(self, lesson: PublishedLesson, lang: str) -> C.SoftLock | None:
        if self.lesson_state(lesson) != "locked":
            return None
        start = self.start_with(lesson)
        if start is None:
            raise JourneyIntegrityError(f"{lesson.lesson_id}: no reachable lesson to start with")
        return C.SoftLock(prerequisites=[self.ref(p, lang) for p in self.unmet_introducers(lesson)],
                          start_with=self.ref(start, lang))

    def ref(self, lesson: PublishedLesson, lang: str) -> C.LessonRef:
        return C.LessonRef(lesson_id=lesson.lesson_id, unit_id=lesson.unit_id, title=self.title(lesson, lang))

    def unit_state(self, unit: Unit) -> str:
        if unit.coming_soon:
            return "locked"
        lessons = self.lessons[unit.id]
        if self.unit_passed(unit.id):
            return "completed" if all(lsn.lesson_id in self.completed for lsn in lessons) else "skipped"
        fact = self.unit_facts.get(unit.id)
        if fact is not None and fact.started_at is not None:
            return "in_progress"
        if any(self.lesson_state(lsn) != "locked" for lsn in lessons):
            return "available"
        return "locked"

    def remaining(self, unit: Unit) -> list[PublishedLesson]:
        return [lsn for lsn in self.lessons[unit.id] if lsn.lesson_id not in self.completed]

    def lesson_target(self, unit: Unit) -> PublishedLesson | None:
        """Planner rule 3: the first available/in-progress lesson of ``unit`` in curriculum order; when every
        remaining lesson is locked, the Soft Lock ``start_with`` of the first one (possibly in another unit)."""
        remaining = self.remaining(unit)
        for lesson in remaining:
            if self.lesson_state(lesson) in ("available", "in_progress"):
                return lesson
        if remaining:
            return self.start_with(remaining[0])
        return None


async def load_view(db: AsyncSession, user: User, track: str | None = None) -> JourneyView:
    track = track or user.track
    units = list((await db.execute(select(Unit).where(Unit.tracks.contains([track])).order_by(Unit.index))).scalars())
    published = await catalog.published_lessons(db)
    open_units = {u.id for u in units if not u.coming_soon}
    lessons: dict[str, list[PublishedLesson]] = {u.id: [] for u in units}
    for lesson in published:
        if lesson.unit_id in open_units:
            lessons[lesson.unit_id].append(lesson)
    completed = set((await db.execute(select(LearnerLesson.lesson_id).where(
        LearnerLesson.user_id == user.id, LearnerLesson.completed_at.is_not(None)))).scalars())
    facts = {f.unit_id: f for f in (await db.execute(
        select(LearnerUnit).where(LearnerUnit.user_id == user.id))).scalars()}
    active = set((await db.execute(select(LearningSession.lesson_id).where(
        LearningSession.user_id == user.id, LearningSession.status == "active",
        LearningSession.kind == "lesson"))).scalars())
    view = JourneyView(user=user, track=track, units=units, lessons=lessons,
                       introducers=await catalog.introducers(db), completed=completed, unit_facts=facts,
                       active_lessons={lesson_id for lesson_id in active if lesson_id})
    view._by_id = {lsn.lesson_id: lsn for by_unit in lessons.values() for lsn in by_unit}
    view._all_published = {lsn.lesson_id: lsn for lsn in published}
    return view


def journey_response(view: JourneyView, lang: str, current: C.JourneyCurrent) -> C.Journey:
    units = []
    for unit in view.units:
        state = view.unit_state(unit)
        fact = view.unit_facts.get(unit.id)
        lessons = [C.JLesson(
            lesson_id=lsn.lesson_id, index=lsn.index, title=view.title(lsn, lang), lesson_type=lsn.lesson_type,
            state=view.lesson_state(lsn), estimated_minutes=lsn.estimated_minutes, xp=lsn.xp,
            standalone_eligible=lsn.standalone_eligible, soft_lock=view.soft_lock(lsn, lang))
            for lsn in view.lessons[unit.id]]
        units.append(C.JUnit(
            unit_id=unit.id, index=unit.index, title=unit.title[lang][view.track],
            subtitle=unit.subtitle[lang][view.track], art_key=unit.art_key,
            has_guide=has_guide(unit, lang, view.track), state=state, coming_soon=unit.coming_soon,
            pretest=C.JPretest(state="taken" if fact is not None and fact.pretest_taken_at is not None
                               else "not_taken"),
            unit_test=C.JUnitTest(
                state="passed" if view.unit_passed(unit.id) else "not_passed",
                best_percent=fact.unit_test_best_percent if fact is not None else None,
                pass_percent=unit.pass_percent,
                can_skip=state not in ("completed", "skipped") and not unit.coming_soon),
            lessons=lessons))
    return C.Journey(track=view.track, current=current, units=units)


def has_guide(unit: Unit, lang: str, track: str) -> bool:
    return bool(unit.guide and unit.guide.get(lang, {}).get(track))


def soft_lock_details(view: JourneyView, lesson: PublishedLesson) -> dict[str, object]:
    """``409 prerequisite_unmet`` details: the same data as the journey ``soft_lock`` (API §6.5)."""
    start = view.start_with(lesson)
    return {"prerequisite_lesson_ids": [p.lesson_id for p in view.unmet_introducers(lesson)],
            "start_with_lesson_id": start.lesson_id if start else None}
