"""Synthetic sources and a scripted model for the full factory pipeline (no live calls, no religious content).

The "Qur'an" is the synthetic mushaf of ``tests.sources.synthetic`` (neutral sentences, never scripture); the
"hadith" records are neutral test sentences shaped like Dorar and HadeethEnc records. Every model answer is built
from the ids the stage actually received (claim ids, candidate ids, evidence keys, slots, text-leaf ids), the way a
real model would have to, so the code checks between stages are exercised exactly as in production.
"""

from __future__ import annotations

import copy
from collections.abc import Callable, Sequence
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import yaml

from app.config import Settings
from app.sources.errors import ProviderNotConfigured, RecordNotFound, UpstreamUnavailable
from app.sources.records import Part, Retrieval, SourceRecord, sha256_text, utcnow
from app.sources.scripture import TRANSLATIONS, ScriptureBindings, prepare_references
from tests.sources import synthetic

HADITH_TEXT = "نص تجريبي محايد بصيغة سجل حديث لأغراض الاختبار فقط"
TERM_AR = "نص تجريبي term"


def manifest(tmp_path: Path) -> Path:
    path = tmp_path / "translations.yaml"
    path.write_text(yaml.safe_dump({"schema": "qabas.quran_translations/1", "status": "approved",
                                    "approved_by": "test specialist", "approved_on": "2026-10-05",
                                    "languages": {"en": {"key": "fixture_key", "version": "1"}}}), encoding="utf-8")
    return path


def _retrieval(tool: str, arguments: dict[str, Any]) -> Retrieval:
    return Retrieval(tool, tool.split(".")[-1], arguments, {"synthetic": True}, sha256_text(repr(arguments)), utcnow())


def dorar_record(record_id: str = "syn1", *, grade: str = "صحيح", text: str = HADITH_TEXT) -> SourceRecord:
    return SourceRecord(
        "dorar", record_id, "hadith", "كتاب تجريبي", "كتاب تجريبي (1)", text, f"https://dorar.net/h/{record_id}",
        "dorar/1", _retrieval("dorar.search", {"value": "synthetic"}),
        (Part("text_authority", "dorar", record_id), Part("grade", "dorar", record_id)),
        {"narrator": "راوٍ تجريبي", "grader": "محدث تجريبي", "book": "كتاب تجريبي", "number_or_page": "1",
         "grade_label": grade, "grade_category": "other", "editorial_brackets": "[" in text})


def hadeethenc_record(record_id: str = "syn1", *, text_ar: str = HADITH_TEXT) -> SourceRecord:
    return SourceRecord(
        "hadeethenc", f"{record_id}:en", "hadith", "Synthetic card", "Synthetic attribution",
        "Synthetic English rendering of the neutral test record", f"https://hadeethenc.com/en/browse/hadith/{record_id}",
        "hadeethenc/1", _retrieval("hadeethenc.get", {"id": record_id, "language": "en"}),
        (Part("text_authority", "hadeethenc", f"{record_id}:ar"), Part("translation", "hadeethenc", f"{record_id}:en")),
        {"language": "en", "text_ar": text_ar, "grade_source": "HadeethEnc"})


class Translator:
    """A QuranEnc stand-in over the synthetic mushaf (approved test manifest only)."""

    async def translation(self, surah: int, ayah: int, key: str, language: str) -> SourceRecord:
        canonical = synthetic.mushaf().get(surah, ayah)
        return SourceRecord("quranenc", f"{key}:{surah}:{ayah}", "quran", "Synthetic translation", f"{surah}:{ayah}",
                            f"Neutral translation sentence {surah}:{ayah}", None, "quranenc/1",
                            _retrieval("quranenc.translation", {"surah": surah, "ayah": ayah}),
                            (Part("translation", "quranenc", f"{key}:{surah}:{ayah}", version="1"),),
                            {"language": "en", "translation_key": key, "translation_version": "1",
                             "arabic_text": canonical.text_uthmani})


