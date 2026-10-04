"""content/curriculum.yaml encodes the owner-confirmed Unit 0-10 curriculum, and invalid curricula fail clearly."""

from __future__ import annotations

import copy
from typing import Any

import pytest
import yaml

from app.content.curriculum import CURRICULUM_PATH, CurriculumError, load_curriculum, parse_curriculum

EXPECTED_SLOTS = {0: 12, 1: 6, 2: 7, 3: 9, 4: 7, 5: 8, 6: 8, 7: 8, 8: 10, 9: 8, 10: 10}


@pytest.fixture(scope="module")
def raw() -> dict[str, Any]:
    data: dict[str, Any] = yaml.safe_load(CURRICULUM_PATH.read_text(encoding="utf-8"))
    return data


def test_production_curriculum_structure() -> None:
    cur = load_curriculum()
    assert [u.unit_id for u in cur.units] == [f"unit_{i}" for i in range(11)]
    assert {u.index: len(u.lessons) for u in cur.units} == EXPECTED_SLOTS
    assert sum(EXPECTED_SLOTS.values()) == len(cur.slots()) == 93
    assert cur.unit("unit_0").tracks == ["explorer"]                       # Unit 0 is Explorer-only (AD-28)
    assert all(u.tracks == ["explorer", "new_muslim"] for u in cur.units[1:])
    assert cur.id_scheme == "canonical" and cur.review_status == "working"  # pending O-12


def test_slot_ids_and_positions_follow_the_curriculum() -> None:
    cur = load_curriculum()
    slots = {s.slot: (u.unit_id, i, s.lesson_id) for u, i, s in cur.slots()}
    assert slots["0.1"] == ("unit_0", 0, "les_u0_l1")
    assert slots["3.2"] == ("unit_3", 1, "les_u3_l2")      # the Salah reference's production slot
    assert slots["10.10"] == ("unit_10", 9, "les_u10_l10")
    titles = {s.slot: s.working_title.en for _, _, s in cur.slots()}
    assert titles["0.1"] == "Do You Have to See It to Know It?"
    assert titles["7.4"] == "Ibrahim" and titles["8.10"] == "The Final Years"


def test_track_framing_for_unit_1() -> None:
    unit = load_curriculum().unit("unit_1")
    assert unit.subtitle["en"] == {"explorer": "Understanding the First Step into Islam",
                                   "new_muslim": "Your First Steps with Allah"}


def _expect(raw: dict[str, Any], mutate: Any, message: str) -> None:
    data = copy.deepcopy(raw)
    mutate(data)
    with pytest.raises(CurriculumError) as exc:
        parse_curriculum(data)
    assert any(message in p for p in exc.value.problems), exc.value.problems


def test_duplicate_unit_index(raw: dict[str, Any]) -> None:
    _expect(raw, lambda d: d["units"][2].update(index=1), "duplicate unit index 1")


def test_non_canonical_lesson_id(raw: dict[str, Any]) -> None:
    _expect(raw, lambda d: d["units"][3]["lessons"][1].update(lesson_id="les_salah"), "canonical lesson id les_u3_l2")


def test_slot_numbers_are_contiguous(raw: dict[str, Any]) -> None:
    _expect(raw, lambda d: d["units"][1]["lessons"].pop(2), "slot 1.4 must be 1.3")


def test_every_track_needs_framing(raw: dict[str, Any]) -> None:
    _expect(raw, lambda d: d["units"][1]["title"]["ar"].pop("new_muslim"), "exactly one entry per unit track")


def test_unknown_art_key(raw: dict[str, Any]) -> None:
    _expect(raw, lambda d: d["units"][0].update(art_key="unit_big_questions"), "not a bundled unit art key")


def test_unknown_fields_are_rejected(raw: dict[str, Any]) -> None:
    _expect(raw, lambda d: d["units"][0].update(locked_until="unit_1"), "units.0.locked_until")


def _concepts(*specs: dict[str, Any]) -> Any:
    return lambda d: d.update(concepts=list(specs))


def test_concept_graph_rules(raw: dict[str, Any]) -> None:
    title = {"ar": "مفهوم", "en": "Concept"}
    _expect(raw, _concepts({"concept_id": "con_a", "unit_id": "unit_1", "title": title, "prerequisite_ids": ["con_b"]},
                           {"concept_id": "con_b", "unit_id": "unit_1", "title": title, "prerequisite_ids": ["con_a"]}),
            "concept prerequisite cycle")
    _expect(raw, _concepts({"concept_id": "con_a", "unit_id": "unit_1", "title": title, "prerequisite_ids": ["con_b"]},
                           {"concept_id": "con_b", "unit_id": "unit_2", "title": title}),
            "sits later in the curriculum")
    # A shared lesson cannot depend on an Explorer-only Unit 0 concept (curriculum: position vs prerequisites).
    _expect(raw, _concepts({"concept_id": "con_a", "unit_id": "unit_1", "title": title, "prerequisite_ids": ["con_z"]},
                           {"concept_id": "con_z", "unit_id": "unit_0", "title": title}),
            "not available in every track")
    _expect(raw, _concepts({"concept_id": "con_a", "unit_id": "unit_1", "title": title, "prerequisite_ids": ["con_x"]}),
            "unknown prerequisite con_x")
