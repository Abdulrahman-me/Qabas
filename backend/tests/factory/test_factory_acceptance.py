"""Factory definition of done (QUALITY §18.2 "Factory", Phase 15 / Milestone C), proven in CI with deterministic
fakes: three lessons for three curriculum slots — primary types concept, story and practice, the concept lesson
composing a teaching scenario — produced end to end through both gates (plan, Gate 1, the full pipeline with media,
Gate 2), localized to English, published as new versions, and playable in learner sessions; at least one visual is
a Visual Selector builtin and one a generated scene.

The live acceptance (real models and media providers, real curriculum concepts, released scene capabilities, on
staging) is gated on O-03, O-12, O-13 and O-02 and is not claimed here. The scene capability release below is a
test-only stand-in, exactly as in the media publication tests.
"""

from __future__ import annotations

import json
from collections.abc import Callable
from pathlib import Path
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import text

from app.config import Settings
from app.contract import models as C
from app.factory.gate2 import ScriptureAuthority, decide_gate2
from app.factory.runs import start_run
from app.llm.fake import FakeLLMClient
from app.media import scenes
from app.media.policy import style_inputs
from app.media.service import MediaService
from app.models import User
from app.runtime import Resources
from tests.factory import pipeline_support as P
from tests.factory.support import InlineDispatcher, drive, plan, reviewer
from tests.factory.test_pipeline import Harness
from tests.learning.conftest import learner, user_id
from tests.media.test_bindings import Normative, Tools, authored, policy
from tests.media.test_publication import Images

pytestmark = pytest.mark.integration
SLOTS = {  # slot: (primary type, introduced concept, prerequisites, scene-bearing)
    "les_t2_1": ("concept", "con_t2_1", ["con_t2_0"], False),
    "les_t2_2": ("story", "con_t2_2", [], True),
    "les_t2_3": ("practice", "con_t2_3", ["con_t2_1"], False),
}

TERMS = {"con_t2_1": "مصطلح أول", "con_t2_2": "مصطلح ثان", "con_t2_3": "مصطلح ثالث"}   # distinct after normalization


def retarget(answer: Callable[[dict[str, Any]], dict[str, Any]], concept: str) -> Callable[..., dict[str, Any]]:
    return lambda data: json.loads(json.dumps(answer(data), ensure_ascii=False).replace("con_t2_1", concept))


def plan_for(kind: str, concept: str, prerequisites: list[str]) -> dict[str, Any]:
    value = plan(lesson_type=kind, introduced_concept_ids=[concept], prerequisite_concept_ids=prerequisites,
                 new_terms=[{"ar": TERMS[concept], "en": f"Synthetic term {concept}"}])
    if kind == "story":
        value["lesson_arc"]["steps"][0]["technique"] = "story"
    return value


def selection_for(scene: bool) -> Callable[[dict[str, Any]], dict[str, Any]]:
    def select(data: dict[str, Any]) -> dict[str, Any]:
        value = P.visual_selection(data)
        for item in value["visuals"]:
            if item["brief_id"] == "b_hook":
                continue                                            # a registered builtin (Visual Selector)
            if scene and item["brief_id"].startswith("b_story."):
                item.update(kind="scene", key=None, group="story", params_json='{"beat": 0, "focus": -1}',
                            image_brief="Neutral synthetic geometry")
            else:
                item.update(kind="image", key=None, group="setting", params_json="{}",
                            image_brief="Neutral synthetic geometry")
        return value
    return select