@dataclass
class SyntheticTools:
    translations: Path | None = None              # an approved test manifest, or the production (pending) one
    hadith: list[SourceRecord] = field(default_factory=lambda: [dorar_record()])
    not_configured: set[str] = field(default_factory=set)
    outages: list[str] = field(default_factory=list)   # tools that fail once with an outage, in order
    calls: list[str] = field(default_factory=list)
    closed: int = 0

    def __post_init__(self) -> None:
        self.mushaf = synthetic.mushaf()

    def _enter(self, tool: str) -> None:
        self.calls.append(tool)
        if tool in self.not_configured:
            raise ProviderNotConfigured(tool, "not approved in this environment (O-03)")
        if self.outages and self.outages[0] == tool:
            self.outages.pop(0)
            raise UpstreamUnavailable(tool, "timeout")

    async def scripture(self, references: Sequence[str]) -> ScriptureBindings:
        self._enter("scripture")
        return await prepare_references(self.mushaf, references, Settings(), translator=Translator(),
                                        translation_manifest=self.translations or TRANSLATIONS)

    async def hadith_search(self, text: str) -> list[SourceRecord]:
        self._enter("dorar")
        return list(self.hadith)

    async def hadeethenc(self, hadith_id: str, language: str) -> SourceRecord:
        self._enter("hadeethenc")
        if hadith_id != "syn1":
            raise RecordNotFound("hadeethenc", "no such card")
        return hadeethenc_record()

    async def islamhouse(self, item_id: str, language: str) -> SourceRecord:
        self._enter("islamhouse")
        raise RecordNotFound("islamhouse", "no such item")

    async def tafsir(self, surah: int, ayah: int, book: str) -> SourceRecord:
        self._enter("tafsir_center")
        raise RecordNotFound("tafsir_center", "no such entry")

    async def aclose(self) -> None:
        self.closed += 1


# ------------------------------------------------------------------------------------------- model answers

def decompose(data: dict[str, Any]) -> dict[str, Any]:
    return {"claims": [
        {"claim_id": "c1", "text_ar": "ادعاء تجريبي أول", "arc_step_id": "s3", "kind": "factual", "basis": "source",
         "reasoning_tool": None},
        {"claim_id": "c2", "text_ar": "ادعاء تجريبي ثان", "arc_step_id": "s3", "kind": "religious",
         "basis": "source", "reasoning_tool": None}], "story_events": [], "issues": []}


def request(rid: str, claim: str, tool: str, **fields: Any) -> dict[str, Any]:
    base = {"request_id": rid, "claim_id": claim, "tool": tool, "reference": None, "text": None, "book": None,
            "item_id": None, "language": None}
    return base | fields


def retrieve(data: dict[str, Any]) -> dict[str, Any]:
    return {"requests": [request("r1", "c1", "quran_reference", reference="1:1"),
                         request("r2", "c2", "hadith_search", text="نص تجريبي"),
                         request("r3", "c2", "hadeethenc_hadith", item_id="syn1", language="en")], "issues": []}


def review(fit: str = "exact", concerns: list[str] | None = None) -> dict[str, Any]:
    return {"fit": fit, "concerns": concerns or [], "note": "synthetic review"}


def verify(data: dict[str, Any], *, weak_supports: bool = False) -> dict[str, Any]:
    verdicts = []
    for claim in data["claims"]:
        judged = []
        for candidate in data["candidates"]:
            if candidate["claim_id"] != claim["claim_id"]:
                continue
            supports = candidate["citable"] or weak_supports
            concerns = ["needs_tafsir"] if candidate["kind"] == "hadith" and supports else []
            judged.append({"candidate_id": candidate["candidate_id"], "supports": supports,
                           "verifier_note": "synthetic entailment note",
                           "semantic_review": review("partial" if concerns else "exact", concerns)
                           if supports else None})
        status = "supported" if any(j["supports"] for j in judged) else "dropped"
        verdicts.append({"claim_id": claim["claim_id"], "status": status, "evidence": judged, "reasoning": None})
    return {"claims": verdicts, "issues": []}


def sentence(sid: str, text: str, role: str, claims: Sequence[str] = ()) -> dict[str, Any]:
    return {"sentence_id": sid, "text": text, "role": role, "claim_ids": list(claims)}


