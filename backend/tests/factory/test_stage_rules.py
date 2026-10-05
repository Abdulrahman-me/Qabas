"""Factory stage rules without the database: request execution through the source layer, composition helpers,
decomposition checks, and the structural guarantee that model calls go through ``app.llm`` only."""

from __future__ import annotations

import ast
from pathlib import Path

from app.config import BACKEND_DIR
from app.factory import compose
from app.factory.stage_models import Decomposition, RetrievalPlan
from app.factory.stages import decompose, retrieve
from tests.factory import pipeline_support as P
from tests.factory.support import plan


async def test_requests_execute_only_through_the_source_layer(tmp_path: Path) -> None:
    tools = P.SyntheticTools(translations=P.manifest(tmp_path))
    requests = RetrievalPlan.model_validate({"issues": [], "requests": [
        P.request("r1", "c1", "quran_text", text="في الحديقة شجرة كبيرة"),       # verbatim (standard orthography)
        P.request("r2", "c1", "quran_text", text="في الحديقة شجرة صغيرة"),       # not verbatim: never "corrected"
        P.request("r3", "c1", "quran_reference", reference="1:1-12"),            # more than 10 ayahs / outside
        P.request("r4", "c1", "quran_reference", reference="9:1"),               # no such surah
        P.request("r5", "c2", "tafsir", reference="1:1", book="mukhtasar"),
        P.request("r6", "c2", "hadith_search", text="نص")]})
    candidates, failures = await retrieve.gather(tools, requests)
    assert [(c["candidate_id"], c["request_id"], c["kind"]) for c in candidates] == [
        ("k1", "r1", "quran"), ("k2", "r6", "hadith")]
    assert candidates[0]["evidence"]["ar"]["quran"]["text_uthmani"] == P.synthetic.mushaf().get(2, 1).text_uthmani
    assert {f.request_id: f.outcome for f in failures} == {"r2": "not_found", "r3": "not_found", "r4": "not_found",
                                                           "r5": "not_found"}


async def test_hadith_citability_is_decided_by_code(tmp_path: Path) -> None:
    from app.factory import evidence as E
    weak = E.hadith_candidate(P.dorar_record(grade="ضعيف"), claim_id="c1", request_id="r1", tool="hadith_search")
    qualified = E.hadith_candidate(P.dorar_record(grade="إسناده صحيح"), claim_id="c1", request_id="r1",
                                   tool="hadith_search")
    gloss = E.hadith_candidate(P.dorar_record(text=P.HADITH_TEXT + " [يعني: تعليق]"), claim_id="c1",
                               request_id="r1", tool="hadith_search")
    sound = E.hadith_candidate(P.dorar_record(), claim_id="c1", request_id="r1", tool="hadith_search")
    assert (weak["citable"], qualified["citable"], sound["citable"]) == (False, False, True)
    assert weak["evidence"]["ar"] is None and "weak" in weak["not_citable_reason"]
    assert qualified["grade_category"] == "other"            # a ruling on the chain only goes to a specialist
    assert gloss["citable"] is False and "editorial gloss" in gloss["not_citable_reason"]
    card = E.plain_candidate(P.hadeethenc_record(), claim_id="c1", request_id="r1", tool="hadeethenc_hadith")
    assert card["citable"] is False and "Dorar" in card["not_citable_reason"]


def test_decomposition_rules() -> None:
    value = P.decompose({})
    value["claims"].append({"claim_id": "c3", "text_ar": "استدلال", "arc_step_id": "s9", "kind": "reasoning",
                            "basis": "reasoning", "reasoning_tool": "inference"})
    value["claims"].append({"claim_id": "c1", "text_ar": "مكرر", "arc_step_id": "s3", "kind": "factual",
                            "basis": "source", "reasoning_tool": "observation"})
    value["story_events"] = [{"event_id": "e1", "arc_step_id": "s3", "order": 1, "claim_id": "c2"}]
    errors = decompose.check(Decomposition.model_validate(value), plan())
    assert "duplicate claim id c1" in errors
    assert "c3: arc step s9 is not in the approved arc" in errors
    assert "c3: reasoning tool inference is not approved in the plan" in errors
    assert "c1: a source claim carries no reasoning tool" in errors
    assert "e1: story events belong to a sourced story step" in errors
    assert "s3: event order must run 0..n-1 without gaps" in errors


def test_localizable_leaves_exclude_evidence_ids_keys_and_media() -> None:
    evidence = {"evidence_id": "src_x", "kind": "quran", "hadith": None,
                "quran": {"text_uthmani": "نص", "surah_name": "اسم"}}
    block = {"block_id": "b1", "type": "teach", "eyebrow": "تمهيد", "title": [{"type": "text", "text": "عنوان"}],
             "style": "standard", "evidence": evidence,
             "visual": compose.placeholder_visual("run_x", "b1", "وصف"),
             "points": [{"point_id": "p1", "visual_params": None,
                         "sentence": {"sentence_id": "s_1", "source_ids": ["src_x"],
                                      "spans": [{"type": "text", "text": "جملة"}]}}]}
    exercise = {"exercise_id": "ex_1", "type": "multiple_choice", "answer_key": {"option_id": "o1"},
                "payload": {"options": [{"option_id": "o1", "spans": [{"type": "text", "text": "خيار"}]}]}}
    leaves = dict(compose.text_leaves({"blocks": [block], "exercise": exercise}))
    assert sorted(leaves.values()) == sorted(["تمهيد", "عنوان", "وصف", "جملة", "خيار"])
    english = compose.replace_leaves({"blocks": [block]}, {path: "EN" for path in leaves if path[0] == "blocks"})
    assert english["blocks"][0]["evidence"] == evidence and english["blocks"][0]["points"][0]["sentence"][
        "sentence_id"] == "s_1"


def test_term_linking_marks_the_first_use_only() -> None:
    blocks = [{"block_id": "b1", "type": "paragraph", "sentences": [
        {"sentence_id": "s_1", "source_ids": [], "spans": [{"type": "text", "text": "Patience matters."}]},
        {"sentence_id": "s_2", "source_ids": [], "spans": [{"type": "text", "text": "Again, patience."}]}]}]
    linked = compose.link_terms(blocks, [("term_1", "patience")], "en")
    assert linked[0]["sentences"][0]["spans"] == [{"type": "term", "text": "Patience", "term_id": "term_1"},
                                                  {"type": "text", "text": " matters."}]
    assert linked[0]["sentences"][1]["spans"] == [{"type": "text", "text": "Again, patience."}]
    assert blocks[0]["sentences"][0]["spans"] == [{"type": "text", "text": "Patience matters."}]   # input unchanged


def test_factory_code_never_calls_a_model_sdk_directly() -> None:
    """Every model call goes through ``app.llm`` (registry, policy, schemas, framing, accounting)."""
    for path in (BACKEND_DIR / "app" / "factory").rglob("*.py"):
        tree = ast.parse(path.read_text(encoding="utf-8"))
        for node in ast.walk(tree):
            names = [a.name for a in node.names] if isinstance(node, ast.Import) else \
                [node.module or ""] if isinstance(node, ast.ImportFrom) else []
            assert not any(n.split(".")[0] in ("anthropic", "openai", "httpx") for n in names), path
