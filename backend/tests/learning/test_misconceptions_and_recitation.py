"""Misconceptions (backend §7.2) and recitation answers (API §6.6, backend §6.3) through the API.

The contract's test curriculum has neither, so ``les_t2_2`` is revised through the real pipeline: its
``spot_error`` maps the wrong segment to a misconception, its ``scenario`` targets it, and a ``recite_verse``
specimen is appended. Recitation checks are inserted directly; the ASR worker that produces them is Phase 10.
"""

from __future__ import annotations

import copy
import hashlib
import json
from typing import Any

import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.contract import FIXTURES_DIR
from tests.api.helpers import execute, query
from tests.learning.conftest import learner, revise, user_id

pytestmark = pytest.mark.integration

MIS = "mis_t_test"
SPOT, WHICH, ORDER, SCENARIO, RECITE = "ex_t22_0", "ex_t22_1", "ex_t22_2", "ex_t22_3", "ex_t22_rc"
FOLDERS = {SPOT: "spot_error", WHICH: "which_evidence", ORDER: "order_steps", SCENARIO: "scenario"}


def _load(path: str) -> Any:
    return json.loads((FIXTURES_DIR / path).read_text(encoding="utf-8"))


def _with_misconception_and_recitation(data: dict[str, Any]) -> None:
    spot = next(e for e in data["exercises"] if e["exercise_id"] == SPOT)
    for lang in ("ar", "en"):
        spot["exercise"][lang]["option_misconceptions"] = {"seg_3": MIS}
    next(e for e in data["exercises"] if e["exercise_id"] == SCENARIO)["targets_misconception_id"] = MIS
    data["misconceptions"].append({
        "misconception_id": MIS, "concept_id": "con_test",
        "title": {"ar": "فكرة خاطئة اختبارية", "en": "A test misconception"},
        "card": {"ar": [{"type": "text", "text": "بطاقة تصحيح اختبارية."}],
                 "en": [{"type": "text", "text": "A test correction card."}]},
        "source_ids": []})
    specimen = _load("exercises/recite_verse/exercise.json")
    passed = _load("exercises/recite_verse/eval_passed.json")
    recite = {**specimen, "exercise_id": RECITE, "answer_key": None, "option_misconceptions": {},
              "duel_eligible": False}
    data["exercises"].append({
        "exercise_id": RECITE, "purpose": "lesson", "exercise": {"ar": recite, "en": copy.deepcopy(recite)},
        "feedback": {lang: {"explanation": passed["explanation"], "option_feedback": [], "event_dates": [],
                            "pin_labels": []} for lang in ("ar", "en")},
        "targets_misconception_id": None, "source_ids": ["src_q_112_1"]})
    if not any(s["source_id"] == "src_q_112_1" for s in data["sources"]):
        raise AssertionError("les_t2_2 should already carry src_q_112_1 (which_evidence)")
    for by in data["variants"].values():
        for variant in by.values():
            variant["blocks"].append({"block_id": "b_rc", "type": "exercise", "exercise_id": RECITE})
    data["arc_map"][-1]["block_ids"].append("b_rc")


@pytest.fixture
def revised(fresh_curriculum: tuple[TestClient, Settings]) -> tuple[TestClient, Settings]:
    client, settings = fresh_curriculum
    revise(settings, "les_t2_2", _with_misconception_and_recitation)
    return client, settings


def start(client: TestClient, headers: dict[str, str]) -> dict[str, Any]:
    response = client.post("/v1/sessions", json={"kind": "lesson", "lesson_id": "les_t2_2"}, headers=headers)
    assert response.status_code == 201, response.text
    return dict(response.json())


def submit(client: TestClient, headers: dict[str, str], session: dict[str, Any], exercise_id: str, outcome: str, *,
           retry: bool = False, status: int = 200) -> dict[str, Any]:
    payload = {**_load(f"exercises/{FOLDERS[exercise_id]}/answer_{outcome}.json"), "exercise_id": exercise_id,
               "is_retry": retry}
    response = client.post(f"/v1/sessions/{session['session_id']}/answers", json=payload, headers=headers)
    assert response.status_code == status, response.text
    return dict(response.json())


