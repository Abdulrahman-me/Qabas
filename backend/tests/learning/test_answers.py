"""Answers through the API on the test curriculum (API §6.5, backend §6.3, §7.1).

QUALITY §18.1 ``test_types`` (every lesson type through a real session), ``test_attempt_identity``,
``test_mastery``, ``test_null_correct`` (answer side) and the submit/replay part of ``test_history_redaction``.
The test exercises are the contract specimens, so the contract's own answer bodies are used.
"""

from __future__ import annotations

import asyncio
import json
from decimal import Decimal
from typing import Any

import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.content.test_curriculum import build_packages
from app.contract import FIXTURES_DIR, contextual
from app.contract import models as C
from app.models import User
from app.runtime import Resources
from app.services.learning import answers
from tests.api.helpers import execute, query
from tests.learning.conftest import learner, user_id
from tests.learning.test_journey import practiced

pytestmark = pytest.mark.integration

EXERCISES = FIXTURES_DIR / "exercises"
PREREQUISITES = ("les_t1_0", "les_t1_1", "les_t2_0", "les_t2_1", "les_t2_3")
LESSONS = ("les_t1_0", "les_t1_1", "les_t1_2", "les_t2_0", "les_t2_1", "les_t2_2", "les_t2_3", "les_t3_0",
           "les_t3_1", "les_t3_2")


def folder(exercise: dict[str, Any]) -> str:
    typ = exercise["type"]
    return f"{typ}__{exercise['payload']['presentation']}" if typ in ("categorize", "map_place") else typ


def fixture(exercise: dict[str, Any], name: str) -> Any:
    return json.loads((EXERCISES / folder(exercise) / f"{name}.json").read_text(encoding="utf-8"))


def body(exercise: dict[str, Any], outcome: str, *, retry: bool = False) -> dict[str, Any]:
    submitted = fixture(exercise, f"answer_{outcome}")
    return {**submitted, "exercise_id": exercise["exercise_id"], "is_retry": retry}


def open_everything(settings: Settings, uid: str, *, skip: str | None = None) -> None:
    for lesson_id in PREREQUISITES:
        if lesson_id != skip:
            execute(settings.database_url, "INSERT INTO learner_lessons (user_id, lesson_id, completed_at) "
                    "VALUES ($1, $2, now()) ON CONFLICT DO NOTHING", uid, lesson_id)


def start(client: TestClient, headers: dict[str, str], request: dict[str, Any]) -> dict[str, Any]:
    response = client.post("/v1/sessions", json=request, headers=headers)
    assert response.status_code in (200, 201), response.text
    return dict(response.json())


def exercises(session: dict[str, Any]) -> list[dict[str, Any]]:
    return [b["exercise"] for b in session["items"] if b["type"] == "exercise"]


def answer(client: TestClient, headers: dict[str, str], session: dict[str, Any], payload: dict[str, Any],
           status: int = 200) -> dict[str, Any]:
    response = client.post(f"/v1/sessions/{session['session_id']}/answers", json=payload, headers=headers)
    assert response.status_code == status, response.text
    return dict(response.json())


KEYS = {e.exercise_id: e.exercise["ar"].answer_key for p in build_packages() for e in p.exercises}


def keyed(exercise: dict[str, Any], *, correct: bool) -> dict[str, Any]:
    """An answer built from the private key (assessment banks are not contract specimens)."""
    key = KEYS[exercise["exercise_id"]]
    assert key is not None
    value = key.model_dump(mode="json")
    if not correct:
        if "option_id" in value:
            options = [o["option_id"] for o in exercise["payload"]["options"]]
            value = {"option_id": next(o for o in options if o != value["option_id"])}
        elif "reason_option_id" in value:
            value = {**value, "value": not value["value"]}
        elif "order" in value:
            value = {"order": list(reversed(value["order"]))}
        else:
            raise AssertionError(f"no wrong answer recipe for {exercise['type']}")
    return {"exercise_id": exercise["exercise_id"], "answer": value, "elapsed_ms": 4000, "is_retry": False}


def mastery(settings: Settings, uid: str, concept_id: str = "con_test") -> Decimal | None:
    rows = query(settings.database_url, "SELECT mastery FROM learner_concepts WHERE user_id = $1 AND concept_id = $2",
                 uid, concept_id)
    return Decimal(rows[0]["mastery"]) if rows else None


