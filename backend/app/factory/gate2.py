"""Gate 2: the reviewer's decision on the stored draft, and publication (API §6.11 ``Gate2``; factory §13.6, §14).

The reviewer decides on exactly what they saw: the run row is locked (the first valid decision wins), a run not
awaiting Gate 2 is ``409 run_not_at_gate`` and a digest other than its current ``review_digest`` (draft + QA
report, contract ``review.py``) is ``409 review_stale``. Nothing is regenerated here.

* ``reject``: recorded; the run ends ``rejected``.
* ``request_changes`` (reason required): recorded; the reviewed artifacts are kept under
  ``artifacts.revisions`` and the pipeline re-runs from ``write`` (then exercises, glossary, localize and qa)
  with the reviewer's reason as data for the Writer. The new draft gets a new digest and needs a new decision.
* ``approve`` (optional paired sentence edits and exercise removals): the stored package is edited, terms in
  edited text are re-linked deterministically, and every publication gate runs again on the result: the content
  validators (structure, roles, arc, localization parity, evidence budget, exercises, pools, placeholder media),
  draft-visual readiness, the verified-scripture/source checks of the gold path, the model-reported blockers that
  this request did not clear, and then the Phase 4 publication checks (prerequisites, concepts introduced once,
  scenes). Any blocker → ``400 validation_error`` with ``details.issues`` and *nothing* is recorded or published:
  approval and publication are one transaction (API: "approve (publishes)"). Otherwise the cited source records
  are persisted, the package is imported as the lesson's next version (``origin = factory``), the decision is
  recorded with the reviewed digest, the edits (before/after) and the published content digest, and Phase 4's
  ``publish`` makes it current, all before commit.
"""

from __future__ import annotations

import copy
import uuid
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from pydantic import ValidationError
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.config import Settings
from app.content import validation
from app.content.package import LessonPackage, content_digest, sentences_of
from app.content.store import Approval, import_package, publish
from app.content.validation import ContentValidationError
from app.contract import contextual
from app.contract import models as C
from app.errors import ApiError, ErrorCode
from app.factory import compose, pipeline
from app.factory.evidence import load_record
from app.factory.gates import _active_reviewer
from app.factory.orchestrator import Dispatcher
from app.factory.runs import to_contract
from app.factory.stages.qa import issue, readiness_issues, validation_issues
from app.media import publication
from app.media.errors import MediaError
from app.models import FactoryRun, LessonVersion, ReviewDecision, Unit
from app.services.platform.auth_sessions import utcnow
from app.services.platform.storage import ObjectStorage, StorageError, build_storage
from app.sources.errors import SourceError
from app.sources.mushaf import Mushaf
from app.sources.records import SourceRecord
from app.sources.store import citable, persist, source_id

REWRITE_FROM = "write"
REWRITTEN = ("write", "exercises", "glossary", "localize", "visuals", "scene_author", "scene_render", "narration", "qa")


@dataclass
class ScriptureAuthority:
    """What the scripture re-verification reads: the canonical mushaf and the specialist's translation selection.
    ``mushaf`` is loaded from settings when not given (tests pass the synthetic stand-in)."""

    mushaf: Mushaf | None = None
    translations: Path | None = None          # None: the committed manifest (content/sources/translations.yaml)


@dataclass
class Edited:
    package: dict[str, Any]
    sentences: set[tuple[str, str, str]] = field(default_factory=set)
    arabic: set[str] = field(default_factory=set)        # sentence ids with an Arabic edit
    any_language: set[str] = field(default_factory=set)
    removed: set[str] = field(default_factory=set)
    audit: dict[str, Any] = field(default_factory=dict)
    issues: list[dict[str, Any]] = field(default_factory=list)


def _text(spans: list[dict[str, Any]]) -> str:
    return "".join(s.get("text", "") for s in spans)


