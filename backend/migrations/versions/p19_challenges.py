"""Challenges: duels, players, questions and answers (Phase 19; data model ``duels`` ... ``duel_answers``).

A closed duel (finished, expired, declined) never changes status and its result is written once; recorded answers
are never updated (custom SQLSTATE QB007 duel closed, QB004 insert-only).

Revision ID: p19_challenges (provisional; renumbered after the Phase 17 and Phase 18 integrations)
Revises: p18_community
"""

from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "p19_challenges"
down_revision: str | None = "p18_community"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

TRIGGERS = (
    """
    CREATE FUNCTION qabas_duel_guard() RETURNS trigger LANGUAGE plpgsql AS $$
    BEGIN
        IF OLD.status IN ('finished', 'expired', 'declined') AND (NEW.status <> OLD.status
                OR NEW.result IS DISTINCT FROM OLD.result OR NEW.finished_at IS DISTINCT FROM OLD.finished_at) THEN
            RAISE EXCEPTION 'duel % is closed (%)', OLD.id, OLD.status USING ERRCODE = 'QB007';
        END IF;
        RETURN NEW;
    END $$
    """,
    """
    CREATE TRIGGER duels_closed_guard BEFORE UPDATE ON duels
    FOR EACH ROW EXECUTE FUNCTION qabas_duel_guard()
    """,
    """
    CREATE TRIGGER duel_answers_insert_only BEFORE UPDATE ON duel_answers
    FOR EACH ROW EXECUTE FUNCTION qabas_insert_only()
    """,
)


