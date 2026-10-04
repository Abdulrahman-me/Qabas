"""The stored lesson package: everything one lesson version publishes, built from contract models.

A package is what the factory's Gate 2 approves and what a gold import supplies (factory §13.6-13.7):
the approved ``LessonPlan``, the Arabic-authored and English-localized variants (one block skeleton),
claims with their evidence or reasoning, the role of every sentence, the arc map, every exercise with
its private key and per-language feedback (lesson items, flashcards, pretest/unit-test items, duel items),
glossary records, misconception cards and the sources it cites.

Storage form vs learner form: a stored exercise block names its exercise (``exercise_id``) instead of
embedding it (data model §4.2); :func:`app.content.projection` resolves it into the contract ``Exercise``
the learner sees, without the key. Nothing here is served until the version is published.
"""

from __future__ import annotations

import hashlib
import json
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field, TypeAdapter, field_validator, model_validator

from app.contract import models as C

Lang = Literal["ar", "en"]
Variant = Literal["explorer", "new_muslim"]
Purpose = Literal["lesson", "pretest", "unit_test", "duel"]
LANGS: tuple[Lang, ...] = ("ar", "en")

BLOCK_ADAPTER: TypeAdapter[Any] = TypeAdapter(C.Block)


class Strict(BaseModel):
    model_config = ConfigDict(extra="forbid")


class ExerciseRef(Strict):
    """Storage form of an exercise block."""

    block_id: str
    type: Literal["exercise"]
    exercise_id: str


class VariantContent(Strict):
    """One language x track variant of the lesson (the learner-facing projection source)."""

    title: str = Field(min_length=1)
    subtitle: str | None
    objectives: list[C.Spans] = Field(min_length=1, max_length=3)
    blocks: list[dict[str, Any]] = Field(min_length=1)
    completion: C.Completion | None

    @field_validator("blocks")
    @classmethod
    def _blocks(cls, blocks: list[dict[str, Any]]) -> list[dict[str, Any]]:
        for block in blocks:
            if block.get("type") == "exercise":
                ExerciseRef.model_validate(block)
            else:
                BLOCK_ADAPTER.validate_python(block)
        ids = [b["block_id"] for b in blocks]
        if len(ids) != len(set(ids)):
            raise ValueError("block ids must be unique within a variant")
        return blocks

    def exercise_ids(self) -> list[str]:
        return [b["exercise_id"] for b in self.blocks if b["type"] == "exercise"]

    def skeleton(self) -> list[tuple[str, str, str | None]]:
        """Top-level block ids, types and exercise ids, in order (the shared variant skeleton)."""
        return [(b["block_id"], b["type"], b.get("exercise_id")) for b in self.blocks]


class ExerciseFeedback(Strict):
    """Per-language evaluation content (returned only after an answer, per feedback mode)."""

    explanation: C.Spans = Field(min_length=1)
    option_feedback: list[C.OptionFeedback]  # scenario: one per option
    event_dates: list[C.EventDate]           # timeline_order: one per event
    pin_labels: list[C.PinLabel]             # map_place: one per pin


class ExerciseRecord(Strict):
    """One exercise identity with its wording per language (same type, ids and key in both)."""

    exercise_id: str
    purpose: Purpose
    exercise: dict[Lang, C.ReviewerExercise]
    feedback: dict[Lang, ExerciseFeedback]
    targets_misconception_id: str | None
    source_ids: list[str]

    @model_validator(mode="after")
    def _languages(self) -> ExerciseRecord:
        if set(self.exercise) != set(LANGS) or set(self.feedback) != set(LANGS):
            raise ValueError(f"{self.exercise_id}: wording and feedback are required in ar and en")
        ar, en = self.exercise["ar"], self.exercise["en"]
        for lang, item in self.exercise.items():
            if item.exercise_id != self.exercise_id:
                raise ValueError(f"{self.exercise_id}: {lang} wording carries id {item.exercise_id}")
        # Localization keeps identity, type, concepts, scoring, key, misconception mapping and option ids.
        for field in ("type", "concept_ids", "scoring", "time_limit_ms", "answer_key", "option_misconceptions",
                      "duel_eligible"):
            if getattr(ar, field) != getattr(en, field):
                raise ValueError(f"{self.exercise_id}: ar and en differ in {field}")
        if _payload_ids(ar.payload) != _payload_ids(en.payload):
            raise ValueError(f"{self.exercise_id}: ar and en differ in option/item/step/pin ids")
        if self.purpose == "duel" and not ar.duel_eligible:
            raise ValueError(f"{self.exercise_id}: duel items are duel_eligible")
        return self

    @property
    def type(self) -> str:
        return str(self.exercise["ar"].type)

    @property
    def concept_ids(self) -> list[str]:
        return list(self.exercise["ar"].concept_ids)

    @property
    def scored(self) -> bool:
        return bool(self.exercise["ar"].scoring.accuracy)


