"""Gold lessons end to end (factory §13.6-13.7): import unpublished, authenticated digest-bound approval and
publication in one transaction, rejection, and the CLI conversion report."""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path
from typing import Any

import pytest
from sqlalchemy import select

from app.content.gold import (
    GoldError,
    GoldFile,
    Provenance,
    approve_and_publish,
    authenticate_reviewer,
    import_gold,
    read_gold,
    reject,
    write_gold,
)
from app.content.package import LessonPackage
from app.content.store import apply_curriculum
from app.content.test_curriculum import build_curriculum, build_packages
from app.models import Lesson, LessonVersion, ReviewDecision, User
from app.runtime import Resources
from app.services.platform import passwords
from tests.content.test_unit0_converter import record
from tests.sources.synthetic import mushaf

pytestmark = pytest.mark.integration
PASSWORD = "a long reviewer passphrase"
BACKEND = Path(__file__).resolve().parents[2]
TRANSLATION_TEST_MANIFEST = Path("test-manifest-not-configured")


@pytest.fixture(autouse=True)
def canonical_test_sources(tmp_path: Path, monkeypatch: Any) -> None:
    """Neutral canonical data and a test-only specialist choice; no production fixture exception."""
    import app.sources.gold as verifier
    from tests.sources.test_scripture import manifest
    path = manifest(tmp_path)
    monkeypatch.setattr(verifier, "get_mushaf", lambda settings: mushaf())
    monkeypatch.setattr(verifier, "TRANSLATIONS", path)
    monkeypatch.setattr(sys.modules[__name__], "TRANSLATION_TEST_MANIFEST", path, raising=False)


def production_like(package: LessonPackage, title_suffix: str = "") -> LessonPackage:
    """A media-free gold shape using compiled visuals and untimed assessments (D-61).

    URL strings alone are not production media. The dedicated media tests upload and review real bytes.
    """
    data = json.loads(json.dumps(package.model_dump(mode="json")).replace("mock-asset://", "https://cdn.qabas.app/"))
    def compiled(node: Any) -> None:
        if isinstance(node, dict):
            if node.get("kind") == "image" and "alt" in node and "overlays" in node:
                node.update(kind="builtin", key="workplace", version=1, params={}, image=None)
            if "pronunciation_audio_url" in node:
                node["pronunciation_audio_url"] = None
            if "narration_audio_url" in node:
                node["narration_audio_url"] = None
            for child in node.values():
                compiled(child)
        elif isinstance(node, list):
            for child in node:
                compiled(child)
    compiled(data)
    for exercise in data["exercises"]:
        if exercise["purpose"] != "duel":
            for lang in ("ar", "en"):
                exercise["exercise"][lang]["time_limit_ms"] = None
    for by in data["variants"].values():
        for variant in by.values():
            variant["title"] += title_suffix
    return LessonPackage.model_validate(data)


