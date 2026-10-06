from __future__ import annotations

from dataclasses import replace

import pytest
from sqlalchemy import func, select

from app.models import RaqeebMemory, RaqeebMessage
from app.raqeeb import memory, worker
from app.services.platform import deletion
from app.sources.errors import RecordNotFound, UpstreamUnavailable
from app.workers.tasks_embeddings import store_embedding
from tests.raqeeb.support import Tools, model
from tests.raqeeb.test_api_worker import guest, send, start

pytestmark = pytest.mark.integration


class Embedder:
    async def encode(self, texts):
        return [[1.0] + [0.0] * 1023 for _ in texts]


async def test_empty_memory_namespace_does_not_depend_on_an_embedding_worker(api, resources):
    class AbsentWorker:
        async def encode(self, texts):
            raise AssertionError("an empty memory must not enqueue an embedding call")

    headers = guest(api)
    aid = send(api, headers, start(api, headers)).json()["assistant_message"]["message_id"]
    gateway = memory.Gateway(resources, aid, embedder=AbsentWorker(), synthetic=True)
    assert await worker.process(resources, aid, client=script(), tools=Tools(), memory_gateway=gateway) == "completed"
    async with resources.sessionmaker() as db:
        assert (await db.get(RaqeebMessage, aid)).trace["memory"]["outcome"] == "miss"


def script(*, equivalent=True, private=False, standalone=True):
    client = model("general_knowledge")
    client.script["raqeeb_classify"]["standalone"] = standalone
    client.script |= {"raqeeb_equivalence": {"same_question": equivalent, "reason": "Synthetic decision"},
        "raqeeb_memory_safe": {"depersonalised": not private, "contains_private_details": private}}
    return client


async def answer(api, resources, headers, tools, client, *, synthetic=True, expected="completed"):
    aid = send(api, headers, start(api, headers)).json()["assistant_message"]["message_id"]
    gateway = memory.Gateway(resources, aid, embedder=Embedder(), synthetic=synthetic)
    outcome = await worker.process(resources, aid, client=client, tools=tools, memory_gateway=gateway)
    async with resources.sessionmaker() as db:
        failed = (await db.get(RaqeebMessage, aid)).trace.get("failure")
    assert outcome == expected, failed
    return aid


async def test_native_vector_reuse_fresh_sources_fenced_hits_and_replay(api, resources):
    headers, tools = guest(api), Tools()
    first = await answer(api, resources, headers, tools, script())
    async with resources.sessionmaker() as db:
        stored = (await db.execute(select(RaqeebMemory))).scalar_one()
        mid = stored.id
        assert stored.origin_message_id == first and stored.embedding is None
        assert "question" not in stored.core and stored.canonical_question == "Neutral example"
    assert await store_embedding(resources, mid, Embedder()) == "stored"
    assert await store_embedding(resources, mid, Embedder()) == "existing"
    client = script()
    second = await answer(api, resources, headers, tools, client)
    assert any(c[0] == "resolve" for c in tools.calls)
    assert not any(c[0] == "raqeeb_write" for c in client.calls)
    assert await worker.process(resources, second, client=client, tools=tools) == "ignored"
    async with resources.sessionmaker() as db:
        assert (await db.get(RaqeebMemory, mid)).hits == 1
        assert (await db.get(RaqeebMessage, second)).trace["memory"]["outcome"] == "reused"
        assert await db.scalar(select(func.count()).select_from(RaqeebMemory)) == 1


@pytest.mark.parametrize("reason", ["different_question", "changed_text", "changed_attribution", "outage", "missing"])
async def test_similar_is_not_equivalent_and_source_changes_or_outages_never_reuse(api, resources, reason):
    headers, tools = guest(api), Tools()
    await answer(api, resources, headers, tools, script())
    async with resources.sessionmaker() as db:
        mid = (await db.execute(select(RaqeebMemory.id))).scalar_one()
    await store_embedding(resources, mid, Embedder())
    if reason == "changed_text":
        tools.articles = [replace(r, text="Changed neutral material") for r in tools.articles]
    if reason == "changed_attribution":
        tools.articles = [replace(r, reference="A different attribution") for r in tools.articles]
    if reason == "outage":
        tools.error = UpstreamUnavailable("islamhouse", "Synthetic outage")
    if reason == "missing":
        tools.error = RecordNotFound("islamhouse", "Synthetic removed source")
    client = script(equivalent=reason != "different_question")
    aid = await answer(api, resources, headers, tools, client,
                       expected="failed" if reason.startswith("changed_") else "completed")
    async with resources.sessionmaker() as db:
        stored = await db.get(RaqeebMemory, mid)
        assert stored.hits == 0
        assert (await db.get(RaqeebMessage, aid)).trace.get("memory", {}).get("outcome") != "reused"
        if reason.startswith("changed_") or reason == "missing":
            from app.services.platform.auth_sessions import utcnow
            assert stored.expires_at <= utcnow()
        if reason == "outage":
            from app.services.platform.auth_sessions import utcnow
            assert stored.expires_at > utcnow()


@pytest.mark.parametrize("reason", ["pending_cache_terms", "private", "dependent"])
async def test_pending_provider_terms_personalised_or_dependent_answers_are_not_cached(api, resources, reason):
    await answer(api, resources, guest(api), Tools(), script(private=reason == "private",
        standalone=reason != "dependent"), synthetic=reason != "pending_cache_terms")
    async with resources.sessionmaker() as db:
        assert await db.scalar(select(func.count()).select_from(RaqeebMemory)) == 0


async def test_memory_purge_after_account_deletion_and_backup_repurge(api, resources):
    headers = guest(api)
    await answer(api, resources, headers, Tools(), script())
    async with resources.sessionmaker() as db:
        uid = (await db.execute(select(RaqeebMemory.origin_user_id))).scalar_one()
    assert api.delete("/v1/me", headers=headers).status_code == 204
    async with resources.sessionmaker() as db, db.begin():
        await deletion.purge_user(db, resources.storage, uid)
        await deletion.purge_user(db, resources.storage, uid)
        assert await db.scalar(select(func.count()).select_from(RaqeebMemory)) == 0
