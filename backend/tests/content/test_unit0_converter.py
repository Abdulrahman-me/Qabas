"""The Unit 0 authoring converter (D-40, D-81, D-82) on a synthetic, neutral authoring record.

The real drafts are unapproved and stay private (D-19); this record has their exact shape with neutral text.
"""

from __future__ import annotations

import copy
from typing import Any

import pytest

from app.content.curriculum import ConceptSpec, Curriculum, load_curriculum
from app.content.importers import unit0
from app.content.package import LessonPackage
from app.content.validation import Context, validate_package

CONCEPTS = ["con_u0_test_a", "con_u0_test_b"]


def T(ar: str, en: str) -> dict[str, str]:
    return {"ar": ar, "en": en}


def S(text: str) -> list[dict[str, str]]:
    return [{"type": "text", "text": text}]


def sentence(sid: str, text: str, role: str = "framing", claims: list[str] | None = None) -> dict[str, Any]:
    return {"sentence_id": sid, "role": role, "claim_ids": claims or [], "spans": S(text)}


VISUAL = {"kind": "builtin", "key": "workplace", "version": 1, "params": {}, "image": None, "scene": None,
          "fallback_image": None, "fallback_params": None, "alt": "desk", "overlays": []}


def mc(exercise_id: str, lang: str, correct: str = "opt_b") -> dict[str, Any]:
    word = "Option" if lang == "en" else "خيار"
    return {"exercise_id": exercise_id, "type": "multiple_choice", "concept_ids": list(CONCEPTS),
            "prompt": S(f"{word} ?"), "time_limit_ms": None,
            "scoring": {"accuracy": True, "combo": True, "layer": "understand"}, "framing": None,
            "payload": {"options": [{"option_id": o, "spans": S(f"{word} {o}")} for o in ("opt_a", "opt_b", "opt_c")]}}


def pool(exercise_id: str, *, duel: bool = False) -> dict[str, Any]:
    return {"exercise_id": exercise_id, "type": "multiple_choice", "concept_ids": list(CONCEPTS),
            "prompt": {lang: mc(exercise_id, lang)["prompt"] for lang in ("ar", "en")},
            "time_limit_ms": 15000 if duel else None,
            "scoring": {"accuracy": True, "combo": False, "layer": "understand"}, "framing": None,
            "payload": {lang: mc(exercise_id, lang)["payload"] for lang in ("ar", "en")},
            "correct_answer": {"option_id": "opt_b"},
            "explanation": {"ar": S("شرح."), "en": S("Explanation.")}}


def nested_key(item: dict[str, Any]) -> dict[str, Any]:
    """The drafts' other key form: ``answer_key: {correct_answer, option_misconceptions}``."""
    key = item.pop("correct_answer")
    return {**item, "answer_key": {"correct_answer": key, "option_misconceptions": {}}}


def variant(lang: str) -> dict[str, Any]:
    def text(ar: str, en: str) -> str:
        return ar if lang == "ar" else en
    exercise = {**mc("ex_u0_t_01", lang), "explanation": [sentence("s_ex1", text("لأن ب صحيح.", "Because B holds."),
                                                                   "claim", ["c_t_01"])]}
    exercise_2 = {**mc("ex_u0_t_02", lang), "explanation": [sentence("s_ex2", text("شرح.", "Explanation."))]}
    return {
        "title": text("درس", "Lesson"), "subtitle": text("فرعي", "Subtitle"),
        "objectives": [S(text("هدف.", "Objective."))],
        "blocks": [
            {"block_id": "b_hook", "type": "hook", "situation": [sentence("s_h1", text("تخيل موقفا.", "Imagine."),
                                                                          "hypothetical")],
             "question": [sentence("s_h2", text("ماذا ترى؟", "What do you see?"), "question")], "visual": VISUAL,
             "cta": None},
            {"block_id": "b_teach", "type": "teach", "eyebrow": None, "title": S(text("فكرة", "Idea")),
             "style": "standard", "visual": None, "evidence": None,
             "points": [{"point_id": "p1", "sentence": sentence("s_t1", text("ب يصح هنا.", "B holds here."), "claim",
                                                                ["c_t_01"]), "visual_params": None}]},
            {"block_id": "b_ex1", "type": "exercise", "exercise": exercise},
            {"block_id": "b_ex2", "type": "exercise", "exercise": exercise_2},
        ],
        "completion": {"challenge": None, "check_in": None,
                       "review_topics": [{"concept_ids": [CONCEPTS[0]], "label": S(text("موضوع", "Topic"))}]},
    }


