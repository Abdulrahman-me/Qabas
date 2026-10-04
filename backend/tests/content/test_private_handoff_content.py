"""The converters on the real, unapproved handoff content - only where the private handoff exists (D-19).

The drafts and the reference export never enter the public repository, so CI skips this module; locally it
proves that (1) every Unit 0 lesson and the Salah reference are blocked exactly by the recorded human, source
and media inputs, and (2) the projections themselves are lossless. Stand-ins for the missing human inputs are
used only inside these assertions; nothing is written or imported.
"""

from __future__ import annotations

import copy
from pathlib import Path
from typing import Any

import pytest

from app.content.curriculum import ConceptSpec, load_curriculum
from app.content.importers import salah, unit0
from app.content.package import LessonPackage
from app.content.validation import Context, validate_package

HANDOFF = Path(__file__).resolve().parents[3] / "FINAL_ENGINEERING_HANDOFF"
UNIT0 = HANDOFF / "UNIT_0_CONTENT" / "lessons"
REFERENCE = HANDOFF / "10_REFERENCE" / "engineer_delivery" / "reply8" / "reference_export"

pytestmark = pytest.mark.skipif(not UNIT0.exists() or not REFERENCE.exists(),
                                reason="private handoff content is not in the public repository (D-19)")

EXPECTED_UNIT0 = {"reasoning_tool_unmapped", "plan_text_missing", "concept_unregistered", "scene_media_unpublished"}


def test_every_unit0_lesson_is_blocked_by_the_recorded_inputs() -> None:
    records = unit0.load_records(UNIT0)
    assert len(records) == 12
    for r in records:
        conversion = unit0.convert(r, load_curriculum(), mapping=unit0.load_mapping(), scenes={})
        codes = {b.code for b in conversion.blockers}
        assert conversion.package is None and codes >= EXPECTED_UNIT0, (conversion.lesson, codes)
        assert codes <= EXPECTED_UNIT0 | {"source_pending", "claim_in_span_field"}, (conversion.lesson, codes)


class _Fallbacks(dict[str, Any]):
    def get(self, key: Any, default: Any = None) -> Any:
        return {"url": "https://stand.in/f.webp", "mime_type": "image/webp", "width": 1600, "height": 1000}


class _AnyScene:
    def get(self, scene_id: str) -> unit0.SceneMedia:
        ref = {"scene_id": scene_id, "version": 1, "schema_version": "qabas.scene/1",
               "url": f"https://stand.in/{scene_id}.json", "mime_type": "application/json", "sha256": "0" * 64,
               "view_box": {"width": 1600, "height": 1000}, "required_capabilities": []}
        return unit0.SceneMedia(scene_ref=ref, fallbacks=_Fallbacks())


def both(value: Any) -> dict[str, Any]:
    return value if isinstance(value, dict) else {"ar": value, "en": value}


def test_with_the_human_inputs_supplied_the_projection_passes_every_validator() -> None:
    # Stand-ins: an approved mapping, registered concepts, published scenes and both languages of the plan text.
    records = unit0.load_records(UNIT0)
    mapping = unit0.ToolMapping(status="approved", approved_by="stand-in",
                                mapping={t: "inference" for t in unit0.load_mapping().mapping})
    concepts = sorted({c for r in records for c in r["plan"]["introduced_concept_ids"]})
    curriculum = load_curriculum()
    curriculum = curriculum.model_copy(update={"concepts": [
        ConceptSpec(concept_id=c, unit_id="unit_0", title={"ar": c, "en": c}) for c in concepts]})
    clean = []
    for r in records:
        r = copy.deepcopy(r)
        arc = r["plan"]["lesson_arc"]
        arc["rationale"] = both(arc["rationale"])
        for step in arc["steps"]:
            step["experience"] = both(step["experience"])
        for tool in r["plan"]["reasoning_tools"]:
            tool["justification"] = both(tool["justification"])
        conversion = unit0.convert(r, curriculum, mapping=mapping, scenes=_AnyScene())  # type: ignore[arg-type]
        if conversion.package is None:
            assert {b.code for b in conversion.blockers} <= {"source_pending", "claim_in_span_field"}
            continue
        package = LessonPackage.model_validate(conversion.package)
        assert validate_package(package, Context(unit_tracks=["explorer"], known_concepts=set(concepts))) == []
        clean.append(conversion.lesson)
    assert clean == ["les_u0_l5", "les_u0_l6", "les_u0_l8"]


def test_the_salah_export_is_blocked_and_projects_losslessly() -> None:
    export = salah.load_export(REFERENCE)
    conversion = salah.convert(export, load_curriculum(), None)
    assert conversion.package is None
    assert {b.code for b in conversion.blockers} == {"media_unavailable", "source_pending", "reference_acceptance",
                                                     "completion_record_missing", "curriculum_placement"}
    variants, exercises = salah.variants_and_exercises(export)
    for lang, track in salah.VARIANTS:
        items = salah.served_items(variants, exercises, lang, track)
        assert items == export["sessions"][f"{lang}_{track}"]["items"] and len(items) == 14