def write(data: dict[str, Any], **changes: Any) -> dict[str, Any]:
    keys = {e["kind"]: e["evidence_id"] for e in data["evidence"]}
    blocks = [
        {"block_id": "b_hook", "type": "hook", "situation": "موقف يومي تجريبي", "question": "سؤال تجريبي؟",
         "cta": None, "visual_brief": "a neutral synthetic scene"},
        {"block_id": "b_story", "type": "story", "label": "موقف", "title": None, "sourced": False,
         "origin_title": None, "beats": [
             {"beat_id": "beat1", "narration": [sentence("s_sc1", "تخيل موقفا تجريبيا", "hypothetical")],
              "quote_evidence_id": None, "quote_meaning": None, "visual_brief": "beat one"},
             {"beat_id": "beat2", "narration": [sentence("s_sc2", "ماذا تلاحظ هنا؟", "question")],
              "quote_evidence_id": None, "quote_meaning": None, "visual_brief": "beat two"}]},
        {"block_id": "b_predict", "type": "predict", "prompt": "ماذا تتوقع؟", "reveal": "كشف تجريبي",
         "options": [{"option_id": "o_a", "text": "أ"}, {"option_id": "o_b", "text": "ب"}], "visual_brief": None},
        {"block_id": "b_teach", "type": "teach", "eyebrow": None, "title": "عنوان تجريبي", "style": "standard",
         "evidence_id": keys["quran"], "visual_brief": None, "points": [
             {"point_id": "p1", "sentence": sentence("s_t1", "جملة تجريبية تدعمها الأدلة", "claim", ["c1"])},
             {"point_id": "p2", "sentence": sentence("s_t2", f"يسمى هذا {TERM_AR} في الدرس", "claim", ["c2"])}]},
        {"block_id": "b_ev", "type": "evidence", "evidence_id": keys["hadith"], "caption": "تعليق تجريبي"},
        {"block_id": "b_x1", "type": "exercise_slot", "intent": "recognise the idea"},
        {"block_id": "b_x2", "type": "exercise_slot", "intent": "apply the idea"},
        {"block_id": "b_x3", "type": "exercise_slot", "intent": "order the steps"},
        {"block_id": "b_sum", "type": "teach", "eyebrow": None, "title": "خلاصة", "style": "summary",
         "evidence_id": None, "visual_brief": None, "points": [
             {"point_id": "q1", "sentence": sentence("s_sum1", "خلاصة تجريبية", "claim", ["c1"])},
             {"point_id": "q2", "sentence": sentence("s_sum2", "انتقل إلى التطبيق", "instruction")}]},
    ]
    completion = {"challenge": "تحد صغير تجريبي", "check_in": "سؤال مراجعة تجريبي",
                  "review_topics": [{"topic_id": "rt1", "title": "موضوع", "concept_ids": ["con_t2_1"]}]}
    variants = [{"variant": v, "title": f"عنوان {v}", "subtitle": None, "blocks": copy.deepcopy(blocks),
                 "completion": completion} for v in data["variants_to_write"]]
    arc = [{"step_id": "s1", "block_ids": ["b_hook", "b_story"]}, {"step_id": "s2", "block_ids": ["b_predict"]},
           {"step_id": "s3", "block_ids": ["b_teach", "b_ev", "b_x1"]},
           {"step_id": "s4", "block_ids": ["b_x2", "b_x3"]}, {"step_id": "s5", "block_ids": ["b_sum"]}]
    return {"variants": variants, "arc_map": arc, "issues": []} | changes


def option(oid: str, text: str, *, misconception: str | None = None, feedback: str | None = None) -> dict[str, Any]:
    return {"option_id": oid, "text": text, "misconception_id": misconception, "feedback": feedback}


EMPTY = {"slot_block_id": None, "layer": "understand", "myth_statement": None, "targets_misconception_id": None,
         "evidence_ids": [], "statement": None, "correct_value": None, "situation": None, "options": None,
         "correct_option_id": None, "pairs": None, "categories": None, "items": None, "steps": None,
         "segments": None, "words": None, "evidence_option_ids": None, "verse_evidence_id": None, "front": None,
         "back": None}


def item(xid: str, purpose: str, kind: str, **fields: Any) -> dict[str, Any]:
    return {"exercise_id": xid, "purpose": purpose, "type": kind, "concept_ids": ["con_t2_1"],
            "prompt": f"سؤال {xid}", "explanation": f"شرح {xid}"} | EMPTY | fields


