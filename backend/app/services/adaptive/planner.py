"""Next-step planner (backend §7.3): ``GET /journey/next``, ``GET /journey`` ``current``, onboarding, finish.

Rules, first match wins, starting at the current unit:
  1. Current unit = the first unit of the learner's track path that is neither completed/skipped nor
     ``coming_soon`` (decision D-44). If its pretest isn't taken and none of its lessons is completed yet
     (lessons may be done through Discover) -> ``pretest``.
  2. At least 5 due concepts (FSRS ``due_at <= now``, learning or mastered) and a card deck to serve
     -> ``review`` (backend §7.4: the planner never recommends a review that would be ``nothing_to_review``).
  3. The first available/in-progress lesson of the unit in curriculum order; if every remaining lesson is
     locked, the Soft Lock ``start_with`` of the first one -> ``lesson``.
  4. All lessons completed and the unit test not passed -> ``unit_test``.
  5. Otherwise the next unit (loop to 1); none left -> ``journey_complete``.
Curriculum position orders recommendations only; it never gates access (AD-29).

``current`` (journey pointer, decision D-45) is the rule-3 lesson of the current unit when there is one,
whatever the next step is, else the current unit alone; with no current unit both ids are null.
"""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.contract import models as C
from app.i18n import NEXT_STEP_TITLES
from app.models import LearnerConcept, User
from app.services.learning import review
from app.services.learning.journey import JourneyView, load_view
from app.services.platform.auth_sessions import utcnow

DUE_REVIEW_THRESHOLD = 5


async def due_reviews_count(db: AsyncSession, user_id: str, now: datetime) -> int:
    """Concepts due for review that the learner is learning or has mastered (mastery > 0)."""
    count = await db.scalar(select(func.count()).select_from(LearnerConcept).where(
        LearnerConcept.user_id == user_id, LearnerConcept.due_at <= now, LearnerConcept.mastery > 0))
    return int(count or 0)


async def plan(db: AsyncSession, view: JourneyView, lang: str, *,
               now: datetime | None = None) -> tuple[C.NextStep, C.JourneyCurrent]:
    now = now or utcnow()
    user = view.user
    due = await due_reviews_count(db, user.id, now)
    reviewable: bool | None = None
    current: C.JourneyCurrent | None = None
    for unit in view.units:
        if unit.coming_soon or view.unit_state(unit) in ("completed", "skipped"):
            continue
        target = view.lesson_target(unit)
        if current is None:
            current = (C.JourneyCurrent(unit_id=target.unit_id, lesson_id=target.lesson_id) if target
                       else C.JourneyCurrent(unit_id=unit.id, lesson_id=None))
        fact = view.unit_facts.get(unit.id)
        if (fact is None or fact.pretest_taken_at is None) and not any(
                lsn.lesson_id in view.completed for lsn in view.lessons[unit.id]):
            return _unit_step("pretest", "new_unit_pretest", unit.id, lang, due), current
        if due >= DUE_REVIEW_THRESHOLD:
            if reviewable is None:
                reviewable = bool(await review.select_cards(db, view, now))
            if reviewable:
                return C.NextStep(type="review", reason="due_reviews", unit_id=None, lesson_id=None,
                                  title=NEXT_STEP_TITLES["review"][lang], due_reviews_count=due), current
        if target is not None:
            return C.NextStep(type="lesson", reason="next_lesson", unit_id=target.unit_id,
                              lesson_id=target.lesson_id, title=view.title(target, lang),
                              due_reviews_count=due), current
        if not view.remaining(unit) and not view.unit_passed(unit.id):
            return _unit_step("unit_test", "unit_ready_for_test", unit.id, lang, due), current
    return (C.NextStep(type="journey_complete", reason="all_done", unit_id=None, lesson_id=None, title=None,
                       due_reviews_count=due),
            current or C.JourneyCurrent(unit_id=None, lesson_id=None))


def _unit_step(kind: str, reason: str, unit_id: str, lang: str, due: int) -> C.NextStep:
    return C.NextStep(type=kind, reason=reason, unit_id=unit_id, lesson_id=None,
                      title=NEXT_STEP_TITLES[kind][lang], due_reviews_count=due)


async def next_step(db: AsyncSession, user: User, *, lang: str | None = None,
                    now: datetime | None = None) -> C.NextStep:
    step, _ = await plan(db, await load_view(db, user), lang or user.language, now=now)
    return step
