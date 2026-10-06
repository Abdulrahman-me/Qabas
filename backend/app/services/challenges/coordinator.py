"""AD-23 fenced coordinator: local timers wake it; persisted facts determine every transition.

Redis ownership is atomic, expires after five seconds and is renewed every second. The persisted epoch is a floor
for Redis INCR, including after Redis data loss. Every transaction locks the duel, checks exact ownership/epoch,
sets its database fencing context and checks ownership again before commit. Only committed journal entries are
published; reconnect/polling tails recover a crash or lost pubsub wakeup.
"""

from __future__ import annotations

import asyncio
import secrets
from collections.abc import Awaitable
from contextlib import suppress
from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Any, cast

from sqlalchemy import Text, exists, select, text, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from app.models import Duel, DuelConnection, DuelLiveEvent
from app.runtime import Resources, redis_key
from app.services.challenges import bot, duels, live, play, results

LEASE_MS = 5000
RENEW_SECONDS = 1.0
PULSE_SECONDS = 0.2

_ACQUIRE = """
if redis.call('EXISTS', KEYS[1]) == 1 then return 0 end
local n = tonumber(redis.call('GET', KEYS[2]) or '0')
local floor = tonumber(ARGV[2])
if n < floor then redis.call('SET', KEYS[2], ARGV[2]) end
local epoch = redis.call('INCR', KEYS[2])
redis.call('SET', KEYS[1], ARGV[1] .. ':' .. tostring(epoch), 'NX', 'PX', 5000)
return epoch
"""
_RENEW = """
if redis.call('GET', KEYS[1]) ~= ARGV[1] then return 0 end
return redis.call('PEXPIRE', KEYS[1], 5000)
"""
_RELEASE = """
if redis.call('GET', KEYS[1]) ~= ARGV[1] then return 0 end
return redis.call('DEL', KEYS[1])
"""


class LeaseLost(Exception):
    """No writes/broadcasts are authorized by this coordinator anymore."""


@dataclass(frozen=True)
class Lease:
    duel_id: str
    epoch: int
    nonce: str

    @property
    def token(self) -> str:
        return f"{self.nonce}:{self.epoch}"

    def owner_key(self, r: Resources) -> str:
        return redis_key(r.settings, "duel", self.duel_id, "owner")

    async def valid(self, r: Resources) -> bool:
        result = await asyncio.wait_for(r.redis.get(self.owner_key(r)), 1)
        return bool(result == self.token.encode())

    async def check(self, r: Resources) -> None:
        if not await self.valid(r):
            raise LeaseLost()

    async def renew(self, r: Resources) -> bool:
        result = await asyncio.wait_for(cast(Awaitable[Any],
            r.redis.eval(_RENEW, 1, self.owner_key(r), self.token)), 1)
        return bool(result)

    async def release(self, r: Resources) -> None:
        await asyncio.wait_for(cast(Awaitable[Any], r.redis.eval(_RELEASE, 1, self.owner_key(r), self.token)), 1)


async def fencing_context(db: AsyncSession, epoch: int) -> None:
    await db.execute(text("SELECT set_config('qabas.coordinator_epoch', :epoch, true)"), {"epoch": str(epoch)})


async def acquire(r: Resources, duel_id: str) -> Lease | None:
    async with r.sessionmaker() as db:
        duel = await db.get(Duel, duel_id)
        if duel is None or duel.mode != "live" or duel.status not in duels.OPEN:
            return None
        floor = duel.coordinator_epoch
    nonce = secrets.token_urlsafe(24)
    epoch = int(await asyncio.wait_for(cast(Awaitable[Any], r.redis.eval(
        _ACQUIRE, 2, redis_key(r.settings, "duel", duel_id, "owner"),
        redis_key(r.settings, "duel", duel_id, "epoch"), nonce, str(floor))), 1))
    if not epoch:
        return None
    lease = Lease(duel_id, epoch, nonce)
    try:
        async with r.sessionmaker() as db, db.begin():
            await lease.check(r)
            await fencing_context(db, epoch)
            claimed = await db.execute(update(Duel).where(Duel.id == duel_id, Duel.mode == "live",
                Duel.status.in_(duels.OPEN), Duel.coordinator_epoch < epoch).values(coordinator_epoch=epoch)
                .returning(Duel.id))
            if claimed.scalar_one_or_none() is None:
                raise LeaseLost()
            await lease.check(r)
    except BaseException:
        await lease.release(r)
        raise
    return lease


