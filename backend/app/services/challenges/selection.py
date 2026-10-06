"""Challenge question selection (backend §11.1): 7 (duel) or 3 (group) questions, no repeats.

Pool: duel-purpose exercises pinned by the *current published* lesson versions, whose pinned version is
``duel_eligible`` and of a closed type (``multiple_choice``, ``true_false``, ``verse_meaning``). Questions are taken
tier by tier until enough are chosen:

1. exercises whose concepts all have mastery >= 0.5 for **every** human player;
2. then exercises whose concepts are all covered by tier 1 or by lessons **every** human player completed;
3. then the duel pool of the first unit shared by both tracks (Unit 1), so mixed-track challenges stay possible.

A bot is not a player for selection (the human's concepts only). Within a tier the order is a shuffle seeded by the
duel id, so a selection is reproducible. The chosen exercise versions are pinned in ``duel_questions``.
"""

from __future__ import annotations

import random
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.content import catalog
from app.content.catalog import PoolItem
from app.db.enums import DUEL_TYPES
from app.errors import ApiError, ErrorCode
from app.models import LearnerConcept, LearnerLesson, Unit

MASTERY = Decimal("0.5")


def not_enough_questions(needed: int, available: int) -> ApiError:
    return ApiError(ErrorCode.duel_not_joinable, "There are not enough challenge questions yet.",
                    {"reason": "not_enough_questions", "needed": needed, "available": available})


async def _mastered(db: AsyncSession, user_id: str) -> set[str]:
    return set((await db.execute(select(LearnerConcept.concept_id).where(
        LearnerConcept.user_id == user_id, LearnerConcept.mastery >= MASTERY))).scalars())


async def _completed_concepts(db: AsyncSession, user_id: str,
                              lessons: dict[str, catalog.PublishedLesson]) -> set[str]:
    done = (await db.execute(select(LearnerLesson.lesson_id).where(
        LearnerLesson.user_id == user_id, LearnerLesson.completed_at.is_not(None)))).scalars()
    return {c for lesson_id in done if lesson_id in lessons for c in lessons[lesson_id].introduced_concept_ids}


def _common(sets: list[set[str]]) -> set[str]:
    return set.intersection(*sets) if sets else set()


async def eligible_pool(db: AsyncSession) -> tuple[list[PoolItem], set[str]]:
    """Every challenge-eligible exercise, and the ids of those in the first unit shared by both tracks."""
    units = list((await db.execute(select(Unit).order_by(Unit.index))).scalars())
    items = await catalog.pool(db, [u.id for u in units], ("duel",))
    versions = await catalog.exercise_versions(db, [(i.exercise_id, i.version) for i in items])
    usable = [i for i in items if i.type in DUEL_TYPES and i.concept_ids
              and (v := versions.get((i.exercise_id, i.version))) is not None and v.duel_eligible]
    shared = next((u for u in units if {"explorer", "new_muslim"} <= set(u.tracks)), None)
    unit_one = set()
    if shared is not None:
        unit_one = {i.exercise_id for i in await catalog.pool(db, [shared.id], ("duel",))}
    return usable, unit_one


async def choose(db: AsyncSession, human_ids: list[str], count: int, seed: str) -> list[PoolItem]:
    usable, unit_one = await eligible_pool(db)
    lessons = {lsn.lesson_id: lsn for lsn in await catalog.published_lessons(db)}
    mastered = _common([await _mastered(db, uid) for uid in human_ids])
    completed = _common([await _completed_concepts(db, uid, lessons) for uid in human_ids])
    tiers = [
        [i for i in usable if set(i.concept_ids) <= mastered],
        [i for i in usable if set(i.concept_ids) <= mastered | completed],
        [i for i in usable if i.exercise_id in unit_one],
    ]
    rng = random.Random(seed)  # noqa: S311 (reproducible order, not secrecy)
    chosen: list[PoolItem] = []
    taken: set[str] = set()
    for tier in tiers:
        candidates = [i for i in tier if i.exercise_id not in taken]
        rng.shuffle(candidates)
        for item in candidates[:count - len(chosen)]:
            chosen.append(item)
            taken.add(item.exercise_id)
        if len(chosen) == count:
            return chosen
    raise not_enough_questions(count, len(chosen))
