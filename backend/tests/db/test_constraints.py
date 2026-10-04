"""Every mandatory invariant from the data model, enforced by the database itself.

Each test names the invariant it covers. Failures are asserted by SQLSTATE: standard integrity
codes, or the custom QB00x codes raised by the migration's triggers.
"""

from __future__ import annotations

from decimal import Decimal

import pytest
from sqlalchemy.ext.asyncio import AsyncConnection

from app.db.ids import new_id
from tests.db import factories as f
from tests.support.db import (
    CHECK_VIOLATION,
    CURRENT_NOT_PUBLISHED,
    FK_VIOLATION,
    IMMUTABLE,
    INSERT_ONLY,
    SESSION_GUARD,
    SET_ONCE,
    UNIQUE_VIOLATION,
    expect_sqlstate,
    run,
)

pytestmark = pytest.mark.integration

ANSWER_SQL = """INSERT INTO session_answers (session_id, exercise_id, exercise_version, answer, correct, is_retry,
                evaluation) VALUES (:s, :e, 1, CAST('{"option_id": "opt_b"}' AS jsonb), true, :retry,
                CAST('{"recorded": true}' AS jsonb))"""


# --- one original and one retry per exercise and session -----------------------------------------

async def test_attempt_identity_is_unique(conn: AsyncConnection) -> None:
    s = await f.learning_slice(conn)
    params = {"s": s["session_id"], "e": s["exercise_id"], "retry": False}
    await run(conn, ANSWER_SQL, params)
    await run(conn, ANSWER_SQL, {**params, "retry": True})
    await expect_sqlstate(conn, UNIQUE_VIOLATION, ANSWER_SQL, params)
    await expect_sqlstate(conn, UNIQUE_VIOLATION, ANSWER_SQL, {**params, "retry": True})


async def test_answers_are_insert_only_and_reference_a_served_version(conn: AsyncConnection) -> None:
    s = await f.learning_slice(conn)
    await run(conn, ANSWER_SQL, {"s": s["session_id"], "e": s["exercise_id"], "retry": False})
    await expect_sqlstate(conn, INSERT_ONLY, "UPDATE session_answers SET correct = false")
    await expect_sqlstate(conn, FK_VIOLATION, ANSWER_SQL.replace("VALUES (:s, :e, 1,", "VALUES (:s, :e, 9,"),
                          {"s": s["session_id"], "e": s["exercise_id"], "retry": True})


# --- one active session per (user, kind, lesson/unit, mode) --------------------------------------

async def test_one_active_session_per_key(conn: AsyncConnection) -> None:
    s = await f.learning_slice(conn)
    await expect_sqlstate(conn, UNIQUE_VIOLATION, """
        INSERT INTO sessions (id, user_id, kind, lesson_id, lesson_version_id, unit_id, feedback_mode, language,
                              variant, items_snapshot, served_exercises, contract_revision)
        VALUES (:id, :u, 'lesson', :l, :lv, :unit, 'immediate', 'ar', 'explorer', '{}', '[]', 10)""",
        {"id": new_id("ses"), "u": s["user_id"], "l": s["lesson_id"], "lv": s["lesson_version_id"],
         "unit": s["unit_id"]})


async def test_review_modes_and_finished_sessions_do_not_collide(conn: AsyncConnection) -> None:
    user_id = await f.user(conn)
    review = """INSERT INTO sessions (id, user_id, kind, mode, feedback_mode, language, variant, items_snapshot,
                                      served_exercises, contract_revision)
                VALUES (:id, :u, 'review', :mode, 'immediate', 'en', 'explorer', '{}', '[]', 10)"""
    first = new_id("ses")
    await run(conn, review, {"id": first, "u": user_id, "mode": "cards"})
    await run(conn, review, {"id": new_id("ses"), "u": user_id, "mode": "quick"})  # other mode: allowed
    await expect_sqlstate(conn, UNIQUE_VIOLATION, review, {"id": new_id("ses"), "u": user_id, "mode": "cards"})
    await run(conn, "UPDATE sessions SET status = 'abandoned', abandoned_at = now() WHERE id = :id", {"id": first})
    await run(conn, review, {"id": new_id("ses"), "u": user_id, "mode": "cards"})  # old one no longer active