def answer_count(settings: Settings, session_id: str) -> int:
    return int(query(settings.database_url, "SELECT count(*) AS n FROM session_answers WHERE session_id = $1",
                     session_id)[0]["n"])


# --- every type, graded against the pinned key, equal to the contract evaluations -----------------------------

@pytest.mark.parametrize("outcome", ["correct", "incorrect"])
def test_every_lesson_type_is_graded_like_the_contract(learn_api: TestClient, curriculum_settings: Settings,
                                                       outcome: str) -> None:
    headers = learner(learn_api, language="ar")
    uid = user_id(learn_api, headers)
    open_everything(curriculum_settings, uid)
    seen, rules = set(), []
    for lesson_id in LESSONS:
        session = start(learn_api, headers, {"kind": "lesson", "lesson_id": lesson_id})
        for exercise in exercises(session):
            evaluation = answer(learn_api, headers, session, body(exercise, outcome))
            C.AnswerEvaluation.model_validate(evaluation)
            expected = fixture(exercise, f"eval_{outcome}")
            ignore = {"exercise_id", "mastery_changes"}
            assert {k: v for k, v in evaluation.items() if k not in ignore} == \
                {k: v for k, v in expected.items() if k not in ignore}, (lesson_id, folder(exercise))
            assert evaluation["exercise_id"] == exercise["exercise_id"]
            assert [m["concept_id"] for m in evaluation["mastery_changes"]] == exercise["concept_ids"]
            rules.append(outcome)
            seen.add(folder(exercise))
    assert len(seen) == 14                                      # every lesson exercise presentation
    expected_mastery = Decimal(0)
    for rule in rules:
        expected_mastery = contextual.update_mastery(expected_mastery, rule)
    assert mastery(curriculum_settings, uid) == expected_mastery  # six-decimal private value, in order


def test_neutral_outcomes_change_nothing(learn_api: TestClient, curriculum_settings: Settings) -> None:
    headers = learner(learn_api)
    uid = user_id(learn_api, headers)
    open_everything(curriculum_settings, uid)
    session = start(learn_api, headers, {"kind": "lesson", "lesson_id": "les_t1_2"})
    *_, pins = exercises(session)
    for exercise in exercises(session)[:3]:
        answer(learn_api, headers, session, body(exercise, "correct"))
    before = mastery(curriculum_settings, uid)
    evaluation = answer(learn_api, headers, session, body(pins, "unavailable"))
    assert (evaluation["correct"], evaluation["correct_answer"], evaluation["details"],
            evaluation["mastery_changes"]) == (None, None, None, [])
    assert mastery(curriculum_settings, uid) == before
    retry = answer(learn_api, headers, session, body(pins, "correct", retry=True), status=409)
    assert retry["error"]["code"] == "retry_not_allowed"         # neutral outcomes are not retried
    history = learn_api.get(f"/v1/sessions/{session['session_id']}", headers=headers).json()["answers"]
    assert history[-1]["result"] == "neutral"


# --- retries, order, identity ------------------------------------------------------------------------------------

def test_one_retry_for_an_incorrect_first_attempt(learn_api: TestClient, curriculum_settings: Settings) -> None:
    headers = learner(learn_api)
    uid = user_id(learn_api, headers)
    session = start(learn_api, headers, {"kind": "lesson", "lesson_id": "les_t1_0"})
    mcq, tfr, *_ = exercises(session)
    assert answer(learn_api, headers, session, body(mcq, "correct", retry=True), status=409)["error"]["code"] == \
        "retry_not_allowed"                                   # no first attempt yet
    answer(learn_api, headers, session, body(mcq, "incorrect"))
    answer(learn_api, headers, session, body(tfr, "correct"))
    assert answer(learn_api, headers, session, body(tfr, "incorrect", retry=True), status=409)["error"]["code"] == \
        "retry_not_allowed"                                   # the first attempt was correct
    before = mastery(curriculum_settings, uid)
    retry = answer(learn_api, headers, session, body(mcq, "correct", retry=True))
    assert retry["correct"] is True and retry["misconception"] is None and retry["xp_awarded"] == 0
    assert mastery(curriculum_settings, uid) == contextual.update_mastery(before, "retry_correct")
    again = answer(learn_api, headers, session, body(mcq, "incorrect", retry=True))
    assert again == retry                                     # the retry is spent: a second one replays it
    assert answer_count(curriculum_settings, session["session_id"]) == 3


