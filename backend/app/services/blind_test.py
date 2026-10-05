"""Blind tests (factory §14; API §6.11 ``BlindPair``/``BlindAnswer``; Phase 15).

An operator pairs a published gold lesson with a published generated lesson (``scripts/create_blind_pair.py``);
the gold side is drawn at random and stored. A reviewer is shown, one pair at a time, the next pair they have not
answered (``204`` when none remain): each side is the stored, published lesson version as a preview in the
reviewer's language and the Explorer variant (title, objectives, items, completion), exercises in their learner
form, never which side is gold. An answer is recorded once per reviewer and pair (insert-only); repeating the same
answer is harmless, a different one is refused.
"""

from __future__ import annotations

import secrets
import uuid
from typing import Any

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.content.projection import resolve_items
from app.content.store import load_package
from app.contract import models as C
from app.db.ids import new_id
from app.errors import ApiError, ErrorCode
from app.models import BlindPair, BlindResponse, Lesson, LessonVersion


class BlindTestError(ValueError):
    pass


async def _published(db: AsyncSession, lesson_id: str) -> LessonVersion:
    lesson = await db.get(Lesson, lesson_id)
    if lesson is None or lesson.current_version is None:
        raise BlindTestError(f"{lesson_id} has no published version")
    version = (await db.execute(select(LessonVersion).where(
        LessonVersion.lesson_id == lesson_id, LessonVersion.version == lesson.current_version))).scalar_one()
    return version


async def create_pair(db: AsyncSession, *, gold: str, generated: str, side: str | None = None) -> BlindPair:
    """Pair the current published versions of a gold lesson and a generated lesson (caller commits)."""
    gold_version, generated_version = await _published(db, gold), await _published(db, generated)
    gold_lesson = await db.get(Lesson, gold)
    if gold_lesson is None or not gold_lesson.is_gold or gold_version.origin != "gold_import":
        raise BlindTestError(f"{gold} is not a published gold lesson")
    if generated_version.origin != "factory":
        raise BlindTestError(f"{generated} is not a published factory lesson")
    gold_side = side if side in ("a", "b") else secrets.choice(("a", "b"))
    a, b = (gold_version, generated_version) if gold_side == "a" else (generated_version, gold_version)
    pair = BlindPair(id=new_id("pair"), lesson_version_a=a.id, lesson_version_b=b.id, gold_side=gold_side)
    db.add(pair)
    await db.flush()
    return pair


async def _preview(db: AsyncSession, version_id: uuid.UUID, lang: str) -> dict[str, Any]:
    package = await load_package(db, version_id)
    variants = package.variants[lang]  # type: ignore[index]
    variant = "explorer" if "explorer" in variants else sorted(variants)[0]
    content = variants[variant]
    return {"title": content.title, "objectives": [[s.model_dump(mode="json") for s in o] for o in content.objectives],
            "items": resolve_items(package, lang, variant),
            "completion": content.completion.model_dump(mode="json") if content.completion else None}


async def next_pair(db: AsyncSession, *, reviewer_id: str, lang: str) -> dict[str, Any] | None:
    answered = select(BlindResponse.pair_id).where(BlindResponse.reviewer_id == reviewer_id)
    pair = (await db.execute(select(BlindPair).where(BlindPair.id.not_in(answered))
                             .order_by(BlindPair.created_at, BlindPair.id).limit(1))).scalar_one_or_none()
    if pair is None:
        return None
    value = {"pair_id": pair.id, "lesson_a": await _preview(db, pair.lesson_version_a, lang),
             "lesson_b": await _preview(db, pair.lesson_version_b, lang)}
    projected: dict[str, Any] = C.BlindPair.model_validate(value).model_dump(mode="json")
    return projected


async def answer(db: AsyncSession, *, reviewer_id: str, pair_id: str, body: C.BlindAnswer) -> None:
    if await db.get(BlindPair, pair_id) is None:
        raise ApiError(ErrorCode.not_found, "Blind-test pair was not found.")
    values = body.model_dump()
    await db.execute(insert(BlindResponse).values(pair_id=pair_id, reviewer_id=reviewer_id, **values)
                     .on_conflict_do_nothing())
    stored = await db.get(BlindResponse, (pair_id, reviewer_id))
    assert stored is not None
    if {k: getattr(stored, k) for k in values} != values:
        raise ApiError(ErrorCode.validation_error, "You already answered this pair differently.",
                       {"field": "pair_id"})
