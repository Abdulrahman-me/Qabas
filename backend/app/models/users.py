"""Users, auth sessions, request idempotency and account deletion (data model §4.1, rev 10)."""

from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    ForeignKey,
    Index,
    LargeBinary,
    SmallInteger,
    String,
    Text,
    func,
    text,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db import enums
from app.db.base import SHA256_HEX, Base, Timestamps, enum_check, id_check


class User(Timestamps, Base):
    __tablename__ = "users"
    __table_args__ = (
        id_check("id", "usr"),
        enum_check("role", enums.ROLE),
        enum_check("language", enums.LANGUAGE),
        enum_check("track", enums.TRACK),
        enum_check("familiarity", enums.FAMILIARITY, nullable=True),
        enum_check("daily_goal_minutes", enums.DAILY_GOAL_MINUTES),
        # Reviewers sign in with email/password; learners (guests) never have credentials.
        CheckConstraint("(role = 'reviewer') = (email IS NOT NULL AND password_hash IS NOT NULL)",
                        name="reviewer_credentials"),
        CheckConstraint("NOT (is_bot AND is_synthetic)", name="bot_or_synthetic"),
        Index("uq_users_email_lower", func.lower(text("email")), unique=True,
              postgresql_where=text("email IS NOT NULL")),
    )

    id: Mapped[str] = mapped_column(Text, primary_key=True)
    display_name: Mapped[str] = mapped_column(Text)
    avatar_key: Mapped[str] = mapped_column(Text)
    role: Mapped[str] = mapped_column(Text, server_default="learner")
    language: Mapped[str] = mapped_column(Text, server_default="ar")
    track: Mapped[str] = mapped_column(Text, server_default="explorer")
    familiarity: Mapped[str | None] = mapped_column(Text)
    daily_goal_minutes: Mapped[int] = mapped_column(SmallInteger, server_default="10")
    private_profile: Mapped[bool] = mapped_column(Boolean, server_default="true")
    timezone: Mapped[str] = mapped_column(Text)
    onboarding_completed: Mapped[bool] = mapped_column(Boolean, server_default="false")
    # Onboarding bridge only; never used for ordering, recommendations, adaptation or inference (AD-33).
    goal_anchor: Mapped[str | None] = mapped_column(Text)
    email: Mapped[str | None] = mapped_column(Text)
    password_hash: Mapped[str | None] = mapped_column(Text)  # Argon2id, reviewers only
    is_synthetic: Mapped[bool] = mapped_column(Boolean, server_default="false")
    is_bot: Mapped[bool] = mapped_column(Boolean, server_default="false")
    last_seen_at: Mapped[datetime | None]
    deleted_at: Mapped[datetime | None]
    deactivated_at: Mapped[datetime | None]  # reviewer deactivation by an operator


class AuthSession(Base):
    """Revocable opaque bearer tokens (AD-20): only HMAC-SHA-256(pepper, token) is stored."""

    __tablename__ = "auth_sessions"
    __table_args__ = (
        enum_check("role", enums.ROLE),
        CheckConstraint("octet_length(token_hmac) = 32", name="token_hmac_length"),
        Index("ix_auth_sessions_user_id_active", "user_id", postgresql_where=text("revoked_at IS NULL")),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID, primary_key=True, server_default=func.gen_random_uuid())
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    token_hmac: Mapped[bytes] = mapped_column(LargeBinary, unique=True)
    role: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())
    last_used_at: Mapped[datetime] = mapped_column(server_default=func.now())
    expires_at: Mapped[datetime | None]  # reviewers: 12 h absolute; guests: null (180-day inactivity rule)
    revoked_at: Mapped[datetime | None]


class IdempotencyKey(Base):
    """``Idempotency-Key`` replay store (backend §5.2); one row per (user, key), kept 24 h."""

    __tablename__ = "idempotency_keys"
    __table_args__ = (
        CheckConstraint(f"request_hash ~ '{SHA256_HEX}'", name="request_hash_format"),
        CheckConstraint("response_status BETWEEN 100 AND 599", name="response_status_range"),
        Index("ix_idempotency_keys_created_at", "created_at"),
    )

    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    key: Mapped[str] = mapped_column(String(64), primary_key=True)
    request_hash: Mapped[str] = mapped_column(Text)
    response_status: Mapped[int] = mapped_column(SmallInteger)
    response_body: Mapped[dict[str, Any]]
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())


class DeletionJob(Base):
    """Account purge log. No FK to users: it survives the purge and drives re-purge after a restore."""

    __tablename__ = "deletion_jobs"
    __table_args__ = (
        Index("uq_deletion_jobs_user_id_pending", "user_id", unique=True,
              postgresql_where=text("completed_at IS NULL")),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID, primary_key=True, server_default=func.gen_random_uuid())
    user_id: Mapped[str] = mapped_column(Text)
    requested_at: Mapped[datetime] = mapped_column(server_default=func.now())
    completed_at: Mapped[datetime | None]
    steps: Mapped[dict[str, Any]] = mapped_column(server_default=text("'{}'::jsonb"))
