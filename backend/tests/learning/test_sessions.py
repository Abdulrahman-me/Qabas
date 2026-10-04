"""Session creation, resume and abandon on the test curriculum (API §6.5, backend §6.2).

Covers QUALITY §18.1 ``test_discover_identity``, ``test_assessment_supply`` (serve side) and the resume/redaction
part of ``test_history_redaction``. Answer rows are inserted directly; Phase 6 records them through the API.
"""

from __future__ import annotations

import asyncio
import json
from typing import Any

import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.contract import FIXTURES_DIR
from app.contract import models as C
from app.models import User
from app.runtime import Resources
from app.services.learning import sessions
from tests.api.helpers import execute, query
from tests.learning.conftest import learner, user_id
from tests.learning.test_journey import practiced

pytestmark = pytest.mark.integration

CURRICULUM = FIXTURES_DIR / "curriculum_test"
PER_SESSION = {"session_id", "started_at"}
PRIVATE_FIELDS = ("answer_key", "option_misconceptions", "duel_eligible", "targets_misconception_id")


def start(client: TestClient, headers: dict[str, str], body: dict[str, Any], status: int = 201,
          lang: str | None = None) -> dict[str, Any]:
    extra = {"Accept-Language": lang} if lang else {}
    response = client.post("/v1/sessions", json=body, headers={**headers, **extra})
    assert response.status_code == status, response.text
    if status in (200, 201):
        C.Session.model_validate(response.json())
    return dict(response.json())


def content(session: dict[str, Any]) -> dict[str, Any]:
    return {k: v for k, v in session.items() if k not in PER_SESSION}


def exercises(session: dict[str, Any]) -> list[dict[str, Any]]:
    return [b["exercise"] for b in session["items"] if b["type"] == "exercise"]


def _lesson_files() -> list[tuple[str, str, str]]:
    return sorted((p.name.split("__")[0], *p.stem.split("__")[1].split("_", 1))  # type: ignore[misc]
                  for p in (CURRICULUM / "lessons").glob("*.json"))


# --- lesson sessions -----------------------------------------------------------------------------------------------

@pytest.mark.parametrize(("lesson_id", "lang", "variant"), _lesson_files())
def test_lesson_sessions_equal_the_contract_sessions(learn_api: TestClient, curriculum_settings: Settings,
                                                     lesson_id: str, lang: str, variant: str) -> None:
    headers = learner(learn_api, track=variant, language="ar")
    uid = user_id(learn_api, headers)
    for prerequisite in ("les_t1_0", "les_t1_1", "les_t2_0", "les_t2_1", "les_t2_3"):   # open every lesson
        if prerequisite != lesson_id:
            execute(curriculum_settings.database_url, "INSERT INTO learner_lessons (user_id, lesson_id, "
                    "completed_at) VALUES ($1, $2, now())", uid, prerequisite)
    session = start(learn_api, headers, {"kind": "lesson", "lesson_id": lesson_id}, lang=lang)
    expected = json.loads((CURRICULUM / "lessons" / f"{lesson_id}__{lang}_{variant}.json").read_text(encoding="utf-8"))
    ignore = PER_SESSION | {"reviewed_by"}
    assert {k: v for k, v in session.items() if k not in ignore} == {k: v for k, v in expected.items()
                                                                      if k not in ignore}
    assert session["reviewed_by"] == "test fixture"
    assert not any(field in json.dumps(session) for field in PRIVATE_FIELDS)


def test_prerequisites_then_session(learn_api: TestClient, curriculum_settings: Settings) -> None:
    headers = learner(learn_api, language="en")
    start(learn_api, headers, {"kind": "lesson", "lesson_id": "les_t3_0"}, status=409)
    execute(curriculum_settings.database_url, "INSERT INTO learner_lessons (user_id, lesson_id, completed_at) "
            "VALUES ($1, 'les_t2_3', now())", user_id(learn_api, headers))
    session = start(learn_api, headers, {"kind": "lesson", "lesson_id": "les_t3_0"})
    expected = json.loads((CURRICULUM / "lessons" / "les_t3_0__en_explorer.json").read_text(encoding="utf-8"))
    assert session["items"] == expected["items"] and session["sources"] == expected["sources"]