async def tick(r: Resources, lease: Lease, now: datetime) -> bool:
    """One recoverable pulse. Returns false once no further live work is possible."""
    async with r.sessionmaker() as db, db.begin():
        duel = await db.scalar(select(Duel).where(Duel.id == lease.duel_id).with_for_update())
        if duel is None or duel.coordinator_epoch != lease.epoch:
            raise LeaseLost()
        await lease.check(r)
        await fencing_context(db, lease.epoch)
        if duel.mode != "live":
            return False
        await duels.settle(db, duel, now)
        players = await duels.players_of(db, duel.id)

        async def emit(kind: str, key: str, data: dict[str, object]) -> None:
            await live.append(db, duel, kind, key, data, now, lease.epoch)

        # Inputs committed by socket instances are consumed once without relying on pubsub delivery.
        sent = aliased(DuelLiveEvent)
        signals = list((await db.execute(select(DuelLiveEvent).where(DuelLiveEvent.duel_id == duel.id,
            DuelLiveEvent.epoch.is_(None), ~exists(select(sent.id).where(sent.duel_id == duel.id,
            sent.event_key == "signal:" + DuelLiveEvent.id.cast(Text))))
            .order_by(DuelLiveEvent.id))).scalars())
        for signal in signals:
            kind = {"input.ready": "player_ready", "input.disconnected": "opponent_disconnected",
                    "input.reconnected": "opponent_reconnected", "input.answered": "answered"}[signal.kind]
            data = dict(signal.data)
            if kind == "opponent_disconnected":
                data["grace_ms"] = 10000
            await emit(kind, f"signal:{signal.id}", data)

        if duel.status in ("pending", "ready"):
            for p in players:
                if p.status != "left":
                    await emit("player_status", f"status:{p.user_id}:{p.status}",
                               {"user_id": p.user_id, "status": p.status})
        if duel.status == "ready":
            await emit("state", "lobby:ready", {"status": "ready"})
        if duel.status in ("expired", "declined"):
            await emit("state", f"terminal:{duel.status}", {})
            active = False
        elif duel.status == "finished":
            active = False
        else:
            active = True
            participating = results.participants(players)
            connections = await live.active_connections(db, duel.id, now)
            connected = {c.user_id for c in connections}
            for p in participating:
                if p.is_bot:
                    if p.ready_at is None and duel.live_connected_at is not None and p.joined_at is not None:
                        ready_at = max(duel.live_connected_at, p.joined_at) + timedelta(seconds=1)
                        if now >= ready_at:
                            p.ready_at = ready_at
                            await emit("player_ready", f"bot-ready:{p.user_id}", {"user_id": p.user_id})
                    continue
                if p.user_id not in connected and p.disconnected_at is None:
                    expired = await db.scalar(select(DuelConnection).where(DuelConnection.duel_id == duel.id,
                        DuelConnection.user_id == p.user_id).order_by(DuelConnection.expires_at.desc()).limit(1))
                    if expired is not None:
                        p.disconnected_at = expired.closed_at or expired.expires_at
                        await emit("opponent_disconnected", f"dead-connection:{expired.id}",
                                   {"user_id": p.user_id, "grace_ms": 10000})
                if duel.phase is not None and p.status != "left" and p.disconnected_at is not None \
                        and now >= p.disconnected_at + live.GRACE:
                    p.status = "left"
                if duel.phase is not None and p.status == "left" and duel.preset == "group":
                    await emit("player_left", f"left:{p.user_id}", {"user_id": p.user_id})
            await db.flush()
            if duel.status == "ready" and participating and all(p.ready_at is not None for p in participating):
                duel.status, duel.phase, duel.starts_at = "in_progress", "countdown", now + timedelta(seconds=3)
                await emit("countdown", "countdown", {"starts_at": live.timestamp(duel.starts_at), "seconds": 3})
                await db.flush()
            qs = await live.questions(db, duel.id)
            if duel.phase == "countdown" and duel.starts_at is not None and now >= duel.starts_at:
                qs[0].issued_at = duel.starts_at
                qs[0].deadline_at = duel.starts_at + timedelta(milliseconds=duel.config["time_limit_ms"])
                duel.phase = "question"
                await emit("question", "question:0", {"question_index": 0})
                await db.flush()
            current = next((q for q in qs if q.issued_at is not None and q.closed_at is None), None)
            if duel.phase == "question" and current is None:
                raise ValueError("live question state has no issued question")
            if duel.phase == "question" and current is not None:
                assert current.issued_at is not None and current.deadline_at is not None
                for p in participating:
                    if p.status == "left":
                        await live.record(db, duel, p, current, None, now, absent=True)
                    elif p.is_bot:
                        version = await play._version(db, duel.id, current.question_index)
                        choice = bot.answer(duel.id, current.question_index, p.user_id,
                                            play._exercise(version, duel, "ar"), version.answer_key)
                        due = current.issued_at + timedelta(milliseconds=choice.elapsed_ms)
                        if now >= due and due <= current.deadline_at \
                                and await live.record(db, duel, p, current, choice.answer, due):
                            await emit("answered", f"bot-answer:{p.user_id}:{current.question_index}",
                                       {"user_id": p.user_id, "question_index": current.question_index})
                rows = [a for a in await live.answers(db, duel.id) if a.question_index == current.question_index]
                accounted = {a.user_id for a in rows}
                quorum = {p.user_id for p in participating if p.status == "joined"
                          and (p.is_bot or p.user_id in connected)}
                if now > current.deadline_at or (quorum and quorum <= accounted) \
                        or all(p.status == "left" for p in participating):
                    for p in participating:
                        await live.record(db, duel, p, current, None, now, absent=p.status == "left")
                    coordinates = live.result_coordinates(participating, await live.answers(db, duel.id),
                                                          current.question_index)
                    current.closed_at = now
                    current.reveal_until = now + timedelta(milliseconds=duel.config["reveal_ms"])
                    current.result_snapshot = coordinates
                    duel.phase = "result"
                    await db.flush()
                    await emit("question_result", f"result:{current.question_index}",
                               {"question_index": current.question_index})
            if duel.phase == "result":
                closed = [q for q in qs if q.closed_at is not None]
                if not closed:
                    raise ValueError("live result state has no closed question")
                last = closed[-1]
                assert last.reveal_until is not None
                if now >= last.reveal_until:
                    if last.question_index + 1 == duel.config["question_count"]:
                        await results.finish(db, duel, now)
                        await emit("finished", "finished", {})
                        active = False
                    else:
                        nxt = qs[last.question_index + 1]
                        nxt.issued_at, nxt.deadline_at = now, now + timedelta(milliseconds=duel.config["time_limit_ms"])
                        duel.phase = "question"
                        await emit("question", f"question:{nxt.question_index}", {"question_index": nxt.question_index})
            await db.flush()
        await lease.check(r)
    # This is deliberately outside the DB transaction. The journal recovers failure here.
    await lease.check(r)
    await live.notify(r, lease.duel_id)
    return active


