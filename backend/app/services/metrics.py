"""Reviewer metrics (``GET /admin/metrics``; factory §14) and their outbox-fed learning facts (Phase 15).

Learning metrics come from per-learner facts kept by the ``metrics`` subscriber of ``session.finished``: it
recomputes the finishing learner's facts from the authoritative tables in the subscriber's transaction, so a
redelivered event, a late one or a backfill (:func:`refresh_all`) always converges on the current truth. The
endpoint aggregates the facts, excluding synthetic, bot and deleted users (backend §15, §10). Factory metrics are
read from runs and blind responses. The Raqeeb benchmark is ``null`` until a benchmark run is stored (Phase 16).

Definitions (factory §14):
* ``pre_post`` per unit: learners with both a pretest and a first post-test (the first unit test after every
  lesson was completed); averages rounded half up, ``delta`` = post - pre.
* ``misconceptions``: ever activated and resolved; ``resolution_rate_percent`` null when nothing was activated.
* ``completion``: units started vs completed or skipped.
* ``avg_generation_minutes``: run created → first Gate 2 arrival, excluding the time the plan waited at Gate 1;
  ``avg_review_minutes``: first Gate 2 view → decision (§13.6 timestamps). Null until measured.
* Blind test: ``handwritten_identified_percent`` = correct guesses / responses; ``generated_preferred_or_same_percent``
  = responses where the generated lesson was clearer or ``same``.
"""

from __future__ import annotations

from datetime import datetime
from decimal import ROUND_HALF_UP, Decimal
from typing import Any

from sqlalchemy import delete, func, select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.contract import models as C
from app.models import (
    BlindPair,
    BlindResponse,
    FactoryRun,
    LearnerMisconception,
    LearnerUnit,
    MetricLearnerFact,
    MetricUnitFact,
    OutboxEvent,
    Unit,
    User,
)
from app.services.learning import finish_events
from app.services.platform.auth_sessions import utcnow


def half_up(value: Decimal | float) -> int:
    return int(Decimal(str(value)).quantize(Decimal(1), rounding=ROUND_HALF_UP))


# ------------------------------------------------------------------------------------------- facts (outbox effect)

async def refresh_learner(db: AsyncSession, user_id: str) -> None:
    """Recompute one learner's facts from ``learner_units`` and ``learner_misconceptions`` (idempotent)."""
    now = utcnow()
    units = (await db.execute(select(LearnerUnit).where(LearnerUnit.user_id == user_id))).scalars().all()
    await db.execute(delete(MetricUnitFact).where(MetricUnitFact.user_id == user_id))
    for row in units:
        started = row.started_at is not None or row.pretest_taken_at is not None
        completed = row.completed_at is not None or row.skipped_at is not None
        db.add(MetricUnitFact(user_id=user_id, unit_id=row.unit_id, started=started or completed,
                              completed=completed, pretest_percent=row.pretest_percent,
                              first_post_percent=row.first_post_percent, refreshed_at=now))
    activated = await db.scalar(select(func.count()).select_from(LearnerMisconception).where(
        LearnerMisconception.user_id == user_id, LearnerMisconception.activated_at.is_not(None)))
    resolved = await db.scalar(select(func.count()).select_from(LearnerMisconception).where(
        LearnerMisconception.user_id == user_id, LearnerMisconception.resolved_at.is_not(None)))
    await db.execute(insert(MetricLearnerFact).values(
        user_id=user_id, misconceptions_activated=int(activated or 0), misconceptions_resolved=int(resolved or 0),
        refreshed_at=now).on_conflict_do_update(index_elements=[MetricLearnerFact.user_id], set_={
            "misconceptions_activated": int(activated or 0), "misconceptions_resolved": int(resolved or 0),
            "refreshed_at": now}))
    await db.flush()


@finish_events.subscriber("metrics")
async def on_session_finished(db: AsyncSession, event: OutboxEvent) -> None:
    user = await db.get(User, event.payload["user_id"])
    if user is None or user.deleted_at is not None or user.is_synthetic or user.is_bot or user.role != "learner":
        return
    await refresh_learner(db, user.id)


async def refresh_all(db: AsyncSession) -> int:
    """Backfill: recompute every eligible learner's facts (e.g. after deploying this subscriber, D-77)."""
    ids = (await db.execute(select(User.id).where(User.role == "learner", User.deleted_at.is_(None),
                                                  User.is_synthetic.is_(False), User.is_bot.is_(False)))).scalars()
    count = 0
    for user_id in ids:
        await refresh_learner(db, user_id)
        count += 1
    return count


# ------------------------------------------------------------------------------------------- aggregates

