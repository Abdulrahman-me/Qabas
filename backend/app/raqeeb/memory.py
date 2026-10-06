"""Derived memory: cosine is discovery only; fresh sources and equivalence remain mandatory."""
from __future__ import annotations

import copy
import math
import uuid
from datetime import timedelta
from typing import Any

from sqlalchemy import Float, delete, select, update
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import BACKEND_DIR, Environment
from app.factory.evidence import dump_record, load_record
from app.llm.prompts import get_prompt
from app.models import RaqeebMemory, RaqeebMessage
from app.raqeeb import pipeline, source_checks
from app.raqeeb import schemas as S
from app.raqeeb.retrieval import Pool, Tools
from app.raqeeb.suggestions import Embedder
from app.runtime import Resources
from app.services.platform.auth_sessions import utcnow
from app.sources.errors import RecordNotFound, SourceError
from app.sources.policy import load_policies
from app.sources.records import SourceRecord, canonical_json, sha256_text
from app.sources.store import source_id


def versions(resources: Resources) -> tuple[str, str]:
    settings = resources.settings
    policy = sha256_text(canonical_json({name: (BACKEND_DIR / "content" / name).read_text(encoding="utf-8")
        for name in ("safety_rules.yaml", "referrals.yaml", "sources/translations.yaml", "sources/mushaf.yaml")}))
    # Registered prompt identities include schema hashes; a policy/model/source configuration change expires reuse.
    prompts = {name: get_prompt(name).identity() for name in
               ("raqeeb_classify", "raqeeb_verify", "raqeeb_write", "raqeeb_guard", "raqeeb_equivalence",
                "raqeeb_memory_safe", "raqeeb_rewrite", "raqeeb_rewrite_check")}
    adapter_code = {p.relative_to(BACKEND_DIR).as_posix(): sha256_text(p.read_text(encoding="utf-8"))
                    for p in sorted((BACKEND_DIR / "app" / "sources").rglob("*.py"))}
    manifest = settings.raqeeb_embedding_model_dir / "qabas-model.yaml" \
        if settings.raqeeb_embedding_model_dir else None
    digest = sha256_text(canonical_json({"prompts": prompts, "strong": settings.llm_model_strong,
        "adapters": adapter_code, "embedding_revision": sha256_text(manifest.read_text(encoding="utf-8"))
            if manifest and manifest.is_file() else "pending",
        "fast": settings.llm_model_fast,
        "sources": {k: p.model_dump(mode="json") for k, p in load_policies().items()}}))
    return policy, digest


def cache_seconds(records: list[SourceRecord], resources: Resources) -> int:
    """A semantic answer is also a source cache. Pending cache terms cannot be bypassed (D-91)."""
    policies = load_policies()
    ttls = [resources.settings.raqeeb_memory_ttl_days * 86400]
    if not records:
        return 0
    for record in records:
        for provider in {record.provider, *(p.provider for p in record.parts if p.role in
                        ("text_authority", "translation", "explanation", "grade"))}:
            permission = policies.get(provider)
            if permission is None or permission.cache_ttl_seconds <= 0:
                return 0
            ttls.append(permission.cache_ttl_seconds)
    return min(ttls)


def vector(value: list[float]) -> list[float]:
    if len(value) != 1024 or any(isinstance(v, bool) or not math.isfinite(v) for v in value) or \
            sum(v * v for v in value) == 0:
        raise ValueError("invalid bge-m3 vector")
    return value


