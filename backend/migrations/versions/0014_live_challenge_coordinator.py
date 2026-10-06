"""Durable live challenge connections, journal and coordinator fencing (QB008).

Revision ID: 0014
Revises: 0013
Create Date: 2026-10-06 11:51:57.875958
"""

from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = '0014'
down_revision: str | None = '0013'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

TRIGGERS = (
    """
    CREATE FUNCTION qabas_assert_duel_epoch(did text) RETURNS void LANGUAGE plpgsql AS $$
    DECLARE actual bigint; supplied bigint;
    BEGIN
        SELECT coordinator_epoch INTO actual FROM duels WHERE id = did FOR UPDATE;
        supplied := NULLIF(current_setting('qabas.coordinator_epoch', true), '')::bigint;
        IF actual IS NULL OR supplied IS NULL OR supplied <> actual OR supplied <= 0 THEN
            RAISE EXCEPTION 'stale challenge coordinator' USING ERRCODE = 'QB008';
        END IF;
    END $$
    """,
    """
    CREATE FUNCTION qabas_duel_epoch_guard() RETURNS trigger LANGUAGE plpgsql AS $$
    DECLARE supplied bigint;
    BEGIN
        supplied := NULLIF(current_setting('qabas.coordinator_epoch', true), '')::bigint;
        IF NEW.coordinator_epoch < OLD.coordinator_epoch THEN
            RAISE EXCEPTION 'challenge epoch regressed' USING ERRCODE = 'QB008';
        END IF;
        IF NEW.coordinator_epoch IS DISTINCT FROM OLD.coordinator_epoch
                OR NEW.phase IS DISTINCT FROM OLD.phase OR NEW.starts_at IS DISTINCT FROM OLD.starts_at THEN
            IF supplied IS NULL OR supplied <> NEW.coordinator_epoch OR supplied <= 0 THEN
                RAISE EXCEPTION 'stale challenge coordinator' USING ERRCODE = 'QB008';
            END IF;
        END IF;
        IF OLD.starts_at IS NOT NULL AND NEW.starts_at IS DISTINCT FROM OLD.starts_at THEN
            RAISE EXCEPTION 'challenge countdown is immutable' USING ERRCODE = 'QB002';
        END IF;
        IF NEW.mode = 'live' AND NEW.phase = 'finished' AND OLD.phase IS DISTINCT FROM NEW.phase THEN
            IF (SELECT count(*) FROM duel_questions WHERE duel_id = NEW.id AND user_id IS NULL
                    AND closed_at IS NOT NULL) <> (NEW.config->>'question_count')::integer THEN
                RAISE EXCEPTION 'challenge has unclosed questions' USING ERRCODE = 'QB007';
            END IF;
        END IF;
        RETURN NEW;
    END $$
    """,
    """
    CREATE TRIGGER duels_epoch_guard BEFORE UPDATE ON duels
    FOR EACH ROW EXECUTE FUNCTION qabas_duel_epoch_guard()
    """,
    """
    CREATE FUNCTION qabas_live_question_guard() RETURNS trigger LANGUAGE plpgsql AS $$
    BEGIN
        IF NEW.duel_id IS DISTINCT FROM OLD.duel_id OR NEW.question_index IS DISTINCT FROM OLD.question_index
                OR NEW.exercise_id IS DISTINCT FROM OLD.exercise_id
                OR NEW.exercise_version IS DISTINCT FROM OLD.exercise_version
                OR NEW.user_id IS DISTINCT FROM OLD.user_id THEN
            RAISE EXCEPTION 'challenge question identity is immutable' USING ERRCODE = 'QB002';
        END IF;
        IF OLD.user_id IS NULL AND (NEW.issued_at IS DISTINCT FROM OLD.issued_at
                OR NEW.deadline_at IS DISTINCT FROM OLD.deadline_at OR NEW.closed_at IS DISTINCT FROM OLD.closed_at
                OR NEW.reveal_until IS DISTINCT FROM OLD.reveal_until
                OR NEW.result_snapshot IS DISTINCT FROM OLD.result_snapshot) THEN
            PERFORM qabas_assert_duel_epoch(NEW.duel_id);
            IF (OLD.issued_at IS NOT NULL AND NEW.issued_at IS DISTINCT FROM OLD.issued_at)
                OR (OLD.deadline_at IS NOT NULL AND NEW.deadline_at IS DISTINCT FROM OLD.deadline_at)
                OR (OLD.closed_at IS NOT NULL AND NEW.closed_at IS DISTINCT FROM OLD.closed_at)
                OR (OLD.reveal_until IS NOT NULL AND NEW.reveal_until IS DISTINCT FROM OLD.reveal_until)
                OR (OLD.result_snapshot IS NOT NULL AND NEW.result_snapshot IS DISTINCT FROM OLD.result_snapshot) THEN
                RAISE EXCEPTION 'challenge timing is immutable' USING ERRCODE = 'QB002';
            END IF;
        END IF;
        RETURN NEW;
    END $$
    """,
    """
    CREATE TRIGGER duel_questions_live_guard BEFORE UPDATE ON duel_questions
    FOR EACH ROW EXECUTE FUNCTION qabas_live_question_guard()
    """,
    """
    CREATE FUNCTION qabas_live_event_guard() RETURNS trigger LANGUAGE plpgsql AS $$
    BEGIN
        IF NEW.epoch IS NOT NULL THEN
            PERFORM qabas_assert_duel_epoch(NEW.duel_id);
            IF NEW.epoch <> NULLIF(current_setting('qabas.coordinator_epoch', true), '')::bigint THEN
                RAISE EXCEPTION 'stale challenge event' USING ERRCODE = 'QB008';
            END IF;
        END IF;
        RETURN NEW;
    END $$
    """,
    """
    CREATE TRIGGER duel_live_events_epoch_guard BEFORE INSERT ON duel_live_events
    FOR EACH ROW EXECUTE FUNCTION qabas_live_event_guard()
    """,
    """
    CREATE TRIGGER duel_live_events_insert_only BEFORE UPDATE ON duel_live_events
    FOR EACH ROW EXECUTE FUNCTION qabas_insert_only()
    """,
    """
    CREATE FUNCTION qabas_live_answer_guard() RETURNS trigger LANGUAGE plpgsql AS $$
    DECLARE d duels; p duel_players; q duel_questions; missing boolean;
    BEGIN
        SELECT * INTO d FROM duels WHERE id = NEW.duel_id FOR UPDATE;
        IF d.mode <> 'live' THEN RETURN NEW; END IF;
        missing := NEW.answer IS NULL OR NEW.answer = 'null'::jsonb;
        SELECT * INTO p FROM duel_players WHERE duel_id = NEW.duel_id AND user_id = NEW.user_id;
        SELECT * INTO q FROM duel_questions WHERE duel_id = NEW.duel_id
            AND question_index = NEW.question_index AND user_id IS NULL;
        IF p.user_id IS NULL OR q.id IS NULL OR (missing AND (NEW.correct OR NEW.points <> 0)) THEN
            RAISE EXCEPTION 'invalid challenge answer binding' USING ERRCODE = 'QB007';
        END IF;
        IF p.is_bot OR missing THEN PERFORM qabas_assert_duel_epoch(NEW.duel_id); END IF;
        IF d.status <> 'in_progress' OR d.phase IS DISTINCT FROM 'question' OR q.issued_at IS NULL
                OR q.closed_at IS NOT NULL THEN
            RAISE EXCEPTION 'challenge question is not open' USING ERRCODE = 'QB007';
        END IF;
        IF NOT missing AND (p.status <> 'joined' OR NEW.received_at < q.issued_at
                OR NEW.received_at > q.deadline_at) THEN
            RAISE EXCEPTION 'challenge answer is outside its window' USING ERRCODE = 'QB007';
        END IF;
        RETURN NEW;
    END $$
    """,
    """
    CREATE TRIGGER duel_answers_live_guard BEFORE INSERT ON duel_answers
    FOR EACH ROW EXECUTE FUNCTION qabas_live_answer_guard()
    """,
)

