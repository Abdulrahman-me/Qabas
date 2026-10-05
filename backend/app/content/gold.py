"""Gold lessons: import, specialist approval and publication (factory §13.6-13.7, SEED_AND_IMPORT).

A **gold file** holds one handwritten (or converted) lesson in the stored content schema - exactly a
:class:`~app.content.package.LessonPackage` - plus its provenance::

    {"schema": "qabas.gold/1", "provenance": {...}, "lesson": <LessonPackage>}

* :func:`import_gold` stores it as the next **unpublished** version (``origin = gold_import``) through Phase 4's
  ``import_package``, so every validator, slot-placement and concept-registration check applies; the lesson is
  marked ``is_gold``. Identical content is a no-op. Nothing here can publish.
* :func:`approve_and_publish` is the Gate 2-equivalent decision of §13.7: an authenticated, active reviewer
  approves the exact content digest they reviewed; the ``review_decisions`` row (with ``published_digest``) and
  the publication commit in one transaction (§13.6). A digest that no longer matches is refused.
* :func:`reject` records a rejection of a reviewed digest; the version stays unpublished.

There is no other path to publication and no fixture shortcut: test fixtures use their own origin (D-29).
"""

from __future__ import annotations

import json
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field, TypeAdapter, ValidationError
from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import Settings
from app.content.package import LessonPackage
from app.content.store import Approval, ImportResult, import_package, publish
from app.content.validation import ContentValidationError, Issue
from app.models import Lesson, LessonVersion, ReviewDecision, User
from app.services.platform import passwords
from app.sources.records import SourceRecord

SCHEMA = "qabas.gold/1"


class Provenance(BaseModel):
    """Where a gold lesson came from; recorded with the import run, never shown to learners."""

    model_config = ConfigDict(extra="forbid")

    source: str                       # e.g. "unit0_authoring", "salah_reference", "handwritten"
    source_digest: str | None = None  # digest of the upstream record(s) it was converted from
    converter: str | None = None      # converter name/version when converted
    notes: list[str] = []


class GoldFile(BaseModel):
    model_config = ConfigDict(extra="forbid", populate_by_name=True)

    schema_: Literal["qabas.gold/1"] = Field(default="qabas.gold/1", alias="schema")
    provenance: Provenance
    lesson: LessonPackage
    source_records: dict[str, SourceRecord] = Field(default_factory=dict)

    def dump(self) -> dict[str, Any]:
        result = {"schema": SCHEMA, "provenance": self.provenance.model_dump(mode="json"),
                  "lesson": self.lesson.model_dump(mode="json")}
        if self.source_records:
            result["source_records"] = TypeAdapter(dict[str, SourceRecord]).dump_python(
                self.source_records, mode="json")
        return result


class GoldError(ValueError):
    pass


def read_gold(path: Path) -> GoldFile:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise GoldError(f"{path}: not readable JSON ({exc})") from None
    if not isinstance(data, dict) or data.get("schema") != SCHEMA:
        raise GoldError(f"{path}: not a {SCHEMA} gold file")
    try:
        return GoldFile.model_validate(data)
    except ValidationError as exc:
        problems = "; ".join(f"{'.'.join(str(p) for p in e['loc'])}: {e['msg']}" for e in exc.errors()[:20])
        raise GoldError(f"{path}: invalid gold lesson: {problems}") from None


def write_gold(path: Path, gold: GoldFile) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(gold.dump(), ensure_ascii=False, indent=1, sort_keys=False) + "\n",
                    encoding="utf-8", newline="\n")


async def import_gold(db: AsyncSession, gold: GoldFile, *, run_id: str | None = None) -> ImportResult:
    """Store a gold lesson as an unpublished version (caller owns the transaction)."""
    from app.sources.gold import verify_scripture
    from app.sources.store import citable, persist
    try:
        verify_scripture(gold.lesson.model_dump(mode="json"), gold.source_records)
        # Capability snapshots (audio/timing metadata) are verified above and stay embedded in the canonical
        # row's provenance; only authority records become citable sources (D-106).
        for identifier, record in sorted(gold.source_records.items()):
            if citable(record):
                await persist(db, record, id_=identifier)
    except (RuntimeError, LookupError, ValueError, TypeError) as exc:
        raise GoldError(f"scripture/source verification failed: {exc}") from exc
    result = await import_package(db, gold.lesson, origin="gold_import", run_id=run_id)
    await db.execute(update(Lesson).where(Lesson.id == gold.lesson.lesson_id).values(is_gold=True))
    await db.flush()
    return result


