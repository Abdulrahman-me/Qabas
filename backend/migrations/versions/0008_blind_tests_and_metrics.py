"""Blind tests and learning-metric facts (Phase 15; data model ``blind_pairs``/``blind_responses``).

Blind pairs and responses are review audit data: runtime roles may not delete them, and responses are
insert-only. Metric facts are a recomputable outbox effect owned by the learner (purged with the account).

Revision ID: 0008
Revises: 0007
"""
from __future__ import annotations

from collections.abc import Sequence
from importlib import import_module

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0008"
down_revision: str | None = "0007"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

base = import_module("migrations.versions.0005_factory_runs")
media = import_module("migrations.versions.0007_media_receipts")
PREVIOUS_GRANTS: str = media.GRANTS
GRANTS = base.GRANTS.format(
    no_delete=base.NO_DELETE_AFTER + ", media_jobs, media_assets, blind_pairs, blind_responses").replace(
    "REVOKE UPDATE ON review_decisions, session_answers",
    "REVOKE UPDATE ON media_jobs, media_assets, blind_responses, review_decisions, session_answers")


def upgrade() -> None:
    op.create_table(
        "blind_pairs",
        sa.Column("id", sa.Text(), primary_key=True),
        sa.Column("lesson_version_a", postgresql.UUID(), sa.ForeignKey("lesson_versions.id",
                  name=op.f("fk_blind_pairs_lesson_version_a_lesson_versions")), nullable=False),
        sa.Column("lesson_version_b", postgresql.UUID(), sa.ForeignKey("lesson_versions.id",
                  name=op.f("fk_blind_pairs_lesson_version_b_lesson_versions")), nullable=False),
        sa.Column("gold_side", sa.Text(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("id ~ '^pair_[0-9A-Za-z_]+$'", name=op.f("ck_blind_pairs_id_format")),
        sa.CheckConstraint("lesson_version_a <> lesson_version_b", name=op.f("ck_blind_pairs_distinct_versions")),
        sa.CheckConstraint("gold_side IN ('a', 'b')", name=op.f("ck_blind_pairs_gold_side_valid")),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_blind_pairs")),
    )
    op.create_table(
        "blind_responses",
        sa.Column("pair_id", sa.Text(), sa.ForeignKey("blind_pairs.id",
                  name=op.f("fk_blind_responses_pair_id_blind_pairs")), nullable=False),
        sa.Column("reviewer_id", sa.Text(), sa.ForeignKey("users.id",
                  name=op.f("fk_blind_responses_reviewer_id_users")), nullable=False),
        sa.Column("clearer", sa.Text(), nullable=False),
        sa.Column("more_accurate", sa.Text(), nullable=False),
        sa.Column("guessed_handwritten", sa.Text(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("clearer IN ('a', 'b', 'same')", name=op.f("ck_blind_responses_clearer_valid")),
        sa.CheckConstraint("more_accurate IN ('a', 'b', 'same')", name=op.f("ck_blind_responses_more_accurate_valid")),
        sa.CheckConstraint("guessed_handwritten IN ('a', 'b', 'unsure')", name=op.f("ck_blind_responses_guess_valid")),
        sa.PrimaryKeyConstraint("pair_id", "reviewer_id", name=op.f("pk_blind_responses")),
    )
    op.create_index("ix_blind_responses_reviewer_id", "blind_responses", ["reviewer_id"])
    op.create_table(
        "metric_unit_facts",
        sa.Column("user_id", sa.Text(), sa.ForeignKey("users.id", ondelete="CASCADE",
                  name=op.f("fk_metric_unit_facts_user_id_users")), nullable=False),
        sa.Column("unit_id", sa.Text(), sa.ForeignKey("units.id",
                  name=op.f("fk_metric_unit_facts_unit_id_units")), nullable=False),
        sa.Column("started", sa.Boolean(), nullable=False),
        sa.Column("completed", sa.Boolean(), nullable=False),
        sa.Column("pretest_percent", sa.SmallInteger(), nullable=True),
        sa.Column("first_post_percent", sa.SmallInteger(), nullable=True),
        sa.Column("refreshed_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("pretest_percent IS NULL OR pretest_percent BETWEEN 0 AND 100",
                           name=op.f("ck_metric_unit_facts_pretest_range")),
        sa.CheckConstraint("first_post_percent IS NULL OR first_post_percent BETWEEN 0 AND 100",
                           name=op.f("ck_metric_unit_facts_post_range")),
        sa.CheckConstraint("started OR NOT completed", name=op.f("ck_metric_unit_facts_completed_after_started")),
        sa.PrimaryKeyConstraint("user_id", "unit_id", name=op.f("pk_metric_unit_facts")),
    )
    op.create_index("ix_metric_unit_facts_unit_id", "metric_unit_facts", ["unit_id"])
    op.create_table(
        "metric_learner_facts",
        sa.Column("user_id", sa.Text(), sa.ForeignKey("users.id", ondelete="CASCADE",
                  name=op.f("fk_metric_learner_facts_user_id_users")), nullable=False),
        sa.Column("misconceptions_activated", sa.Integer(), nullable=False),
        sa.Column("misconceptions_resolved", sa.Integer(), nullable=False),
        sa.Column("refreshed_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("misconceptions_activated >= 0 AND misconceptions_resolved >= 0",
                           name=op.f("ck_metric_learner_facts_non_negative")),
        sa.PrimaryKeyConstraint("user_id", name=op.f("pk_metric_learner_facts")),
    )
    op.execute("""CREATE TRIGGER blind_responses_insert_only BEFORE UPDATE OR DELETE ON blind_responses
                  FOR EACH ROW EXECUTE FUNCTION qabas_insert_only()""")
    op.execute(GRANTS)
    op.execute("SELECT qabas_apply_grants()")


def downgrade() -> None:
    op.execute(PREVIOUS_GRANTS)
    op.execute("SELECT qabas_apply_grants()")
    op.execute("DROP TRIGGER IF EXISTS blind_responses_insert_only ON blind_responses")
    op.drop_table("metric_learner_facts")
    op.drop_index("ix_metric_unit_facts_unit_id", table_name="metric_unit_facts")
    op.drop_table("metric_unit_facts")
    op.drop_index("ix_blind_responses_reviewer_id", table_name="blind_responses")
    op.drop_table("blind_responses")
    op.drop_table("blind_pairs")
