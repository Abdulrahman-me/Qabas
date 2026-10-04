"""Curriculum seeding, content import and publication against the real test database."""

from __future__ import annotations

import copy
import json
from typing import Any

import pytest
from sqlalchemy import select, text
from sqlalchemy.exc import DBAPIError

from app.content.curriculum import CurriculumError, load_curriculum, parse_curriculum
from app.content.package import LessonPackage
from app.content.projection import (
    counts,
    project_sources,
    reader_blocks,
    resolve_items,
    select_variant,
    source_count,
    term_card,
)
from app.content.store import Approval, FixtureApproval, apply_curriculum, import_package, load_package, publish
from app.content.test_curriculum import CURRICULUM_DIR, build_curriculum, build_packages, load_test_curriculum
from app.content.validation import ContentValidationError
from app.contract import models as C
from app.models import Concept, Exercise, Lesson, LessonVersion, ReviewDecision, Unit, User
from app.runtime import Resources
from tests.support.db import sqlstate

pytestmark = pytest.mark.integration


async def _load(resources: Resources) -> dict[str, int]:
    async with resources.sessionmaker() as db, db.begin():
        return await load_test_curriculum(db, resources.settings)


# --- production curriculum seed -------------------------------------------------------------------------

async def test_production_seed_is_idempotent_and_creates_no_lessons(resources: Resources) -> None:
    async with resources.sessionmaker() as db, db.begin():
        first = await apply_curriculum(db, load_curriculum())
    assert first.created == {"units": 11, "slots": 93, "concepts": 0}
    async with resources.sessionmaker() as db, db.begin():
        assert not (await apply_curriculum(db, load_curriculum())).changed
    async with resources.sessionmaker() as db:
        units = (await db.execute(select(Unit).order_by(Unit.index))).scalars().all()
        assert all(u.coming_soon for u in units)                       # nothing published yet
        assert units[0].tracks == ["explorer"] and units[1].tracks == ["explorer", "new_muslim"]
        assert await db.scalar(select(text("count(*)")).select_from(Lesson)) == 0


async def test_seed_refuses_destructive_changes(resources: Resources) -> None:
    await _load(resources)
    cur = build_curriculum().model_dump(by_alias=True, mode="json")
    moved = copy.deepcopy(cur)
    moved["units"][0]["lessons"].reverse()          # would move occupied slots
    for i, slot in enumerate(moved["units"][0]["lessons"]):
        slot["slot"] = f"0.{i + 1}"
    dropped = copy.deepcopy(cur)
    dropped["units"] = dropped["units"][1:]          # would drop a unit with lessons
    gone = {c["concept_id"] for c in dropped["concepts"] if c["unit_id"] == cur["units"][0]["unit_id"]}
    dropped["concepts"] = [{**c, "prerequisite_ids": [p for p in c["prerequisite_ids"] if p not in gone]}
                           for c in dropped["concepts"] if c["concept_id"] not in gone]
    retracked = copy.deepcopy(cur)
    retracked["units"][0]["tracks"] = ["explorer", "new_muslim"]
    for track_map in (retracked["units"][0]["title"], retracked["units"][0]["subtitle"]):
        for lang in track_map:
            track_map[lang]["new_muslim"] = track_map[lang]["explorer"]
    for broken, message in ((moved, "cannot be moved or removed"), (dropped, "not in the curriculum file"),
                            (retracked, "tracks cannot change")):
        async with resources.sessionmaker() as db:
            with pytest.raises(CurriculumError, match=message):
                async with db.begin():
                    await apply_curriculum(db, parse_curriculum(broken))


# --- the test curriculum through the real pipeline --------------------------------------------------------

