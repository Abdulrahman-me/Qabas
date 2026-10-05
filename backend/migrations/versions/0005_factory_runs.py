"""Lesson Factory runs (data model ``factory_runs`` with rev 10 ``review_digest`` and ``cost``).

Also binds the two columns that waited for this table: ``review_decisions.run_id`` and
``lesson_versions.run_id`` become foreign keys (an orphaned value stops the upgrade with its id), and runtime
roles may not delete factory runs (audit history), like the other content and review tables.

Revision ID: 0005
Revises: 0004
"""

from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0005"
down_revision: str | None = "0004"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


NO_DELETE_BEFORE = ("units, concepts, lessons, exercises, sources, terms, misconceptions, lesson_versions, "
                    "exercise_versions, scene_versions, scene_assets, claims, sentences, review_decisions")
NO_DELETE_AFTER = NO_DELETE_BEFORE + ", factory_runs"
GRANTS = """
CREATE OR REPLACE FUNCTION qabas_apply_grants() RETURNS void LANGUAGE plpgsql AS $$
DECLARE
    role_name text;
    no_delete text := '{no_delete}';
BEGIN
    FOREACH role_name IN ARRAY ARRAY['qabas_app', 'qabas_worker'] LOOP
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = role_name) THEN
            EXECUTE format('GRANT USAGE ON SCHEMA public TO %I', role_name);
            EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO %I', role_name);
            EXECUTE format('GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO %I', role_name);
            EXECUTE format('REVOKE DELETE ON %s FROM %I', no_delete, role_name);
            EXECUTE format('REVOKE UPDATE ON review_decisions, session_answers FROM %I', role_name);
            EXECUTE format('REVOKE INSERT, UPDATE, DELETE ON alembic_version FROM %I', role_name);
        END IF;
    END LOOP;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'qabas_readonly') THEN
        GRANT USAGE ON SCHEMA public TO qabas_readonly;
        GRANT SELECT ON ALL TABLES IN SCHEMA public TO qabas_readonly;
    END IF;
END $$
"""
ORPHANS = """DO $$
DECLARE orphan text;
BEGIN
    SELECT run_id INTO orphan FROM (
        SELECT run_id FROM review_decisions WHERE run_id IS NOT NULL
        UNION ALL SELECT run_id FROM lesson_versions WHERE run_id IS NOT NULL) refs LIMIT 1;
    IF orphan IS NOT NULL THEN
        RAISE EXCEPTION 'run_id % refers to no factory run; resolve it before migrating', orphan;
    END IF;
END $$"""


