"""Curriculum slots and content identity (Phase 4).

* ``curriculum_slots``: the declared curriculum positions (unit, 0-based index) and the canonical lesson ID
  for each. ``lessons`` gains a composite FK to its slot, so a lesson exists only in a declared position and
  can never drift from it (one lesson per slot, AD-34).
* ``lessons.index`` becomes 0-based, as the contract's ``JLesson.index`` and the test-curriculum fixtures
  define it (decision D-30; migration 0001 assumed 1-based).
* ``lesson_versions.origin``: factory | gold_import | test_fixture (decision D-29).
* ``sources.provider`` and ``sources.excerpt`` become required, as in the contract's ``Source``.
* Claim and sentence ids lose their prefix CHECK: they are authored per lesson version and the contract
  fixtures use ids such as ``s1`` (decision D-33).
* Exercise identity: ``exercises.type`` and ``exercises.purpose`` are immutable. Translations keep an
  exercise's identity and type; genuinely different content needs a new identity (SEED_AND_IMPORT).
  Custom SQLSTATE QB006.

No deployment has data, but the migration still moves any existing lesson rows deterministically
(1-based to 0-based positions, a backfilled slot per lesson); the downgrade reverses it.

Revision ID: 0002
Revises: 0001
Create Date: 2026-10-04
"""

from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0002"
down_revision: str | None = "0001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

ORIGINS = "'factory', 'gold_import', 'test_fixture'"
PROVIDERS = "'tafsir_center', 'quran_com', 'hadeethenc', 'quranenc', 'islamhouse', 'dorar'"


def upgrade() -> None:
    op.create_table(
        "curriculum_slots",
        sa.Column("lesson_id", sa.Text(), nullable=False),
        sa.Column("unit_id", sa.Text(), nullable=False),
        sa.Column("index", sa.Integer(), nullable=False),
        sa.Column("working_title", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("focus", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.CheckConstraint("lesson_id ~ '^les_[0-9A-Za-z_]+$'", name=op.f("ck_curriculum_slots_lesson_id_format")),
        sa.CheckConstraint("index >= 0", name=op.f("ck_curriculum_slots_index_non_negative")),
        sa.ForeignKeyConstraint(["unit_id"], ["units.id"], name=op.f("fk_curriculum_slots_unit_id_units")),
        sa.PrimaryKeyConstraint("lesson_id", name=op.f("pk_curriculum_slots")),
        sa.UniqueConstraint("lesson_id", "unit_id", "index", name="uq_curriculum_slots_position"),
        sa.UniqueConstraint("unit_id", "index", name="uq_curriculum_slots_unit_id_index"),
    )

    op.drop_constraint(op.f("ck_lessons_index_positive"), "lessons", type_="check")
    # Existing rows (none in any deployment) move from 1-based to 0-based positions. Negating first keeps
    # UNIQUE (unit_id, index) valid row by row while the values shift.
    op.execute("UPDATE lessons SET index = -index")
    op.execute("UPDATE lessons SET index = -index - 1")
    op.create_check_constraint(op.f("ck_lessons_index_non_negative"), "lessons", "index >= 0")
    # Every existing lesson gets the slot it occupies; the curriculum seed then supplies working titles.
    op.execute("""
        INSERT INTO curriculum_slots (lesson_id, unit_id, index, working_title)
        SELECT id, unit_id, index, jsonb_build_object('en', id) FROM lessons
    """)
    op.create_foreign_key(op.f("fk_lessons_curriculum_slot"), "lessons", "curriculum_slots",
                          ["id", "unit_id", "index"], ["lesson_id", "unit_id", "index"])

    op.add_column("lesson_versions", sa.Column("origin", sa.Text(), nullable=False))
    op.create_check_constraint(op.f("ck_lesson_versions_origin_valid"), "lesson_versions", f"origin IN ({ORIGINS})")

    op.alter_column("sources", "provider", existing_type=sa.Text(), nullable=False)
    op.alter_column("sources", "excerpt", existing_type=sa.Text(), nullable=False)
    op.drop_constraint(op.f("ck_sources_provider_valid"), "sources", type_="check")
    op.create_check_constraint(op.f("ck_sources_provider_valid"), "sources", f"provider IN ({PROVIDERS})")

    # Claim and sentence ids are authored per lesson version and need no wire prefix (decision D-33).
    op.drop_constraint(op.f("ck_claims_id_format"), "claims", type_="check")
    op.drop_constraint(op.f("ck_sentences_id_format"), "sentences", type_="check")

    op.execute("""
    CREATE FUNCTION qabas_exercise_identity_immutable() RETURNS trigger LANGUAGE plpgsql AS $$
    BEGIN
        IF NEW.type IS DISTINCT FROM OLD.type OR NEW.purpose IS DISTINCT FROM OLD.purpose THEN
            RAISE EXCEPTION 'exercise % keeps its type and purpose; different content needs a new exercise id', OLD.id
                USING ERRCODE = 'QB006';
        END IF;
        RETURN NEW;
    END $$
    """)
    op.execute("""
    CREATE TRIGGER exercises_identity_immutable BEFORE UPDATE OF type, purpose ON exercises
    FOR EACH ROW EXECUTE FUNCTION qabas_exercise_identity_immutable()
    """)
    op.execute("SELECT qabas_apply_grants()")  # cover curriculum_slots for the runtime roles


def downgrade() -> None:
    op.execute("DROP TRIGGER IF EXISTS exercises_identity_immutable ON exercises")
    op.execute("DROP FUNCTION IF EXISTS qabas_exercise_identity_immutable()")
    op.create_check_constraint(op.f("ck_sentences_id_format"), "sentences", "id ~ '^sen_[0-9A-Za-z_]+$'")
    op.create_check_constraint(op.f("ck_claims_id_format"), "claims", "id ~ '^clm_[0-9A-Za-z_]+$'")
    op.drop_constraint(op.f("ck_sources_provider_valid"), "sources", type_="check")
    op.create_check_constraint(op.f("ck_sources_provider_valid"), "sources", f"provider IS NULL OR provider IN ({PROVIDERS})")
    op.alter_column("sources", "excerpt", existing_type=sa.Text(), nullable=True)
    op.alter_column("sources", "provider", existing_type=sa.Text(), nullable=True)
    op.drop_constraint(op.f("ck_lesson_versions_origin_valid"), "lesson_versions", type_="check")
    op.drop_column("lesson_versions", "origin")
    op.drop_constraint(op.f("fk_lessons_curriculum_slot"), "lessons", type_="foreignkey")
    op.drop_constraint(op.f("ck_lessons_index_non_negative"), "lessons", type_="check")
    op.execute("UPDATE lessons SET index = -index")
    op.execute("UPDATE lessons SET index = -index + 1")
    op.create_check_constraint(op.f("ck_lessons_index_positive"), "lessons", "index >= 1")
    op.drop_table("curriculum_slots")