def recite(client: TestClient, headers: dict[str, str], session: dict[str, Any], answer: dict[str, Any],
           status: int = 200) -> dict[str, Any]:
    response = client.post(f"/v1/sessions/{session['session_id']}/answers", headers=headers,
                           json={"exercise_id": RECITE, "answer": answer, "elapsed_ms": 30000, "is_retry": False})
    assert response.status_code == status, response.text
    return dict(response.json())


def learner_misconception(settings: Settings, uid: str) -> dict[str, Any]:
    row = query(settings.database_url, "SELECT status, evidence_score, correct_streak, resolved_at IS NOT NULL AS "
                "resolved FROM learner_misconceptions WHERE user_id = $1 AND misconception_id = $2", uid, MIS)
    return dict(row[0]) if row else {}


def add_check(settings: Settings, uid: str, check_id: str, *, passed: bool, word_start: int | None = None,
              word_end: int | None = None, text: str | None = None) -> None:
    payload = _load("exercises/recite_verse/exercise.json")["payload"]
    digest = hashlib.sha256((text or payload["text_uthmani"]).encode()).hexdigest()
    execute(settings.database_url, "INSERT INTO recitation_checks (id, user_id, surah, ayah, word_start, word_end, "
            "checked_text_sha256, status, passed, words, summary) VALUES ($1, $2, 112, 1, $3, $4, $5, 'evaluated', "
            "$6, '[]'::jsonb, '{}'::jsonb)", check_id, uid, word_start, word_end, digest, passed)


def test_misconceptions_activate_show_and_resolve(revised: tuple[TestClient, Settings]) -> None:
    client, settings = revised
    headers = learner(client)
    uid = user_id(client, headers)
    session = start(client, headers)

    wrong = submit(client, headers, session, SPOT, "incorrect")            # the mapped segment: +1.0 -> active
    assert wrong["misconception"] == {"misconception_id": MIS, "title": "فكرة خاطئة اختبارية",
                                      "card": [{"type": "text", "text": "بطاقة تصحيح اختبارية."}], "source_ids": []}
    assert learner_misconception(settings, uid) == {"status": "active", "evidence_score": 1, "correct_streak": 0,
                                                    "resolved": False}
    submit(client, headers, session, WHICH, "correct")
    submit(client, headers, session, ORDER, "correct")
    targeted = submit(client, headers, session, SCENARIO, "incorrect")     # targets it: +0.5, no card
    assert targeted["misconception"] is None
    assert learner_misconception(settings, uid)["evidence_score"] == 1.5
    retry = submit(client, headers, session, SPOT, "correct", retry=True)  # retries never touch misconceptions
    assert retry["misconception"] is None and learner_misconception(settings, uid)["correct_streak"] == 0
    stored = query(settings.database_url, "SELECT misconception_id FROM session_answers WHERE session_id = $1 "
                   "ORDER BY id", session["session_id"])
    assert [r["misconception_id"] for r in stored] == [MIS, None, None, None, None]

    for outcomes in (("correct", "correct"), ("correct",)):                # three correct answers resolve it
        client.post(f"/v1/sessions/{session['session_id']}/abandon", headers=headers)
        session = start(client, headers)
        submit(client, headers, session, SPOT, outcomes[0])
        if len(outcomes) > 1:
            submit(client, headers, session, WHICH, "correct")
            submit(client, headers, session, ORDER, "correct")
            submit(client, headers, session, SCENARIO, outcomes[1])
    assert learner_misconception(settings, uid) == {"status": "resolved", "evidence_score": 1.5,
                                                    "correct_streak": 3, "resolved": True}

    client.post(f"/v1/sessions/{session['session_id']}/abandon", headers=headers)
    session = start(client, headers)
    again = submit(client, headers, session, SPOT, "incorrect")            # new evidence reactivates it
    assert again["misconception"]["misconception_id"] == MIS
    assert learner_misconception(settings, uid)["status"] == "active"