# --- one completion per session; the stored result is replayed ------------------------------------

async def test_finish_requires_a_stored_result_and_is_terminal(conn: AsyncConnection) -> None:
    s = await f.learning_slice(conn)
    sid = {"id": s["session_id"]}
    await expect_sqlstate(conn, CHECK_VIOLATION,
                          "UPDATE sessions SET status = 'finished', finished_at = now() WHERE id = :id", sid)
    await run(conn, """UPDATE sessions SET status = 'finished', finished_at = now(), duration_ms = 1000,
                       result_snapshot = CAST('{"score": 1}' AS jsonb) WHERE id = :id""", sid)
    await expect_sqlstate(conn, SESSION_GUARD,
                          "UPDATE sessions SET result_snapshot = CAST('{\"score\": 0}' AS jsonb) WHERE id = :id", sid)
    await expect_sqlstate(conn, SESSION_GUARD, "UPDATE sessions SET duration_ms = 5 WHERE id = :id", sid)
    await expect_sqlstate(conn, SESSION_GUARD, "UPDATE sessions SET status = 'active', finished_at = NULL, "
                          "result_snapshot = NULL, duration_ms = NULL WHERE id = :id", sid)


async def test_abandoned_sessions_carry_no_result(conn: AsyncConnection) -> None:
    s = await f.learning_slice(conn)
    sid = {"id": s["session_id"]}
    await expect_sqlstate(conn, CHECK_VIOLATION, """UPDATE sessions SET status = 'abandoned', abandoned_at = now(),
                          result_snapshot = CAST('{}' AS jsonb) WHERE id = :id""", sid)
    await run(conn, "UPDATE sessions SET status = 'abandoned', abandoned_at = now() WHERE id = :id", sid)
    await expect_sqlstate(conn, SESSION_GUARD, "UPDATE sessions SET status = 'finished', finished_at = now(), "
                          "result_snapshot = CAST('{}' AS jsonb) WHERE id = :id", sid)


async def test_served_snapshot_is_frozen_except_through_a_snapshot_migration(conn: AsyncConnection) -> None:
    s = await f.learning_slice(conn)
    sid = {"id": s["session_id"]}
    await expect_sqlstate(conn, SESSION_GUARD,
                          "UPDATE sessions SET items_snapshot = CAST('{\"items\": [1]}' AS jsonb) WHERE id = :id", sid)
    await expect_sqlstate(conn, SESSION_GUARD, "UPDATE sessions SET language = 'ar' WHERE id = :id", sid)
    await expect_sqlstate(conn, SESSION_GUARD,
                          "UPDATE sessions SET served_exercises = CAST('[]' AS jsonb) WHERE id = :id", sid)
    await run(conn, """UPDATE sessions SET items_snapshot = CAST('{"items": [], "migrated": true}' AS jsonb),
                       snapshot_revision = 11 WHERE id = :id""", sid)


async def test_session_kind_rules(conn: AsyncConnection) -> None:
    s = await f.learning_slice(conn)
    base = {"id": new_id("ses"), "u": s["user_id"], "unit": s["unit_id"]}
    insert = """INSERT INTO sessions (id, user_id, kind, mode, unit_id, feedback_mode, language, variant,
                                      items_snapshot, served_exercises, contract_revision)
                VALUES (:id, :u, :kind, :mode, :unit, :fb, 'en', 'explorer', '{}', '[]', 10)"""
    await expect_sqlstate(conn, CHECK_VIOLATION, insert, {**base, "kind": "pretest", "mode": None, "fb": "end"})
    await expect_sqlstate(conn, CHECK_VIOLATION, insert, {**base, "kind": "pretest", "mode": "quick", "fb": "none"})
    await expect_sqlstate(conn, CHECK_VIOLATION, insert, {**base, "kind": "review", "mode": None, "fb": "immediate"})
    await expect_sqlstate(conn, CHECK_VIOLATION, insert,
                          {**base, "kind": "unit_test", "mode": None, "fb": "end", "unit": None})
    await run(conn, insert, {**base, "kind": "unit_test", "mode": None, "fb": "end"})


# --- published content is immutable ---------------------------------------------------------------

