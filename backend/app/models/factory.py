"""Lesson Factory runs (data model ``factory_runs``; factory §13, rev 10).

One run produces (or revises) the single lesson of one curriculum slot. The contract's ``FactoryRun``
invariants are also database constraints: a ``review_digest`` exists exactly while the run awaits a gate, an
``error`` exactly when it failed, a published reference exactly when it is published; at most one active run
per slot (one lesson per slot, never a sibling; §13.5 composition rule).

Durable provenance lives here, not in logs (§13.1 stage execution): ``artifacts`` keeps each stage's accepted
output with the attempt, prompt/model identity, input and output digests; ``attempts`` keeps every attempt of
every stage with its outcome and error; ``cost`` keeps every model call record (``app.llm.budget.UsageRecord``)
including calls whose output was rejected.
"""

from __future__ import annotations

from datetime import datetime
from typing import Any

from sqlalchemy import CheckConstraint, ForeignKey, ForeignKeyConstraint, Index, Integer, Text, text
from sqlalchemy.orm import Mapped, mapped_column

from app.db import enums
from app.db.base import SHA256_HEX, Base, Timestamps, enum_check, id_check

ACTIVE = "status IN ('running', 'awaiting_gate1', 'awaiting_gate2')"


class FactoryRun(Timestamps, Base):
    __tablename__ = "factory_runs"
    __table_args__ = (
        id_check("id", "run"),
        enum_check("lesson_type", enums.LESSON_TYPE),
        enum_check("status", enums.RUN_STATUS),
        enum_check("stage", enums.RUN_STAGE),
        CheckConstraint("position_index >= 0", name="position_index_non_negative"),
        CheckConstraint("attempt >= 1", name="attempt_positive"),
        CheckConstraint("budget_tokens IS NULL OR budget_tokens > 0", name="budget_positive"),
        CheckConstraint(f"review_digest IS NULL OR review_digest ~ '{SHA256_HEX}'", name="review_digest_format"),
        CheckConstraint("(status IN ('awaiting_gate1', 'awaiting_gate2')) = (review_digest IS NOT NULL)",
                        name="digest_iff_at_gate"),
        CheckConstraint("status <> 'awaiting_gate1' OR plan IS NOT NULL", name="gate1_has_plan"),
        CheckConstraint("status <> 'awaiting_gate2' OR qa_report IS NOT NULL", name="gate2_has_qa_report"),
        CheckConstraint("(status = 'failed') = (error IS NOT NULL)", name="error_iff_failed"),
        CheckConstraint("(status = 'published') = (published_lesson_id IS NOT NULL AND published_version IS NOT NULL)",
                        name="published_iff_status"),
        ForeignKeyConstraint(["lesson_id", "unit_id", "position_index"],
                             ["curriculum_slots.lesson_id", "curriculum_slots.unit_id", "curriculum_slots.index"],
                             name="fk_factory_runs_slot"),
        Index("uq_factory_runs_active_slot", "lesson_id", unique=True, postgresql_where=text(ACTIVE)),
        Index("ix_factory_runs_status", "status"),
    )

    id: Mapped[str] = mapped_column(Text, primary_key=True)
    unit_id: Mapped[str] = mapped_column(ForeignKey("units.id"))
    lesson_id: Mapped[str] = mapped_column(Text)            # the slot's canonical lesson (created or revised)
    position_index: Mapped[int] = mapped_column(Integer)    # curriculum position; never a prerequisite
    lesson_type: Mapped[str] = mapped_column(Text)
    brief: Mapped[str] = mapped_column(Text)                # reviewer free text: untrusted data in prompts
    status: Mapped[str] = mapped_column(Text, server_default="running")
    stage: Mapped[str] = mapped_column(Text, server_default="plan")
    attempt: Mapped[int] = mapped_column(Integer, server_default="1")   # current attempt of the current stage
    stages: Mapped[list[Any]]                               # contract StageStatus[]
    plan: Mapped[dict[str, Any] | None]                     # LessonPlan (as approved at Gate 1, once decided)
    artifacts: Mapped[dict[str, Any]] = mapped_column(server_default=text("'{}'::jsonb"))
    qa_report: Mapped[dict[str, Any] | None]
    gate1_decision: Mapped[dict[str, Any] | None]
    gate2_decision: Mapped[dict[str, Any] | None]
    stage_timings: Mapped[dict[str, Any]] = mapped_column(server_default=text("'{}'::jsonb"))
    attempts: Mapped[list[Any]] = mapped_column(server_default=text("'[]'::jsonb"))
    review_started_at: Mapped[datetime | None]
    review_finished_at: Mapped[datetime | None]
    published_lesson_id: Mapped[str | None] = mapped_column(Text)
    published_version: Mapped[int | None] = mapped_column(Integer)
    review_digest: Mapped[str | None] = mapped_column(Text)
    cost: Mapped[dict[str, Any]] = mapped_column(server_default=text("'{\"calls\": []}'::jsonb"))
    budget_tokens: Mapped[int | None] = mapped_column(Integer)
    error: Mapped[dict[str, Any] | None]
    created_by: Mapped[str] = mapped_column(ForeignKey("users.id"))
