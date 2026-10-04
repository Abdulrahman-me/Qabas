"""Every active session carries its private learning snapshot (Phase 7 audit, decision D-76).

Migration 0003 added ``sessions.learning_snapshot`` (start mastery, review due dates, term-concept bindings,
pass threshold), which finish needs to report a session truthfully. A session started before 0003 has none, and
its start state cannot be reconstructed without guessing, so such a session could never be finished.

This migration makes that state impossible from here on with a CHECK: an ``active`` session must have a
snapshot. If legacy active sessions exist, the upgrade stops with instructions instead of silently changing
them; an operator then abandons them explicitly with ``scripts/abandon_legacy_sessions.py`` (answers'
effects stay, finish effects never happen, the learner simply starts the activity again) and re-runs the
upgrade. Finished and abandoned sessions are unaffected.

Revision ID: 0004
Revises: 0003
"""

from collections.abc import Sequence

from alembic import op

revision: str = "0004"
down_revision: str | None = "0003"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

GUARD = """
DO $$
DECLARE
    legacy integer;
BEGIN
    SELECT count(*) INTO legacy FROM sessions WHERE status = 'active' AND learning_snapshot IS NULL;
    IF legacy > 0 THEN
        RAISE EXCEPTION '% active session(s) started before the private learning snapshot existed and cannot be '
            'finished truthfully. Review them, abandon them with `uv run python scripts/abandon_legacy_sessions.py '
            '--confirm`, then upgrade again.', legacy;
    END IF;
END $$
"""


def upgrade() -> None:
    # A SQL guard rather than a Python check, so rendered (offline) SQL carries it too.
    op.execute(GUARD)
    op.create_check_constraint(op.f("ck_sessions_active_has_learning_snapshot"), "sessions",
                               "status <> 'active' OR learning_snapshot IS NOT NULL")


def downgrade() -> None:
    op.drop_constraint(op.f("ck_sessions_active_has_learning_snapshot"), "sessions", type_="check")
