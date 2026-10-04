"""Each deterministic content rule rejects the violation it targets (factory §13.2-13.5, backend §6.5).

Every test starts from a valid package (the synthetic test curriculum) and breaks exactly one rule.
"""

from __future__ import annotations

import copy
from collections.abc import Callable
from typing import Any

import pytest
from pydantic import ValidationError

from app.content.package import LessonPackage
from app.content.test_curriculum import build_curriculum, build_packages
from app.content.validation import Context, validate_package

CURRICULUM = build_curriculum()
PACKAGES = {p.lesson_id: p for p in build_packages()}
CONCEPTS = {c.concept_id for c in CURRICULUM.concepts}


def ctx(lesson_id: str, **overrides: Any) -> Context:
    package = PACKAGES[lesson_id]
    return Context(unit_tracks=list(CURRICULUM.unit(package.unit_id).tracks), known_concepts=CONCEPTS,
                   allow_placeholder_media=True, **overrides)


def broken(lesson_id: str, mutate: Callable[[dict[str, Any]], None]) -> LessonPackage:
    data = copy.deepcopy(PACKAGES[lesson_id].model_dump(mode="json"))
    mutate(data)
    return LessonPackage.model_validate(data)


def codes(package: LessonPackage, context: Context) -> list[str]:
    return [f"{i.code}: {i.message}" for i in validate_package(package, context)]


def assert_issue(lesson_id: str, mutate: Callable[[dict[str, Any]], None], expected: str, **ctx_overrides: Any) -> None:
    found = codes(broken(lesson_id, mutate), ctx(lesson_id, **ctx_overrides))
    assert any(expected in f for f in found), found


def ex(data: dict[str, Any], purpose: str | None = None, typ: str | None = None) -> list[dict[str, Any]]:
    return [e for e in data["exercises"] if (purpose is None or e["purpose"] == purpose)
            and (typ is None or e["exercise"]["ar"]["type"] == typ)]


@pytest.mark.parametrize("lesson_id", sorted(PACKAGES))
def test_every_test_curriculum_lesson_is_valid(lesson_id: str) -> None:
    assert codes(PACKAGES[lesson_id], ctx(lesson_id)) == []


# --- variants, skeleton, localization ---------------------------------------------------------------

def test_explorer_only_unit_has_no_new_muslim_variant() -> None:
    def add_new_muslim(d: dict[str, Any]) -> None:
        for lang in ("ar", "en"):
            d["variants"][lang]["new_muslim"] = copy.deepcopy(d["variants"][lang]["explorer"])
    assert_issue("les_t1_0", add_new_muslim, "are not tracks of this unit")


def test_shared_lesson_requires_an_explorer_variant() -> None:
    def drop_explorer(d: dict[str, Any]) -> None:
        for lang in ("ar", "en"):
            d["variants"][lang].pop("explorer")
    assert_issue("les_t2_0", drop_explorer, "never served a New Muslim variant")


def test_variants_share_one_block_skeleton() -> None:
    assert_issue("les_t2_0", lambda d: d["variants"]["ar"]["new_muslim"]["blocks"].reverse(), "one block skeleton")


def test_english_keeps_sentence_ids() -> None:
    def rename(d: dict[str, Any]) -> None:
        d["variants"]["en"]["explorer"]["blocks"][0]["sentences"][0]["sentence_id"] = "s_other"
    assert_issue("les_t1_0", rename, "keeps every sentence id")


def test_localization_keeps_exercise_answers() -> None:
    def change_key(d: dict[str, Any]) -> None:
        mcq = ex(d, "lesson", "multiple_choice")[0]
        mcq["exercise"]["en"]["answer_key"] = {"option_id": "opt_other"}
    with pytest.raises(ValidationError, match="ar and en differ in answer_key"):
        broken("les_t1_0", change_key)


# --- sentences, claims, arc ------------------------------------------------------------------------------

def test_every_sentence_has_a_role() -> None:
    assert_issue("les_t1_0", lambda d: d["sentence_map"].clear(), "every sentence needs a role")


