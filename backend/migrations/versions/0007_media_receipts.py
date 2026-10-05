"""Durable, append-only media jobs and reviewed production receipts.

Revision ID: 0007
Revises: 0006
"""
from __future__ import annotations

from collections.abc import Sequence
from importlib import import_module

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0007"
down_revision: str | None = "0006"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

previous = import_module("migrations.versions.0005_factory_runs")
PREVIOUS_GRANTS: str = previous.GRANTS.format(no_delete=previous.NO_DELETE_AFTER)
GRANTS = previous.GRANTS.format(no_delete=previous.NO_DELETE_AFTER + ", media_jobs, media_assets").replace(
    "REVOKE UPDATE ON review_decisions, session_answers",
    "REVOKE UPDATE ON media_jobs, media_assets, review_decisions, session_answers")


def upgrade() -> None:
    op.create_table("media_jobs",
        sa.Column("id", sa.Text(), primary_key=True),
        sa.Column("run_id", sa.Text(), sa.ForeignKey("factory_runs.id"), nullable=False),
        sa.Column("input_sha256", sa.Text(), nullable=False),
        sa.Column("output_sha256", sa.Text(), nullable=False),
        sa.Column("output", postgresql.JSONB(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("id ~ '^[0-9a-f]{64}$'", name=op.f("ck_media_jobs_id_format")),
        sa.CheckConstraint("input_sha256 ~ '^[0-9a-f]{64}$' AND output_sha256 ~ '^[0-9a-f]{64}$'",
                           name=op.f("ck_media_jobs_digests_format")))
    op.create_table("media_assets",
        sa.Column("id", sa.Text(), primary_key=True),
        sa.Column("content_key", sa.Text(), nullable=False),
        sa.Column("sha256", sa.Text(), nullable=False),
        sa.Column("receipt", postgresql.JSONB(), nullable=False),
        sa.Column("review_decision_id", postgresql.UUID(), sa.ForeignKey("review_decisions.id"), nullable=False),
        sa.Column("published_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("id ~ '^[0-9a-f]{64}$'", name=op.f("ck_media_assets_id_format")),
        sa.CheckConstraint("sha256 ~ '^[0-9a-f]{64}$'", name=op.f("ck_media_assets_sha256_format")))
    op.create_index(op.f("ix_media_assets_content_key"), "media_assets", ["content_key"])
    for table in ("media_jobs", "media_assets"):
        op.execute(f"CREATE TRIGGER {table}_insert_only BEFORE UPDATE OR DELETE ON {table} "
                   "FOR EACH ROW EXECUTE FUNCTION qabas_insert_only()")
    op.execute(GRANTS)
    op.execute("SELECT qabas_apply_grants()")


def downgrade() -> None:
    op.drop_table("media_assets")
    op.drop_table("media_jobs")
    op.execute(PREVIOUS_GRANTS)
    op.execute("SELECT qabas_apply_grants()")
