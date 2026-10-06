"""Durable live transport facts; Postgres remains authoritative when Redis or an API instance restarts.

The append-only journal stores coordinates, never answer keys, rendered questions or credentials. Input signals
have no epoch; only the fenced coordinator can insert outbound events. IDs order delivery internally and are
not additions to the closed revision 10 WebSocket contract.
"""

from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import BigInteger, CheckConstraint, ForeignKey, Identity, Index, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class DuelConnection(Base):
    __tablename__ = "duel_connections"
    __table_args__ = (
        CheckConstraint("expires_at > connected_at", name="expiry_after_connect"),
        Index("ix_duel_connections_duel_id_user_id", "duel_id", "user_id"),
        Index("ix_duel_connections_user_id_expires_at", "user_id", "expires_at"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    duel_id: Mapped[str] = mapped_column(ForeignKey("duels.id", ondelete="CASCADE"))
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    auth_session_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("auth_sessions.id", ondelete="CASCADE"))
    connected_at: Mapped[datetime]
    expires_at: Mapped[datetime]
    closed_at: Mapped[datetime | None]


class DuelLiveEvent(Base):
    __tablename__ = "duel_live_events"
    __table_args__ = (
        UniqueConstraint("duel_id", "event_key"),
        CheckConstraint("epoch IS NULL OR epoch > 0", name="epoch_positive"),
        CheckConstraint("(epoch IS NULL) = (kind LIKE 'input.%')", name="input_has_no_epoch"),
        Index("ix_duel_live_events_duel_id_id", "duel_id", "id"),
    )

    id: Mapped[int] = mapped_column(BigInteger, Identity(), primary_key=True)
    duel_id: Mapped[str] = mapped_column(ForeignKey("duels.id", ondelete="CASCADE"))
    event_key: Mapped[str] = mapped_column(Text)
    kind: Mapped[str] = mapped_column(Text)
    data: Mapped[dict[str, Any]]
    epoch: Mapped[int | None] = mapped_column(BigInteger)
    recorded_at: Mapped[datetime]
