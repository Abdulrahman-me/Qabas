"""Derived, guarded memory and durable private-upload receipts; never learner progress."""
from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any

from pgvector.sqlalchemy import VECTOR
from sqlalchemy import CheckConstraint, ForeignKey, Index, Integer, Text, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.dialects.postgresql.base import ischema_names
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, id_check

# PostgreSQL qualifies a type outside search_path; retain real vector dimensions in Alembic reflection.
ischema_names["extensions.vector"] = VECTOR


class RaqeebMemory(Base):
    __tablename__ = "raqeeb_memory"
    __table_args__ = (
        id_check("id", "mem"),
        CheckConstraint("language IN ('ar','en')", name="language_valid"),
        CheckConstraint("question_class IN ('general_knowledge','text_explanation')", name="class_valid"),
        CheckConstraint("hits >= 0", name="hits_nonnegative"),
        CheckConstraint("length(canonical_question) BETWEEN 1 AND 2000", name="question_bounded"),
        UniqueConstraint("origin_message_id", name="uq_raqeeb_memory_origin_message_id"),
        Index("ix_raqeeb_memory_lookup", "language", "question_class", "policy_version", "prompt_version"),
        Index("ix_raqeeb_memory_origin_user_id", "origin_user_id"),
        Index("ix_raqeeb_memory_embedding", "embedding", postgresql_using="hnsw",
              postgresql_ops={"embedding": "extensions.vector_cosine_ops"}),
    )
    id: Mapped[str] = mapped_column(Text, primary_key=True)
    language: Mapped[str] = mapped_column(Text)
    question_class: Mapped[str] = mapped_column(Text)
    canonical_question: Mapped[str] = mapped_column(Text)
    embedding: Mapped[Any | None] = mapped_column(VECTOR(1024))
    core: Mapped[dict[str, Any]]
    source_digests: Mapped[dict[str, Any]]
    evidence: Mapped[dict[str, Any]]
    policy_version: Mapped[str] = mapped_column(Text)
    prompt_version: Mapped[str] = mapped_column(Text)
    origin_user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    origin_message_id: Mapped[str] = mapped_column(ForeignKey("raqeeb_messages.id", ondelete="CASCADE"))
    namespace: Mapped[uuid.UUID | None] = mapped_column(UUID)
    hits: Mapped[int] = mapped_column(Integer, server_default="0")
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())
    expires_at: Mapped[datetime]


class RaqeebUploadReceipt(Base):
    __tablename__ = "raqeeb_upload_receipts"
    __table_args__ = (
        id_check("id", "att"),
        CheckConstraint("status IN ('pending','attached','deleted')", name="status_valid"),
        CheckConstraint("kind IN ('audio','image','document')", name="kind_valid"),
        CheckConstraint("size_bytes > 0", name="size_positive"),
        UniqueConstraint("object_key", name="uq_raqeeb_upload_receipts_object_key"),
        Index("ix_raqeeb_upload_receipts_user_id", "user_id"),
        Index("ix_raqeeb_upload_receipts_retention", "status", "expires_at"),
    )
    id: Mapped[str] = mapped_column(Text, primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    message_id: Mapped[str | None] = mapped_column(ForeignKey("raqeeb_messages.id", ondelete="SET NULL"))
    request_hash: Mapped[str] = mapped_column(Text)
    object_key: Mapped[str] = mapped_column(Text)
    sha256: Mapped[str] = mapped_column(Text)
    kind: Mapped[str] = mapped_column(Text)
    filename: Mapped[str] = mapped_column(Text)
    mime: Mapped[str] = mapped_column(Text)
    size_bytes: Mapped[int] = mapped_column(Integer)
    duration_ms: Mapped[int | None] = mapped_column(Integer)
    pages: Mapped[int | None] = mapped_column(Integer)
    status: Mapped[str] = mapped_column(Text, server_default="pending")
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())
    expires_at: Mapped[datetime]
