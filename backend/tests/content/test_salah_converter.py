"""The Salah reference converter (D-83): lossless projection of the export and the completion-record merge.

The real reference export is unpublished private gold (D-19). Here the contract's own test-curriculum sessions
for a shared lesson stand in for the four exported variants, and the parts the completion record must supply
come from that lesson's stored test package.
"""

from __future__ import annotations

import json
from typing import Any

from app.content.importers import salah
from app.content.package import LessonPackage
from app.content.test_curriculum import CURRICULUM_DIR, build_curriculum, build_packages

LESSON = "les_t2_0"


def export() -> dict[str, Any]:
    package = next(p for p in build_packages() if p.lesson_id == LESSON)
    sessions = {f"{lang}_{track}": json.loads((CURRICULUM_DIR / "lessons" / f"{LESSON}__{lang}_{track}.json")
                                              .read_text(encoding="utf-8")) for lang, track in salah.VARIANTS}
    placed = {e.exercise_id: e for e in package.exercises if e.purpose == "lesson" and e.type != "flashcard"}
    private = {f"{lang}_{track}": {"private_exercises": {
        eid: {"answer_key": rec.exercise[lang].answer_key.model_dump(mode="json") if rec.exercise[lang].answer_key
              else None, "explanation": rec.feedback[lang].model_dump(mode="json")["explanation"],
              "misconception_card": None} for eid, rec in placed.items()}} for lang, track in salah.VARIANTS}
    return {"sessions": sessions, "gold": {"publication_blockers": [], "variants": private}, "glossary": []}


def completion(target: str = LESSON) -> salah.Completion:
    package = next(p for p in build_packages() if p.lesson_id == LESSON)
    placed = set(package.variants["ar"]["explorer"].exercise_ids())
    return salah.Completion.model_validate({
        "schema": "qabas.salah_completion/1", "target_lesson_id": target, "decided_by": "Test Product Owner",
        "plan": package.plan.model_dump(mode="json"),
        "claims": [c.model_dump(mode="json") for c in package.claims],
        "sentence_map": [s.model_dump(mode="json") for s in package.sentence_map],
        "arc_map": [a.model_dump(mode="json") for a in package.arc_map],
        "misconceptions": [m.model_dump(mode="json") for m in package.misconceptions],
        "option_misconceptions": {}, "targets": {},
        "feedback": {e.exercise_id: {lang: {k: v for k, v in e.feedback[lang].model_dump(mode="json").items()
                                            if k != "explanation"} for lang in ("ar", "en")}
                     for e in package.exercises if e.exercise_id in placed},
        "exercise_sources": {e.exercise_id: list(e.source_ids) for e in package.exercises if e.exercise_id in placed},
        "exercises": [e.model_dump(mode="json") for e in package.exercises if e.exercise_id not in placed],
        "sources": [{"record": s.model_dump(mode="json"), "provider_record_id": s.source_id,
                     "verified_by": "Test Specialist"} for s in package.sources],
    })


def test_the_projection_reproduces_every_exported_variant() -> None:
    data = export()
    variants, exercises = salah.variants_and_exercises(data)
    for lang, track in salah.VARIANTS:
        assert salah.served_items(variants, exercises, lang, track) == data["sessions"][f"{lang}_{track}"]["items"]


def test_without_a_completion_record_nothing_is_authored() -> None:
    conversion = salah.convert(export(), build_curriculum(), None)
    assert conversion.package is None
    assert {b.code for b in conversion.blockers} == {"completion_record_missing", "curriculum_placement"}


def test_the_completion_record_completes_the_lesson() -> None:
    conversion = salah.convert(export(), build_curriculum(), completion())
    assert conversion.blockers == [] and conversion.package is not None
    built = LessonPackage.model_validate(conversion.package)
    original = next(p for p in build_packages() if p.lesson_id == LESSON)
    assert built.variants == original.variants
    assert {e.exercise_id: e for e in built.exercises} == {e.exercise_id: e for e in original.exercises}
    assert (built.plan, built.claims, built.arc_map) == (original.plan, original.claims, original.arc_map)


def test_export_blockers_and_unavailable_media_still_block() -> None:
    data = export()
    data["gold"]["publication_blockers"] = ["licensed seven-word reciter clip and actual word timings absent",
                                            "scripture/attribution copied from bundled prototype",
                                            "complete API-driven fourteen-step Session playback/parity not run"]
    conversion = salah.convert(data, build_curriculum(), completion())
    assert conversion.package is None
    assert {b.code for b in conversion.blockers} == {"media_unavailable", "source_pending", "reference_acceptance"}
    unknown = salah.convert(export(), build_curriculum(), completion("les_unknown"))
    assert [b.code for b in unknown.blockers] == ["curriculum_placement"]
