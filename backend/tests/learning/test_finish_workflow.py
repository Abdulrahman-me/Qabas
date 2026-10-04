"""Contract §6.5 arithmetic and recitation/misconception/outbox integration on published content."""

import copy
import json
import re
from datetime import UTC, datetime, timedelta
from typing import Any

import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.contract import FIXTURES_DIR, VENDOR_ROOT
from app.services.learning import answers, sessions
from app.services.learning import finish as service
from tests.api.helpers import execute, query
from tests.learning.conftest import learner, revise, user_id
from tests.learning.test_finish import finish, reasons
from tests.learning.test_misconceptions_and_recitation import (
    MIS,
    ORDER,
    RECITE,
    SCENARIO,
    SPOT,
    WHICH,
    _with_misconception_and_recitation,
    add_check,
    recite,
    start,
    submit,
)

pytestmark = pytest.mark.integration


def example_content(data: dict[str, Any]) -> None:
    _with_misconception_and_recitation(data)
    mc_ex = json.loads((FIXTURES_DIR / "exercises/multiple_choice/exercise.json").read_text(encoding="utf-8"))
    mc_eval = json.loads((FIXTURES_DIR / "exercises/multiple_choice/eval_correct.json").read_text(encoding="utf-8"))
    mc = {**mc_ex, "exercise_id": "ex_t22_mc", "concept_ids": ["con_allah_one"],
          "answer_key": mc_eval["correct_answer"], "option_misconceptions": {}, "duel_eligible": False}
    data["exercises"].append({"exercise_id": "ex_t22_mc", "purpose": "lesson",
                              "exercise": {"ar": mc, "en": copy.deepcopy(mc)},
                              "feedback": {lang: {"explanation": mc_eval["explanation"], "option_feedback": [],
                                                   "event_dates": [], "pin_labels": []} for lang in ("ar", "en")},
                              "targets_misconception_id": None, "source_ids": []})
    for e in data["exercises"]:
        if e["exercise_id"] in (SPOT, RECITE):
            for lang in ("ar", "en"):
                e["exercise"][lang]["concept_ids"] = ["con_qibla" if e["exercise_id"] == SPOT else "con_allah_one"]
    for variants in data["variants"].values():
        for variant in variants.values():
            content = [b for b in variant["blocks"] if b["type"] != "exercise"]
            variant["blocks"] = [*content, {"block_id": "b_mc", "type": "exercise", "exercise_id": "ex_t22_mc"},
                                           {"block_id": "b_spot", "type": "exercise", "exercise_id": SPOT},
                                           {"block_id": "b_rc", "type": "exercise", "exercise_id": RECITE}]
    kept = {b["block_id"] for b in next(iter(data["variants"]["ar"].values()))["blocks"]}
    for step in data["arc_map"]:
        step["block_ids"] = [b for b in step["block_ids"] if b in kept]
    data["arc_map"][-1]["block_ids"] = [b for b in data["arc_map"][-1]["block_ids"] if b != "b_rc"]
    data["arc_map"][-1]["block_ids"] += ["b_mc", "b_spot", "b_rc"]


def test_finish_workflow_contract_65(fresh_curriculum: tuple[TestClient, Settings],
                                   monkeypatch: pytest.MonkeyPatch) -> None:
    client, settings = fresh_curriculum
    for cid, title in (("con_allah_one", "وحدانية الله"), ("con_qibla", "القِبلة")):
        execute(settings.database_url, "INSERT INTO concepts(id,unit_id,title) VALUES($1,'unit_test_2',$2::jsonb)",
                cid, json.dumps({"ar": title, "en": title}))
    revise(settings, "les_t2_2", example_content)
    at = datetime(2026, 10, 4, 13, tzinfo=UTC)
    monkeypatch.setattr(sessions, "utcnow", lambda: at)
    monkeypatch.setattr(answers, "utcnow", lambda: at + timedelta(seconds=10))
    monkeypatch.setattr(service, "utcnow", lambda: at + timedelta(milliseconds=312000))
    headers = learner(client)
    uid = user_id(client, headers)
    for cid, mastery in (("con_allah_one", .2), ("con_qibla", .4)):
        execute(settings.database_url, "INSERT INTO learner_concepts(user_id,concept_id,mastery) VALUES($1,$2,$3)",
                uid, cid, mastery)
    for days, minutes in ((2, 0), (1, 0), (0, 7)):
        execute(settings.database_url, "INSERT INTO daily_activity(user_id,local_date,qualifying,minutes,duration_ms) "
                "VALUES($1,$2,true,$3,$4)", uid, (at - timedelta(days=days)).date(), minutes, minutes * 60000)
    for slot, kind in enumerate(("earn_xp", "complete_review", "win_challenge"), 1):
        execute(settings.database_url, "INSERT INTO quests(user_id,local_date,slot,kind,goal,reward_xp) "
                "VALUES($1,$2,$3,$4,30,10)", uid, at.date(), slot, kind)
    add_check(settings, uid, "rchk_example", passed=True)
    session = start(client, headers)
    correct = json.loads((FIXTURES_DIR / "exercises/multiple_choice/answer_correct.json").read_text(encoding="utf-8"))
    response = client.post(f"/v1/sessions/{session['session_id']}/answers", headers=headers,
                           json={**correct, "exercise_id": "ex_t22_mc"})
    assert response.status_code == 200, response.text
    submit(client, headers, session, SPOT, "incorrect")
    assert recite(client, headers, session, {"check_id": "rchk_example"})["xp_awarded"] == 3
    submit(client, headers, session, SPOT, "correct", retry=True)
    result = finish(client, headers, session, 312000)
    examples = [json.loads(block) for block in re.findall(r"```json\s*\n(.*?)\n```", (
        VENDOR_ROOT / "03_API/API_REQUIREMENTS.md").read_text(encoding="utf-8"), re.S)]
    expected = next(e for e in examples if isinstance(e, dict) and e.get("session_id") == "ses_91ab" and "score" in e)
    for key in ("score", "layers", "duration_ms", "xp", "daily_goal", "mastery_summary"):
        assert result[key] == expected[key], key
    assert result["streak"]["current"] == 3
    assert result["misconceptions"]["activated"] == [{"misconception_id": MIS, "title": "فكرة خاطئة اختبارية"}]


def test_recitation_cannot_farm_by_abandoning_and_restarting(fresh_curriculum: tuple[TestClient, Settings]) -> None:
    client, settings = fresh_curriculum
    revise(settings, "les_t2_2", _with_misconception_and_recitation)
    headers = learner(client)
    uid = user_id(client, headers)
    add_check(settings, uid, "rchk_once", passed=True)
    for index in range(3):
        session = start(client, headers)
        for eid in (SPOT, WHICH, ORDER, SCENARIO):
            submit(client, headers, session, eid, "correct")
        evaluation = recite(client, headers, session, {"check_id": "rchk_once"})
        assert evaluation["correct"] and evaluation["mastery_changes"]
        assert evaluation["xp_awarded"] == (3 if index == 0 else 0)
        if index == 0:
            client.post(f"/v1/sessions/{session['session_id']}/abandon", headers=headers)
        else:
            result = finish(client, headers, session)
            assert "recitation_passed" not in reasons(result)
    assert len(query(settings.database_url, "SELECT 1 FROM xp_events WHERE user_id=$1 "
                     "AND reason='recitation_passed'", uid)) == 1