async def test_test_curriculum_publishes_through_the_pipeline(resources: Resources) -> None:
    result = await _load(resources)
    assert result == {"lessons": 10, "published": 10, "scenes": 1}
    async with resources.sessionmaker() as db:
        lessons = (await db.execute(select(Lesson).order_by(Lesson.unit_id, Lesson.index))).scalars().all()
        assert all(lesson.current_version == 1 for lesson in lessons)
        units = {u.id: u for u in (await db.execute(select(Unit))).scalars()}
        assert [units[f"unit_test_{i}"].coming_soon for i in range(1, 5)] == [False, False, False, True]
        intro = {c.id: c.introduced_by_lesson_id for c in (await db.execute(select(Concept))).scalars()}
        assert intro["con_t1_0"] == "les_t1_0" and intro["con_test"] is None
        t3 = await db.get(Lesson, "les_t3_0")
        assert t3 is not None and t3.prerequisite_concept_ids == ["con_t2_3"] and not t3.standalone_eligible
        exercises = (await db.execute(select(Exercise))).scalars().all()
        assert all(e.current_version == 1 for e in exercises)
        assert {e.purpose for e in exercises} == {"lesson", "pretest", "unit_test", "duel"}
        versions = (await db.execute(select(LessonVersion))).scalars().all()
        assert {v.origin for v in versions} == {"test_fixture"}
        assert all(v.reviewed_by == "test fixture" for v in versions)
    assert (await _load(resources))["published"] == 0      # identical content: no new versions


async def test_storage_is_lossless(resources: Resources) -> None:
    await _load(resources)
    built = {p.lesson_id: p for p in build_packages()}
    async with resources.sessionmaker() as db:
        for lv in (await db.execute(select(LessonVersion))).scalars().all():
            stored = await load_package(db, lv.id)
            assert stored.digest() == built[lv.lesson_id].digest() == lv.content_sha256


def _session_files() -> list[tuple[str, str, str]]:
    return sorted((p.name.split("__")[0], *p.stem.split("__")[1].split("_", 1))  # type: ignore[misc]
                  for p in (CURRICULUM_DIR / "lessons").glob("*.json"))


@pytest.mark.parametrize(("lesson_id", "lang", "variant"), _session_files())
def test_projection_reproduces_the_contract_sessions(lesson_id: str, lang: str, variant: str) -> None:
    package = next(p for p in build_packages() if p.lesson_id == lesson_id)
    session_file = CURRICULUM_DIR / "lessons" / f"{lesson_id}__{lang}_{variant}.json"
    session = json.loads(session_file.read_text(encoding="utf-8"))
    items = resolve_items(package, lang, variant)
    content = package.variants[lang][variant]  # type: ignore[index]
    assert items == session["items"]
    assert (content.title, content.subtitle) == (session["title"], session["subtitle"])
    assert content.model_dump(mode="json")["objectives"] == session["objectives"]
    assert (content.completion.model_dump(mode="json") if content.completion else None) == session["completion"]
    sources = project_sources(package, items)
    assert sources == session["sources"] and source_count(sources) == session["source_count"]
    assert counts(items) == session["counts"]
    assert all(b["type"] != "exercise" for b in reader_blocks(items))
    assert "answer_key" not in json.dumps(items)                  # keys never reach a learner payload


def test_term_cards_use_the_contract_projection() -> None:
    spans = {"ar": [{"type": "text", "text": "تعريف"}], "en": [{"type": "text", "text": "A definition"}]}
    record = C.StoredGlossaryTerm.model_validate({
        "term_id": "term_x", "text": {"ar": "مصطلح", "en": "Term"}, "arabic": "مصطلح", "transliteration": "mustalah",
        "definition": {"basic": spans, "intermediate": None}, "example": spans, "concept_id": None,
        "lesson_id": "les_t1_0", "source_id": None, "pronunciation_audio_url": None})
    card = term_card(record, "en", state="learning", level="intermediate", lesson_title="Lesson")
    assert card["text"] == "Term" and card["arabic"] == "مصطلح" and card["state"] == "learning"
    assert card["definition"] == spans["en"]          # no intermediate definition: the basic one is served
    assert card["lesson_title"] == "Lesson" and card["level"] == "intermediate"


