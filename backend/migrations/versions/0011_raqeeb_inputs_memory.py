"""Phase 17 private-input receipts and guarded memory (parallel p18/p19 revisions remain untouched).

0010 was reserved before Claude chose provisional named revisions; 0011 is independent on integrated 0009.
The later community/challenge integration must reconcile its chain without modifying this checkpoint's history.
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from pgvector.sqlalchemy import VECTOR
from sqlalchemy.dialects.postgresql import JSONB, UUID

revision: str = "0011"
down_revision: str | None = "0009"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # Provision the extension as the database administrator, outside public so test resets cannot drop it.
    # The migration never elevates an application role or substitutes an array for pgvector.
    op.execute("CREATE SCHEMA IF NOT EXISTS extensions")
    op.execute("CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA extensions")
    op.execute("SET LOCAL search_path TO public, extensions")
    op.create_table("raqeeb_memory",
        sa.Column("id", sa.Text(), primary_key=True),
        sa.Column("language", sa.Text(), nullable=False), sa.Column("question_class", sa.Text(), nullable=False),
        sa.Column("canonical_question", sa.Text(), nullable=False), sa.Column("embedding", VECTOR(1024)),
        sa.Column("core", JSONB(), nullable=False), sa.Column("source_digests", JSONB(), nullable=False),
        sa.Column("evidence", JSONB(), nullable=False), sa.Column("policy_version", sa.Text(), nullable=False),
        sa.Column("prompt_version", sa.Text(), nullable=False),
        sa.Column("origin_user_id", sa.Text(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("origin_message_id", sa.Text(), sa.ForeignKey("raqeeb_messages.id", ondelete="CASCADE"), nullable=False),
        sa.Column("namespace", UUID()), sa.Column("hits", sa.Integer(), server_default="0", nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint("id ~ '^mem_[0-9A-Za-z_]+$'", name=op.f("ck_raqeeb_memory_id_format")),
        sa.CheckConstraint("language IN ('ar','en')", name=op.f("ck_raqeeb_memory_language_valid")),
        sa.CheckConstraint("question_class IN ('general_knowledge','text_explanation')", name=op.f("ck_raqeeb_memory_class_valid")),
        sa.CheckConstraint("hits >= 0", name=op.f("ck_raqeeb_memory_hits_nonnegative")),
        sa.CheckConstraint("length(canonical_question) BETWEEN 1 AND 2000", name=op.f("ck_raqeeb_memory_question_bounded")),
        sa.UniqueConstraint("origin_message_id", name="uq_raqeeb_memory_origin_message_id"))
    op.create_index("ix_raqeeb_memory_lookup", "raqeeb_memory", ["language", "question_class", "policy_version", "prompt_version"])
    op.create_index("ix_raqeeb_memory_origin_user_id", "raqeeb_memory", ["origin_user_id"])
    op.create_index("ix_raqeeb_memory_embedding", "raqeeb_memory", ["embedding"], postgresql_using="hnsw",
                    postgresql_ops={"embedding": "extensions.vector_cosine_ops"})
    op.create_table("raqeeb_upload_receipts",
        sa.Column("id", sa.Text(), primary_key=True),
        sa.Column("user_id", sa.Text(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("message_id", sa.Text(), sa.ForeignKey("raqeeb_messages.id", ondelete="SET NULL")),
        sa.Column("request_hash", sa.Text(), nullable=False), sa.Column("object_key", sa.Text(), nullable=False),
        sa.Column("sha256", sa.Text(), nullable=False), sa.Column("kind", sa.Text(), nullable=False),
        sa.Column("filename", sa.Text(), nullable=False), sa.Column("mime", sa.Text(), nullable=False),
        sa.Column("size_bytes", sa.Integer(), nullable=False), sa.Column("duration_ms", sa.Integer()),
        sa.Column("pages", sa.Integer()), sa.Column("status", sa.Text(), server_default="pending", nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint("id ~ '^att_[0-9A-Za-z_]+$'", name=op.f("ck_raqeeb_upload_receipts_id_format")),
        sa.CheckConstraint("status IN ('pending','attached','deleted')", name=op.f("ck_raqeeb_upload_receipts_status_valid")),
        sa.CheckConstraint("kind IN ('audio','image','document')", name=op.f("ck_raqeeb_upload_receipts_kind_valid")),
        sa.CheckConstraint("size_bytes > 0", name=op.f("ck_raqeeb_upload_receipts_size_positive")),
        sa.UniqueConstraint("object_key", name="uq_raqeeb_upload_receipts_object_key"))
    op.create_index("ix_raqeeb_upload_receipts_user_id", "raqeeb_upload_receipts", ["user_id"])
    op.create_index("ix_raqeeb_upload_receipts_retention", "raqeeb_upload_receipts", ["status", "expires_at"])
    op.execute("""DO $$ DECLARE r text; BEGIN
        FOREACH r IN ARRAY ARRAY['qabas_app','qabas_worker','qabas_readonly'] LOOP
            IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname=r) THEN
                EXECUTE format('GRANT USAGE ON SCHEMA extensions TO %I', r);
                EXECUTE format('GRANT SELECT ON raqeeb_memory, raqeeb_upload_receipts TO %I', r);
                IF r <> 'qabas_readonly' THEN
                    EXECUTE format('GRANT INSERT, UPDATE, DELETE ON raqeeb_memory, raqeeb_upload_receipts TO %I', r);
                END IF;
            END IF;
        END LOOP;
    END $$""")


def downgrade() -> None:
    op.drop_table("raqeeb_upload_receipts")
    op.drop_table("raqeeb_memory")
    # Leave the administrator-provisioned extension for other databases/features/operators.