def gold(title_suffix: str = "") -> GoldFile:
    package = next(p for p in build_packages() if p.lesson_id == "les_t1_0")
    from dataclasses import replace

    from app.sources.scripture import insert
    from app.sources.store import source_id
    from tests.sources.test_scripture import translation
    data = production_like(package, title_suffix).model_dump(mode="json")
    canonical = mushaf()
    records, sources = {}, {}
    for ayah in (1, 2):
        selected = translation()
        selected = replace(selected, provider_record_id=f"fixture_key:1:{ayah}", reference=f"1:{ayah}",
                           data={**selected.data, "arabic_text": canonical.get(1, ayah).text_uthmani})
        inserted = insert(canonical, 1, (ayah, ayah), translations=(selected,),
                          translation_manifest=TRANSLATION_TEST_MANIFEST)
        identifier, source = inserted.evidence.evidence_id, inserted.source
        records[identifier] = source
        records[source_id(selected)] = selected
        sources[identifier] = {"source_id": identifier, "kind": source.kind, "provider": source.provider,
                               "title": source.title, "reference": source.reference, "excerpt": source.text,
                               "url": source.url}
    for language, variants in data["variants"].items():
        for variant in variants.values():
            def walk(node: Any, language: str = language) -> None:
                if isinstance(node, dict):
                    if node.get("kind") == "quran" and node.get("quran"):
                        ayah = node["quran"]["ayah_start"]
                        selected = translation()
                        selected = replace(selected, provider_record_id=f"fixture_key:1:{ayah}", reference=f"1:{ayah}",
                                           data={**selected.data, "arabic_text": canonical.get(1, ayah).text_uthmani})
                        inserted = insert(canonical, 1, (ayah, ayah), language=language,
                                          translations=(selected,),
                                          translation_manifest=TRANSLATION_TEST_MANIFEST)
                        node.update(inserted.evidence.model_dump(mode="json"))
                        identifier, source = node["evidence_id"], inserted.source
                        records[identifier] = source
                        for item in inserted.records:
                            records[source_id(item)] = item
                        sources[identifier] = {"source_id": identifier, "kind": source.kind,
                            "provider": source.provider, "title": source.title, "reference": source.reference,
                            "excerpt": source.text, "url": source.url}
                    for value in node.values():
                        walk(value, language)
                elif isinstance(node, list):
                    for value in node:
                        walk(value, language)
            walk(variant)
    for exercise in data["exercises"]:
        for language, item in exercise["exercise"].items():
            walk(item, language)
    replacements = {f"src_q_112_{ayah}": next(identifier for identifier, source in records.items()
                                              if source.provider == "quran_com"
                                              and source.parts[0].record_id == f"1:{ayah}")
                    for ayah in (1, 2)}
    def relink(node: Any) -> Any:
        if isinstance(node, str):
            return replacements.get(node, node)
        if isinstance(node, list):
            return [relink(value) for value in node]
        if isinstance(node, dict):
            return {key: relink(value) for key, value in node.items()}
        return node
    data = relink(data)
    data["sources"] = list(sources.values())
    return GoldFile(provenance=Provenance(source="handwritten", notes=["test"]),
                    lesson=LessonPackage.model_validate(data), source_records=records)


async def _reviewer(db: Any, *, active: bool = True, email: str = "specialist@example.test") -> str:
    from datetime import UTC, datetime
    user = User(id="usr_specialist" + ("" if active else "_off"), display_name="Specialist", avatar_key="traveler_01",
                timezone="UTC", role="reviewer", email=email, password_hash=passwords.hash_password(PASSWORD),
                onboarding_completed=True, deactivated_at=None if active else datetime.now(UTC))
    db.add(user)
    await db.flush()
    return user.id


def test_gold_files_round_trip(tmp_path: Path) -> None:
    path = tmp_path / "les_t1_0.json"
    write_gold(path, gold())
    assert read_gold(path).lesson.digest() == gold().lesson.digest()
    path.write_text(json.dumps({"schema": "qabas.gold/0"}), encoding="utf-8")
    with pytest.raises(GoldError, match=r"not a qabas\.gold/1 gold file"):
        read_gold(path)


