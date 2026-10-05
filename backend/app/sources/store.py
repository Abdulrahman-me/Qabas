"""Insert cited records once. A changed provider text requires re-verification, never overwrite.

The caller owns the transaction. PostgreSQL's unique provider/record index arbitrates concurrent inserts;
the winner's original retrieval metadata remains immutable on replay.
"""

from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Source
from app.sources.errors import SourceChanged
from app.sources.records import SourceRecord, sha256_text


def source_id(record: SourceRecord) -> str:
    return "src_" + sha256_text(f"{record.provider}\0{record.provider_record_id}")[:32]


async def persist(db: AsyncSession, record: SourceRecord, *, id_: str | None = None) -> Source:
    identifier = id_ or source_id(record)
    values = {"id": identifier, "provider": record.provider, "provider_record_id": record.provider_record_id,
              "kind": record.kind, "title": record.title, "reference": record.reference, "excerpt": record.text,
              "url": record.url, "raw": record.raw(), "text_sha256": record.text_sha256,
              "retrieved_at": record.retrieved_at, "adapter_version": record.adapter_version}
    await db.execute(insert(Source).values(**values).on_conflict_do_nothing())
    row = (await db.execute(select(Source).where(Source.provider == record.provider,
                                                 Source.provider_record_id == record.provider_record_id)
                            .with_for_update())).scalar_one_or_none()
    if row is None:
        raise SourceChanged(record.provider, "source ID already belongs to a different provider record")
    if row.text_sha256 != record.text_sha256 or row.excerpt != record.text or row.kind != record.kind:
        raise SourceChanged(record.provider, f"record {record.provider_record_id} changed; re-verification required")
    if any(getattr(row, field) != getattr(record, field) for field in ("title", "reference", "url")):
        raise SourceChanged(record.provider, "citation metadata changed; re-verification required")
    critical = {"grade_label", "grade_category", "grader", "narrator", "book", "number_or_page",
                "grade_ar", "attribution_ar", "reference_ar", "translation_key", "translation_version", "language"}
    previous_data = row.raw.get("data", {})
    if any(previous_data.get(field) != record.data.get(field) for field in critical):
        raise SourceChanged(record.provider, "attribution or translation version changed; re-verification required")
    if id_ is not None and row.id != id_:
        raise SourceChanged(record.provider, "provider record is already bound to another source ID")
    return row


async def by_record(db: AsyncSession, provider: str, record_id: str) -> Source | None:
    return (await db.execute(select(Source).where(Source.provider == provider,
                                                  Source.provider_record_id == record_id))).scalar_one_or_none()
