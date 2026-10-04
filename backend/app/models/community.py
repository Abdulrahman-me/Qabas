"""XP, daily activity and quests: written by the finish transaction (backend §10.1-10.2, §10.6).

Leagues, friends, achievements and challenges arrive with their phases (18-20).
"""

from __future__ import annotations

from datetime import date, datetime

from sqlalchemy import (
    BigInteger,
    Boolean,
    CheckConstraint,
    ForeignKey,
    Identity,
    Index,
    Integer,
    PrimaryKeyConstraint,
    SmallInteger,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy import text as sql_text
from sqlalchemy.orm import Mapped, mapped_column

from app.db import enums
from app.db.base import Base, enum_check


class XpEvent(Base):
    __tablename__ = "xp_events"
    __table_args__ = (
        enum_check("reason", enums.XP_REASON),
        CheckConstraint("xp >= 0", name="xp_non_negative"),
        # Effects happen once: one grant per (user, reason, reference) (data model, mandatory).
        UniqueConstraint("user_id", "reason", "ref_type", "ref_id", name="uq_xp_events_grant"),
        # daily_goal_met at most once per stored local date.
        Index("uq_xp_events_daily_goal", "user_id", "local_date", unique=True,
              postgresql_where=sql_text("reason = 'daily_goal_met'")),
        Index("ix_xp_events_user_id_week_key", "user_id", "week_key"),
    )

    id: Mapped[int] = mapped_column(BigInteger, Identity(), primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    reason: Mapped[str] = mapped_column(Text)
    xp: Mapped[int] = mapped_column(Integer)
    ref_type: Mapped[str] = mapped_column(Text)
    ref_id: Mapped[str] = mapped_column(Text)
    week_key: Mapped[str] = mapped_column(Text)   # league week, Sunday 00:00 Asia/Riyadh (backend §10.3)
    local_date: Mapped[date]                      # learner's local day at the event; never recomputed
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())


class DailyActivity(Base):
    __tablename__ = "daily_activity"
    __table_args__ = (
        PrimaryKeyConstraint("user_id", "local_date", name="pk_daily_activity"),
        CheckConstraint("minutes >= 0 AND xp >= 0", name="counters_non_negative"),
    )

    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    local_date: Mapped[date]
    minutes: Mapped[int] = mapped_column(Integer, server_default="0")
    xp: Mapped[int] = mapped_column(Integer, server_default="0")
    qualifying: Mapped[bool] = mapped_column(Boolean, server_default="false")


class Quest(Base):
    __tablename__ = "quests"
    __table_args__ = (
        UniqueConstraint("user_id", "local_date", "slot", name="uq_quests_slot"),
        UniqueConstraint("user_id", "local_date", "kind", name="uq_quests_kind"),  # at most one of each kind
        CheckConstraint("slot BETWEEN 1 AND 3", name="slot_range"),
        enum_check("kind", enums.QUEST_KIND),
        CheckConstraint("goal > 0 AND progress >= 0 AND reward_xp >= 0", name="amounts_valid"),
        CheckConstraint("completed_at IS NULL OR progress >= goal", name="completed_when_goal_met"),
    )

    id: Mapped[int] = mapped_column(BigInteger, Identity(), primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    local_date: Mapped[date]
    slot: Mapped[int] = mapped_column(SmallInteger)
    kind: Mapped[str] = mapped_column(Text)
    goal: Mapped[int] = mapped_column(Integer)
    progress: Mapped[int] = mapped_column(Integer, server_default="0")
    reward_xp: Mapped[int] = mapped_column(Integer)
    completed_at: Mapped[datetime | None]