async def produce(resources: Resources, tmp_path: Path, slot: str, path: Path,
                  terms: dict[str, Any]) -> tuple[str, str]:
    kind, concept, prerequisites, scene = SLOTS[slot]
    tools = Tools(translations=P.manifest(tmp_path))
    answers = {"factory_plan": plan_for(kind, concept, prerequisites),
               "factory_write": retarget(P.write, concept), "factory_exercises": retarget(P.exercises, concept),
               "factory_glossary": retarget(P.glossary, concept), "factory_visuals": selection_for(scene),
               "factory_scene_author": authored, "factory_image_prompt": {"prompt": "Neutral synthetic geometry"},
               "factory_visual_audit": {"passed": True, "issues": []}}
    configured = resources.settings
    h = Harness(resources, FakeLLMClient(P.script(**answers)), tools)
    h.orchestrator.settings = configured
    h.orchestrator.services = {"sources": lambda: tools, "media": MediaService(
        resources.storage, image_provider=Images(), image_terms=terms, style=style_inputs(path),
        previewer=Normative())}
    who = await reviewer(resources) if slot == "les_t2_1" else "usr_factory_reviewer"
    async with resources.sessionmaker() as db:
        user = await db.get(User, who)
    h.dispatcher = InlineDispatcher()
    h.orchestrator.dispatcher = h.dispatcher
    run_id = await start_run(resources.sessionmaker, configured, h.dispatcher, reviewer=user, lesson_id=slot,
                             lesson_type=kind, brief=f"Plan the {kind} lesson for this slot.")
    await h.approve_plan(run_id)
    outcomes = await drive(h.orchestrator, h.dispatcher, limit=60)
    run = await h.load(run_id)
    assert run.status == "awaiting_gate2", (slot, outcomes, run.error)
    try:
        result = await decide_gate2(
            resources.sessionmaker, configured, h.dispatcher, run_id=run_id, reviewer_id=who,
            body=C.Gate2(decision="approve", review_digest=run.review_digest or "", sentence_edits=[],
                         exercise_removals=[], reason=None),
            authority=ScriptureAuthority(mushaf=P.synthetic.mushaf(), translations=P.manifest(tmp_path)),
            storage=resources.storage)
    except Exception as exc:
        raise AssertionError((slot, getattr(exc, "details", exc))) from exc
    assert result["status"] == "published" and result["published"]["version"] == 2, result
    return run_id, kind


async def test_three_lessons_go_through_both_gates_and_are_playable(
        fresh_curriculum: tuple[TestClient, Settings], tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    client, settings = fresh_curriculum
    released = scenes.registry()
    for capability in released["capabilities"]:
        capability.update(status="released", release_evidence={"synthetic_test_only": True})
    monkeypatch.setattr(scenes, "registry", lambda: released)
    path, _, terms = policy(tmp_path, recitation=False)
    resources = Resources.create(settings.model_copy(update={
        "media_policy_path": path, "image_provider": "openai", "cdn_base_url": "https://cdn.qabas.app/media"}))
    try:
        produced = [await produce(resources, tmp_path, slot, path, terms) for slot in SLOTS]
        assert sorted(kind for _, kind in produced) == ["concept", "practice", "story"]
        async with resources.sessionmaker() as db:
            origins = {}
            for slot in SLOTS:
                version = (await db.execute(text(
                    "SELECT origin, content FROM lesson_versions WHERE lesson_id = :l AND version = 2"),
                    {"l": slot})).one()
                origins[slot] = version.origin
                blocks = version.content["variants"]["ar"]["explorer"]["blocks"]
                kinds = {b["visual"]["kind"] for b in blocks if isinstance(b.get("visual"), dict)}
                kinds |= {beat["visual"]["kind"] for b in blocks if b["type"] == "story" for beat in b["beats"]}
                assert "builtin" in kinds                            # the Visual Selector chose a builtin
                if SLOTS[slot][3]:
                    assert "scene" in kinds                          # and a generated scene was published
                assert set(version.content["variants"]) == {"ar", "en"}
            assert set(origins.values()) == {"factory"}
            runs = (await db.execute(text("SELECT count(*) FROM factory_runs WHERE status = 'published'"))).scalar()
            assert runs == 3
        # Playable: a learner with the prerequisites completed gets the published v2 of each lesson.
        headers = learner(client)
        uid = user_id(client, headers)
        async with resources.sessionmaker() as db, db.begin():
            for done in ("les_t2_0", "les_t2_1"):
                await db.execute(text("INSERT INTO learner_lessons (user_id, lesson_id, completed_at) "
                                      "VALUES (:u, :l, now())"), {"u": uid, "l": done})
        for slot in SLOTS:
            response = client.post("/v1/sessions", json={"kind": "lesson", "lesson_id": slot}, headers=headers)
            assert response.status_code in (200, 201), response.text
            session = response.json()
            assert session["lesson_version"] == 2 and session["items"]
            assert "answer_key" not in json.dumps(session)
    finally:
        await resources.close()
