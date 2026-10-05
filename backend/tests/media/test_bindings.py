"""F-108 exercise bindings and Qur'an reference audio (Phase 14): timeline events dated by supported historical
claims, map hotspots anchored in a generated scene, licensed recitation segments, and whole-ayah reference audio
on displayed Qur'an evidence, all the way through Gate 2 publication.

Everything here is synthetic: the "mushaf" is neutral test text, the "recording" a silent MP3, the policy a
fixture-only approval (dev/test), and the normative renderer a test double that is never selected by application
code. No scripture, art or licence is approved by these tests.
"""

from __future__ import annotations

import copy
import json
from dataclasses import dataclass, replace
from pathlib import Path
from typing import Any

import pytest
import yaml

from app.config import BACKEND_DIR, Settings
from app.content.package import LessonPackage
from app.content.projection import display_roles, resolve_items
from app.contract import FIXTURES_DIR
from app.contract import models as C
from app.factory.gate2 import ScriptureAuthority, decide_gate2
from app.llm.fake import FakeLLMClient
from app.media.policy import style_inputs
from app.media.preview import InspectionPreviewer
from app.media.service import MediaService
from app.runtime import Resources
from app.services.platform.storage import sha256_hex
from app.sources.records import SourceRecord
from tests.factory import pipeline_support as P
from tests.factory.test_pipeline import Harness
from tests.media.test_core import audio
from tests.media.test_publication import Images
from tests.sources.test_scripture import audio as capability_audio

pytestmark = pytest.mark.integration
APPROVAL = {"status": "approved", "approved_by": "synthetic test only", "approved_on": "2026-01-01"}
TARGETS = [{"target_id": "palm", "label": "النخلة"}, {"target_id": "well", "label": "البئر"},
           {"target_id": "tent", "label": "الخيمة"}]


class Tools(P.SyntheticTools):
    async def quran_audio(self, surah: int, ayah: int, reciter_id: int) -> SourceRecord:
        self._enter("quran_audio")
        source = capability_audio()
        return replace(source, data={**source.data, "reciter_id": reciter_id})


@dataclass
class Recordings:
    reciter_id: int = 7
    reads: int = 0

    def recording(self, surah: int, ayah: int) -> tuple[bytes, str]:
        self.reads += 1
        data = audio()
        return data, sha256_hex(data)


class Normative(InspectionPreviewer):
    async def render(self, *args: Any, **kwargs: Any) -> Any:
        inspected = await super().render(*args, **kwargs)
        # Explicit test-only release evidence; never selected by application code or committed policy.
        return replace(inspected, normative=True, renderer_version="qabas_scene synthetic/1",
                       timing={"build_raster_p95_ms": 1, "first_frame_ms": 10, "device": "synthetic fixture"},
                       evidence={"anchor_visibility_passed": True, "fallback_equality_passed": True})


def policy(tmp_path: Path, *, recitation: bool) -> tuple[Path, dict[str, Any], dict[str, Any]]:
    style = {**APPROVAL, "references": []}
    for name, file in (("guide", "style.md"), ("characters", "characters.md")):
        relative = f"tests/media/fixtures/{file}"
        style[name] = {"path": relative, "sha256": sha256_hex((BACKEND_DIR / relative).read_bytes())}
    terms = {**APPROVAL, "licence": APPROVAL, "model": "synthetic-image", "size": "1536x1024"}
    examples = [{"path": str((FIXTURES_DIR / "scenes" / n).relative_to(BACKEND_DIR)),
                 "sha256": sha256_hex((FIXTURES_DIR / "scenes" / n).read_bytes())}
                for n in ("asset_positive.scene.json", "scn_test_desert_well.v2.scene.json")]
    document: dict[str, Any] = {
        "schema": "qabas.media_policy/1", "fixture_only": True, "style": style,
        "providers": {"image": {"openai": terms}},
        "scene_author": {**APPROVAL, "design_tokens": style["guide"], "examples": examples},
        "renderer": {**APPROVAL, "renderer_version": "qabas_scene synthetic/1"},
        "recitation": {**APPROVAL, "licence": APPROVAL, "provider": "quran_com", "reciter": "Synthetic reciter",
                       "reciter_id": 7} if recitation else {"status": "pending", "approved_by": None,
                                                            "approved_on": None, "licence": {"status": "pending"}}}
    path = tmp_path / "media-policy.yaml"
    path.write_text(yaml.safe_dump(document), encoding="utf-8")
    return path, style, terms


def decompose(data: dict[str, Any]) -> dict[str, Any]:
    value = P.decompose(data)
    value["claims"][0]["kind"] = "historical"
    return value