def test_claim_sentences_link_supported_claims() -> None:
    def link(d: dict[str, Any]) -> None:
        d["sentence_map"][0].update(role="claim", claim_ids=["clm_missing"])
    assert_issue("les_t1_0", link, "not a supported claim")


def test_reasoning_claims_use_planned_tools() -> None:
    def add_claim(d: dict[str, Any]) -> None:
        d["claims"].append({"claim_id": "clm_r", "text": "A reasoned point.", "status": "supported",
                            "basis": "reasoning", "evidence": [],
                            "reasoning": {"tool": "inference", "premises": ["p"], "inference": "q"}})
    assert_issue("les_t1_0", add_claim, "is not in the approved plan")


def test_arc_map_follows_the_plan() -> None:
    assert_issue("les_t1_0", lambda d: d["arc_map"].reverse(), "every approved arc step once, in order")
    assert_issue("les_t1_0", lambda d: d["arc_map"][0]["block_ids"].append("b_ghost"), "unknown block")


def test_blocks_follow_their_arc_technique() -> None:
    def predict_in_explanation(d: dict[str, Any]) -> None:
        for by in d["variants"].values():
            for content in by.values():
                content["blocks"].insert(0, {"block_id": "b_pr", "type": "predict",
                                             "prompt": [{"type": "text", "text": "Guess?"}],
                                             "options": [{"option_id": "o1", "spans": [{"type": "text", "text": "A"}]},
                                                         {"option_id": "o2", "spans": [{"type": "text", "text": "B"}]}],
                                             "reveal": [{"type": "text", "text": "R"}], "visual": None})
        d["arc_map"][0]["block_ids"].insert(0, "b_pr")
    assert_issue("les_t1_0", predict_in_explanation, "predict block belongs to a prediction or reflection step")


# --- exercises and pools -------------------------------------------------------------------------------------

def test_graded_exercise_bounds() -> None:
    def one_graded(d: dict[str, Any]) -> None:
        for e in ex(d, "lesson")[1:]:
            for lang in ("ar", "en"):
                e["exercise"][lang]["scoring"]["accuracy"] = False
    assert_issue("les_t1_0", one_graded, "2-6 graded exercises")


def test_each_taught_concept_has_a_flashcard() -> None:
    assert_issue("les_t1_0", lambda d: d["exercises"].remove(ex(d, typ="flashcard")[0]), "at least one flashcard")


def test_assessment_and_duel_supply() -> None:
    assert_issue("les_t1_0", lambda d: d["exercises"].remove(ex(d, "pretest")[0]), "2 pretest item(s)")
    assert_issue("les_t1_0", lambda d: d["exercises"].remove(ex(d, "duel")[0]), "3 duel item(s)")


def test_assessment_type_rules() -> None:
    def flashcard_pretest(d: dict[str, Any]) -> None:
        ex(d, typ="flashcard")[0]["purpose"] = "pretest"
    assert_issue("les_t1_0", flashcard_pretest, "excluded from pretests")


def test_answer_key_must_use_served_ids() -> None:
    def bad_key(d: dict[str, Any]) -> None:
        for lang in ("ar", "en"):
            ex(d, "lesson", "multiple_choice")[0]["exercise"][lang]["answer_key"] = {"option_id": "opt_unserved"}
    assert_issue("les_t1_0", bad_key, "key is not a complete answer")


def test_scenario_feedback_covers_every_option() -> None:
    lesson_id = next(lid for lid, p in PACKAGES.items() if any(e.type == "scenario" for e in p.exercises))
    def drop_feedback(d: dict[str, Any]) -> None:
        ex(d, typ="scenario")[0]["feedback"]["ar"]["option_feedback"].pop()
    assert_issue(lesson_id, drop_feedback, "option_feedback must cover exactly the served ids")


# --- sources, terms, misconceptions, media -----------------------------------------------------------------