def apply_edits(stored: dict[str, Any], body: C.Gate2) -> Edited:
    """The reviewer's sentence edits and exercise removals on a copy of the stored package."""
    package = copy.deepcopy(stored)
    result = Edited(package)
    glossary = package["glossary"]
    audit_edits = []
    for edit in body.sentence_edits:
        variant = package["variants"].get(edit.language, {}).get(edit.variant)
        targets = [s for b in (variant or {}).get("blocks", []) for s in sentences_of(b)
                   if s["sentence_id"] == edit.sentence_id]
        if not targets:
            result.issues.append(issue("blocker", "validation", f"{edit.language}/{edit.variant}: there is no "
                                       f"sentence {edit.sentence_id} to edit", sentence_id=edit.sentence_id))
            continue
        assert variant is not None
        linked_elsewhere = {span["term_id"] for b in variant["blocks"] for s in sentences_of(b)
                            if s["sentence_id"] != edit.sentence_id for span in s["spans"]
                            if span.get("type") == "term"}
        terms = [(t["term_id"], t["text"][edit.language]) for t in glossary if t["term_id"] not in linked_elsewhere]
        before = _text(targets[0]["spans"])
        for target in targets:
            fresh = {"sentence_id": edit.sentence_id, "spans": compose.span(edit.new_text),
                     "source_ids": target["source_ids"]}
            target["spans"] = compose.link_terms([fresh], terms, edit.language)[0]["spans"]
        result.sentences.add((edit.language, edit.variant, edit.sentence_id))
        result.any_language.add(edit.sentence_id)
        if edit.language == "ar":
            result.arabic.add(edit.sentence_id)
        audit_edits.append({"sentence_id": edit.sentence_id, "language": edit.language, "variant": edit.variant,
                            "before": before, "after": edit.new_text})
    known = {e["exercise_id"] for e in package["exercises"]}
    for exercise_id in body.exercise_removals:
        if exercise_id not in known:
            result.issues.append(issue("blocker", "validation", f"there is no exercise {exercise_id} to remove",
                                       exercise_id=exercise_id))
    removed = set(body.exercise_removals) & known
    if removed:
        package["exercises"] = [e for e in package["exercises"] if e["exercise_id"] not in removed]
        dropped_blocks = set()
        for by_variant in package["variants"].values():
            for content in by_variant.values():
                kept = []
                for block in content["blocks"]:
                    if block["type"] == "exercise" and block["exercise_id"] in removed:
                        dropped_blocks.add(block["block_id"])
                    else:
                        kept.append(block)
                content["blocks"] = kept
        package["arc_map"] = [{**row, "block_ids": [b for b in row["block_ids"] if b not in dropped_blocks]}
                              for row in package["arc_map"]]
    result.removed = removed
    result.audit = {"sentence_edits": audit_edits, "exercise_removals": sorted(removed)}
    return result


def remaining_model_blockers(report: dict[str, Any], package: LessonPackage, edited: Edited) -> list[dict[str, Any]]:
    """API §6.11: deterministic findings (``validation``, visual readiness, the verifier's semantic blockers) are
    re-evaluated; any other blocker clears only when this request edits (Arabic; English for ``localization``) or
    removes what it flags. A blocker with no sentence or exercise location needs a new draft."""
    out = []
    for item in report["issues"]:
        if item["severity"] != "blocker" or item["kind"] == "validation":
            continue
        location = item["location"]
        if item["kind"] == "scholarly_review" and location["sentence_id"] is None and location["exercise_id"] is None:
            continue                                         # re-derived from the claims below
        sentence, exercise = location["sentence_id"], location["exercise_id"]
        edited_ids = edited.any_language if item["kind"] == "localization" else edited.arabic
        if (sentence is not None and sentence in edited_ids) or (exercise is not None and exercise in edited.removed):
            continue
        out.append(item)
    links: dict[str, list[str]] = {}
    for row in package.sentence_map:
        for claim_id in row.claim_ids:
            links.setdefault(claim_id, []).append(row.sentence_id)
    for claim in package.claims:
        if claim.status != "supported":
            continue
        for evidence in claim.evidence:
            review = evidence.semantic_review
            if not evidence.supports or review is None:
                continue
            blocking = contextual.SEMANTIC_BLOCKING_CONCERNS & set(review.concerns)
            sentences = links.get(claim.claim_id, [])
            if blocking and not (sentences and all(s in edited.arabic for s in sentences)):
                out.append(issue("blocker", "scholarly_review", f"{claim.claim_id} / {evidence.source.source_id} "
                                 f"({review.fit}; {', '.join(sorted(blocking))}): narrow or edit every sentence that "
                                 f"asserts it ({', '.join(sentences) or 'none'}) — {review.note}"))
    return out


