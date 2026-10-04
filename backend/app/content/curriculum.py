"""Curriculum structure: ``content/curriculum.yaml`` (units, tracks, track framing, slots, concept graph).

Loading validates everything and reports every problem at once; invalid curricula are rejected, never
repaired. ``id_scheme: canonical`` (production) also enforces the canonical ids: ``unit_<index>`` and
``les_u<unit>_l<n>`` for slot "<unit>.<n>" at 0-based position n-1 (SEED_AND_IMPORT §15).
"""

from __future__ import annotations

from pathlib import Path
from typing import Any, Literal

import yaml
from pydantic import BaseModel, ConfigDict, Field, ValidationError, model_validator

from app.contract import models as C
from app.registries import registries

CURRICULUM_PATH = Path(__file__).resolve().parents[2] / "content" / "curriculum.yaml"

Lang = Literal["ar", "en"]
Track = Literal["explorer", "new_muslim"]
LANGS: tuple[Lang, ...] = ("ar", "en")


class CurriculumError(ValueError):
    def __init__(self, problems: list[str]) -> None:
        self.problems = problems
        super().__init__("invalid curriculum:\n" + "\n".join(f"  - {p}" for p in problems))


class _Strict(BaseModel):
    model_config = ConfigDict(extra="forbid")


class WorkingText(_Strict):
    en: str = Field(min_length=1)
    ar: str | None = Field(default=None, min_length=1)


class GuideSpec(_Strict):
    title: str = Field(min_length=1)
    sections: list[C.GuideSection] = Field(min_length=1)


class SlotSpec(_Strict):
    slot: str = Field(pattern=r"^\d+\.\d+$")
    lesson_id: str = Field(pattern=r"^les_[0-9A-Za-z_]+$")
    working_title: WorkingText
    focus: WorkingText | None = None


class UnitSpec(_Strict):
    unit_id: str = Field(pattern=r"^unit_[0-9A-Za-z_]+$")
    index: int = Field(ge=0)
    tracks: list[Track] = Field(min_length=1)
    art_key: str | None
    pass_percent: int = Field(ge=1, le=100)
    title: dict[Lang, dict[Track, str]]
    subtitle: dict[Lang, dict[Track, str]]
    goal: WorkingText | None = None
    guide: dict[Lang, dict[Track, GuideSpec]] | None = None
    lessons: list[SlotSpec]


class ConceptSpec(_Strict):
    concept_id: str = Field(pattern=r"^con_[0-9A-Za-z_]+$")
    unit_id: str
    title: dict[Lang, str]
    prerequisite_ids: list[str] = Field(default_factory=list)

    @model_validator(mode="after")
    def _title(self) -> ConceptSpec:
        if set(self.title) != set(LANGS) or not all(v.strip() for v in self.title.values()):
            raise ValueError(f"{self.concept_id}: title is required in ar and en")
        return self


class Curriculum(_Strict):
    schema_: Literal["qabas.curriculum/1"] = Field(alias="schema")
    review_status: Literal["working", "approved"]
    id_scheme: Literal["canonical", "fixture"] = "canonical"
    units: list[UnitSpec] = Field(min_length=1)
    concepts: list[ConceptSpec]

    model_config = ConfigDict(extra="forbid", populate_by_name=True)

    def unit(self, unit_id: str) -> UnitSpec:
        return next(u for u in self.units if u.unit_id == unit_id)

    def slots(self) -> list[tuple[UnitSpec, int, SlotSpec]]:
        return [(u, i, s) for u in sorted(self.units, key=lambda u: u.index) for i, s in enumerate(u.lessons)]


def load_curriculum(path: Path = CURRICULUM_PATH) -> Curriculum:
    raw = yaml.safe_load(path.read_text(encoding="utf-8"))
    return parse_curriculum(raw)


def parse_curriculum(raw: Any) -> Curriculum:
    try:
        curriculum = Curriculum.model_validate(raw)
    except ValidationError as exc:
        raise CurriculumError([f"{'.'.join(str(p) for p in e['loc'])}: {e['msg']}" for e in exc.errors()]) from None
    problems = validate_curriculum(curriculum)
    if problems:
        raise CurriculumError(problems)
    return curriculum


