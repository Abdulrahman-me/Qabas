"""Blind tests and learning-metric facts (data model ``blind_pairs``/``blind_responses``; factory §14; Phase 15).

* A **blind pair** compares two published lesson versions, one gold (handwritten) and one generated, with the gold
  side drawn at random when the pair is created. A reviewer answers a pair once; responses are insert-only.
* **Metric facts** are each learner's current contribution to ``GET /admin/metrics``. They are an outbox effect of
  ``session.finished`` (backend "Transactions and effects": metrics aggregates go through the outbox): the
  subscriber recomputes the learner's rows from the authoritative tables (``learner_units``,
  ``learner_misconceptions``), so a redelivered or late event, or a backfill, converges on the same values.
  Facts belong to the learner and are removed by the account purge.
"""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import CheckConstraint, ForeignKey, Index, Integer, SmallInteger, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, id_check


class BlindPair(Base):
    __tablename__ = "blind_pairs"
    __table_args__ = (
        id_check("id", "pair"),
        CheckConstraint("lesson_version_a <> lesson_version_b", name="distinct_versions"),
        CheckConstraint("gold_side IN ('a', 'b')", name="gold_side_valid"),
    )

    id: Mapped[str] = mapped_column(Text, primary_key=True)
    lesson_version_a: Mapped[uuid.UUID] = mapped_column(UUID, ForeignKey("lesson_versions.id"))
    lesson_version_b: Mapped[uuid.UUID] = mapped_column(UUID, ForeignKey("lesson_versions.id"))
    gold_side: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())


class BlindResponse(Base):
    __tablename__ = "blind_responses"
    __table_args__ = (
        CheckConstraint("clearer IN ('a', 'b', 'same')", name="clearer_valid"),
        CheckConstraint("more_accurate IN ('a', 'b', 'same')", name="more_accurate_valid"),
        CheckConstraint("guessed_handwritten IN ('a', 'b', 'unsure')", name="guess_valid"),
        Index("ix_blind_responses_reviewer_id", "reviewer_id"),
    )

    pair_id: Mapped[str] = mapped_column(ForeignKey("blind_pairs.id"), primary_key=True)
    reviewer_id: Mapped[str] = mapped_column(ForeignKey("users.id"), primary_key=True)
    clearer: Mapped[str] = mapped_column(Text)
    more_accurate: Mapped[str] = mapped_column(Text)
    guessed_handwritten: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())


class MetricUnitFact(Base):
    """One learner x unit: started/completed (or skipped), pretest and first post-test percent."""

    __tablename__ = "metric_unit_facts"
    __table_args__ = (
        CheckConstraint("pretest_percent IS NULL OR pretest_percent BETWEEN 0 AND 100", name="pretest_range"),
        CheckConstraint("first_post_percent IS NULL OR first_post_percent BETWEEN 0 AND 100", name="post_range"),
        CheckConstraint("started OR NOT completed", name="completed_after_started"),
        Index("ix_metric_unit_facts_unit_id", "unit_id"),
    )

    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    unit_id: Mapped[str] = mapped_column(ForeignKey("units.id"), primary_key=True)
    started: Mapped[bool]
    completed: Mapped[bool]
    pretest_percent: Mapped[int | None] = mapped_column(SmallInteger)
    first_post_percent: Mapped[int | None] = mapped_column(SmallInteger)
    refreshed_at: Mapped[datetime] = mapped_column(server_default=func.now())


class MetricLearnerFact(Base):
    """One learner: misconceptions ever activated and resolved."""

    __tablename__ = "metric_learner_facts"
    __table_args__ = (
        CheckConstraint("misconceptions_activated >= 0 AND misconceptions_resolved >= 0", name="non_negative"),
    )

    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    misconceptions_activated: Mapped[int] = mapped_column(Integer)
    misconceptions_resolved: Mapped[int] = mapped_column(Integer)
    refreshed_at: Mapped[datetime] = mapped_column(server_default=func.now())
