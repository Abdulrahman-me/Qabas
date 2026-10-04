"""The Salah reference export (reply8 ``reference_export``) -> gold lesson (factory §13.7, SEED_AND_IMPORT).

The frontend's exporter reproduces the prototype lesson 1:1: four session candidates (ar/en x explorer/new
muslim) with all 14 steps, canonical Arabic terms and captured bank order, plus private keys, explanations and
misconception cards (``salah-01.gold-candidate.json``) and the stored glossary. Factory §13.7.2 then requires
what the prototype does not contain: the plan, claims, sentence roles, arc map, misconception records and
mappings, flashcards and the assessment and duel items, all specialist-reviewed. Those are new religious
teaching content and are **not authored by the converter** (decision D-83): they arrive in a
:class:`Completion` record written by the content team. The production slot (as-is at 3.2, adapted or merged)
is product decision P-07 and is part of that record.

The converter projects the export mechanically (``_mock_*`` markers stripped, ids kept, the fixture identity
``les_u1_l3`` replaced by the completion record's slot) and blocks on: a missing completion record, the
unavailable licensed recitation clip (O-06), source text copied from the prototype rather than verified
(O-05, Phase 9), and the export's own publication blockers.
"""

from __future__ import annotations

import copy
import json
from collections.abc import Mapping
from pathlib import Path
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field, ValidationError

from app.content.curriculum import Curriculum
from app.content.importers.report import Conversion
from app.content.package import ExerciseRecord, LessonPackage, MisconceptionRecord, SourceRecord
from app.contract import models as C

CONVERTER = "salah_reference/1"
FIXTURE_LESSON = "les_u1_l3"
VARIANTS = (("ar", "explorer"), ("ar", "new_muslim"), ("en", "explorer"), ("en", "new_muslim"))
LEARNER_FIELDS = ("exercise_id", "type", "concept_ids", "prompt", "time_limit_ms", "scoring", "framing", "payload")


class VerifiedSource(BaseModel):
    """A source record re-verified against its provider (Phase 9 adapters) and approved by a specialist."""

    model_config = ConfigDict(extra="forbid")

    record: SourceRecord
    provider_record_id: str = Field(min_length=1)
    verified_by: str = Field(min_length=1)


class FeedbackExtras(BaseModel):
    model_config = ConfigDict(extra="forbid")

    option_feedback: list[C.OptionFeedback] = []
    event_dates: list[C.EventDate] = []
    pin_labels: list[C.PinLabel] = []


class Completion(BaseModel):
    """Everything §13.7.2 adds to the 1:1 export, written by the content team and specialist-reviewed."""

    model_config = ConfigDict(extra="forbid", populate_by_name=True)

    schema_: Literal["qabas.salah_completion/1"] = Field(alias="schema")
    target_lesson_id: str            # the P-07 decision, e.g. les_u3_l2
    decided_by: str = Field(min_length=1)
    plan: C.LessonPlan
    claims: list[C.Claim]
    sentence_map: list[C.SentenceClaims]
    arc_map: list[C.ArcStepBlocks]
    misconceptions: list[MisconceptionRecord]
    option_misconceptions: dict[str, dict[str, str]]   # exercise_id -> {option_id: misconception_id}
    targets: dict[str, str]                            # exercise_id -> targeted misconception_id
    # Per lesson exercise and language: scenario option feedback, timeline event dates, map pin labels the
    # prototype does not contain (the export carries only keys, explanations and misconception cards).
    feedback: dict[str, dict[str, FeedbackExtras]] = {}
    exercise_sources: dict[str, list[str]] = {}         # exercise_id -> sources its feedback cites
    exercises: list[ExerciseRecord]                    # flashcards, pretest, unit-test and duel items
    sources: list[VerifiedSource]
    recitation_audio: dict[str, Any] | None = None     # licensed clip with word timings (O-06)


def _strip_mock(node: Any) -> Any:
    if isinstance(node, dict):
        return {k: _strip_mock(v) for k, v in node.items() if not k.startswith("_mock")}
    if isinstance(node, list):
        return [_strip_mock(v) for v in node]
    return node


def load_export(export_dir: Path) -> dict[str, Any]:
    sessions = {f"{lang}_{track}": _strip_mock(json.loads(
        (export_dir / f"session_salah_{lang}_{track}.json").read_text(encoding="utf-8"))) for lang, track in VARIANTS}
    gold = json.loads((export_dir / "salah-01.gold-candidate.json").read_text(encoding="utf-8"))
    glossary = json.loads((export_dir / "stored_glossary.json").read_text(encoding="utf-8"))
    return {"sessions": sessions, "gold": gold, "glossary": glossary}


