from __future__ import annotations

import asyncio
import uuid
from datetime import timedelta

import pytest
from sqlalchemy import func, select, text

from app.contract import models as C
from app.llm.errors import BudgetExceeded, LLMOutputInvalid, LLMRefusal, LLMTruncated, LLMUnavailable
from app.models import OutboxEvent, RaqeebConversation, RaqeebMessage, Source
from app.raqeeb import service, worker
from app.services.platform import deletion, outbox
from app.services.platform.auth_sessions import utcnow
from app.sources.errors import SourceChanged
from tests.raqeeb.support import Tools, model

pytestmark = pytest.mark.integration


async def test_existing_source_registry_identity_is_adopted_without_text_change(api, resources):
    from app.sources.store import persist
    from tests.raqeeb.support import record
    original = record()
    async with resources.sessionmaker() as db, db.begin():
        await persist(db, original, id_="src_existing_registry")
    headers = guest(api)
    aid = send(api, headers, start(api, headers)).json()["assistant_message"]["message_id"]
    assert await worker.process(resources, aid, client=model("general_knowledge"),
                                tools=Tools(articles=[original])) == "completed"
    completed = api.get(f"/v1/raqeeb/messages/{aid}", headers=headers).json()
    assert completed["citations"][0]["source"]["source_id"] == "src_existing_registry"
    assert completed["blocks"][0]["spans"][0]["text"] == original.text
    async with resources.sessionmaker() as db:
        assert await db.scalar(select(func.count()).select_from(Source)) == 1


def guest(api):
    result = api.post("/v1/auth/guest", json={"timezone": "Asia/Riyadh"})
    assert result.status_code == 201, result.text
    return {"Authorization": f"Bearer {result.json()['access_token']}", "Accept-Language": "en"}


def start(api, headers, *, context=None):
    response = api.post("/v1/raqeeb/conversations", json={"context": context}, headers=headers)
    assert response.status_code == 201, response.text
    C.Conversation.model_validate(response.json())
    return response.json()["conversation_id"]


def send(api, headers, conv, *, key=None, question="A neutral question"):
    return api.post(f"/v1/raqeeb/conversations/{conv}/messages", files={"text": (None, question)},
        headers=headers | {"Idempotency-Key": key or str(uuid.uuid4())})


async def test_accept_poll_complete_feedback_and_replay(api, resources):
    headers = guest(api)
    conv = start(api, headers)
    key = str(uuid.uuid4())
    accepted = send(api, headers, conv, key=key)
    assert accepted.status_code == 202, accepted.text
    C.PostMessageResp.model_validate(accepted.json())
    aid = accepted.json()["assistant_message"]["message_id"]
    processing = api.get(f"/v1/raqeeb/messages/{aid}", headers=headers).json()
    assert set(processing) == {"message_id", "role", "status", "stage", "created_at"}
    assert send(api, headers, conv).status_code == 409
    assert send(api, headers, conv, key=key).json() == accepted.json()
    assert send(api, headers, conv, key=key, question="Different").status_code == 409
    client = model("general_knowledge")
    assert await worker.process(resources, aid, client=client, tools=Tools()) == "completed"
    completed = api.get(f"/v1/raqeeb/messages/{aid}", headers=headers).json()
    C.RaqeebCompleted.model_validate(completed)
    assert not completed["abstained"]
    assert "trace" not in completed and "input_snapshot" not in completed
    calls = len(client.calls)
    assert await worker.process(resources, aid, client=client, tools=Tools()) == "ignored"
    assert len(client.calls) == calls
    assert send(api, headers, conv, key=key).json() == accepted.json()
    reply = api.post(f"/v1/raqeeb/messages/{aid}/feedback", headers=headers,
                     json={"rating": "down", "reason": "unclear", "comment": None})
    assert reply.status_code == 204
    detail = api.get(f"/v1/raqeeb/conversations/{conv}", headers=headers).json()
    C.ConvDetail.model_validate(detail)
    assert detail["conversation"]["title"] == "Learning example"
    assert [m["role"] for m in detail["messages"]] == ["user", "assistant"]
    assert detail["messages"][1]["feedback"] == "down"
    page = api.get("/v1/raqeeb/conversations", headers=headers).json()
    C.EXPORTED["ConversationPage"].model_validate(page)
    assert page["items"][0]["conversation_id"] == conv
    async with resources.sessionmaker() as db, db.begin():
        assert await db.scalar(select(func.count()).select_from(Source)) == 2
        assert await db.scalar(select(func.count()).select_from(OutboxEvent).where(
            OutboxEvent.kind == "raqeeb.completed")) == 1