def record() -> dict[str, Any]:
    return {
        "lesson_id": "les_u0_l01", "unit_id": "unit_0", "number": "0.1", "index": 1,
        "plan": {
            "title": T("درس", "Lesson"), "lesson_type": "concept", "depth_profile": "standard",
            "central_question": T("سؤال؟", "Question?"), "primary_learning_outcome": T("نتيجة", "Outcome"),
            "supporting_understandings": [T("فهم", "Understanding")], "objectives": [T("هدف.", "Objective.")],
            "prerequisite_concept_ids": [], "introduced_concept_ids": list(CONCEPTS),
            "new_terms": ["term_u0_t"], "target_misconceptions": ["mis_u0_t"], "estimated_minutes": 7,
            "lesson_arc": {"pattern": "discovery", "rationale": T("سبب", "Why"),
                           "steps": [{"step_id": "a1", "technique": "scenario", "experience": T("موقف", "Scene"),
                                      "learner_acts": False},
                                     {"step_id": "a2", "technique": "explanation", "experience": T("شرح", "Explain"),
                                      "learner_acts": False},
                                     {"step_id": "a3", "technique": "practice", "experience": T("تدرب", "Practise"),
                                      "learner_acts": True}]},
            "reasoning_tools": [{"tool": "observation_vs_inference", "justification": T("لماذا", "Why")}],
            "standalone_eligible": True, "content_budget": 2, "exercise_budget": 2, "unit_context_check": "ok"},
        "concepts": [{"concept_id": c, "label": T(c, c)} for c in CONCEPTS],
        "claims": [{"claim_id": "c_t_01", "arc_step_id": "a2", "basis": "reasoning", "text": T("ب يصح.", "B holds."),
                    "reasoning": {"tool": "observation_vs_inference", "premises": ["A premise."],
                                  "inference": "B holds."}}],
        "variants": {"ar_explorer": variant("ar"), "en_explorer": variant("en")},
        "arc_map": {"a1": ["b_hook"], "a2": ["b_teach"], "a3": ["b_ex1", "b_ex2"]},
        "answer_keys": {"ex_u0_t_01": {"correct_answer": {"option_id": "opt_b"},
                                       "option_misconceptions": {"opt_a": "mis_u0_t"}},
                        "ex_u0_t_02": {"correct_answer": {"option_id": "opt_c"}, "option_misconceptions": {}}},
        "flashcards": [{"exercise_id": f"ex_u0_t_fc{n}", "type": "flashcard", "concept_ids": [c],
                        "prompt": {"ar": [], "en": []}, "time_limit_ms": None,
                        "scoring": {"accuracy": False, "combo": False, "layer": None}, "framing": None,
                        "payload": {lang: {"front": S("front"), "back": S("back")} for lang in ("ar", "en")}}
                       for n, c in enumerate(CONCEPTS)],
        "assessment_items": {"pretest": [pool(f"ex_u0_t_pre{n}") for n in range(2)],
                             "unit_test": [nested_key(pool(f"ex_u0_t_ut{n}")) for n in range(3)]},
        "duel_items": [pool(f"ex_u0_t_duel{n}", duel=True) for n in range(3)],
        "glossary": [{"term_id": "term_u0_t", "arabic": "مصطلح", "heading": T("مصطلح", "Term"),
                      "transliteration": "mustalah", "definition_basic": T("تعريف", "Definition"),
                      "example": T("مثال", "Example")}],
        "misconceptions": [{"misconception_id": "mis_u0_t", "statement": T("فكرة خاطئة", "A wrong idea"),
                            "correction": T("تصحيح", "A correction")}],
        "visuals": [], "qa_self_check": [], "flags_for_specialist": ["Check the wording of point 1."],
    }