def exercises(data: dict[str, Any]) -> dict[str, Any]:
    keys = {e["kind"]: e["evidence_id"] for e in data["evidence"]}
    slots = [s["slot_block_id"] for s in data["slots"]]
    two = [option("o_a", "صحيح هنا"), option("o_b", "خطأ هنا")]
    return {"exercises": [
        item("x1", "lesson", "true_false_reason", slot_block_id=slots[0], statement="عبارة تجريبية",
             correct_value=True, options=two, correct_option_id="o_a", myth_statement="فكرة خاطئة شائعة تجريبية",
             targets_misconception_id="new_1"),
        item("x2", "lesson", "scenario", slot_block_id=slots[1], layer="apply", situation="موقف تطبيقي",
             options=[option("o_a", "اختيار صحيح", feedback="لأن..."),
                      option("o_b", "اختيار خاطئ", misconception="new_1", feedback="لأن..."),
                      option("o_c", "اختيار ثالث", feedback="لأن...")], correct_option_id="o_a"),
        item("x3", "lesson", "order_steps", slot_block_id=slots[2], layer="apply",
             steps=[option("o_1", "خطوة أولى"), option("o_2", "خطوة ثانية"), option("o_3", "خطوة ثالثة")]),
        item("x4", "lesson", "flashcard", layer=None, front="وجه البطاقة", back="ظهر البطاقة"),
        item("x5", "pretest", "which_evidence", statement="ادعاء للاختبار",
             evidence_option_ids=[keys["quran"], keys["hadith"]], correct_option_id=keys["quran"]),
        item("x6", "pretest", "categorize", categories=[{"category_id": "k_a", "label": "فئة أ"},
                                                        {"category_id": "k_b", "label": "فئة ب"}],
             items=[{"item_id": f"i{n}", "text": f"عنصر {n}", "category_id": "k_a" if n % 2 else "k_b"}
                    for n in range(1, 5)]),
        item("x7", "unit_test", "match_pairs", pairs=[{"left_id": f"l{n}", "left": f"يسار {n}", "right_id": f"r{n}",
                                                      "right": f"يمين {n}"} for n in range(1, 4)]),
        item("x8", "unit_test", "fill_blank", segments=[
            {"kind": "text", "text": "جملة", "blank_id": None}, {"kind": "blank", "text": None, "blank_id": "f1"},
            {"kind": "text", "text": "ثم", "blank_id": None}, {"kind": "blank", "text": None, "blank_id": "f2"}],
             words=[{"word_id": "w_a", "text": "كلمة1", "fills_blank_id": "f1"},
                    {"word_id": "w_b", "text": "كلمة2", "fills_blank_id": "f2"},
                    {"word_id": "w_c", "text": "كلمة3", "fills_blank_id": None}]),
        item("x9", "unit_test", "spot_error", steps=[option("o_g1", "مقطع سليم"), option("o_g2", "مقطع فيه خطأ")],
             correct_option_id="o_g2"),
        item("x10", "duel", "multiple_choice", options=[option("o_a", "أ"), option("o_b", "ب"), option("o_c", "ج")],
             correct_option_id="o_b"),
        item("x11", "duel", "true_false", statement="عبارة سريعة", correct_value=False),
        item("x12", "duel", "verse_meaning", verse_evidence_id=keys["quran"], options=two, correct_option_id="o_a"),
    ], "misconceptions": [{"misconception_id": "new_1", "concept_id": "con_t2_1", "title": "فكرة خاطئة",
                           "card": "بطاقة تصحيح تجريبية"}], "issues": []}


def glossary(data: dict[str, Any]) -> dict[str, Any]:
    return {"terms": [{"term_id": "t1", "text_ar": data["new_terms"][0]["ar"], "arabic": None,
                       "transliteration": "synthetic", "basic_ar": "تعريف تجريبي", "intermediate_ar": None,
                       "example_ar": f"مثال على {TERM_AR}", "concept_id": "con_t2_1"}], "issues": []}


def localize(data: dict[str, Any]) -> dict[str, Any]:
    return {"texts": [{"id": t["id"], "text": f"Synthetic English for {t['id']}"} for t in data["texts"]],
            "issues": []}


def qa_review(data: dict[str, Any]) -> dict[str, Any]:
    return {"issues": []}


def pedagogy_review(data: dict[str, Any]) -> dict[str, Any]:
    return {"issues": [{"severity": "warning", "kind": "pedagogy", "sentence_id": "s_t1", "exercise_id": None,
                        "message": "synthetic pedagogy finding"}]}


def script(**overrides: Callable[[dict[str, Any]], dict[str, Any]] | dict[str, Any]) -> dict[str, Any]:
    from tests.factory.support import plan
    answers: dict[str, Any] = {"factory_plan": plan(), "factory_decompose": decompose,
                               "factory_retrieve": retrieve, "factory_verify": verify, "factory_write": write,
                               "factory_exercises": exercises, "factory_glossary": glossary,
                               "factory_localize": localize, "factory_qa": qa_review,
                               "factory_pedagogy": pedagogy_review}
    answers.update(overrides)
    return answers
