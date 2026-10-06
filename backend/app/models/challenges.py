"""Challenges (backend §11, API §6.10; Phase 19): the system of record for duel and group challenges.

* ``duels``: preset, mode, status and the frozen ``config``; ``phase`` and ``coordinator_epoch`` belong to the live
  coordinator (Phase 20). A terminal duel (finished, expired, declined) never changes status again and its result
  is written once (database trigger).
* ``duel_players``: the creator (seat 0), invitees in request order (1-3) and practice bots (4-6; a bot duel seats
  its bot at 1).
* ``duel_questions``: the questions chosen at creation (``user_id`` null: one row per index, pinned exercise
  version); live timing columns are written by the coordinator. Async duels add one row per player and index with
  that player's server ``issued_at``/``deadline_at`` (data model "per player for async duels").
* ``duel_answers``: one answer per (duel, player, question), never updated; server ``received_at`` and points.
"""

from __future__ import annotations

from datetime import datetime
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
    PrimaryKeyConstraint,
    SmallInteger,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy import text as sql_text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, id_check

STATUSES = ("pending", "ready", "in_progress", "finished", "expired", "declined")
TERMINAL = ("finished", "expired", "declined")
PLAYER_STATUSES = ("invited", "joined", "declined", "left")


class Duel(Base):
    __tablename__ = "duels"
    __table_args__ = (
        id_check("id", "duel"),
        CheckConstraint("preset IN ('duel', 'group')", name="preset_valid"),
        CheckConstraint("mode IN ('live', 'async')", name="mode_valid"),
        CheckConstraint("status IN ('pending', 'ready', 'in_progress', 'finished', 'expired', 'declined')",
                        name="status_valid"),
        CheckConstraint("opponent_type IN ('bot', 'friend', 'friends')", name="opponent_type_valid"),
        CheckConstraint("(preset = 'duel' AND opponent_type IN ('bot', 'friend')) OR "
                        "(preset = 'group' AND opponent_type = 'friends')", name="preset_opponents"),
        CheckConstraint("phase IS NULL OR phase IN ('countdown', 'question', 'result', 'finished')",
                        name="phase_valid"),
        # Async play is the duel preset against a friend only (API §6.10 "Async fallback").
        CheckConstraint("mode = 'live' OR (preset = 'duel' AND opponent_type = 'friend' AND async_at IS NOT NULL)",
                        name="async_is_friend_duel"),
        CheckConstraint("(status = 'finished') = (result IS NOT NULL AND finished_at IS NOT NULL)",
                        name="finished_has_result"),
        CheckConstraint("expires_at > created_at", name="expires_after_created"),
        CheckConstraint("coordinator_epoch >= 0", name="epoch_non_negative"),
        Index("ix_duels_status_expires_at", "status", "expires_at"),
        Index("ix_duels_created_by", "created_by"),
    )

    id: Mapped[str] = mapped_column(Text, primary_key=True)
    preset: Mapped[str] = mapped_column(Text)
    mode: Mapped[str] = mapped_column(Text, server_default="live")
    status: Mapped[str] = mapped_column(Text)
    phase: Mapped[str | None] = mapped_column(Text)
    opponent_type: Mapped[str] = mapped_column(Text)
    bot_fill: Mapped[bool] = mapped_column(Boolean, server_default="false")
    config: Mapped[dict[str, Any]]
    created_by: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())
    expires_at: Mapped[datetime]
    lobby_deadline_at: Mapped[datetime | None]
    async_at: Mapped[datetime | None]
    coordinator_epoch: Mapped[int] = mapped_column(BigInteger, server_default="0")
    result: Mapped[dict[str, Any] | None]
    finished_at: Mapped[datetime | None]


