"""Real transaction, finish replay, progression, review and profile acceptance tests."""

from __future__ import annotations

import asyncio
import importlib.util
from concurrent.futures import ThreadPoolExecutor
from datetime import UTC, datetime, timedelta
from typing import Any
from zoneinfo import ZoneInfo

import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.contract import TOOLS_DIR
from app.contract import models as C
from app.models import User
from app.runtime import Resources
from app.services.learning import finish as service
from tests.api.helpers import execute, query
from tests.learning.conftest import learner, revise, user_id
from tests.learning.test_answers import answer, body, exercises, keyed, start

pytestmark = pytest.mark.integration


def with_terms_and_practice(data: dict[str, Any]) -> None:
    for exercise in data["exercises"]:
        if exercise["purpose"] == "lesson" and exercise["exercise"]["ar"]["type"] != "flashcard":
            for lang in ("ar", "en"):
                exercise["exercise"][lang]["concept_ids"] = ["con_test", "con_t1_0"]
    spans = {"ar": [{"type": "text", "text": "تعريف اختباري"}],
             "en": [{"type": "text", "text": "Test definition"}]}
    data["glossary"].append({"term_id": "term_finish", "text": {"ar": "مصطلح", "en": "Term"},
                             "arabic": "مصطلح", "transliteration": "term", "definition": {
                                 "basic": spans, "intermediate": None}, "example": spans,
                             "concept_id": "con_t1_0", "lesson_id": "les_t1_0", "source_id": None,
                             "pronunciation_audio_url": None})
    for lang, variants in data["variants"].items():
        for variant in variants.values():
            variant["blocks"][0]["sentences"][0]["spans"] = [
                {"type": "term", "term_id": "term_finish", "text": "مصطلح" if lang == "ar" else "Term"}]


@pytest.fixture
def rich_api(learn_api: TestClient, curriculum_settings: Settings) -> tuple[TestClient, Settings]:
    if not query(curriculum_settings.database_url, "SELECT 1 FROM terms WHERE id='term_finish'"):
        revise(curriculum_settings, "les_t1_0", with_terms_and_practice)
    return learn_api, curriculum_settings


def filled(client: TestClient, headers: dict[str, str], session: dict[str, Any], *, correct: bool = True) -> None:
    for ex in exercises(session):
        if session["kind"] in ("pretest", "unit_test"):
            payload = keyed(ex, correct=correct)
        elif ex["type"] == "flashcard":
            payload = {"exercise_id": ex["exercise_id"], "answer": {"rating": "good"}, "elapsed_ms": 4000,
                       "is_retry": False}
        else:
            payload = body(ex, "correct" if correct else "incorrect")
        answer(client, headers, session, payload)


def finish(client: TestClient, headers: dict[str, str], session: dict[str, Any], duration: int = 0) -> dict[str, Any]:
    response = client.post(f"/v1/sessions/{session['session_id']}/finish", headers=headers,
                           json={"duration_ms": duration})
    assert response.status_code == 200, response.text
    C.SessionResult.model_validate(response.json())
    return dict(response.json())


def reasons(result: dict[str, Any]) -> dict[str, int]:
    return {g["reason"]: g["xp"] for g in result["xp"]["breakdown"]}


def test_finish_progress_review_replay_and_private_start(rich_api: tuple[TestClient, Settings]) -> None:
    learn_api, curriculum_settings = rich_api
    headers = learner(learn_api)
    uid = user_id(learn_api, headers)
    session = start(learn_api, headers, {"kind": "lesson", "lesson_id": "les_t1_0"})
    filled(learn_api, headers, session)
    # Another learning event since start must not replace the captured start mastery.
    execute(curriculum_settings.database_url, "UPDATE learner_concepts SET mastery = .9 WHERE user_id = $1", uid)
    result = finish(learn_api, headers, session)
    assert result["score"] == {"correct": 4, "total": 4, "percent": 100}
    assert reasons(result)["lesson_complete"] == 10 and reasons(result)["lesson_perfect"] == 3
    assert all(c["before"] == 0 and c["after"] == .9 for c in result["mastery_summary"])
    assert result["next_step"]["lesson_id"] == "les_t1_1"
    assert "les_t1_1" in [u["id"] for u in result["unlocked"]]
    assert result["streak"] == {"current": 1, "extended_today": True}
    row = query(curriculum_settings.database_url, "SELECT fsrs_card, first_practiced_at, due_at "
                "FROM learner_concepts WHERE user_id=$1 AND concept_id='con_test'", uid)[0]
    assert row["fsrs_card"] and row["first_practiced_at"] and row["due_at"]
    assert "learning_snapshot" not in learn_api.get(f"/v1/sessions/{session['session_id']}", headers=headers).json()
    for changed in ({"duration_ms": 999999999}, {"duration_ms": "bad"}, {}):
        response = learn_api.post(f"/v1/sessions/{session['session_id']}/finish", headers=headers, json=changed)
        assert response.json() == result
    assert learn_api.post(f"/v1/sessions/{session['session_id']}/finish", headers=headers,
                          content="{malformed").json() == result
    assert len(query(curriculum_settings.database_url, "SELECT * FROM outbox_events WHERE event_key=$1",
                     f"session:{session['session_id']}:finished")) == 1
    assert start(learn_api, headers, {"kind": "review", "mode": "cards"})["total_exercises"] > 0


