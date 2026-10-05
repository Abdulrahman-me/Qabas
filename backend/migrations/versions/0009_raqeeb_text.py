"""Raqeeb conversations, durable processing and benchmark storage. Revision 0009, revises 0008."""

from __future__ import annotations

from collections.abc import Sequence
from importlib import import_module

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import JSONB, UUID

revision: str = "0009"
down_revision: str | None = "0008"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None
previous = import_module("migrations.versions.0008_blind_tests_and_metrics")
GRANTS = previous.GRANTS.replace("blind_pairs, blind_responses", "blind_pairs, blind_responses, benchmark_runs").replace(
    "media_assets, blind_responses, review_decisions", "media_assets, blind_responses, benchmark_runs, review_decisions")


def upgrade() -> None:
    op.create_table("raqeeb_conversations",
        sa.Column("id", sa.Text(), primary_key=True),
        sa.Column("user_id", sa.Text(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("title", sa.Text()), sa.Column("context", JSONB()),
        sa.Column("language", sa.Text(), nullable=False), sa.Column("track", sa.Text(), nullable=False),
        sa.Column("context_snapshot", JSONB(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("id ~ '^conv_[0-9A-Za-z_]+$'", name=op.f("ck_raqeeb_conversations_id_format")))
    op.create_index("ix_raqeeb_conversations_user_id", "raqeeb_conversations", ["user_id"])
    columns: list[sa.Column] = [
        sa.Column("id", sa.Text(), primary_key=True),
        sa.Column("conversation_id", sa.Text(), sa.ForeignKey("raqeeb_conversations.id", ondelete="CASCADE"),
                  nullable=False),
        sa.Column("reply_to", sa.Text(), sa.ForeignKey("raqeeb_messages.id", ondelete="CASCADE")),
        sa.Column("role", sa.Text(), nullable=False), sa.Column("status", sa.Text(), nullable=False),
        sa.Column("stage", sa.Text(), nullable=False), sa.Column("text", sa.Text()),
        sa.Column("attachments", JSONB(), nullable=False),
        sa.Column("abstained", sa.Boolean()), sa.Column("lease", UUID()),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("completed_at", sa.DateTime(timezone=True)),
    ]
    columns += [sa.Column(name, sa.Text()) for name in ("feedback", "feedback_reason", "feedback_comment")]
    columns += [sa.Column(name, JSONB(), nullable=name not in ("trace", "input_snapshot")) for name in (
        "understood_input", "classification", "blocks", "citations", "terms", "suggested_lessons", "error",
        "trace", "input_snapshot")]
    op.create_table("raqeeb_messages", *columns,
        sa.CheckConstraint("id ~ '^msg_[0-9A-Za-z_]+$'", name=op.f("ck_raqeeb_messages_id_format")),
        sa.CheckConstraint("(role = 'user' AND status = 'received') OR "
                           "(role = 'assistant' AND status IN ('processing','completed','failed'))",
                           name=op.f("ck_raqeeb_messages_role_status")),
        sa.CheckConstraint("stage IN ('received','reading_inputs','classifying','retrieving','verifying','writing',"
                           "'adapting','done')", name=op.f("ck_raqeeb_messages_stage_valid")),
        sa.CheckConstraint("feedback IS NULL OR (status = 'completed' AND feedback IN ('up','down'))",
                           name=op.f("ck_raqeeb_messages_feedback_valid")),
        sa.CheckConstraint("(role = 'assistant') = (reply_to IS NOT NULL)",
                           name=op.f("ck_raqeeb_messages_reply_role_valid")),
        sa.CheckConstraint("status <> 'completed' OR (completed_at IS NOT NULL AND stage = 'done' AND "
                           "understood_input IS NOT NULL AND classification IS NOT NULL AND abstained IS NOT NULL "
                           "AND blocks IS NOT NULL AND citations IS NOT NULL AND terms IS NOT NULL "
                           "AND suggested_lessons IS NOT NULL)",
                           name=op.f("ck_raqeeb_messages_completion_valid")),
        sa.UniqueConstraint("reply_to", name="uq_raqeeb_messages_reply_to"))
    op.create_index("uq_raqeeb_messages_processing", "raqeeb_messages", ["conversation_id"], unique=True,
                    postgresql_where=sa.text("status = 'processing'"))
    op.create_index("ix_raqeeb_messages_conversation_id", "raqeeb_messages", ["conversation_id"])
    op.create_table("benchmark_runs", sa.Column("id", UUID(), primary_key=True),
        sa.Column("run_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("question_count", sa.Integer(), nullable=False),
        sa.Column("results", JSONB(), nullable=False), sa.Column("provenance", JSONB(), nullable=False),
        sa.Column("digest", sa.Text(), nullable=False), sa.Column("synthetic", sa.Boolean(), nullable=False),
        sa.CheckConstraint("question_count > 0", name=op.f("ck_benchmark_runs_question_count_positive")))
    op.execute("""CREATE FUNCTION qabas_raqeeb_immutable() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN
        IF OLD.role = 'user' OR OLD.status IN ('completed','failed') THEN
            IF (to_jsonb(OLD) - ARRAY['feedback','feedback_reason','feedback_comment']) IS DISTINCT FROM
               (to_jsonb(NEW) - ARRAY['feedback','feedback_reason','feedback_comment']) THEN
                RAISE EXCEPTION 'terminal Raqeeb content is immutable';
            END IF;
        END IF;
        RETURN NEW;
    END $$""")
    op.execute("CREATE TRIGGER raqeeb_immutable BEFORE UPDATE ON raqeeb_messages "
               "FOR EACH ROW EXECUTE FUNCTION qabas_raqeeb_immutable()")
    op.execute("CREATE TRIGGER benchmark_runs_insert_only BEFORE UPDATE OR DELETE ON benchmark_runs "
               "FOR EACH ROW EXECUTE FUNCTION qabas_insert_only()")
    op.execute(GRANTS)
    op.execute("SELECT qabas_apply_grants()")


def downgrade() -> None:
    op.execute(previous.GRANTS)
    op.execute("SELECT qabas_apply_grants()")
    op.drop_table("benchmark_runs")
    op.drop_table("raqeeb_messages")
    op.execute("DROP FUNCTION qabas_raqeeb_immutable()")
    op.drop_table("raqeeb_conversations")