def _records(stored: dict[str, list[dict[str, Any]]]) -> dict[str, SourceRecord]:
    records = {}
    for chain in stored.values():
        for raw in chain:
            record = load_record(raw)
            records[source_id(record)] = record
    return records


def source_issues(package: LessonPackage, records: dict[str, SourceRecord], authority: ScriptureAuthority,
                  settings: Settings) -> list[dict[str, Any]]:
    """The gold path's mechanical scripture/source verification on the factory package (factory §13.7.3)."""
    from app.sources.gold import verify_scripture
    from app.sources.mushaf import MushafError, get_mushaf
    try:
        mushaf = authority.mushaf or get_mushaf(settings)
        verify_scripture(package.model_dump(mode="json"), records, mushaf=mushaf,
                         translation_manifest=authority.translations)
    except MushafError as exc:
        return [issue("blocker", "validation", f"the canonical mushaf is not available: {exc}")]
    except (RuntimeError, LookupError, ValueError) as exc:
        return [issue("blocker", "validation", f"source verification failed: {exc}")]
    return []


def _issues_of(exc: ContentValidationError, package: LessonPackage) -> list[dict[str, Any]]:
    return validation_issues(exc.issues, {s.sentence_id for s in package.sentence_map},
                             {e.exercise_id for e in package.exercises})


def _blocked(issues: list[dict[str, Any]]) -> ApiError:
    return ApiError(ErrorCode.validation_error, "The draft cannot be approved and published yet.",
                    {"issues": issues})


async def _approve(db: AsyncSession, settings: Settings, run: FactoryRun, body: C.Gate2, reviewer_id: str,
                   authority: ScriptureAuthority, storage: ObjectStorage) -> ReviewDecision:
    output = (run.artifacts.get("qa") or {}).get("output") or {}
    stored = output.get("package")
    if stored is None or LessonPackage.model_validate(stored).digest() != output.get("package_digest"):
        raise _blocked([issue("blocker", "validation", "the stored draft package is missing or altered")])
    edited = apply_edits(stored, body)
    if edited.issues:
        raise _blocked(edited.issues)
    try:
        package = LessonPackage.model_validate(edited.package)
    except ValidationError as exc:
        raise _blocked([issue("blocker", "validation", f"{'/'.join(map(str, e['loc']))}: {e['msg']}")
                        for e in exc.errors()[:20]]) from None
    unit = await db.get(Unit, run.unit_id)
    assert unit is not None
    context = await _context(db, unit)
    sentence_ids = {s.sentence_id for s in package.sentence_map}
    exercise_ids = {e.exercise_id for e in package.exercises}
    draft = pipeline.current_draft(run.artifacts)
    assert isinstance(draft, dict) and run.qa_report is not None
    records = _records(output.get("source_records", {}))
    issues = validation_issues(validation.validate_package(package, context), sentence_ids, exercise_ids)
    issues += readiness_issues(draft["visuals"])
    issues += source_issues(package, records, authority, settings)
    issues += remaining_model_blockers(run.qa_report, package, edited)
    if issues:
        raise _blocked(issues)
    if output.get("media_objects") and not any(
        i["message"] == "reviewed media receipts: " + content_digest(output["media_objects"])
        for i in run.qa_report["issues"]):
        raise _blocked([issue("blocker", "validation", "media provenance differs from the reviewed QA fingerprint")])
    try:
        await publication.validate(storage, settings, output, package)
        for source in package.sources:
            record = records.get(source.source_id)
            if record is None or not citable(record):
                raise ContentValidationError([validation.Issue("sources", "a cited source has no verified, citable "
                                                               "provenance record", source.source_id)])
            await persist(db, record, id_=source.source_id)
        imported = await import_package(db, package, origin="factory", run_id=run.id,
                                        edited_sentences=frozenset(edited.sentences))
        if not imported.created:
            raise ContentValidationError([validation.Issue("placement", "this exact content is already stored as "
                                                           f"version {imported.version}; nothing new to publish")])
        version = await db.get(LessonVersion, imported.lesson_version_id)
        assert version is not None
        decision = ReviewDecision(run_id=run.id, lesson_version_id=version.id, gate=2, decision="approve",
                                  reviewer_id=reviewer_id, reviewed_digest=body.review_digest,
                                  published_digest=version.content_sha256, edits=edited.audit, reason=body.reason)
        db.add(decision)
        await db.flush()
        await publication.promote(db, storage, settings, output, package, decision_id=decision.id, run_id=run.id)
        await publish(db, settings, version.id, Approval(decision.id))
    except ContentValidationError as exc:
        raise _blocked(_issues_of(exc, package)) from None
    except SourceError as exc:      # e.g. SourceChanged: the stored citation differs; a person re-verifies it
        raise _blocked([issue("blocker", "validation", f"source re-verification required: {exc}")]) from None
    except (MediaError, StorageError) as exc:
        raise _blocked([issue("blocker", "validation", str(exc))]) from None
    run.status, run.published_lesson_id, run.published_version = "published", version.lesson_id, version.version
    return decision