def curriculum() -> Curriculum:
    cur = load_curriculum()
    return cur.model_copy(update={"concepts": [ConceptSpec(concept_id=c, unit_id="unit_0", title=T(c, c))
                                               for c in CONCEPTS]})


APPROVED = unit0.ToolMapping(status="approved", approved_by="Test Specialist",
                             mapping={"observation_vs_inference": "observation"})


def codes(conversion: unit0.Conversion) -> set[str]:
    return {b.code for b in conversion.blockers}


def test_a_resolved_record_projects_to_a_valid_lesson() -> None:
    conversion = unit0.convert(record(), curriculum(), mapping=APPROVED, scenes={})
    assert conversion.blockers == [] and conversion.package is not None
    package = LessonPackage.model_validate(conversion.package)
    assert (package.lesson_id, package.unit_id, package.index) == ("les_u0_l1", "unit_0", 0)   # D-82
    assert [s.interactive for s in package.plan.lesson_arc.steps] == [False, False, True]     # learner_acts
    assert package.plan.reasoning_tools[0].tool == "observation"
    assert package.claims[0].text == "ب يصح." and package.claims[0].reasoning.tool == "observation"  # type: ignore[union-attr]
    roles = {s.sentence_id: s.role for s in package.sentence_map}
    assert roles == {"s_t1": "claim"}                    # hook sentences become spans; only Sentence objects keep roles
    hook = package.variants["ar"]["explorer"].blocks[0]
    assert hook["situation"] == S("تخيل موقفا.") and hook["question"] == S("ماذا ترى؟")
    by_id = {e.exercise_id: e for e in package.exercises}
    assert by_id["ex_u0_t_01"].exercise["ar"].option_misconceptions == {"opt_a": "mis_u0_t"}
    assert by_id["ex_u0_t_ut0"].exercise["en"].answer_key is not None                       # nested key form
    assert by_id["ex_u0_t_duel0"].exercise["ar"].duel_eligible
    assert package.glossary[0].lesson_id == "les_u0_l1"
    topic = package.variants["en"]["explorer"].completion
    assert topic is not None and topic.review_topics[0].title == "Topic"
    issues = validate_package(package, Context(unit_tracks=["explorer"], known_concepts=set(CONCEPTS)))
    assert issues == []
    assert conversion.notes == ["specialist flag: Check the wording of point 1."]


def test_the_committed_tool_mapping_is_pending_and_blocks() -> None:
    mapping = unit0.load_mapping()
    assert mapping.status == "pending" and all(v is None for v in mapping.mapping.values())
    assert len(mapping.mapping) == 9                                                         # D-40
    conversion = unit0.convert(record(), curriculum(), mapping=mapping, scenes={})
    assert conversion.package is None
    details = [b.detail for b in conversion.blockers if b.code == "reasoning_tool_unmapped"]
    assert details == ["plan tool observation_vs_inference", "claim c_t_01 tool observation_vs_inference"]


def test_quran_placeholders_use_verified_sources_and_keep_unselected_english_blocked() -> None:
    from app.sources.scripture import insert
    from tests.sources.synthetic import mushaf
    data = record()
    for variant in data["variants"].values():
        variant["blocks"][1]["evidence"] = {"kind": "quran", "ref": "1:1", "insert_by_code": True}
    canonical = mushaf()
    def resolve(reference: str, language: str) -> Any:
        passage = canonical.resolve(reference)
        return insert(canonical, passage.surah, (passage.ayah_start, passage.ayah_end), language=language)
    conversion = unit0.convert(data, curriculum(), mapping=APPROVED, scenes={}, scripture=resolve)
    assert conversion.package is None and len(conversion.source_records) == 1
    assert all("en translation is unselected" in blocker.detail for blocker in conversion.blockers)
    assert next(iter(conversion.source_records.values())).text == canonical.get(1, 1).text_uthmani