def test_sources_must_exist() -> None:
    lesson_id = next(lid for lid, p in PACKAGES.items() if p.sources)
    assert_issue(lesson_id, lambda d: d["sources"].clear(), "not in the package or the source registry")


def test_content_source_budget() -> None:
    def four_evidence_blocks(d: dict[str, Any]) -> None:
        for n in range(4):
            sid = f"src_q_1_{n}"
            d["sources"].append({"source_id": sid, "kind": "quran", "provider": "quran_com", "title": "T",
                                 "reference": f"1:{n + 1}", "excerpt": "text", "url": None})
            for by in d["variants"].values():
                for content in by.values():
                    content["blocks"].insert(1, {
                        "block_id": f"b_ev{n}", "type": "evidence", "caption": None, "evidence": {
                        "evidence_id": sid, "kind": "quran", "hadith": None, "quran": {
                            "surah": 1, "surah_name": "T", "ayah_start": n + 1, "ayah_end": n + 1, "segment": None,
                            "text_uthmani": "text", "translation": None, "translation_source": None, "audio": None}}})
            d["arc_map"][0]["block_ids"].insert(1, f"b_ev{n}")
    assert_issue("les_t1_0", four_evidence_blocks, "at most 3 displayed content sources")


def test_term_spans_need_glossary_records() -> None:
    def term(d: dict[str, Any]) -> None:
        for by in d["variants"].values():
            for content in by.values():
                content["blocks"][0]["sentences"][0]["spans"].append({"type": "term", "text": "x", "term_id": "term_x"})
    assert_issue("les_t1_0", term, "without a glossary record")


def test_mapped_misconceptions_need_cards() -> None:
    def map_option(d: dict[str, Any]) -> None:
        for lang in ("ar", "en"):
            mcq = ex(d, "lesson", "multiple_choice")[0]["exercise"][lang]
            mcq["option_misconceptions"] = {mcq["payload"]["options"][1]["option_id"]: "mis_missing"}
    assert_issue("les_t1_0", map_option, "maps a misconception without a card")


def test_placeholder_media_blocks_publication() -> None:
    # The fixtures use mock-asset:// images on purpose; real content must not (contextual.placeholder_media_errors).
    lesson_id = "les_t2_1"  # the image-only lesson
    strict = Context(unit_tracks=list(CURRICULUM.unit(PACKAGES[lesson_id].unit_id).tracks),
                     known_concepts=CONCEPTS, allow_placeholder_media=False)
    found = codes(PACKAGES[lesson_id], strict)
    assert any("placeholder media URL mock-asset://" in f for f in found), found


def test_a_served_order_must_not_reveal_the_answer() -> None:
    lesson_id, exercise_id = next((p.lesson_id, e.exercise_id) for p in PACKAGES.values() for e in p.exercises
                                  if e.type == "order_steps")

    def key_order(d: dict[str, Any]) -> None:
        for lang in ("ar", "en"):
            record = next(e for e in d["exercises"] if e["exercise_id"] == exercise_id)["exercise"][lang]
            by_id = {s["step_id"]: s for s in record["payload"]["steps"]}
            record["payload"]["steps"] = [by_id[i] for i in record["answer_key"]["order"]]
    assert_issue(lesson_id, key_order, "order equals the answer key")


def test_a_match_column_must_not_line_up_with_its_answer() -> None:
    lesson_id, exercise_id = next((p.lesson_id, e.exercise_id) for p in PACKAGES.values() for e in p.exercises
                                  if e.type == "match_pairs")

    def aligned(d: dict[str, Any]) -> None:
        for lang in ("ar", "en"):
            record = next(e for e in d["exercises"] if e["exercise_id"] == exercise_id)["exercise"][lang]
            pairs = {p["left_id"]: p["right_id"] for p in record["answer_key"]["pairs"]}
            by_id = {r["item_id"]: r for r in record["payload"]["right"]}
            record["payload"]["right"] = [by_id[pairs[x["item_id"]]] for x in record["payload"]["left"]]
    assert_issue(lesson_id, aligned, "order equals the answer key")
