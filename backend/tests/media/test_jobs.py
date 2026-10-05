from __future__ import annotations

import asyncio
from dataclasses import replace
from typing import Any

import pytest
from sqlalchemy import select, text
from sqlalchemy.exc import DBAPIError

from app.factory.orchestrator import RunSnapshot, StageContext
from app.factory.runs import create_run
from app.llm.budget import Ledger
from app.llm.fake import FakeLLMClient
from app.media import jobs, objects
from app.media.service import MediaService
from app.models import MediaJob, User
from app.runtime import Resources
from app.services.platform.storage import Bucket
from tests.factory.support import SLOT, reviewer
from tests.media.test_core import picture

pytestmark = pytest.mark.integration


async def context(resources: Resources) -> StageContext:
    who = await reviewer(resources)
    async with resources.sessionmaker() as db, db.begin():
        user = await db.get(User, who)
        assert user is not None
        run = await create_run(
            db, resources.settings, reviewer=user, lesson_id=SLOT, lesson_type="concept", brief="Synthetic media test"
        )
    return StageContext(
        RunSnapshot(run.id, run.unit_id, SLOT, 1, "concept", run.brief, "visuals", 1, None, {}, None, [], []),
        resources.settings,
        FakeLLMClient({}),
        Ledger(),
        resources.sessionmaker,
        {"media": MediaService(resources.storage)},
    )


@pytest.fixture
async def ctx(fresh_curriculum: Any) -> Any:
    resources = Resources.create(fresh_curriculum[1])
    try:
        yield await context(resources), resources
    finally:
        await resources.close()


async def test_concurrent_delivery_calls_provider_once_and_ready_jobs_are_insert_only(ctx: Any) -> None:
    context, resources = ctx
    calls = 0

    async def work() -> dict[str, Any]:
        nonlocal calls
        calls += 1
        await asyncio.sleep(0.02)
        return {"asset": "synthetic"}

    result = await asyncio.gather(
        *(jobs.once(context, resources.storage, "same", {"version": 1}, work) for _ in range(4))
    )
    assert calls == 1 and all(r == result[0] for r in result)
    async with resources.sessionmaker() as db:
        rows = list((await db.scalars(select(MediaJob))).all())
        assert len(rows) == 1
    async with resources.sessionmaker() as db:
        with pytest.raises(DBAPIError):
            await db.execute(text("UPDATE media_jobs SET output='{}'::jsonb"))
            await db.commit()
    async with resources.sessionmaker() as db:
        with pytest.raises(DBAPIError):
            await db.execute(text("DELETE FROM media_jobs"))
            await db.commit()


async def test_checkpoint_recovers_after_db_commit_failure_without_a_second_provider_call(
    ctx: Any, monkeypatch: Any
) -> None:
    context, resources = ctx
    calls = 0

    async def work() -> dict[str, Any]:
        nonlocal calls
        calls += 1
        return {"asset": "durable"}

    # Fail after object checkpoint creation but before the ORM insert/transaction commit.
    from sqlalchemy.ext.asyncio import AsyncSession

    real_add = AsyncSession.add

    def failed_add(self: AsyncSession, instance: Any, **kwargs: Any) -> None:
        if isinstance(instance, MediaJob):
            raise RuntimeError("synthetic DB failure")
        real_add(self, instance, **kwargs)

    monkeypatch.setattr(AsyncSession, "add", failed_add)
    with pytest.raises(RuntimeError, match="DB failure"):
        await jobs.once(context, resources.storage, "recover", {"version": 1}, work)
    monkeypatch.setattr(AsyncSession, "add", real_add)
    result = await jobs.once(context, resources.storage, "recover", {"version": 1}, work)
    assert result["asset"] == "durable" and calls == 1


async def test_changed_inputs_create_a_new_job_without_replacing_old_receipts(ctx: Any) -> None:
    context, resources = ctx

    async def work() -> dict[str, Any]:
        return {"asset": "synthetic"}

    await jobs.once(context, resources.storage, "asset", {"version": 1}, work)
    await jobs.once(context, resources.storage, "asset", {"version": 2}, work)
    async with resources.sessionmaker() as db:
        assert len(list((await db.scalars(select(MediaJob))).all())) == 2


@pytest.mark.parametrize("reported_pass", [False, True])
async def test_pixel_audit_is_real_and_limited_to_three_attempts(ctx: Any, reported_pass: bool) -> None:
    context, resources = ctx
    from app.media.types import GeneratedMedia

    class Images:
        calls = 0

        async def generate(self, **kwargs: Any) -> GeneratedMedia:
            self.calls += 1
            return GeneratedMedia(picture(), "image/webp", "fake", "fake-image")

    provider = Images()
    llm = FakeLLMClient(
        {
            "factory_image_prompt": {"prompt": "Neutral synthetic geometric artwork"},
            "factory_visual_audit": {"passed": reported_pass, "issues": ["Synthetic audit failure"]},
        }
    )
    media = MediaService(
        resources.storage,
        image_provider=provider,
        style={
            "identity": {"fixture": "neutral"},
            "guide": "Synthetic guide",
            "characters": "No people",
            "references": [],
        },
        image_terms={"licence": {"status": "approved", "approved_by": "test", "approved_on": "2026-01-01"}},
    )
    context = replace(context, llm=llm)
    first = await media.artwork(context, name="test", brief={}, content={}, width=1600, height=1000)
    assert first["attempts"] == 3 and not first["audit"]["passed"] and provider.calls == 3
    assert len([v for name, v in llm.vision_calls if name == "factory_visual_audit" and v]) == 3
    again = await media.artwork(context, name="test", brief={}, content={}, width=1600, height=1000)
    assert again == first and provider.calls == 3
    record = objects.MediaObject.model_validate(first["object"])
    assert not resources.storage.exists(Bucket.content, record.content_key)
    assert record.provenance["audit_image_sha256"] == record.sha256
