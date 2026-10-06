"""The challenge results transaction (backend §11.2 "Finish", §10.1; API §6.10), shared by async play (Phase 19) and
the live coordinator (Phase 20).

Under the duel's row lock and exactly once (a finished duel is closed by a database trigger):

* **Ranking:** total points desc; ties broken by the lower total response time of correct answers; still tied →
  shared rank. A forfeiting player (async friend who did not finish within 24 h, or declined after the switch)
  ranks after everyone who did not forfeit. ``winner_user_ids`` = every rank-1 player; ``is_draw`` when all share
  rank 1.
* **XP** through the one ledger (:func:`xp.grant`, ref ``duel``/id, which also places learners in leagues): duel
  ``duel_win``/``duel_draw``/``duel_loss`` 15/8/4, group ``group_rank_1``/``group_rank_2``/``group_rank_other``
  15/8/4; every rank-1 player gets the rank-1 award; bots and forfeiters get none. At most
  :data:`REWARDED_PER_DAY` challenges per learner and local day earn challenge XP (anti-farming, recorded decision).
* **Day and quests** like a finished session: the day qualifies, play time counts toward the daily goal,
  ``win_challenge`` advances for winners of a non-draw.
* **Outbox** ``duel.finished`` → achievements (``challenges_won``) for every human player.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Duel, DuelAnswer, DuelPlayer, OutboxEvent, User, XpEvent
from app.services.learning import progress, xp
from app.services.learning.locking import learner_lock
from app.services.platform import outbox

KIND = "duel.finished"
CHALLENGE_REASONS = ("duel_win", "duel_draw", "duel_loss", "group_rank_1", "group_rank_2", "group_rank_other")
AWARDS = {"duel_win": 15, "duel_draw": 8, "duel_loss": 4, "group_rank_1": 15, "group_rank_2": 8,
          "group_rank_other": 4}
REWARDED_PER_DAY = 5
SESSION_CAP_MS = 20 * 60_000


@dataclass(frozen=True)
class Standing:
    user_id: str
    is_bot: bool
    forfeited: bool
    points: int
    correct: int
    correct_ms: int
    played_ms: int


def participants(players: list[DuelPlayer]) -> list[DuelPlayer]:
    """Players who take part in the result: joined (or left mid-game) players, and an async invitee who forfeits."""
    return [p for p in players if p.status in ("joined", "left") or p.forfeited]


def rank(standings: list[Standing]) -> dict[str, int]:
    def key(s: Standing) -> tuple[int, int, int]:
        return (int(s.forfeited), -s.points, s.correct_ms)

    ordered = sorted(standings, key=key)
    ranks: dict[str, int] = {}
    for position, s in enumerate(ordered, start=1):
        previous = ordered[position - 2] if position > 1 else None
        ranks[s.user_id] = ranks[previous.user_id] if previous is not None and key(previous) == key(s) else position
    return ranks


def reason_for(preset: str, rank_: int, is_draw: bool) -> str:
    if preset == "duel":
        return "duel_draw" if is_draw else ("duel_win" if rank_ == 1 else "duel_loss")
    return {1: "group_rank_1", 2: "group_rank_2"}.get(rank_, "group_rank_other")


async def standings(db: AsyncSession, duel: Duel, players: list[DuelPlayer]) -> list[Standing]:
    limit = int(duel.config["time_limit_ms"])
    rows = (await db.execute(select(DuelAnswer).where(DuelAnswer.duel_id == duel.id))).scalars().all()
    found = []
    for player in participants(players):
        mine = [r for r in rows if r.user_id == player.user_id]
        found.append(Standing(
            user_id=player.user_id, is_bot=player.is_bot, forfeited=player.forfeited,
            points=sum(r.points for r in mine), correct=sum(1 for r in mine if r.correct),
            correct_ms=sum(r.elapsed_ms for r in mine if r.correct),
            played_ms=sum(min(r.elapsed_ms, limit) for r in mine)))
    return found


async def _rewarded_today(db: AsyncSession, user: User, now: datetime) -> int:
    return int(await db.scalar(select(func.count()).select_from(XpEvent).where(
        XpEvent.user_id == user.id, XpEvent.local_date == xp.local_date(now, user.timezone),
        XpEvent.reason.in_(CHALLENGE_REASONS))) or 0)


async def _reward(db: AsyncSession, duel: Duel, user: User, standing: Standing, rank_: int, is_draw: bool,
                  won: bool, now: datetime) -> int:
    """Challenge XP, the day and quests for one human player (caller holds the learner lock)."""
    awarded = 0
    if not standing.forfeited and await _rewarded_today(db, user, now) < REWARDED_PER_DAY:
        reason = reason_for(duel.preset, rank_, is_draw)
        if await xp.grant(db, user, reason, AWARDS[reason], "duel", duel.id, now, reward_key=f"duel:{duel.id}"):
            awarded = AWARDS[reason]
    if standing.forfeited:
        return awarded
    day = xp.local_date(now, user.timezone)
    daily = await progress.day_row(db, user, day)
    daily.qualifying = True
    daily.duration_ms += min(standing.played_ms, SESSION_CAP_MS)
    daily.minutes = daily.duration_ms // 60_000
    if daily.minutes >= user.daily_goal_minutes:
        await xp.grant(db, user, "daily_goal_met", xp.AMOUNTS["daily_goal_met"], "local_date", day.isoformat(), now)
    await progress.advance_quests(db, user, now, {"win_challenge": 1} if won else {})
    await progress.refresh_xp(db, user, day, daily)
    return awarded


async def finish(db: AsyncSession, duel: Duel, now: datetime) -> bool:
    """Write the result once (caller's transaction, duel row locked by the caller). False if already closed."""
    if duel.status in ("finished", "expired", "declined"):
        return False
    players = list((await db.execute(select(DuelPlayer).where(DuelPlayer.duel_id == duel.id)
                                     .order_by(DuelPlayer.seat))).scalars())
    table = await standings(db, duel, players)
    ranks = rank(table)
    is_draw = len(table) > 1 and all(r == 1 for r in ranks.values())
    winners = [s.user_id for s in table if ranks[s.user_id] == 1]
    humans = sorted(s.user_id for s in table if not s.is_bot)
    for user_id in humans:                                   # one lock order for every results transaction
        await learner_lock(db, user_id)
    by_id = {p.user_id: p for p in players}
    for s in table:
        player = by_id[s.user_id]
        if s.is_bot:
            player.xp_awarded = 0
            continue
        user = await db.get(User, s.user_id)
        if user is None or user.deleted_at is not None:
            player.xp_awarded = 0
            continue
        player.xp_awarded = await _reward(db, duel, user, s, ranks[s.user_id], is_draw,
                                          s.user_id in winners and not is_draw, now)
    duel.result = {"winner_user_ids": winners, "is_draw": is_draw,
                   "scores": [{"user_id": s.user_id, "rank": ranks[s.user_id], "points": s.points,
                               "correct": s.correct} for s in sorted(table, key=lambda s: (ranks[s.user_id],
                                                                                          by_id[s.user_id].seat))]}
    duel.status, duel.finished_at = "finished", now
    if duel.mode == "live":
        duel.phase = "finished"
    await db.flush()
    await outbox.enqueue(db, event_key=f"duel:{duel.id}:finished", kind=KIND,
                         payload={"duel_id": duel.id, "user_ids": humans})
    return True


@outbox.consumer(KIND)
async def on_finished(db: AsyncSession, event: OutboxEvent) -> None:
    from app.services.community import achievements

    for user_id in event.payload["user_ids"]:
        user = await db.get(User, user_id)
        if user is not None and achievements.tracked(user):
            await achievements.refresh(db, user)


def result_for(duel: Duel, player: DuelPlayer | None) -> dict[str, Any] | None:
    """The contract ``DuelResult`` for one viewer (``xp_awarded`` is the viewer's own challenge XP)."""
    if duel.result is None:
        return None
    return {**duel.result, "xp_awarded": int(player.xp_awarded or 0) if player is not None else 0}