def test_discover_and_roadmap_serve_byte_identical_lessons(learn_api: TestClient) -> None:
    # The request has no entry-surface field: one is rejected, and two learners opening the same standalone
    # lesson (one "from Discover", one "from the Roadmap") get identical content.
    roadmap, discover = learner(learn_api), learner(learn_api)
    response = learn_api.post("/v1/sessions", json={"kind": "lesson", "lesson_id": "les_t2_2", "surface": "discover"},
                              headers=discover)
    assert response.status_code == 400
    first = start(learn_api, roadmap, {"kind": "lesson", "lesson_id": "les_t2_2"})
    second = start(learn_api, discover, {"kind": "lesson", "lesson_id": "les_t2_2"})
    assert content(first) == content(second)
    assert first["session_id"] != second["session_id"]


def test_one_active_session_per_key(learn_api: TestClient) -> None:
    headers = learner(learn_api, language="ar")
    first = start(learn_api, headers, {"kind": "lesson", "lesson_id": "les_t1_0"}, lang="ar")
    again = start(learn_api, headers, {"kind": "lesson", "lesson_id": "les_t1_0"}, status=200, lang="en")
    assert again == first                                     # same session, still in its pinned language
    learn_api.patch("/v1/me", json={"language": "en"}, headers=headers)
    assert learn_api.get(f"/v1/sessions/{first['session_id']}", headers=headers).json() == first
    other = start(learn_api, headers, {"kind": "lesson", "lesson_id": "les_t2_0"})
    assert other["session_id"] != first["session_id"]


def test_an_active_session_survives_a_track_change(learn_api: TestClient) -> None:
    headers = learner(learn_api)
    first = start(learn_api, headers, {"kind": "lesson", "lesson_id": "les_t1_0"})
    learn_api.patch("/v1/me", json={"track": "new_muslim"}, headers=headers)
    assert start(learn_api, headers, {"kind": "lesson", "lesson_id": "les_t1_0"}, status=200) == first
    learn_api.post(f"/v1/sessions/{first['session_id']}/abandon", headers=headers)
    start(learn_api, headers, {"kind": "lesson", "lesson_id": "les_t1_0"}, status=404)   # outside the track now


def test_new_muslim_variant_and_fallback(learn_api: TestClient) -> None:
    headers = learner(learn_api, track="new_muslim", language="ar")
    session = start(learn_api, headers, {"kind": "lesson", "lesson_id": "les_t2_0"})
    assert session["title"].startswith("[new_muslim]")


def test_requests_are_validated(learn_api: TestClient) -> None:
    headers = learner(learn_api)
    for body in ({"kind": "review"}, {"kind": "lesson"}, {"kind": "pretest"}, {"kind": "lesson", "lesson_id": "x",
                                                                                "mode": "cards"}, {"kind": "duel"}):
        response = learn_api.post("/v1/sessions", json=body, headers=headers)
        assert response.status_code == 400, body
        assert response.json()["error"]["code"] == "validation_error"
    start(learn_api, headers, {"kind": "lesson", "lesson_id": "les_unknown"}, status=404)
    start(learn_api, headers, {"kind": "pretest", "unit_id": "unit_unknown"}, status=404)


# --- assessments -----------------------------------------------------------------------------------------------

def _bank(unit: str, kind: str) -> dict[str, dict[str, Any]]:
    """The contract's assessment session for a unit: exercise_id -> learner exercise (per language)."""
    found: dict[str, dict[str, Any]] = {}
    for path in (CURRICULUM / "assessments").glob(f"ses_{unit}_{kind}_ar_*.json"):
        session = json.loads(path.read_text(encoding="utf-8"))
        found.update({e["exercise_id"]: e for e in exercises(session)})
    return found


@pytest.mark.parametrize(("unit", "kind", "size"), [("unit_test_1", "pretest", 6), ("unit_test_1", "unit_test", 9),
                                                    ("unit_test_2", "pretest", 8), ("unit_test_2", "unit_test", 12),
                                                    ("unit_test_3", "pretest", 6), ("unit_test_3", "unit_test", 9)])