async def test_published_lesson_version_is_immutable(conn: AsyncConnection) -> None:
    unit_id = await f.unit(conn)
    lesson_id = await f.lesson(conn, unit_id)
    draft = await f.lesson_version(conn, lesson_id, 1)
    await run(conn, "UPDATE lesson_versions SET reviewed_by = 'Reviewer' WHERE id = :id", {"id": draft})
    await run(conn, "UPDATE lesson_versions SET published_at = now() WHERE id = :id", {"id": draft})
    await expect_sqlstate(conn, IMMUTABLE, "UPDATE lesson_versions SET reviewed_by = 'Other' WHERE id = :id",
                          {"id": draft})
    await expect_sqlstate(conn, IMMUTABLE, "UPDATE lesson_versions SET published_at = NULL WHERE id = :id",
                          {"id": draft})
    await expect_sqlstate(conn, IMMUTABLE, "DELETE FROM lesson_versions WHERE id = :id", {"id": draft})


async def test_claims_and_sentences_of_published_versions_are_immutable(conn: AsyncConnection) -> None:
    unit_id = await f.unit(conn)
    lesson_id = await f.lesson(conn, unit_id)
    lv = await f.lesson_version(conn, lesson_id, 1)
    claim = ("INSERT INTO claims (lesson_version_id, id, text, status, basis) "
             "VALUES (:lv, :id, 'A claim.', 'supported', 'source')")
    sentence = ("INSERT INTO sentences (lesson_version_id, lang, variant, id, role, claim_ids) "
                "VALUES (:lv, 'en', 'explorer', :id, 'claim', ARRAY['clm_a'])")
    await run(conn, claim, {"lv": lv, "id": "clm_a"})
    await run(conn, sentence, {"lv": lv, "id": "sen_a"})
    await run(conn, "UPDATE lesson_versions SET published_at = now() WHERE id = :id", {"id": lv})
    await expect_sqlstate(conn, IMMUTABLE, claim, {"lv": lv, "id": "clm_b"})
    await expect_sqlstate(conn, IMMUTABLE, "UPDATE claims SET text = 'Changed.' WHERE lesson_version_id = :lv",
                          {"lv": lv})
    await expect_sqlstate(conn, IMMUTABLE, "DELETE FROM sentences WHERE lesson_version_id = :lv", {"lv": lv})
    await expect_sqlstate(conn, IMMUTABLE, sentence, {"lv": lv, "id": "sen_b"})


async def test_published_exercise_version_is_immutable(conn: AsyncConnection) -> None:
    s = await f.learning_slice(conn)
    key = {"e": s["exercise_id"]}
    await expect_sqlstate(conn, IMMUTABLE, "UPDATE exercise_versions SET answer_key = CAST('{\"option_id\": "
                          "\"opt_a\"}' AS jsonb) WHERE exercise_id = :e", key)
    await expect_sqlstate(conn, IMMUTABLE, "DELETE FROM exercise_versions WHERE exercise_id = :e", key)


async def test_published_scene_version_and_assets_are_immutable(conn: AsyncConnection) -> None:
    sha = "a" * 64
    await run(conn, """INSERT INTO scene_versions (scene_id, version, manifest_url, sha256, bytes, view_box, states,
                       fallback_image) VALUES ('scn_t', 1, 'https://cdn.example.test/s.json', :sha, 10,
                       '{}', '{}', '{}')""", {"sha": sha})
    asset = """INSERT INTO scene_assets (scene_id, version, asset_id, url, mime_type, width, height, bytes, sha256)
               VALUES ('scn_t', 1, :a, 'https://cdn.example.test/a.webp', 'image/webp', 10, 10, 10, :sha)"""
    await run(conn, asset, {"a": "a1", "sha": sha})
    await expect_sqlstate(conn, CHECK_VIOLATION, "UPDATE scene_versions SET status = 'published' "
                          "WHERE scene_id = 'scn_t'")  # status and published_at move together
    await run(conn, "UPDATE scene_versions SET status = 'published', published_at = now() WHERE scene_id = 'scn_t'")
    await expect_sqlstate(conn, IMMUTABLE, "UPDATE scene_versions SET bytes = 11 WHERE scene_id = 'scn_t'")
    await expect_sqlstate(conn, IMMUTABLE, asset, {"a": "a2", "sha": sha})
    await expect_sqlstate(conn, IMMUTABLE, "DELETE FROM scene_assets WHERE scene_id = 'scn_t'")