def write(data: dict[str, Any]) -> dict[str, Any]:
    draft = P.write(data)
    for variant in draft["variants"]:
        variant["blocks"].insert(-1, {"block_id": "b_rx", "type": "exercise_slot", "intent": "recite the verse",
                                      "activity": "recitation"})
    draft["arc_map"][3]["block_ids"].append("b_rx")
    return draft


def exercises(data: dict[str, Any], *, event_claim: str = "c1") -> dict[str, Any]:
    value = P.exercises(data)
    quran = next(e["evidence_id"] for e in data["evidence"] if e["kind"] == "quran")
    slots = {s["activity"]: s["slot_block_id"] for s in data["slots"]}
    items = {x["exercise_id"]: x for x in value["exercises"]}
    items["x2"] = P.item("x2", "lesson", "map_place", slot_block_id=items["x2"]["slot_block_id"], layer="apply",
                         prompt="أين البئر؟", map_brief="مخيم في الصحراء فيه بئر ونخلة وخيمة",
                         targets=TARGETS, correct_option_id="well")
    items["x6"] = P.item("x6", "pretest", "timeline_order", events=[
        {"event_id": f"o_e{n}", "text": f"حدث {n}", "date_label": f"سنة {n}", "claim_id": event_claim}
        for n in range(1, 4)])
    items["x13"] = P.item("x13", "lesson", "recite_verse", slot_block_id=slots["recitation"], layer=None,
                          verse_evidence_id=quran, word_start=2, word_end=4)
    value["exercises"] = list(items.values())
    return value


def selection(data: dict[str, Any]) -> dict[str, Any]:
    value = P.visual_selection(data)
    for item in value["visuals"]:
        anchored = any(b["brief_id"] == item["brief_id"] and b["anchors"] for b in data["briefs"])
        item.update(kind="scene" if anchored else "image", key=None, image_brief="Neutral synthetic geometry",
                    group="map" if anchored else "setting",
                    params_json='{"beat": 0, "focus": -1}' if anchored else "{}")
    return value


def authored(data: dict[str, Any]) -> dict[str, Any]:
    manifest = json.loads((FIXTURES_DIR / "scenes/asset_positive.scene.json").read_text("utf-8"))
    manifest.update(scene_id=data["scene_id"], version=data["version"],
                    preview={"frames_ms": [0, 500], "states": [{"beat": 0, "focus": -1}]})
    assert {a["anchor_id"] for a in data["required_anchors"]} <= {"palm", "well", "tent"}
    return {"manifest_json": json.dumps(manifest), "artwork": [
        {"asset_id": a["asset_id"], "brief": "Neutral synthetic geometry", "width": a["width"], "height": a["height"]}
        for a in manifest["assets"]]}


async def run_lesson(settings: Settings, tmp_path: Path, *, recitation: bool = True,
                     **overrides: Any) -> tuple[Resources, Harness, str, list[str], Recordings]:
    path, _, terms = policy(tmp_path, recitation=recitation)
    configured = settings.model_copy(update={"media_policy_path": path, "image_provider": "openai",
                                             "cdn_base_url": "https://cdn.qabas.app/media"})
    resources = Resources.create(configured)
    answers = {"factory_decompose": decompose, "factory_write": write, "factory_exercises": exercises,
               "factory_visuals": selection, "factory_scene_author": authored,
               "factory_image_prompt": {"prompt": "Neutral synthetic geometry, no text"},
               "factory_visual_audit": {"passed": True, "issues": []}} | overrides
    tools = Tools(translations=P.manifest(tmp_path))
    recordings = Recordings()
    h = Harness(resources, FakeLLMClient(P.script(**answers)), tools)
    media = MediaService(resources.storage, image_provider=Images(), image_terms=terms, style=style_inputs(path),
                         previewer=Normative())
    h.orchestrator.services = {"sources": lambda: tools, "media": media, "recordings": recordings}
    run_id, outcomes = await h.to_gate2()
    return resources, h, run_id, outcomes, recordings


@pytest.fixture
def settings(fresh_curriculum: Any) -> Settings:
    value: Settings = fresh_curriculum[1]
    return value