async def test_two_workers_concurrent_do_not_duplicate_calls(api, resources):
    headers = guest(api)
    aid = send(api, headers, start(api, headers)).json()["assistant_message"]["message_id"]
    entered, release = asyncio.Event(), asyncio.Event()
    delegate = model("general_knowledge")

    class Paused:
        async def structured(self, *args, **kwargs):
            entered.set()
            await release.wait()
            return await delegate.structured(*args, **kwargs)

    first = asyncio.create_task(worker.process(resources, aid, client=Paused(), tools=Tools()))
    await asyncio.wait_for(entered.wait(), 10)
    assert await worker.process(resources, aid, client=delegate, tools=Tools()) == "busy"
    release.set()
    assert await first == "completed"
    assert len([p for p, _ in delegate.calls if p == "raqeeb_write"]) == 1


async def test_worker_crash_resumes_committed_calls(api, resources):
    headers = guest(api)
    aid = send(api, headers, start(api, headers)).json()["assistant_message"]["message_id"]
    delegate = model("general_knowledge")

    class Crash:
        async def structured(self, prompt, data, **kwargs):
            if prompt == "raqeeb_verify":
                raise asyncio.CancelledError
            return await delegate.structured(prompt, data, **kwargs)

    with pytest.raises(asyncio.CancelledError):
        await worker.process(resources, aid, client=Crash(), tools=Tools())
    assert await worker.process(resources, aid, client=delegate, tools=Tools()) == "completed"
    assert len([p for p, _ in delegate.calls if p == "raqeeb_classify"]) == 1


@pytest.mark.parametrize("error,code", [(LLMRefusal, "upstream_unavailable"),
    (LLMTruncated, "upstream_unavailable"), (LLMUnavailable, "upstream_unavailable"),
    (BudgetExceeded, "upstream_unavailable"), (LLMOutputInvalid, "internal_error")])
async def test_model_failures_terminate_typed(api, resources, error, code):
    headers = guest(api)
    aid = send(api, headers, start(api, headers)).json()["assistant_message"]["message_id"]

    class Broken:
        async def structured(self, *args, **kwargs):
            raise error("synthetic failure")

    assert await worker.process(resources, aid, client=Broken(), tools=Tools()) == "failed"
    result = api.get(f"/v1/raqeeb/messages/{aid}", headers=headers).json()
    C.AssistantFailed.model_validate(result)
    assert result["error"]["code"] == code and "synthetic failure" not in str(result)


async def test_token_budget_is_persisted_and_never_bypasses_guard(api, resources):
    headers = guest(api)
    aid = send(api, headers, start(api, headers)).json()["assistant_message"]["message_id"]
    resources.settings.raqeeb_budget_tokens = 1
    assert await worker.process(resources, aid, client=model("general_knowledge"), tools=Tools()) == "failed"
    async with resources.sessionmaker() as db:
        row = await db.get(RaqeebMessage, aid)
        assert row.trace["cost"]["tokens"]["total"] > 1
        assert row.trace["cost"]["calls"][0]["prompt_id"] == "raqeeb_classify"


async def test_deadline_poll_releases_slot_and_old_worker_cannot_finish(api, resources):
    headers = guest(api)
    conv = start(api, headers)
    aid = send(api, headers, conv).json()["assistant_message"]["message_id"]
    async with resources.sessionmaker() as db, db.begin():
        row = await db.get(RaqeebMessage, aid)
        row.created_at = utcnow() - timedelta(seconds=76)
    failed = api.get(f"/v1/raqeeb/messages/{aid}", headers=headers).json()
    assert failed["status"] == "failed" and failed["error"]["code"] == "upstream_unavailable"
    assert send(api, headers, conv).status_code == 202
    assert await worker.process(resources, aid, client=model("general_knowledge"), tools=Tools()) == "ignored"


