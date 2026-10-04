"""Next-step planner (backend §7.3): ``GET /journey/next``, onboarding and session finish.

Rules, first match wins:
  1. Current unit = first unit of the learner's track path that is neither completed nor skipped.
     If it is ``coming_soon`` (or there is none) -> ``journey_complete`` (rule 5). If its pretest
     isn't taken and none of its lessons is completed -> ``pretest``.
  2. At least 5 due concepts -> ``review``.
  3. First available/in-progress lesson in curriculum order (or the Soft Lock ``start_with``).
  4. All lessons completed and the unit test not passed -> ``unit_test``.
Rules 3-4 need lesson access state (prerequisites, Soft Lock) from the journey service, which
arrives in Phases 5/7. Until then no lesson can be started, so the planner never reaches them.
Curriculum position orders recommendations only; it never gates access (AD-29).
"""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.contract import models as C
from app.i18n import NEXT_STEP_TITLES
from app.models import LearnerConcept, LearnerLesson, LearnerUnit, Lesson, Unit, User
from app.services.platform.auth_sessions import utcnow

DUE_REVIEW_THRESHOLD = 5


async def track_path(db: AsyncSession, track: str) -> list[Unit]:
    """Units of the learner's track in curriculum order (Unit 0 is Explorer-only, AD-28)."""
    rows = await db.execute(select(Unit).where(Unit.tracks.contains([track])).order_by(Unit.index))
    return list(rows.scalars())


async def due_reviews_count(db: AsyncSession, user_id: str, now: datetime) -> int:
    count = await db.scalar(select(func.count()).select_from(LearnerConcept)
                            .where(LearnerConcept.user_id == user_id, LearnerConcept.due_at <= now))
    return int(count or 0)


async def next_step(db: AsyncSession, user: User, *, now: datetime | None = None) -> C.NextStep:
    now = now or utcnow()
    due = await due_reviews_count(db, user.id, now)
    facts = {row.unit_id: row for row in (await db.execute(
        select(LearnerUnit).where(LearnerUnit.user_id == user.id))).scalars()}
    current: Unit | None = None
    for unit in await track_path(db, user.track):
        fact = facts.get(unit.id)
        if fact is not None and (fact.completed_at is not None or fact.skipped_at is not None):
            continue
        current = unit
        break
    if current is None or current.coming_soon:
        return C.NextStep(type="journey_complete", reason="all_done", unit_id=None, lesson_id=None, title=None,
                          due_reviews_count=due)

    fact = facts.get(current.id)
    completed_in_unit = await db.scalar(
        select(func.count()).select_from(LearnerLesson).join(Lesson, Lesson.id == LearnerLesson.lesson_id)
        .where(LearnerLesson.user_id == user.id, LearnerLesson.completed_at.is_not(None),
               Lesson.unit_id == current.id))
    if (fact is None or fact.pretest_taken_at is None) and not completed_in_unit:
        return C.NextStep(type="pretest", reason="new_unit_pretest", unit_id=current.id, lesson_id=None,
                          title=NEXT_STEP_TITLES["pretest"][user.language], due_reviews_count=due)
    if due >= DUE_REVIEW_THRESHOLD:
        return C.NextStep(type="review", reason="due_reviews", unit_id=None, lesson_id=None,
                          title=NEXT_STEP_TITLES["review"][user.language], due_reviews_count=due)
    raise NotImplementedError("planner rules 3-4 (lesson and unit-test steps) arrive with the journey service")
