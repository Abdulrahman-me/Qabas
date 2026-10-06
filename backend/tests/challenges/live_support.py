"""Native PostgreSQL/Redis rooms with explicit server time; no production timing exceptions or provider calls."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Any
from uuid import UUID

from sqlalchemy import select

from app.models import AuthSession, Duel, DuelPlayer, DuelQuestion, User
from app.runtime import Resources
from app.services.challenges import coordinator, live, tickets
from app.services.platform.auth_sessions import utcnow
from tests.challenges import support as S


@dataclass
class Room:
    r: Resources
    duel_id: str
    users: list[str]
    headers: list[dict[str, str]]
    tickets: list[tickets.Ticket]
    connections: list[UUID]
    start: datetime
    lease: coordinator.Lease

    async def pulse(self, now: datetime) -> bool:
        assert await self.lease.renew(self.r)
        return await coordinator.tick(self.r, self.lease, now)

    async def send(self, seat: int, kind: str, data: dict[str, Any], now: datetime) -> None:
        await live.message(self.r, self.tickets[seat], self.connections[seat], {"type": kind, "data": data}, now)

    async def state(self, seat: int, now: datetime) -> dict[str, Any]:
        async with self.r.sessionmaker() as db, db.begin():
            viewer = await db.get(User, self.users[seat])
            assert viewer is not None
            duel, me = await live.authorize(db, self.duel_id, viewer.id)
            return (await live.state(db, self.r, duel, me, viewer, self.tickets[seat].language,
                                      "ws://testserver", now))[0]

    async def question(self, index: int) -> DuelQuestion:
        async with self.r.sessionmaker() as db:
            q = await db.scalar(select(DuelQuestion).where(DuelQuestion.duel_id == self.duel_id,
                DuelQuestion.question_index == index, DuelQuestion.user_id.is_(None)))
            assert q is not None
            return q

    async def status(self) -> Duel:
        async with self.r.sessionmaker() as db:
            duel = await db.get(Duel, self.duel_id)
            assert duel is not None
            return duel


async def ticket_for(r: Resources, uid: str, duel_id: str, lang: str = "en") -> tickets.Ticket:
    async with r.sessionmaker() as db:
        sid = await db.scalar(select(AuthSession.id).where(AuthSession.user_id == uid,
            AuthSession.revoked_at.is_(None)).order_by(AuthSession.created_at.desc()).limit(1))
        assert sid is not None
        return tickets.Ticket(user_id=uid, session_id=sid, duel_id=duel_id, language=lang)


async def make(r: Resources, *, humans: int = 1, preset: str = "duel", ready: bool = True) -> Room:
    accounts = [await S.signed_in(r, display_name=f"Seeker {i}") for i in range(humans)]
    users, headers = [a[0] for a in accounts], [a[1] for a in accounts]
    start = utcnow()
    for friend in users[1:]:
        await S.befriend(r, users[0], friend)
    duel_id = await S.create(r, users[0], start, preset=preset,
        opponent_type="bot" if humans == 1 else ("friends" if preset == "group" else "friend"), friends=users[1:])
    for uid in users[1:]:
        await S.accept(r, uid, duel_id, start)
    bound = [await ticket_for(r, uid, duel_id) for uid in users]
    conns = [await live.open_connection(r, t, start) for t in bound]
    lease = await coordinator.acquire(r, duel_id)
    assert lease is not None
    room = Room(r, duel_id, users, headers, bound, conns, start, lease)
    if ready:
        for i in range(humans):
            await room.send(i, "ready", {}, start)
        await room.pulse(start)
        if humans == 1:
            await room.pulse(start + timedelta(seconds=1))
    return room


async def players(r: Resources, duel_id: str) -> list[DuelPlayer]:
    async with r.sessionmaker() as db:
        return list((await db.execute(select(DuelPlayer).where(DuelPlayer.duel_id == duel_id)
                                       .order_by(DuelPlayer.seat))).scalars())
