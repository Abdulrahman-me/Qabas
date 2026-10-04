"""Private learning snapshots, cross-session rewards and exact daily duration.

Revision ID: 0003
Revises: 0002
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0003"
down_revision: str | None = "0002"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("sessions", sa.Column("learning_snapshot", postgresql.JSONB(), nullable=True))
    op.alter_column("sessions", "duration_ms", type_=sa.BigInteger(), existing_type=sa.Integer())
    op.add_column("session_answers", sa.Column("misconception_changes", postgresql.JSONB(), nullable=True))
    op.add_column("xp_events", sa.Column("reward_key", sa.Text(), nullable=True))
    op.create_unique_constraint("uq_xp_events_reward", "xp_events", ["user_id", "reason", "reward_key"])
    # Preserve every historical grant and issued evaluation. The earliest existing grant claims its reward.
    op.execute("""UPDATE xp_events x SET reward_key = r.reward_key FROM (
        SELECT DISTINCT ON (user_id, reason, split_part(ref_id, ':', 2)) id,
            'exercise:' || split_part(ref_id, ':', 2) AS reward_key
        FROM xp_events WHERE reason = 'recitation_passed' AND ref_type = 'session_exercise'
        ORDER BY user_id, reason, split_part(ref_id, ':', 2), id
    ) r WHERE x.id = r.id""")
    op.add_column("daily_activity", sa.Column("duration_ms", sa.BigInteger(), nullable=False, server_default="0"))
    op.execute("UPDATE daily_activity SET duration_ms = minutes::bigint * 60000")
    op.create_check_constraint(op.f("ck_daily_activity_duration_non_negative"), "daily_activity", "duration_ms >= 0")
    op.execute("""CREATE FUNCTION qabas_learning_snapshot_guard() RETURNS trigger LANGUAGE plpgsql AS $$
        BEGIN
            IF NEW.learning_snapshot IS DISTINCT FROM OLD.learning_snapshot THEN
                RAISE EXCEPTION 'private learning snapshot is immutable' USING ERRCODE = 'QB003';
            END IF;
            RETURN NEW;
        END $$""")
    op.execute("CREATE TRIGGER learning_snapshot_guard BEFORE UPDATE ON sessions "
               "FOR EACH ROW EXECUTE FUNCTION qabas_learning_snapshot_guard()")
    op.execute("SELECT qabas_apply_grants()")


def downgrade() -> None:
    op.execute("DROP TRIGGER learning_snapshot_guard ON sessions")
    op.execute("DROP FUNCTION qabas_learning_snapshot_guard()")
    op.drop_constraint(op.f("ck_daily_activity_duration_non_negative"), "daily_activity", type_="check")
    op.drop_column("daily_activity", "duration_ms")
    op.drop_constraint("uq_xp_events_reward", "xp_events", type_="unique")
    op.drop_column("xp_events", "reward_key")
    op.drop_column("session_answers", "misconception_changes")
    op.drop_column("sessions", "learning_snapshot")
    op.alter_column("sessions", "duration_ms", type_=sa.Integer(), existing_type=sa.BigInteger())
