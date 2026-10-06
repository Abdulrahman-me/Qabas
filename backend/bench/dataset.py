"""Digest-bound private sets, disjoint warming data and bounded owner-supplied attachments."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.contract import models as C
from app.sources.records import canonical_json, sha256_bytes, sha256_text


class Case(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    id: str = Field(min_length=1, max_length=100)
    language: Literal["ar", "en"]
    question: str = Field(max_length=2000)
    attachments: list[str] | None
    expected_class: C.QuestionClass
    should_abstain: bool
    expected_referral_type: Literal["fatwa_authority", "human_support", "specialist"] | None
    gold_points: list[str]
    gold_refs: list[str]
    # Explicit private-set extensions for adversarial/reuse/follow-up and unreadable-input cases.
    history: list[str] = Field(default_factory=list, max_length=3)
    expected_error: str | None = None
    must_not_reuse: bool = False
    tags: list[str] = Field(default_factory=list)

    @model_validator(mode="after")
    def usable(self) -> Case:
        if not self.question.strip() and not self.attachments:
            raise ValueError("an evaluation case requires text or an attachment")
        if any(not turn.strip() or len(turn) > 2000 for turn in self.history):
            raise ValueError("dependent history must contain bounded, non-empty turns")
        if not self.gold_points or any(not point.strip() for point in self.gold_points):
            raise ValueError("specialist behavior points are required even for error/referral cases")
        return self


def attachment(root: Path, name: str) -> Path:
    path = (root / name).resolve()
    if not path.is_relative_to(root.resolve()) or not path.is_file() or path.is_symlink():
        raise ValueError("benchmark attachment must be an existing private file inside the dataset root")
    return path


def read(root: Path, name: str) -> tuple[list[Case], str]:
    path = attachment(root, name)
    if path.stat().st_size > 10 * 1024 * 1024:
        raise ValueError("benchmark JSONL exceeds ten MiB")
    raw = path.read_bytes()
    cases = [Case.model_validate_json(line) for line in raw.splitlines() if line.strip()]
    if len({c.id for c in cases}) != len(cases) or not cases or len(cases) > 1000:
        raise ValueError("benchmark case IDs must be unique and bounded")
    hashes = {name: file_digest(attachment(root, name))
              for case in cases for name in case.attachments or []}
    return cases, sha256_text(canonical_json({"jsonl": sha256_bytes(raw), "files": hashes}))


def input_digest(case: Case, root: Path) -> str:
    return sha256_text(canonical_json({"language": case.language, "question": case.question.strip(),
        "files": [file_digest(attachment(root, p)) for p in case.attachments or []],
        "history": case.history}))


def load(root: Path, *, synthetic: bool = False) -> tuple[dict[str, list[Case]], dict[str, str]]:
    root = root.resolve()
    if not synthetic and ".private" not in root.parts:
        raise ValueError("real evaluation material must be under a private, git-ignored root (D-19)")
    sets, digests = {}, {}
    for name in ("questions", "adversarial", "warm"):
        sets[name], digests[name] = read(root, f"{name}.jsonl")
    all_cases = sets["questions"] + sets["adversarial"]
    if {input_digest(c, root) for c in all_cases} & {input_digest(c, root) for c in sets["warm"]} or \
            {c.id for c in all_cases} & {c.id for c in sets["warm"]}:
        raise ValueError("warm-up cases must be disjoint from held-out questions and adversarial cases")
    if len({c.id for c in all_cases}) != len(all_cases):
        raise ValueError("IDs overlap between question and adversarial sets")
    if not synthetic:
        manifest = json.loads(attachment(root, "manifest.json").read_text(encoding="utf-8"))
        if manifest.get("schema") != "qabas.raqeeb_dataset/1" or manifest.get("status") != "approved" or \
                not all(manifest.get(k) for k in ("specialist", "approved_on", "licence", "report",
                                               "provider_processing_approval")) or \
                manifest.get("digests") != digests:
            raise ValueError("private gold requires specialist approval, licence review and exact dataset digests")
        questions = sets["questions"]
        if not 60 <= len(questions) <= 80 or {c.language for c in questions} != {"ar", "en"} or \
                {c.expected_class for c in questions} != set(C.QuestionClass.__args__) or \
                len(sets["adversarial"]) < 20:
            raise ValueError("real evaluation requires 60-80 bilingual questions/all eight classes and 20 adversarial")
        required = {"conflicting_sources", "missing_references", "weak_hadith", "fabricated_hadith", "inexact_quran"}
        adversarial = {"image_injection", "document_injection", "transcript_injection", "near_duplicate",
                       "dependent_followup", "corrupt", "encrypted", "oversized"}
        if not required <= {t for c in questions for t in c.tags} or \
                not adversarial <= {t for c in sets["adversarial"] for t in c.tags}:
            raise ValueError("specialist-approved coverage tags are incomplete")
        if not {"voice", "image", "docx", "pdf_text", "pdf_scan"} <= {t for c in all_cases for t in c.tags}:
            raise ValueError("every supported input must be represented in the private evaluation")
        if any(not c.must_not_reuse for c in sets["adversarial"]
               if set(c.tags) & {"near_duplicate", "dependent_followup"}):
            raise ValueError("near-duplicate/dependent adversarial cases must explicitly forbid memory reuse")
    return sets, digests


def file_digest(path: Path) -> str:
    if path.stat().st_size > 128 * 1024**2:
        raise ValueError("private fixture exceeds the bounded oversized-test limit")
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()