def test_variant_choice() -> None:
    assert select_variant({"explorer", "new_muslim"}, "new_muslim") == "new_muslim"
    assert select_variant({"explorer"}, "new_muslim") == "explorer"     # fallback to the attributed framing
    assert select_variant({"explorer", "new_muslim"}, "explorer") == "explorer"


# --- versioning, approval, prerequisites, placement ---------------------------------------------------------

def _changed(package: LessonPackage) -> LessonPackage:
    data = package.model_dump(mode="json")
    for by in data["variants"].values():
        for content in by.values():
            content["title"] += " (revised)"
    return LessonPackage.model_validate(data)


async def test_changed_content_is_a_new_version_and_old_versions_stay_immutable(resources: Resources) -> None:
    await _load(resources)
    package = next(p for p in build_packages() if p.lesson_id == "les_t1_0")
    async with resources.sessionmaker() as db, db.begin():
        result = await import_package(db, _changed(package), origin="test_fixture", allow_placeholder_media=True)
    assert (result.version, result.created) == (2, True)
    async with resources.sessionmaker() as db:
        lesson = await db.get(Lesson, "les_t1_0")
        assert lesson is not None and lesson.current_version == 1       # drafts are never served
    async with resources.sessionmaker() as db, db.begin():
        await publish(db, resources.settings, result.lesson_version_id, FixtureApproval())
    async with resources.sessionmaker() as db:
        lesson = await db.get(Lesson, "les_t1_0")
        assert lesson is not None and lesson.current_version == 2
        with pytest.raises(DBAPIError) as exc:
            await db.execute(text("UPDATE lesson_versions SET reviewed_by = 'x' "
                                  "WHERE lesson_id = 'les_t1_0' AND version = 1"))
        assert sqlstate(exc.value) == "QB001"


async def test_fixture_content_never_publishes_outside_dev_or_test(resources: Resources) -> None:
    async with resources.sessionmaker() as db, db.begin():
        await apply_curriculum(db, build_curriculum())
    package = build_packages()[0]
    staging = resources.settings.model_copy(update={"app_env": "staging"})
    async with resources.sessionmaker() as db:
        with pytest.raises(ContentValidationError, match="fixture approval applies only"):
            async with db.begin():
                result = await import_package(db, package, origin="test_fixture", allow_placeholder_media=True)
                await publish(db, staging, result.lesson_version_id, FixtureApproval())


async def test_reviewer_approval_is_bound_to_the_digest(resources: Resources) -> None:
    async with resources.sessionmaker() as db, db.begin():
        await apply_curriculum(db, build_curriculum())
        db.add(User(id="usr_reviewer1", display_name="Reviewer", avatar_key="traveler_01", timezone="UTC",
                    role="reviewer", email="r@example.test", password_hash="argon2id$x"))
    package = build_packages()[0]
    async with resources.sessionmaker() as db, db.begin():
        # A gold import must pass the media gate, so this one uses real-looking https media.
        data = json.loads(json.dumps(package.model_dump(mode="json")).replace("mock-asset://", "https://cdn.qabas.app/"))
        result = await import_package(db, LessonPackage.model_validate(data), origin="gold_import")
        lv = await db.get(LessonVersion, result.lesson_version_id)
        assert lv is not None
        stale = ReviewDecision(lesson_version_id=lv.id, gate=2, decision="approve", reviewer_id="usr_reviewer1",
                               reviewed_digest="0" * 64)
        good = ReviewDecision(lesson_version_id=lv.id, gate=2, decision="approve", reviewer_id="usr_reviewer1",
                              reviewed_digest=lv.content_sha256)
        db.add_all([stale, good])
    async with resources.sessionmaker() as db:
        with pytest.raises(ContentValidationError, match="Gate 2 approval of exactly this content digest"):
            async with db.begin():
                await publish(db, resources.settings, result.lesson_version_id, Approval(stale.id))
    async with resources.sessionmaker() as db, db.begin():
        await publish(db, resources.settings, result.lesson_version_id, Approval(good.id))
    async with resources.sessionmaker() as db:
        lv = await db.get(LessonVersion, result.lesson_version_id)
        assert lv is not None and lv.reviewed_by == "Reviewer" and lv.published_at is not None