def test_a_wrong_retry_never_lowers_mastery(learn_api: TestClient, curriculum_settings: Settings) -> None:
    headers = learner(learn_api)
    uid = user_id(learn_api, headers)
    session = start(learn_api, headers, {"kind": "lesson", "lesson_id": "les_t1_0"})
    mcq = exercises(session)[0]
    answer(learn_api, headers, session, body(mcq, "incorrect"))
    before = mastery(curriculum_settings, uid)
    retry = answer(learn_api, headers, session, body(mcq, "retry_incorrect", retry=True))
    assert (retry["correct"], retry["mastery_changes"]) == (False, [])
    assert mastery(curriculum_settings, uid) == before


def test_first_attempts_follow_authored_order(learn_api: TestClient) -> None:
    headers = learner(learn_api)
    session = start(learn_api, headers, {"kind": "lesson", "lesson_id": "les_t1_0"})
    items = exercises(session)
    response = answer(learn_api, headers, session, body(items[2], "correct"), status=409)
    assert response["error"] == {"code": "out_of_order", "message": "Answer the earlier exercises first.",
                                 "details": {"exercise_id": items[0]["exercise_id"]}}


def test_recorded_identities_replay_and_change_nothing(learn_api: TestClient, curriculum_settings: Settings) -> None:
    headers = learner(learn_api)
    uid = user_id(learn_api, headers)
    session = start(learn_api, headers, {"kind": "lesson", "lesson_id": "les_t1_0"})
    mcq = exercises(session)[0]
    first = answer(learn_api, headers, session, body(mcq, "incorrect"))
    value = mastery(curriculum_settings, uid)
    assert answer(learn_api, headers, session, body(mcq, "incorrect")) == first
    assert answer(learn_api, headers, session, body(mcq, "correct")) == first          # changed body: not re-graded
    garbage = {"exercise_id": mcq["exercise_id"], "is_retry": False, "answer": {"nonsense": [1, 2]}, "elapsed_ms": -5}
    assert answer(learn_api, headers, session, garbage) == first                      # malformed body still replays
    assert mastery(curriculum_settings, uid) == value
    assert answer_count(curriculum_settings, session["session_id"]) == 1


def test_finished_and_abandoned_sessions(learn_api: TestClient, curriculum_settings: Settings) -> None:
    headers = learner(learn_api)
    session = start(learn_api, headers, {"kind": "lesson", "lesson_id": "les_t1_0"})
    mcq, tfr, *_ = exercises(session)
    recorded = answer(learn_api, headers, session, body(mcq, "correct"))
    execute(curriculum_settings.database_url, "UPDATE sessions SET status = 'finished', finished_at = now(), "
            "duration_ms = 1, result_snapshot = '{}'::jsonb WHERE id = $1", session["session_id"])
    assert answer(learn_api, headers, session, body(mcq, "correct")) == recorded        # replays after finish
    assert answer(learn_api, headers, session, body(tfr, "correct"), status=409)["error"]["code"] == "session_finished"
    other = start(learn_api, headers, {"kind": "lesson", "lesson_id": "les_t2_0"})
    learn_api.post(f"/v1/sessions/{other['session_id']}/abandon", headers=headers)
    first = exercises(other)[0]
    assert answer(learn_api, headers, other, body(first, "correct"), status=409)["error"]["code"] == \
        "session_not_active"