@dataclass(frozen=True)
class PendingVersion:
    lesson_id: str
    version: int
    lesson_version_id: uuid.UUID
    content_sha256: str
    origin: str
    published: bool


async def version_of(db: AsyncSession, lesson_id: str, version: int) -> PendingVersion:
    row = (await db.execute(select(LessonVersion).where(LessonVersion.lesson_id == lesson_id,
                                                        LessonVersion.version == version))).scalar_one_or_none()
    if row is None:
        raise GoldError(f"{lesson_id} has no version {version}")
    return PendingVersion(lesson_id, version, row.id, row.content_sha256, row.origin, row.published_at is not None)


async def authenticate_reviewer(db: AsyncSession, email: str, password: str) -> str:
    """The reviewer's own credentials (Argon2id, constant-time for unknown emails); returns the reviewer id."""
    user = (await db.execute(select(User).where(func.lower(User.email) == email.strip().lower(),
                                                User.role == "reviewer"))).scalar_one_or_none()
    if not passwords.verify_password(user.password_hash if user else None, password) or user is None:
        raise GoldError("reviewer authentication failed")
    return user.id


async def _reviewer(db: AsyncSession, reviewer_id: str) -> User:
    reviewer = await db.get(User, reviewer_id)
    if reviewer is None or reviewer.role != "reviewer" or reviewer.deactivated_at is not None \
            or reviewer.deleted_at is not None:
        raise GoldError("only an active reviewer can decide on a lesson version")
    return reviewer


async def _decidable(db: AsyncSession, lesson_id: str, version: int, reviewed_digest: str) -> PendingVersion:
    pending = await version_of(db, lesson_id, version)
    if pending.origin != "gold_import":
        raise GoldError(f"{lesson_id} v{version} is not a gold import (origin {pending.origin})")
    if pending.published:
        raise GoldError(f"{lesson_id} v{version} is already published")
    if reviewed_digest != pending.content_sha256:
        # The reviewer saw other content (an older import or a mistyped digest): never approve blind.
        raise GoldError(f"{lesson_id} v{version}: the reviewed digest does not match the stored content")
    return pending


async def approve_and_publish(db: AsyncSession, settings: Settings, *, reviewer_id: str, lesson_id: str,
                              version: int, reviewed_digest: str) -> uuid.UUID:
    """Record the Gate 2-equivalent approval of exactly ``reviewed_digest`` and publish it, atomically."""
    await _reviewer(db, reviewer_id)
    pending = await _decidable(db, lesson_id, version, reviewed_digest)
    decision = ReviewDecision(lesson_version_id=pending.lesson_version_id, gate=2, decision="approve",
                              reviewer_id=reviewer_id, reviewed_digest=reviewed_digest,
                              published_digest=pending.content_sha256)
    db.add(decision)
    await db.flush()
    await publish(db, settings, pending.lesson_version_id, Approval(decision.id))
    return decision.id


async def reject(db: AsyncSession, *, reviewer_id: str, lesson_id: str, version: int, reviewed_digest: str,
                 reason: str | None = None) -> uuid.UUID:
    """Record a rejection; the version stays unpublished and a corrected import becomes a new version."""
    await _reviewer(db, reviewer_id)
    pending = await _decidable(db, lesson_id, version, reviewed_digest)
    decision = ReviewDecision(lesson_version_id=pending.lesson_version_id, gate=2, decision="reject",
                              reviewer_id=reviewer_id, reviewed_digest=reviewed_digest, reason=reason)
    db.add(decision)
    await db.flush()
    return decision.id


def issues_text(exc: ContentValidationError) -> list[str]:
    return [f"[{i.code}] {i.message}" + (f" ({i.location})" if i.location else "") for i in exc.issues]


__all__ = ["GoldError", "GoldFile", "Issue", "Provenance", "approve_and_publish", "authenticate_reviewer",
           "import_gold", "read_gold", "reject", "version_of", "write_gold"]
