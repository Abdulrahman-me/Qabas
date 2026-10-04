"""Tests that change published content: version pinning (serve side), pools after a revision, unit guides.

QUALITY §18.1 ``test_version_pinning`` (serve side: grading against the served version arrives in Phase 6).
"""

from __future__ import annotations

import asyncio
import json
from collections.abc import Callable
from typing import Any

import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.content.package import LessonPackage
from app.content.store import FixtureApproval, import_package, publish
from app.content.test_curriculum import build_packages
from app.contract import models as C
from app.runtime import Resources
from tests.api.helpers import execute, query
from tests.learning.conftest import learner, user_id

pytestmark = pytest.mark.integration


def revise(settings: Settings, lesson_id: str, change: Callable[[dict[str, Any]], None]) -> None:
    """Import and publish a new version of ``lesson_id`` through the real pipeline."""
    original = next(p for p in build_packages() if p.lesson_id == lesson_id)
    data = original.model_dump(mode="json")
    change(data)
    package = LessonPackage.model_validate(data)

    async def main() -> None:
        resources = Resources.create(settings)
        try:
            async with resources.sessionmaker() as db, db.begin():
                result = await import_package(db, package, origin="test_fixture", allow_placeholder_media=True)
                await publish(db, settings, result.lesson_version_id, FixtureApproval())
        finally:
            await resources.close()

    asyncio.run(main())


def served(settings: Settings, session_id: str) -> dict[str, int]:
    row = query(settings.database_url, "SELECT served_exercises FROM sessions WHERE id = $1", session_id)[0]
    return {e["exercise_id"]: e["version"] for e in json.loads(row["served_exercises"])}


def test_an_active_session_keeps_its_versions(fresh_curriculum: tuple[TestClient, Settings]) -> None:
    client, settings = fresh_curriculum
    early = learner(client)
    before = client.post("/v1/sessions", json={"kind": "lesson", "lesson_id": "les_t1_0"}, headers=early).json()
    mcq = next(b["exercise"] for b in before["items"] if b["type"] == "exercise"
               and b["exercise"]["type"] == "multiple_choice")

    def change(data: dict[str, Any]) -> None:
        for by in data["variants"].values():
            for variant in by.values():
                variant["title"] += " (revised)"
        record = next(e for e in data["exercises"] if e["exercise_id"] == mcq["exercise_id"])
        options = [o["option_id"] for o in record["exercise"]["ar"]["payload"]["options"]]
        for lang in ("ar", "en"):
            key = record["exercise"][lang]["answer_key"]["option_id"]
            record["exercise"][lang]["answer_key"] = {"option_id": next(o for o in options if o != key)}
            record["feedback"][lang]["explanation"] = [{"type": "text", "text": "Revised explanation."}]

    revise(settings, "les_t1_0", change)

    resumed = client.get(f"/v1/sessions/{before['session_id']}", headers=early).json()
    assert resumed == before                                              # nothing changed underneath
    assert served(settings, before["session_id"])[mcq["exercise_id"]] == 1
    again = client.post("/v1/sessions", json={"kind": "lesson", "lesson_id": "les_t1_0"}, headers=early)
    assert again.status_code == 200 and again.json() == before            # the active session wins

    late = learner(client)
    after = client.post("/v1/sessions", json={"kind": "lesson", "lesson_id": "les_t1_0"}, headers=late).json()
    assert after["lesson_version"] == 2 and after["title"].endswith("(revised)")
    assert served(settings, after["session_id"])[mcq["exercise_id"]] == 2
    reader = client.get("/v1/lessons/les_t1_0", headers=late).json()
    assert reader["version"] == 2


def test_pools_follow_the_current_lesson_versions(fresh_curriculum: tuple[TestClient, Settings]) -> None:
    client, settings = fresh_curriculum
    package = next(p for p in build_packages() if p.lesson_id == "les_t2_0")
    old_id = next(e.exercise_id for e in package.exercises if e.purpose == "pretest")

    def swap(data: dict[str, Any]) -> None:
        record = next(e for e in data["exercises"] if e["exercise_id"] == old_id)
        record["exercise_id"] = "ex_t2_0_pre_new"
        for lang in ("ar", "en"):
            record["exercise"][lang]["exercise_id"] = "ex_t2_0_pre_new"

    revise(settings, "les_t2_0", swap)
    headers = learner(client)
    session = client.post("/v1/sessions", json={"kind": "pretest", "unit_id": "unit_test_2"}, headers=headers).json()
    ids = {b["exercise"]["exercise_id"] for b in session["items"]}
    assert len(ids) == 8 and "ex_t2_0_pre_new" in ids and old_id not in ids
    unit = query(settings.database_url, "SELECT coming_soon FROM units WHERE id = 'unit_test_2'")[0]
    assert unit["coming_soon"] is False


