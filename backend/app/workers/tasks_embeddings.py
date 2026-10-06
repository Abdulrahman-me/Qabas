"""Dedicated CPU embeddings queue. Broker arguments contain IDs, not learner questions/files."""
from __future__ import annotations

from sqlalchemy import select

from app.models import RaqeebMemory, RaqeebMessage
from app.raqeeb import intake, memory, suggestions
from app.runtime import Resources
from app.services.platform.auth_sessions import utcnow
from app.sources.errors import ProviderNotConfigured
from app.workers.celery_app import celery_app
from app.workers.tasks_maintenance import run_with_resources


async def encode_question(resources: Resources, message_id: str) -> list[float]:
    async with resources.sessionmaker() as db:
        row = await db.get(RaqeebMessage, message_id)
        if row is None or row.status != "processing":
            raise ProviderNotConfigured("bge_m3", "question is no longer processing")
        classified = row.trace.get("classification", {})
        question = classified.get("canonical_question", "")
        if not classified.get("standalone") or classified.get("question_class") not in (
                "general_knowledge", "text_explanation") or not 1 <= len(question) <= 2000:
            raise ProviderNotConfigured("bge_m3", "question is not eligible for memory")
    return memory.vector((await suggestions.LocalBge(resources.settings).encode([question]))[0])


async def store_embedding(resources: Resources, memory_id: str,
                          embedder: suggestions.Embedder | None = None) -> str:
    async with resources.sessionmaker() as db:
        row = await db.get(RaqeebMemory, memory_id)
        if row is None or row.expires_at <= utcnow():
            return "expired"
        if row.embedding is not None:
            return "existing"
        question, version = row.canonical_question, (row.policy_version, row.prompt_version)
    embedding = memory.vector((await (embedder or suggestions.LocalBge(resources.settings)).encode([question]))[0])
    async with resources.sessionmaker() as db, db.begin():
        row = (await db.execute(select(RaqeebMemory).where(RaqeebMemory.id == memory_id)
                               .with_for_update())).scalar_one_or_none()
        if row is None or row.expires_at <= utcnow() or version != memory.versions(resources) or \
                (row.policy_version, row.prompt_version) != version:
            return "expired"
        if row.embedding is None:
            row.embedding = embedding
        return "stored"


@celery_app.task(name="embeddings.question", expires=60)
def question(message_id: str) -> list[float]:
    return run_with_resources(lambda r: encode_question(r, message_id))


@celery_app.task(name="embeddings.store", autoretry_for=(OSError,), retry_backoff=True, max_retries=2)
def store(memory_id: str) -> str:
    return run_with_resources(lambda r: store_embedding(r, memory_id))


@celery_app.task(name="maintenance.raqeeb_private_cleanup")
def cleanup() -> dict[str, int]:
    async def job(r: Resources) -> dict[str, int]:
        return {"uploads": await intake.sweep(r), "memory": await memory.purge_expired(r)}
    return run_with_resources(job)
