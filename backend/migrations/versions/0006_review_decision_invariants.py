"""Gate decision invariants for the reviewer console (Phase 13; data model "Gate decisions are auditable").

* A Gate 2 approval always records the digest of the content it published (``published_digest``).
* One Gate 1 decision per run, and one final Gate 2 decision (approve or reject) per run and per lesson version:
  a replayed or concurrent decision can never add a second approval or overturn a recorded one. Any number of
  ``request_changes`` decisions may precede the final one (each reviews a different draft digest).

An existing row that already violates these rules stops the upgrade with its id instead of being rewritten.

Revision ID: 0006
Revises: 0005
"""

from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0006"
down_revision: str | None = "0005"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

FINAL = "gate = 2 AND decision IN ('approve', 'reject')"
VIOLATIONS = """
DO $$
DECLARE bad text;
BEGIN
    SELECT string_agg(id::text, ', ') INTO bad FROM review_decisions
     WHERE gate = 2 AND decision = 'approve' AND published_digest IS NULL;
    IF bad IS NOT NULL THEN
        RAISE EXCEPTION 'Gate 2 approvals without published_digest: %', bad;
    END IF;
    SELECT string_agg(run_id, ', ') INTO bad FROM (
        SELECT run_id FROM review_decisions WHERE gate = 1 GROUP BY run_id HAVING count(*) > 1
        UNION SELECT run_id FROM review_decisions WHERE run_id IS NOT NULL AND gate = 2 AND decision IN ('approve', 'reject')
              GROUP BY run_id HAVING count(*) > 1) runs;
    IF bad IS NOT NULL THEN
        RAISE EXCEPTION 'runs with more than one decision at a gate: %', bad;
    END IF;
    SELECT string_agg(lesson_version_id::text, ', ') INTO bad FROM (
        SELECT lesson_version_id FROM review_decisions WHERE lesson_version_id IS NOT NULL AND gate = 2 AND decision IN ('approve', 'reject')
         GROUP BY lesson_version_id HAVING count(*) > 1) versions;
    IF bad IS NOT NULL THEN
        RAISE EXCEPTION 'lesson versions with more than one final decision: %', bad;
    END IF;
END $$;
"""


def upgrade() -> None:
    op.execute(VIOLATIONS)
    op.create_check_constraint(
        op.f("ck_review_decisions_gate2_approve_publishes"), "review_decisions",
        "gate <> 2 OR decision <> 'approve' OR published_digest IS NOT NULL")
    op.create_index("uq_review_decisions_gate1_run", "review_decisions", ["run_id"], unique=True,
                    postgresql_where=sa.text("gate = 1"))
    op.create_index("uq_review_decisions_final_run", "review_decisions", ["run_id"], unique=True,
                    postgresql_where=sa.text(f"run_id IS NOT NULL AND {FINAL}"))
    op.create_index("uq_review_decisions_final_version", "review_decisions", ["lesson_version_id"], unique=True,
                    postgresql_where=sa.text(f"lesson_version_id IS NOT NULL AND {FINAL}"))


def downgrade() -> None:
    op.drop_index("uq_review_decisions_final_version", table_name="review_decisions")
    op.drop_index("uq_review_decisions_final_run", table_name="review_decisions")
    op.drop_index("uq_review_decisions_gate1_run", table_name="review_decisions")
    op.drop_constraint(op.f("ck_review_decisions_gate2_approve_publishes"), "review_decisions", type_="check")