class Gateway:
    def __init__(self, resources: Resources, message_id: str, *, embedder: Embedder | None = None,
                 namespace: uuid.UUID | None = None, synthetic: bool = False) -> None:
        self.resources, self.message_id, self.embedder = resources, message_id, embedder
        self.namespace, self.synthetic = namespace, synthetic
        if synthetic and resources.settings.app_env not in (Environment.dev, Environment.test):
            raise ValueError("synthetic memory is test-only")

    @property
    def enabled(self) -> bool:
        return self.resources.settings.raqeeb_memory_enabled and (self.embedder is not None or
            self.resources.settings.raqeeb_embedding_model_dir is not None)

    async def encode(self, question: str, calls: pipeline.Calls) -> list[float]:
        if self.embedder is not None:
            return vector((await self.embedder.encode([question]))[0])
        # Only an opaque message ID crosses the broker; embeddings queue reads its committed canonical question.
        import asyncio

        from celery.exceptions import CeleryError

        from app.sources.errors import ProviderResponseInvalid
        from app.workers.celery_app import celery_app
        await calls.save(calls.trace)
        result = celery_app.send_task("embeddings.question", args=[self.message_id], queue="embeddings")
        try:
            answer = await asyncio.to_thread(result.get,
                timeout=self.resources.settings.raqeeb_embedding_timeout_seconds, disable_sync_subtasks=False)
            return vector(answer)
        except CeleryError:
            raise ProviderResponseInvalid("bge_m3", "embedding queue is unavailable") from None
        finally:
            result.forget()

    async def reuse(self, classified: S.Classified, calls: pipeline.Calls, tools: Tools,
                    profile: dict[str, Any], *, question: str | None = None,
                    history: list[dict[str, Any]] | None = None) -> tuple[dict[str, Any], Pool] | None:
        if not self.enabled or not 1 <= len(classified.canonical_question.strip()) <= 2000:
            return None
        policy, prompts = versions(self.resources)
        eligible = (RaqeebMemory.language == classified.language,
            RaqeebMemory.question_class == classified.question_class,
            RaqeebMemory.policy_version == policy, RaqeebMemory.prompt_version == prompts,
            RaqeebMemory.namespace == self.namespace, RaqeebMemory.expires_at > utcnow(),
            RaqeebMemory.embedding.is_not(None))
        async with self.resources.sessionmaker() as db:
            if await db.scalar(select(RaqeebMemory.id).where(*eligible).limit(1)) is None:
                calls.trace["memory"] = {"outcome": "miss"}
                return None  # an empty/expired namespace needs no embedding worker or queue timeout
        try:
            embedding = await self.encode(classified.canonical_question, calls)
        except (SourceError, ValueError, OSError, TimeoutError):
            calls.trace["memory"] = {"outcome": "embedding_unavailable"}
            return None
        async with self.resources.sessionmaker() as db:
            # Operators are qualified because pgvector deliberately lives outside the application's search_path.
            distance = RaqeebMemory.embedding.op("OPERATOR(extensions.<=>)", return_type=Float)(embedding)
            rows = list((await db.execute(select(RaqeebMemory).where(
                *eligible, distance <= .08).order_by(distance, RaqeebMemory.id).limit(3)
            )).scalars())
            for row in rows:
                origin = await db.get(RaqeebMessage, row.origin_message_id)
                if origin is None:
                    continue
                records = [load_record(r) for r in origin.trace.get("retrieved", [])
                           if source_id(load_record(r)) in row.source_digests]
                if not self.synthetic and cache_seconds(records, self.resources) <= 0:
                    continue
                pool, changed = Pool(), False
                try:
                    if len(records) != len(row.source_digests):
                        continue
                    for record in records:
                        resolved = await source_checks.fresh(record, tools, classified.language, pool)
                        changed |= source_checks.identity(resolved) != row.source_digests[source_id(record)]
                except RecordNotFound:
                    await db.execute(update(RaqeebMemory).where(RaqeebMemory.id == row.id)
                                     .values(expires_at=utcnow()))
                    await db.commit()
                    continue
                except SourceError:
                    # Outage is not evidence that the source changed and must never authorize reuse.
                    continue
                if changed:
                    await db.execute(update(RaqeebMemory).where(RaqeebMemory.id == row.id)
                                     .values(expires_at=utcnow()))
                    await db.commit()
                    continue
                equivalent = S.Equivalent.model_validate(await calls("raqeeb_equivalence", {
                    "stored_question": row.canonical_question,
                    "new_question": question or classified.canonical_question,
                    "canonical_question": classified.canonical_question, "history": history or []},
                    key=f"memory:{row.id}:equivalence"))
                if not equivalent.same_question:
                    continue
                core = copy.deepcopy(row.core)
                if pipeline.guard(core, pool, classified.question_class):
                    continue
                allowed = pipeline.support_sources(pool, classified.question_class)
                verification = S.Verified.model_validate(await calls("raqeeb_verify", {
                    "question": classified.canonical_question, "material": "", "sources": pool.sources(),
                    "verification": [], "candidate_answer": core}, key=f"memory:{row.id}:verify"))
                supported = [c.model_dump(mode="json") for c in verification.claims
                             if c.supported and c.source_ids and not set(c.source_ids) - allowed]
                if not supported:
                    continue
                core = await pipeline.adapt(core, calls, profile, key=f"memory:{row.id}")
                checked = S.Guarded.model_validate(await calls("raqeeb_guard", {
                    "question": classified.canonical_question, "material": "",
                    "question_class": classified.question_class, "answer": core,
                    "supported_claims": supported, "sources": pool.sources(), "verification": [],
                    "canonical_evidence": list(pool.evidence.values())}, key=f"memory:{row.id}:guard"))
                if checked.violations or pipeline.guard(core, pool, classified.question_class):
                    continue
                calls.trace["memory"] = {"outcome": "reused", "id": row.id}
                calls.trace["retrieved"] = [dump_record(r) for r in pool.records.values()]
                await calls.save(calls.trace)
                return core, pool
        calls.trace["memory"] = {"outcome": "miss"}
        return None

    async def prepare(self, calls: pipeline.Calls) -> dict[str, Any] | None:
        if not self.enabled or not calls.trace.get("memory_eligible"):
            return None
        classified = S.Classified.model_validate(calls.trace["classification"])
        core = calls.trace["core"]
        records = [load_record(r) for r in calls.trace.get("retrieved", [])]
        pool = Pool(records={source_id(r): r for r in records},
                    evidence=calls.trace.get("retrieval_checkpoint", {}).get("evidence", {}))
        ttl = self.resources.settings.raqeeb_memory_ttl_days * 86400 if self.synthetic else \
            cache_seconds(records, self.resources)
        if ttl <= 0 or pipeline.guard(core, pool, classified.question_class) or \
                not 1 <= len(classified.canonical_question.strip()) <= 2000:
            return None
        original_guard = S.Guarded.model_validate(await calls("raqeeb_guard", {
            "question": classified.canonical_question, "material": "", "question_class": classified.question_class,
            "answer": core, "supported_claims": calls.trace.get("verified", {}).get("claims", []),
            "sources": pool.sources(), "verification": [], "canonical_evidence": list(pool.evidence.values())},
            key="memory:original_core_guard"))
        if original_guard.violations:
            return None
        safe = S.MemorySafe.model_validate(await calls("raqeeb_memory_safe", {
            "canonical_question": classified.canonical_question, "core": core}))
        if not safe.depersonalised or safe.contains_private_details:
            return None
        policy, prompts = versions(self.resources)
        return {"id": "mem_" + sha256_text(self.message_id)[:24], "language": classified.language,
            "question_class": classified.question_class, "canonical_question": classified.canonical_question,
            "core": core, "source_digests": {source_id(r): source_checks.identity(r) for r in records},
            "evidence": pool.evidence, "policy_version": policy, "prompt_version": prompts,
            "namespace": self.namespace, "origin_message_id": self.message_id,
            "expires_at": utcnow() + timedelta(seconds=ttl)}

    async def commit(self, db: AsyncSession, trace: dict[str, Any], prepared: dict[str, Any] | None,
                     user_id: str) -> None:
        if trace.get("memory", {}).get("outcome") == "reused":
            await db.execute(update(RaqeebMemory).where(RaqeebMemory.id == trace["memory"]["id"])
                             .values(hits=RaqeebMemory.hits + 1))
        if prepared:
            await db.execute(insert(RaqeebMemory).values(**prepared, origin_user_id=user_id)
                             .on_conflict_do_nothing(index_elements=[RaqeebMemory.origin_message_id]))
            from app.services.platform import outbox
            await outbox.enqueue(db, event_key=f"memory:{self.message_id}", kind="raqeeb.memory_embedding",
                                 payload={"memory_id": prepared["id"]})


async def purge_expired(resources: Resources) -> int:
    policy, prompts = versions(resources)
    async with resources.sessionmaker() as db, db.begin():
        result = await db.execute(delete(RaqeebMemory).where(
            (RaqeebMemory.expires_at <= utcnow()) | (RaqeebMemory.policy_version != policy) |
            (RaqeebMemory.prompt_version != prompts)))
        return int(result.rowcount)  # type: ignore[attr-defined]
