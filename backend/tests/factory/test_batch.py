"""Operator admission is bounded and replay-safe without approving or replacing content."""
from __future__ import annotations

import asyncio

import pytest
from pydantic import SecretStr
from sqlalchemy import func, select

from app.content.curriculum import load_curriculum
from app.content.store import apply_curriculum
from app.errors import ApiError
from app.factory import batch
from app.llm.errors import LLMNotConfigured
from app.models import FactoryRun, User
from app.runtime import Resources
from tests.factory.support import reviewer

pytestmark = pytest.mark.integration


async def test_inventory_covers_every_slot_without_writing(resources: Resources) -> None:
    curriculum = load_curriculum()
    async with resources.sessionmaker() as db, db.begin():
        await apply_curriculum(db, curriculum)
    async with resources.sessionmaker() as db:
        report = await batch.inventory(db, curriculum)
        assert report["totals"]["slots"] == 93
        assert report["totals"]["real_lessons"] == report["totals"]["factory_runs"] == 0
        assert {i["unit_id"] for i in report["slots"]} == {f"unit_{n}" for n in range(11)}
        assert all(i["registered"] and i["scaffold_only"] and not i["published"] for i in report["slots"])
        assert await db.scalar(select(func.count()).select_from(FactoryRun)) == 0


async def test_missing_provider_fails_before_admission(resources: Resources) -> None:
    curriculum = load_curriculum()
    async with resources.sessionmaker() as db, db.begin():
        await apply_curriculum(db, curriculum)
    rid = await reviewer(resources)
    async with resources.sessionmaker() as db, db.begin():
        user = await db.get(User, rid)
        assert user is not None
        with pytest.raises(LLMNotConfigured, match="ANTHROPIC_API_KEY"):
            await batch.admit(db, resources.settings, curriculum, reviewer=user,
                              unit_id="unit_0", lesson_type="concept")
        assert await db.scalar(select(func.count()).select_from(FactoryRun)) == 0


async def test_inactive_reviewer_cannot_admit_even_an_empty_batch(resources: Resources) -> None:
    curriculum = load_curriculum()
    rid = await reviewer(resources, active=False)
    async with resources.sessionmaker() as db, db.begin():
        user = await db.get(User, rid)
        assert user is not None
        with pytest.raises(ApiError, match="active reviewer"):
            await batch.admit(db, resources.settings, curriculum, reviewer=user,
                              unit_id="unit_0", lesson_type="concept")
        assert await db.scalar(select(func.count()).select_from(FactoryRun)) == 0


async def test_concurrent_batches_are_bounded_and_do_not_replace_existing_runs(resources: Resources) -> None:
    curriculum = load_curriculum()
    async with resources.sessionmaker() as db, db.begin():
        await apply_curriculum(db, curriculum)
    rid = await reviewer(resources)
    settings = resources.settings.model_copy(update={"anthropic_api_key": SecretStr("synthetic-test-credential")})

    async def enqueue() -> list[str]:
        async with resources.sessionmaker() as db, db.begin():
            user = await db.get(User, rid)
            assert user is not None
            created = await batch.admit(db, settings, curriculum, reviewer=user,
                                        unit_id="unit_0", lesson_type="concept", limit=4)
            assert all(r.stage == "plan" and r.review_digest is None and r.gate1_decision is None
                       and r.gate2_decision is None and r.published_version is None for r in created)
            return [r.id for r in created]

    admitted = await asyncio.gather(enqueue(), enqueue())
    assert sorted(map(len, admitted)) == [0, 4]
    assert await enqueue() == []
    async with resources.sessionmaker() as db:
        report = await batch.inventory(db, curriculum)
        assert report["totals"]["factory_runs"] == 4
        assert report["totals"]["published"] == report["totals"]["reviewed"] == 0
        assert sum(r["operator_status"] == "queued" for i in report["slots"] for r in i["runs"]) == 4


async def test_broker_failure_preserves_run_for_explicit_resume(resources: Resources, monkeypatch, capsys) -> None:
    from argparse import Namespace

    from scripts import curriculum_batch

    curriculum = load_curriculum()
    async with resources.sessionmaker() as db, db.begin():
        await apply_curriculum(db, curriculum)
    rid = await reviewer(resources)
    settings = resources.settings.model_copy(update={"anthropic_api_key": SecretStr("synthetic-test-credential")})
    monkeypatch.setattr(curriculum_batch, "get_settings", lambda: settings)

    class Dispatcher:
        def send(self, *args):
            raise RuntimeError("private-broker-credentials-must-not-be-printed")

    monkeypatch.setattr(curriculum_batch, "CeleryDispatcher", Dispatcher)
    assert await curriculum_batch.execute(Namespace(command="enqueue", unit="unit_0", reviewer_id=rid,
                                                     lesson_type="concept", limit=1)) == 2
    assert "private-broker-credentials" not in capsys.readouterr().err
    async with resources.sessionmaker() as db:
        run = (await db.execute(select(FactoryRun))).scalar_one()
        identifier = run.id
        assert run.stage == "plan" and run.status == "running" and run.gate1_decision is None
    delivered = []
    monkeypatch.setattr(Dispatcher, "send", lambda self, *args: delivered.append(args))
    assert await curriculum_batch.execute(Namespace(command="resume", run_id=identifier, reviewer_id=rid)) == 0
    assert delivered == [(identifier, "plan", 1)]
    async with resources.sessionmaker() as db:
        assert await db.scalar(select(func.count()).select_from(FactoryRun)) == 1