def upgrade() -> None:
    # ### commands auto generated by Alembic - please adjust! ###
    op.create_table('duel_connections',
    sa.Column('id', sa.Uuid(), nullable=False),
    sa.Column('duel_id', sa.Text(), nullable=False),
    sa.Column('user_id', sa.Text(), nullable=False),
    sa.Column('auth_session_id', sa.UUID(), nullable=False),
    sa.Column('connected_at', sa.DateTime(timezone=True), nullable=False),
    sa.Column('expires_at', sa.DateTime(timezone=True), nullable=False),
    sa.Column('closed_at', sa.DateTime(timezone=True), nullable=True),
    sa.CheckConstraint('expires_at > connected_at', name=op.f('ck_duel_connections_expiry_after_connect')),
    sa.ForeignKeyConstraint(['auth_session_id'], ['auth_sessions.id'], name=op.f('fk_duel_connections_auth_session_id_auth_sessions'), ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['duel_id'], ['duels.id'], name=op.f('fk_duel_connections_duel_id_duels'), ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], name=op.f('fk_duel_connections_user_id_users'), ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id', name=op.f('pk_duel_connections'))
    )
    op.create_index('ix_duel_connections_duel_id_user_id', 'duel_connections', ['duel_id', 'user_id'], unique=False)
    op.create_index('ix_duel_connections_user_id_expires_at', 'duel_connections', ['user_id', 'expires_at'], unique=False)
    op.create_table('duel_live_events',
    sa.Column('id', sa.BigInteger(), sa.Identity(always=False), nullable=False),
    sa.Column('duel_id', sa.Text(), nullable=False),
    sa.Column('event_key', sa.Text(), nullable=False),
    sa.Column('kind', sa.Text(), nullable=False),
    sa.Column('data', postgresql.JSONB(astext_type=sa.Text()), nullable=False),
    sa.Column('epoch', sa.BigInteger(), nullable=True),
    sa.Column('recorded_at', sa.DateTime(timezone=True), nullable=False),
    sa.CheckConstraint("(epoch IS NULL) = (kind LIKE 'input.%')", name=op.f('ck_duel_live_events_input_has_no_epoch')),
    sa.CheckConstraint('epoch IS NULL OR epoch > 0', name=op.f('ck_duel_live_events_epoch_positive')),
    sa.ForeignKeyConstraint(['duel_id'], ['duels.id'], name=op.f('fk_duel_live_events_duel_id_duels'), ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id', name=op.f('pk_duel_live_events')),
    sa.UniqueConstraint('duel_id', 'event_key', name=op.f('uq_duel_live_events_duel_id_event_key'))
    )
    op.create_index('ix_duel_live_events_duel_id_id', 'duel_live_events', ['duel_id', 'id'], unique=False)
    op.add_column('duel_players', sa.Column('ready_at', sa.DateTime(timezone=True), nullable=True))
    op.add_column('duel_players', sa.Column('disconnected_at', sa.DateTime(timezone=True), nullable=True))
    op.add_column('duels', sa.Column('live_connected_at', sa.DateTime(timezone=True), nullable=True))
    op.add_column('duels', sa.Column('starts_at', sa.DateTime(timezone=True), nullable=True))
    op.add_column('duel_questions', sa.Column('result_snapshot', postgresql.JSONB(), nullable=True))
    op.create_check_constraint(op.f('ck_duel_questions_timing_pair'), 'duel_questions',
                               '(issued_at IS NULL) = (deadline_at IS NULL)')
    op.create_check_constraint(op.f('ck_duel_questions_close_after_issue'), 'duel_questions',
                               'closed_at IS NULL OR (issued_at IS NOT NULL AND closed_at >= issued_at)')
    op.create_check_constraint(op.f('ck_duel_questions_reveal_after_close'), 'duel_questions',
                               '(closed_at IS NULL) = (reveal_until IS NULL) AND '
                               '(reveal_until IS NULL OR reveal_until >= closed_at)')
    op.create_check_constraint(op.f('ck_duel_questions_closed_has_public_result'), 'duel_questions',
                               'user_id IS NOT NULL OR closed_at IS NULL OR result_snapshot IS NOT NULL')
    for statement in TRIGGERS:
        op.execute(statement)
    op.execute("SELECT qabas_apply_grants()")
    # ### end Alembic commands ###


def downgrade() -> None:
    for name in ('ck_duel_questions_closed_has_public_result', 'ck_duel_questions_reveal_after_close',
                 'ck_duel_questions_close_after_issue',
                 'ck_duel_questions_timing_pair'):
        op.drop_constraint(op.f(name), 'duel_questions', type_='check')
    op.execute("DROP TRIGGER duel_answers_live_guard ON duel_answers")
    op.execute("DROP TRIGGER duel_live_events_insert_only ON duel_live_events")
    op.execute("DROP TRIGGER duel_live_events_epoch_guard ON duel_live_events")
    op.execute("DROP TRIGGER duel_questions_live_guard ON duel_questions")
    op.execute("DROP TRIGGER duels_epoch_guard ON duels")
    for name in ("qabas_live_answer_guard", "qabas_live_event_guard", "qabas_live_question_guard",
                 "qabas_duel_epoch_guard"):
        op.execute(f"DROP FUNCTION {name}()")
    op.execute("DROP FUNCTION qabas_assert_duel_epoch(text)")
    # ### commands auto generated by Alembic - please adjust! ###
    op.drop_column('duels', 'starts_at')
    op.drop_column('duel_questions', 'result_snapshot')
    op.drop_column('duels', 'live_connected_at')
    op.drop_column('duel_players', 'disconnected_at')
    op.drop_column('duel_players', 'ready_at')
    op.drop_index('ix_duel_live_events_duel_id_id', table_name='duel_live_events')
    op.drop_table('duel_live_events')
    op.drop_index('ix_duel_connections_user_id_expires_at', table_name='duel_connections')
    op.drop_index('ix_duel_connections_duel_id_user_id', table_name='duel_connections')
    op.drop_table('duel_connections')
    # ### end Alembic commands ###
