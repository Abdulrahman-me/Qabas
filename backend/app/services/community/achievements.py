"""Achievements (backend §10.7, API ``GET /me/achievements``).

Definitions are seeded configuration (``achievements``). Each counter is derived from authoritative tables, never
from event counts, so a redelivered or lost event, a backfill or a read always converges on the same truth (D-77).
``learner_achievements.progress`` is recomputed on the relevant events — the ``session.finished`` subscriber,
completed Raqeeb answers, and reads of ``GET /me/achievements`` — and ``unlocked_at`` is set once, when progress
first reaches the target, and never revoked.

Counters (anti-farming in brackets):
* ``raqeeb_questions``: user messages whose assistant reply reached ``completed`` [one per user message].
* ``lessons_completed`` / ``units_completed``: as ``/me/stats`` (completed lessons; unit tests passed).
* ``longest_streak``: the longest run of qualifying days (``daily_activity``).
* ``terms_mastered`` / ``misconceptions_resolved``: mastered terms; misconceptions ever resolved.
* ``recitations_passed``: distinct passages with a passed check [repeating a verse does not count twice].
* ``reviews_completed``: finished review sessions.
* ``perfect_lessons``: ``lesson_perfect`` grants [already one per lesson reward key].
* ``challenges_won``: finished *live* challenges against friends that the learner won outright (a rank-1 winner of
  a non-draw), from ``duels`` [the badge is "Win a live challenge with friends": bot duels, async forfeits and draws
  never count].
"""

from __future__ import annotations

from collections.abc import Awaitable, Callable
from datetime import date, datetime

from sqlalchemy import distinct, func, select, tuple_
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.contract import models as C
from app.models import (
    AchievementDefinition,
    Duel,
    DuelPlayer,
    LearnerAchievement,
    LearnerLesson,
    LearnerMisconception,
    LearnerTerm,
    LearnerUnit,
    LearningSession,
    OutboxEvent,
    RaqeebConversation,
    RaqeebMessage,
    RecitationCheckRecord,
    User,
    XpEvent,
)
from app.services.learning import finish_events, progress
from app.services.learning.locking import learner_lock
from app.services.platform.auth_sessions import utcnow
from app.services.users import iso

Counter = Callable[[AsyncSession, User], Awaitable[int]]


async def _count(db: AsyncSession, query: object) -> int:
    return int(await db.scalar(query) or 0)  # type: ignore[call-overload]


async def raqeeb_questions(db: AsyncSession, user: User) -> int:
    return await _count(db, select(func.count(distinct(RaqeebMessage.reply_to)))
                        .join(RaqeebConversation, RaqeebConversation.id == RaqeebMessage.conversation_id)
                        .where(RaqeebConversation.user_id == user.id, RaqeebMessage.role == "assistant",
                               RaqeebMessage.status == "completed"))


async def lessons_completed(db: AsyncSession, user: User) -> int:
    return await _count(db, select(func.count()).select_from(LearnerLesson).where(
        LearnerLesson.user_id == user.id, LearnerLesson.completed_at.is_not(None)))


async def units_completed(db: AsyncSession, user: User) -> int:
    return await _count(db, select(func.count()).select_from(LearnerUnit).where(
        LearnerUnit.user_id == user.id, LearnerUnit.unit_test_passed_at.is_not(None)))


async def longest_streak(db: AsyncSession, user: User) -> int:
    return int((await progress.streak(db, user, date.today())).longest)   # independent of today


async def terms_mastered(db: AsyncSession, user: User) -> int:
    return await _count(db, select(func.count()).select_from(LearnerTerm).where(
        LearnerTerm.user_id == user.id, LearnerTerm.state == "mastered"))


async def misconceptions_resolved(db: AsyncSession, user: User) -> int:
    return await _count(db, select(func.count()).select_from(LearnerMisconception).where(
        LearnerMisconception.user_id == user.id, LearnerMisconception.resolved_at.is_not(None)))


async def recitations_passed(db: AsyncSession, user: User) -> int:
    passage = tuple_(RecitationCheckRecord.surah, RecitationCheckRecord.ayah,
                     func.coalesce(RecitationCheckRecord.word_start, 0),
                     func.coalesce(RecitationCheckRecord.word_end, 0))
    return await _count(db, select(func.count(distinct(passage))).where(
        RecitationCheckRecord.user_id == user.id, RecitationCheckRecord.passed.is_(True)))


async def reviews_completed(db: AsyncSession, user: User) -> int:
    return await _count(db, select(func.count()).select_from(LearningSession).where(
        LearningSession.user_id == user.id, LearningSession.kind == "review", LearningSession.status == "finished"))


