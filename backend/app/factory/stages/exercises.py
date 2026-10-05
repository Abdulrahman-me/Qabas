"""Stage 6 ``exercises`` — Exercise Designer and selection (factory §13.1 stage 6, §13.3 exercise rules).

The designer writes typed Arabic items; code turns each into the contract ``ReviewerExercise`` with its private
answer key and checks everything checkable: one graded item per writer slot (= the plan's exercise budget), 2
pretest + 3 unit-test + 3 duel items, a flashcard for every concept taught, type preconditions (``which_evidence``
offers verified sources only; ``verse_meaning`` uses a Qur'an source displayed in the lesson), concepts the lesson
teaches or requires, misconception mappings with cards, and payload sizes.

Ids are minted by code and are opaque: options, items, steps, words and blanks are numbered by their *served*
position, and ordered banks are served rotated from the key order, so neither an id nor the public order spells
out the private answer (D-42). ``recite_verse`` and ``map_place`` need the media pipeline (Phase 14, O-06) and
``timeline_order`` dated event sources, so the designer is not offered them yet.
"""

from __future__ import annotations

from collections import Counter
from typing import Any

from pydantic import ValidationError
from sqlalchemy import select

from app.contract import models as C
from app.factory import compose
from app.factory.orchestrator import StageContext, StageResult
from app.factory.stage_models import ExerciseSet, XExercise
from app.factory.stages.common import accepted, approved_plan, duplicates, key_of, parse, require
from app.models import Misconception

ASSESSMENT = {"pretest": 2, "unit_test": 3, "duel": 3}
DUEL_TYPES = ("multiple_choice", "true_false", "verse_meaning")
NOT_ASSESSMENT = ("flashcard",)


def _rotate(values: list[Any]) -> list[Any]:
    return values[1:] + values[:1] if len(values) > 1 else list(values)