def test_requests_are_checked_against_the_served_session(learn_api: TestClient,
                                                        curriculum_settings: Settings) -> None:
    headers, stranger = learner(learn_api), learner(learn_api)
    open_everything(curriculum_settings, user_id(learn_api, headers))
    session = start(learn_api, headers, {"kind": "lesson", "lesson_id": "les_t1_1"})
    bucket, day_arc, *_ = exercises(session)
    assert answer(learn_api, stranger, session, body(bucket, "correct"), status=404)["error"]["code"] == "not_found"
    unserved = {**body(bucket, "correct"), "exercise_id": "ex_t20_0"}
    assert answer(learn_api, headers, session, unserved, status=400)["error"]["details"] == {"field": "exercise_id"}
    invalid = answer(learn_api, headers, session, body(bucket, "invalid"), status=400)
    assert invalid["error"]["details"]["reason"] == "duplicate_or_missing_item"
    answer(learn_api, headers, session, body(bucket, "correct"))
    invalid = answer(learn_api, headers, session, body(day_arc, "invalid"), status=400)
    assert invalid["error"]["details"]["reason"] == "duplicate_or_missing_item"
    early = {**body(day_arc, "correct"), "answer": None, "elapsed_ms": 1000}   # the specimens carry 20 s timers
    assert answer(learn_api, headers, session, early, status=400)["error"]["details"] == {"field": "elapsed_ms"}
    for broken in ({"exercise_id": day_arc["exercise_id"]}, {"is_retry": False}, ["x"]):
        response = learn_api.post(f"/v1/sessions/{session['session_id']}/answers", json=broken, headers=headers)
        assert response.status_code == 400
    response = learn_api.post(f"/v1/sessions/{session['session_id']}/answers", content=b"{not json",
                              headers={**headers, "Content-Type": "application/json"})
    assert response.status_code == 400


# --- feedback modes and session kinds ----------------------------------------------------------------------------

def test_assessments_record_without_revealing(learn_api: TestClient, curriculum_settings: Settings) -> None:
    headers = learner(learn_api)
    uid = user_id(learn_api, headers)
    pretest = start(learn_api, headers, {"kind": "pretest", "unit_id": "unit_test_1"})
    first = exercises(pretest)[0]
    response = answer(learn_api, headers, pretest, keyed(first, correct=True))
    assert response == {"exercise_id": first["exercise_id"], "recorded": True}
    assert mastery(curriculum_settings, uid) == contextual.update_mastery(Decimal(0), "pretest_correct")  # half
    assert answer(learn_api, headers, pretest, keyed(first, correct=False)) == response
    retry = answer(learn_api, headers, pretest, {**keyed(first, correct=True), "is_retry": True}, status=409)
    assert retry["error"]["code"] == "retry_not_allowed"         # retries exist only in lessons

    unit_test = start(learn_api, headers, {"kind": "unit_test", "unit_id": "unit_test_1"})
    first = exercises(unit_test)[0]
    assert answer(learn_api, headers, unit_test, keyed(first, correct=False)) == \
        {"exercise_id": first["exercise_id"], "recorded": True}
    history = learn_api.get(f"/v1/sessions/{unit_test['session_id']}", headers=headers).json()["answers"]
    assert [(a["result"], a["evaluation"]) for a in history] == [("hidden", None)]
    stored = query(curriculum_settings.database_url, "SELECT correct, evaluation FROM session_answers sa JOIN "
                   "sessions s ON s.id = sa.session_id WHERE s.id = $1", unit_test["session_id"])[0]
    assert stored["correct"] is False and json.loads(stored["evaluation"])["correct_answer"] is not None


def test_flashcard_ratings(learn_api: TestClient, curriculum_settings: Settings) -> None:
    headers = learner(learn_api)
    uid = user_id(learn_api, headers)
    for concept_id in ("con_t1_0", "con_t2_0", "con_t2_1"):
        practiced(curriculum_settings, uid, concept_id, due="now() - interval '1 hour'", mastery="0.5")
    session = start(learn_api, headers, {"kind": "review", "mode": "cards"})
    cards = exercises(session)
    results = []
    for card, rating in zip(cards, ("hard", "again", "easy"), strict=True):
        payload = {"exercise_id": card["exercise_id"], "answer": {"rating": rating}, "elapsed_ms": 3000,
                   "is_retry": False}
        evaluation = answer(learn_api, headers, session, payload)
        assert evaluation["correct"] is (rating != "again") and evaluation["correct_answer"] is None
        concept = card["concept_ids"][0]
        rule = {"hard": "flashcard_hard", "again": "incorrect", "easy": "correct"}[rating]
        assert mastery(curriculum_settings, uid, concept) == contextual.update_mastery(Decimal("0.5"), rule)
        results.append(evaluation)
    retry = {"exercise_id": cards[1]["exercise_id"], "answer": {"rating": "good"}, "elapsed_ms": 1, "is_retry": True}
    assert answer(learn_api, headers, session, retry, status=409)["error"]["code"] == "retry_not_allowed"