async def _context(db: AsyncSession, unit: Unit) -> validation.Context:
    from app.content.store import _context as store_context
    return await store_context(db, unit, allow_placeholder_media=False)


def _request_changes(run: FactoryRun, decision_id: uuid.UUID, body: C.Gate2, now: str) -> None:
    """Keep the reviewed artifacts, then send the run back to ``write`` with the reviewer's reason."""
    revisions = list(run.artifacts.get("revisions", []))
    revisions.append({"round": len(revisions) + 1, "decision_id": str(decision_id), "reason": body.reason,
                      "reviewed_digest": body.review_digest, "qa_report": run.qa_report,
                      "artifacts": {stage: run.artifacts[stage] for stage in REWRITTEN if stage in run.artifacts}})
    discarded = {*REWRITTEN, "media_previous", "media_regeneration"}
    run.artifacts = {**{k: v for k, v in run.artifacts.items() if k not in discarded}, "revisions": revisions}
    run.stages = [{**s, "status": "pending", "started_at": None, "finished_at": None}
                  if s["stage"] in REWRITTEN else s for s in run.stages]
    run.stage_timings = {k: v for k, v in run.stage_timings.items() if k not in REWRITTEN}
    run.attempts = [*run.attempts, {"stage": REWRITE_FROM, "attempt": 1, "event": "revision_requested",
                                    "round": len(revisions), "at": now}]
    run.qa_report = None
    run.status, run.stage, run.attempt = "running", REWRITE_FROM, 1


async def decide_gate2(sessionmaker: async_sessionmaker[AsyncSession], settings: Settings, dispatcher: Dispatcher, *,
                       run_id: str, reviewer_id: str, body: C.Gate2,
                       authority: ScriptureAuthority | None = None,
                       storage: ObjectStorage | None = None) -> dict[str, Any]:
    authority = authority or ScriptureAuthority()
    async with sessionmaker() as db, db.begin():
        await _active_reviewer(db, reviewer_id)
        run = await db.get(FactoryRun, run_id, with_for_update=True)
        if run is None:
            raise ApiError(ErrorCode.not_found, "Factory run was not found.")
        if run.status != "awaiting_gate2":
            raise ApiError(ErrorCode.run_not_at_gate, "This run is not waiting at Gate 2.")
        if body.review_digest != run.review_digest:
            raise ApiError(ErrorCode.review_stale, "The draft changed since you reviewed it; review it again.")
        now = utcnow()
        if body.decision == "approve":
            decision = await _approve(db, settings, run, body, reviewer_id, authority,
                                      storage or build_storage(settings))
        else:
            decision = ReviewDecision(run_id=run.id, gate=2, decision=body.decision, reviewer_id=reviewer_id,
                                      reviewed_digest=body.review_digest, reason=body.reason)
            db.add(decision)
            await db.flush()
            if body.decision == "reject":
                run.status = "rejected"
            else:
                _request_changes(run, decision.id, body, now.isoformat())
        run.review_started_at = run.review_started_at or now
        run.review_finished_at = now
        run.review_digest = None
        run.gate2_decision = {"decision": body.decision, "decision_id": str(decision.id), "reviewer_id": reviewer_id,
                              "reason": body.reason, "edits": decision.edits or {}, "decided_at": now.isoformat()}
        await db.flush()
        projected = to_contract(run)
    if body.decision == "request_changes":
        dispatcher.send(run_id, REWRITE_FROM, 1)
    return projected