async def test_import_approve_publish_and_reject(resources: Resources) -> None:
    settings = resources.settings
    async with resources.sessionmaker() as db, db.begin():
        await apply_curriculum(db, build_curriculum())
        reviewer = await _reviewer(db)
        inactive = await _reviewer(db, active=False, email="former@example.test")
        first = await import_gold(db, gold())
        assert first.created and (await import_gold(db, gold())).created is False      # identical: no-op
    digest = gold().lesson.digest()
    async with resources.sessionmaker() as db:
        lesson = await db.get(Lesson, "les_t1_0")
        version = await db.get(LessonVersion, first.lesson_version_id)
        assert lesson is not None and lesson.is_gold and lesson.current_version is None    # never published here
        assert version is not None and version.origin == "gold_import" and version.content_sha256 == digest

    async with resources.sessionmaker() as db, db.begin():
        with pytest.raises(GoldError, match="authentication failed"):
            await authenticate_reviewer(db, "specialist@example.test", "wrong")
        assert await authenticate_reviewer(db, "SPECIALIST@example.test", PASSWORD) == reviewer
        with pytest.raises(GoldError, match="active reviewer"):
            await approve_and_publish(db, settings, reviewer_id=inactive, lesson_id="les_t1_0", version=1,
                                      reviewed_digest=digest)
        with pytest.raises(GoldError, match="reviewed digest does not match"):
            await approve_and_publish(db, settings, reviewer_id=reviewer, lesson_id="les_t1_0", version=1,
                                      reviewed_digest="0" * 64)
    async with resources.sessionmaker() as db, db.begin():
        decision_id = await approve_and_publish(db, settings, reviewer_id=reviewer, lesson_id="les_t1_0", version=1,
                                                reviewed_digest=digest)
    async with resources.sessionmaker() as db:
        decision = await db.get(ReviewDecision, decision_id)
        assert decision is not None and (decision.decision, decision.gate) == ("approve", 2)
        assert decision.reviewed_digest == decision.published_digest == digest
        lesson = await db.get(Lesson, "les_t1_0")
        assert lesson is not None and lesson.current_version == 1
        version = await db.get(LessonVersion, first.lesson_version_id)
        assert version is not None and version.reviewed_by == "Specialist" and version.published_at is not None
    async with resources.sessionmaker() as db, db.begin():
        with pytest.raises(GoldError, match="already published"):
            await approve_and_publish(db, settings, reviewer_id=reviewer, lesson_id="les_t1_0", version=1,
                                      reviewed_digest=digest)

    revised = gold(" (revised)")
    async with resources.sessionmaker() as db, db.begin():
        second = await import_gold(db, revised)
        assert second.version == 2
        await reject(db, reviewer_id=reviewer, lesson_id="les_t1_0", version=2, reviewed_digest=revised.lesson.digest(),
                     reason="Title change not approved.")
    async with resources.sessionmaker() as db:
        decisions = (await db.execute(select(ReviewDecision).order_by(ReviewDecision.decided_at))).scalars().all()
        assert [d.decision for d in decisions] == ["approve", "reject"] and decisions[1].published_digest is None
        assert decisions[1].reason == "Title change not approved."
        lesson = await db.get(Lesson, "les_t1_0")
        assert lesson is not None and lesson.current_version == 1                            # still the approved one
    # A recorded decision is final: the rejected version can never be approved later (a correction is v3).
    async with resources.sessionmaker() as db:
        with pytest.raises(GoldError, match="already decided"):
            async with db.begin():
                await approve_and_publish(db, settings, reviewer_id=reviewer, lesson_id="les_t1_0", version=2,
                                          reviewed_digest=revised.lesson.digest())


@pytest.mark.parametrize("corruption", ["text", "range", "english_translation", "provenance"])
async def test_gold_rejects_scripture_corruption_before_any_source_or_lesson_write(
        resources: Resources, corruption: str) -> None:
    from sqlalchemy import func

    from app.models import Source
    candidate = gold()
    data = candidate.dump()
    language = "en" if corruption == "english_translation" else "ar"
    def corrupt(node: Any) -> bool:
        if isinstance(node, dict):
            if node.get("kind") == "quran" and node.get("quran"):
                value = node["quran"]
                if corruption == "text":
                    value["text_uthmani"] = "Different neutral text"
                elif corruption == "range":
                    value["segment"] = {"word_start": 1, "word_end": 999}
                elif corruption == "english_translation":
                    value["translation"] = None
                return True
            return any(corrupt(value) for value in node.values())
        if isinstance(node, list):
            return any(corrupt(value) for value in node)
        return False
    assert corrupt([exercise["exercise"][language] for exercise in data["lesson"]["exercises"]])
    if corruption == "provenance":
        data["source_records"] = {}
    refused = GoldFile.model_validate(data)
    with pytest.raises(GoldError, match="verification failed"):
        async with resources.sessionmaker() as db, db.begin():
            await apply_curriculum(db, build_curriculum())
            await import_gold(db, refused)
    async with resources.sessionmaker() as db:
        assert (await db.execute(select(func.count()).select_from(Source))).scalar_one() == 0
        assert (await db.execute(select(func.count()).select_from(LessonVersion))).scalar_one() == 0


