"""Conversion outcomes: a gold package, or the exact list of what is still missing and who supplies it."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any

# Who resolves each kind of blocker (decision D-81). Converters never resolve them themselves.
OWNERS: dict[str, str] = {
    "reasoning_tool_unmapped": "content specialist: approve the reasoning-tool mapping (D-40, O-12)",
    "plan_text_missing": "content author: write the missing language of the plan text",
    "concept_unregistered": "curriculum review: register the concept in content/curriculum.yaml (O-12)",
    "source_pending": "verified source insertion (Phase 9) and specialist provenance approval (O-05)",
    "scene_media_unpublished": "visual pipeline: normative renderer, released capability, published scene (O-13)",
    "media_unavailable": "media owner: licensed, hosted media (O-06, O-13)",
    "claim_in_span_field": "content author: move the assertion into a sentence the contract can link",
    "completion_record_missing": "content author + specialist: the plan, claims, roles, arc map and pools the "
                                 "reference lacks (factory §13.7.2, O-05)",
    "curriculum_placement": "product/curriculum decision (P-07, O-12)",
    "reference_acceptance": "frontend: API-driven playback parity of the exported reference lesson",
    "record_invalid": "content author: fix the authoring record",
}


@dataclass(frozen=True)
class Blocker:
    code: str
    lesson: str
    detail: str

    @property
    def owner(self) -> str:
        return OWNERS[self.code]

    def as_dict(self) -> dict[str, str]:
        return {"code": self.code, "lesson": self.lesson, "detail": self.detail, "owner": self.owner}


@dataclass
class Conversion:
    """One lesson's conversion: ``package`` is set only when there is no blocker."""

    lesson: str
    package: dict[str, Any] | None = None
    blockers: list[Blocker] = field(default_factory=list)
    notes: list[str] = field(default_factory=list)

    def block(self, code: str, detail: str) -> None:
        if code not in OWNERS:
            raise KeyError(code)
        blocker = Blocker(code, self.lesson, detail)
        if blocker not in self.blockers:
            self.blockers.append(blocker)

    @property
    def ready(self) -> bool:
        return self.package is not None and not self.blockers


def summary(conversions: list[Conversion]) -> dict[str, Any]:
    """A reviewer-facing report: per lesson, ready or blocked and by what; counts per blocker kind."""
    by_code: dict[str, int] = {}
    for conversion in conversions:
        for blocker in conversion.blockers:
            by_code[blocker.code] = by_code.get(blocker.code, 0) + 1
    return {
        "lessons": [{"lesson": c.lesson, "ready": c.ready, "blockers": [b.as_dict() for b in c.blockers],
                     "notes": c.notes} for c in conversions],
        "blocker_counts": dict(sorted(by_code.items())),
        "owners": {code: OWNERS[code] for code in sorted(by_code)},
    }
