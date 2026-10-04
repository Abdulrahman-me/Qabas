"""Unit 0 authoring records (``UNIT_0_CONTENT/lessons/u0_lNN.json``) -> gold lessons (D-40, factory §13.7).

The authoring package is the authoritative Unit 0 source: Arabic Explorer authoring with matched English, the
plan, claims, sentence roles and claim links, arc map, private keys, flashcards, pretest/unit-test/duel pools,
glossary and misconceptions. This converter projects it into the stored content schema mechanically and
blocks (never guesses) on what the record cannot supply:

* draft reasoning tools without an approved mapping to the contract's six (``reasoning_tool_unmapped``);
* plan text present in one language only (arc rationale, step experiences, tool justifications);
* concepts not registered in the curriculum graph (O-12);
* scripture or sourced stories awaiting verified insertion and provenance approval (Phase 9, O-05);
* scenes without published production media (O-13);
* an assertion placed where the contract carries plain spans, so its claim link would be lost.

Mechanical projections (decision D-82): two-digit authoring ids -> canonical slot ids (``les_u0_l1``), 1-based
numbers -> 0-based slot indices; ``learner_acts`` -> the contract's ``interactive`` (same meaning); inline
sentence roles -> the sentence map; claims keep the Arabic text (the authored language); misconception
``statement``/``correction`` -> title/card; glossary heading/definition/example -> ``StoredGlossaryTerm``; review
topic labels -> titles with stable ids. Authoring-only records (QA self-checks, visual briefs, specialist flags)
are not learner content: specialist flags travel in the gold provenance for the reviewer.
"""

from __future__ import annotations

import hashlib
import json
from collections.abc import Mapping
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import yaml
from pydantic import BaseModel, ConfigDict, ValidationError

from app.content.curriculum import CONTENT_DIR, Curriculum
from app.content.importers.report import Conversion
from app.content.package import LessonPackage
from app.contract import models as C

CONVERTER = "unit0_authoring/1"
MAPPING_PATH = CONTENT_DIR / "mappings" / "reasoning_tools.yaml"
CONTRACT_TOOLS = set(C.ReasoningTool.__args__)
SPAN_ONLY = {"hook": ("situation", "question"), "predict": ("reveal",), "callout": ("sentences",)}


class ToolMapping(BaseModel):
    model_config = ConfigDict(extra="forbid")

    schema_: str = "qabas.reasoning_tool_mapping/1"
    status: str
    approved_by: str | None = None
    approved_on: str | None = None
    mapping: dict[str, str | None]

    def resolve(self, tool: str) -> str | None:
        """The approved contract tool for a draft tool, or None while unapproved or unmapped."""
        if tool in CONTRACT_TOOLS:
            return tool
        if self.status != "approved" or not self.approved_by:
            return None
        target = self.mapping.get(tool)
        return target if target in CONTRACT_TOOLS else None


def load_mapping(path: Path = MAPPING_PATH) -> ToolMapping:
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    data["schema_"] = data.pop("schema")
    return ToolMapping.model_validate(data)


@dataclass(frozen=True)
class SceneMedia:
    """A published production scene version and its state-matched fallbacks (Phase 14 provides these)."""

    scene_ref: dict[str, Any]                  # contract SceneRef
    fallbacks: Mapping[str, dict[str, Any]]    # canonical params JSON -> contract Image

    def fallback(self, params: dict[str, Any]) -> dict[str, Any] | None:
        return self.fallbacks.get(json.dumps(params, sort_keys=True))


def canonical_id(number: str) -> tuple[str, int]:
    """``0.1`` -> (``les_u0_l1``, index 0)."""
    unit, position = number.split(".")
    return f"les_u{int(unit)}_l{int(position)}", int(position) - 1


def digest(record: dict[str, Any]) -> str:
    return hashlib.sha256(json.dumps(record, sort_keys=True, ensure_ascii=False).encode()).hexdigest()