def test_bilingual_quran_insertion_keeps_identity_and_all_provenance(tmp_path: Any) -> None:
    from app.sources.scripture import insert
    from tests.sources.synthetic import mushaf
    from tests.sources.test_scripture import manifest, translation
    data = record()
    for variant in data["variants"].values():
        variant["blocks"][1]["evidence"] = {"kind": "quran", "ref": "1:1", "insert_by_code": True}
    canonical, choice, selected = mushaf(), manifest(tmp_path), translation()
    def resolve(reference: str, language: str) -> Any:
        passage = canonical.resolve(reference)
        return insert(canonical, passage.surah, (passage.ayah_start, passage.ayah_end), language=language,
                      translations=(selected,), translation_manifest=choice)
    conversion = unit0.convert(data, curriculum(), mapping=APPROVED, scenes={}, scripture=resolve)
    assert conversion.package is not None and not conversion.blockers
    ar = conversion.package["variants"]["ar"]["explorer"]["blocks"][1]["evidence"]
    en = conversion.package["variants"]["en"]["explorer"]["blocks"][1]["evidence"]
    assert ar["evidence_id"] == en["evidence_id"]
    assert ar["quran"]["translation"] is None and en["quran"]["translation"] == selected.text
    assert len(conversion.package["sources"]) == 1 and len(conversion.source_records) == 2


@pytest.mark.parametrize(("change", "code"), [
    (lambda r: r["plan"]["lesson_arc"].update(rationale="English only"), "plan_text_missing"),
    (lambda r: r["plan"]["reasoning_tools"][0].update(justification="English only"), "plan_text_missing"),
    (lambda r: None, "concept_unregistered"),
    (lambda r: r["variants"]["ar_explorer"]["blocks"][1].update(
        evidence={"kind": "quran", "ref": "1:1", "insert_by_code": True}), "source_pending"),
    (lambda r: r["claims"].append({"claim_id": "c_src", "basis": "source", "text": T("x", "x"),
                                   "source_note": "Source X"}), "source_pending"),
    (lambda r: [v["blocks"][0].update(visual={"kind": "scene", "scene_id": "scn_x", "params": {"beat": 0},
                                              "alt": "x"}) for v in r["variants"].values()], "scene_media_unpublished"),
    (lambda r: [v["blocks"][0]["question"][0].update(role="claim", claim_ids=["c_only_here"])
                for v in r["variants"].values()], "claim_in_span_field"),
    (lambda r: r.update(number="0.99"), "record_invalid"),
])
def test_each_missing_input_blocks_with_its_owner(change: Any, code: str) -> None:
    data = copy.deepcopy(record())
    change(data)
    cur = load_curriculum() if code == "concept_unregistered" else curriculum()
    conversion = unit0.convert(data, cur, mapping=APPROVED, scenes={})
    assert conversion.package is None and code in codes(conversion), conversion.blockers
    assert all(b.owner for b in conversion.blockers)


def test_a_flattened_claim_taught_elsewhere_is_not_lost() -> None:
    data = copy.deepcopy(record())
    for v in data["variants"].values():   # the same claim is also linked by the teach sentence
        v["blocks"][0]["question"][0].update(role="claim", claim_ids=["c_t_01"])
    assert unit0.convert(data, curriculum(), mapping=APPROVED, scenes={}).blockers == []


def test_scene_visuals_resolve_only_with_published_media() -> None:
    data = copy.deepcopy(record())
    for v in data["variants"].values():
        v["blocks"][0]["visual"] = {"kind": "scene", "scene_id": "scn_x", "params": {"beat": 0}, "alt": "x"}
    ref = {"scene_id": "scn_x", "version": 2, "schema_version": "qabas.scene/1", "url": "https://cdn.qabas.app/s.json",
           "mime_type": "application/json", "sha256": "a" * 64, "view_box": {"width": 1600, "height": 1000},
           "required_capabilities": []}
    image = {"url": "https://cdn.qabas.app/f.webp", "mime_type": "image/webp", "width": 1600, "height": 1000}
    media = unit0.SceneMedia(scene_ref=ref, fallbacks={'{"beat": 0}': image})
    conversion = unit0.convert(data, curriculum(), mapping=APPROVED, scenes={"scn_x": media})
    assert conversion.blockers == [] and conversion.package is not None
    visual = conversion.package["variants"]["ar"]["explorer"]["blocks"][0]["visual"]
    assert visual["scene"] == ref and visual["fallback_image"] == image and visual["fallback_params"] == {"beat": 0}
