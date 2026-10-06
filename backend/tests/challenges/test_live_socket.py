"""Real ASGI sockets backed by PostgreSQL/Redis, with bounded receives and server-owned test clocks."""

from __future__ import annotations

import asyncio
import json
import logging
import threading
from contextlib import ExitStack
from datetime import datetime, timedelta
from typing import Any
from urllib.parse import parse_qs, urlsplit

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select
from starlette.testclient import WebSocketDenialResponse, WebSocketTestSession
from starlette.websockets import WebSocketDisconnect

from app.contract import models as C
from app.logs import JsonFormatter, SocketURLFilter
from app.main import create_app
from app.models import AuthSession, DuelAnswer, DuelConnection
from app.runtime import Resources, redis_key
from app.services.challenges import live, tickets
from app.services.platform.rate_limits import RateLimiter
from tests.challenges import live_support as L
from tests.challenges import support as S
from tests.conftest import CONTRACT_HEADERS

pytestmark = pytest.mark.integration


def receive(ws: WebSocketTestSession, seconds: float = 8) -> dict[str, Any]:
    async def next_frame() -> dict[str, Any]:
        return await asyncio.wait_for(ws._send_rx.receive(), seconds)

    frame = ws.portal.call(next_frame)
    ws._raise_on_close(frame)
    result = json.loads(frame["text"])
    C.WsEvent.model_validate(result)
    return result


def until(ws: WebSocketTestSession, kind: str) -> dict[str, Any]:
    for _ in range(40):
        result = receive(ws)
        if result["type"] == kind:
            return result["data"]
    raise AssertionError(f"missing {kind}")


def url(api: TestClient, room: L.Room, seat: int = 0) -> str:
    response = api.get(f"/v1/duels/{room.duel_id}", headers=room.headers[seat] | {"Accept-Language": "en"})
    assert response.status_code == 200, response.text
    return str(response.json()["ws_url"])


async def fresh_room(r: Resources, humans: int = 1) -> L.Room:
    room = await L.make(r, humans=humans, ready=False)
    for i in range(humans):
        await live.close_connection(r, room.tickets[i], room.connections[i], room.start)
    await room.lease.release(r)
    return room


async def test_fresh_ticket_single_use_binding_ttl_and_history(world: tuple[TestClient, Resources]) -> None:
    api, r = world
    room = await fresh_room(r)
    first, second = url(api, room), url(api, room)
    assert first != second and room.headers[0]["Authorization"].split()[1] not in first
    token = parse_qs(urlsplit(first).query)["ticket"][0]
    assert 0 < await r.redis.ttl(tickets.key(r.settings, token)) <= 60
    history_response = api.get("/v1/duels", headers=room.headers[0])
    assert history_response.status_code == 200
    history = history_response.json()
    assert "ticket=" not in json.dumps(history)
    results = await asyncio.gather(*(tickets.consume(r.redis, r.settings, room.duel_id, token)
                                     for _ in range(8)), return_exceptions=True)
    assert sum(isinstance(v, tickets.Ticket) for v in results) == 1
    with pytest.raises(WebSocketDenialResponse) as denied, api.websocket_connect(first):
        pass
    assert denied.value.status_code == 401
    with api.websocket_connect(second) as ws:
        assert receive(ws)["type"] == "state"
        ws.send_json({"type": "ping", "data": {}})
        assert until(ws, "pong") == {}
    with pytest.raises(WebSocketDenialResponse) as denied, api.websocket_connect(second):
        pass
    assert denied.value.status_code == 401