class _Projector:
    def __init__(self, record: dict[str, Any], conversion: Conversion, *, mapping: ToolMapping,
                 concepts: set[str], scenes: Mapping[str, SceneMedia]) -> None:
        self.r, self.c, self.mapping, self.concepts, self.scenes = record, conversion, mapping, concepts, scenes
        self.roles: dict[str, dict[str, Any]] = {}
        self.sentence_claims: set[str] = set()
        self.flattened_claims: dict[str, set[str]] = {}

    # --- text --------------------------------------------------------------------------------------------

    def localized(self, value: Any, what: str) -> dict[str, str] | None:
        if isinstance(value, dict) and value.get("ar", "").strip() and value.get("en", "").strip():
            return {"ar": value["ar"], "en": value["en"]}
        self.c.block("plan_text_missing", f"{what} is not written in both Arabic and English")
        return None

    def sentence(self, s: dict[str, Any]) -> dict[str, Any]:
        entry = {"sentence_id": s["sentence_id"], "role": s["role"], "claim_ids": list(s.get("claim_ids", []))}
        previous = self.roles.setdefault(s["sentence_id"], entry)
        if previous != entry:
            self.c.block("record_invalid", f"sentence {s['sentence_id']} has different roles across languages")
        self.sentence_claims.update(entry["claim_ids"])
        return {"sentence_id": s["sentence_id"], "spans": s["spans"], "source_ids": list(s.get("source_ids", []))}

    def flatten(self, sentences: list[dict[str, Any]], where: str) -> list[dict[str, Any]]:
        """Sentences in a field the contract types as plain spans: their claim links cannot be carried there."""
        spans: list[dict[str, Any]] = []
        for n, s in enumerate(sentences):
            if n:
                spans.append({"type": "text", "text": " "})
            spans.extend(s["spans"])
            for claim_id in s.get("claim_ids", []):
                self.flattened_claims.setdefault(claim_id, set()).add(where)
        return spans

    def spans(self, value: list[dict[str, Any]], where: str) -> list[dict[str, Any]]:
        """Explanation text written either as spans or as sentences (both appear in the drafts)."""
        if value and "sentence_id" in value[0]:
            return self.flatten(value, where)
        return value

    @staticmethod
    def option_feedback(value: Any, payload: dict[str, Any]) -> list[dict[str, Any]]:
        """``[{option_id, spans}]`` or ``{option_id: spans}`` (both appear in the drafts) -> the contract list,
        in served option order."""
        if isinstance(value, dict):
            order = [o["option_id"] for o in payload.get("options", [])]
            return [{"option_id": o, "spans": value[o]} for o in order if o in value]
        return list(value or [])

    # --- visuals and evidence --------------------------------------------------------------------------

    def visual(self, v: dict[str, Any] | None, where: str) -> dict[str, Any] | None:
        if v is None:
            return None
        if v.get("kind") != "scene":
            return v  # built-in or image visuals already have the contract shape
        media = self.scenes.get(v["scene_id"])
        fallback = media.fallback(v.get("params") or {}) if media else None
        if media is None or fallback is None:
            self.c.block("scene_media_unpublished", f"{where}: scene {v['scene_id']} {v.get('params')} has no "
                                                    "published production version and state-matched fallback")
            return None
        return {"kind": "scene", "key": None, "version": None, "params": v.get("params"), "image": None,
                "scene": media.scene_ref, "fallback_image": fallback, "fallback_params": v.get("params"),
                "alt": v["alt"], "overlays": []}

    def evidence(self, e: dict[str, Any] | None, where: str) -> dict[str, Any] | None:
        if e is None:
            return None
        if e.get("insert_by_code") or "evidence_id" not in e:
            self.c.block("source_pending", f"{where}: {e.get('kind')} {e.get('ref')} awaits verified insertion")
            return None
        return e

    # --- blocks ----------------------------------------------------------------------------------------

    def block(self, b: dict[str, Any], lang: str) -> dict[str, Any] | None:
        where, kind = b["block_id"], b["type"]
        if kind == "hook":
            return {"block_id": where, "type": "hook", "situation": self.flatten(b["situation"], where),
                    "question": self.flatten(b["question"], where), "visual": self.visual(b["visual"], where),
                    "cta": b.get("cta")}
        if kind == "predict":
            return {"block_id": where, "type": "predict", "prompt": b["prompt"], "options": b["options"],
                    "reveal": self.flatten(b["reveal"], where), "visual": self.visual(b.get("visual"), where)}
        if kind == "callout":
            return {"block_id": where, "type": "callout", "variant": b["variant"],
                    "spans": self.flatten(b["sentences"], where)}
        if kind == "paragraph":
            return {"block_id": where, "type": "paragraph", "sentences": [self.sentence(s) for s in b["sentences"]]}
        if kind == "teach":
            return {"block_id": where, "type": "teach", "eyebrow": b.get("eyebrow"), "title": b["title"],
                    "style": b["style"], "visual": self.visual(b.get("visual"), where),
                    "evidence": self.evidence(b.get("evidence"), where),
                    "points": [{"point_id": p["point_id"], "sentence": self.sentence(p["sentence"]),
                                "visual_params": p.get("visual_params")} for p in b["points"]]}
        if kind == "story":
            if b.get("origin") is not None or b.get("provenance") is not None:
                reference = (b.get("provenance") or {}).get("reference")
                self.c.block("source_pending", f"{where}: sourced story ({reference}) awaits verified source records")
            return {"block_id": where, "type": "story", "label": b["label"], "title": b.get("title"),
                    "provenance": None, "origin": None,
                    "beats": [{"beat_id": beat["beat_id"], "beat_index": beat["beat_index"],
                               "narration": [self.sentence(s) for s in beat["narration"]],
                               "narration_audio_url": beat.get("narration_audio_url"),
                               "quote": self.evidence(beat.get("quote"), f"{where}/{beat['beat_id']}"),
                               "quote_meaning": beat.get("quote_meaning"),
                               "visual": self.visual(beat["visual"], f"{where}/{beat['beat_id']}")}
                              for beat in b["beats"]]}
        if kind == "exercise":
            return {"block_id": where, "type": "exercise", "exercise_id": b["exercise"]["exercise_id"]}
        if kind in ("evidence", "visual"):
            item = dict(b)
            item.pop("sentences", None)
            if kind == "evidence":
                item["evidence"] = self.evidence(b["evidence"], where)
            else:
                item["visual"] = self.visual(b["visual"], where)
            return item
        self.c.block("record_invalid", f"{where}: unknown block type {kind}")
        return None

    # --- exercises --------------------------------------------------------------------------------------

    @staticmethod
    def _learner(e: dict[str, Any], lang: str) -> dict[str, Any]:
        def pick(value: Any) -> Any:
            return value[lang] if isinstance(value, dict) and set(value) == {"ar", "en"} else value
        return {"exercise_id": e["exercise_id"], "type": e["type"], "concept_ids": e["concept_ids"],
                "prompt": pick(e["prompt"]), "time_limit_ms": e["time_limit_ms"], "scoring": e["scoring"],
                "framing": e["framing"], "payload": pick(e["payload"])}

    def lesson_exercises(self) -> list[dict[str, Any]]:
        keys = self.r["answer_keys"]
        by_lang = {lang: {b["exercise"]["exercise_id"]: b["exercise"]
                          for b in self.r["variants"][f"{lang}_explorer"]["blocks"] if b["type"] == "exercise"}
                   for lang in ("ar", "en")}
        records = []
        for exercise_id, ar in by_lang["ar"].items():
            en = by_lang["en"].get(exercise_id)
            key = keys.get(exercise_id)
            if en is None or key is None:
                self.c.block("record_invalid", f"{exercise_id}: missing English version or private key")
                continue
            exercise, feedback = {}, {}
            for lang, source in (("ar", ar), ("en", en)):
                exercise[lang] = {**self._learner(source, lang), "answer_key": key["correct_answer"],
                                  "option_misconceptions": key.get("option_misconceptions", {}),
                                  "duel_eligible": False}
                feedback[lang] = {"explanation": self.spans(source["explanation"], exercise_id),
                                  "option_feedback": self.option_feedback(source.get("option_feedback"),
                                                                          source["payload"]),
                                  "event_dates": source.get("event_dates", []),
                                  "pin_labels": source.get("pin_labels", [])}
            records.append({"exercise_id": exercise_id, "purpose": "lesson", "exercise": exercise,
                            "feedback": feedback, "targets_misconception_id": key.get("targets_misconception_id"),
                            "source_ids": []})
        return records

    @staticmethod
    def pool_key(item: dict[str, Any]) -> tuple[Any, dict[str, str]]:
        """The private key of a pool item. The drafts write it as ``correct_answer``, as ``answer_key``, or as
        ``answer_key: {correct_answer, option_misconceptions}`` (the lesson ``answer_keys`` shape)."""
        key = item.get("correct_answer", item.get("answer_key"))
        if isinstance(key, dict) and "correct_answer" in key:
            return key["correct_answer"], dict(key.get("option_misconceptions") or {})
        return key, dict(item.get("option_misconceptions") or {})

    def pool_exercises(self) -> list[dict[str, Any]]:
        pools = [("lesson", self.r["flashcards"], False), ("pretest", self.r["assessment_items"]["pretest"], False),
                 ("unit_test", self.r["assessment_items"]["unit_test"], False), ("duel", self.r["duel_items"], True)]
        records = []
        for purpose, items, duel in pools:
            for item in items:
                explanation = item.get("explanation") or {"ar": [], "en": []}
                key, option_misconceptions = self.pool_key(item)
                records.append({
                    "exercise_id": item["exercise_id"], "purpose": purpose,
                    "exercise": {lang: {**self._learner(item, lang), "answer_key": key,
                                        "option_misconceptions": option_misconceptions,
                                        "duel_eligible": duel} for lang in ("ar", "en")},
                    "feedback": {lang: {"explanation": self.spans(explanation[lang], item["exercise_id"])
                                        or item["payload"][lang].get("back", []),
                                        "option_feedback": self.option_feedback(
                                            (item.get("option_feedback") or {}).get(lang), item["payload"][lang]),
                                        "event_dates": [], "pin_labels": []} for lang in ("ar", "en")},
                    "targets_misconception_id": item.get("targets_misconception_id"), "source_ids": []})
        return records

    # --- the lesson -------------------------------------------------------------------------------------

    def plan(self) -> dict[str, Any]:
        p = self.r["plan"]
        arc = p["lesson_arc"]
        tools = []
        for use in p["reasoning_tools"]:
            target = self.mapping.resolve(use["tool"])
            if target is None:
                self.c.block("reasoning_tool_unmapped", f"plan tool {use['tool']}")
            tools.append({"tool": target or use["tool"],
                          "justification": self.localized(use["justification"], f"justification of {use['tool']}")})
        terms = {g["term_id"]: g["heading"] for g in self.r["glossary"]}
        misconceptions = {m["misconception_id"]: m for m in self.r["misconceptions"]}
        missing = [t for t in p["new_terms"] if t not in terms]
        missing += [m for m in p["target_misconceptions"] if m not in misconceptions]
        for ident in missing:
            self.c.block("record_invalid", f"plan names {ident}, which has no glossary or misconception record")
        for concept_id in [*p["introduced_concept_ids"], *p["prerequisite_concept_ids"]]:
            if concept_id not in self.concepts:
                self.c.block("concept_unregistered", concept_id)
        return {
            "title": p["title"], "central_question": p["central_question"],
            "primary_learning_outcome": p["primary_learning_outcome"],
            "supporting_understandings": p["supporting_understandings"], "depth_profile": p["depth_profile"],
            "objectives": p["objectives"], "prerequisite_concept_ids": p["prerequisite_concept_ids"],
            "introduced_concept_ids": p["introduced_concept_ids"],
            "new_terms": [terms[t] for t in p["new_terms"] if t in terms],
            "target_misconceptions": [{"misconception_id": m, "title": misconceptions[m]["statement"],
                                       "description": misconceptions[m]["correction"]}
                                      for m in p["target_misconceptions"] if m in misconceptions],
            "lesson_type": p["lesson_type"], "estimated_minutes": p["estimated_minutes"],
            "lesson_arc": {"pattern": arc["pattern"], "rationale": self.localized(arc["rationale"], "arc rationale"),
                           "steps": [{"step_id": s["step_id"], "technique": s["technique"],
                                      "experience": self.localized(s["experience"], f"arc step {s['step_id']}"),
                                      "interactive": s["learner_acts"]} for s in arc["steps"]]},
            "reasoning_tools": tools, "standalone_eligible": p["standalone_eligible"],
            "content_budget": p["content_budget"], "exercise_budget": p["exercise_budget"],
        }

    def claims(self) -> list[dict[str, Any]]:
        found = []
        for claim in self.r["claims"]:
            if claim["basis"] == "source":
                self.c.block("source_pending", f"claim {claim['claim_id']} ({claim.get('source_note', '')[:80]}) "
                                               "needs verified evidence records")
                continue
            reasoning = claim["reasoning"]
            target = self.mapping.resolve(reasoning["tool"])
            if target is None:
                self.c.block("reasoning_tool_unmapped", f"claim {claim['claim_id']} tool {reasoning['tool']}")
            found.append({"claim_id": claim["claim_id"], "text": claim["text"]["ar"], "status": "supported",
                          "basis": "reasoning", "evidence": [],
                          "reasoning": {"tool": target or reasoning["tool"], "premises": reasoning["premises"],
                                        "inference": reasoning["inference"]}})
        return found

    def variant(self, lang: str) -> dict[str, Any]:
        v = self.r["variants"][f"{lang}_explorer"]
        completion = v.get("completion")
        if completion is not None:
            completion = {"challenge": completion.get("challenge"), "check_in": completion.get("check_in"),
                          "review_topics": [{"topic_id": f"rt_{n + 1}", "concept_ids": t["concept_ids"],
                                             "title": "".join(s.get("text", "") for s in t["label"]).strip()}
                                            for n, t in enumerate(completion.get("review_topics", []))]}
        return {"title": v["title"], "subtitle": v.get("subtitle"), "objectives": v["objectives"],
                "blocks": [b for b in (self.block(b, lang) for b in v["blocks"]) if b is not None],
                "completion": completion}

    def package(self, lesson_id: str, unit_id: str, index: int) -> dict[str, Any]:
        variants = {"ar": {"explorer": self.variant("ar")}, "en": {"explorer": self.variant("en")}}
        plan = self.plan()
        claims = self.claims()
        exercises = self.lesson_exercises() + self.pool_exercises()
        for claim_id, places in sorted(self.flattened_claims.items()):
            if claim_id not in self.sentence_claims:
                self.c.block("claim_in_span_field", f"claim {claim_id} is asserted only in {sorted(places)}, "
                                                    "where the contract carries plain spans")
        steps = [s["step_id"] for s in self.r["plan"]["lesson_arc"]["steps"]]
        return {
            "lesson_id": lesson_id, "unit_id": unit_id, "index": index, "plan": plan, "variants": variants,
            "claims": claims, "sentence_map": list(self.roles.values()),
            "arc_map": [{"step_id": s, "block_ids": self.r["arc_map"].get(s, [])} for s in steps],
            "exercises": exercises,
            "glossary": [{"term_id": g["term_id"], "text": g["heading"], "arabic": g.get("arabic"),
                          "transliteration": g["transliteration"],
                          "definition": {"basic": {lang: [{"type": "text", "text": g["definition_basic"][lang]}]
                                                   for lang in ("ar", "en")}, "intermediate": None},
                          "example": {lang: [{"type": "text", "text": g["example"][lang]}] for lang in ("ar", "en")},
                          "concept_id": None, "lesson_id": lesson_id, "source_id": None,
                          "pronunciation_audio_url": None} for g in self.r["glossary"]],
            "misconceptions": [{"misconception_id": m["misconception_id"], "concept_id": None,
                                "title": m["statement"],
                                "card": {lang: [{"type": "text", "text": m["correction"][lang]}]
                                         for lang in ("ar", "en")}, "source_ids": []}
                               for m in self.r["misconceptions"]],
            "sources": [],
        }


