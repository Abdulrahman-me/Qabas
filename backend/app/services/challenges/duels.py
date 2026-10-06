"""Challenge lifecycle over REST (API §6.10, backend §11.4).

States: ``pending`` (friend invitations) → ``ready`` (live; the Phase 20 coordinator moves it to ``in_progress``)
or ``declined``/``expired``; an async friend duel is ``in_progress`` until ``finished`` (or ``expired`` when an
account is deleted). Closed states never change again (database trigger QB007).

* Bot duels start ``ready``; friend challenges start ``pending`` with every invitee ``invited``.
* Duel preset: the friend's accept → ``ready``, decline → ``declined``; unanswered after 2 minutes → ``expired``.
* Group preset: starts when every invitee responded, or at the 60 s lobby deadline, if at least one friend
  joined (``bot_fill`` seats practice bots for the friends who did not join); otherwise ``expired``.
* A ``ready`` live challenge that the coordinator has not started by ``expires_at`` expires (Phase 20 owns starting).
* Async (duel preset, inviter only, after 60 s pending): ``mode = async``, ``in_progress``, open 24 h; the friend can
  still accept for 24 h; a decline then counts as a forfeit; at 24 h the duel closes with the forfeit rules.

Time-based transitions are applied by the sweep job and before any read or write of a duel (:func:`settle`), under
the duel's row lock, so polling clients and the beat job always agree.
"""

from __future__ import annotations

from datetime import datetime, timedelta
from typing import Any

from sqlalchemy import Select, and_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.contract import models as C
from app.db.ids import new_id
from app.errors import ApiError, ErrorCode
from app.models import Duel, DuelAnswer, DuelPlayer, DuelQuestion, User
from app.registries import deleted_learner_name
from app.services.challenges import bot, results, selection
from app.services.community.friends import are_friends, can_befriend
from app.services.learning.locking import learner_lock
from app.services.learning.profile import page_args
from app.services.platform.deletion import DELETED_DISPLAY_NAME
from app.services.users import iso

PRESETS: dict[str, dict[str, Any]] = {
    "duel": {"question_count": 7, "time_limit_ms": 15000,
             "scoring": {"base": 100, "speed_bonus": 100, "rounding": "floor"}, "reveal_ms": 3000},
    "group": {"question_count": 3, "time_limit_ms": 10000,
              "scoring": {"base": 100, "speed_bonus": 50, "rounding": "half_up"}, "reveal_ms": 2200},
}
LIVE_TTL = timedelta(minutes=2)          # duels expire after 2 minutes (API §6.10)
GROUP_LOBBY = timedelta(seconds=60)      # group challenges start or close after 60 s
ASYNC_AFTER = timedelta(seconds=60)      # "Play now; your friend plays later" after 60 s pending
ASYNC_TTL = timedelta(hours=24)
OPEN = ("pending", "ready", "in_progress")


def not_joinable(reason: str, message: str = "This challenge is no longer available.") -> ApiError:
    return ApiError(ErrorCode.duel_not_joinable, message, {"reason": reason})


def not_found() -> ApiError:
    return ApiError(ErrorCode.not_found, "Challenge not found.")


def invalid(message: str, reason: str) -> ApiError:
    return ApiError(ErrorCode.validation_error, message, {"field": "friend_user_ids", "reason": reason})


# ------------------------------------------------------------------------------------------- projection

async def players_of(db: AsyncSession, duel_id: str) -> list[DuelPlayer]:
    return list((await db.execute(select(DuelPlayer).where(DuelPlayer.duel_id == duel_id)
                                  .order_by(DuelPlayer.seat))).scalars())


def shown(duel: Duel, players: list[DuelPlayer]) -> list[DuelPlayer]:
    """A started group shows its participants (joined friends and seated bots); otherwise every seat."""
    if duel.preset == "group" and duel.status in ("ready", "in_progress", "finished"):
        return [p for p in players if p.status in ("joined", "left")]
    return players


def ws_url(base: str, duel_id: str) -> str:
    return f"{base}/v1/ws/duels/{duel_id}"