def validate_curriculum(cur: Curriculum) -> list[str]:
    problems: list[str] = []
    art_keys = set(registries()["unit_art"]["keys"])
    unit_ids = [u.unit_id for u in cur.units]
    indices = [u.index for u in cur.units]
    problems += [f"duplicate unit id {u}" for u in sorted({u for u in unit_ids if unit_ids.count(u) > 1})]
    problems += [f"duplicate unit index {i}" for i in sorted({i for i in indices if indices.count(i) > 1})]
    lesson_ids: list[str] = []
    for unit in cur.units:
        where = unit.unit_id
        if len(set(unit.tracks)) != len(unit.tracks):
            problems.append(f"{where}: a track is listed twice")
        if cur.id_scheme == "canonical" and unit.unit_id != f"unit_{unit.index}":
            problems.append(f"{where}: canonical unit id is unit_{unit.index}")
        if unit.art_key is not None and unit.art_key not in art_keys:
            problems.append(f"{where}: art_key {unit.art_key!r} is not a bundled unit art key")
        for name in ("title", "subtitle"):
            framing = getattr(unit, name)
            if set(framing) != set(LANGS):
                problems.append(f"{where}.{name}: required in ar and en")
            for lang, by_track in framing.items():
                if set(by_track) != set(unit.tracks):
                    problems.append(f"{where}.{name}.{lang}: exactly one entry per unit track {unit.tracks}")
                problems += [f"{where}.{name}.{lang}.{t}: empty" for t, text in by_track.items() if not text.strip()]
        if unit.guide is not None:
            for lang, by_track in unit.guide.items():
                if set(by_track) != set(unit.tracks):
                    problems.append(f"{where}.guide.{lang}: one guide per unit track")
            if set(unit.guide) != set(LANGS):
                problems.append(f"{where}.guide: required in ar and en when present")
        for position, slot in enumerate(unit.lessons):
            lesson_ids.append(slot.lesson_id)
            unit_part, number = slot.slot.split(".")
            if int(unit_part) != unit.index or int(number) != position + 1:
                problems.append(f"{where}: slot {slot.slot} must be {unit.index}.{position + 1} "
                                f"(slots are numbered in order from 1)")
            if cur.id_scheme == "canonical":
                expected = f"les_u{unit.index}_l{position + 1}"
                if slot.lesson_id != expected:
                    problems.append(f"{where}: slot {slot.slot} has canonical lesson id {expected}")
    problems += [f"duplicate lesson id {i}" for i in sorted({i for i in lesson_ids if lesson_ids.count(i) > 1})]
    for track in ("explorer", "new_muslim"):
        if not any(track in u.tracks for u in cur.units):
            problems.append(f"no unit serves the {track} track")
    problems += _concept_graph(cur)
    return problems


def _concept_graph(cur: Curriculum) -> list[str]:
    problems = []
    units = {u.unit_id: u for u in cur.units}
    concepts = {c.concept_id: c for c in cur.concepts}
    if len(concepts) != len(cur.concepts):
        problems.append("duplicate concept id")
    for concept in cur.concepts:
        unit = units.get(concept.unit_id)
        if unit is None:
            problems.append(f"{concept.concept_id}: unknown unit {concept.unit_id}")
            continue
        for prereq_id in concept.prerequisite_ids:
            prereq = concepts.get(prereq_id)
            if prereq is None:
                problems.append(f"{concept.concept_id}: unknown prerequisite {prereq_id}")
                continue
            prereq_unit = units.get(prereq.unit_id)
            if prereq_unit is None:
                continue
            if prereq_unit.index > unit.index:
                problems.append(f"{concept.concept_id}: prerequisite {prereq_id} sits later in the curriculum")
            if not set(unit.tracks) <= set(prereq_unit.tracks):
                problems.append(f"{concept.concept_id}: prerequisite {prereq_id} is not available in every track "
                                f"this unit serves")
    # cycles
    state: dict[str, int] = {}

    def visit(cid: str, stack: list[str]) -> None:
        if state.get(cid) == 2:
            return
        if state.get(cid) == 1:
            problems.append(f"concept prerequisite cycle: {' -> '.join([*stack, cid])}")
            return
        state[cid] = 1
        for prereq_id in concepts[cid].prerequisite_ids if cid in concepts else []:
            if prereq_id in concepts:
                visit(prereq_id, [*stack, cid])
        state[cid] = 2

    for cid in concepts:
        visit(cid, [])
    return problems