def test_finish_completeness_ownership_abandon_and_duration(learn_api: TestClient,
                                                          curriculum_settings: Settings) -> None:
    headers, other = learner(learn_api), learner(learn_api)
    session = start(learn_api, headers, {"kind": "lesson", "lesson_id": "les_t1_0"})
    url = f"/v1/sessions/{session['session_id']}/finish"
    assert learn_api.post(url, headers=other, json={}).status_code == 404
    response = learn_api.post(url, headers=headers, json={"duration_ms": 0})
    assert response.status_code == 409
    assert response.json()["error"]["details"]["missing_exercise_ids"] == [e["exercise_id"] for e in exercises(session)]
    filled(learn_api, headers, session)
    assert learn_api.post(url, headers=headers, json={"duration_ms": "bad"}).status_code == 400
    assert finish(learn_api, headers, session, -200)["duration_ms"] == 0
    again = start(learn_api, headers, {"kind": "lesson", "lesson_id": "les_t1_0"})
    filled(learn_api, headers, again)
    result = finish(learn_api, headers, again, 999999999)
    assert 0 <= result["duration_ms"] < 60000
    third = start(learn_api, headers, {"kind": "lesson", "lesson_id": "les_t1_0"})
    learn_api.post(f"/v1/sessions/{third['session_id']}/abandon", headers=headers)
    assert learn_api.post(f"/v1/sessions/{third['session_id']}/finish", headers=headers, json={}).status_code == 409
    assert len(query(curriculum_settings.database_url, "SELECT * FROM learner_lessons")) == 1


def test_repeated_lesson_rewards_and_first_perfect_bonus(learn_api: TestClient) -> None:
    headers = learner(learn_api)
    results = []
    for correct in (False, True, True):
        session = start(learn_api, headers, {"kind": "lesson", "lesson_id": "les_t1_0"})
        filled(learn_api, headers, session, correct=correct)
        results.append(finish(learn_api, headers, session))
    assert reasons(results[0]).get("lesson_complete") == 10
    assert "lesson_perfect" not in reasons(results[0])
    assert "lesson_complete" not in reasons(results[1]) and reasons(results[1])["lesson_perfect"] == 3
    assert "lesson_complete" not in reasons(results[2]) and "lesson_perfect" not in reasons(results[2])


def test_pretest_first_result_and_no_fsrs_or_history_leak(learn_api: TestClient,
                                                       curriculum_settings: Settings) -> None:
    headers = learner(learn_api)
    uid = user_id(learn_api, headers)
    results = []
    for correct in (False, True):
        session = start(learn_api, headers, {"kind": "pretest", "unit_id": "unit_test_1"})
        filled(learn_api, headers, session, correct=correct)
        results.append(finish(learn_api, headers, session))
        resumed = learn_api.get(f"/v1/sessions/{session['session_id']}", headers=headers).json()
        assert all(a["result"] == "hidden" and a["evaluation"] is None for a in resumed["answers"])
        assert results[-1]["review_items"] is None and results[-1]["passed"] is None
    assert reasons(results[0])["pretest_complete"] == 5 and "pretest_complete" not in reasons(results[1])
    fact = query(curriculum_settings.database_url, "SELECT * FROM learner_units WHERE user_id=$1", uid)[0]
    assert fact["pretest_percent"] == 0
    assert not query(curriculum_settings.database_url, "SELECT 1 FROM learner_concepts "
                     "WHERE user_id=$1 AND first_practiced_at IS NOT NULL", uid)


