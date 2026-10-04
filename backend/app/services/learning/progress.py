"""Atomic local-day activity and deterministic daily quests (backend §10.2, §10.5-10.6)."""

import hashlib
from datetime import UTC, date, datetime, time, timedelta
from typing import Any
from zoneinfo import ZoneInfo

from sqlalchemy import func, select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.contract import models as C
from app.models import DailyActivity, Quest, User, XpEvent
from app.services.learning import xp

POOL = ("earn_xp", "complete_lessons", "perfect_lesson", "complete_review", "win_challenge", "recite_verse")
TITLES = {
    "earn_xp": {"ar": "اجمع {goal} جمرة", "en": "Earn {goal} XP"},
    "complete_lessons": {"ar": "أكمل {goal} دروس", "en": "Complete {goal} lessons"},
    "perfect_lesson": {"ar": "أنهِ درساً دون أخطاء", "en": "Finish a lesson without mistakes"},
    "complete_review": {"ar": "أكمل مراجعة", "en": "Complete a review"},
    "win_challenge": {"ar": "فُز بتحدٍ", "en": "Win a challenge"},
    "recite_verse": {"ar": "تدرّب على تلاوة آية", "en": "Recite a verse"},
}


# Goals of one and two read naturally rather than as numerals (API §6.2 example: «أكمل درسين»).
COUNTED = {("complete_lessons", 1): {"ar": "أكمل درساً", "en": "Complete a lesson"},
           ("complete_lessons", 2): {"ar": "أكمل درسين", "en": "Complete 2 lessons"}}


def quest_title(kind: str, goal: int, lang: str) -> str:
    """Localized quest title (backend §10.6 templates), agreeing with its number in Arabic and English."""
    counted = COUNTED.get((kind, goal))
    return counted[lang] if counted else TITLES[kind][lang].format(goal=goal)


async def quests(db: AsyncSession, user: User, day: date) -> list[Quest]:
    chosen = sorted(POOL, key=lambda k: hashlib.sha256(f"{user.id}:{day}:{k}".encode()).digest())[:3]
    for slot, kind in enumerate(chosen, 1):
        goal = user.daily_goal_minutes * 3 if kind == "earn_xp" else (
            2 if kind == "complete_lessons" and user.daily_goal_minutes >= 15 else 1)
        await db.execute(insert(Quest).values(user_id=user.id, local_date=day, slot=slot, kind=kind, goal=goal,
                                             reward_xp=15 if kind in ("perfect_lesson", "win_challenge") else 10)
                         .on_conflict_do_nothing())
    return list((await db.execute(select(Quest).where(Quest.user_id == user.id, Quest.local_date == day)
                                  .order_by(Quest.slot).with_for_update())).scalars())


async def day_row(db: AsyncSession, user: User, day: date) -> DailyActivity:
    await db.execute(insert(DailyActivity).values(user_id=user.id, local_date=day).on_conflict_do_nothing())
    return (await db.execute(select(DailyActivity).where(DailyActivity.user_id == user.id,
                            DailyActivity.local_date == day).with_for_update())).scalar_one()


async def refresh_xp(db: AsyncSession, user: User, day: date, row: DailyActivity) -> None:
    row.xp = int(await db.scalar(select(func.coalesce(func.sum(XpEvent.xp), 0)).where(
        XpEvent.user_id == user.id, XpEvent.local_date == day)) or 0)


async def advance_quests(db: AsyncSession, user: User, now: datetime, events: dict[str, int]) -> list[dict[str, Any]]:
    """Activity counters receive only newly rewarded work. Reward XP may complete earn_xp, never itself twice."""
    day = xp.local_date(now, user.timezone)
    rows = await quests(db, user, day)
    grants = []
    for _ in range(len(rows) + 1):
        newly_done = False
        for row in rows:
            if row.completed_at is not None:
                continue
            if row.kind == "earn_xp":
                row.progress = int(await db.scalar(select(func.coalesce(func.sum(XpEvent.xp), 0)).where(
                    XpEvent.user_id == user.id, XpEvent.local_date == day)) or 0)
            else:
                row.progress += events.get(row.kind, 0)
            if row.progress >= row.goal:
                row.completed_at = now
                if await xp.grant(db, user, "quest_complete", row.reward_xp, "quest", str(row.id), now):
                    grants.append({"reason": "quest_complete", "xp": row.reward_xp})
                newly_done = True
        events = {}  # never apply a completion event again during the earn_xp cascade
        if not newly_done:
            break
    return grants


async def streak(db: AsyncSession, user: User, today: date) -> C.Streak:
    days = list((await db.execute(select(DailyActivity.local_date).where(
        DailyActivity.user_id == user.id, DailyActivity.qualifying.is_(True)).order_by(DailyActivity.local_date)))
                .scalars())
    longest = run = 0
    previous = None
    for day in days:
        run = run + 1 if previous is not None and day == previous + timedelta(days=1) else 1
        longest = max(longest, run)
        previous = day
    known = set(days)
    cursor = today if today in known else today - timedelta(days=1)
    current = 0
    while cursor in known:
        current += 1
        cursor -= timedelta(days=1)
    return C.Streak(current=current, longest=longest, today_completed=today in known)


async def quest_response(db: AsyncSession, user: User, lang: str, now: datetime) -> C.Quests:
    day = xp.local_date(now, user.timezone)
    rows = await quests(db, user, day)
    midnight = datetime.combine(day + timedelta(days=1), time(), ZoneInfo(user.timezone))
    resets = max(0, int((midnight.astimezone(UTC) - now).total_seconds()))
    return C.Quests(date=day.isoformat(), resets_in_seconds=resets,
                    items=[C.Quest(quest_id=f"q_{day:%Y%m%d}_{r.slot}", kind=r.kind,
                                   title=quest_title(r.kind, r.goal, lang), progress=r.progress,
                                   goal=r.goal, reward_xp=r.reward_xp, completed=r.completed_at is not None)
                           for r in rows])
