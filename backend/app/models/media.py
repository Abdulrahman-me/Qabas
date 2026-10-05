"""Durable media receipts. Ready work and published media are insert-only, including provenance."""
from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import CheckConstraint, ForeignKey, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import SHA256_HEX, Base


class MediaJob(Base):
    __tablename__ = "media_jobs"
    __table_args__ = (
        CheckConstraint(f"id ~ '{SHA256_HEX}'", name="id_format"),
        CheckConstraint(f"input_sha256 ~ '{SHA256_HEX}' AND output_sha256 ~ '{SHA256_HEX}'", name="digests_format"),
    )
    id: Mapped[str] = mapped_column(Text, primary_key=True)
    run_id: Mapped[str] = mapped_column(ForeignKey("factory_runs.id"))
    input_sha256: Mapped[str] = mapped_column(Text)
    output_sha256: Mapped[str] = mapped_column(Text)
    output: Mapped[dict[str, Any]]
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())


class MediaAssetRecord(Base):
    __tablename__ = "media_assets"
    __table_args__ = (
        CheckConstraint(f"id ~ '{SHA256_HEX}'", name="id_format"),
        CheckConstraint(f"sha256 ~ '{SHA256_HEX}'", name="sha256_format"),
    )
    id: Mapped[str] = mapped_column(Text, primary_key=True)
    content_key: Mapped[str] = mapped_column(Text, index=True)
    sha256: Mapped[str] = mapped_column(Text)
    receipt: Mapped[dict[str, Any]]
    review_decision_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("review_decisions.id"))
    published_at: Mapped[datetime] = mapped_column(server_default=func.now())