@pytest.mark.parametrize("case", ["absent", "expired", "wrong_duel", "revoked", "outsider", "origin", "bearer"])
async def test_upgrade_denials_are_non_enumerating(world: tuple[TestClient, Resources], case: str) -> None:
    api, r = world
    room = await fresh_room(r)
    target, extra, code = url(api, room), {}, 401
    if case in ("absent", "bearer"):
        target = target.split("?")[0]
        if case == "bearer":
            extra = room.headers[0]
    elif case == "expired":
        token = parse_qs(urlsplit(target).query)["ticket"][0]
        await r.redis.delete(tickets.key(r.settings, token))
    elif case == "wrong_duel":
        target = target.replace(room.duel_id, "unknown-duel")
    elif case == "revoked":
        async with r.sessionmaker() as db, db.begin():
            auth = await db.get(AuthSession, room.tickets[0].session_id)
            assert auth is not None
            auth.revoked_at = room.start
    elif case == "outsider":
        uid, _ = await S.signed_in(r)
        outsider = await L.ticket_for(r, uid, room.duel_id)
        token = await tickets.mint(r.redis, r.settings, uid, outsider.session_id, room.duel_id, "en")
        target = target.split("?")[0] + "?ticket=" + token
        code = 403
    else:
        extra, code = {"Origin": "https://untrusted.example"}, 403
    with pytest.raises(WebSocketDenialResponse) as denied, api.websocket_connect(target, headers=extra):
        pass
    assert denied.value.status_code == code
    assert "answer" not in denied.value.text


async def test_malformed_frames_rate_limit_oversize_and_recovery(world: tuple[TestClient, Resources]) -> None:
    api, r = world
    room = await fresh_room(r)
    with api.websocket_connect(url(api, room)) as ws:
        receive(ws)
        for payload in ("{", '{"type":"leave","data":{}}', '{"type":"ping","data":{"secret":1}}'):
            ws.send_text(payload)
            assert until(ws, "error")["code"] == "validation_error"
        ws.send_bytes(b"binary")
        assert until(ws, "error")["code"] == "validation_error"
        ws.send_json({"type": "ping", "data": {}})
        until(ws, "pong")
        # Exhaust the real bucket atomically without assuming DB waits consume no refill time.
        async with r.sessionmaker() as db:
            cid = await db.scalar(select(DuelConnection.id).where(DuelConnection.duel_id == room.duel_id,
                DuelConnection.closed_at.is_(None)))
        assert cid is not None
        await r.redis.delete(redis_key(r.settings, "rl", "ws_message", "0", str(cid)))
        limiter = RateLimiter(r.redis, r.settings)
        for _ in range(5):
            await limiter.hit("ws_message", str(cid))
        ws.send_json({"type": "ping", "data": {}})
        assert until(ws, "error")["code"] == "rate_limited"
        ws.send_text("x" * (r.settings.live_ws_max_frame_bytes + 1))
        with pytest.raises(WebSocketDisconnect) as closed:
            receive(ws)
        assert closed.value.code == 1009
    with api.websocket_connect(url(api, room)) as ws:
        assert receive(ws)["type"] == "state"


async def test_two_api_instances_answer_secrecy_and_fresh_reconnect(world: tuple[TestClient, Resources]) -> None:
    api, r = world
    room = await fresh_room(r, humans=2)
    clock = [room.start]
    api.app.state.live_manager.clock = lambda: clock[0]
    with TestClient(create_app(r.settings), headers=CONTRACT_HEADERS, raise_server_exceptions=False) as other:
        other.app.state.live_manager.clock = lambda: clock[0]
        with other.websocket_connect(url(other, room, 1)) as b:
            assert receive(b)["type"] == "state"
            with api.websocket_connect(url(api, room)) as a:
                initial = receive(a)
                assert initial["data"]["live"] is None
                a.send_json({"type": "ready", "data": {}})
                b.send_json({"type": "ready", "data": {}})
                start = until(a, "countdown")["starts_at"]
                assert until(b, "countdown")["starts_at"] == start
                clock[0] = datetime.fromisoformat(start.replace("Z", "+00:00"))
                question = until(a, "question")
                assert until(b, "question") == question
                assert "correct_answer" not in json.dumps(question) and "answer_key" not in json.dumps(question)
                key = await S.key(r, room.duel_id, 0)
                clock[0] += timedelta(seconds=2)
                a.send_json({"type": "answer", "data": {"question_index": 0, "answer": key}})
                assert until(a, "answer_received") == {"question_index": 0}
                assert until(b, "opponent_answered") == {"question_index": 0, "user_id": room.users[0]}
            with api.websocket_connect(url(api, room)) as restored:
                snapshot = receive(restored)["data"]["live"]
                assert snapshot["question"]["deadline_at"] == question["deadline_at"]
                assert snapshot["my_answer"] == {"answer": key, "locked": True}
                assert all(p["points"] == 0 for p in snapshot["totals"])
                restored.send_json({"type": "answer", "data": {"question_index": 0,
                    "answer": S.wrong(key, question["exercise"])}})
                b.send_json({"type": "answer", "data": {"question_index": 0, "answer": key}})
                result = until(b, "question_result")
                assert until(restored, "question_result") == result
                assert result["correct_answer"] == key and all(p["correct"] for p in result["players"])
        async with r.sessionmaker() as db:
            assert len((await db.execute(select(DuelAnswer).where(DuelAnswer.duel_id == room.duel_id))).scalars()
                       .all()) == 2