async def keepalive(r: Resources, lease: Lease) -> None:
    while True:
        await asyncio.sleep(RENEW_SECONDS)
        if not await lease.renew(r):
            raise LeaseLost()


async def recover(r: Resources, now: datetime, *, limit: int = 100) -> int:
    """Bounded beat fallback: claim and pulse ownerless rooms, releasing before the next scheduled invocation."""
    cursor_key = redis_key(r.settings, "live-recovery-cursor")
    raw_cursor = await r.redis.get(cursor_key)
    cursor = raw_cursor.decode() if raw_cursor else ""
    async with r.sessionmaker() as db:
        ids = list((await db.execute(select(Duel.id).where(Duel.mode == "live", Duel.status.in_(duels.OPEN))
                                    .where(Duel.id > cursor).order_by(Duel.id).limit(limit))).scalars())
    await r.redis.set(cursor_key, ids[-1] if len(ids) == limit else "", ex=60)
    recovered = 0
    for duel_id in ids:
        try:
            lease = await acquire(r, duel_id)
        except LeaseLost:
            continue
        if lease is not None:
            renewer = asyncio.create_task(keepalive(r, lease))
            try:
                await asyncio.wait_for(tick(r, lease, now), 10)
                recovered += 1
            finally:
                renewer.cancel()
                await asyncio.gather(renewer, return_exceptions=True)
                with suppress(Exception):
                    await lease.release(r)
    return recovered