def test_unit_skip_retake_post_and_end_history(learn_api: TestClient, curriculum_settings: Settings) -> None:
    headers = learner(learn_api)
    uid = user_id(learn_api, headers)
    session = start(learn_api, headers, {"kind": "unit_test", "unit_id": "unit_test_1"})
    filled(learn_api, headers, session)
    result = finish(learn_api, headers, session)
    assert result["passed"] and reasons(result)["unit_test_passed"] == 20
    assert len(result["review_items"]) == len(exercises(session))
    resumed = learn_api.get(f"/v1/sessions/{session['session_id']}", headers=headers).json()
    assert all(a["result"] == "correct" and a["evaluation"] is not None for a in resumed["answers"])
    # Submit replay remains recorded-only after finish (D-64).
    assert set(answer(learn_api, headers, session, keyed(exercises(session)[0], correct=False))) == \
        {"exercise_id", "recorded"}
    fact = query(curriculum_settings.database_url, "SELECT * FROM learner_units WHERE user_id=$1", uid)[0]
    assert fact["skipped_at"] and fact["first_post_percent"] is None
    assert learn_api.get("/v1/journey", headers=headers).json()["units"][0]["state"] == "skipped"
    execute(curriculum_settings.database_url, "INSERT INTO learner_lessons(user_id,lesson_id,completed_at) "
            "SELECT $1,id,now() FROM lessons WHERE unit_id='unit_test_1' ON CONFLICT DO NOTHING", uid)
    again = start(learn_api, headers, {"kind": "unit_test", "unit_id": "unit_test_1"})
    filled(learn_api, headers, again, correct=False)
    assert not finish(learn_api, headers, again)["passed"]
    fact = query(curriculum_settings.database_url, "SELECT * FROM learner_units WHERE user_id=$1", uid)[0]
    assert fact["unit_test_best_percent"] == 100 and fact["first_post_percent"] == 0 and fact["completed_at"]


def test_review_reward_requires_due_work_and_is_shared_daily_cap(rich_api: tuple[TestClient, Settings]) -> None:
    learn_api, curriculum_settings = rich_api
    headers = learner(learn_api)
    uid = user_id(learn_api, headers)
    lesson = start(learn_api, headers, {"kind": "lesson", "lesson_id": "les_t1_0"})
    filled(learn_api, headers, lesson)
    finish(learn_api, headers, lesson)
    for due, reward in ((False, False), (True, True), (True, False)):
        if due:
            execute(curriculum_settings.database_url, "UPDATE learner_concepts SET due_at=now()-interval '1 day' "
                    "WHERE user_id=$1", uid)
        session = start(learn_api, headers, {"kind": "review", "mode": "cards"})
        filled(learn_api, headers, session)
        assert ("review_complete" in reasons(finish(learn_api, headers, session))) is reward
    execute(curriculum_settings.database_url, "UPDATE learner_concepts SET due_at=now()-interval '1 day' "
            "WHERE user_id=$1", uid)
    quick = start(learn_api, headers, {"kind": "review", "mode": "quick"})
    filled(learn_api, headers, quick)
    assert "review_complete" not in reasons(finish(learn_api, headers, quick))


def test_daily_duration_precision_cap_goal_stats_activity(learn_api: TestClient,
                                                        curriculum_settings: Settings,
                                                        monkeypatch: pytest.MonkeyPatch) -> None:
    headers = learner(learn_api)
    uid = user_id(learn_api, headers)
    learn_api.patch("/v1/me", headers=headers, json={"daily_goal_minutes": 5})
    for duration in (30000, 30000, 30 * 60000):
        session = start(learn_api, headers, {"kind": "lesson", "lesson_id": "les_t1_0"})
        filled(learn_api, headers, session)
        monkeypatch.setattr(service, "utcnow", lambda: datetime.now(UTC) + timedelta(minutes=40))
        result = finish(learn_api, headers, session, duration)
    assert result["daily_goal"]["minutes_today"] == 21
    stats = learn_api.get("/v1/me/stats", headers=headers)
    assert stats.status_code == 200, stats.text
    C.Stats.model_validate(stats.json())
    assert stats.json()["daily_goal"]["met"] and stats.json()["lessons_completed"] == 1
    assert stats.json()["units_completed"] == 0
    assert len(query(curriculum_settings.database_url, "SELECT 1 FROM xp_events "
                     "WHERE user_id=$1 AND reason='daily_goal_met'", uid)) == 1
    activity = learn_api.get("/v1/me/activity", headers=headers)
    assert activity.status_code == 200 and activity.json()["days"][0]["minutes"] == 21
    assert learn_api.get("/v1/me/activity?from=2026-01-01&to=2026-05-01", headers=headers).status_code == 400