async def project(db: AsyncSession, duel: Duel, viewer: User, lang: str, ws_base: str) -> C.Duel:
    players = await players_of(db, duel.id)
    users = {u.id: u for u in (await db.execute(select(User).where(
        User.id.in_([p.user_id for p in players])))).scalars()}
    rows = []
    for p in shown(duel, players):
        user = users[p.user_id]
        if p.is_bot:
            name, avatar = bot.NAME[lang], bot.AVATAR
        elif user.deleted_at is not None and user.display_name == DELETED_DISPLAY_NAME:
            name, avatar = deleted_learner_name(lang), user.avatar_key
        else:
            name, avatar = user.display_name, user.avatar_key
        rows.append({"user_id": p.user_id, "display_name": name, "avatar_key": avatar, "is_me": p.user_id == viewer.id,
                     "is_bot": p.is_bot, "status": "joined" if p.status == "left" else p.status})
    mine = next((p for p in players if p.user_id == viewer.id), None)
    return C.Duel.model_validate({
        "duel_id": duel.id, "status": duel.status, "mode": duel.mode, "preset": duel.preset,
        "opponent_type": duel.opponent_type, "players": rows, "config": duel.config,
        "ws_url": ws_url(ws_base, duel.id), "created_at": iso(duel.created_at), "expires_at": iso(duel.expires_at),
        "result": results.result_for(duel, mine)})


# ------------------------------------------------------------------------------------------- loading

async def locked(db: AsyncSession, duel_id: str, user: User, now: datetime) -> tuple[Duel, list[DuelPlayer]]:
    """The duel, row-locked and settled, if ``user`` holds a seat in it (otherwise 404, revealing nothing)."""
    duel = (await db.execute(select(Duel).where(Duel.id == duel_id).with_for_update())).scalar_one_or_none()
    if duel is None:
        raise not_found()
    players = await players_of(db, duel.id)
    if not any(p.user_id == user.id for p in players):
        raise not_found()
    await settle(db, duel, now, players)
    return duel, await players_of(db, duel.id)


# ------------------------------------------------------------------------------------------- creation

async def create(db: AsyncSession, user: User, body: C.DuelCreate, now: datetime) -> Duel:
    await learner_lock(db, user.id)                            # serializes this learner's creations
    friend_ids = list(body.friend_user_ids)
    if len(set(friend_ids)) != len(friend_ids) or user.id in friend_ids:
        raise invalid("Invite each friend once.", "duplicate_or_self")
    friends: list[User] = []
    for friend_id in friend_ids:
        friend = await db.get(User, friend_id)
        if friend is None or not can_befriend(friend) or not await are_friends(db, user.id, friend_id):
            raise invalid("Challenges are only possible with your friends.", "not_a_friend")
        friends.append(friend)
    if friends:
        # One open challenge at a time with the same friend (no stacking of rematches; recorded decision).
        busy = await db.scalar(select(Duel.id).join(DuelPlayer, DuelPlayer.duel_id == Duel.id).where(
            Duel.status.in_(OPEN), Duel.created_by == user.id, DuelPlayer.user_id.in_(friend_ids),
            Duel.expires_at > now).limit(1))
        if busy is not None:
            raise not_joinable("already_open", "You already have an open challenge with this friend.")
    duel_id = new_id("duel")
    config = PRESETS[body.preset]
    chosen = await selection.choose(db, [user.id, *friend_ids], config["question_count"], duel_id)
    is_bot = body.opponent_type == "bot"
    duel = Duel(id=duel_id, preset=body.preset, mode="live", status="ready" if is_bot else "pending",
                opponent_type=body.opponent_type, bot_fill=body.bot_fill, config=config, created_by=user.id,
                created_at=now, expires_at=now + LIVE_TTL,
                lobby_deadline_at=now + GROUP_LOBBY if body.preset == "group" else None)
    db.add(duel)
    await db.flush()
    db.add(DuelPlayer(duel_id=duel_id, user_id=user.id, seat=0, status="joined", joined_at=now, responded_at=now))
    if is_bot:
        await bot.ensure_bots(db)
        db.add(DuelPlayer(duel_id=duel_id, user_id=bot.BOT_IDS[0], seat=1, is_bot=True, status="joined",
                          joined_at=now))
    for seat, friend in enumerate(friends, start=1):
        db.add(DuelPlayer(duel_id=duel_id, user_id=friend.id, seat=seat, status="invited"))
    for index, item in enumerate(chosen):
        db.add(DuelQuestion(duel_id=duel_id, question_index=index, exercise_id=item.exercise_id,
                            exercise_version=item.version))
    await db.flush()
    return duel


# ------------------------------------------------------------------------------------------- transitions

async def _start_group(db: AsyncSession, duel: Duel, players: list[DuelPlayer], now: datetime) -> None:
    joined = [p for p in players if p.seat > 0 and p.status == "joined"]
    if not joined:
        duel.status = "expired"
        return
    if duel.bot_fill:
        missing = [p for p in players if p.seat > 0 and p.status != "joined"]
        if missing:
            await bot.ensure_bots(db)
        for offset, (_, bot_id) in enumerate(zip(missing, bot.BOT_IDS, strict=False)):
            db.add(DuelPlayer(duel_id=duel.id, user_id=bot_id, seat=4 + offset, is_bot=True, status="joined",
                              joined_at=now))
    duel.status = "ready"
    await db.flush()


