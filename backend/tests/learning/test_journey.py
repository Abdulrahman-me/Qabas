"""Journey, access and next steps on the test curriculum (QUALITY §18.1 ``test_curriculum``, journey part).

Learner facts that later phases write (lesson completion, pretest and unit-test results, FSRS due dates) are
inserted directly; Phases 6-7 produce them through answers and finish.
"""

from __future__ import annotations

import json
from datetime import UTC, datetime
from typing import Any

import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.contract import FIXTURES_DIR
from app.contract import models as C
from tests.api.helpers import execute
from tests.api.test_auth import add_reviewer, login
from tests.learning.conftest import bearer, learner, user_id

pytestmark = pytest.mark.integration

CURRICULUM = FIXTURES_DIR / "curriculum_test"
STANDALONE = {"les_t1_0", "les_t2_0", "les_t2_2", "les_t3_2"}


def journey(client: TestClient, headers: dict[str, str], lang: str | None = None) -> dict[str, Any]:
    extra = {"Accept-Language": lang} if lang else {}
    response = client.get("/v1/journey", headers={**headers, **extra})
    assert response.status_code == 200, response.text
    C.Journey.model_validate(response.json())
    return dict(response.json())


def lessons(body: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {lsn["lesson_id"]: lsn for unit in body["units"] for lsn in unit["lessons"]}


def units(body: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {unit["unit_id"]: unit for unit in body["units"]}


def next_step(client: TestClient, headers: dict[str, str]) -> dict[str, Any]:
    response = client.get("/v1/journey/next", headers=headers)
    assert response.status_code == 200, response.text
    return dict(response.json())


def complete(settings: Settings, uid: str, *lesson_ids: str) -> None:
    for lesson_id in lesson_ids:
        execute(settings.database_url, "INSERT INTO learner_lessons (user_id, lesson_id, completed_at) "
                                       "VALUES ($1, $2, now())", uid, lesson_id)


def unit_fact(settings: Settings, uid: str, unit_id: str, **facts: Any) -> None:
    columns = ", ".join(facts)
    values = ", ".join(f"${i + 3}" for i in range(len(facts)))
    updates = ", ".join(f"{k} = EXCLUDED.{k}" for k in facts)
    execute(settings.database_url, f"INSERT INTO learner_units (user_id, unit_id, {columns}) VALUES ($1, $2, {values}) "
                                   f"ON CONFLICT (user_id, unit_id) DO UPDATE SET {updates}",
            uid, unit_id, *facts.values())


def pass_unit(settings: Settings, uid: str, unit_id: str) -> None:
    execute(settings.database_url, "INSERT INTO learner_units (user_id, unit_id, unit_test_passed_at, "
                                   "unit_test_best_percent) VALUES ($1, $2, now(), 90) ON CONFLICT (user_id, unit_id) "
                                   "DO UPDATE SET unit_test_passed_at = now(), unit_test_best_percent = 90",
            uid, unit_id)


def structure(body: dict[str, Any]) -> dict[str, Any]:
    """Everything the fixtures fix except lesson titles and XP (decisions D-31, D-49)."""
    return {"track": body["track"], "current": body["current"], "units": [
        {**{k: v for k, v in unit.items() if k != "lessons"},
         "lessons": [{**{k: v for k, v in lsn.items() if k not in ("title", "xp", "soft_lock")},
                      "soft_lock": None if lsn["soft_lock"] is None else {
                          "prerequisites": [(r["lesson_id"], r["unit_id"]) for r in lsn["soft_lock"]["prerequisites"]],
                          "start_with": (lsn["soft_lock"]["start_with"]["lesson_id"],
                                         lsn["soft_lock"]["start_with"]["unit_id"])}}
                     for lsn in unit["lessons"]]} for unit in body["units"]]}


# --- the contract journeys ----------------------------------------------------------------------------------

@pytest.mark.parametrize(("lang", "track"), [("ar", "explorer"), ("en", "explorer"), ("ar", "new_muslim"),
                                             ("en", "new_muslim")])
def test_journey_matches_the_contract_fixture_once_the_start_unit_is_under_way(
        learn_api: TestClient, lang: str, track: str) -> None:
    headers = learner(learn_api, track=track, language=lang)
    expected = json.loads((CURRICULUM / f"journey_{lang}_{track}.json").read_text(encoding="utf-8"))
    start_unit = expected["current"]["unit_id"]
    fresh = journey(learn_api, headers)
    # The fixture generator marks the start unit in_progress; by backend §6.1 a unit is in_progress only
    # once one of its sessions started, so a brand-new learner sees it available (finding F-14).
    assert units(fresh)[start_unit]["state"] == "available"
    response = learn_api.post("/v1/sessions", json={"kind": "pretest", "unit_id": start_unit}, headers=headers)
    assert response.status_code == 201, response.text
    body = journey(learn_api, headers)
    assert structure(body) == structure(expected)
    assert all(lsn["xp"] == 13 for lsn in lessons(body).values())          # D-31: completion 10 + perfect 3
    # Lesson titles are the published variant's title for the learner's track (finding F-15).
    for lesson_id, lsn in lessons(body).items():
        variant = track if (CURRICULUM / "lessons" / f"{lesson_id}__{lang}_{track}.json").exists() else "explorer"
        path = CURRICULUM / "lessons" / f"{lesson_id}__{lang}_{variant}.json"
        session = json.loads(path.read_text(encoding="utf-8"))
        assert lsn["title"] == session["title"]


def test_explorer_only_units_are_outside_the_new_muslim_journey(learn_api: TestClient) -> None:
    explorer, new_muslim = learner(learn_api), learner(learn_api, track="new_muslim")
    assert "unit_test_1" in units(journey(learn_api, explorer))
    assert "unit_test_1" not in units(journey(learn_api, new_muslim))
    response = learn_api.post("/v1/sessions", json={"kind": "lesson", "lesson_id": "les_t1_0"}, headers=new_muslim)
    assert response.status_code == 404
    response = learn_api.post("/v1/sessions", json={"kind": "pretest", "unit_id": "unit_test_1"}, headers=new_muslim)
    assert response.status_code == 404
    assert learn_api.get("/v1/lessons/les_t1_0", headers=new_muslim).status_code == 404


def test_track_framing_and_language(learn_api: TestClient) -> None:
    headers = learner(learn_api, track="new_muslim", language="ar")
    english = journey(learn_api, headers, "en")
    unit = units(english)["unit_test_2"]
    expected = json.loads((CURRICULUM / "journey_en_new_muslim.json").read_text(encoding="utf-8"))
    assert (unit["title"], unit["subtitle"]) == (units(expected)["unit_test_2"]["title"],
                                                units(expected)["unit_test_2"]["subtitle"])
    nm = json.loads((CURRICULUM / "lessons" / "les_t2_0__ar_new_muslim.json").read_text(encoding="utf-8"))
    assert lessons(journey(learn_api, headers))["les_t2_0"]["title"] == nm["title"]   # the track's variant
    assert lessons(journey(learn_api, headers, "fr, en;q=0.5"))["les_t2_0"]["title"] == \
        lessons(english)["les_t2_0"]["title"]                                    # q-weighted negotiation
    assert lessons(journey(learn_api, headers, "fr"))["les_t2_0"]["title"] != \
        lessons(english)["les_t2_0"]["title"]                                    # unsupported -> profile (ar)


# --- access, Soft Lock, standalone ------------------------------------------------------------------------------

def test_soft_lock_and_prerequisite_unmet(learn_api: TestClient, curriculum_settings: Settings) -> None:
    headers = learner(learn_api)
    body = lessons(journey(learn_api, headers))
    assert body["les_t1_2"]["soft_lock"]["prerequisites"][0]["lesson_id"] == "les_t1_1"
    assert body["les_t1_2"]["soft_lock"]["start_with"]["lesson_id"] == "les_t1_0"      # transitive
    response = learn_api.post("/v1/sessions", json={"kind": "lesson", "lesson_id": "les_t1_2"}, headers=headers)
    assert response.status_code == 409
    assert response.json()["error"]["code"] == "prerequisite_unmet"
    assert response.json()["error"]["details"] == {"prerequisite_lesson_ids": ["les_t1_1"],
                                                   "start_with_lesson_id": "les_t1_0"}
    assert learn_api.get("/v1/lessons/les_t1_2", headers=headers).status_code == 409

    complete(curriculum_settings, user_id(learn_api, headers), "les_t1_0")
    body = lessons(journey(learn_api, headers))
    assert body["les_t1_0"]["state"] == "completed" and body["les_t1_1"]["state"] == "available"
    assert body["les_t1_2"]["soft_lock"]["start_with"]["lesson_id"] == "les_t1_1"


def test_position_is_never_a_prerequisite(learn_api: TestClient) -> None:
    body = lessons(journey(learn_api, learner(learn_api)))
    assert body["les_t3_1"]["state"] == "available" and not body["les_t3_1"]["standalone_eligible"]
    assert body["les_t3_0"]["state"] == "locked"
    assert body["les_t3_0"]["soft_lock"]["start_with"] == {"lesson_id": "les_t2_0", "unit_id": "unit_test_2",
                                                           "title": body["les_t2_0"]["title"]}
    assert {lid for lid, lsn in body.items() if lsn["standalone_eligible"]} == STANDALONE
    assert all(body[lid]["state"] != "locked" for lid in STANDALONE)


def test_a_passed_unit_test_satisfies_its_concepts(learn_api: TestClient, curriculum_settings: Settings) -> None:
    headers = learner(learn_api)
    uid = user_id(learn_api, headers)
    pass_unit(curriculum_settings, uid, "unit_test_2")
    body = journey(learn_api, headers)
    assert units(body)["unit_test_2"]["state"] == "skipped"
    assert units(body)["unit_test_2"]["unit_test"] == {"state": "passed", "best_percent": 90, "pass_percent": 80,
                                                      "can_skip": False}
    assert lessons(body)["les_t3_0"]["state"] == "available"        # its prerequisite's unit was passed
    assert lessons(body)["les_t2_1"]["state"] == "available"         # its prerequisite's unit was passed too
    assert lessons(body)["les_t2_0"]["state"] == "available"         # the lessons themselves aren't completed
    complete(curriculum_settings, uid, "les_t2_0", "les_t2_1", "les_t2_2", "les_t2_3")
    assert units(journey(learn_api, headers))["unit_test_2"]["state"] == "completed"


def test_track_switch_keeps_completions(learn_api: TestClient, curriculum_settings: Settings) -> None:
    headers = learner(learn_api)
    complete(curriculum_settings, user_id(learn_api, headers), "les_t1_0", "les_t2_0")
    assert learn_api.patch("/v1/me", json={"track": "new_muslim"}, headers=headers).status_code == 200
    body = journey(learn_api, headers)
    assert body["track"] == "new_muslim" and "unit_test_1" not in units(body)
    assert lessons(body)["les_t2_0"]["state"] == "completed"
    learn_api.patch("/v1/me", json={"track": "explorer"}, headers=headers)
    assert lessons(journey(learn_api, headers))["les_t1_0"]["state"] == "completed"


def test_coming_soon_units(learn_api: TestClient) -> None:
    headers = learner(learn_api)
    unit = units(journey(learn_api, headers))["unit_test_4"]
    assert (unit["state"], unit["coming_soon"], unit["lessons"], unit["unit_test"]["can_skip"]) == \
        ("locked", True, [], False)
    for kind in ("pretest", "unit_test"):
        response = learn_api.post("/v1/sessions", json={"kind": kind, "unit_id": "unit_test_4"}, headers=headers)
        assert response.status_code == 404


def test_any_started_session_puts_its_unit_in_progress(learn_api: TestClient) -> None:
    headers = learner(learn_api)
    response = learn_api.post("/v1/sessions", json={"kind": "lesson", "lesson_id": "les_t2_2"}, headers=headers)
    assert response.status_code == 201
    body = journey(learn_api, headers)
    assert units(body)["unit_test_2"]["state"] == "in_progress"
    assert lessons(body)["les_t2_2"]["state"] == "in_progress"
    session_id = response.json()["session_id"]
    assert learn_api.post(f"/v1/sessions/{session_id}/abandon", headers=headers).status_code == 204
    body = journey(learn_api, headers)
    assert lessons(body)["les_t2_2"]["state"] == "available"
    assert units(body)["unit_test_2"]["state"] == "in_progress"      # it was started


# --- next step and the current pointer -------------------------------------------------------------------------

def test_next_steps_follow_the_planner(learn_api: TestClient, curriculum_settings: Settings) -> None:
    headers = learner(learn_api, language="en")
    uid = user_id(learn_api, headers)
    step = next_step(learn_api, headers)
    assert (step["type"], step["reason"], step["unit_id"]) == ("pretest", "new_unit_pretest", "unit_test_1")
    assert step["title"] == "A quick check before you start" and step["due_reviews_count"] == 0

    unit_fact(curriculum_settings, uid, "unit_test_1", pretest_taken_at=datetime(2026, 10, 4, 9, tzinfo=UTC),
              pretest_percent=50)
    step = next_step(learn_api, headers)
    assert (step["type"], step["lesson_id"]) == ("lesson", "les_t1_0")
    assert step["title"] == lessons(journey(learn_api, headers))["les_t1_0"]["title"]

    complete(curriculum_settings, uid, "les_t1_0", "les_t1_1", "les_t1_2")
    step = next_step(learn_api, headers)
    assert (step["type"], step["reason"], step["unit_id"]) == ("unit_test", "unit_ready_for_test", "unit_test_1")
    assert journey(learn_api, headers)["current"] == {"unit_id": "unit_test_1", "lesson_id": None}

    pass_unit(curriculum_settings, uid, "unit_test_1")
    step = next_step(learn_api, headers)
    assert (step["type"], step["unit_id"]) == ("pretest", "unit_test_2")
    assert journey(learn_api, headers)["current"] == {"unit_id": "unit_test_2", "lesson_id": "les_t2_0"}

    for unit_id in ("unit_test_2", "unit_test_3"):
        pass_unit(curriculum_settings, uid, unit_id)
    step = next_step(learn_api, headers)
    assert (step["type"], step["reason"], step["unit_id"], step["title"]) == \
        ("journey_complete", "all_done", None, None)                   # unit_test_4 is coming soon
    assert journey(learn_api, headers)["current"] == {"unit_id": None, "lesson_id": None}


def test_a_discover_completion_means_no_pretest(learn_api: TestClient, curriculum_settings: Settings) -> None:
    headers = learner(learn_api)
    complete(curriculum_settings, user_id(learn_api, headers), "les_t1_0")
    step = next_step(learn_api, headers)
    assert (step["type"], step["lesson_id"]) == ("lesson", "les_t1_1")


def test_due_reviews_come_before_lessons(learn_api: TestClient, curriculum_settings: Settings) -> None:
    headers = learner(learn_api)
    uid = user_id(learn_api, headers)
    unit_fact(curriculum_settings, uid, "unit_test_1", pretest_taken_at=datetime(2026, 10, 4, 9, tzinfo=UTC),
              pretest_percent=50)
    concepts = ["con_t1_0", "con_t1_1", "con_t2_0", "con_t2_1", "con_t2_2"]
    for concept_id in concepts[:4]:
        practiced(curriculum_settings, uid, concept_id, due="now() - interval '1 hour'")
    assert next_step(learn_api, headers)["type"] == "lesson"              # 4 due concepts: below the threshold
    practiced(curriculum_settings, uid, concepts[4], due="now() - interval '1 hour'")
    step = next_step(learn_api, headers)
    assert (step["type"], step["reason"], step["due_reviews_count"]) == ("review", "due_reviews", 5)


def practiced(settings: Settings, uid: str, concept_id: str, *, due: str, mastery: str = "0.5") -> None:
    execute(settings.database_url,
            f"INSERT INTO learner_concepts (user_id, concept_id, mastery, due_at, first_practiced_at) "
            f"VALUES ($1, $2, {mastery}, {due}, now() - interval '2 days')", uid, concept_id)


def test_reviewers_have_no_journey(learn_api: TestClient, curriculum_settings: Settings) -> None:
    add_reviewer(curriculum_settings.database_url)
    token = login(learn_api, "reviewer@example.test").json()["access_token"]  # type: ignore[attr-defined]
    for path in ("/v1/journey", "/v1/journey/next", "/v1/lessons/les_t1_0"):
        assert learn_api.get(path, headers=bearer(token)).status_code == 403
    response = learn_api.post("/v1/sessions", json={"kind": "lesson", "lesson_id": "les_t1_0"}, headers=bearer(token))
    assert response.status_code == 403
