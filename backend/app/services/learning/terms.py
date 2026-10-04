"""Term cards for sessions, the lesson reader and unit guides (backend §6.2, §7.5-7.6).

A card is the contract's single ``project_term`` projection of the canonical glossary record, with the
learner's term ``state`` (``new`` until the learner has seen it) and level (``basic`` until the learner has a
completed/skipped unit or 8 mastered concepts). ``arabic``, ``text`` and ``transliteration`` stay independent.
"""

from __future__ import annotations

from decimal import Decimal
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.content import catalog
from app.content.projection import select_variant, term_card, term_ids
from app.contract import models as C
from app.errors import ApiError, ErrorCode
from app.models import LearnerConcept, LearnerTerm, LearnerUnit, Term, User
from app.services.learning import profile

MASTERED = Decimal("0.8")
INTERMEDIATE_AFTER_MASTERED = 8


async def learner_level(db: AsyncSession, user_id: str) -> str:
    units_done = await db.scalar(select(func.count()).select_from(LearnerUnit).where(
        LearnerUnit.user_id == user_id, LearnerUnit.unit_test_passed_at.is_not(None)))
    mastered = await db.scalar(select(func.count()).select_from(LearnerConcept).where(
        LearnerConcept.user_id == user_id, LearnerConcept.mastery >= MASTERED))
    return "basic" if not units_done and (mastered or 0) < INTERMEDIATE_AFTER_MASTERED else "intermediate"


def stored_term(row: Term) -> C.StoredGlossaryTerm:
    return C.StoredGlossaryTerm(
        term_id=row.id, text=row.text, arabic=row.arabic, transliteration=row.transliteration,
        definition=row.definition, example=row.example, concept_id=row.concept_id,
        lesson_id=row.lesson_id, source_id=row.source_id, pronunciation_audio_url=row.pronunciation_audio_url)


async def cards_for(db: AsyncSession, user: User, track: str, lang: str, *nodes: Any) -> dict[str, dict[str, Any]]:
    """TermCards for every ``term`` span in ``nodes``, keyed by term id, in order of first appearance."""
    ids: list[str] = []
    for node in nodes:
        ids += [t for t in term_ids(node) if t not in ids]
    if not ids:
        return {}
    rows = await catalog.terms(db, ids)
    missing = [t for t in ids if t not in rows]
    if missing:
        raise RuntimeError(f"term spans without a published glossary record: {missing}")
    states = {t.term_id: t.state for t in (await db.execute(select(LearnerTerm).where(
        LearnerTerm.user_id == user.id, LearnerTerm.term_id.in_(ids)))).scalars()}
    level = await learner_level(db, user.id)
    lesson_ids = sorted({r.lesson_id for r in rows.values() if r.lesson_id})
    titles = {lsn.lesson_id: lsn.title(lang, select_variant(set(lsn.variants), track))
              for lsn in await catalog.published_lessons(db) if lsn.lesson_id in lesson_ids}
    return {t: term_card(stored_term(rows[t]), lang, state=states.get(t, "new"), level=level,
                         lesson_title=titles.get(rows[t].lesson_id or "")) for t in ids}


async def get_card(db: AsyncSession, user: User, term_id: str, lang: str) -> C.TermCard:
    if await db.get(Term, term_id) is None:
        raise ApiError(ErrorCode.not_found, "Term was not found.")
    cards = await cards_for(db, user, user.track, lang, [{"type": "term", "term_id": term_id, "text": ""}])
    return C.TermCard.model_validate(cards[term_id])


async def page(db: AsyncSession, user: User, lang: str, state: str, cursor: str | None, limit: int) -> Any:
    profile.page_args(cursor, limit, "term_")
    if state not in ("all", "new", "learning", "mastered"):
        raise profile.invalid("state")
    # Personal glossary contains only encountered terms; explicit new is a valid empty filter.
    query = select(LearnerTerm.term_id).where(LearnerTerm.user_id == user.id, LearnerTerm.state != "new")
    if state != "all":
        query = query.where(LearnerTerm.state == state)
    if cursor:
        query = query.where(LearnerTerm.term_id > cursor)
    ids = list((await db.execute(query.order_by(LearnerTerm.term_id).limit(limit + 1))).scalars())
    cards = await cards_for(db, user, user.track, lang,
                           [{"type": "term", "term_id": tid, "text": ""} for tid in ids[:limit]])
    return C.EXPORTED["GlossaryPage"].model_validate({"items": list(cards.values()),
                                                    "next_cursor": ids[limit - 1] if len(ids) > limit else None})


async def opened(db: AsyncSession, user: User, term_id: str) -> None:
    async with db.begin():
        if await db.get(Term, term_id) is None:
            raise ApiError(ErrorCode.not_found, "Term was not found.")
        await db.execute(insert(LearnerTerm).values(user_id=user.id, term_id=term_id).on_conflict_do_nothing())
        row = (await db.execute(select(LearnerTerm).where(LearnerTerm.user_id == user.id,
                                LearnerTerm.term_id == term_id).with_for_update())).scalar_one()
        row.opened_count += 1
        if row.state == "new":
            row.state = "learning"