async def test_current_version_must_be_published(conn: AsyncConnection) -> None:
    unit_id = await f.unit(conn)
    lesson_id = await f.lesson(conn, unit_id)
    await f.lesson_version(conn, lesson_id, 1)
    await expect_sqlstate(conn, CURRENT_NOT_PUBLISHED, "UPDATE lessons SET current_version = 1 WHERE id = :id",
                          {"id": lesson_id})
    await f.lesson_version(conn, lesson_id, 2, published=True)
    await run(conn, "UPDATE lessons SET current_version = 2 WHERE id = :id", {"id": lesson_id})
    exercise_id = await f.exercise(conn, unit_id, lesson_id)
    await f.exercise_version(conn, exercise_id, 1)
    await expect_sqlstate(conn, CURRENT_NOT_PUBLISHED, "UPDATE exercises SET current_version = 1 WHERE id = :id",
                          {"id": exercise_id})


# --- recitation binding -------------------------------------------------------------------------

async def test_recitation_check_binding_columns(conn: AsyncConnection) -> None:
    user_id = await f.user(conn)
    insert = """INSERT INTO recitation_checks (id, user_id, surah, ayah, word_start, word_end, checked_text_sha256,
                status, passed, words, summary)
                VALUES (:id, :u, :surah, 103, :ws, :we, :sha, :status, :passed, '[]', '{}')"""
    good = {"id": new_id("rchk"), "u": user_id, "surah": 4, "ws": 14, "we": 20, "sha": "b" * 64,
            "status": "evaluated", "passed": True}
    await run(conn, insert, good)
    for bad in ({"surah": 115}, {"ws": 0}, {"ws": 20, "we": 14}, {"ws": 3, "we": None}, {"sha": "nothex"},
                {"status": "unclear", "passed": True}):
        await expect_sqlstate(conn, CHECK_VIOLATION, insert, {**good, "id": new_id("rchk"), **bad})


# --- six-decimal private mastery ----------------------------------------------------------------

async def test_mastery_is_six_decimal_and_bounded(conn: AsyncConnection) -> None:
    s = await f.learning_slice(conn)
    concept_id = await f.concept(conn, s["unit_id"])
    insert = "INSERT INTO learner_concepts (user_id, concept_id, mastery) VALUES (:u, :c, :m)"
    await run(conn, insert, {"u": s["user_id"], "c": concept_id, "m": Decimal("0.5454545")})
    stored = (await run(conn, "SELECT mastery FROM learner_concepts WHERE concept_id = :c", {"c": concept_id})).scalar()
    assert stored == Decimal("0.545455")
    other = await f.concept(conn, s["unit_id"], "b")
    await expect_sqlstate(conn, CHECK_VIOLATION, insert, {"u": s["user_id"], "c": other, "m": Decimal("1.000001")})
    await expect_sqlstate(conn, CHECK_VIOLATION, insert, {"u": s["user_id"], "c": other, "m": Decimal("-0.1")})


# --- effects happen once -----------------------------------------------------------------------------

async def test_outbox_and_effect_ledger_keys_are_unique(conn: AsyncConnection) -> None:
    outbox = "INSERT INTO outbox_events (event_key, kind, payload) VALUES ('session:ses_x:finished', 'k', '{}')"
    await run(conn, outbox)
    await expect_sqlstate(conn, UNIQUE_VIOLATION, outbox)
    ledger = "INSERT INTO effect_ledger (effect_key, event_key) VALUES ('ach:usr_x:ses_x', 'session:ses_x:finished')"
    await run(conn, ledger)
    await expect_sqlstate(conn, UNIQUE_VIOLATION, ledger)