class Builder:
    """Converts one designer item into the stored Arabic exercise (reviewer projection + feedback)."""

    def __init__(self, exercise_id: str, x: XExercise, registry: dict[str, dict[str, Any]],
                 displayed: set[str], misconception_id: Any) -> None:
        self.id, self.x, self.registry, self.displayed = exercise_id, x, registry, displayed
        self.misconception_id = misconception_id
        self.errors: list[str] = []
        self.option_misconceptions: dict[str, str] = {}
        self.option_feedback: list[dict[str, Any]] = []
        self.sources: list[str] = []

    def need(self, condition: bool, message: str) -> bool:
        if not condition:
            self.errors.append(f"{self.x.exercise_id} ({self.x.type}): {message}")
        return condition

    def options(self, *, feedback: bool = False) -> tuple[list[dict[str, Any]], str | None]:
        options = self.x.options or []
        if not self.need(2 <= len(options) <= 4, "2-4 options"):
            return [], None
        if not self.need(not duplicates([o.option_id for o in options]), "option ids are unique"):
            return [], None
        served, correct = [], None
        for index, option in enumerate(options, start=1):
            opaque = f"o{index}"
            served.append({"option_id": opaque, "spans": compose.span(option.text)})
            if option.option_id == self.x.correct_option_id:
                correct = opaque
            if option.misconception_id:
                mapped = self.misconception_id(option.misconception_id)
                if self.need(mapped is not None, f"option {option.option_id} maps unknown misconception "
                                                 f"{option.misconception_id}"):
                    self.option_misconceptions[opaque] = mapped
            if feedback and self.need(bool(option.feedback), "a scenario has feedback for every option"):
                self.option_feedback.append({"option_id": opaque, "spans": compose.span(option.feedback or "")})
        self.need(correct is not None, "correct_option_id names one of its options")
        if correct is not None and correct in self.option_misconceptions:
            self.errors.append(f"{self.x.exercise_id}: the correct option cannot represent a misconception")
        return served, correct

    def evidence(self, key: str | None, *, quran_displayed: bool = False) -> dict[str, Any] | None:
        item = self.registry.get(key or "")
        if not self.need(item is not None, f"evidence {key} is not in the verified evidence registry"):
            return None
        assert item is not None
        if quran_displayed:
            self.need(item["kind"] == "quran" and key in self.displayed,
                      "verse_meaning uses a Qur'an source displayed in this lesson")
        self.sources.append(item["source_id"])
        value: dict[str, Any] = item["evidence"]["ar"]
        return value

    def payload(self) -> tuple[dict[str, Any], dict[str, Any] | None]:
        x, t = self.x, self.x.type
        payload: dict[str, Any]
        options: list[dict[str, Any]]
        correct: str | None
        if t in ("multiple_choice", "scenario"):
            options, correct = self.options(feedback=t == "scenario")
            payload = {"options": options}
            if t == "scenario":
                self.need(bool(x.situation), "a scenario has a situation")
                payload = {"situation": compose.span(x.situation or ""), "options": options}
            return payload, {"option_id": correct}
        if t == "true_false":
            self.need(bool(x.statement) and x.correct_value is not None, "statement and correct_value")
            return {"statement": compose.span(x.statement or "")}, {"value": bool(x.correct_value)}
        if t == "true_false_reason":
            self.need(bool(x.statement) and x.correct_value is not None, "statement and correct_value")
            reasons, correct = self.options()
            return ({"statement": compose.span(x.statement or ""), "reasons": reasons},
                    {"value": bool(x.correct_value), "reason_option_id": correct})
        if t == "match_pairs":
            pairs = x.pairs or []
            self.need(3 <= len(pairs) <= 5, "3-5 pairs")
            left = [{"item_id": f"l{i}", "spans": compose.span(p.left)} for i, p in enumerate(pairs, start=1)]
            served = _rotate(list(range(len(pairs))))
            right = [{"item_id": f"r{i}", "spans": compose.span(pairs[k].right)} for i, k in enumerate(served, 1)]
            key = [{"left_id": f"l{k + 1}", "right_id": f"r{served.index(k) + 1}"} for k in range(len(pairs))]
            return {"left": left, "right": right}, {"pairs": key}
        if t == "fill_blank":
            return self.fill_blank()
        if t == "categorize":
            categories, items = x.categories or [], x.items or []
            self.need(2 <= len(categories) <= 3, "buckets have 2-3 categories")
            self.need(4 <= len(items) <= 8, "buckets have 4-8 items")
            ids = {c.category_id: f"c{i}" for i, c in enumerate(categories, start=1)}
            assignments = []
            for index, item in enumerate(items, start=1):
                if self.need(item.category_id in ids, f"item {item.item_id} names one of the categories"):
                    assignments.append({"item_id": f"i{index}", "category_id": ids[item.category_id or ""]})
            return ({"presentation": "buckets",
                     "categories": [{"category_id": ids[c.category_id], "label": c.label, "art_key": None,
                                     "phase": None, "capacity": None} for c in categories],
                     "items": [{"item_id": f"i{i}", "spans": compose.span(item.text), "secondary_label": None}
                               for i, item in enumerate(items, start=1)]},
                    {"assignments": assignments})
        if t == "order_steps":
            steps = x.steps or []
            self.need(3 <= len(steps) <= 7, "3-7 steps")
            served = _rotate(list(range(len(steps))))
            payload = {"presentation": "plain",
                       "steps": [{"step_id": f"s{i}", "spans": compose.span(steps[k].text), "secondary_label": None}
                                 for i, k in enumerate(served, start=1)]}
            return payload, {"order": [f"s{served.index(k) + 1}" for k in range(len(steps))]}
        if t == "spot_error":
            segments = x.steps or []
            self.need(len(segments) >= 2, "at least 2 segments")
            ids = {s.option_id: f"g{i}" for i, s in enumerate(segments, start=1)}
            self.need(x.correct_option_id in ids, "correct_option_id names the erroneous segment")
            return ({"segments": [{"segment_id": ids[s.option_id], "spans": compose.span(s.text)} for s in segments]},
                    {"segment_id": ids.get(x.correct_option_id or "")})
        if t == "which_evidence":
            keys = x.evidence_option_ids or []
            self.need(2 <= len(keys) <= 4 and not duplicates(keys), "2-4 distinct verified evidence options")
            self.need(bool(x.statement), "the claim the evidence must support")
            options, correct = [], None
            for index, evidence_key in enumerate(keys, start=1):
                evidence = self.evidence(evidence_key)
                if evidence is not None:
                    options.append({"option_id": f"o{index}", "evidence": evidence})
                if evidence_key == x.correct_option_id:
                    correct = f"o{index}"
            self.need(correct is not None, "correct_option_id is one of evidence_option_ids")
            return {"claim": compose.span(x.statement or ""), "options": options}, {"option_id": correct}
        if t == "verse_meaning":
            verse = self.evidence(x.verse_evidence_id, quran_displayed=True)
            options, correct = self.options()
            return {"verse": verse, "options": options}, {"option_id": correct}
        self.need(bool(x.front) and bool(x.back), "a flashcard has a front and a back")
        return {"front": compose.span(x.front or ""), "back": compose.span(x.back or "")}, None

    def fill_blank(self) -> tuple[dict[str, Any], dict[str, Any] | None]:
        segments, words = self.x.segments or [], self.x.words or []
        blanks: list[str] = []
        served_segments: list[dict[str, Any]] = []
        for segment in segments:
            if segment.kind == "blank":
                if self.need(bool(segment.blank_id), "every blank has an id"):
                    blanks.append(segment.blank_id or "")
                    served_segments.append({"type": "blank", "blank_id": f"b{len(blanks)}"})
            elif self.need(bool(segment.text), "text segments carry text"):
                served_segments.append({"type": "text", "text": segment.text})
        self.need(bool(blanks) and not duplicates([b or "" for b in blanks]), "at least one blank, ids unique")
        fills = {w.fills_blank_id: w for w in words if w.fills_blank_id}
        self.need(sorted(fills) == sorted(b or "" for b in blanks) and
                  len([w for w in words if w.fills_blank_id]) == len(blanks),
                  "exactly one word fills each blank")
        order = list(range(len(words)))
        correct = [words.index(fills[b]) for b in blanks if b in fills]
        for _ in range(len(words)):
            if len(blanks) < 2 or order[:len(correct)] != correct:
                break
            order = _rotate(order)
        bank = [{"word_id": f"w{i}", "text": words[k].text} for i, k in enumerate(order, start=1)]
        key = [{"blank_id": f"b{i}", "word_id": f"w{order.index(words.index(fills[b])) + 1}"}
               for i, b in enumerate(blanks, start=1) if b in fills]
        return {"segments": served_segments, "word_bank": bank}, {"fills": key}

    def build(self, purpose: str) -> dict[str, Any] | None:
        x = self.x
        payload, key = self.payload()
        framing = None
        target = None
        if x.targets_misconception_id:
            target = self.misconception_id(x.targets_misconception_id)
            self.need(target is not None, f"targets unknown misconception {x.targets_misconception_id}")
        if x.myth_statement:
            self.need(target is not None, "a myth-framed item targets the misconception it corrects")
            framing = {"kind": "myth", "statement": compose.span(x.myth_statement)}
        for key_id in x.evidence_ids:
            if key_id in self.registry:
                self.sources.append(self.registry[key_id]["source_id"])
            else:
                self.need(False, f"evidence {key_id} is not in the verified evidence registry")
        if self.errors:
            return None
        body = {"exercise_id": self.id, "type": x.type, "concept_ids": list(x.concept_ids),
                "prompt": compose.span(x.prompt), "time_limit_ms": None,
                "scoring": {"accuracy": True, "combo": True, "layer": x.layer}, "framing": framing,
                "payload": payload, "answer_key": key, "option_misconceptions": self.option_misconceptions,
                "duel_eligible": purpose == "duel"}
        try:
            exercise = C.ReviewerExercise.model_validate(body).model_dump(mode="json")
        except ValidationError as error:
            self.errors.append(f"{x.exercise_id} ({x.type}): {error.errors()[0]['msg']}")
            return None
        feedback = {"explanation": compose.span(x.explanation), "option_feedback": self.option_feedback,
                    "event_dates": [], "pin_labels": []}
        return {"exercise_id": self.id, "purpose": purpose, "exercise": exercise, "feedback": feedback,
                "targets_misconception_id": target, "source_ids": sorted(set(self.sources)),
                "slot_block_id": x.slot_block_id, "designer_id": x.exercise_id}


