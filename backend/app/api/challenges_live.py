"""Closed revision 10 challenge WebSocket; ticket authentication replaces URL bearer tokens."""

from __future__ import annotations

import asyncio
import json
import logging
from contextlib import suppress
from typing import Any

from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from sqlalchemy import select

from app.contract import models as C
from app.errors import ApiError, ErrorCode, error_response
from app.models import DuelLiveEvent
from app.runtime import Resources, redis_key
from app.services.challenges import live, tickets
from app.services.challenges.runtime import LiveManager
from app.services.platform.rate_limits import RateLimiter

router = APIRouter(prefix="/ws/duels")
log = logging.getLogger("qabas.live.socket")


class CloseSocket(Exception):
    def __init__(self, code: int) -> None:
        self.code = code


@router.websocket("/{duel_id}")
async def socket(websocket: WebSocket, duel_id: str) -> None:
    r: Resources = websocket.app.state.resources
    manager: LiveManager = websocket.app.state.live_manager
    accepted = False
    ticket = None
    cid = None
    tasks: list[asyncio.Task[None]] = []
    pubsub = None
    try:
        if manager.draining:
            raise ApiError(ErrorCode.upstream_unavailable, "The server is restarting. Please reconnect.")
        origin = websocket.headers.get("origin")
        if origin is not None and origin not in {*r.settings.cors_allowed_origins, "https://qabas-app.pages.dev"}:
            raise ApiError(ErrorCode.forbidden, "Challenge access denied.")
        tokens = websocket.query_params.getlist("ticket")
        if len(tokens) != 1:
            raise tickets.unauthorized()
        ticket = await tickets.consume(r.redis, r.settings, duel_id, tokens[0])
        await RateLimiter(r.redis, r.settings).hit("ws_connect", ticket.user_id)
        cid = await live.open_connection(r, ticket, manager.clock())
        base = f"{websocket.url.scheme}://{websocket.url.netloc}"
        async with r.sessionmaker() as db, db.begin():
            viewer = await tickets.principal(db, ticket, r.settings, manager.clock())
            duel, me = await live.authorize(db, duel_id, ticket.user_id)
            viewer = await tickets.principal(db, ticket, r.settings, manager.clock())
            initial, cursor = await live.state(db, r, duel, me, viewer, ticket.language, base, manager.clock())
            completed = await live.finished(db, duel, me, ticket.language) if duel.status == "finished" else None
            closed = duel.status in ("expired", "declined")
        await websocket.accept()
        accepted = True
        manager.sockets.add(websocket)
        await asyncio.wait_for(websocket.send_json(initial), r.settings.live_ws_send_timeout_seconds)
        if completed is not None:
            await asyncio.wait_for(websocket.send_json(completed), r.settings.live_ws_send_timeout_seconds)
            await websocket.close(code=1000)
            return
        if closed:
            await websocket.close(code=1000)
            return
        current = initial["data"]["live"]
        if current is not None and current["phase"] == "question" and me.status == "joined":
            await asyncio.wait_for(websocket.send_json(live.event("question", current["question"])),
                                   r.settings.live_ws_send_timeout_seconds)
        manager.ensure(duel_id)
        queue: asyncio.Queue[dict[str, Any]] = asyncio.Queue(maxsize=32)
        pubsub = r.redis.pubsub()
        await pubsub.subscribe(redis_key(r.settings, "duel", duel_id, "events"))

        def enqueue(body: dict[str, Any]) -> None:
            queue.put_nowait(body)  # bounded; a slow consumer reconnects from the durable projection

        async def send() -> None:
            while True:
                body = await queue.get()
                await asyncio.wait_for(websocket.send_json(body), r.settings.live_ws_send_timeout_seconds)
                if body["type"] == "finished":
                    return
                if body["type"] == "state" and body["data"]["duel"]["status"] in ("expired", "declined"):
                    return

        async def receive() -> None:
            assert ticket is not None and cid is not None
            while True:
                try:
                    frame = await asyncio.wait_for(websocket.receive(), 30)
                except TimeoutError:
                    raise CloseSocket(1000) from None
                now = manager.clock()  # receipt time, before database or provider waits; never a client timestamp
                if frame["type"] == "websocket.disconnect":
                    return
                raw = frame.get("text")
                size = len(raw.encode("utf-8")) if raw is not None else len(frame.get("bytes") or b"")
                if size > r.settings.live_ws_max_frame_bytes:
                    raise CloseSocket(1009)
                try:
                    await RateLimiter(r.redis, r.settings).hit("ws_message", str(cid))
                    if raw is None:
                        raise ValueError()
                    body = json.loads(raw)
                    C.WsClientMessage.model_validate(body)
                    await live.message(r, ticket, cid, body, now)
                    if body["type"] == "ping":
                        enqueue(live.event("pong", {}))
                except (ValueError, RecursionError):
                    await live.message(r, ticket, cid, {"type": "ping", "data": {}}, now)
                    enqueue(live.event("error", {"code": "validation_error", "message": "Invalid challenge message."}))
                except ApiError as exc:
                    if exc.code in (ErrorCode.unauthorized, ErrorCode.forbidden, ErrorCode.duel_not_joinable):
                        raise
                    enqueue(live.event("error", {"code": exc.code.value, "message": exc.message}))

        async def forward() -> None:
            nonlocal cursor
            assert ticket is not None and pubsub is not None
            while True:
                async with r.sessionmaker() as db, db.begin():
                    viewer = await tickets.principal(db, ticket, r.settings, manager.clock())
                    duel, me = await live.authorize(db, duel_id, ticket.user_id)
                    viewer = await tickets.principal(db, ticket, r.settings, manager.clock())
                    rows = list((await db.execute(select(DuelLiveEvent).where(DuelLiveEvent.duel_id == duel_id,
                        DuelLiveEvent.epoch.is_not(None), DuelLiveEvent.id > cursor)
                        .order_by(DuelLiveEvent.id).limit(32))).scalars())
                    for row in rows:
                        body = await live.project_event(db, r, duel, me, viewer, row, ticket.language,
                                                        base, manager.clock())
                        cursor = row.id
                        if body is not None:
                            enqueue(body)
                    terminal = duel.status in ("expired", "declined")
                    if terminal:
                        enqueue((await live.state(db, r, duel, me, viewer, ticket.language, base, manager.clock()))[0])
                if terminal:
                    # Flush the terminal state without holding a database lock during network delivery.
                    await asyncio.Future[None]()
                if len(rows) < 32:
                    await asyncio.wait_for(pubsub.get_message(ignore_subscribe_messages=True, timeout=1), 2)

        tasks = [asyncio.create_task(send()), asyncio.create_task(receive()), asyncio.create_task(forward())]
        done, _ = await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED)
        for task in done:
            task.result()
        for task in tasks:
            task.cancel()
        await asyncio.gather(*tasks, return_exceptions=True)
        await websocket.close(code=1000)
    except (WebSocketDisconnect, asyncio.CancelledError):
        pass
    except CloseSocket as exc:
        for task in tasks:
            task.cancel()
        await asyncio.gather(*tasks, return_exceptions=True)
        with suppress(Exception):
            await websocket.close(code=exc.code)
    except ApiError as exc:
        for task in tasks:
            task.cancel()
        await asyncio.gather(*tasks, return_exceptions=True)
        if accepted:
            with suppress(Exception):
                await websocket.send_json(live.event("error", {"code": exc.code.value, "message": exc.message}))
                await websocket.close(code=1008 if exc.code == ErrorCode.unauthorized else 1000)
        else:
            await websocket.send_denial_response(error_response(exc.code, exc.message, exc.details))
    except Exception as exc:
        for task in tasks:
            task.cancel()
        await asyncio.gather(*tasks, return_exceptions=True)
        # No exception text/traceback: database errors can contain answers and URL errors can contain tickets.
        log.warning("challenge socket unavailable", extra={"error_type": type(exc).__name__})
        with suppress(Exception):
            if accepted:
                await websocket.close(code=1013)
            else:
                await websocket.send_denial_response(error_response(ErrorCode.upstream_unavailable,
                                                                     "Challenge connection unavailable."))
    finally:
        for task in tasks:
            task.cancel()
        await asyncio.gather(*tasks, return_exceptions=True)
        manager.sockets.discard(websocket)
        if pubsub is not None:
            with suppress(Exception):
                # Redis PubSub lacks aclose annotations.
                await pubsub.aclose()  # type: ignore[no-untyped-call]
        if ticket is not None and cid is not None:
            with suppress(Exception):
                await live.close_connection(r, ticket, cid, manager.clock())
                await live.notify(r, duel_id)