async def _after_response(db: AsyncSession, duel: Duel, players: list[DuelPlayer], now: datetime) -> None:
    invitees = [p for p in players if p.seat > 0 and not p.is_bot]
    if duel.preset == "duel":
        duel.status = "ready" if invitees[0].status == "joined" else "declined"
    elif all(p.status != "invited" for p in invitees):
        await _start_group(db, duel, players, now)


async def settle(db: AsyncSession, duel: Duel, now: datetime, players: list[DuelPlayer] | None = None) -> None:
    """Apply every transition whose time has come (idempotent; caller holds the row lock)."""
    if duel.status not in OPEN:
        return
    players = players if players is not None else await players_of(db, duel.id)
    if duel.mode == "async":
        if now >= duel.expires_at:
            await close_async(db, duel, players, now)
        return
    if duel.status == "pending" and duel.preset == "group" and duel.lobby_deadline_at is not None \
            and now >= duel.lobby_deadline_at:
        await _start_group(db, duel, players, now)
    if duel.status in ("pending", "ready") and duel.phase is None and now >= duel.expires_at:
        duel.status = "expired"
    await db.flush()


async def close_async(db: AsyncSession, duel: Duel, players: list[DuelPlayer], now: datetime) -> None:
    """24 h after the switch: a friend who has not finished forfeits (the inviter wins); an inviter who abandoned
    keeps 0 on unanswered questions and normal ranking applies (API §6.10)."""
    friend = next(p for p in players if p.seat == 1)
    if friend.completed_at is None:
        friend.forfeited = True
    await db.flush()
    await results.finish(db, duel, now)


async def accept(db: AsyncSession, user: User, duel_id: str, now: datetime) -> Duel:
    duel, players = await locked(db, duel_id, user, now)
    me = next(p for p in players if p.user_id == user.id)
    if me.seat == 0 or me.is_bot:
        raise not_joinable("own_challenge", "You created this challenge.")
    if me.status == "joined":
        return duel                                            # repeated accept: the same answer
    if me.status != "invited" or duel.status not in ("pending", "in_progress") or me.forfeited:
        raise not_joinable(duel.status)
    me.status, me.joined_at, me.responded_at = "joined", now, now
    if duel.mode == "live":
        await _after_response(db, duel, players, now)
    await db.flush()
    return duel


async def decline(db: AsyncSession, user: User, duel_id: str, now: datetime) -> None:
    duel, players = await locked(db, duel_id, user, now)
    me = next(p for p in players if p.user_id == user.id)
    if me.seat == 0 or me.is_bot:
        raise not_joinable("own_challenge", "You created this challenge.")
    if me.status == "declined":
        return                                                 # idempotent
    if me.status != "invited":
        raise not_joinable("already_joined", "You already joined this challenge.")
    if duel.status not in ("pending", "in_progress"):
        return                                                 # the invitation already closed: nothing to decline
    me.status, me.responded_at = "declined", now
    if duel.mode == "async":
        me.forfeited = True                                    # the inviter wins when they finish (or at 24 h)
        inviter = next(p for p in players if p.seat == 0)
        if inviter.completed_at is not None:
            await results.finish(db, duel, now)
    else:
        await _after_response(db, duel, players, now)
    await db.flush()


async def switch_async(db: AsyncSession, user: User, duel_id: str, now: datetime) -> Duel:
    duel, _ = await locked(db, duel_id, user, now)
    if duel.created_by != user.id:
        raise not_joinable("not_inviter", "Only the challenger can play now.")
    if duel.mode == "async":
        return duel                                            # repeated switch: the same answer
    if duel.preset != "duel" or duel.opponent_type != "friend" or duel.status != "pending":
        raise not_joinable(duel.status, "This challenge cannot be played later.")
    if now < duel.created_at + ASYNC_AFTER:
        raise not_joinable("too_early", "Wait a minute for your friend first.")
    duel.mode, duel.status, duel.async_at, duel.expires_at = "async", "in_progress", now, now + ASYNC_TTL
    await db.flush()
    return duel


# ------------------------------------------------------------------------------------------- lists

def _mine(user_id: str) -> Select[Any]:
    return select(Duel).join(DuelPlayer, DuelPlayer.duel_id == Duel.id).where(DuelPlayer.user_id == user_id)