def _guide(source_id: str) -> dict[str, Any]:
    def section(lang: str, track: str) -> dict[str, Any]:
        return {"title": f"{lang}-{track} guide", "sections": [{"title": "What you will learn", "sentences": [
            {"sentence_id": "sen_g1", "source_ids": [source_id], "spans": [
                {"type": "text", "text": "A word: "}, {"type": "term", "text": "salah", "term_id": "term_guide"}]}]}]}
    return {lang: {track: section(lang, track) for track in ("explorer", "new_muslim")} for lang in ("ar", "en")}


def test_unit_guides(fresh_curriculum: tuple[TestClient, Settings]) -> None:
    client, settings = fresh_curriculum
    url = settings.database_url
    source_id = query(url, "SELECT id FROM sources ORDER BY id LIMIT 1")[0]["id"]
    spans = json.dumps({"ar": [{"type": "text", "text": "تعريف"}], "en": [{"type": "text", "text": "Definition"}]})
    execute(url, "INSERT INTO terms (id, text, arabic, transliteration, definition, example) VALUES ('term_guide', "
                 "'{\"ar\": \"الصلاة\", \"en\": \"Prayer\"}'::jsonb, 'الصلاة', 'salah', "
                 "jsonb_build_object('basic', $1::jsonb, 'intermediate', null), $1::jsonb)", spans)
    execute(url, "UPDATE units SET guide = $1::jsonb WHERE id = 'unit_test_2'", json.dumps(_guide(source_id)))

    headers = learner(client, track="new_muslim", language="en")
    units = {u["unit_id"]: u for u in client.get("/v1/journey", headers=headers).json()["units"]}
    assert units["unit_test_2"]["has_guide"] is True and units["unit_test_3"]["has_guide"] is False
    response = client.get("/v1/units/unit_test_2/guide", headers=headers)
    assert response.status_code == 200
    guide = C.Guide.model_validate(response.json()).model_dump(mode="json")
    assert guide["title"] == "en-new_muslim guide"
    assert [s["source_id"] for s in guide["sources"]] == [source_id]
    assert all(not s["displayed"] and s["display_role"] is None for s in guide["sources"])
    card = guide["terms"]["term_guide"]
    assert (card["text"], card["arabic"], card["state"], card["level"]) == ("Prayer", "الصلاة", "new", "basic")

    uid = user_id(client, headers)
    execute(url, "INSERT INTO learner_terms (user_id, term_id, state) VALUES ($1, 'term_guide', 'learning')", uid)
    execute(url, "INSERT INTO learner_units (user_id, unit_id, unit_test_passed_at) VALUES ($1, 'unit_test_3', now())",
            uid)
    card = client.get("/v1/units/unit_test_2/guide", headers=headers).json()["terms"]["term_guide"]
    assert (card["state"], card["level"]) == ("learning", "intermediate")
    assert card["definition"] == [{"type": "text", "text": "Definition"}]        # intermediate falls back to basic
    arabic = client.get("/v1/units/unit_test_2/guide", headers={**headers, "Accept-Language": "ar"}).json()
    assert arabic["title"] == "ar-new_muslim guide"
    assert client.get("/v1/units/unit_test_3/guide", headers=headers).status_code == 404
    assert client.get("/v1/units/unit_test_1/guide", headers=headers).status_code == 404   # outside the track


def test_a_coming_soon_unit_is_passed_over(fresh_curriculum: tuple[TestClient, Settings]) -> None:
    # D-44: the current unit is the first one that is neither finished nor coming soon; units never wait.
    client, settings = fresh_curriculum
    execute(settings.database_url, "UPDATE units SET coming_soon = true WHERE id = 'unit_test_1'")
    headers = learner(client)
    step = client.get("/v1/journey/next", headers=headers).json()
    assert (step["type"], step["unit_id"]) == ("pretest", "unit_test_2")
    body = client.get("/v1/journey", headers=headers).json()
    assert body["current"] == {"unit_id": "unit_test_2", "lesson_id": "les_t2_0"}
    assert body["units"][0]["lessons"] == [] and body["units"][0]["state"] == "locked"
