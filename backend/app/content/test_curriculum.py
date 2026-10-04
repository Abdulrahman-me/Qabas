"""The contract's test curriculum (``fixtures/curriculum_test``) as real stored content, for automated tests.

SEED_AND_IMPORT §15: ``scripts/seed.py --test-curriculum`` loads 3 units x 3-4 lessons (an Explorer-only first
unit, shared units 2-3, both languages, concept/story/practice, prerequisite chains with Soft Locks,
standalone lessons, an image-only lesson and a lesson on the generated scene) plus ``fixtures/scenes``. It is a
synthetic contract witness, not curriculum content, and it goes through exactly the same import and
publication pipeline as real lessons, with ``origin = test_fixture``. That is allowed only in dev/test (D-29).

The fixtures are served Session snapshots, so this module rebuilds the stored form from them without
guessing: every lesson exercise must be byte-identical to a contract exercise specimen (keys and feedback
come from that specimen's evaluations), assessment items come with their private keys, and lesson-level
prerequisites become one introduced concept per lesson (``con_t<u>_<l>``). Fields the fixtures don't carry
(plans, sentence roles, flashcards, duel items, English feedback) are filled with clearly synthetic,
deterministic values.
"""

from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import Settings
from app.content.curriculum import Curriculum, parse_curriculum
from app.content.package import LessonPackage, sentences_of
from app.content.store import FixtureApproval, import_package, publish
from app.contract import FIXTURES_DIR
from app.models import SceneVersion

CURRICULUM_DIR = FIXTURES_DIR / "curriculum_test"
SCENES_DIR = FIXTURES_DIR / "scenes"
LANGS = ("ar", "en")


class FixtureError(ValueError):
    pass