async def perfect_lessons(db: AsyncSession, user: User) -> int:
    return await _count(db, select(func.count()).select_from(XpEvent).where(
        XpEvent.user_id == user.id, XpEvent.reason == "lesson_perfect"))


async def challenges_won(db: AsyncSession, user: User) -> int:
    return await _count(db, select(func.count()).select_from(Duel).join(
        DuelPlayer, (DuelPlayer.duel_id == Duel.id) & (DuelPlayer.user_id == user.id)).where(
        Duel.status == "finished", Duel.mode == "live", Duel.opponent_type.in_(("friend", "friends")),
        Duel.result["is_draw"].as_boolean().is_(False), Duel.result["winner_user_ids"].contains([user.id])))


COUNTERS: dict[str, Counter] = {
    "raqeeb_questions": raqeeb_questions, "lessons_completed": lessons_completed,
    "units_completed": units_completed, "longest_streak": longest_streak, "terms_mastered": terms_mastered,
    "misconceptions_resolved": misconceptions_resolved, "challenges_won": challenges_won,
    "recitations_passed": recitations_passed, "reviews_completed": reviews_completed,
    "perfect_lessons": perfect_lessons,
}


def register_counter(name: str, counter: Counter) -> None:
    """Replace a counter with one over another phase's tables (the registry is closed to new names)."""
    if name not in COUNTERS:
        raise ValueError(f"unknown achievement counter {name}")
    COUNTERS[name] = counter


def tracked(user: User | None) -> bool:
    return (user is not None and user.role == "learner" and not user.is_bot and not user.is_synthetic
            and user.deleted_at is None)


async def definitions(db: AsyncSession) -> list[AchievementDefinition]:
    return list((await db.execute(select(AchievementDefinition).order_by(AchievementDefinition.position))).scalars())


async def refresh(db: AsyncSession, user: User, now: datetime | None = None) -> None:
    """Recompute the learner's progress from the authoritative tables (caller's transaction; idempotent).

    Serialized with the learner's reward writes (``learner_lock``), so a refresh never overwrites a newer
    progress with an older one; ``unlocked_at`` is kept once set."""
    if not tracked(user):
        return
    now = now or utcnow()
    await learner_lock(db, user.id)
    defs = await definitions(db)
    values = {name: await COUNTERS[name](db, user) for name in sorted({d.counter for d in defs})}
    for d in defs:
        value = values[d.counter]
        statement = insert(LearnerAchievement).values(
            user_id=user.id, achievement_key=d.achievement_key, progress=value,
            unlocked_at=now if value >= d.target else None, updated_at=now)
        await db.execute(statement.on_conflict_do_update(
            index_elements=[LearnerAchievement.user_id, LearnerAchievement.achievement_key],
            set_={"progress": statement.excluded.progress, "updated_at": now,
                  "unlocked_at": func.coalesce(LearnerAchievement.unlocked_at, statement.excluded.unlocked_at)}))
    await db.flush()


async def response(db: AsyncSession, user: User, lang: str) -> C.Achievements:
    await refresh(db, user)
    stored = {row.achievement_key: row for row in (await db.execute(
        select(LearnerAchievement).where(LearnerAchievement.user_id == user.id))).scalars()}
    items = []
    for d in await definitions(db):
        row = stored.get(d.achievement_key)
        unlocked_at = row.unlocked_at if row is not None else None
        current = d.target if unlocked_at is not None else min(row.progress if row else 0, d.target)
        items.append(C.Achievement(achievement_key=d.achievement_key, title=d.title[lang],
                                   description=d.description[lang], unlocked=unlocked_at is not None,
                                   unlocked_at=iso(unlocked_at) if unlocked_at else None,
                                   progress=C.AchievementProgress(current=current, target=d.target)))
    return C.Achievements(items=items)


async def refresh_for_event(db: AsyncSession, event: OutboxEvent) -> None:
    user = await db.get(User, event.payload["user_id"])
    if user is not None and tracked(user):
        await refresh(db, user)


# A finished session may advance any counter; the ``raqeeb.completed`` consumer calls the same refresh.
finish_events.subscriber("achievements")(refresh_for_event)


async def refresh_all(maker: async_sessionmaker[AsyncSession]) -> int:
    """Backfill every learner from the authoritative tables (after deploying Phase 18, D-77), one learner per
    transaction so no learner's lock is held longer than their own refresh."""
    async with maker() as db:
        ids = (await db.execute(select(User.id).where(User.role == "learner", User.deleted_at.is_(None),
                                                      User.is_synthetic.is_(False), User.is_bot.is_(False))
                                .order_by(User.id))).scalars().all()
    for user_id in ids:
        async with maker() as db, db.begin():
            user = await db.get(User, user_id)
            if user is not None:
                await refresh(db, user)
    return len(ids)
