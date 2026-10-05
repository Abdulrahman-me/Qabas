"""Idempotent, fenced Raqeeb tasks. No row locks across paid/provider calls; all completion writes are atomic."""

from __future__ import annotations

import asyncio
import copy
import uuid
from datetime import timedelta
from typing import Any

from sqlalchemy import select, text

from app.contract import models as C
from app.errors import ApiError
from app.factory.evidence import load_record
from app.llm.budget import Ledger, UsageRecord
from app.llm.client import LLMClient
from app.llm.errors import LLMError, LLMOutputInvalid, LLMRequestRejected, UnsafePromptData
from app.models import OutboxEvent, RaqeebConversation, RaqeebMessage
from app.raqeeb import level, pipeline, service, suggestions
from app.raqeeb.providers import HostedClient, LiveTools
from app.raqeeb.retrieval import Tools
from app.runtime import Resources
from app.services.platform import outbox
from app.services.platform.auth_sessions import utcnow
from app.services.users import iso
from app.sources.errors import SourceError
from app.sources.store import persist, source_id


class LostLease(Exception):
    pass


@outbox.consumer("raqeeb.requested")
async def dispatch(db: Any, event: OutboxEvent) -> None:
    from app.workers.celery_app import celery_app
    row = await db.get(RaqeebMessage, event.payload["message_id"])
    if row is not None and row.status == "processing":
        celery_app.send_task("raqeeb.process_message", args=[row.id], queue="raqeeb")
        remaining = max(0, (row.created_at + timedelta(seconds=service.DEADLINE) - utcnow()).total_seconds())
        celery_app.send_task("maintenance.expire_raqeeb_message", args=[row.id], queue="maintenance",
                             countdown=remaining)


@outbox.consumer("raqeeb.completed")
async def completed(db: Any, event: OutboxEvent) -> None:
    # Achievements recompute from immutable completed rows (D-77), not transient event counts (Phase 18).
    from app.services.community import achievements
    await achievements.refresh_for_event(db, event)


async def process(resources: Resources, message_id: str, *, client: LLMClient | None = None,
                  tools: Tools | None = None, embedder: suggestions.Embedder | None = None) -> str:
    lock_key = f"raqeeb:{message_id}"
    async with resources.engine.connect() as connection:
        acquired = await connection.scalar(text("SELECT pg_try_advisory_lock(hashtextextended(:k, 0))"),
                                           {"k": lock_key})
        await connection.commit()
        if not acquired:
            return "busy"
        try:
            return await _process(resources, message_id, client=client, tools=tools, embedder=embedder)
        finally:
            # A session lock must never be returned to the pool still held.
            try:
                await connection.execute(text("SELECT pg_advisory_unlock(hashtextextended(:k, 0))"), {"k": lock_key})
                await connection.commit()
            except BaseException:
                await connection.invalidate()
                raise