async def test_stall_sweeper_fails_dead_worker_once(api, resources):
    headers = guest(api)
    aid = send(api, headers, start(api, headers)).json()["assistant_message"]["message_id"]
    async with resources.sessionmaker() as db, db.begin():
        row = await db.get(RaqeebMessage, aid)
        row.created_at = utcnow() - timedelta(seconds=91)
    assert await worker.sweep(resources) == 1
    assert await worker.sweep(resources) == 0
    assert api.get(f"/v1/raqeeb/messages/{aid}", headers=headers).json()["error"]["code"] == "internal_error"


async def test_source_change_rolls_back_all_completion_writes(api, resources, monkeypatch):
    headers = guest(api)
    aid = send(api, headers, start(api, headers)).json()["assistant_message"]["message_id"]
    real = worker.persist
    count = 0

    async def changed(db, record):
        nonlocal count
        count += 1
        if count == 2:
            raise SourceChanged("islamhouse", "changed")
        return await real(db, record)

    monkeypatch.setattr(worker, "persist", changed)
    assert await worker.process(resources, aid, client=model("general_knowledge"), tools=Tools()) == "failed"
    async with resources.sessionmaker() as db:
        assert await db.scalar(select(func.count()).select_from(Source)) == 0
        assert await db.scalar(select(func.count()).select_from(OutboxEvent).where(
            OutboxEvent.kind == "raqeeb.completed")) == 0


async def test_conversation_account_purge_and_no_resurrection(api, resources):
    headers = guest(api)
    uid = api.get("/v1/me", headers=headers).json()["user_id"]
    conv = start(api, headers)
    aid = send(api, headers, conv).json()["assistant_message"]["message_id"]
    assert api.delete("/v1/me", headers=headers).status_code == 204
    await outbox.relay(resources.sessionmaker)
    outcome = await worker.process(resources, aid, client=model("general_knowledge"), tools=Tools())
    assert outcome in ("deleted", "ignored")
    async with resources.sessionmaker() as db, db.begin():
        await deletion.purge_user(db, resources.storage, uid)
        assert await db.scalar(select(func.count()).select_from(RaqeebConversation)) == 0
        assert await db.scalar(select(func.count()).select_from(RaqeebMessage)) == 0


def test_cross_user_visibility_and_text_limits(api):
    one, two = guest(api), guest(api)
    conv = start(api, one)
    aid = send(api, one, conv).json()["assistant_message"]["message_id"]
    assert api.get(f"/v1/raqeeb/conversations/{conv}", headers=two).status_code == 404
    assert api.get(f"/v1/raqeeb/messages/{aid}", headers=two).status_code == 404
    assert send(api, two, conv).status_code == 404
    for question in ("", " " * 3, "x" * 2001):
        assert send(api, one, conv, question=question).status_code == 400
    response = api.post(f"/v1/raqeeb/conversations/{conv}/messages", files={"audio": ("x.mp3", b"x")},
                         headers=one | {"Idempotency-Key": str(uuid.uuid4())})
    assert response.status_code == 400


async def test_terminal_content_immutable_but_feedback_and_purge_allowed(api, resources):
    headers = guest(api)
    aid = send(api, headers, start(api, headers)).json()["assistant_message"]["message_id"]
    await worker.process(resources, aid, client=model("general_knowledge"), tools=Tools())
    from sqlalchemy.exc import DBAPIError
    async with resources.sessionmaker() as db:
        with pytest.raises(DBAPIError, match="terminal Raqeeb content is immutable"):
            async with db.begin():
                await db.execute(text("UPDATE raqeeb_messages SET blocks = '[]'::jsonb WHERE id=:id"), {"id": aid})


async def test_durable_dispatch_contains_only_message_id(api, resources, monkeypatch):
    headers = guest(api)
    aid = send(api, headers, start(api, headers)).json()["assistant_message"]["message_id"]
    from app.workers.celery_app import celery_app
    delivered = []
    monkeypatch.setattr(celery_app, "send_task", lambda *args, **kwargs: delivered.append((args, kwargs)))
    assert await outbox.relay(resources.sessionmaker) == 1
    assert delivered[0] == (("raqeeb.process_message",), {"args": [aid], "queue": "raqeeb"})
    assert delivered[1][0] == ("maintenance.expire_raqeeb_message",)
    assert delivered[1][1]["args"] == [aid] and 0 <= delivered[1][1]["countdown"] <= 75
    assert await outbox.relay(resources.sessionmaker) == 0