class SourceRecord(Strict):
    """A cited source (the contract ``Source`` without the per-session display flags)."""

    source_id: str
    kind: C.SourceKind
    provider: C.Provider
    title: str
    reference: str
    excerpt: str
    url: str | None


class MisconceptionRecord(Strict):
    misconception_id: str
    concept_id: str | None
    title: dict[Lang, str]
    card: dict[Lang, C.Spans]
    source_ids: list[str]

    @model_validator(mode="after")
    def _langs(self) -> MisconceptionRecord:
        if set(self.title) != set(LANGS) or set(self.card) != set(LANGS):
            raise ValueError(f"{self.misconception_id}: title and card are required in ar and en")
        return self


class LessonPackage(Strict):
    lesson_id: str
    unit_id: str
    index: int = Field(ge=0)
    plan: C.LessonPlan
    variants: dict[Lang, dict[Variant, VariantContent]]
    claims: list[C.Claim]
    sentence_map: list[C.SentenceClaims]
    arc_map: list[C.ArcStepBlocks]
    exercises: list[ExerciseRecord]
    glossary: list[C.StoredGlossaryTerm]
    misconceptions: list[MisconceptionRecord]
    sources: list[SourceRecord]

    def variant_keys(self) -> list[tuple[Lang, Variant]]:
        return [(lang, variant) for lang in LANGS for variant in sorted(self.variants.get(lang, {}))]

    def exercise(self, exercise_id: str) -> ExerciseRecord | None:
        return next((e for e in self.exercises if e.exercise_id == exercise_id), None)

    def digest(self) -> str:
        """Content identity: SHA-256 of the canonical JSON of the whole package."""
        return content_digest(self.model_dump(mode="json"))


def content_digest(value: Any) -> str:
    canonical = json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


def _payload_ids(payload: dict[str, Any]) -> dict[str, list[str]]:
    """Identity-bearing ids inside an exercise payload (options, items, steps, pins, ...)."""
    found: dict[str, list[str]] = {}

    def walk(node: Any) -> None:
        if isinstance(node, dict):
            for key, value in node.items():
                if key.endswith("_id") and isinstance(value, str):
                    found.setdefault(key, []).append(value)
                else:
                    walk(value)
        elif isinstance(node, list):
            for value in node:
                walk(value)

    walk(payload)
    return {k: sorted(v) for k, v in found.items()}


def sentences_of(block: dict[str, Any]) -> list[dict[str, Any]]:
    """Every ``Sentence`` object inside a stored block (paragraph, teach points, story narration, ...)."""
    found: list[dict[str, Any]] = []

    def walk(node: Any) -> None:
        if isinstance(node, dict):
            if "sentence_id" in node and "spans" in node:
                found.append(node)
            for value in node.values():
                walk(value)
        elif isinstance(node, list):
            for value in node:
                walk(value)

    walk(block)
    return found


def spans_of(node: Any) -> list[dict[str, Any]]:
    """Every span (text/strong/term/citation) inside a structure."""
    found: list[dict[str, Any]] = []

    def walk(item: Any) -> None:
        if isinstance(item, dict):
            if item.get("type") in ("text", "strong", "term", "citation") and ("text" in item or "ref" in item):
                found.append(item)
            for value in item.values():
                walk(value)
        elif isinstance(item, list):
            for value in item:
                walk(value)

    walk(node)
    return found