def test_an_active_misconception_chosen_again_shows_its_card(revised: tuple[TestClient, Settings]) -> None:
    client, settings = revised
    headers = learner(client, language="en")
    uid = user_id(client, headers)
    first = start(client, headers)
    assert submit(client, headers, first, SPOT, "incorrect")["misconception"]["title"] == "A test misconception"
    client.post(f"/v1/sessions/{first['session_id']}/abandon", headers=headers)
    second = start(client, headers)
    submit(client, headers, second, SPOT, "correct")
    assert learner_misconception(settings, uid)["correct_streak"] == 1
    client.post(f"/v1/sessions/{second['session_id']}/abandon", headers=headers)
    third = start(client, headers)
    shown = submit(client, headers, third, SPOT, "incorrect")
    assert shown["misconception"]["misconception_id"] == MIS                # shown again
    assert learner_misconception(settings, uid)["correct_streak"] == 0      # and the streak restarts


def test_recitation_answers_bind_to_the_callers_check(revised: tuple[TestClient, Settings]) -> None:
    client, settings = revised
    headers, other = learner(client), learner(client)
    uid, other_uid = user_id(client, headers), user_id(client, other)
    session = start(client, headers)
    for exercise_id in (SPOT, WHICH, ORDER, SCENARIO):
        submit(client, headers, session, exercise_id, "correct")
    add_check(settings, uid, "rchk_t_segment", passed=True, word_start=1, word_end=2)
    add_check(settings, uid, "rchk_t_other_text", passed=True, text="نص آخر")
    add_check(settings, other_uid, "rchk_t_not_mine", passed=True)
    add_check(settings, uid, "rchk_t_failed", passed=False)
    add_check(settings, uid, "rchk_t_passed", passed=True)
    for check_id in ("rchk_t_segment", "rchk_t_other_text", "rchk_t_not_mine", "rchk_t_missing"):
        error = recite(client, headers, session, {"check_id": check_id}, status=409)["error"]
        assert error["code"] == "recitation_check_mismatch"
    before = query(settings.database_url, "SELECT mastery FROM learner_concepts WHERE user_id = $1", uid)[0]["mastery"]
    evaluation = recite(client, headers, session, {"check_id": "rchk_t_passed"})
    assert (evaluation["correct"], evaluation["correct_answer"], evaluation["details"], evaluation["xp_awarded"]) == \
        (True, None, None, 3)
    assert evaluation["mastery_changes"][0]["before"] == round(float(before), 2)
    assert recite(client, headers, session, {"check_id": "rchk_t_failed"}) == evaluation   # replay, no new XP
    grants = query(settings.database_url, "SELECT reason, xp, ref_id, week_key, local_date FROM xp_events "
                   "WHERE user_id = $1", uid)
    assert [(g["reason"], g["xp"], g["ref_id"]) for g in grants] == \
        [("recitation_passed", 3, f"{session['session_id']}:{RECITE}")]
    assert grants[0]["week_key"].startswith("20") and "-W" in grants[0]["week_key"]
    retry = client.post(f"/v1/sessions/{session['session_id']}/answers", headers=headers,
                        json={"exercise_id": RECITE, "answer": {"check_id": "rchk_t_passed"}, "elapsed_ms": 1,
                              "is_retry": True})
    assert retry.status_code == 409 and retry.json()["error"]["code"] == "retry_not_allowed"


def test_failed_and_skipped_recitations(revised: tuple[TestClient, Settings]) -> None:
    client, settings = revised
    headers = learner(client)
    uid = user_id(client, headers)
    for answer, correct in (({"check_id": "rchk_t_fail2"}, False), ({"skipped": True}, None)):
        add_check(settings, uid, "rchk_t_fail2", passed=False) if correct is False else None
        session = start(client, headers)
        for exercise_id in (SPOT, WHICH, ORDER, SCENARIO):
            submit(client, headers, session, exercise_id, "correct")
        evaluation = recite(client, headers, session, answer)
        assert (evaluation["correct"], evaluation["mastery_changes"], evaluation["xp_awarded"]) == (correct, [], 0)
        client.post(f"/v1/sessions/{session['session_id']}/abandon", headers=headers)
    assert not query(settings.database_url, "SELECT 1 FROM xp_events WHERE user_id = $1", uid)
