"""Per-answer adaptation (backend §7.1-7.2), applied in the answer's transaction.

**Lock order** (backend "Transactions and effects"): the session row, then the learner's concept rows in
ascending ``concept_id``, then misconception rows in ascending ``misconception_id`` (decision D-56; terms are not
touched per answer). Finish (Phase 7) takes the same order, so concurrent answers and finish cannot deadlock.
Missing rows are created with ``ON CONFLICT DO NOTHING`` before locking, so two devices answering for the first
time can't collide.

**Mastery:** the contract's six-decimal ``update_mastery``; responses report half-up two decimals.

**Misconceptions** (§7.2; retries and neutral outcomes never touch them):
* evidence: choosing an option mapped to a misconception +1.0; answering incorrectly an exercise that targets
  one +0.5; one answer adds the larger of the two per misconception (decision D-57);
* activation at evidence >= 1.0: ``active``, streak 0, the card is returned; a resolved misconception that
  gathers new evidence becomes active again;
* already active and a mapped option chosen again: the card is returned again and the streak resets;
* resolution: a correct answer on an exercise that targets or maps the misconception adds one to the streak,
  an incorrect one resets it; at 3 the misconception is ``resolved``.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from decimal import Decimal
from typing import Any

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import LearnerConcept, LearnerMisconception

MAPPED_EVIDENCE = Decimal("1.0")
TARGETED_EVIDENCE = Decimal("0.5")
ACTIVATION = Decimal("1.0")
RESOLVED_STREAK = 3


async def lock_concepts(db: AsyncSession, user_id: str, concept_ids: list[str]) -> dict[str, LearnerConcept]:
    ordered = sorted(set(concept_ids))
    if not ordered:
        return {}
    await db.execute(pg_insert(LearnerConcept).values([{"user_id": user_id, "concept_id": c} for c in ordered])
                     .on_conflict_do_nothing(index_elements=["user_id", "concept_id"]))
    rows = await db.execute(select(LearnerConcept).where(LearnerConcept.user_id == user_id,
                                                          LearnerConcept.concept_id.in_(ordered))
                            .order_by(LearnerConcept.concept_id).with_for_update())
    return {r.concept_id: r for r in rows.scalars()}


async def lock_misconceptions(db: AsyncSession, user_id: str, misconception_ids: list[str],
                              create: set[str]) -> dict[str, LearnerMisconception]:
    """Lock the learner's rows for ``misconception_ids``; rows in ``create`` are made first when missing."""
    ordered = sorted(set(misconception_ids))
    if not ordered:
        return {}
    if create:
        await db.execute(pg_insert(LearnerMisconception)
                         .values([{"user_id": user_id, "misconception_id": m} for m in sorted(create)])
                         .on_conflict_do_nothing(index_elements=["user_id", "misconception_id"]))
    rows = await db.execute(select(LearnerMisconception).where(
        LearnerMisconception.user_id == user_id, LearnerMisconception.misconception_id.in_(ordered))
        .order_by(LearnerMisconception.misconception_id).with_for_update())
    return {r.misconception_id: r for r in rows.scalars()}


@dataclass
class MisconceptionPlan:
    """What one answer means for the misconceptions its exercise is about."""

    evidence: dict[str, Decimal] = field(default_factory=dict)   # misconception_id -> evidence to add
    chosen: str | None = None                                    # mapped misconception of the chosen option
    related: set[str] = field(default_factory=set)               # targeted or mapped by the exercise


def plan_misconceptions(answer: Any, correct: bool | None, is_retry: bool, option_misconceptions: dict[str, str],
                        targets: str | None) -> MisconceptionPlan:
    plan = MisconceptionPlan(related=set(option_misconceptions.values()) | ({targets} if targets else set()))
    if is_retry or correct is None:
        return MisconceptionPlan()
    chosen_ids = [v for k, v in (answer or {}).items() if k.endswith("_id") and isinstance(v, str)]
    plan.chosen = next((option_misconceptions[i] for i in chosen_ids if i in option_misconceptions), None)
    if plan.chosen is not None:
        plan.evidence[plan.chosen] = MAPPED_EVIDENCE
    if targets is not None and correct is False:
        plan.evidence[targets] = max(plan.evidence.get(targets, Decimal(0)), TARGETED_EVIDENCE)
    return plan


def apply_misconceptions(plan: MisconceptionPlan, rows: dict[str, LearnerMisconception], correct: bool | None,
                         now: datetime) -> str | None:
    """Update the locked rows; return the misconception whose card the evaluation shows (or None)."""
    shown: list[str] = []
    for misconception_id in sorted(plan.related):
        row = rows.get(misconception_id)
        if row is None:
            continue
        gained = plan.evidence.get(misconception_id)
        if gained is not None:
            row.evidence_score = Decimal(row.evidence_score) + gained
            if row.status == "active":
                row.correct_streak = 0
                if misconception_id == plan.chosen:
                    shown.append(misconception_id)          # chosen again: show the card again
            elif row.evidence_score >= ACTIVATION:
                row.status, row.correct_streak, row.resolved_at = "active", 0, None
                row.activated_at = row.activated_at or now
                shown.append(misconception_id)
        elif row.status == "active" and correct is True:
            row.correct_streak += 1
            if row.correct_streak >= RESOLVED_STREAK:
                row.status, row.resolved_at = "resolved", now
        elif row.status == "active" and correct is False:
            row.correct_streak = 0
    if plan.chosen in shown:
        return plan.chosen
    return shown[0] if shown else None