async def test_drain_rejects_new_upgrade_and_closes_existing_socket(world: tuple[TestClient, Resources]) -> None:
    api, r = world
    room = await fresh_room(r)
    with api.websocket_connect(url(api, room)) as ws:
        receive(ws)
        target = url(api, room)
        api.portal.call(api.app.state.live_manager.close)
        with pytest.raises(WebSocketDisconnect) as closed:
            for _ in range(40):
                receive(ws)  # already committed lobby events may precede the drain close
        assert closed.value.code == 1012
        with pytest.raises(WebSocketDenialResponse) as denied, api.websocket_connect(target):
            pass
        assert denied.value.status_code == 503


def test_upgrade_logs_redact_url_even_without_custom_logging_configuration() -> None:
    record = logging.LogRecord("uvicorn.error", logging.INFO, "", 0, '%s - "WebSocket %s" [accepted]',
                               ("peer", "/v1/ws/duels/duel1?ticket=private-nonce&extra=unsafe"), None)
    assert SocketURLFilter().filter(record)
    assert "private-nonce" not in record.getMessage() and "unsafe" not in record.getMessage()
    raw = logging.LogRecord("uvicorn.error", logging.INFO, "", 0,
                            '/v1/ws/duels/duel1?ticket=private-nonce', (), None)
    assert "private-nonce" not in JsonFormatter().format(raw)


async def test_finished_reconnect_returns_same_result_without_rewards(world: tuple[TestClient, Resources]) -> None:
    api, r = world
    room = await L.make(r, humans=2, preset="group")
    start = (await room.status()).starts_at
    assert start is not None
    await room.pulse(start)
    for i in range(3):
        q = await room.question(i)
        assert q.issued_at is not None
        for seat in range(2):
            await room.send(seat, "answer", {"question_index": i, "answer": await S.key(r, room.duel_id, i)},
                            q.issued_at + timedelta(seconds=1))
        await room.pulse(q.issued_at + timedelta(seconds=1))
        reveal = (await room.question(i)).reveal_until
        assert reveal is not None
        await room.pulse(reveal)
    await room.lease.release(r)
    for _ in range(2):
        with api.websocket_connect(url(api, room)) as ws:
            initial = receive(ws)["data"]
            final = receive(ws)
            assert initial["live"]["phase"] == "finished" and len(initial["live"]["results_so_far"]) == 3
            assert final["type"] == "finished" and final["data"]["result"] == initial["duel"]["result"]
            assert final["data"]["result"]["xp_awarded"] == 15
            with pytest.raises(WebSocketDisconnect) as closed:
                receive(ws)
            assert closed.value.code == 1000