def check(designed: ExerciseSet, plan: dict[str, Any], slots: list[str]) -> list[str]:
    errors = [f"duplicate exercise id {e}" for e in duplicates([x.exercise_id for x in designed.exercises])]
    concepts = set(plan["introduced_concept_ids"]) | set(plan["prerequisite_concept_ids"])
    placed = [x for x in designed.exercises if x.purpose == "lesson" and x.type != "flashcard"]
    filled = [x.slot_block_id for x in placed]
    if sorted(s or "" for s in filled) != sorted(slots) or duplicates([s or "" for s in filled]):
        errors.append(f"exactly one graded lesson exercise fills each writer slot {slots} (got {filled}); unused "
                      "candidates are dropped, not kept")
    for x in designed.exercises:
        if (x.purpose != "lesson" or x.type == "flashcard") and x.slot_block_id is not None:
            errors.append(f"{x.exercise_id}: only graded lesson exercises fill slots")
        unknown = set(x.concept_ids) - concepts
        if unknown:
            errors.append(f"{x.exercise_id}: concepts {sorted(unknown)} are neither taught nor required here")
        if x.type == "true_false" and x.purpose != "duel":
            errors.append(f"{x.exercise_id}: true_false is challenge-only (duel)")
        if x.purpose == "duel" and x.type not in DUEL_TYPES:
            errors.append(f"{x.exercise_id}: duel items are {', '.join(DUEL_TYPES)}")
        if x.purpose != "lesson" and x.type in NOT_ASSESSMENT:
            errors.append(f"{x.exercise_id}: flashcards are not assessment items")
    counts: Counter[str] = Counter(str(x.purpose) for x in designed.exercises)
    for purpose, expected in ASSESSMENT.items():
        if counts.get(purpose, 0) != expected:
            errors.append(f"exactly {expected} {purpose} items (found {counts.get(purpose, 0)})")
    flashcards = {c for x in designed.exercises if x.type == "flashcard" for c in x.concept_ids}
    for concept_id in sorted(set(plan["introduced_concept_ids"]) - flashcards):
        errors.append(f"every concept the lesson teaches has a flashcard ({concept_id} has none)")
    new = [m.misconception_id for m in designed.misconceptions]
    errors += [f"duplicate misconception card {m}" for m in duplicates(new)]
    return errors


