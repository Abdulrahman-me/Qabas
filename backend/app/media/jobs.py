"""Serialize media work across workers and replay durable, digest-bound receipts after a crash.

Only the media job's advisory transaction lock is held; no learner/run row lock spans provider calls.
Private checkpoints survive a failed DB commit. Public objects are written only during reviewed promotion.
"""

from __future__ import annotations

import json
from collections.abc import Awaitable, Callable
from dataclasses import asdict
from typing import Any

from sqlalchemy import text

from app.content.package import content_digest
from app.factory.orchestrator import StageContext
from app.llm.budget import UsageRecord
from app.media import objects
from app.media.errors import MediaInvalid
from app.media.objects import encode
from app.models.media import MediaJob
from app.services.platform.storage import Bucket, ObjectStorage


async def once(
    ctx: StageContext,
    storage: ObjectStorage,
    name: str,
    inputs: dict[str, Any],
    execute: Callable[[], Awaitable[dict[str, Any]]],
) -> dict[str, Any]:
    fingerprint = content_digest(inputs)
    key = content_digest({"run": ctx.run.id, "name": name, "inputs": fingerprint})
    lock = int(key[:16], 16) - (1 << 63)
    checkpoint = f"factory/{ctx.run.id}/checkpoints/{key}.json"
    async with ctx.sessionmaker() as db, db.begin():
        await db.execute(text("SELECT pg_advisory_xact_lock(:key)"), {"key": lock})
        row = await db.get(MediaJob, key)
        if row is not None:
            if row.input_sha256 != fingerprint or content_digest(row.output) != row.output_sha256:
                raise MediaInvalid("stored media job identity changed")
            output = dict(row.output)
            _recover_spend(ctx, output)
            return output
        if await objects.io(storage.exists, Bucket.private, checkpoint):
            saved = json.loads(await objects.io(storage.get, Bucket.private, checkpoint))
            if saved["inputs"] != fingerprint or content_digest(saved["output"]) != saved["digest"]:
                raise MediaInvalid("media checkpoint identity changed")
            output = saved["output"]
        else:
            before = len(ctx.ledger.records)
            output = await execute()
            output = {**output, "_model_calls": [asdict(call) for call in ctx.ledger.records[before:]]}
            saved = {"inputs": fingerprint, "digest": content_digest(output), "output": output}
            await objects.io(
                storage.put_immutable, Bucket.private, checkpoint, encode(saved), "application/json"
            )
        db.add(
            MediaJob(
                id=key, run_id=ctx.run.id, input_sha256=fingerprint, output_sha256=content_digest(output), output=output
            )
        )
        _recover_spend(ctx, output)
        return dict(output)


def _recover_spend(ctx: StageContext, output: dict[str, Any]) -> None:
    existing = {content_digest(asdict(call)) for call in ctx.ledger.records}
    for call in output.get("_model_calls", []):
        if content_digest(call) not in existing:
            ctx.ledger.charge(UsageRecord(**call))
            existing.add(content_digest(call))