async def test_xp_grants_and_daily_goal_happen_once(conn: AsyncConnection) -> None:
    user_id = await f.user(conn)
    grant = """INSERT INTO xp_events (user_id, reason, xp, ref_type, ref_id, week_key, local_date)
               VALUES (:u, :reason, :xp, :rt, :rid, '2026-W40', DATE '2026-10-04')"""
    await run(conn, grant, {"u": user_id, "reason": "lesson_complete", "xp": 10, "rt": "session", "rid": "ses_a"})
    await expect_sqlstate(conn, UNIQUE_VIOLATION, grant,
                          {"u": user_id, "reason": "lesson_complete", "xp": 10, "rt": "session", "rid": "ses_a"})
    await run(conn, grant, {"u": user_id, "reason": "daily_goal_met", "xp": 2, "rt": "day", "rid": "a"})
    await expect_sqlstate(conn, UNIQUE_VIOLATION, grant,
                          {"u": user_id, "reason": "daily_goal_met", "xp": 2, "rt": "day", "rid": "b"})
    await expect_sqlstate(conn, CHECK_VIOLATION, grant,
                          {"u": user_id, "reason": "made_up", "xp": 1, "rt": "x", "rid": "y"})


async def test_quests_one_per_slot_and_kind(conn: AsyncConnection) -> None:
    user_id = await f.user(conn)
    quest = """INSERT INTO quests (user_id, local_date, slot, kind, goal, reward_xp)
               VALUES (:u, DATE '2026-10-04', :slot, :kind, 1, 10)"""
    await run(conn, quest, {"u": user_id, "slot": 1, "kind": "earn_xp"})
    await expect_sqlstate(conn, UNIQUE_VIOLATION, quest, {"u": user_id, "slot": 1, "kind": "complete_review"})
    await expect_sqlstate(conn, UNIQUE_VIOLATION, quest, {"u": user_id, "slot": 2, "kind": "earn_xp"})
    await expect_sqlstate(conn, CHECK_VIOLATION, quest, {"u": user_id, "slot": 4, "kind": "recite_verse"})


# --- request idempotency ------------------------------------------------------------------------------

async def test_idempotency_key_unique_per_user(conn: AsyncConnection) -> None:
    user_id = await f.user(conn)
    insert = """INSERT INTO idempotency_keys (user_id, key, request_hash, response_status, response_body)
                VALUES (:u, 'k-1', :h, 201, '{}')"""
    await run(conn, insert, {"u": user_id, "h": "c" * 64})
    await expect_sqlstate(conn, UNIQUE_VIOLATION, insert, {"u": user_id, "h": "d" * 64})
    await run(conn, insert, {"u": await f.user(conn), "h": "c" * 64})  # same key, other user


# --- gate decisions are auditable -----------------------------------------------------------------

async def test_review_decisions_are_insert_only(conn: AsyncConnection) -> None:
    reviewer = await f.user(conn, role="reviewer", email="reviewer@example.test", password_hash="argon2id$x")
    insert = """INSERT INTO review_decisions (run_id, gate, decision, reviewer_id, reviewed_digest, published_digest)
                VALUES ('run_t', :gate, :decision, :r, :d, :p)"""
    await run(conn, insert, {"gate": 2, "decision": "approve", "r": reviewer, "d": "e" * 64, "p": "f" * 64})
    await expect_sqlstate(conn, INSERT_ONLY, "UPDATE review_decisions SET reason = 'x'")
    await expect_sqlstate(conn, INSERT_ONLY, "DELETE FROM review_decisions")
    await expect_sqlstate(conn, CHECK_VIOLATION, insert,
                          {"gate": 1, "decision": "request_changes", "r": reviewer, "d": "e" * 64, "p": None})
    await expect_sqlstate(conn, CHECK_VIOLATION, insert,
                          {"gate": 2, "decision": "reject", "r": reviewer, "d": "e" * 64, "p": "f" * 64})


# --- curriculum: one lesson per slot, one completion per canonical lesson, one introducing lesson ---

async def test_one_lesson_per_curriculum_slot(conn: AsyncConnection) -> None:
    unit_id = await f.unit(conn)
    await f.lesson(conn, unit_id, 1)
    await expect_sqlstate(conn, UNIQUE_VIOLATION, """INSERT INTO lessons (id, unit_id, index, lesson_type,
                          estimated_minutes) VALUES ('les_other', :u, 1, 'story', 7)""", {"u": unit_id})


