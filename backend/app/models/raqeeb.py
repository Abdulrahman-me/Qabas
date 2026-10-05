"""Learner-owned conversations and append-only benchmark results (data model §4.4-4.5)."""

from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import CheckConstraint, ForeignKey, Index, Integer, Text, UniqueConstraint, func, text
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, id_check


class RaqeebConversation(Base):
    __tablename__ = "raqeeb_conversations"
    __table_args__ = (id_check("id", "conv"), Index("ix_raqeeb_conversations_user_id", "user_id"))
    id: Mapped[str] = mapped_column(Text, primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    title: Mapped[str | None] = mapped_column(Text)
    context: Mapped[dict[str, Any] | None]
    language: Mapped[str] = mapped_column(Text)
    track: Mapped[str] = mapped_column(Text)
    context_snapshot: Mapped[dict[str, Any]]
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(server_default=func.now())


class RaqeebMessage(Base):
    __tablename__ = "raqeeb_messages"
    __table_args__ = (
        id_check("id", "msg"),
        CheckConstraint("(role = 'user' AND status = 'received') OR "
                        "(role = 'assistant' AND status IN ('processing','completed','failed'))", name="role_status"),
        CheckConstraint("stage IN ('received','reading_inputs','classifying','retrieving','verifying','writing',"
                        "'adapting','done')", name="stage_valid"),
        CheckConstraint("feedback IS NULL OR (status = 'completed' AND feedback IN ('up','down'))",
                        name="feedback_valid"),
        CheckConstraint("(role = 'assistant') = (reply_to IS NOT NULL)", name="reply_role_valid"),
        CheckConstraint("status <> 'completed' OR (completed_at IS NOT NULL AND stage = 'done' AND "
                        "understood_input IS NOT NULL AND classification IS NOT NULL AND abstained IS NOT NULL "
                        "AND blocks IS NOT NULL AND citations IS NOT NULL AND terms IS NOT NULL "
                        "AND suggested_lessons IS NOT NULL)",
                        name="completion_valid"),
        UniqueConstraint("reply_to", name="uq_raqeeb_messages_reply_to"),
        Index("uq_raqeeb_messages_processing", "conversation_id", unique=True,
              postgresql_where=text("status = 'processing'")),
        Index("ix_raqeeb_messages_conversation_id", "conversation_id"),
    )
    id: Mapped[str] = mapped_column(Text, primary_key=True)
    conversation_id: Mapped[str] = mapped_column(ForeignKey("raqeeb_conversations.id", ondelete="CASCADE"))
    reply_to: Mapped[str | None] = mapped_column(ForeignKey("raqeeb_messages.id", ondelete="CASCADE"))
    role: Mapped[str] = mapped_column(Text)
    status: Mapped[str] = mapped_column(Text)
    stage: Mapped[str] = mapped_column(Text)
    text: Mapped[str | None] = mapped_column(Text)
    attachments: Mapped[list[dict[str, Any]]] = mapped_column(JSONB)
    understood_input: Mapped[dict[str, Any] | None]
    classification: Mapped[dict[str, Any] | None]
    abstained: Mapped[bool | None]
    blocks: Mapped[list[dict[str, Any]] | None] = mapped_column(JSONB)
    citations: Mapped[list[dict[str, Any]] | None] = mapped_column(JSONB)
    terms: Mapped[dict[str, Any] | None]
    suggested_lessons: Mapped[list[dict[str, Any]] | None] = mapped_column(JSONB)
    error: Mapped[dict[str, Any] | None]
    feedback: Mapped[str | None] = mapped_column(Text)
    feedback_reason: Mapped[str | None] = mapped_column(Text)
    feedback_comment: Mapped[str | None] = mapped_column(Text)
    trace: Mapped[dict[str, Any]]
    input_snapshot: Mapped[dict[str, Any]]
    lease: Mapped[uuid.UUID | None] = mapped_column(UUID)
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())
    completed_at: Mapped[datetime | None]


class BenchmarkRun(Base):
    __tablename__ = "benchmark_runs"
    __table_args__ = (CheckConstraint("question_count > 0", name="question_count_positive"),)
    id: Mapped[uuid.UUID] = mapped_column(UUID, primary_key=True)
    run_at: Mapped[datetime]
    question_count: Mapped[int] = mapped_column(Integer)
    results: Mapped[dict[str, Any]]
    provenance: Mapped[dict[str, Any]]
    digest: Mapped[str] = mapped_column(Text)
    synthetic: Mapped[bool]