async def run(ctx: StageContext) -> StageResult:
    plan = approved_plan(ctx)
    written = accepted(ctx, "write")
    verified = accepted(ctx, "verify_evidence")
    registry = {item["evidence_key"]: item for item in verified["evidence"]}
    first = next(iter(written["variants"].values()))
    slots = [b["block_id"] for b in first["blocks"] if b["type"] == "exercise"]
    writer_first = written["writer"]["variants"][0]
    displayed = {b.get("evidence_id") for b in writer_first["blocks"] if b["type"] in ("evidence", "teach")}
    displayed |= {beat.get("quote_evidence_id") for b in writer_first["blocks"] if b["type"] == "story"
                  for beat in b["beats"]}
    async with ctx.sessionmaker() as db:
        existing = {m.id: m for m in (await db.execute(select(Misconception).where(
            Misconception.unit_id == ctx.run.unit_id))).scalars()}
    steps = {s["step_id"]: s for s in plan["lesson_arc"]["steps"]}
    slot_steps = {block_id: row["step_id"] for row in written["arc_map"] for block_id in row["block_ids"]}
    data = {"plan": plan,
            "slots": [{"slot_block_id": b["block_id"], "intent": b["intent"],
                       "arc_step": steps[slot_steps[b["block_id"]]]}
                      for b in first["blocks"] if b["type"] == "exercise"],
            "lesson_text": written["writer"]["variants"][0],
            "supported_claims": [r["claim"] for r in verified["claims"] if r["claim"]["status"] == "supported"],
            "evidence": [{"evidence_id": k, "kind": v["kind"], "reference": v["reference"], "text": v["text"],
                          "displayed_in_lesson": k in displayed} for k, v in registry.items()],
            "existing_misconceptions": [{"misconception_id": m.id, "concept_id": m.concept_id, "title": m.title}
                                        for m in existing.values()],
            "previous_attempt_issues": ctx.run.previous_issues}
    result = await ctx.llm.structured("factory_exercises", data, ledger=ctx.ledger, call_key=ctx.call_key)
    designed = parse(ExerciseSet, result.data, "exercises_invalid")
    errors = check(designed, plan, slots)
    key = key_of(ctx.run.id)
    new_ids = {m.misconception_id: f"mis_{key}_{i}" for i, m in enumerate(designed.misconceptions, start=1)
               if m.misconception_id not in existing}

    def misconception_id(value: str) -> str | None:
        return value if value in existing else new_ids.get(value)

    for card in designed.misconceptions:
        if card.misconception_id in existing:
            errors.append(f"{card.misconception_id} already has a card; only new misconceptions get one here")
        if card.concept_id is not None and card.concept_id not in (set(plan["introduced_concept_ids"]) |
                                                                   set(plan["prerequisite_concept_ids"])):
            errors.append(f"{card.misconception_id}: concept {card.concept_id} is not part of this lesson")
    records = []
    for index, x in enumerate(designed.exercises, start=1):
        builder = Builder(f"ex_{key}_{index}", x, registry, {k for k in displayed if k}, misconception_id)
        record = builder.build(x.purpose)
        errors += builder.errors
        if record is not None:
            records.append(record)
    require(errors, "exercises_invalid")
    slot_exercise = {r["slot_block_id"]: r["exercise_id"] for r in records if r["slot_block_id"]}
    misconceptions = [{"misconception_id": new_ids[m.misconception_id], "concept_id": m.concept_id,
                       "title": m.title, "card": compose.span(m.card), "designer_id": m.misconception_id}
                      for m in designed.misconceptions]
    output = {"exercises": records, "slots": slot_exercise, "misconceptions": misconceptions}
    return StageResult(output=output, inputs=data, notes={"agent_issues": designed.issues})