async def _process(resources: Resources, message_id: str, *, client: LLMClient | None, tools: Tools | None,
                   embedder: suggestions.Embedder | None) -> str:
    maker = resources.sessionmaker
    lease = uuid.uuid4()
    async with maker() as db, db.begin():
        candidate = await db.get(RaqeebMessage, message_id)
        if candidate is None or candidate.status != "processing":
            return "ignored"
        conv = await db.get(RaqeebConversation, candidate.conversation_id)
        assert conv is not None
        try:
            await service.active_user(db, conv.user_id)
        except ApiError:
            return "deleted"
        conv = await service.conversation(db, conv.user_id, conv.id, lock=True)
        row: RaqeebMessage | None = (await db.execute(select(RaqeebMessage).where(RaqeebMessage.id == message_id)
                               .with_for_update())).scalar_one()
        assert row is not None
        if row.status != "processing":
            return "ignored"
        if service.expire(row):
            return "expired"
        row.lease = lease
        original = await db.get(RaqeebMessage, row.reply_to)
        assert original is not None and original.text is not None
        question, snapshot, trace = original.text, copy.deepcopy(row.input_snapshot), copy.deepcopy(row.trace)
        created_at, conversation_id, user_id = row.created_at, conv.id, conv.user_id
        needs_title = conv.title is None
    deadline = created_at + timedelta(seconds=service.DEADLINE)
    ledger = Ledger(resources.settings.raqeeb_budget_tokens)
    for usage in trace.get("cost", {}).get("calls", []):
        ledger.records.append(UsageRecord(**{k: v for k, v in usage.items() if k != "cost_usd"}))

    async def checkpoint(current: dict[str, Any], *, stage: str | None = None) -> None:
        expired = False
        async with maker() as db, db.begin():
            row = (await db.execute(select(RaqeebMessage).where(RaqeebMessage.id == message_id)
                                   .with_for_update())).scalar_one_or_none()
            if row is None or row.status != "processing" or row.lease != lease:
                raise LostLease
            row.trace = copy.deepcopy(current)
            expired = service.expire(row)
            if not expired and stage is not None:
                row.stage = stage
                trace.setdefault("stages", []).append({"stage": stage, "at": iso(utcnow())})
        if expired:
            raise LostLease

    async def stage(name: str) -> None:
        await checkpoint(trace, stage=name)

    calls = pipeline.Calls(client or HostedClient(resources.settings), ledger, trace, checkpoint)
    sources = tools or LiveTools(resources.settings)
    title = None
    try:
        async with asyncio.timeout(max(0, (deadline - utcnow()).total_seconds())):
            answer = await pipeline.run(question, snapshot, calls, sources, stage)
            answer["blocks"], answer["terms"] = level.link(answer["blocks"], snapshot["cards"])
            if not answer["abstained"]:
                try:
                    async with asyncio.timeout(min(resources.settings.raqeeb_embedding_timeout_seconds,
                                                   max(.01, (deadline - utcnow()).total_seconds() - 1))):
                        async with maker() as db, db.begin():
                            answer["suggested_lessons"] = await suggestions.recommend(db, question,
                                snapshot["profile"]["track"], snapshot["profile"]["language"],
                                embedder or suggestions.LocalBge(resources.settings))
                except (SourceError, ValueError, TimeoutError, OSError) as exc:
                    trace["suggestions"] = {"outcome": "unavailable", "type": type(exc).__name__}
            # Title failure is optional and must never turn an otherwise valid answer into a failure.
            remaining = (deadline - utcnow()).total_seconds() - 1
            if needs_title and remaining > 0:
                try:
                    async with asyncio.timeout(min(3, remaining)):
                        named = await calls("conversation_title", {
                            "question": trace.get("classification", {}).get("canonical_question", "Learning question"),
                            "language": snapshot["profile"]["language"]})
                        title = named["title"] if len(named["title"].split()) <= 6 else None
                except (LLMError, TimeoutError):
                    pass
            completed_at = utcnow()
            wire = {"message_id": message_id, "role": "assistant", "status": "completed", "stage": "done",
                    "created_at": iso(created_at), "completed_at": iso(completed_at), **answer}
            C.RaqeebCompleted.model_validate(wire)
            async with maker() as db, db.begin():
                await service.active_user(db, user_id)
                conv = await service.conversation(db, user_id, conversation_id, lock=True)
                row = (await db.execute(select(RaqeebMessage).where(RaqeebMessage.id == message_id)
                                       .with_for_update())).scalar_one_or_none()
                if row is None or row.status != "processing" or row.lease != lease or utcnow() >= deadline:
                    raise LostLease
                used = {c["source"]["source_id"] for c in answer["citations"]}
                aliases = {}
                decoded_records = [load_record(record) for record in trace.get("retrieved", [])]
                for decoded in sorted(decoded_records, key=lambda r: (r.provider, r.provider_record_id)):
                    if source_id(decoded) in used:
                        stored = await persist(db, decoded)
                        aliases[source_id(decoded)] = stored.id
                # A gold import may already have assigned this identical provider record a registry ID.
                # Adopt that identity mechanically; never duplicate a provider record or alter its text.
                def rebind(node: Any) -> Any:
                    if isinstance(node, dict):
                        return {k: aliases.get(v, v) if k in ("source_id", "evidence_id") and isinstance(v, str)
                                else [aliases.get(s, s) for s in v] if k == "source_ids" and isinstance(v, list)
                                else rebind(v) for k, v in node.items()}
                    if isinstance(node, list):
                        return [rebind(v) for v in node]
                    return node
                answer = rebind(answer)
                C.RaqeebCompleted.model_validate(wire | answer)
                trace["source_registry_ids"] = aliases
                for key, value in answer.items():
                    setattr(row, key, value)
                row.status, row.stage, row.completed_at, row.lease = "completed", "done", completed_at, None
                row.trace = trace
                conv.updated_at = completed_at
                if conv.title is None and title:
                    conv.title = title
                await outbox.enqueue(db, event_key=f"raqeeb:{message_id}:completed", kind="raqeeb.completed",
                                     payload={"message_id": message_id, "user_id": user_id})
            return "completed"
    except LostLease:
        return "superseded"
    except ApiError:
        return "deleted"
    except Exception as exc:
        code = "upstream_unavailable" if isinstance(exc, (LLMError, SourceError, TimeoutError)) else "internal_error"
        if isinstance(exc, (LLMOutputInvalid, LLMRequestRejected, UnsafePromptData)):
            code = "internal_error"
        async with maker() as db, db.begin():
            row = (await db.execute(select(RaqeebMessage).where(RaqeebMessage.id == message_id)
                                   .with_for_update())).scalar_one_or_none()
            if row is not None and row.status == "processing" and row.lease == lease:
                row.trace = trace | {"failure": {"type": type(exc).__name__, "code": code}, "cost": ledger.summary()}
                row.status, row.lease = "failed", None
                row.error = {"code": code, "message": "The answer could not be completed safely. Please try again."}
        return "failed"
    finally:
        await sources.aclose()


async def sweep(resources: Resources) -> int:
    async with resources.sessionmaker() as db, db.begin():
        rows = (await db.execute(select(RaqeebMessage).where(RaqeebMessage.status == "processing",
            RaqeebMessage.created_at <= utcnow() - timedelta(seconds=service.STALL))
            .with_for_update(skip_locked=True))).scalars()
        return sum(service.expire(r, seconds=service.STALL, code="internal_error") for r in rows)


async def expire_deadline(resources: Resources, message_id: str) -> bool:
    async with resources.sessionmaker() as db, db.begin():
        row = (await db.execute(select(RaqeebMessage).where(RaqeebMessage.id == message_id)
                               .with_for_update())).scalar_one_or_none()
        return service.expire(row) if row else False