def test_quick_review_timeouts(learn_api: TestClient, curriculum_settings: Settings) -> None:
    headers = learner(learn_api)
    uid = user_id(learn_api, headers)
    practiced(curriculum_settings, uid, "con_test", due="now() - interval '1 hour'", mastery="0.4")
    session = start(learn_api, headers, {"kind": "review", "mode": "quick"})
    first, second = exercises(session)[:2]
    early = {"exercise_id": first["exercise_id"], "answer": None, "elapsed_ms": 19999, "is_retry": False}
    assert answer(learn_api, headers, session, early, status=400)["error"]["details"] == {"field": "elapsed_ms"}
    timeout = answer(learn_api, headers, session, {**early, "elapsed_ms": 20000})
    assert timeout["correct"] is False and timeout["correct_answer"] is not None
    assert timeout["mastery_changes"][0] == {"concept_id": "con_test", "title": "مفهوم اختباري", "before": 0.4,
                                             "after": 0.3}
    answer(learn_api, headers, session, body(second, "correct"))


# --- concurrency ---------------------------------------------------------------------------------------------------

async def _race(settings: Settings, uid: str, session_id: str, payloads: list[dict[str, Any]]) -> list[Any]:
    resources = Resources.create(settings)

    async def attempt(payload: dict[str, Any]) -> Any:
        async with resources.sessionmaker() as db:
            user = await db.get(User, uid)
            assert user is not None
            await db.commit()
            try:
                return await answers.submit(db, user, session_id, payload)
            except Exception as exc:
                return exc

    try:
        return list(await asyncio.gather(*(attempt(p) for p in payloads)))
    finally:
        await resources.close()


def test_concurrent_duplicates_record_once(learn_api: TestClient, curriculum_settings: Settings) -> None:
    headers = learner(learn_api)
    uid = user_id(learn_api, headers)
    session = start(learn_api, headers, {"kind": "lesson", "lesson_id": "les_t1_0"})
    mcq = exercises(session)[0]
    payloads = [body(mcq, "incorrect"), body(mcq, "correct"), body(mcq, "incorrect"), body(mcq, "correct")]
    results = asyncio.run(_race(curriculum_settings, uid, session["session_id"], payloads))
    assert all(r == results[0] for r in results) and isinstance(results[0], dict)
    assert answer_count(curriculum_settings, session["session_id"]) == 1
    expected = contextual.update_mastery(Decimal(0), "correct" if results[0]["correct"] else "incorrect")
    assert mastery(curriculum_settings, uid) == expected          # applied exactly once


def test_two_devices_racing_the_retry(learn_api: TestClient, curriculum_settings: Settings) -> None:
    headers = learner(learn_api)
    uid = user_id(learn_api, headers)
    session = start(learn_api, headers, {"kind": "lesson", "lesson_id": "les_t1_0"})
    mcq = exercises(session)[0]
    answer(learn_api, headers, session, body(mcq, "incorrect"))
    before = mastery(curriculum_settings, uid)
    assert before is not None
    payloads = [body(mcq, "correct", retry=True), body(mcq, "retry_incorrect", retry=True)] * 2
    results = asyncio.run(_race(curriculum_settings, uid, session["session_id"], payloads))
    assert all(r == results[0] for r in results)
    assert answer_count(curriculum_settings, session["session_id"]) == 2
    rule = "retry_correct" if results[0]["correct"] else "retry_incorrect"
    assert mastery(curriculum_settings, uid) == contextual.update_mastery(before, rule)


def test_mastery_rounds_half_up_for_display(learn_api: TestClient, curriculum_settings: Settings) -> None:
    # 0.3 + 0.35 * 0.7 = 0.545 -> reported 0.55 (backend §7.1); stored exactly.
    headers = learner(learn_api)
    uid = user_id(learn_api, headers)
    practiced(curriculum_settings, uid, "con_test", due="now() + interval '1 day'", mastery="0.3")
    session = start(learn_api, headers, {"kind": "lesson", "lesson_id": "les_t1_0"})
    evaluation = answer(learn_api, headers, session, body(exercises(session)[0], "correct"))
    assert evaluation["mastery_changes"][0]["before"] == 0.3 and evaluation["mastery_changes"][0]["after"] == 0.55
    assert mastery(curriculum_settings, uid) == Decimal("0.545000")