async def test_one_completion_record_per_canonical_lesson(conn: AsyncConnection) -> None:
    s = await f.learning_slice(conn)
    insert = "INSERT INTO learner_lessons (user_id, lesson_id, completed_at) VALUES (:u, :l, now())"
    await run(conn, insert, {"u": s["user_id"], "l": s["lesson_id"]})
    await expect_sqlstate(conn, UNIQUE_VIOLATION, insert, {"u": s["user_id"], "l": s["lesson_id"]})


async def test_concept_is_introduced_by_one_lesson_once(conn: AsyncConnection) -> None:
    unit_id = await f.unit(conn)
    concept_id = await f.concept(conn, unit_id)
    first, second = await f.lesson(conn, unit_id, 1), await f.lesson(conn, unit_id, 2)
    update = "UPDATE concepts SET introduced_by_lesson_id = :l WHERE id = :c"
    await run(conn, update, {"l": first, "c": concept_id})
    await run(conn, update, {"l": first, "c": concept_id})  # unchanged value is fine
    await expect_sqlstate(conn, SET_ONCE, update, {"l": second, "c": concept_id})
    await expect_sqlstate(conn, SET_ONCE, update, {"l": None, "c": concept_id})


async def test_standalone_lessons_have_no_prerequisites(conn: AsyncConnection) -> None:
    unit_id = await f.unit(conn)
    await expect_sqlstate(conn, CHECK_VIOLATION, """INSERT INTO lessons (id, unit_id, index, lesson_type,
                          estimated_minutes, standalone_eligible, prerequisite_concept_ids)
                          VALUES ('les_x', :u, 1, 'story', 7, true, ARRAY['con_a'])""", {"u": unit_id})


# --- exercise pools -------------------------------------------------------------------------------------

async def test_exercise_purpose_and_type_rules(conn: AsyncConnection) -> None:
    unit_id = await f.unit(conn)
    lesson_id = await f.lesson(conn, unit_id)
    insert = """INSERT INTO exercises (id, lesson_id, unit_id, purpose, type)
                VALUES (:id, :l, :u, :purpose, :type)"""
    base = {"l": lesson_id, "u": unit_id}
    for i, (purpose, type_) in enumerate([("pretest", "flashcard"), ("unit_test", "recite_verse"),
                                          ("duel", "scenario"), ("lesson", "true_false"), ("lesson", "essay")]):
        await expect_sqlstate(conn, CHECK_VIOLATION, insert,
                              {**base, "id": f"ex_bad_{i}", "purpose": purpose, "type": type_})
    await expect_sqlstate(conn, CHECK_VIOLATION, insert, {**base, "id": "ex_nol", "l": None, "purpose": "lesson",
                                                          "type": "multiple_choice"})
    await run(conn, insert, {**base, "id": "ex_duel", "purpose": "duel", "type": "true_false"})


# --- users ------------------------------------------------------------------------------------------------

async def test_user_rules(conn: AsyncConnection) -> None:
    await expect_sqlstate(conn, CHECK_VIOLATION, """INSERT INTO users (id, display_name, avatar_key, timezone,
                          role) VALUES ('usr_rev', 'R', 'a', 'UTC', 'reviewer')""")  # reviewer without credentials
    await expect_sqlstate(conn, CHECK_VIOLATION, """INSERT INTO users (id, display_name, avatar_key, timezone,
                          email, password_hash) VALUES ('usr_l', 'L', 'a', 'UTC', 'x@example.test', 'h')""")
    await expect_sqlstate(conn, CHECK_VIOLATION, """INSERT INTO users (id, display_name, avatar_key, timezone,
                          daily_goal_minutes) VALUES ('usr_g', 'G', 'a', 'UTC', 7)""")
    await expect_sqlstate(conn, CHECK_VIOLATION, """INSERT INTO users (id, display_name, avatar_key, timezone)
                          VALUES ('user_1', 'G', 'a', 'UTC')""")  # wrong id prefix
    await f.user(conn, role="reviewer", email="Rev@Example.test", password_hash="h")
    await expect_sqlstate(conn, UNIQUE_VIOLATION, """INSERT INTO users (id, display_name, avatar_key, timezone, role,
                          email, password_hash) VALUES ('usr_dup', 'D', 'a', 'UTC', 'reviewer',
                          'rev@example.test', 'h')""")  # email unique case-insensitively