def _eligible() -> Any:
    return select(User.id).where(User.role == "learner", User.deleted_at.is_(None), User.is_synthetic.is_(False),
                                 User.is_bot.is_(False))


def _title(unit: Unit, lang: str) -> str:
    by_track = unit.title.get(lang) or unit.title.get("en") or {}
    return str(by_track.get("explorer") or next(iter(by_track.values()), unit.id))


async def learning(db: AsyncSession, lang: str) -> dict[str, Any]:
    eligible = _eligible()
    units = {u.id: u for u in (await db.execute(select(Unit).order_by(Unit.index))).scalars()}
    rows = (await db.execute(select(
        MetricUnitFact.unit_id, func.count(), func.avg(MetricUnitFact.pretest_percent),
        func.avg(MetricUnitFact.first_post_percent)).where(
        MetricUnitFact.user_id.in_(eligible), MetricUnitFact.pretest_percent.is_not(None),
        MetricUnitFact.first_post_percent.is_not(None)).group_by(MetricUnitFact.unit_id))).all()
    pre_post = []
    for unit_id, participants, pre, post in sorted(rows, key=lambda r: units[r[0]].index):
        pre_avg, post_avg = half_up(pre), half_up(post)
        pre_post.append({"unit_id": unit_id, "unit_title": _title(units[unit_id], lang),
                         "participants": int(participants), "pre_avg_percent": pre_avg,
                         "post_avg_percent": post_avg, "delta": post_avg - pre_avg})
    activated, resolved = (await db.execute(select(
        func.coalesce(func.sum(MetricLearnerFact.misconceptions_activated), 0),
        func.coalesce(func.sum(MetricLearnerFact.misconceptions_resolved), 0)).where(
        MetricLearnerFact.user_id.in_(eligible)))).one()
    started, completed = (await db.execute(select(
        func.count().filter(MetricUnitFact.started), func.count().filter(MetricUnitFact.completed)).where(
        MetricUnitFact.user_id.in_(eligible)))).one()
    return {"pre_post": pre_post,
            "misconceptions": {"activated": int(activated), "resolved": int(resolved),
                               "resolution_rate_percent": half_up(Decimal(int(resolved)) * 100 / int(activated))
                               if activated else None},
            "completion": {"units_started": int(started), "units_completed": int(completed)}}


def _event_time(run: FactoryRun, stage: str) -> datetime | None:
    """When ``stage`` first finished (``done`` event) — plan → Gate 1, qa → Gate 2."""
    for event in run.attempts:
        if event.get("stage") == stage and event.get("event") == "done":
            return datetime.fromisoformat(event["at"])
    return None


def generation_minutes(run: FactoryRun) -> float | None:
    reached = _event_time(run, "qa")
    if reached is None:
        return None
    total = (reached - run.created_at).total_seconds()
    entered = _event_time(run, "plan")
    decided = (run.gate1_decision or {}).get("decided_at")
    if entered is not None and decided is not None:
        total -= max(0.0, (datetime.fromisoformat(decided) - entered).total_seconds())
    return max(0.0, total) / 60


async def factory(db: AsyncSession) -> dict[str, Any]:
    runs = (await db.execute(select(FactoryRun))).scalars().all()
    published = sum(1 for r in runs if r.status == "published")
    generation = [m for m in (generation_minutes(r) for r in runs) if m is not None]
    review = [(r.review_finished_at - r.review_started_at).total_seconds() / 60 for r in runs
              if r.review_started_at is not None and r.review_finished_at is not None]
    answered = (await db.execute(select(BlindResponse, BlindPair).join(
        BlindPair, BlindPair.id == BlindResponse.pair_id))).all()
    identified = sum(1 for response, pair in answered if response.guessed_handwritten == pair.gold_side)
    generated_side = {"a": "b", "b": "a"}
    preferred = sum(1 for response, pair in answered
                    if response.clearer in ("same", generated_side[pair.gold_side]))
    total = len(answered)
    return {"lessons_published": published,
            "avg_generation_minutes": half_up(sum(generation) / len(generation)) if generation else None,
            "avg_review_minutes": half_up(sum(review) / len(review)) if review else None,
            "blind_test": {"responses": total,
                           "handwritten_identified_percent": half_up(Decimal(identified * 100) / total)
                           if total else None,
                           "generated_preferred_or_same_percent": half_up(Decimal(preferred * 100) / total)
                           if total else None}}


async def metrics(db: AsyncSession, lang: str) -> dict[str, Any]:
    value = {"learning": await learning(db, lang), "raqeeb_benchmark": None, "factory": await factory(db)}
    projected: dict[str, Any] = C.Metrics.model_validate(value).model_dump(mode="json")
    return projected
