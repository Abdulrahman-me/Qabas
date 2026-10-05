"""PostgreSQL arbitration, unchanged provenance on replay, and transactional rollback."""

import asyncio
from dataclasses import replace

import pytest
from sqlalchemy import func, select

from app.models import Source
from app.runtime import Resources
from app.sources.errors import SourceChanged
from app.sources.records import Part, Retrieval, SourceRecord, sha256_text, utcnow
from app.sources.store import persist

pytestmark = pytest.mark.integration


def record(text: str = "Neutral source text") -> SourceRecord:
    return SourceRecord("islamhouse", "fixture:1", "article", "Neutral title", "Neutral reference", text,
                        None, "test/1", Retrieval("fixture.get", "get", {"id": 1}, {"text": text},
                                                 sha256_text(text), utcnow()),
                        (Part("text_authority", "islamhouse", "fixture:1"),))


async def test_store_replay_preserves_original_metadata_and_changed_text_rejected(resources: Resources) -> None:
    original = record()
    async with resources.sessionmaker() as db, db.begin():
        first = await persist(db, original)
        identifier = first.id
    async with resources.sessionmaker() as db, db.begin():
        replay = await persist(db, replace(original, adapter_version="test/2", retrieval=replace(
            original.retrieval, retrieved_at=utcnow())))
        assert replay.id == identifier and replay.raw == original.raw() and replay.adapter_version == "test/1"
    with pytest.raises(SourceChanged):
        async with resources.sessionmaker() as db, db.begin():
            await persist(db, record("Changed neutral text"))
    async with resources.sessionmaker() as db:
        row = await db.get(Source, identifier)
        assert row is not None and row.excerpt == original.text and row.text_sha256 == original.text_sha256


@pytest.mark.parametrize("changed", [False, True])
async def test_concurrent_store_cannot_duplicate_or_overwrite(resources: Resources, changed: bool) -> None:
    async def write(value: SourceRecord) -> str:
        async with resources.sessionmaker() as db, db.begin():
            return (await persist(db, value)).id
    results = await asyncio.gather(write(record()), write(record("Different" if changed else "Neutral source text")),
                                   return_exceptions=True)
    assert sum(isinstance(item, SourceChanged) for item in results) == int(changed)
    assert all(isinstance(item, (str, SourceChanged)) for item in results)
    async with resources.sessionmaker() as db:
        assert (await db.execute(select(func.count()).select_from(Source))).scalar_one() == 1


async def test_source_and_caller_changes_roll_back_together(resources: Resources) -> None:
    with pytest.raises(ValueError, match="caller failed"):
        async with resources.sessionmaker() as db, db.begin():
            await persist(db, record())
            raise ValueError("caller failed")
    async with resources.sessionmaker() as db:
        assert (await db.execute(select(func.count()).select_from(Source))).scalar_one() == 0


async def test_grade_change_with_identical_text_requires_reverification(resources: Resources) -> None:
    original = replace(record(), data={"grade_label": "recorded ruling", "grader": "recorded grader"})
    async with resources.sessionmaker() as db, db.begin():
        await persist(db, original)
    changed = replace(original, data={**original.data, "grade_label": "changed ruling"})
    with pytest.raises(SourceChanged, match="attribution"):
        async with resources.sessionmaker() as db, db.begin():
            await persist(db, changed)