async def test_test_fixture_content_never_takes_the_gold_path(resources: Resources) -> None:
    from app.content.store import import_package
    async with resources.sessionmaker() as db, db.begin():
        await apply_curriculum(db, build_curriculum())
        reviewer = await _reviewer(db)
        package = next(p for p in build_packages() if p.lesson_id == "les_t1_0")
        result = await import_package(db, package, origin="test_fixture", allow_placeholder_media=True)
        with pytest.raises(GoldError, match="not a gold import"):
            await approve_and_publish(db, resources.settings, reviewer_id=reviewer, lesson_id="les_t1_0",
                                      version=result.version, reviewed_digest=package.digest())


async def test_gold_publication_requires_actual_reviewed_media_not_only_a_plausible_https_url(
    resources: Resources,
) -> None:
    from sqlalchemy import func

    from app.content.validation import ContentValidationError
    candidate = gold()
    data = candidate.lesson.model_dump(mode="json")
    def replace_visual(node: Any) -> bool:
        if isinstance(node, dict):
            if node.get("kind") == "builtin" and "alt" in node:
                node.update(kind="image", key=None, version=None, params=None,
                            image={"url": "https://cdn.qabas.app/unverified.webp", "mime_type": "image/webp",
                                   "width": 1600, "height": 1000})
                return True
            return any(replace_visual(value) for value in node.values())
        if isinstance(node, list):
            return any(replace_visual(value) for value in node)
        return False
    assert replace_visual(data["variants"]["ar"])
    assert replace_visual(data["variants"]["en"])
    candidate = candidate.model_copy(update={"lesson": LessonPackage.model_validate(data)})
    async with resources.sessionmaker() as db, db.begin():
        await apply_curriculum(db, build_curriculum())
        reviewer = await _reviewer(db)
        imported = await import_gold(db, candidate)
    with pytest.raises(ContentValidationError, match="production media verification"):
        async with resources.sessionmaker() as db, db.begin():
            await approve_and_publish(db, resources.settings, reviewer_id=reviewer,
                                      lesson_id=candidate.lesson.lesson_id,
                                      version=imported.version, reviewed_digest=candidate.lesson.digest())
    async with resources.sessionmaker() as db:
        assert await db.scalar(select(func.count()).select_from(ReviewDecision)) == 0
        version = await db.get(LessonVersion, imported.lesson_version_id)
        assert version is not None and version.published_at is None


def test_the_convert_command_reports_blockers_and_writes_only_ready_lessons(tmp_path: Path) -> None:
    source, out = tmp_path / "lessons", tmp_path / "gold"
    source.mkdir()
    (source / "u0_l01.json").write_text(json.dumps(record(), ensure_ascii=False), encoding="utf-8")
    report = tmp_path / "report.json"
    completed = subprocess.run([sys.executable, "scripts/import_gold.py", "convert", "unit0", "--source", str(source),
                                "--out", str(out), "--report", str(report)], cwd=BACKEND, capture_output=True,
                               text=True, encoding="utf-8", check=False)
    assert completed.returncode == 2, completed.stderr                 # the committed mapping is pending (D-40)
    data = json.loads(report.read_text(encoding="utf-8"))
    assert data["lessons"][0]["ready"] is False
    assert {"reasoning_tool_unmapped", "concept_unregistered"} <= set(data["blocker_counts"])
    assert not out.exists() or not any(out.iterdir())                  # nothing written for a blocked lesson