def upgrade() -> None:
    op.create_table('duels',
    sa.Column('id', sa.Text(), nullable=False),
    sa.Column('preset', sa.Text(), nullable=False),
    sa.Column('mode', sa.Text(), server_default='live', nullable=False),
    sa.Column('status', sa.Text(), nullable=False),
    sa.Column('phase', sa.Text(), nullable=True),
    sa.Column('opponent_type', sa.Text(), nullable=False),
    sa.Column('bot_fill', sa.Boolean(), server_default='false', nullable=False),
    sa.Column('config', postgresql.JSONB(astext_type=sa.Text()), nullable=False),
    sa.Column('created_by', sa.Text(), nullable=False),
    sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.Column('expires_at', sa.DateTime(timezone=True), nullable=False),
    sa.Column('lobby_deadline_at', sa.DateTime(timezone=True), nullable=True),
    sa.Column('async_at', sa.DateTime(timezone=True), nullable=True),
    sa.Column('coordinator_epoch', sa.BigInteger(), server_default='0', nullable=False),
    sa.Column('result', postgresql.JSONB(astext_type=sa.Text()), nullable=True),
    sa.Column('finished_at', sa.DateTime(timezone=True), nullable=True),
    sa.CheckConstraint("(preset = 'duel' AND opponent_type IN ('bot', 'friend')) OR (preset = 'group' AND opponent_type = 'friends')", name=op.f('ck_duels_preset_opponents')),
    sa.CheckConstraint("(status = 'finished') = (result IS NOT NULL AND finished_at IS NOT NULL)", name=op.f('ck_duels_finished_has_result')),
    sa.CheckConstraint("id ~ '^duel_[0-9A-Za-z_]+$'", name=op.f('ck_duels_id_format')),
    sa.CheckConstraint("mode = 'live' OR (preset = 'duel' AND opponent_type = 'friend' AND async_at IS NOT NULL)", name=op.f('ck_duels_async_is_friend_duel')),
    sa.CheckConstraint("mode IN ('live', 'async')", name=op.f('ck_duels_mode_valid')),
    sa.CheckConstraint("opponent_type IN ('bot', 'friend', 'friends')", name=op.f('ck_duels_opponent_type_valid')),
    sa.CheckConstraint("phase IS NULL OR phase IN ('countdown', 'question', 'result', 'finished')", name=op.f('ck_duels_phase_valid')),
    sa.CheckConstraint("preset IN ('duel', 'group')", name=op.f('ck_duels_preset_valid')),
    sa.CheckConstraint("status IN ('pending', 'ready', 'in_progress', 'finished', 'expired', 'declined')", name=op.f('ck_duels_status_valid')),
    sa.CheckConstraint('coordinator_epoch >= 0', name=op.f('ck_duels_epoch_non_negative')),
    sa.CheckConstraint('expires_at > created_at', name=op.f('ck_duels_expires_after_created')),
    sa.ForeignKeyConstraint(['created_by'], ['users.id'], name=op.f('fk_duels_created_by_users'), ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id', name=op.f('pk_duels'))
    )
    op.create_index('ix_duels_created_by', 'duels', ['created_by'], unique=False)
    op.create_index('ix_duels_status_expires_at', 'duels', ['status', 'expires_at'], unique=False)
    op.create_table('duel_answers',
    sa.Column('duel_id', sa.Text(), nullable=False),
    sa.Column('user_id', sa.Text(), nullable=False),
    sa.Column('question_index', sa.SmallInteger(), nullable=False),
    sa.Column('answer', postgresql.JSONB(astext_type=sa.Text()), nullable=True),
    sa.Column('correct', sa.Boolean(), nullable=False),
    sa.Column('received_at', sa.DateTime(timezone=True), nullable=False),
    sa.Column('elapsed_ms', sa.Integer(), nullable=False),
    sa.Column('points', sa.Integer(), nullable=False),
    sa.Column('response', postgresql.JSONB(astext_type=sa.Text()), nullable=True),
    sa.CheckConstraint('correct OR points = 0', name=op.f('ck_duel_answers_points_only_when_correct')),
    sa.CheckConstraint('elapsed_ms >= 0', name=op.f('ck_duel_answers_elapsed_non_negative')),
    sa.CheckConstraint('points >= 0', name=op.f('ck_duel_answers_points_non_negative')),
    sa.CheckConstraint('question_index >= 0', name=op.f('ck_duel_answers_index_non_negative')),
    sa.ForeignKeyConstraint(['duel_id'], ['duels.id'], name=op.f('fk_duel_answers_duel_id_duels'), ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], name=op.f('fk_duel_answers_user_id_users'), ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('duel_id', 'user_id', 'question_index', name='pk_duel_answers')
    )
    op.create_index('ix_duel_answers_user_id', 'duel_answers', ['user_id'], unique=False)
    op.create_table('duel_players',
    sa.Column('duel_id', sa.Text(), nullable=False),
    sa.Column('user_id', sa.Text(), nullable=False),
    sa.Column('seat', sa.SmallInteger(), nullable=False),
    sa.Column('is_bot', sa.Boolean(), server_default='false', nullable=False),
    sa.Column('status', sa.Text(), nullable=False),
    sa.Column('joined_at', sa.DateTime(timezone=True), nullable=True),
    sa.Column('responded_at', sa.DateTime(timezone=True), nullable=True),
    sa.Column('forfeited', sa.Boolean(), server_default='false', nullable=False),
    sa.Column('completed_at', sa.DateTime(timezone=True), nullable=True),
    sa.Column('xp_awarded', sa.Integer(), nullable=True),
    sa.CheckConstraint("(status = 'joined') = (joined_at IS NOT NULL) OR status = 'left'", name=op.f('ck_duel_players_joined_has_time')),
    sa.CheckConstraint("NOT is_bot OR status = 'joined'", name=op.f('ck_duel_players_bots_join')),
    sa.CheckConstraint("status IN ('invited', 'joined', 'declined', 'left')", name=op.f('ck_duel_players_status_valid')),
    sa.CheckConstraint('seat BETWEEN 0 AND 6', name=op.f('ck_duel_players_seat_range')),
    sa.CheckConstraint('xp_awarded IS NULL OR xp_awarded >= 0', name=op.f('ck_duel_players_xp_non_negative')),
    sa.ForeignKeyConstraint(['duel_id'], ['duels.id'], name=op.f('fk_duel_players_duel_id_duels'), ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], name=op.f('fk_duel_players_user_id_users'), ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('duel_id', 'user_id', name='pk_duel_players'),
    sa.UniqueConstraint('duel_id', 'seat', name='uq_duel_players_duel_id_seat')
    )
    op.create_index('ix_duel_players_user_id', 'duel_players', ['user_id'], unique=False)
    op.create_table('duel_questions',
    sa.Column('id', sa.BigInteger(), sa.Identity(always=False), nullable=False),
    sa.Column('duel_id', sa.Text(), nullable=False),
    sa.Column('question_index', sa.SmallInteger(), nullable=False),
    sa.Column('user_id', sa.Text(), nullable=True),
    sa.Column('exercise_id', sa.Text(), nullable=False),
    sa.Column('exercise_version', sa.Integer(), nullable=False),
    sa.Column('issued_at', sa.DateTime(timezone=True), nullable=True),
    sa.Column('deadline_at', sa.DateTime(timezone=True), nullable=True),
    sa.Column('closed_at', sa.DateTime(timezone=True), nullable=True),
    sa.Column('reveal_until', sa.DateTime(timezone=True), nullable=True),
    sa.CheckConstraint('deadline_at IS NULL OR (issued_at IS NOT NULL AND deadline_at > issued_at)', name=op.f('ck_duel_questions_deadline_after_issue')),
    sa.CheckConstraint('question_index >= 0', name=op.f('ck_duel_questions_index_non_negative')),
    sa.CheckConstraint('user_id IS NULL OR (issued_at IS NOT NULL AND deadline_at IS NOT NULL)', name=op.f('ck_duel_questions_player_rows_are_issued')),
    sa.ForeignKeyConstraint(['duel_id'], ['duels.id'], name=op.f('fk_duel_questions_duel_id_duels'), ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['exercise_id', 'exercise_version'], ['exercise_versions.exercise_id', 'exercise_versions.version'], name='fk_duel_questions_exercise_versions'),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], name=op.f('fk_duel_questions_user_id_users'), ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id', name=op.f('pk_duel_questions'))
    )
    op.create_index('uq_duel_questions_exercise', 'duel_questions', ['duel_id', 'exercise_id'], unique=True, postgresql_where=sa.text('user_id IS NULL'))
    op.create_index('uq_duel_questions_player', 'duel_questions', ['duel_id', 'user_id', 'question_index'], unique=True, postgresql_where=sa.text('user_id IS NOT NULL'))
    op.create_index('uq_duel_questions_shared', 'duel_questions', ['duel_id', 'question_index'], unique=True, postgresql_where=sa.text('user_id IS NULL'))
    for statement in TRIGGERS:
        op.execute(statement)
    op.execute("SELECT qabas_apply_grants()")


def downgrade() -> None:
    op.execute("DROP TRIGGER IF EXISTS duel_answers_insert_only ON duel_answers")
    op.execute("DROP TRIGGER IF EXISTS duels_closed_guard ON duels")
    op.execute("DROP FUNCTION IF EXISTS qabas_duel_guard()")
    op.drop_index('uq_duel_questions_shared', table_name='duel_questions', postgresql_where=sa.text('user_id IS NULL'))
    op.drop_index('uq_duel_questions_player', table_name='duel_questions', postgresql_where=sa.text('user_id IS NOT NULL'))
    op.drop_index('uq_duel_questions_exercise', table_name='duel_questions', postgresql_where=sa.text('user_id IS NULL'))
    op.drop_table('duel_questions')
    op.drop_index('ix_duel_players_user_id', table_name='duel_players')
    op.drop_table('duel_players')
    op.drop_index('ix_duel_answers_user_id', table_name='duel_answers')
    op.drop_table('duel_answers')
    op.drop_index('ix_duels_status_expires_at', table_name='duels')
    op.drop_index('ix_duels_created_by', table_name='duels')
    op.drop_table('duels')