async def test_expired_challenge_flushes_state_to_open_socket(world: tuple[TestClient, Resources]) -> None:
    api, r = world
    room = await fresh_room(r)
    clock = [room.start]
    api.app.state.live_manager.clock = lambda: clock[0]
    with api.websocket_connect(url(api, room)) as ws:
        receive(ws)
        clock[0] += timedelta(seconds=121)
        while True:
            result = receive(ws)
            if result["type"] == "state" and result["data"]["duel"]["status"] == "expired":
                break
        with pytest.raises(WebSocketDisconnect) as closed:
            receive(ws)
        assert closed.value.code == 1000


@pytest.mark.parametrize("blocked_lock", [False, True])
async def test_deletion_revokes_socket_authentication(world: tuple[TestClient, Resources],
                                                     monkeypatch: pytest.MonkeyPatch, blocked_lock: bool) -> None:
    api, r = world
    room = await fresh_room(r)
    waiting, released = threading.Event(), asyncio.Event()
    original = live.authorize
    calls = 0

    async def authorize(*args: Any, **kwargs: Any) -> Any:
        nonlocal calls
        calls += 1
        # Open and initial projection are calls 1/2; pause the journal reader after its principal lookup.
        if calls == 3:
            waiting.set()
            await asyncio.wait_for(released.wait(), 8)
        return await original(*args, **kwargs)

    if blocked_lock:
        monkeypatch.setattr(live, "authorize", authorize)
    with api.websocket_connect(url(api, room)) as ws:
        receive(ws)
        try:
            if blocked_lock:
                assert await asyncio.to_thread(waiting.wait, 5)
            assert api.delete("/v1/me", headers=room.headers[0]).status_code == 204
        finally:
            api.portal.call(released.set)
        ws.send_json({"type": "ping", "data": {}})
        assert until(ws, "error")["code"] == "unauthorized"
        with pytest.raises(WebSocketDisconnect) as closed:
            receive(ws)
        assert closed.value.code == 1008


async def test_slow_consumer_has_bounded_delivery_and_can_reconnect(world: tuple[TestClient, Resources],
                                                                 monkeypatch: pytest.MonkeyPatch) -> None:
    from starlette.websockets import WebSocket

    api, r = world
    room = await fresh_room(r)
    r_api = api.app.state.resources
    monkeypatch.setattr(r_api.settings, "live_ws_send_timeout_seconds", 0.05)
    original = WebSocket.send_json

    async def slow(self: WebSocket, data: Any, mode: str = "text") -> None:
        if data.get("type") == "pong":
            await asyncio.sleep(1)
        await original(self, data, mode)

    with monkeypatch.context() as m:
        m.setattr(WebSocket, "send_json", slow)
        with api.websocket_connect(url(api, room)) as ws:
            receive(ws)
            ws.send_json({"type": "ping", "data": {}})
            with pytest.raises(WebSocketDisconnect) as closed:
                for _ in range(40):
                    receive(ws)  # committed lobby events may already be queued before the slow pong
            assert closed.value.code == 1013
    with api.websocket_connect(url(api, room)) as ws:
        assert receive(ws)["type"] == "state"


async def test_multiple_devices_cannot_bypass_connection_limit(world: tuple[TestClient, Resources]) -> None:
    api, r = world
    room = await fresh_room(r)
    with ExitStack() as devices:
        for _ in range(r.settings.live_ws_max_connections):
            ws = devices.enter_context(api.websocket_connect(url(api, room)))
            assert receive(ws)["type"] == "state"
        with pytest.raises(WebSocketDenialResponse) as denied, api.websocket_connect(url(api, room)):
            pass
        assert denied.value.status_code == 429


async def test_idle_socket_closes_without_resetting_game(world: tuple[TestClient, Resources]) -> None:
    api, r = world
    room = await fresh_room(r)
    with api.websocket_connect(url(api, room)) as ws:
        receive(ws)
        with pytest.raises(WebSocketDisconnect) as closed:
            for _ in range(40):
                receive(ws, 35)
        assert closed.value.code == 1000
    assert (await room.status()).phase is None
    with api.websocket_connect(url(api, room)) as ws:
        assert receive(ws)["data"]["duel"]["duel_id"] == room.duel_id