def test_assessments_serve_the_unit_pool_without_repeats(learn_api: TestClient, unit: str, kind: str,
                                                         size: int) -> None:
    headers = learner(learn_api, language="ar")
    session = start(learn_api, headers, {"kind": kind, "unit_id": unit})
    served = exercises(session)
    assert len(served) == size == len({e["exercise_id"] for e in served})      # min(8|12, pool), no repeats
    assert session["feedback_mode"] == ("none" if kind == "pretest" else "end")
    assert (session["objectives"], session["completion"]) == ([], None)
    assert (session["mode"], session["lesson_id"]) == (None, None)
    assert all(e["type"] not in ("flashcard", "recite_verse") for e in served)
    bank = _bank(unit, kind)
    assert {e["exercise_id"] for e in served} <= set(bank) or len(bank) < size
    for exercise in served:
        if exercise["exercise_id"] in bank:
            assert exercise == bank[exercise["exercise_id"]]
    assert not any(field in json.dumps(session) for field in PRIVATE_FIELDS)


def test_assessment_order_is_shuffled_at_serve_time(learn_api: TestClient) -> None:
    headers = learner(learn_api)
    orders = set()
    for _ in range(6):
        session = start(learn_api, headers, {"kind": "unit_test", "unit_id": "unit_test_2"})
        orders.add(tuple(e["exercise_id"] for e in exercises(session)))
        resumed = learn_api.get(f"/v1/sessions/{session['session_id']}", headers=headers).json()
        assert exercises(resumed) == exercises(session)                           # the stored order is kept
        learn_api.post(f"/v1/sessions/{session['session_id']}/abandon", headers=headers)
    assert len(orders) > 1


# --- reviews -----------------------------------------------------------------------------------------------------

def test_nothing_to_review_without_practiced_concepts(learn_api: TestClient) -> None:
    headers = learner(learn_api)
    for mode in ("cards", "quick"):
        response = learn_api.post("/v1/sessions", json={"kind": "review", "mode": mode}, headers=headers)
        assert response.status_code == 409 and response.json()["error"]["code"] == "nothing_to_review"


def test_card_review_orders_due_concepts_first(learn_api: TestClient, curriculum_settings: Settings) -> None:
    headers = learner(learn_api)
    uid = user_id(learn_api, headers)
    practiced(curriculum_settings, uid, "con_t2_1", due="now() + interval '3 days'", mastery="0.1")
    practiced(curriculum_settings, uid, "con_t1_0", due="now() - interval '1 hour'", mastery="0.9")
    practiced(curriculum_settings, uid, "con_t3_2", due="now() - interval '2 hours'", mastery="0.6")
    practiced(curriculum_settings, uid, "con_t2_0", due="now() + interval '1 day'", mastery="0.3")
    session = start(learn_api, headers, {"kind": "review", "mode": "cards"})
    assert [e["exercise_id"] for e in exercises(session)] == ["ex_t3_2_fc", "ex_t1_0_fc", "ex_t2_1_fc", "ex_t2_0_fc"]
    assert all(e["type"] == "flashcard" and e["time_limit_ms"] is None for e in exercises(session))
    assert (session["unit_id"], session["mode"], session["feedback_mode"]) == (None, "cards", "immediate")
    assert session["title"] == "مراجعة البطاقات"


def test_reviews_stay_inside_the_learners_track(learn_api: TestClient, curriculum_settings: Settings) -> None:
    headers = learner(learn_api, track="new_muslim")
    uid = user_id(learn_api, headers)
    practiced(curriculum_settings, uid, "con_t1_0", due="now() - interval '1 hour'")   # Explorer-only unit
    start(learn_api, headers, {"kind": "review", "mode": "cards"}, status=409)
    practiced(curriculum_settings, uid, "con_t2_2", due="now() - interval '1 hour'")
    session = start(learn_api, headers, {"kind": "review", "mode": "cards"})
    assert [e["exercise_id"] for e in exercises(session)] == ["ex_t2_2_fc"]