class DuelPlayer(Base):
    __tablename__ = "duel_players"
    __table_args__ = (
        PrimaryKeyConstraint("duel_id", "user_id", name="pk_duel_players"),
        UniqueConstraint("duel_id", "seat", name="uq_duel_players_duel_id_seat"),
        CheckConstraint("seat BETWEEN 0 AND 6", name="seat_range"),
        CheckConstraint("status IN ('invited', 'joined', 'declined', 'left')", name="status_valid"),
        CheckConstraint("NOT is_bot OR status = 'joined'", name="bots_join"),
        CheckConstraint("(status = 'joined') = (joined_at IS NOT NULL) OR status = 'left'", name="joined_has_time"),
        CheckConstraint("xp_awarded IS NULL OR xp_awarded >= 0", name="xp_non_negative"),
        Index("ix_duel_players_user_id", "user_id"),
    )

    duel_id: Mapped[str] = mapped_column(ForeignKey("duels.id", ondelete="CASCADE"))
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    seat: Mapped[int] = mapped_column(SmallInteger)
    is_bot: Mapped[bool] = mapped_column(Boolean, server_default="false")
    status: Mapped[str] = mapped_column(Text)
    joined_at: Mapped[datetime | None]
    responded_at: Mapped[datetime | None]
    forfeited: Mapped[bool] = mapped_column(Boolean, server_default="false")
    completed_at: Mapped[datetime | None]     # async: the player answered (or timed out on) every question
    xp_awarded: Mapped[int | None] = mapped_column(Integer)


class DuelQuestion(Base):
    __tablename__ = "duel_questions"
    __table_args__ = (
        ForeignKeyConstraint(["exercise_id", "exercise_version"],
                             ["exercise_versions.exercise_id", "exercise_versions.version"],
                             name="fk_duel_questions_exercise_versions"),
        CheckConstraint("question_index >= 0", name="index_non_negative"),
        CheckConstraint("deadline_at IS NULL OR (issued_at IS NOT NULL AND deadline_at > issued_at)",
                        name="deadline_after_issue"),
        CheckConstraint("user_id IS NULL OR (issued_at IS NOT NULL AND deadline_at IS NOT NULL)",
                        name="player_rows_are_issued"),
        Index("uq_duel_questions_shared", "duel_id", "question_index", unique=True,
              postgresql_where=sql_text("user_id IS NULL")),
        Index("uq_duel_questions_player", "duel_id", "user_id", "question_index", unique=True,
              postgresql_where=sql_text("user_id IS NOT NULL")),
        # One question of a duel is never served twice (backend §11.1 "no repeats").
        Index("uq_duel_questions_exercise", "duel_id", "exercise_id", unique=True,
              postgresql_where=sql_text("user_id IS NULL")),
    )

    id: Mapped[int] = mapped_column(BigInteger, Identity(), primary_key=True)
    duel_id: Mapped[str] = mapped_column(ForeignKey("duels.id", ondelete="CASCADE"))
    question_index: Mapped[int] = mapped_column(SmallInteger)
    user_id: Mapped[str | None] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    exercise_id: Mapped[str] = mapped_column(Text)
    exercise_version: Mapped[int] = mapped_column(Integer)
    issued_at: Mapped[datetime | None]
    deadline_at: Mapped[datetime | None]
    closed_at: Mapped[datetime | None]
    reveal_until: Mapped[datetime | None]


class DuelAnswer(Base):
    __tablename__ = "duel_answers"
    __table_args__ = (
        PrimaryKeyConstraint("duel_id", "user_id", "question_index", name="pk_duel_answers"),
        CheckConstraint("question_index >= 0", name="index_non_negative"),
        CheckConstraint("points >= 0", name="points_non_negative"),
        CheckConstraint("elapsed_ms >= 0", name="elapsed_non_negative"),
        CheckConstraint("correct OR points = 0", name="points_only_when_correct"),
        Index("ix_duel_answers_user_id", "user_id"),
    )

    duel_id: Mapped[str] = mapped_column(ForeignKey("duels.id", ondelete="CASCADE"))
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    question_index: Mapped[int] = mapped_column(SmallInteger)
    answer: Mapped[dict[str, Any] | None]
    correct: Mapped[bool] = mapped_column(Boolean)
    received_at: Mapped[datetime]
    elapsed_ms: Mapped[int] = mapped_column(Integer)
    points: Mapped[int] = mapped_column(Integer)
    response: Mapped[dict[str, Any] | None]   # the async answer response, replayed exactly as issued