def convert(record: dict[str, Any], curriculum: Curriculum, *, mapping: ToolMapping,
            scenes: Mapping[str, SceneMedia]) -> Conversion:
    """Project one authoring record; ``package`` is set only when nothing blocks it."""
    try:
        lesson_id, index = canonical_id(record["number"])
    except (KeyError, ValueError):
        conversion = Conversion(str(record.get("lesson_id", "?")))
        conversion.block("record_invalid", "the record has no curriculum number like 0.1")
        return conversion
    conversion = Conversion(lesson_id)
    slot = next(((u, i, s) for u, i, s in curriculum.slots() if s.lesson_id == lesson_id), None)
    if slot is None or slot[0].unit_id != record.get("unit_id") or slot[1] != index:
        conversion.block("record_invalid", f"{record.get('lesson_id')} ({record.get('number')}) is not curriculum "
                                           f"slot {lesson_id}")
        return conversion
    concepts = {c.concept_id for c in curriculum.concepts}
    projector = _Projector(record, conversion, mapping=mapping, concepts=concepts, scenes=scenes)
    try:
        data = projector.package(lesson_id, slot[0].unit_id, index)
    except (KeyError, TypeError) as exc:
        conversion.block("record_invalid", f"unexpected authoring shape: {exc!r}")
        return conversion
    flags = record.get("flags_for_specialist", [])
    conversion.notes = [f"specialist flag: {flag}" for flag in flags]
    if conversion.blockers:
        return conversion
    try:
        conversion.package = LessonPackage.model_validate(data).model_dump(mode="json")
    except ValidationError as exc:
        for error in exc.errors()[:30]:
            conversion.block("record_invalid", f"{'.'.join(str(p) for p in error['loc'])}: {error['msg']}")
    return conversion


def load_records(lessons_dir: Path) -> list[dict[str, Any]]:
    return [json.loads(p.read_text(encoding="utf-8")) for p in sorted(lessons_dir.glob("u0_l*.json"))]