def test_quick_review_is_timed_and_excludes_untimed_types(learn_api: TestClient,
                                                          curriculum_settings: Settings) -> None:
    headers = learner(learn_api, language="en")
    uid = user_id(learn_api, headers)
    # The contract's graded test exercises all practise ``con_test``; flashcards practise one concept each.
    practiced(curriculum_settings, uid, "con_test", due="now() - interval '1 hour'")
    session = start(learn_api, headers, {"kind": "review", "mode": "quick"})
    served = exercises(session)
    assert 1 <= len(served) <= 10 and len({e["exercise_id"] for e in served}) == len(served)
    assert all(e["time_limit_ms"] == 20000 for e in served)
    assert all(e["type"] not in ("flashcard", "recite_verse", "true_false") for e in served)
    assert not any(e["type"] == "categorize" and e["payload"]["presentation"] == "day_arc" for e in served)
    assert not any(e["type"] == "map_place" and e["payload"]["visual"]["kind"] == "builtin" for e in served)
    assert len(served) == 10 and all("con_test" in e["concept_ids"] for e in served)
    assert session["title"] == "Quick review"


# --- resume, redaction, abandon --------------------------------------------------------------------------------

def _evaluation(exercise_id: str, correct: bool | None) -> dict[str, Any]:
    template = json.loads((FIXTURES_DIR / "sessions" / "history_immediate_active.json").read_text(encoding="utf-8"))
    evaluation = dict(template["answers"][0]["evaluation"])
    return {**evaluation, "exercise_id": exercise_id, "correct": correct}


def record(settings: Settings, session_id: str, exercise_id: str, correct: bool | None, *,
           retry: bool = False) -> None:
    version = query(settings.database_url, "SELECT e.version FROM sessions s, jsonb_to_recordset(s.served_exercises) "
                    "AS e(exercise_id text, version int) WHERE s.id = $1 AND e.exercise_id = $2",
                    session_id, exercise_id)[0]["version"]
    execute(settings.database_url, "INSERT INTO session_answers (session_id, exercise_id, exercise_version, answer, "
            "correct, elapsed_ms, is_retry, evaluation) VALUES ($1, $2, $3, '{}'::jsonb, $4, 1000, $5, $6::jsonb)",
            session_id, exercise_id, version, correct, retry, json.dumps(_evaluation(exercise_id, correct)))


def finish(settings: Settings, session_id: str) -> None:
    execute(settings.database_url, "UPDATE sessions SET status = 'finished', finished_at = now(), duration_ms = 1000, "
            "result_snapshot = '{}'::jsonb WHERE id = $1", session_id)


def test_resume_redacts_history_by_feedback_mode(learn_api: TestClient, curriculum_settings: Settings) -> None:
    headers = learner(learn_api)
    lesson = start(learn_api, headers, {"kind": "lesson", "lesson_id": "les_t1_0"})
    unit_test = start(learn_api, headers, {"kind": "unit_test", "unit_id": "unit_test_1"})
    pretest = start(learn_api, headers, {"kind": "pretest", "unit_id": "unit_test_2"})
    for session in (lesson, unit_test, pretest):
        first, second = (e["exercise_id"] for e in exercises(session)[:2])
        record(curriculum_settings, session["session_id"], first, True)
        record(curriculum_settings, session["session_id"], second, False)
    record(curriculum_settings, lesson["session_id"], exercises(lesson)[1]["exercise_id"], True, retry=True)

    def resumed(session: dict[str, Any]) -> dict[str, Any]:
        response = learn_api.get(f"/v1/sessions/{session['session_id']}", headers=headers)
        assert response.status_code == 200
        C.Session.model_validate(response.json())
        return dict(response.json())

    body = resumed(lesson)
    assert [(a["result"], a["is_retry"]) for a in body["answers"]] == [("correct", False), ("incorrect", False),
                                                                       ("correct", True)]
    assert all(a["evaluation"] is not None for a in body["answers"]) and body["answered_exercises"] == 2
    assert content({**body, "answers": [], "answered_exercises": 0}) == content(lesson)    # snapshot unchanged
    body = resumed(unit_test)
    assert [(a["result"], a["evaluation"]) for a in body["answers"]] == [("hidden", None)] * 2
    finish(curriculum_settings, unit_test["session_id"])
    body = resumed(unit_test)
    assert [(a["result"], a["evaluation"]) for a in body["answers"]] == [("correct", None), ("incorrect", None)]
    finish(curriculum_settings, pretest["session_id"])
    body = resumed(pretest)
    assert [(a["result"], a["evaluation"]) for a in body["answers"]] == [("hidden", None)] * 2


