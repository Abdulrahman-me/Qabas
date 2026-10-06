"""Production Raqeeb pipeline in an isolated benchmark database; no golden data enters its prompts."""
from __future__ import annotations

import base64
import mimetypes
import time
import uuid
from collections.abc import Callable
from pathlib import Path
from typing import Any
from urllib.parse import urlsplit

from sqlalchemy import func, select

from app.config import Environment
from app.errors import ApiError
from app.llm.batches import Request
from app.llm.budget import UsageRecord
from app.llm.client import LLMClient
from app.llm.errors import BudgetExceeded, LLMError
from app.llm.vision import VisionImage
from app.models import RaqeebMemory, RaqeebMessage, User
from app.raqeeb import inputs, intake, memory, service, worker
from app.raqeeb.providers import HostedClient, LiveTools
from app.raqeeb.retrieval import Tools
from app.raqeeb.suggestions import Embedder
from app.registries import default_avatar_key
from app.runtime import Resources
from app.sources.records import canonical_json, sha256_text
from app.workers.tasks_embeddings import store_embedding
from bench import audit
from bench.dataset import Case, attachment, input_digest


class Native:
    def __init__(self, resources: Resources, root: Path, *, synthetic: bool = False,
                 client_factory: Callable[[], LLMClient] | None = None,
                 tools_factory: Callable[[], Tools] | None = None, embedder: Embedder | None = None) -> None:
        self.resources, self.root = resources, root.resolve()
        self.synthetic = synthetic
        self.client_factory = client_factory or (lambda: HostedClient(resources.settings))
        self.tools_factory = tools_factory or (lambda: LiveTools(resources.settings))
        self.embedder = embedder
        if synthetic and resources.settings.app_env is not Environment.test:
            raise ValueError("native synthetic benchmark injection is test-only")
        if resources.settings.app_env not in (Environment.dev, Environment.test) or \
                (not synthetic and not urlsplit(resources.settings.database_url).path.startswith("/qabas_bench_")):
            raise ValueError("live benchmark needs a dedicated qabas_bench_* database in dev/test")

    def payload(self, case: Case) -> intake.Payload:
        uploads = []
        for name in case.attachments or []:
            path = attachment(self.root, name)
            mime = {".m4a": "audio/mp4", ".wav": "audio/wav", ".webm": "audio/webm"}.get(path.suffix.lower()) or \
                mimetypes.guess_type(path.name)[0]
            kind = next((k for k, types in intake.MIMES.items() if mime in types), None)
            if kind is None:
                raise ValueError("private benchmark attachment has an unsupported type")
            if path.stat().st_size > (8 if kind == "image" else 10) * intake.MIB:
                from app.errors import ErrorCode
                raise ApiError(ErrorCode.payload_too_large, "Attachment exceeds its size limit.")
            uploads.append(intake.Upload(kind, path.name, str(mime), path.read_bytes()))
        if any(sum(u.kind == kind for u in uploads) > (3 if kind == "image" else 1)
               for kind in intake.MIMES):
            raise ValueError("too many private benchmark attachments")
        return intake.Payload(case.question or None, tuple(uploads))

    async def answer(self, case: Case, namespace: uuid.UUID, *,
                     remaining_tokens: int | None = None) -> dict[str, Any]:
        # Derived stable IDs make full worker/crash recovery available without duplicating paid calls.
        identifier = sha256_text(canonical_json({"namespace": str(namespace), "input": input_digest(case, self.root)}))
        uid, conv_id = "usr_" + identifier[:24], "conv_" + identifier[:24]
        aid = None
        usage: list[dict[str, Any]] = []
        started = time.monotonic()
        try:
            payload = self.payload(case)
            resources = self.resources
            async with resources.sessionmaker() as db, db.begin():
                user = await db.get(User, uid)
                if user is None:
                    user = User(id=uid, display_name="Private benchmark", avatar_key=default_avatar_key(),
                        language=case.language, track="explorer", timezone="Asia/Riyadh", is_synthetic=True)
                    db.add(user)
                    await db.flush()
                    _, created = await service.create(db, user, case.language, None)
                    from app.models import RaqeebConversation
                    conv = await db.get(RaqeebConversation, created["conversation_id"])
                    assert conv is not None
                    conv.id = conv_id
            # Dependent history is generated through the actual conversation pipeline, not a forged transcript.
            for index, turn in enumerate([*case.history, case.question]):
                async with resources.sessionmaker() as db:
                    rows = list((await db.execute(select(RaqeebMessage).where(
                        RaqeebMessage.conversation_id == conv_id, RaqeebMessage.role == "assistant")
                        .order_by(RaqeebMessage.created_at))).scalars())
                if len(rows) > index:
                    aid = rows[index].id
                else:
                    uploads = payload.uploads if index == len(case.history) else ()
                    receipt_ids = await intake.prepare(resources, uid, f"{identifier}:{index}",
                        sha256_text(canonical_json([u.identity() for u in uploads])), uploads)
                    async def no_rate_limit() -> None:
                        pass
                    async with resources.sessionmaker() as db, db.begin():
                        user = await db.get(User, uid)
                        assert user is not None
                        _, response = await service.submit(db, user, conv_id, turn or None, no_rate_limit,
                            attachment_ids=receipt_ids, settings=resources.settings)
                        aid = response["assistant_message"]["message_id"]
                assert aid is not None
                remaining = None if remaining_tokens is None else remaining_tokens - sum(
                    UsageRecord(**{k: v for k, v in raw.items() if k != "cost_usd"}).tokens for raw in usage)
                if remaining is not None and remaining <= 0:
                    raise BudgetExceeded("evaluation budget spent before the next dependent turn")
                client = self.client_factory()
                try:
                    await worker.process(resources, aid, client=client, tools=self.tools_factory(),
                        memory_gateway=memory.Gateway(resources, aid, namespace=namespace,
                                                     synthetic=self.synthetic, embedder=self.embedder),
                        budget_tokens=remaining)
                finally:
                    close = getattr(client, "aclose", None)
                    if close is not None:
                        await close()
                async with resources.sessionmaker() as db:
                    turn_row = await db.get(RaqeebMessage, aid)
                    assert turn_row is not None
                    usage.extend(turn_row.trace.get("cost", {}).get("calls", []))
            async with resources.sessionmaker() as db:
                row = await db.get(RaqeebMessage, aid)
                assert row is not None
                prior_rows = list((await db.execute(select(RaqeebMessage).where(
                    RaqeebMessage.conversation_id == conv_id, RaqeebMessage.role == "assistant")
                    .order_by(RaqeebMessage.created_at))).scalars())[:len(case.history)]
                history = [{"question": question, "answer": {k: v for k, v in
                    service.project_message(prior_row).items() if k in ("blocks", "citations", "classification",
                                                                       "abstained")}}
                    for question, prior_row in zip(case.history, prior_rows, strict=True)]
                costs = row.trace.get("cost", {})
                return {"answer": service.project_message(row), "error": row.error["code"] if row.error else None,
                    "latency_ms": round(((row.completed_at or row.created_at) - row.created_at).total_seconds() * 1000),
                    "cost_usd": None if row.trace.get("speech") else costs.get("usd"),
                    "reused": row.trace.get("memory", {}).get("outcome") == "reused", "usage": usage,
                    "history": history}
        except (ApiError, LLMError, inputs.InputUnreadable) as exc:
            return {"answer": {}, "error": exc.code.value if isinstance(exc, ApiError) else
                "input_unreadable" if isinstance(exc, inputs.InputUnreadable) else type(exc).__name__,
                "latency_ms": round((time.monotonic() - started) * 1000), "cost_usd": None,
                "reused": False, "usage": usage}

    async def baseline_request(self, case: Case, key: str) -> Request:
        payload = self.payload(case)
        question, material = case.question, []
        images: list[VisionImage] = []
        # Input capabilities are shared; the baseline receives no religious tools, retrieved sources or gold.
        for upload in payload.uploads:
            decoded = await inputs.decode(self.resources.settings, upload.kind, upload.mime, upload.data)
            if upload.kind == "audio":
                transcript = await inputs.HostedWhisper(self.resources.settings).transcribe(
                    base64.b64decode(decoded["wav"]), language_hint=case.language)
                question += "\n" + transcript.text
            else:
                material.append(decoded["text"])
                images.extend(VisionImage(base64.b64decode(i), "image/jpeg") for i in decoded["images"])
        return Request(key, "raqeeb_baseline", {"question": question, "material": "\n".join(material),
                       "history": case.history, "language": case.language}, tuple(images))

    async def audit(self, answer: dict[str, Any], case: Case, *,
                    system: str = "raqeeb") -> tuple[list[str], list[dict[str, Any]]]:
        tools = self.tools_factory()
        try:
            async with self.resources.sessionmaker() as db:
                return await audit.inspect(db, answer, tools, case.language, require_pipeline=system == "raqeeb")
        finally:
            await tools.aclose()

    async def warm(self, cases: list[Case], namespace: uuid.UUID, *,
                   already_answered: bool = False) -> dict[str, Any]:
        usage = []
        if not already_answered:
            for case in cases:
                result = await self.answer(case, namespace)
                usage.extend(result.get("usage", []))
        async with self.resources.sessionmaker() as db:
            ids = list((await db.execute(select(RaqeebMemory.id).where(RaqeebMemory.namespace == namespace))).scalars())
        for mid in ids:
            await store_embedding(self.resources, mid, self.embedder)
        async with self.resources.sessionmaker() as db:
            count = int(await db.scalar(select(func.count()).select_from(RaqeebMemory).where(
                RaqeebMemory.namespace == namespace, RaqeebMemory.embedding.is_not(None))) or 0)
            return {"count": count, "usage": usage}