def _load(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def _lt(ar: str, en: str) -> dict[str, str]:
    return {"ar": ar, "en": en}


def _spans_text(spans: list[dict[str, Any]]) -> str:
    return "".join(s.get("text", "") for s in spans)


@dataclass
class _Specimen:
    name: str
    exercise: dict[str, Any]
    key: Any
    explanation: list[dict[str, Any]]
    option_feedback: list[dict[str, Any]]
    event_dates: list[dict[str, Any]]
    pin_labels: list[dict[str, Any]]


def _specimens() -> list[_Specimen]:
    context = _load(FIXTURES_DIR / "EVALUATION_CONTEXT.json")
    found = []
    for folder in sorted((FIXTURES_DIR / "exercises").iterdir()):
        exercise = _load(folder / "exercise.json")
        option_feedback: dict[str, dict[str, Any]] = {}
        event_dates: dict[str, dict[str, Any]] = {}
        pin_labels: dict[str, dict[str, Any]] = {}
        explanation: list[dict[str, Any]] = []
        key = None
        for evaluation_file in sorted(folder.glob("eval_*.json")):
            evaluation = _load(evaluation_file)
            details = evaluation.get("details") or {}
            for row in details.get("option_feedback", []):
                option_feedback.setdefault(row["option_id"], row)
            for row in details.get("event_dates", []):
                event_dates.setdefault(row["event_id"], row)
            for row in details.get("pin_labels", []):
                pin_labels.setdefault(row["pin_id"], row)
            if evaluation_file.name == "eval_correct.json" or not explanation:
                explanation = evaluation["explanation"]
            if evaluation_file.name == "eval_correct.json":
                key = context[f"exercises/{folder.name}/eval_correct.json"]["private_key"]
        found.append(_Specimen(folder.name, exercise, key, explanation, list(option_feedback.values()),
                               list(event_dates.values()), list(pin_labels.values())))
    return found


def _specimen_for(exercise: dict[str, Any], specimens: list[_Specimen]) -> _Specimen:
    for spec in specimens:
        e = spec.exercise
        if (e["type"], e["payload"], e["prompt"]) == (exercise["type"], exercise["payload"], exercise["prompt"]):
            return spec
    raise FixtureError(f"{exercise['exercise_id']}: no identical contract specimen; refusing to guess its key")


def _feedback(spec: _Specimen, exercise: dict[str, Any], lang: str) -> dict[str, Any]:
    """Specimen feedback (Arabic). English test content is synthetic, so is its feedback."""
    payload = exercise["payload"]
    def cover(rows: list[dict[str, Any]], field: str, ids: list[str], label: str) -> list[dict[str, Any]]:
        # Specimen evaluations only show the feedback of the options they chose; any other option gets
        # clearly synthetic copy (the key itself is never synthesized).
        by_id = {r[field]: r for r in rows} if lang == "ar" else {}
        synthetic = "نص اختباري" if lang == "ar" else "Test"
        return [by_id.get(i) or {field: i, ("spans" if label == "option_feedback" else "label"):
                                 ([{"type": "text", "text": f"{synthetic} {i}"}] if label == "option_feedback"
                                  else f"{synthetic} {i}")} for i in ids]
    typ = exercise["type"]
    return {
        "explanation": spec.explanation if lang == "ar" else [{"type": "text", "text": "Test explanation."}],
        "option_feedback": cover(spec.option_feedback, "option_id", [o["option_id"] for o in payload["options"]],
                                 "option_feedback") if typ == "scenario" else [],
        "event_dates": cover(spec.event_dates, "event_id", [e["event_id"] for e in payload["events"]],
                             "event_dates") if typ == "timeline_order" else [],
        "pin_labels": cover(spec.pin_labels, "pin_id", [p["pin_id"] for p in payload["pins"]],
                            "pin_labels") if typ == "map_place" else [],
    }


def _record(purpose: str, by_lang: dict[str, dict[str, Any]], key: Any, spec: _Specimen | None,
            *, duel: bool = False) -> dict[str, Any]:
    exercise_id = by_lang["ar"]["exercise_id"]
    return {
        "exercise_id": exercise_id, "purpose": purpose,
        "exercise": {lang: {**by_lang[lang], "answer_key": key, "option_misconceptions": {}, "duel_eligible": duel}
                     for lang in LANGS},
        "feedback": {lang: (_feedback(spec, by_lang[lang], lang) if spec else
                            {"explanation": [{"type": "text", "text": "Test explanation."}], "option_feedback": [],
                             "event_dates": [], "pin_labels": []}) for lang in LANGS},
        "targets_misconception_id": None, "source_ids": [],
    }


def _copy_specimen(spec: _Specimen, exercise_id: str, concept_ids: list[str]) -> dict[str, dict[str, Any]]:
    base = {**spec.exercise, "exercise_id": exercise_id, "concept_ids": concept_ids}
    return {"ar": base, "en": _localize(base)}


def _localize(value: Any) -> Any:
    """Synthetic English for synthetic specimen copies (Arabic text -> 'Test text'), ids unchanged."""
    if isinstance(value, dict):
        return {k: (v if k.endswith("_id") or k in ("text_uthmani", "text_ar", "surah_name", "transliteration")
                    else _localize(v)) for k, v in value.items()}
    if isinstance(value, list):
        return [_localize(v) for v in value]
    if isinstance(value, str) and any("؀" <= c <= "ۿ" for c in value):
        return "Test text"
    return value


# ------------------------------------------------------------------------------------- curriculum

def _journeys() -> dict[tuple[str, str], dict[str, Any]]:
    return {(lang, track): _load(CURRICULUM_DIR / f"journey_{lang}_{track}.json")
            for lang in LANGS for track in ("explorer", "new_muslim")}


def _prerequisite_lessons(journeys: dict[tuple[str, str], dict[str, Any]]) -> dict[str, list[str]]:
    prereqs: dict[str, list[str]] = {}
    for journey in journeys.values():
        for unit in journey["units"]:
            for lesson in unit["lessons"]:
                if lesson["soft_lock"]:
                    prereqs[lesson["lesson_id"]] = [r["lesson_id"] for r in lesson["soft_lock"]["prerequisites"]]
    return prereqs


def concept_for(lesson_id: str) -> str:
    return "con_" + lesson_id.removeprefix("les_")


def build_curriculum() -> Curriculum:
    journeys = _journeys()
    units: dict[str, dict[str, Any]] = {}
    for (lang, track), journey in journeys.items():
        for unit in journey["units"]:
            spec = units.setdefault(unit["unit_id"], {
                "unit_id": unit["unit_id"], "index": unit["index"], "tracks": [], "art_key": unit["art_key"],
                "pass_percent": unit["unit_test"]["pass_percent"], "title": {}, "subtitle": {},
                "lessons": [{"slot": f"{unit['index']}.{lesson['index'] + 1}", "lesson_id": lesson["lesson_id"],
                             "working_title": {"en": lesson["title"]}} for lesson in unit["lessons"]]})
            if track not in spec["tracks"]:
                spec["tracks"].append(track)
            spec["title"].setdefault(lang, {})[track] = unit["title"]
            spec["subtitle"].setdefault(lang, {})[track] = unit["subtitle"]
    prereqs = _prerequisite_lessons(journeys)
    concepts = [{"concept_id": "con_test", "unit_id": "unit_test_1", "title": _lt("مفهوم اختباري", "Test concept")}]
    for unit in sorted(units.values(), key=lambda u: u["index"]):
        unit["tracks"] = [t for t in ("explorer", "new_muslim") if t in unit["tracks"]]
        for lesson in unit["lessons"]:
            lesson_id = lesson["lesson_id"]
            concepts.append({"concept_id": concept_for(lesson_id), "unit_id": unit["unit_id"],
                             "title": _lt(f"مفهوم {lesson_id}", f"Concept {lesson_id}"),
                             "prerequisite_ids": [concept_for(p) for p in prereqs.get(lesson_id, [])]})
    return parse_curriculum({"schema": "qabas.curriculum/1", "review_status": "working", "id_scheme": "fixture",
                             "units": sorted(units.values(), key=lambda u: u["index"]), "concepts": concepts})


# ----------------------------------------------------------------------------------------- lessons

def build_packages() -> list[LessonPackage]:
    journeys = _journeys()
    prereqs = _prerequisite_lessons(journeys)
    specimens = _specimens()
    banks = _load(CURRICULUM_DIR / "ASSESSMENT_BANKS.json")
    keys = _load(CURRICULUM_DIR / "PRIVATE_GRADING_KEYS.json")
    assessment: dict[str, dict[str, list[str]]] = {}
    for unit in banks["units"]:
        for lesson in unit["lessons"]:
            assessment[lesson["lesson_id"]] = {"pretest": lesson["pretest"], "unit_test": lesson["unit_test"]}
    lessons_meta: dict[str, dict[str, Any]] = {}
    for (lang, _track), journey in journeys.items():
        for unit in journey["units"]:
            for lesson in unit["lessons"]:
                lessons_meta.setdefault(lesson["lesson_id"], {"unit_id": unit["unit_id"], "index": lesson["index"],
                                                              "titles": {}, "lesson": lesson})
                lessons_meta[lesson["lesson_id"]]["titles"][lang] = lesson["title"]
    packages = []
    for lesson_id, meta in lessons_meta.items():
        packages.append(_package(lesson_id, meta, prereqs.get(lesson_id, []), specimens, assessment, keys))
    return sorted(packages, key=lambda p: (int(p.unit_id.rsplit("_", 1)[1]), p.index))


def _package(lesson_id: str, meta: dict[str, Any], prereq_lessons: list[str], specimens: list[_Specimen],
             assessment: dict[str, dict[str, list[str]]], keys: dict[str, Any]) -> LessonPackage:
    sessions = {(lang, variant): _load(path) for lang in LANGS for variant in ("explorer", "new_muslim")
                if (path := CURRICULUM_DIR / "lessons" / f"{lesson_id}__{lang}_{variant}.json").exists()}
    first = sessions[("ar", "explorer")]
    lesson = meta["lesson"]
    concept = concept_for(lesson_id)
    variants: dict[str, dict[str, Any]] = {}
    exercises: dict[str, dict[str, Any]] = {}
    lesson_exercises: dict[str, dict[str, dict[str, Any]]] = {}
    sentence_ids: list[str] = []
    for (lang, variant), session in sessions.items():
        if session["terms"] or session["sources"]:
            raise FixtureError(f"{lesson_id}: fixture terms/sources need glossary and source records")
        blocks = []
        for block in session["items"]:
            if block["type"] == "exercise":
                exercise = block["exercise"]
                lesson_exercises.setdefault(exercise["exercise_id"], {})[lang] = exercise
                blocks.append({"block_id": block["block_id"], "type": "exercise",
                               "exercise_id": exercise["exercise_id"]})
            else:
                blocks.append(block)
        variants.setdefault(lang, {})[variant] = {"title": session["title"], "subtitle": session["subtitle"],
                                                  "objectives": session["objectives"], "blocks": blocks,
                                                  "completion": session["completion"]}
        for block in blocks:
            sentence_ids += [s["sentence_id"] for s in sentences_of(block) if s["sentence_id"] not in sentence_ids]
    for exercise_id, by_lang in lesson_exercises.items():
        spec = _specimen_for(by_lang["ar"], specimens)
        exercises[exercise_id] = _record("lesson", by_lang, spec.key, spec)
    flashcard = next(s for s in specimens if s.name == "flashcard")
    flashcard_id = f"ex_{lesson_id[4:]}_fc"
    exercises[flashcard_id] = _record("lesson", _copy_specimen(flashcard, flashcard_id, [concept]),
                                                  None, flashcard)
    for purpose in ("pretest", "unit_test"):
        for exercise_id in assessment[lesson_id][purpose]:
            by_lang = {lang: _load(CURRICULUM_DIR / "bank" / f"{exercise_id}__{lang}.json") for lang in LANGS}
            bank_spec = _specimen_for({**by_lang["ar"], "exercise_id": exercise_id}, specimens) \
                if _has_specimen(by_lang["ar"], specimens) else None
            exercises[exercise_id] = _record(purpose, by_lang, keys[exercise_id], bank_spec)
    for k, name in enumerate(("multiple_choice", "true_false", "verse_meaning")):
        spec = next(s for s in specimens if s.name == name)
        duel_id = f"ex_{lesson_id[4:]}_d{k}"
        exercises[duel_id] = _record("duel", _copy_specimen(spec, duel_id, ["con_test"]), spec.key, spec, duel=True)

    blocks = variants["ar"]["explorer"]["blocks"]
    exercise_blocks = [b["block_id"] for b in blocks if b["type"] == "exercise"]
    content_blocks = [b["block_id"] for b in blocks if b["type"] != "exercise"]
    lesson_type = first["lesson_type"]
    first_technique = {"story": "story", "practice": "demonstration"}.get(lesson_type, "explanation")
    graded = sum(1 for b in blocks if b["type"] == "exercise"
                 and exercises[b["exercise_id"]]["exercise"]["ar"]["scoring"]["accuracy"])
    objectives = [_lt(_spans_text(o), _spans_text(sessions[("en", "explorer")]["objectives"][i]))
                  for i, o in enumerate(first["objectives"])]
    plan = {
        "title": _lt(meta["titles"]["ar"], meta["titles"]["en"]),
        "central_question": _lt("سؤال اختباري؟", "Test central question?"),
        "primary_learning_outcome": _lt("نتيجة تعلم اختبارية.", "Test learning outcome."),
        "supporting_understandings": [], "depth_profile": "standard", "objectives": objectives,
        "prerequisite_concept_ids": [concept_for(p) for p in prereq_lessons], "introduced_concept_ids": [concept],
        "new_terms": [], "target_misconceptions": [], "lesson_type": lesson_type,
        "estimated_minutes": lesson["estimated_minutes"],
        "lesson_arc": {"pattern": "test", "rationale": _lt("مسار اختباري.", "Test arc."), "steps": [
            {"step_id": "a1", "technique": first_technique, "experience": _lt("تعلّم.", "Learn."), "interactive": False},
            {"step_id": "a2", "technique": "practice", "experience": _lt("تدرّب.", "Practise."), "interactive": True}]},
        "reasoning_tools": [], "standalone_eligible": lesson["standalone_eligible"],
        "content_budget": max(1, len(content_blocks)), "exercise_budget": min(6, max(2, graded)),
    }
    sources = _embedded_sources([e["exercise"]["ar"] for e in exercises.values()])
    return LessonPackage.model_validate({
        "lesson_id": lesson_id, "unit_id": meta["unit_id"], "index": meta["index"], "plan": plan,
        "variants": variants, "claims": [],
        "sentence_map": [{"sentence_id": s, "role": "framing", "claim_ids": []} for s in sentence_ids],
        "arc_map": [{"step_id": "a1", "block_ids": content_blocks}, {"step_id": "a2", "block_ids": exercise_blocks}],
        "exercises": list(exercises.values()), "glossary": [], "misconceptions": [], "sources": sources,
    })


def _embedded_sources(exercises: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Source records for evidence embedded in exercise payloads, derived from that evidence itself."""
    found: dict[str, dict[str, Any]] = {}

    def walk(node: Any) -> None:
        if isinstance(node, dict):
            if "evidence_id" in node and node.get("kind") in ("quran", "hadith"):
                if node["kind"] == "quran":
                    q = node["quran"]
                    record = {"kind": "quran", "provider": "quran_com", "title": q["surah_name"],
                              "reference": f"{q['surah_name']}: {q['ayah_start']}"
                                           + (f"-{q['ayah_end']}" if q["ayah_end"] != q["ayah_start"] else ""),
                              "excerpt": q["text_uthmani"], "url": f"https://quran.com/{q['surah']}/{q['ayah_start']}"}
                else:
                    h = node["hadith"]
                    record = {"kind": "hadith", "provider": "dorar", "title": ", ".join(h["collections"]),
                              "reference": h["grade_source"], "excerpt": h["text_ar"], "url": None}
                found.setdefault(node["evidence_id"], {"source_id": node["evidence_id"], **record})
            for value in node.values():
                walk(value)
        elif isinstance(node, list):
            for value in node:
                walk(value)

    walk(exercises)
    return list(found.values())


def _has_specimen(exercise: dict[str, Any], specimens: list[_Specimen]) -> bool:
    wanted = (exercise["type"], exercise["payload"])
    return any((s.exercise["type"], s.exercise["payload"]) == wanted for s in specimens)


# ------------------------------------------------------------------------------------------ scenes

def scene_manifests() -> list[tuple[Path, dict[str, Any]]]:
    return [(path, _load(path)) for path in sorted(SCENES_DIR.glob("*.scene.json"))]


async def load_scenes(db: AsyncSession, packages: list[LessonPackage]) -> int:
    """Register the fixture scenes the test lessons reference as published test scene versions."""
    refs = {}
    for package in packages:
        for by in package.variants.values():
            for content in by.values():
                for visual in _visuals(content.blocks):
                    if visual.get("kind") == "scene":
                        refs[(visual["scene"]["scene_id"], visual["scene"]["version"])] = visual
    count = 0
    for (scene_id, version), visual in refs.items():
        if await db.get(SceneVersion, (scene_id, version)):
            continue
        path, manifest = next(((p, m) for p, m in scene_manifests()
                               if (m.get("scene_id"), m.get("version")) == (scene_id, version)), (None, None))
        if path is None or manifest is None:
            raise FixtureError(f"no fixture manifest for scene {scene_id} v{version}")
        raw = path.read_bytes()
        if hashlib.sha256(raw).hexdigest() != visual["scene"]["sha256"]:
            raise FixtureError(f"{scene_id} v{version}: manifest bytes do not match the SceneRef sha256")
        db.add(SceneVersion(scene_id=scene_id, version=version, manifest_url=visual["scene"]["url"],
                            sha256=visual["scene"]["sha256"], bytes=len(raw), view_box=visual["scene"]["view_box"],
                            states=manifest.get("states", {}),
                            required_capabilities=list(manifest.get("required_capabilities", [])),
                            anchors=manifest.get("anchors", []), fallback_image=visual["fallback_image"],
                            status="published", published_at=datetime.now(UTC)))
        count += 1
    return count


def _visuals(node: Any) -> list[dict[str, Any]]:
    found = []
    if isinstance(node, dict):
        if node.get("kind") in ("builtin", "image", "scene") and "alt" in node:
            found.append(node)
        for value in node.values():
            found += _visuals(value)
    elif isinstance(node, list):
        for value in node:
            found += _visuals(value)
    return found


async def load_test_curriculum(db: AsyncSession, settings: Settings) -> dict[str, int]:
    """Seed and publish the whole test curriculum (caller owns the transaction)."""
    if not settings.is_dev_like:
        raise FixtureError("the test curriculum is test data; it is never loaded into staging or production")
    from app.content.store import apply_curriculum

    await apply_curriculum(db, build_curriculum())
    packages = build_packages()
    await load_scenes(db, packages)
    published = 0
    for package in packages:
        result = await import_package(db, package, origin="test_fixture", allow_placeholder_media=True)
        if result.created:
            await publish(db, settings, result.lesson_version_id, FixtureApproval())
            published += 1
    existing = (await db.execute(select(SceneVersion))).scalars().all()
    return {"lessons": len(packages), "published": published, "scenes": len(existing)}