def test_sessions_belong_to_their_learner(learn_api: TestClient) -> None:
    owner, other = learner(learn_api), learner(learn_api)
    session = start(learn_api, owner, {"kind": "lesson", "lesson_id": "les_t1_0"})
    assert learn_api.get(f"/v1/sessions/{session['session_id']}", headers=other).status_code == 404
    assert learn_api.post(f"/v1/sessions/{session['session_id']}/abandon", headers=other).status_code == 404
    assert learn_api.get("/v1/sessions/ses_missing", headers=owner).status_code == 404


def test_abandon_is_idempotent_and_final(learn_api: TestClient, curriculum_settings: Settings) -> None:
    headers = learner(learn_api)
    session = start(learn_api, headers, {"kind": "lesson", "lesson_id": "les_t1_0"})
    for _ in range(2):
        assert learn_api.post(f"/v1/sessions/{session['session_id']}/abandon", headers=headers).status_code == 204
    assert learn_api.get(f"/v1/sessions/{session['session_id']}", headers=headers).json()["status"] == "abandoned"
    fresh = start(learn_api, headers, {"kind": "lesson", "lesson_id": "les_t1_0"})
    assert fresh["session_id"] != session["session_id"]
    finish(curriculum_settings, fresh["session_id"])
    response = learn_api.post(f"/v1/sessions/{fresh['session_id']}/abandon", headers=headers)
    assert response.status_code == 409 and response.json()["error"]["code"] == "session_finished"


def test_sessions_pin_their_exercise_versions(learn_api: TestClient, curriculum_settings: Settings) -> None:
    headers = learner(learn_api)
    session = start(learn_api, headers, {"kind": "lesson", "lesson_id": "les_t3_2"})
    row = query(curriculum_settings.database_url, "SELECT served_exercises, served_scenes, language, variant, "
                "lesson_version_id IS NOT NULL AS pinned FROM sessions WHERE id = $1", session["session_id"])[0]
    assert [e["exercise_id"] for e in json.loads(row["served_exercises"])] == \
        [e["exercise_id"] for e in exercises(session)]
    scenes = [b["visual"]["scene"] for b in session["items"] if b["type"] == "visual" and b["visual"]["scene"]]
    assert json.loads(row["served_scenes"]) == [{"scene_id": s["scene_id"], "version": s["version"]} for s in scenes]
    assert scenes
    assert (row["language"], row["variant"], row["pinned"]) == ("ar", "explorer", True)


# --- the lesson reader --------------------------------------------------------------------------------------------

def test_reader_is_the_session_without_exercises(learn_api: TestClient) -> None:
    headers = learner(learn_api, language="en")
    session = start(learn_api, headers, {"kind": "lesson", "lesson_id": "les_t2_0"})
    response = learn_api.get("/v1/lessons/les_t2_0", headers=headers)
    assert response.status_code == 200
    reader = response.json()
    C.LessonRead.model_validate(reader)
    assert reader["blocks"] == [b for b in session["items"] if b["type"] != "exercise"]
    assert (reader["objectives"], reader["completion"], reader["title"], reader["version"]) == \
        (session["objectives"], session["completion"], session["title"], session["lesson_version"])
    assert not any(b["type"] == "exercise" for b in reader["blocks"])
    arabic = learn_api.get("/v1/lessons/les_t2_0", headers={**headers, "Accept-Language": "ar"}).json()
    assert arabic["title"] != reader["title"]


async def test_concurrent_starts_create_one_session(learn_api: TestClient, curriculum_settings: Settings) -> None:
    headers = learner(learn_api)
    uid = user_id(learn_api, headers)
    resources = Resources.create(curriculum_settings)
    request = C.SessionCreate(kind="lesson", lesson_id="les_t1_0")

    async def attempt() -> tuple[C.Session, bool]:
        async with resources.sessionmaker() as db:
            user = await db.get(User, uid)
            assert user is not None
            await db.commit()  # as after authentication: the service owns its transaction
            return await sessions.create(db, curriculum_settings, user, request, "ar")

    try:
        results = await asyncio.gather(*(attempt() for _ in range(4)))
    finally:
        await resources.close()
    assert len({session.session_id for session, _ in results}) == 1
    assert sorted(created for _, created in results) == [False, False, False, True]