async def history(db: AsyncSession, user: User, cursor: str | None, limit: int, lang: str, ws_base: str,
                  now: datetime) -> dict[str, Any]:
    page_args(cursor, limit, "duel_")
    query = _mine(user.id)
    if cursor is not None:
        query = query.where(Duel.id < cursor)
    rows = list((await db.execute(query.order_by(Duel.id.desc()).limit(limit + 1))).scalars())
    more = len(rows) > limit
    items = []
    for duel in rows[:limit]:
        locked_duel = (await db.execute(select(Duel).where(Duel.id == duel.id).with_for_update())).scalar_one()
        await settle(db, locked_duel, now)
        items.append((await project(db, locked_duel, user, lang, ws_base)).model_dump(mode="json"))
    return {"items": items, "next_cursor": rows[limit - 1].id if more else None}


async def invitations(db: AsyncSession, user: User, cursor: str | None, limit: int, now: datetime) -> dict[str, Any]:
    """Open invitations to ``user``: pending live challenges, and async duels still acceptable (24 h)."""
    page_args(cursor, limit, "duel_")
    query = (select(Duel, User).join(DuelPlayer, DuelPlayer.duel_id == Duel.id)
             .join(User, User.id == Duel.created_by)
             .where(DuelPlayer.user_id == user.id, DuelPlayer.status == "invited", DuelPlayer.forfeited.is_(False),
                    Duel.expires_at > now, User.deleted_at.is_(None),
                    or_(and_(Duel.status == "pending",
                             or_(Duel.lobby_deadline_at.is_(None), Duel.lobby_deadline_at > now)),
                        and_(Duel.mode == "async", Duel.status == "in_progress"))))
    if cursor is not None:
        query = query.where(Duel.id < cursor)
    rows = list((await db.execute(query.order_by(Duel.id.desc()).limit(limit + 1))).all())
    more = len(rows) > limit
    items = [C.Invitation.model_validate({
        "duel_id": duel.id, "from": {"user_id": inviter.id, "display_name": inviter.display_name},
        "created_at": iso(duel.created_at), "expires_at": iso(duel.expires_at)}).model_dump(mode="json", by_alias=True)
        for duel, inviter in rows[:limit]]
    return {"items": items, "next_cursor": rows[limit - 1][0].id if more else None}


# ------------------------------------------------------------------------------------------- deletion

async def close_for_deleted(db: AsyncSession, user_id: str, now: datetime) -> None:
    """Account deletion: open challenges with the learner close without rewards; a group lobby that still has other
    friends only records the decline. Finished history stays (results name only ids)."""
    open_duels = (await db.execute(select(Duel).join(DuelPlayer, DuelPlayer.duel_id == Duel.id).where(
        DuelPlayer.user_id == user_id, Duel.status.in_(OPEN)).order_by(Duel.id).with_for_update(of=Duel))).scalars()
    for duel in open_duels:
        players = await players_of(db, duel.id)
        me = next(p for p in players if p.user_id == user_id)
        if duel.preset == "group" and duel.status == "pending" and me.seat > 0 and me.status == "invited":
            me.status, me.responded_at = "declined", now
            await _after_response(db, duel, players, now)
        else:
            duel.status = "expired"
    await db.flush()


async def answers_of(db: AsyncSession, duel_id: str, user_id: str) -> list[DuelAnswer]:
    return list((await db.execute(select(DuelAnswer).where(DuelAnswer.duel_id == duel_id,
                                                          DuelAnswer.user_id == user_id)
                                  .order_by(DuelAnswer.question_index))).scalars())


# ------------------------------------------------------------------------------------------- sweep

async def sweep(maker: async_sessionmaker[AsyncSession], now: datetime, *, batch: int = 500) -> int:
    """The expiry/forfeit beat job: settle every open duel whose deadline passed, one transaction per duel
    (rows locked by a request are skipped and settled on the next run or by that request)."""
    async with maker() as db:
        due = (await db.execute(select(Duel.id).where(Duel.status.in_(OPEN), or_(
            Duel.expires_at <= now,
            and_(Duel.status == "pending", Duel.lobby_deadline_at.is_not(None), Duel.lobby_deadline_at <= now)))
            .order_by(Duel.expires_at).limit(batch))).scalars().all()
    settled = 0
    for duel_id in due:
        async with maker() as db, db.begin():
            duel = (await db.execute(select(Duel).where(Duel.id == duel_id).with_for_update(skip_locked=True))
                    ).scalar_one_or_none()
            if duel is not None:
                before = duel.status
                await settle(db, duel, now)
                settled += int(duel.status != before)
    return settled
