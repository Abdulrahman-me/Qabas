"""Learner state, sessions, answers and recitation checks (data model §4.3, rev 10).

Lesson/unit *states* (locked/available/in_progress/...) are derived at read time from prerequisites,
active sessions and these stored facts; only the facts are persisted (decision D-21).
"""

from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal
from typing import Any

from sqlalchemy import (
    BigInteger,
    Boolean,
    CheckConstraint,
    ForeignKey,
    ForeignKeyConstraint,
    Identity,
    Index,
    Integer,
    Numeric,
    PrimaryKeyConstraint,
    SmallInteger,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy import text as sql_text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db import enums
from app.db.base import SHA256_HEX, Base, enum_check, id_check

PERCENT = "BETWEEN 0 AND 100"


class LearnerUnit(Base):
    __tablename__ = "learner_units"
    __table_args__ = (
        PrimaryKeyConstraint("user_id", "unit_id", name="pk_learner_units"),
        CheckConstraint(f"pretest_percent IS NULL OR pretest_percent {PERCENT}", name="pretest_percent_range"),
        CheckConstraint(f"unit_test_best_percent IS NULL OR unit_test_best_percent {PERCENT}",
                        name="unit_test_best_percent_range"),
        CheckConstraint(f"first_post_percent IS NULL OR first_post_percent {PERCENT}",
                        name="first_post_percent_range"),
        CheckConstraint("(pretest_taken_at IS NULL) = (pretest_percent IS NULL)", name="pretest_recorded"),
    )

    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    unit_id: Mapped[str] = mapped_column(ForeignKey("units.id"))
    started_at: Mapped[datetime | None]
    pretest_taken_at: Mapped[datetime | None]
    pretest_percent: Mapped[int | None] = mapped_column(SmallInteger)
    unit_test_best_percent: Mapped[int | None] = mapped_column(SmallInteger)
    unit_test_passed_at: Mapped[datetime | None]
    first_post_percent: Mapped[int | None] = mapped_column(SmallInteger)  # metrics: first test after all lessons
    completed_at: Mapped[datetime | None]
    skipped_at: Mapped[datetime | None]  # unit test passed before all lessons were completed


class LearnerLesson(Base):
    """Completion is keyed by canonical lesson only, never by track, variant, language or surface (AD-28)."""

    __tablename__ = "learner_lessons"
    __table_args__ = (
        PrimaryKeyConstraint("user_id", "lesson_id", name="pk_learner_lessons"),
        CheckConstraint(f"best_percent IS NULL OR best_percent {PERCENT}", name="best_percent_range"),
    )

    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    lesson_id: Mapped[str] = mapped_column(ForeignKey("lessons.id"))
    completed_at: Mapped[datetime | None]
    best_percent: Mapped[int | None] = mapped_column(SmallInteger)
    completed_session_id: Mapped[str | None] = mapped_column(Text)


class LearnerConcept(Base):
    __tablename__ = "learner_concepts"
    __table_args__ = (
        PrimaryKeyConstraint("user_id", "concept_id", name="pk_learner_concepts"),
        CheckConstraint("mastery BETWEEN 0 AND 1", name="mastery_range"),
        Index("ix_learner_concepts_user_id_due_at", "user_id", "due_at"),
    )

    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    concept_id: Mapped[str] = mapped_column(ForeignKey("concepts.id"))
    # Six-decimal private mastery (AD-12); computed with Decimal, reported half-up to two decimals.
    mastery: Mapped[Decimal] = mapped_column(Numeric(7, 6), server_default="0")
    fsrs_card: Mapped[dict[str, Any] | None]
    due_at: Mapped[datetime | None]
    first_practiced_at: Mapped[datetime | None]
    last_reviewed_at: Mapped[datetime | None]


class LearnerTerm(Base):
    __tablename__ = "learner_terms"
    __table_args__ = (
        PrimaryKeyConstraint("user_id", "term_id", name="pk_learner_terms"),
        enum_check("state", enums.TERM_STATE),
        CheckConstraint("exposures >= 0 AND opened_count >= 0", name="counters_non_negative"),
    )

    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    term_id: Mapped[str] = mapped_column(ForeignKey("terms.id"))
    state: Mapped[str] = mapped_column(Text, server_default="new")
    exposures: Mapped[int] = mapped_column(Integer, server_default="0")
    opened_count: Mapped[int] = mapped_column(Integer, server_default="0")


class LearnerMisconception(Base):
    __tablename__ = "learner_misconceptions"
    __table_args__ = (
        PrimaryKeyConstraint("user_id", "misconception_id", name="pk_learner_misconceptions"),
        enum_check("status", enums.MISCONCEPTION_STATUS),
        CheckConstraint("evidence_score >= 0", name="evidence_non_negative"),
        CheckConstraint("correct_streak BETWEEN 0 AND 3", name="correct_streak_range"),
        CheckConstraint("status = 'inactive' OR activated_at IS NOT NULL", name="activation_recorded"),
        CheckConstraint("(status = 'resolved') = (resolved_at IS NOT NULL)", name="resolution_recorded"),
    )

    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    misconception_id: Mapped[str] = mapped_column(ForeignKey("misconceptions.id"))
    status: Mapped[str] = mapped_column(Text, server_default="inactive")
    evidence_score: Mapped[Decimal] = mapped_column(Numeric(6, 2), server_default="0")
    correct_streak: Mapped[int] = mapped_column(SmallInteger, server_default="0")
    activated_at: Mapped[datetime | None]
    resolved_at: Mapped[datetime | None]


class LearningSession(Base):
    """A served session. Its snapshot never changes; finish stores and replays ``result_snapshot``."""

    __tablename__ = "sessions"
    __table_args__ = (
        id_check("id", "ses"),
        enum_check("kind", enums.SESSION_KIND),
        enum_check("mode", enums.SESSION_MODE, nullable=True),
        enum_check("status", enums.SESSION_STATUS),
        enum_check("feedback_mode", enums.FEEDBACK_MODE),
        enum_check("language", enums.LANGUAGE),
        enum_check("variant", enums.VARIANT),
        CheckConstraint("(kind = 'review') = (mode IS NOT NULL)", name="mode_only_for_review"),
        CheckConstraint(
            " OR ".join(f"(kind = '{k}' AND feedback_mode = '{m}')" for k, m in enums.FEEDBACK_BY_KIND.items()),
            name="feedback_mode_matches_kind"),
        CheckConstraint("kind <> 'lesson' OR (lesson_id IS NOT NULL AND lesson_version_id IS NOT NULL "
                        "AND unit_id IS NOT NULL)", name="lesson_session_refs"),
        CheckConstraint("kind NOT IN ('pretest', 'unit_test') OR unit_id IS NOT NULL", name="unit_session_refs"),
        CheckConstraint("kind = 'lesson' OR (lesson_id IS NULL AND lesson_version_id IS NULL)",
                        name="lesson_refs_only_for_lessons"),
        # Finish: exactly one completion with a stored result; abandon: no result (data model).
        CheckConstraint("(status = 'finished') = (finished_at IS NOT NULL AND result_snapshot IS NOT NULL)",
                        name="finished_has_result"),
        CheckConstraint("(status = 'abandoned') = (abandoned_at IS NOT NULL)", name="abandoned_recorded"),
        CheckConstraint("status = 'finished' OR (finished_at IS NULL AND result_snapshot IS NULL "
                        "AND duration_ms IS NULL)", name="result_only_when_finished"),
        CheckConstraint("duration_ms IS NULL OR duration_ms >= 0", name="duration_non_negative"),
        # One active session per (user, kind, lesson/unit, review mode) (data model, mandatory).
        Index("uq_sessions_one_active", "user_id", "kind",
              sql_text("COALESCE(lesson_id, '')"), sql_text("COALESCE(unit_id, '')"), sql_text("COALESCE(mode, '')"),
              unique=True, postgresql_where=sql_text("status = 'active'")),
        Index("ix_sessions_user_id_started_at", "user_id", "started_at"),
    )

    id: Mapped[str] = mapped_column(Text, primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    kind: Mapped[str] = mapped_column(Text)
    mode: Mapped[str | None] = mapped_column(Text)
    lesson_id: Mapped[str | None] = mapped_column(ForeignKey("lessons.id"))
    lesson_version_id: Mapped[uuid.UUID | None] = mapped_column(UUID, ForeignKey("lesson_versions.id"))
    unit_id: Mapped[str | None] = mapped_column(ForeignKey("units.id"))
    status: Mapped[str] = mapped_column(Text, server_default="active")
    feedback_mode: Mapped[str] = mapped_column(Text)
    language: Mapped[str] = mapped_column(Text)
    variant: Mapped[str] = mapped_column(Text)
    items_snapshot: Mapped[dict[str, Any]]            # exactly what was served
    served_exercises: Mapped[list[Any]]               # [{exercise_id, version}]
    served_scenes: Mapped[list[Any]] = mapped_column(server_default=sql_text("'[]'::jsonb"))
    started_at: Mapped[datetime] = mapped_column(server_default=func.now())
    finished_at: Mapped[datetime | None]
    abandoned_at: Mapped[datetime | None]
    duration_ms: Mapped[int | None] = mapped_column(Integer)
    result_snapshot: Mapped[dict[str, Any] | None]    # stored SessionResult, replayed on every finish call
    contract_revision: Mapped[int] = mapped_column(SmallInteger)
    snapshot_revision: Mapped[int | None] = mapped_column(SmallInteger)  # set only by a tested snapshot migration


class SessionAnswer(Base):
    """Insert-only attempt record; identity (session, exercise, is_retry) is unique (AD-09)."""

    __tablename__ = "session_answers"
    __table_args__ = (
        UniqueConstraint("session_id", "exercise_id", "is_retry", name="uq_session_answers_identity"),
        ForeignKeyConstraint(["exercise_id", "exercise_version"],
                             ["exercise_versions.exercise_id", "exercise_versions.version"],
                             name="fk_session_answers_exercise_versions"),
        CheckConstraint("elapsed_ms IS NULL OR elapsed_ms >= 0", name="elapsed_non_negative"),
    )

    id: Mapped[int] = mapped_column(BigInteger, Identity(), primary_key=True)
    session_id: Mapped[str] = mapped_column(ForeignKey("sessions.id", ondelete="CASCADE"))
    exercise_id: Mapped[str] = mapped_column(Text)
    exercise_version: Mapped[int] = mapped_column(Integer)
    answer: Mapped[dict[str, Any] | None]             # null = timeout
    correct: Mapped[bool | None] = mapped_column(Boolean)  # private; null for skipped/unavailable
    elapsed_ms: Mapped[int | None] = mapped_column(Integer)
    is_retry: Mapped[bool] = mapped_column(Boolean)
    misconception_id: Mapped[str | None] = mapped_column(ForeignKey("misconceptions.id"))
    evaluation: Mapped[dict[str, Any]]                # exact evaluation issued, replayed as-is
    recorded_at: Mapped[datetime] = mapped_column(server_default=func.now())


class RecitationCheckRecord(Base):
    """Bound recitation result (API §6.6). Audio is never stored."""

    __tablename__ = "recitation_checks"
    __table_args__ = (
        id_check("id", "rchk"),
        enum_check("status", enums.RECITATION_STATUS),
        CheckConstraint("surah BETWEEN 1 AND 114", name="surah_range"),
        CheckConstraint("ayah >= 1", name="ayah_positive"),
        # Both bounds or neither; explicit IS NOT NULL so a half range cannot pass as NULL.
        CheckConstraint("(word_start IS NULL AND word_end IS NULL) OR (word_start IS NOT NULL AND "
                        "word_end IS NOT NULL AND word_start >= 1 AND word_end >= word_start)",
                        name="word_range_valid"),
        CheckConstraint(f"checked_text_sha256 ~ '{SHA256_HEX}'", name="checked_text_sha256_format"),
        CheckConstraint("status = 'evaluated' OR NOT passed", name="unclear_never_passes"),
        Index("ix_recitation_checks_user_id", "user_id"),
    )

    id: Mapped[str] = mapped_column(Text, primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    surah: Mapped[int] = mapped_column(SmallInteger)
    ayah: Mapped[int] = mapped_column(SmallInteger)
    word_start: Mapped[int | None] = mapped_column(SmallInteger)
    word_end: Mapped[int | None] = mapped_column(SmallInteger)
    checked_text_sha256: Mapped[str] = mapped_column(Text)
    status: Mapped[str] = mapped_column(Text)
    passed: Mapped[bool] = mapped_column(Boolean)
    words: Mapped[list[Any]]
    summary: Mapped[dict[str, Any]]
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())