async def test_prerequisites_must_be_published_first(resources: Resources) -> None:
    async with resources.sessionmaker() as db, db.begin():
        await apply_curriculum(db, build_curriculum())
    dependent = next(p for p in build_packages() if p.lesson_id == "les_t1_1")   # needs con_t1_0
    async with resources.sessionmaker() as db:
        with pytest.raises(ContentValidationError, match="not introduced by a published lesson"):
            async with db.begin():
                result = await import_package(db, dependent, origin="test_fixture", allow_placeholder_media=True)
                await publish(db, resources.settings, result.lesson_version_id, FixtureApproval())


async def test_a_unit_opens_only_when_its_assessment_pools_can_be_served(resources: Resources) -> None:
    # Backend §6.2: pretest needs >= 6 items, unit test >= 9; each lesson supplies 2 + 3 (decision D-38).
    async with resources.sessionmaker() as db, db.begin():
        await apply_curriculum(db, build_curriculum())
    unit_lessons = [p for p in build_packages() if p.unit_id == "unit_test_1"]
    assert len(unit_lessons) == 3
    states = []
    for package in unit_lessons:
        async with resources.sessionmaker() as db, db.begin():
            result = await import_package(db, package, origin="test_fixture", allow_placeholder_media=True)
            await publish(db, resources.settings, result.lesson_version_id, FixtureApproval())
        async with resources.sessionmaker() as db:
            unit = await db.get(Unit, "unit_test_1")
            assert unit is not None
            states.append(unit.coming_soon)
    assert states == [True, True, False]                 # pools 2/3, 4/6, then 6/9
    async with resources.sessionmaker() as db, db.begin():
        assert not (await apply_curriculum(db, build_curriculum())).changed   # re-seeding keeps it open
    async with resources.sessionmaker() as db:
        unit = await db.get(Unit, "unit_test_1")
        assert unit is not None and not unit.coming_soon


async def test_content_must_sit_in_its_declared_slot(resources: Resources) -> None:
    async with resources.sessionmaker() as db, db.begin():
        await apply_curriculum(db, build_curriculum())
    package = build_packages()[0]
    for change, message in (({"lesson_id": "les_unknown"}, "is not a curriculum slot"),
                            ({"index": 2}, "sits at unit_test_1 position 0")):
        moved = LessonPackage.model_validate({**package.model_dump(mode="json"), **change})
        async with resources.sessionmaker() as db:
            with pytest.raises(ContentValidationError, match=message):
                async with db.begin():
                    await import_package(db, moved, origin="test_fixture", allow_placeholder_media=True)


async def test_lessons_exist_only_in_slots_and_exercise_identity_is_fixed(resources: Resources) -> None:
    await _load(resources)
    async with resources.sessionmaker() as db:
        for sql, state in (
            ("INSERT INTO lessons (id, unit_id, index, lesson_type, estimated_minutes) "
             "VALUES ('les_rogue', 'unit_test_1', 7, 'concept', 8)", "23503"),
            ("UPDATE exercises SET type = 'scenario' WHERE id = (SELECT id FROM exercises WHERE type = "
             "'multiple_choice' AND purpose = 'lesson' LIMIT 1)", "QB006"),
        ):
            with pytest.raises(DBAPIError) as exc:
                async with db.begin():
                    await db.execute(text(sql))
            assert sqlstate(exc.value) == state, sql


def test_ids_are_unique_across_the_built_packages() -> None:
    ids: dict[str, Any] = {}
    for package in build_packages():
        for record in package.exercises:
            assert record.exercise_id not in ids, record.exercise_id
            ids[record.exercise_id] = package.lesson_id
