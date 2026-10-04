"""Learner statistics and stable cursor pages from authoritative learning facts."""

from datetime import date, timedelta
from decimal import Decimal
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.contract import models as C
from app.errors import ApiError, ErrorCode
from app.models import (
    Concept,
    DailyActivity,
    LearnerConcept,
    LearnerLesson,
    LearnerMisconception,
    LearnerTerm,
    LearnerUnit,
    User,
    XpEvent,
)
from app.services.learning import grading, progress, xp
from app.services.platform.auth_sessions import utcnow
from app.services.users import iso


def invalid(field: str) -> ApiError:
    return ApiError(ErrorCode.validation_error, "Invalid query parameter.", {"field": field})


def page_args(cursor: str | None, limit: int) -> None:
    if not 1 <= limit <= 100:
        raise invalid("limit")
    if cursor is not None and (len(cursor) > 200 or not cursor.startswith(("con_", "term_"))):
        raise invalid("cursor")


async def stats(db: AsyncSession, user: User) -> C.Stats:
    now = utcnow()
    today = xp.local_date(now, user.timezone)

    async def count(model: Any, *conditions: Any) -> int:
        return int(await db.scalar(select(func.count()).select_from(model).where(
            model.user_id == user.id, *conditions)) or 0)

    total = int(await db.scalar(select(func.coalesce(func.sum(XpEvent.xp), 0)).where(XpEvent.user_id == user.id)) or 0)
    weekly = int(await db.scalar(select(func.coalesce(func.sum(XpEvent.xp), 0)).where(
        XpEvent.user_id == user.id, XpEvent.week_key == xp.week_key(now))) or 0)
    daily = await db.get(DailyActivity, (user.id, today))
    minutes = daily.minutes if daily else 0
    return C.Stats(xp_total=total, xp_this_week=weekly, streak=await progress.streak(db, user, today),
                   daily_goal={"minutes": user.daily_goal_minutes, "minutes_today": minutes,
                               "met": minutes >= user.daily_goal_minutes}, league=None,
                   concepts={"mastered": await count(LearnerConcept, LearnerConcept.mastery >= Decimal("0.8")),
                             "learning": await count(LearnerConcept, LearnerConcept.mastery > 0,
                                                      LearnerConcept.mastery < Decimal("0.8"))},
                   terms={"mastered": await count(LearnerTerm, LearnerTerm.state == "mastered"),
                          "seen": await count(LearnerTerm, LearnerTerm.state != "new")},
                   misconceptions={"active": await count(LearnerMisconception, LearnerMisconception.status == "active"),
                                   "resolved": await count(LearnerMisconception,
                                                           LearnerMisconception.status == "resolved")},
                   lessons_completed=await count(LearnerLesson, LearnerLesson.completed_at.is_not(None)),
                   units_completed=await count(LearnerUnit, LearnerUnit.unit_test_passed_at.is_not(None)))


async def activity(db: AsyncSession, user: User, from_: str | None, to: str | None) -> C.Activity:
    today = xp.local_date(utcnow(), user.timezone)
    try:
        end = date.fromisoformat(to) if to else today
        start = date.fromisoformat(from_) if from_ else end - timedelta(days=34)
    except ValueError:
        raise invalid("from/to") from None
    if not 0 <= (end - start).days <= 61:
        raise invalid("from/to")
    rows = (await db.execute(select(DailyActivity).where(DailyActivity.user_id == user.id,
                             DailyActivity.qualifying.is_(True), DailyActivity.local_date.between(start, end))
                             .order_by(DailyActivity.local_date))).scalars()
    return C.Activity.model_validate({"timezone": user.timezone, "from": start.isoformat(), "to": end.isoformat(),
                                      "streak": await progress.streak(db, user, today),
                                      "days": [{"date": r.local_date.isoformat(), "qualifying": True,
                                                "minutes": r.minutes, "xp": r.xp} for r in rows]})


async def concepts(db: AsyncSession, user: User, lang: str, cursor: str | None, limit: int) -> Any:
    page_args(cursor, limit)
    query = select(Concept, LearnerConcept).join(LearnerConcept, LearnerConcept.concept_id == Concept.id).where(
        LearnerConcept.user_id == user.id)
    if cursor:
        query = query.where(Concept.id > cursor)
    rows = list((await db.execute(query.order_by(Concept.id).limit(limit + 1))).all())
    return C.EXPORTED["ConceptPage"].model_validate({
        "items": [{"concept_id": c.id, "title": c.title[lang], "unit_id": c.unit_id,
                   "mastery": grading.report(r.mastery), "next_review_at": iso(r.due_at) if r.due_at else None}
                  for c, r in rows[:limit]], "next_cursor": rows[limit - 1][0].id if len(rows) > limit else None})