def upgrade() -> None:
    op.create_table('factory_runs',
    sa.Column('id', sa.Text(), nullable=False),
    sa.Column('unit_id', sa.Text(), nullable=False),
    sa.Column('lesson_id', sa.Text(), nullable=False),
    sa.Column('position_index', sa.Integer(), nullable=False),
    sa.Column('lesson_type', sa.Text(), nullable=False),
    sa.Column('brief', sa.Text(), nullable=False),
    sa.Column('status', sa.Text(), server_default='running', nullable=False),
    sa.Column('stage', sa.Text(), server_default='plan', nullable=False),
    sa.Column('attempt', sa.Integer(), server_default='1', nullable=False),
    sa.Column('stages', postgresql.JSONB(astext_type=sa.Text()), nullable=False),
    sa.Column('plan', postgresql.JSONB(astext_type=sa.Text()), nullable=True),
    sa.Column('artifacts', postgresql.JSONB(astext_type=sa.Text()), server_default=sa.text("'{}'::jsonb"), nullable=False),
    sa.Column('qa_report', postgresql.JSONB(astext_type=sa.Text()), nullable=True),
    sa.Column('gate1_decision', postgresql.JSONB(astext_type=sa.Text()), nullable=True),
    sa.Column('gate2_decision', postgresql.JSONB(astext_type=sa.Text()), nullable=True),
    sa.Column('stage_timings', postgresql.JSONB(astext_type=sa.Text()), server_default=sa.text("'{}'::jsonb"), nullable=False),
    sa.Column('attempts', postgresql.JSONB(astext_type=sa.Text()), server_default=sa.text("'[]'::jsonb"), nullable=False),
    sa.Column('review_started_at', sa.DateTime(timezone=True), nullable=True),
    sa.Column('review_finished_at', sa.DateTime(timezone=True), nullable=True),
    sa.Column('published_lesson_id', sa.Text(), nullable=True),
    sa.Column('published_version', sa.Integer(), nullable=True),
    sa.Column('review_digest', sa.Text(), nullable=True),
    sa.Column('cost', postgresql.JSONB(astext_type=sa.Text()), server_default=sa.text('\'{"calls": []}\'::jsonb'), nullable=False),
    sa.Column('budget_tokens', sa.Integer(), nullable=True),
    sa.Column('error', postgresql.JSONB(astext_type=sa.Text()), nullable=True),
    sa.Column('created_by', sa.Text(), nullable=False),
    sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.CheckConstraint("(status = 'failed') = (error IS NOT NULL)", name=op.f('ck_factory_runs_error_iff_failed')),
    sa.CheckConstraint("(status = 'published') = (published_lesson_id IS NOT NULL AND published_version IS NOT NULL)", name=op.f('ck_factory_runs_published_iff_status')),
    sa.CheckConstraint("(status IN ('awaiting_gate1', 'awaiting_gate2')) = (review_digest IS NOT NULL)", name=op.f('ck_factory_runs_digest_iff_at_gate')),
    sa.CheckConstraint("id ~ '^run_[0-9A-Za-z_]+$'", name=op.f('ck_factory_runs_id_format')),
    sa.CheckConstraint("lesson_type IN ('concept', 'story', 'practice')", name=op.f('ck_factory_runs_lesson_type_valid')),
    sa.CheckConstraint("review_digest IS NULL OR review_digest ~ '^[0-9a-f]{64}$'", name=op.f('ck_factory_runs_review_digest_format')),
    sa.CheckConstraint("stage IN ('plan', 'decompose', 'retrieve', 'verify_evidence', 'write', 'exercises', 'glossary', 'localize', 'visuals', 'scene_author', 'scene_render', 'narration', 'qa')", name=op.f('ck_factory_runs_stage_valid')),
    sa.CheckConstraint("status <> 'awaiting_gate1' OR plan IS NOT NULL", name=op.f('ck_factory_runs_gate1_has_plan')),
    sa.CheckConstraint("status <> 'awaiting_gate2' OR qa_report IS NOT NULL", name=op.f('ck_factory_runs_gate2_has_qa_report')),
    sa.CheckConstraint("status IN ('running', 'awaiting_gate1', 'awaiting_gate2', 'published', 'rejected', 'failed')", name=op.f('ck_factory_runs_status_valid')),
    sa.CheckConstraint('attempt >= 1', name=op.f('ck_factory_runs_attempt_positive')),
    sa.CheckConstraint('budget_tokens IS NULL OR budget_tokens > 0', name=op.f('ck_factory_runs_budget_positive')),
    sa.CheckConstraint('position_index >= 0', name=op.f('ck_factory_runs_position_index_non_negative')),
    sa.ForeignKeyConstraint(['created_by'], ['users.id'], name=op.f('fk_factory_runs_created_by_users')),
    sa.ForeignKeyConstraint(['lesson_id', 'unit_id', 'position_index'], ['curriculum_slots.lesson_id', 'curriculum_slots.unit_id', 'curriculum_slots.index'], name='fk_factory_runs_slot'),
    sa.ForeignKeyConstraint(['unit_id'], ['units.id'], name=op.f('fk_factory_runs_unit_id_units')),
    sa.PrimaryKeyConstraint('id', name=op.f('pk_factory_runs'))
    )
    op.create_index('ix_factory_runs_status', 'factory_runs', ['status'], unique=False)
    op.create_index('uq_factory_runs_active_slot', 'factory_runs', ['lesson_id'], unique=True, postgresql_where=sa.text("status IN ('running', 'awaiting_gate1', 'awaiting_gate2')"))
    op.execute(ORPHANS)
    op.create_foreign_key(op.f("fk_review_decisions_run_id_factory_runs"), "review_decisions", "factory_runs",
                          ["run_id"], ["id"])
    op.create_foreign_key(op.f("fk_lesson_versions_run_id_factory_runs"), "lesson_versions", "factory_runs",
                          ["run_id"], ["id"])
    op.execute(GRANTS.format(no_delete=NO_DELETE_AFTER))
    op.execute("SELECT qabas_apply_grants()")


def downgrade() -> None:
    op.execute(GRANTS.format(no_delete=NO_DELETE_BEFORE))
    op.drop_constraint(op.f("fk_lesson_versions_run_id_factory_runs"), "lesson_versions", type_="foreignkey")
    op.drop_constraint(op.f("fk_review_decisions_run_id_factory_runs"), "review_decisions", type_="foreignkey")
    op.drop_index('uq_factory_runs_active_slot', table_name='factory_runs', postgresql_where=sa.text("status IN ('running', 'awaiting_gate1', 'awaiting_gate2')"))
    op.drop_index('ix_factory_runs_status', table_name='factory_runs')
    op.drop_table('factory_runs')
