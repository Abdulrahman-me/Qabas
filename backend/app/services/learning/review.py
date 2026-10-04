"""Review selection (backend §7.4) over the learner's practiced concepts.

Exercises come only from the current published versions of lessons in the learner's journey (open units of
the learner's track, decision D-46), with purpose ``lesson``.

* **Cards** (``mode: cards``): one flashcard per concept, up to 12. Due concepts first (concepts with an active
  misconception first, then by ``due_at``, then lowest mastery), then the other practiced concepts by lowest
  mastery. Fewer than 8 is a valid smaller deck; none -> ``409 nothing_to_review``.
* **Quick** (``mode: quick``): concepts with ``due_at <= now`` by ``due_at`` then lowest mastery; when fewer than 3
  are due, the other practiced concepts follow by lowest mastery. Up to 10 timed exercises from those concepts,
  excluding recitation, flashcards, ``map_place`` on built-in visuals and ``categorize`` with ``day_arc``;
  exercises aimed at an active misconception first, then ones not answered in the last 24 h.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.content import catalog
from app.content.catalog import PoolItem
from app.models import LearnerConcept, LearnerMisconception, LearningSession, Misconception, SessionAnswer
from app.services.learning.journey import JourneyView

CARD_DECK_MAX = 12
QUICK_MAX = 10
QUICK_MIN_DUE = 3
QUICK_EXCLUDED_TYPES = ("recite_verse", "flashcard", "true_false")
RECENT = timedelta(hours=24)


@dataclass(frozen=True)
class Practiced:
    concept_id: str
    mastery: float
    due_at: datetime | None


async def _practiced(db: AsyncSession, user_id: str) -> list[Practiced]:
    rows = await db.execute(select(LearnerConcept).where(
        LearnerConcept.user_id == user_id, LearnerConcept.first_practiced_at.is_not(None)))
    return [Practiced(r.concept_id, float(r.mastery), r.due_at) for r in rows.scalars()]


async def _active_misconceptions(db: AsyncSession, user_id: str) -> dict[str, str | None]:
    """misconception_id -> its concept, for the learner's active misconceptions."""
    rows = await db.execute(select(Misconception.id, Misconception.concept_id)
                            .join(LearnerMisconception, LearnerMisconception.misconception_id == Misconception.id)
                            .where(LearnerMisconception.user_id == user_id, LearnerMisconception.status == "active"))
    return {misconception_id: concept_id for misconception_id, concept_id in rows}


def _journey_units(view: JourneyView) -> list[str]:
    return [u.id for u in view.units if not u.coming_soon]


async def select_cards(db: AsyncSession, view: JourneyView, now: datetime) -> list[PoolItem]:
    practiced = await _practiced(db, view.user.id)
    if not practiced:
        return []
    flagged = {c for c in (await _active_misconceptions(db, view.user.id)).values() if c}
    due = sorted((p for p in practiced if p.due_at is not None and p.due_at <= now),
                 key=lambda p: (p.concept_id not in flagged, p.due_at, p.mastery, p.concept_id))
    due_ids = {p.concept_id for p in due}
    rest = sorted((p for p in practiced if p.concept_id not in due_ids), key=lambda p: (p.mastery, p.concept_id))
    cards = [i for i in await catalog.pool(db, _journey_units(view), ("lesson",)) if i.type == "flashcard"]
    deck: list[PoolItem] = []
    for concept in due + rest:
        card = next((c for c in cards if concept.concept_id in c.concept_ids and c not in deck), None)
        if card is not None:
            deck.append(card)
        if len(deck) == CARD_DECK_MAX:
            break
    return deck


async def select_quick(db: AsyncSession, view: JourneyView, now: datetime, lang: str) -> list[PoolItem]:
    practiced = await _practiced(db, view.user.id)
    due = sorted((p for p in practiced if p.due_at is not None and p.due_at <= now),
                 key=lambda p: (p.due_at, p.mastery, p.concept_id))
    chosen = list(due)
    if len(due) < QUICK_MIN_DUE:
        due_ids = {p.concept_id for p in due}
        chosen += sorted((p for p in practiced if p.concept_id not in due_ids), key=lambda p: (p.mastery, p.concept_id))
    rank = {p.concept_id: i for i, p in enumerate(chosen)}
    if not rank:
        return []
    candidates = [i for i in await catalog.pool(db, _journey_units(view), ("lesson",))
                  if i.type not in QUICK_EXCLUDED_TYPES and rank.keys() & set(i.concept_ids)]
    versions = await catalog.exercise_versions(db, [(i.exercise_id, i.version) for i in candidates])
    active = set(await _active_misconceptions(db, view.user.id))
    recent = set((await db.execute(
        select(SessionAnswer.exercise_id).join(LearningSession, LearningSession.id == SessionAnswer.session_id)
        .where(LearningSession.user_id == view.user.id, SessionAnswer.recorded_at > now - RECENT))).scalars())

    def suited(item: PoolItem) -> bool:
        payload = versions[(item.exercise_id, item.version)].content["languages"][lang]["exercise"]["payload"]
        if item.type == "map_place" and payload["visual"]["kind"] == "builtin":
            return False
        return not (item.type == "categorize" and payload["presentation"] == "day_arc")

    def targets_active(item: PoolItem) -> bool:
        version = versions[(item.exercise_id, item.version)]
        mapped = set(version.option_misconceptions.values()) | {version.targets_misconception_id}
        return bool(mapped & active)

    ordered = sorted((i for i in candidates if suited(i)),
                     key=lambda i: (not targets_active(i), i.exercise_id in recent,
                                    min(rank[c] for c in i.concept_ids if c in rank), i.exercise_id))
    return ordered[:QUICK_MAX]
