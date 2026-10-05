"""Leagues, friends and achievements (backend §10.3, §10.4, §10.7; Phase 18).

Weekly XP is never stored here: a member's ``xp_week`` is the sum of their ``xp_events`` for the league's
``week_key``, so the league can never disagree with the XP ledger. ``league_tiers`` and ``achievements`` are
seeded configuration (``content/registries.json``, synced by ``scripts/seed.py``).
"""

from __future__ import annotations

from datetime import datetime
from typing import Any

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    ForeignKey,
    ForeignKeyConstraint,
    Index,
    Integer,
    PrimaryKeyConstraint,
    SmallInteger,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, id_check

COUNTERS = ("raqeeb_questions", "lessons_completed", "units_completed", "longest_streak", "terms_mastered",
            "misconceptions_resolved", "challenges_won", "recitations_passed", "reviews_completed",
            "perfect_lessons")


class LeagueTier(Base):
    __tablename__ = "league_tiers"
    __table_args__ = (
        UniqueConstraint("index", name="uq_league_tiers_index"),
        CheckConstraint("index >= 0", name="index_non_negative"),
        CheckConstraint("promotion_zone_size >= 1", name="zone_positive"),
    )

    tier_key: Mapped[str] = mapped_column(Text, primary_key=True)
    index: Mapped[int] = mapped_column(SmallInteger)
    name: Mapped[dict[str, Any]]
    promotion_zone_size: Mapped[int] = mapped_column(SmallInteger)
    is_top_tier: Mapped[bool] = mapped_column(Boolean)


class League(Base):
    __tablename__ = "leagues"
    __table_args__ = (
        CheckConstraint("id ~ '^lg_[0-9]{4}w[0-9]{2}_[0-9]+_[0-9]+$'", name="id_format"),
        CheckConstraint("week_key ~ '^[0-9]{4}-W[0-9]{2}$'", name="week_key_format"),
        CheckConstraint("seq >= 1", name="seq_positive"),
        UniqueConstraint("week_key", "tier_key", "seq", name="uq_leagues_week_key_tier_key_seq"),
        UniqueConstraint("id", "week_key", name="uq_leagues_id_week_key"),   # target of league_members' FK
    )

    id: Mapped[str] = mapped_column(Text, primary_key=True)
    week_key: Mapped[str] = mapped_column(Text)
    tier_key: Mapped[str] = mapped_column(ForeignKey("league_tiers.tier_key"))
    seq: Mapped[int] = mapped_column(Integer)
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())


class LeagueMember(Base):
    __tablename__ = "league_members"
    __table_args__ = (
        PrimaryKeyConstraint("league_id", "user_id", name="pk_league_members"),
        # One league per learner per week, enforced by the database (the week is copied from the league).
        UniqueConstraint("user_id", "week_key", name="uq_league_members_user_id_week_key"),
        ForeignKeyConstraint(["league_id", "week_key"], ["leagues.id", "leagues.week_key"], ondelete="CASCADE",
                             name="fk_league_members_league_id_week_key_leagues"),
    )

    league_id: Mapped[str] = mapped_column(Text)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    week_key: Mapped[str] = mapped_column(Text)
    joined_at: Mapped[datetime] = mapped_column(server_default=func.now())


class LearnerTier(Base):
    __tablename__ = "learner_tiers"

    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    tier_key: Mapped[str] = mapped_column(ForeignKey("league_tiers.tier_key"))
    promoted_at: Mapped[datetime | None]
    promoted_week_key: Mapped[str | None] = mapped_column(Text)   # the week whose result moved the learner up


class LeaguePromotion(Base):
    """The week-end promotion job record: one row per ``week_key`` makes the job idempotent."""

    __tablename__ = "league_promotions"
    __table_args__ = (CheckConstraint("promoted >= 0", name="promoted_non_negative"),)

    week_key: Mapped[str] = mapped_column(Text, primary_key=True)
    completed_at: Mapped[datetime] = mapped_column(server_default=func.now())
    promoted: Mapped[int] = mapped_column(Integer)


class AchievementDefinition(Base):
    __tablename__ = "achievements"
    __table_args__ = (
        CheckConstraint("counter IN (" + ", ".join(f"'{c}'" for c in COUNTERS) + ")", name="counter_valid"),
        CheckConstraint("target >= 1", name="target_positive"),
        UniqueConstraint("position", name="uq_achievements_position"),
    )

    achievement_key: Mapped[str] = mapped_column(Text, primary_key=True)
    position: Mapped[int] = mapped_column(SmallInteger)      # display order of the registry
    title: Mapped[dict[str, Any]]
    description: Mapped[dict[str, Any]]
    counter: Mapped[str] = mapped_column(Text)
    target: Mapped[int] = mapped_column(Integer)


class LearnerAchievement(Base):
    __tablename__ = "learner_achievements"
    __table_args__ = (
        PrimaryKeyConstraint("user_id", "achievement_key", name="pk_learner_achievements"),
        CheckConstraint("progress >= 0", name="progress_non_negative"),
    )

    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    achievement_key: Mapped[str] = mapped_column(ForeignKey("achievements.achievement_key"))
    progress: Mapped[int] = mapped_column(Integer)
    unlocked_at: Mapped[datetime | None]
    updated_at: Mapped[datetime] = mapped_column(server_default=func.now())


class Friendship(Base):
    __tablename__ = "friendships"
    __table_args__ = (
        PrimaryKeyConstraint("user_a", "user_b", name="pk_friendships"),
        CheckConstraint("user_a < user_b", name="ordered_pair"),     # one row per pair, never a self-friendship
        Index("ix_friendships_user_b", "user_b"),
    )

    user_a: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    user_b: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())


class FriendInvite(Base):
    __tablename__ = "friend_invites"
    __table_args__ = (
        id_check("id", "inv"),
        CheckConstraint("code ~ '^QBS-[0-9A-HJKMNP-TV-Z]{4}$'", name="code_format"),
        CheckConstraint("expires_at > created_at", name="expires_after_created"),
        CheckConstraint("used_by IS NULL OR used_at IS NOT NULL", name="used_by_has_time"),
        CheckConstraint("used_by IS NULL OR used_by <> inviter_id", name="not_self"),
        Index("ix_friend_invites_code_expires_at", "code", "expires_at"),
        Index("ix_friend_invites_inviter_id", "inviter_id"),
        Index("ix_friend_invites_used_by", "used_by"),
    )

    id: Mapped[str] = mapped_column(Text, primary_key=True)
    code: Mapped[str] = mapped_column(Text)
    inviter_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())
    expires_at: Mapped[datetime]
    used_by: Mapped[str | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"))
    used_at: Mapped[datetime | None]
