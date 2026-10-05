"""Migrations, model/migration parity, contract-derived enums and least-privilege roles."""

from __future__ import annotations

import io
import re

import pytest
from alembic import command
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncConnection

from app.contract import models as C
from app.db import enums
from app.db.base import Base
from tests.support.db import alembic_config

pytestmark = pytest.mark.integration


def test_models_match_migrations(migrated_url: str) -> None:
    """``alembic check``: autogenerate finds no difference between the models and the migrated schema."""
    command.check(alembic_config(migrated_url))


def test_offline_sql_renders(migrated_url: str) -> None:
    """The full migration renders as SQL (reviewable DDL for deployments)."""
    config = alembic_config(migrated_url)
    buffer = io.StringIO()
    config.output_buffer = buffer
    command.upgrade(config, "head", sql=True)
    ddl = buffer.getvalue()
    assert "CREATE TABLE sessions" in ddl and "CREATE TRIGGER sessions_guard" in ddl


async def test_every_model_table_exists(conn: AsyncConnection) -> None:
    rows = await conn.execute(text("SELECT tablename FROM pg_tables WHERE schemaname = 'public'"))
    assert set(Base.metadata.tables) <= {r[0] for r in rows}


async def _check_values(conn: AsyncConnection, constraint: str) -> set[str]:
    definition = (await conn.execute(text("SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname = :n"),
                                     {"n": constraint})).scalar_one()
    return set(re.findall(r"'([^']+)'::text", definition)) or set(re.findall(r"\b(\d+)\b", definition))


@pytest.mark.parametrize(("constraint", "values"), [
    ("ck_users_role_valid", enums.ROLE),
    ("ck_users_track_valid", enums.TRACK),
    ("ck_users_language_valid", enums.LANGUAGE),
    ("ck_users_familiarity_valid", enums.FAMILIARITY),
    ("ck_users_daily_goal_minutes_valid", tuple(str(v) for v in enums.DAILY_GOAL_MINUTES)),
    ("ck_sessions_kind_valid", enums.SESSION_KIND),
    ("ck_sessions_mode_valid", enums.SESSION_MODE),
    ("ck_sessions_status_valid", enums.SESSION_STATUS),
    ("ck_sessions_feedback_mode_valid", enums.FEEDBACK_MODE),
    ("ck_exercises_type_valid", enums.EXERCISE_TYPE),
    ("ck_lessons_lesson_type_valid", enums.LESSON_TYPE),
    ("ck_sources_kind_valid", enums.SOURCE_KIND),
    ("ck_sources_provider_valid", enums.SOURCE_PROVIDER),
    ("ck_xp_events_reason_valid", enums.XP_REASON),
    ("ck_quests_kind_valid", enums.QUEST_KIND),
    ("ck_sentences_role_valid", enums.SENTENCE_ROLE),
    ("ck_claims_basis_valid", enums.CLAIM_BASIS),
    ("ck_claims_status_valid", enums.CLAIM_STATUS),
    ("ck_learner_terms_state_valid", enums.TERM_STATE),
    ("ck_recitation_checks_status_valid", enums.RECITATION_STATUS),
    ("ck_review_decisions_decision_valid", enums.REVIEW_DECISION),
])
async def test_database_enums_equal_contract(conn: AsyncConnection, constraint: str, values: tuple[str, ...]) -> None:
    assert await _check_values(conn, constraint) == set(values)


def test_enums_are_derived_from_the_contract() -> None:
    dispatch = C.EXPORTED["Exercise"]
    assert dispatch is not None
    assert set(enums.EXERCISE_TYPE) == set(C.PAYLOADS)
    assert len(enums.EXERCISE_TYPE) == 15
    assert enums.FEEDBACK_BY_KIND.keys() == set(enums.SESSION_KIND)
    assert set(enums.FEEDBACK_BY_KIND.values()) == set(enums.FEEDBACK_MODE)
    assert set(enums.DUEL_TYPES) <= set(enums.EXERCISE_TYPE)
    assert set(enums.ASSESSMENT_EXCLUDED_TYPES) <= set(enums.EXERCISE_TYPE)


ROLES = ("qabas_app", "qabas_worker", "qabas_readonly")


async def test_least_privilege_roles(conn: AsyncConnection) -> None:
    existing = {r[0] for r in await conn.execute(text("SELECT rolname FROM pg_roles WHERE rolname = ANY(:r)"),
                                                 {"r": list(ROLES)})}
    if existing != set(ROLES):
        pytest.skip("database roles not created (backend/scripts/dev/create-dev-db.ps1 or CI creates them)")

    async def can(role: str, table: str, privilege: str) -> bool:
        return bool((await conn.execute(text("SELECT has_table_privilege(:r, :t, :p)"),
                                        {"r": role, "t": table, "p": privilege})).scalar())

    for role in ("qabas_app", "qabas_worker"):
        assert await can(role, "sessions", "UPDATE")
        assert await can(role, "session_answers", "INSERT")
        assert await can(role, "session_answers", "DELETE")       # account purge
        assert not await can(role, "session_answers", "UPDATE")   # answers are replayed, never rewritten
        assert not await can(role, "lesson_versions", "DELETE")
        assert not await can(role, "review_decisions", "UPDATE")
        assert not await can(role, "review_decisions", "DELETE")
        assert not await can(role, "alembic_version", "UPDATE")
        for table in ("media_jobs", "media_assets"):
            assert await can(role, table, "SELECT")
            assert await can(role, table, "INSERT")
            assert not await can(role, table, "UPDATE")
            assert not await can(role, table, "DELETE")
    assert await can("qabas_readonly", "sessions", "SELECT")
    assert not await can("qabas_readonly", "sessions", "INSERT")