async def test_overall_timeout_cancels_provider_and_terminates(api, resources, monkeypatch):
    headers = guest(api)
    aid = send(api, headers, start(api, headers)).json()["assistant_message"]["message_id"]
    monkeypatch.setattr(service, "DEADLINE", .5)
    cancelled = asyncio.Event()

    class Slow:
        async def structured(self, *args, **kwargs):
            try:
                await asyncio.sleep(10)
            finally:
                cancelled.set()

    assert await worker.process(resources, aid, client=Slow(), tools=Tools()) == "failed"
    assert cancelled.is_set()
    assert api.get(f"/v1/raqeeb/messages/{aid}", headers=headers).json()["status"] == "failed"


async def test_optional_title_failure_preserves_safe_answer(api, resources):
    headers = guest(api)
    aid = send(api, headers, start(api, headers)).json()["assistant_message"]["message_id"]
    delegate = model("general_knowledge")

    class BrokenTitle:
        async def structured(self, prompt, data, **kwargs):
            if prompt == "conversation_title":
                raise LLMRefusal("no title")
            return await delegate.structured(prompt, data, **kwargs)

    assert await worker.process(resources, aid, client=BrokenTitle(), tools=Tools()) == "completed"
    assert api.get(f"/v1/raqeeb/messages/{aid}", headers=headers).json()["status"] == "completed"


async def test_concurrent_idempotent_uploads_only_accept_one_pair(api, resources):
    from concurrent.futures import ThreadPoolExecutor
    headers = guest(api)
    conv, key = start(api, headers), str(uuid.uuid4())
    with ThreadPoolExecutor(max_workers=2) as executor:
        responses = list(executor.map(lambda _: send(api, headers, conv, key=key), range(2)))
    assert [r.status_code for r in responses] == [202, 202]
    assert responses[0].json() == responses[1].json()
    async with resources.sessionmaker() as db:
        assert await db.scalar(select(func.count()).select_from(RaqeebMessage)) == 2


async def test_rate_limit_counts_new_messages_but_not_replays(api, resources):
    headers = guest(api)
    conv, key = start(api, headers), str(uuid.uuid4())
    first = None
    for i in range(5):
        response = send(api, headers, conv, key=key if i == 0 else None)
        assert response.status_code == 202, response.text
        first = first or response
        aid = response.json()["assistant_message"]["message_id"]
        assert await worker.process(resources, aid, client=model("out_of_scope"), tools=Tools()) == "completed"
    assert send(api, headers, conv).status_code == 429
    assert send(api, headers, conv, key=key).json() == first.json()


async def test_safety_path_works_without_secrets_or_source_dataset(api, resources):
    headers = guest(api)
    response = send(api, headers, start(api, headers), question="I want to kill myself")
    aid = response.json()["assistant_message"]["message_id"]
    resources.settings.anthropic_api_key = None
    resources.settings.raqeeb_embedding_model_dir = None
    assert await worker.process(resources, aid) == "completed"
    result = api.get(f"/v1/raqeeb/messages/{aid}", headers=headers).json()
    assert result["classification"]["question_class"] == "sensitive_human"


def test_conversation_cursor_is_opaque_and_stable(api):
    headers = guest(api)
    for _ in range(3):
        start(api, headers)
    page = api.get("/v1/raqeeb/conversations?limit=2", headers=headers).json()
    cursor = page["next_cursor"]
    assert cursor
    second = api.get("/v1/raqeeb/conversations", params={"limit": 2, "cursor": cursor}, headers=headers).json()
    assert len(second["items"]) == 1
    assert not {r["conversation_id"] for r in page["items"]} & {r["conversation_id"] for r in second["items"]}
    assert api.get("/v1/raqeeb/conversations?cursor=malformed", headers=headers).status_code == 400