def test_finish_concurrent_and_rollback(learn_api: TestClient, curriculum_settings: Settings,
                                      monkeypatch: pytest.MonkeyPatch) -> None:
    headers = learner(learn_api)
    uid = user_id(learn_api, headers)
    session = start(learn_api, headers, {"kind": "lesson", "lesson_id": "les_t1_0"})
    filled(learn_api, headers, session)

    async def crash(*args: Any, **kwargs: Any) -> None:
        raise RuntimeError("simulated crash before commit")

    original = service.enqueue
    monkeypatch.setattr(service, "enqueue", crash)
    response = learn_api.post(f"/v1/sessions/{session['session_id']}/finish", headers=headers, json={"duration_ms": 0})
    assert response.status_code == 500
    assert query(curriculum_settings.database_url, "SELECT status FROM sessions WHERE id=$1",
                 session["session_id"])[0]["status"] == "active"
    assert not query(curriculum_settings.database_url, "SELECT 1 FROM learner_lessons WHERE user_id=$1", uid)
    assert not query(curriculum_settings.database_url, "SELECT 1 FROM xp_events WHERE user_id=$1", uid)
    monkeypatch.setattr(service, "enqueue", original)

    async def run() -> list[dict[str, Any]]:
        resources = Resources.create(curriculum_settings)
        try:
            async def one() -> dict[str, Any]:
                async with resources.sessionmaker() as db:
                    user = await db.get(User, uid)
                    if user is not None:
                        db.expunge(user)
                    await db.rollback()
                    assert user is not None
                    return await service.finish(db, user, session["session_id"], {"duration_ms": 0})
            return await asyncio.gather(*(one() for _ in range(4)))
        finally:
            await resources.close()

    results = asyncio.run(run())
    assert all(r == results[0] for r in results)
    assert len(query(curriculum_settings.database_url, "SELECT 1 FROM learner_lessons WHERE user_id=$1", uid)) == 1


def test_glossary_open_exposure_mastery_and_pages(rich_api: tuple[TestClient, Settings]) -> None:
    learn_api, curriculum_settings = rich_api
    headers = learner(learn_api, language="en")
    uid = user_id(learn_api, headers)
    term = query(curriculum_settings.database_url, "SELECT id FROM terms ORDER BY id LIMIT 1")[0]["id"]
    assert learn_api.get("/v1/glossary", headers=headers).json()["items"] == []
    assert learn_api.get(f"/v1/glossary/{term}", headers=headers).status_code == 200
    with ThreadPoolExecutor(max_workers=2) as pool:
        responses = list(pool.map(lambda _: learn_api.post(f"/v1/glossary/{term}/opened", headers=headers), range(2)))
    assert all(r.status_code == 204 for r in responses)
    row = query(curriculum_settings.database_url, "SELECT * FROM learner_terms WHERE user_id=$1", uid)[0]
    assert row["opened_count"] == 2 and row["exposures"] == 0 and row["state"] == "learning"
    assert len(learn_api.get("/v1/glossary?state=learning", headers=headers).json()["items"]) == 1
    assert learn_api.get("/v1/glossary?state=new", headers=headers).json()["items"] == []
    assert learn_api.get("/v1/glossary?limit=0", headers=headers).status_code == 400
    assert learn_api.get("/v1/glossary/term_missing", headers=headers).status_code == 404
    session = start(learn_api, headers, {"kind": "lesson", "lesson_id": "les_t1_0"})
    filled(learn_api, headers, session)
    assert finish(learn_api, headers, session)["terms_mastered"] == []
    session = start(learn_api, headers, {"kind": "lesson", "lesson_id": "les_t1_0"})
    filled(learn_api, headers, session)
    assert finish(learn_api, headers, session)["terms_mastered"] == [{"term_id": term, "text": "Term"}]
    row = query(curriculum_settings.database_url, "SELECT * FROM learner_terms WHERE user_id=$1", uid)[0]
    assert row["exposures"] == 2 and row["state"] == "mastered"
    execute(curriculum_settings.database_url, "UPDATE learner_concepts SET mastery=.8 WHERE user_id=$1", uid)
    stats = learn_api.get("/v1/me/stats", headers=headers).json()
    assert stats["concepts"] == {"mastered": 2, "learning": 0}
    response = learn_api.get("/v1/me/concepts?limit=1", headers=headers)
    assert response.status_code == 200 and len(response.json()["items"]) == 1