async def test_bound_exercises_and_reference_audio_reach_gate2_and_publish(
        settings: Settings, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    resources, h, run_id, outcomes, recordings = await run_lesson(settings, tmp_path)
    try:
        run = await h.load(run_id)
        assert run.status == "awaiting_gate2", (outcomes, run.error)
        package = LessonPackage.model_validate(run.artifacts["qa"]["output"]["package"])
        by_type = {r.type: r for r in package.exercises}
        # map_place: a generated scene with the exercise state as its fallback; pins at the authored anchors.
        mapped = by_type["map_place"].exercise["ar"]
        anchors = {a["anchor_id"]: a for a in json.loads(
            (FIXTURES_DIR / "scenes/asset_positive.scene.json").read_text("utf-8"))["anchors"]}
        assert mapped.payload["visual"]["kind"] == "scene"
        assert mapped.payload["visual"]["fallback_params"] == mapped.payload["visual"]["params"]
        for pin in mapped.payload["pins"]:
            anchor = anchors[pin["anchor_id"]]
            assert (pin["x_pct"], pin["y_pct"]) == (100 * anchor["x"] / 1600, 100 * anchor["y"] / 1000)
        correct = mapped.answer_key.pin_id
        assert next(p for p in mapped.payload["pins"] if p["pin_id"] == correct)["anchor_id"] == "well"
        assert [p["pin_id"] for p in mapped.payload["pins"]] == ["p1", "p2", "p3"]   # hash-ordered, opaque
        assert {p["label"] for p in by_type["map_place"].feedback["ar"].model_dump()["pin_labels"]} == {
            t["label"] for t in TARGETS}
        # timeline_order: served shuffled, dates revealed only through feedback, keyed to served ids.
        timeline = by_type["timeline_order"]
        served = [e["event_id"] for e in timeline.exercise["ar"].payload["events"]]
        assert served != timeline.exercise["ar"].answer_key.order
        assert sorted(d.event_id for d in timeline.feedback["ar"].event_dates) == sorted(served)
        # recite_verse: ungraded, an exact licensed cut of words 2-4 with global positions, its own activity source.
        recite = by_type["recite_verse"].exercise["ar"]
        assert recite.scoring.model_dump() == {"accuracy": False, "combo": False, "layer": None}
        assert recite.payload["audio"]["url"].startswith("https://cdn.qabas.app/media/recitation-clips/")
        assert [w["position"] for w in recite.payload["audio"]["words"]] == [2, 3, 4]
        assert recite.payload["audio"]["words"][0]["start_ms"] == 0
        items = resolve_items(package, "ar", "explorer")
        assert display_roles(items)[recite.payload["source_id"]] == "activity"
        # Displayed Qur'an evidence: whole-ayah reference audio with every word; the source id is rebound
        # consistently (blocks, claims, sources) to the audio-bearing bundle.
        teach = next(b for b in package.variants["ar"]["explorer"].blocks if b["block_id"] == "b_teach")
        evidence = teach["evidence"]
        assert evidence["quran"]["audio"]["words"][0]["position"] == 1
        retrieved = {c["source_id"] for c in run.artifacts["retrieve"]["output"]["candidates"]}
        assert evidence["evidence_id"] not in retrieved
        claim_sources = {e.source.source_id for c in package.claims for e in c.evidence}
        assert evidence["evidence_id"] in claim_sources and evidence["evidence_id"] in {s.source_id for s in
                                                                                         package.sources}
        english = next(b for b in package.variants["en"]["explorer"].blocks if b["block_id"] == "b_teach")
        assert english["evidence"]["quran"]["audio"] == evidence["quran"]["audio"]
        assert english["evidence"]["quran"]["translation"] is not None
        assert recordings.reads == 2                                   # one licensed read per bound passage
        # Gate 2: every receipt, the clip provenance and the gold path's scripture verification pass; it publishes.
        # The production registry releases no capability yet (O-02), so a test-only release stands in for it.
        from app.media import scenes
        released = scenes.registry()
        for capability in released["capabilities"]:
            capability.update(status="released", release_evidence={"synthetic_test_only": True})
        monkeypatch.setattr(scenes, "registry", lambda: released)
        try:
            result = await decide_gate2(
                resources.sessionmaker, resources.settings, h.dispatcher, run_id=run_id,
                reviewer_id="usr_factory_reviewer",
                body=C.Gate2(decision="approve", review_digest=run.review_digest or "", sentence_edits=[],
                             exercise_removals=[], reason=None),
                authority=ScriptureAuthority(mushaf=P.synthetic.mushaf(), translations=P.manifest(tmp_path)),
                storage=resources.storage)
        except Exception as exc:
            raise AssertionError(getattr(exc, "details", exc)) from exc
        assert result["status"] == "published"
    finally:
        await resources.close()


async def test_a_timeline_event_must_be_dated_by_a_supported_historical_claim(settings: Settings,
                                                                               tmp_path: Path) -> None:
    resources, h, run_id, _, _ = await run_lesson(
        settings, tmp_path, factory_exercises=lambda d: exercises(d, event_claim="c2"))
    try:
        run = await h.load(run_id)
        assert run.status == "failed" and run.error["code"] == "exercises_invalid"
        assert "not a supported historical claim" in run.error["message"]
    finally:
        await resources.close()


async def test_without_licensed_recitation_no_recitation_or_reference_audio_is_offered(settings: Settings,
                                                                                         tmp_path: Path) -> None:
    resources, h, run_id, _, recordings = await run_lesson(settings, tmp_path, recitation=False)
    try:
        run = await h.load(run_id)
        assert run.status == "failed" and run.error["code"] == "draft_invalid"
        assert "O-06" in run.error["message"] and recordings.reads == 0
    finally:
        await resources.close()


async def test_a_map_hotspot_needs_a_generated_scene(settings: Settings, tmp_path: Path) -> None:
    def flat(data: dict[str, Any]) -> dict[str, Any]:
        value = selection(data)
        for item in value["visuals"]:
            item.update(kind="image", params_json="{}", group="setting")
        return value

    resources, h, run_id, _, _ = await run_lesson(settings, tmp_path, factory_visuals=flat)
    try:
        run = await h.load(run_id)
        assert run.status == "failed" and run.error["code"] == "visual_selection_invalid"
        assert "static anchors" in run.error["message"]
    finally:
        await resources.close()


def test_pins_follow_anchors_and_never_exceed_the_tap_radius_limit() -> None:
    from app.factory.stages.media import pins_from_anchors
    manifest = {"view_box": {"width": 1600, "height": 1000},
                "anchors": [{"anchor_id": "a", "layer_id": "l", "x": 800, "y": 500, "radius": 1000}]}
    pins = pins_from_anchors(manifest, {"targets": [{"pin_id": "p1", "target_id": "a", "label": "x"}]})
    assert pins == [{"pin_id": "p1", "anchor_id": "a", "x_pct": 50.0, "y_pct": 50.0, "radius_pct": 25.0}]
    from app.media.errors import MediaInvalid
    with pytest.raises(MediaInvalid, match="no static anchor"):
        pins_from_anchors(copy.deepcopy(manifest) | {"anchors": []},
                          {"targets": [{"pin_id": "p1", "target_id": "a", "label": "x"}]})


def test_the_recordings_library_verifies_every_licensed_file(tmp_path: Path) -> None:
    from app.media.errors import MediaInvalid, MediaNotConfigured
    from app.media.recitation import DirectoryRecordings
    data = audio()
    (tmp_path / "001001.mp3").write_bytes(data)
    (tmp_path / "recordings.yaml").write_text(yaml.safe_dump({
        "schema": "qabas.reference_recordings/1", "reciter_id": 7,
        "items": [{"surah": 1, "ayah": 1, "file": "001001.mp3", "sha256": sha256_hex(data)},
                  {"surah": 1, "ayah": 2, "file": "../outside.mp3", "sha256": "0" * 64}]}), encoding="utf-8")
    library = DirectoryRecordings(tmp_path)
    assert library.recording(1, 1) == (data, sha256_hex(data)) and library.reciter_id == 7
    with pytest.raises(MediaNotConfigured, match="no licensed reference recording"):
        library.recording(1, 3)
    with pytest.raises(MediaNotConfigured, match="missing"):
        library.recording(1, 2)                                        # never reads outside the library
    (tmp_path / "001001.mp3").write_bytes(data + b"\x00")
    with pytest.raises(MediaInvalid, match="changed"):
        library.recording(1, 1)


def test_prepared_scene_author_candidates_match_their_recorded_digests() -> None:
    """The committed policy lists the derived token mapping and the candidate examples by digest; approval stays a
    human sign-off (O-13), so the Scene Author still refuses to run on the committed policy."""
    from app.media.errors import MediaNotConfigured
    from app.media.policy import POLICY, policy, scene_author_inputs
    entry = policy(POLICY)["scene_author"]
    assert entry["status"] == "pending" and entry["approved_by"] is None
    for item in (entry["design_tokens"], *entry["examples"]):
        assert sha256_hex((BACKEND_DIR / item["path"]).read_bytes()) == item["sha256"]
    tokens = json.loads((BACKEND_DIR / entry["design_tokens"]["path"]).read_text("utf-8"))
    assert tokens["tokens"]["flame_gold"] == "#E0A526" and len(entry["examples"]) == 2
    with pytest.raises(MediaNotConfigured, match="pending"):
        scene_author_inputs(Settings())