def variants_and_exercises(export: Mapping[str, Any]) -> tuple[dict[str, Any], dict[str, dict[str, Any]]]:
    """Variant contents with exercise references, and the lesson exercises' learner fields, keys and feedback
    per language, exactly as exported."""
    variants: dict[str, dict[str, Any]] = {"ar": {}, "en": {}}
    exercises: dict[str, dict[str, Any]] = {}
    private = export["gold"]["variants"]
    for lang, track in VARIANTS:
        session = export["sessions"][f"{lang}_{track}"]
        keys = private[f"{lang}_{track}"]["private_exercises"]
        blocks = []
        for block in session["items"]:
            if block["type"] != "exercise":
                blocks.append(copy.deepcopy(block))
                continue
            learner = block["exercise"]
            blocks.append({"block_id": block["block_id"], "type": "exercise", "exercise_id": learner["exercise_id"]})
            entry = exercises.setdefault(learner["exercise_id"], {"exercise": {}, "feedback": {}, "card": {}})
            key = keys.get(learner["exercise_id"], {})
            entry["exercise"][lang] = {**{f: learner[f] for f in LEARNER_FIELDS}, "answer_key": key.get("answer_key")}
            entry["feedback"][lang] = {"explanation": key.get("explanation") or [],
                                       "option_feedback": [], "event_dates": [], "pin_labels": []}
            entry["card"][lang] = key.get("misconception_card")
        variants[lang][track] = {"title": session["title"], "subtitle": session["subtitle"],
                                 "objectives": session["objectives"], "blocks": blocks,
                                 "completion": session["completion"]}
    return variants, exercises


def served_items(variants: Mapping[str, Any], exercises: Mapping[str, Any], lang: str,
                 track: str) -> list[dict[str, Any]]:
    """The items a session would serve from the projection (used to prove the projection is lossless)."""
    return [{"block_id": b["block_id"], "type": "exercise",
             "exercise": {f: exercises[b["exercise_id"]]["exercise"][lang][f] for f in LEARNER_FIELDS}}
            if b["type"] == "exercise" else b for b in variants[lang][track]["blocks"]]


def convert(export: Mapping[str, Any], curriculum: Curriculum, completion: Completion | None) -> Conversion:
    conversion = Conversion(completion.target_lesson_id if completion else FIXTURE_LESSON)
    for blocker in export["gold"].get("publication_blockers", []):
        code = ("media_unavailable" if "reciter" in blocker or "timings" in blocker
                else "source_pending" if "scripture" in blocker or "source" in blocker
                else "reference_acceptance" if "playback" in blocker
                else "completion_record_missing")
        conversion.block(code, f"reference export: {blocker}")
    variants, exercises = variants_and_exercises(export)
    for (lang, track) in VARIANTS:
        for block in export["sessions"][f"{lang}_{track}"]["items"]:
            payload = block.get("exercise", {}).get("payload", {}) if block["type"] == "exercise" else {}
            audio = (payload.get("audio") or {}).get("url", "") if isinstance(payload.get("audio"), dict) else ""
            if audio.startswith("unavailable://"):
                conversion.block("media_unavailable", f"{block['block_id']}: recitation clip {audio}")
    if completion is None:
        conversion.block("completion_record_missing",
                         "no completion record: plan, claims, sentence roles, arc map, misconception records and "
                         "mappings, flashcards, pretest/unit-test/duel items and verified sources")
        conversion.block("curriculum_placement", "production slot for the Salah reference (P-07)")
        return conversion
    slot = next(((u, i, s) for u, i, s in curriculum.slots() if s.lesson_id == completion.target_lesson_id), None)
    if slot is None:
        conversion.block("curriculum_placement", f"{completion.target_lesson_id} is not a curriculum slot")
        return conversion
    if conversion.blockers:
        return conversion
    records = []
    for exercise_id, entry in exercises.items():
        maps = completion.option_misconceptions.get(exercise_id, {})
        extras = completion.feedback.get(exercise_id, {})
        feedback = {lang: {**entry["feedback"][lang], **(extras[lang].model_dump(mode="json") if lang in extras
                                                         else {})} for lang in ("ar", "en")}
        records.append({"exercise_id": exercise_id, "purpose": "lesson",
                        "exercise": {lang: {**entry["exercise"][lang], "option_misconceptions": maps,
                                            "duel_eligible": False} for lang in ("ar", "en")},
                        "feedback": feedback, "targets_misconception_id": completion.targets.get(exercise_id),
                        "source_ids": list(completion.exercise_sources.get(exercise_id, []))})
    data = {
        "lesson_id": completion.target_lesson_id, "unit_id": slot[0].unit_id, "index": slot[1],
        "plan": completion.plan.model_dump(mode="json"), "variants": variants,
        "claims": [c.model_dump(mode="json") for c in completion.claims],
        "sentence_map": [s.model_dump(mode="json") for s in completion.sentence_map],
        "arc_map": [a.model_dump(mode="json") for a in completion.arc_map],
        "exercises": records + [e.model_dump(mode="json") for e in completion.exercises],
        "glossary": [{**g, "lesson_id": completion.target_lesson_id if g.get("lesson_id") == FIXTURE_LESSON
                      else g.get("lesson_id")} for g in export["glossary"]],
        "misconceptions": [m.model_dump(mode="json") for m in completion.misconceptions],
        "sources": [s.record.model_dump(mode="json") for s in completion.sources],
    }
    try:
        conversion.package = LessonPackage.model_validate(data).model_dump(mode="json")
    except ValidationError as exc:
        for error in exc.errors()[:30]:
            conversion.block("record_invalid", f"{'.'.join(str(p) for p in error['loc'])}: {error['msg']}")
    return conversion