def test_recovery_uses_stored_history(learn_api: TestClient) -> None:
    spec = importlib.util.spec_from_file_location("recovery_reference", TOOLS_DIR / "recovery.py")
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    headers = learner(learn_api)
    session = start(learn_api, headers, {"kind": "lesson", "lesson_id": "les_t1_0"})
    first = exercises(session)[0]
    answer(learn_api, headers, session, body(first, "incorrect"))
    resumed = learn_api.get(f"/v1/sessions/{session['session_id']}", headers=headers).json()
    recovered = module.resume_point(resumed["items"], resumed["answers"])
    assert recovered["stage"] == "steps" and recovered["retry_queue"] == [first["exercise_id"]]
    answer(learn_api, headers, session, body(exercises(session)[1], "correct"))
    for ex in exercises(session)[2:]:
        answer(learn_api, headers, session, body(ex, "correct"))
    answer(learn_api, headers, session, body(first, "correct", retry=True))
    result = finish(learn_api, headers, session)
    assert result["score"]["percent"] == 75 and "lesson_perfect" not in reasons(result)
    resumed = learn_api.get(f"/v1/sessions/{session['session_id']}", headers=headers).json()
    assert module.resume_point(resumed["items"], resumed["answers"])["retry_queue"] == []


@pytest.mark.parametrize(("track", "language"), [("explorer", "ar"), ("new_muslim", "en")])
def test_curriculum_finishes_through_the_real_planner(learn_api: TestClient, track: str, language: str) -> None:
    headers = learner(learn_api, track=track, language=language)
    seen = set()
    for _ in range(25):
        step = learn_api.get("/v1/journey/next", headers=headers).json()
        if step["type"] == "journey_complete":
            break
        request = {"kind": step["type"]}
        request["lesson_id" if step["type"] == "lesson" else "unit_id"] = \
            step["lesson_id" if step["type"] == "lesson" else "unit_id"]
        session = start(learn_api, headers, request)
        filled(learn_api, headers, session)
        result = finish(learn_api, headers, session)
        seen.add(session["kind"])
        if session["kind"] == "unit_test":
            assert result["passed"]
    else:
        raise AssertionError("planner did not complete the curriculum")
    assert seen == {"lesson", "pretest", "unit_test"}
    journey = learn_api.get("/v1/journey", headers=headers).json()
    assert all(u["state"] == "completed" for u in journey["units"] if not u["coming_soon"])


def test_quest_rewards_are_atomic_and_repeat_activity_cannot_farm(learn_api: TestClient,
                                                               curriculum_settings: Settings) -> None:
    headers = learner(learn_api)
    uid = user_id(learn_api, headers)
    day = datetime.now(UTC).astimezone(ZoneInfo("Asia/Riyadh")).date()
    for slot, kind, goal, reward in ((1, "complete_lessons", 1, 10), (2, "perfect_lesson", 1, 15),
                                     (3, "earn_xp", 13, 10)):
        execute(curriculum_settings.database_url, "INSERT INTO quests(user_id,local_date,slot,kind,goal,reward_xp) "
                "VALUES($1,$2,$3,$4,$5,$6)", uid, day, slot, kind, goal, reward)
    session = start(learn_api, headers, {"kind": "lesson", "lesson_id": "les_t1_0"})
    filled(learn_api, headers, session)
    result = finish(learn_api, headers, session)
    assert result["xp"]["total"] == 48
    assert sum(g["xp"] for g in result["xp"]["breakdown"] if g["reason"] == "quest_complete") == 35
    quests = learn_api.get("/v1/me/quests", headers=headers)
    assert quests.status_code == 200 and all(q["completed"] for q in quests.json()["items"])
    again = start(learn_api, headers, {"kind": "lesson", "lesson_id": "les_t1_0"})
    filled(learn_api, headers, again)
    assert finish(learn_api, headers, again)["xp"]["total"] == 0
    assert learn_api.get("/v1/me/stats", headers=headers).json()["xp_total"] == 48


