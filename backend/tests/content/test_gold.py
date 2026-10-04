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

pytestmark = pytest.mark.integration
PASSWORD = "a long reviewer passphrase"
BACKEND = Path(__file__).resolve().parents[2]


def production_like(package: LessonPackage, title_suffix: str = "") -> LessonPackage:
    """A real-content shape: hosted https media and untimed lesson/assessment items (D-61)."""
    data = json.loads(json.dumps(package.model_dump(mode="json")).replace("mock-asset://", "https://cdn.qabas.app/"))
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
    return GoldFile(provenance=Provenance(source="handwritten", notes=["test"]),
                    lesson=production_like(package, title_suffix))


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
