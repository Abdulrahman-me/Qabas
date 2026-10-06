"""Per-instance transport/coordinator lifecycle. No match state exists solely in these tasks."""

from __future__ import annotations

import asyncio
import logging
from collections.abc import Callable
from contextlib import suppress
from datetime import datetime

from sqlalchemy import select
from starlette.websockets import WebSocket

from app.config import Environment
from app.models import Duel
from app.runtime import Resources
from app.services.challenges import coordinator, duels
from app.services.platform.auth_sessions import utcnow

log = logging.getLogger("qabas.live")


class LiveManager:
    def __init__(self, resources: Resources, *, clock: Callable[[], datetime] = utcnow) -> None:
        self.resources = resources
        self.clock = clock
        self.rooms: dict[str, asyncio.Task[None]] = {}
        self.sockets: set[WebSocket] = set()
        self.scanner: asyncio.Task[None] | None = None
        self.draining = False
        self.cursor = ""

    @property
    def healthy(self) -> bool:
        return not self.draining and (self.scanner is None or not self.scanner.done())

    def start(self) -> None:
        # Plain unit clients have no database. Integration socket tests explicitly start rooms on connect.
        if self.resources.settings.app_env != Environment.test:
            self.scanner = asyncio.create_task(self._scan(), name="live-challenge-scan")

    def ensure(self, duel_id: str) -> None:
        if self.draining:
            return
        task = self.rooms.get(duel_id)
        if task is None or task.done():
            task = asyncio.create_task(self._own(duel_id), name="live-challenge-owner")
            self.rooms[duel_id] = task

            def remove(done: asyncio.Task[None]) -> None:
                if self.rooms.get(duel_id) is done:
                    del self.rooms[duel_id]

            task.add_done_callback(remove)

    async def _scan(self) -> None:
        while not self.draining:
            try:
                async with self.resources.sessionmaker() as db:
                    ids = list((await db.execute(select(Duel.id).where(Duel.mode == "live",
                        Duel.status.in_(duels.OPEN), Duel.id > self.cursor).order_by(Duel.id).limit(100))).scalars())
                self.cursor = ids[-1] if len(ids) == 100 else ""
                for duel_id in ids:
                    self.ensure(duel_id)
            except Exception as exc:
                log.warning("challenge scan unavailable", extra={"error_type": type(exc).__name__})
            await asyncio.sleep(1)

    async def _own(self, duel_id: str) -> None:
        while not self.draining:
            lease = None
            renewer = None
            try:
                lease = await coordinator.acquire(self.resources, duel_id)
                if lease is None:
                    async with self.resources.sessionmaker() as db:
                        duel = await db.get(Duel, duel_id)
                        if duel is None or duel.mode != "live" or duel.status not in duels.OPEN:
                            return
                else:
                    renewer = asyncio.create_task(coordinator.keepalive(self.resources, lease),
                                                   name="live-challenge-renew")
                    while not self.draining:
                        if renewer.done():
                            await renewer
                        active = await asyncio.wait_for(coordinator.tick(self.resources, lease, self.clock()), 10)
                        if not active:
                            return
                        await asyncio.sleep(coordinator.PULSE_SECONDS)
            except coordinator.LeaseLost:
                pass
            except Exception as exc:
                log.warning("challenge owner unavailable", extra={"error_type": type(exc).__name__})
            finally:
                if renewer is not None:
                    renewer.cancel()
                    await asyncio.gather(renewer, return_exceptions=True)
                if lease is not None:
                    with suppress(Exception):
                        await lease.release(self.resources)
            await asyncio.sleep(1)

    async def close(self) -> None:
        self.draining = True
        if self.scanner is not None:
            self.scanner.cancel()
        for socket in list(self.sockets):
            with suppress(Exception):
                await asyncio.wait_for(socket.close(code=1012), 1)
        tasks = list(self.rooms.values())
        if self.scanner is not None:
            tasks.append(self.scanner)
        for task in tasks:
            task.cancel()
        await asyncio.gather(*tasks, return_exceptions=True)