def test_answer_and_finish_race_preserves_completeness(learn_api: TestClient) -> None:
    headers = learner(learn_api)
    session = start(learn_api, headers, {"kind": "lesson", "lesson_id": "les_t1_0"})
    for ex in exercises(session)[:-1]:
        answer(learn_api, headers, session, body(ex, "correct"))
    with ThreadPoolExecutor(max_workers=2) as pool:
        last = pool.submit(answer, learn_api, headers, session, body(exercises(session)[-1], "correct"))
        ending = pool.submit(learn_api.post, f"/v1/sessions/{session['session_id']}/finish", headers=headers,
                             json={"duration_ms": 0})
        assert last.result()["recorded"]
        response = ending.result()
        assert response.status_code in (200, 409)
    assert finish(learn_api, headers, session)["score"]["percent"] == 100


def test_finish_outbox_redelivery_does_not_repeat_reported_effects(learn_api: TestClient,
                                                                 curriculum_settings: Settings,
                                                                 monkeypatch: pytest.MonkeyPatch) -> None:
    from app.services.platform import outbox

    headers = learner(learn_api)
    session = start(learn_api, headers, {"kind": "lesson", "lesson_id": "les_t1_0"})
    filled(learn_api, headers, session)
    result = finish(learn_api, headers, session)
    applied = []

    async def consume(db: Any, event: Any) -> None:
        if await outbox.apply_effect(db, effect_key=f"metrics:{event.event_key}", event_key=event.event_key):
            applied.append(event.event_key)

    monkeypatch.setitem(outbox.CONSUMERS, "session.finished", consume)

    async def relay() -> None:
        resources = Resources.create(curriculum_settings)
        try:
            assert await outbox.relay_one(resources.sessionmaker)
        finally:
            await resources.close()

    asyncio.run(relay())
    execute(curriculum_settings.database_url, "UPDATE outbox_events SET processed_at=NULL WHERE event_key=$1",
            f"session:{session['session_id']}:finished")
    asyncio.run(relay())
    assert applied == [f"session:{session['session_id']}:finished"]
    assert finish(learn_api, headers, session) == result
    assert len(query(curriculum_settings.database_url, "SELECT * FROM learner_lessons")) == 1


def test_unit_test_threshold_is_pinned_at_start(learn_api: TestClient, curriculum_settings: Settings) -> None:
    headers = learner(learn_api)
    session = start(learn_api, headers, {"kind": "unit_test", "unit_id": "unit_test_1"})
    for index, ex in enumerate(exercises(session)):
        answer(learn_api, headers, session, keyed(ex, correct=index < 10))
    execute(curriculum_settings.database_url, "UPDATE units SET pass_percent=100 WHERE id='unit_test_1'")
    try:
        assert finish(learn_api, headers, session)["passed"] is True  # 10/12 passes the captured 80.
    finally:
        execute(curriculum_settings.database_url, "UPDATE units SET pass_percent=80 WHERE id='unit_test_1'")


def test_overlapping_review_modes_reward_only_once(rich_api: tuple[TestClient, Settings]) -> None:
    client, settings = rich_api
    headers = learner(client)
    uid = user_id(client, headers)
    lesson = start(client, headers, {"kind": "lesson", "lesson_id": "les_t1_0"})
    filled(client, headers, lesson)
    finish(client, headers, lesson)
    execute(settings.database_url, "UPDATE learner_concepts SET due_at=now()-interval '1 day' WHERE user_id=$1", uid)
    decks = [start(client, headers, {"kind": "review", "mode": mode}) for mode in ("cards", "quick")]
    for deck in decks:
        filled(client, headers, deck)
    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(lambda deck: finish(client, headers, deck), decks))
    assert sum("review_complete" in reasons(r) for r in results) == 1


def test_long_lived_session_duration_does_not_overflow(learn_api: TestClient,
                                                     monkeypatch: pytest.MonkeyPatch) -> None:
    headers = learner(learn_api)
    session = start(learn_api, headers, {"kind": "lesson", "lesson_id": "les_t1_0"})
    filled(learn_api, headers, session)
    monkeypatch.setattr(service, "utcnow", lambda: datetime.now(UTC) + timedelta(days=40))
    result = finish(learn_api, headers, session, 3_000_000_000)
    assert result["duration_ms"] == 3_000_000_000 and result["daily_goal"]["minutes_today"] == 20
