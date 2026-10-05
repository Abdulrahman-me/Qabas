"""Outbox, consumer effect ledger and reviewer gate audit (data model §4.5, rev 10)."""

from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import BigInteger, CheckConstraint, ForeignKey, Identity, Index, Integer, SmallInteger, Text, func, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db import enums
from app.db.base import SHA256_HEX, Base, enum_check, sql_list


class OutboxEvent(Base):
    """Effects a response does not report, written in the producing transaction (AD-24)."""

    __tablename__ = "outbox_events"
    __table_args__ = (
        CheckConstraint("attempts >= 0", name="attempts_non_negative"),
        Index("ix_outbox_events_pending", "available_at", postgresql_where=text("processed_at IS NULL")),
    )

    id: Mapped[int] = mapped_column(BigInteger, Identity(), primary_key=True)
    event_key: Mapped[str] = mapped_column(Text, unique=True)  # e.g. session:{id}:finished
    kind: Mapped[str] = mapped_column(Text)
    payload: Mapped[dict[str, Any]]
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())
    available_at: Mapped[datetime] = mapped_column(server_default=func.now())
    attempts: Mapped[int] = mapped_column(Integer, server_default="0")
    processed_at: Mapped[datetime | None]
    last_error: Mapped[str | None] = mapped_column(Text)


class EffectLedger(Base):
    """Consumer idempotency: an effect is applied at most once, whatever the redelivery."""

    __tablename__ = "effect_ledger"

    effect_key: Mapped[str] = mapped_column(Text, primary_key=True)
    event_key: Mapped[str] = mapped_column(Text)
    applied_at: Mapped[datetime] = mapped_column(server_default=func.now())


FINAL_DECISION = "gate = 2 AND decision IN ('approve', 'reject')"


class ReviewDecision(Base):
    """Insert-only gate audit bound to the exact reviewed digest (AD-13, AD-19).

    A decision concerns a factory run (Gates 1/2) or, for gold/approved-content imports, an
    imported lesson version (Gate 2-equivalent approval, factory §13.7).
    """

    __tablename__ = "review_decisions"
    __table_args__ = (
        CheckConstraint("gate IN (1, 2)", name="gate_valid"),
        enum_check("decision", enums.REVIEW_DECISION),
        CheckConstraint(f"gate = 2 OR decision IN ({sql_list(enums.GATE1_DECISION)})", name="gate1_decision"),
        CheckConstraint("run_id IS NOT NULL OR lesson_version_id IS NOT NULL", name="has_subject"),
        CheckConstraint(f"reviewed_digest ~ '{SHA256_HEX}'", name="reviewed_digest_format"),
        CheckConstraint(f"published_digest IS NULL OR published_digest ~ '{SHA256_HEX}'",
                        name="published_digest_format"),
        CheckConstraint("published_digest IS NULL OR (gate = 2 AND decision = 'approve')",
                        name="published_only_on_gate2_approve"),
        CheckConstraint("gate <> 2 OR decision <> 'approve' OR published_digest IS NOT NULL",
                        name="gate2_approve_publishes"),
        # One Gate 1 decision per run; one final Gate 2 decision per run and per lesson version (migration 0006).
        Index("uq_review_decisions_gate1_run", "run_id", unique=True, postgresql_where=text("gate = 1")),
        Index("uq_review_decisions_final_run", "run_id", unique=True,
              postgresql_where=text(f"run_id IS NOT NULL AND {FINAL_DECISION}")),
        Index("uq_review_decisions_final_version", "lesson_version_id", unique=True,
              postgresql_where=text(f"lesson_version_id IS NOT NULL AND {FINAL_DECISION}")),
        Index("ix_review_decisions_run_id", "run_id"),
        Index("ix_review_decisions_lesson_version_id", "lesson_version_id"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID, primary_key=True, server_default=func.gen_random_uuid())
    run_id: Mapped[str | None] = mapped_column(ForeignKey("factory_runs.id"))
    lesson_version_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("lesson_versions.id"))
    gate: Mapped[int] = mapped_column(SmallInteger)
    decision: Mapped[str] = mapped_column(Text)
    reviewer_id: Mapped[str] = mapped_column(ForeignKey("users.id"))
    reviewed_digest: Mapped[str] = mapped_column(Text)
    published_digest: Mapped[str | None] = mapped_column(Text)
    edits: Mapped[dict[str, Any]] = mapped_column(server_default=text("'{}'::jsonb"))
    reason: Mapped[str | None] = mapped_column(Text)
    decided_at: Mapped[datetime] = mapped_column(server_default=func.now())
