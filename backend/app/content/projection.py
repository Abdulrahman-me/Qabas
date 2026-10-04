"""Projection from stored lesson content to the learner-facing contract shapes.

* Variant choice (backend §6.2): Explorer learners get the Explorer variant; New Muslim learners get the
  New Muslim variant, or the Explorer variant when none was authored. An Explorer never gets a New Muslim
  variant. The entry surface (Roadmap or Discover) is never an input.
* Exercise blocks are resolved to the contract ``Exercise``. The private key, misconception mapping and
  duel flag stay server-side; they are not part of the learner model at all.
* Sources: every source referenced by blocks and exercises, in order of first appearance. ``displayed`` is
  true exactly for counted sources: ``content`` (evidence blocks, teach evidence, story quotes) and
  ``activity`` (a recitation exercise's own verified source). ``source_count`` counts them (§6.5.3).
* Reader projection (``GET /lessons/{id}``): the same blocks with exercise blocks removed.
* Term cards: the contract's single ``display_fields.project_term`` projection, used by glossary, sessions,
  guides and Raqeeb alike. Stored terms must already carry the rev 10 explicit fields (``arabic`` etc.);
  ``display_fields.backfill_legacy`` is never applied to content (decision D-36).
"""

from __future__ import annotations

from typing import Any

from app.content.package import LessonPackage, Variant, spans_of
from app.contract import display_fields
from app.contract import models as C
from app.errors import ApiError, ErrorCode

ACTIVITY_TYPES = ("recite_verse",)


def select_variant(available: set[str], track: str) -> Variant:
    if track == "new_muslim" and "new_muslim" in available:
        return "new_muslim"
    if "explorer" in available:
        return "explorer"
    raise ApiError(ErrorCode.not_found, "This lesson has no variant for your track.")


def learner_exercise(package: LessonPackage, exercise_id: str, lang: str) -> dict[str, Any]:
    record = package.exercise(exercise_id)
    if record is None:
        raise KeyError(f"unknown exercise {exercise_id}")
    stored = record.exercise[lang]  # type: ignore[index]
    learner = C.Exercise.model_validate(stored.model_dump(include=set(C.Exercise.model_fields)))
    projected: dict[str, Any] = learner.model_dump(mode="json")
    return projected


def resolve_items(package: LessonPackage, lang: str, variant: str) -> list[dict[str, Any]]:
    """Contract ``Block`` list for one variant, exercises resolved to their learner form."""
    content = package.variants[lang][variant]  # type: ignore[index]
    items = []
    for block in content.blocks:
        if block["type"] == "exercise":
            items.append({"block_id": block["block_id"], "type": "exercise",
                          "exercise": learner_exercise(package, block["exercise_id"], lang)})
        else:
            items.append(block)
    return items


def reader_blocks(items: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [block for block in items if block["type"] != "exercise"]


def _evidence_ids(block: dict[str, Any]) -> list[str]:
    if block["type"] == "evidence":
        return [block["evidence"]["evidence_id"]]
    if block["type"] == "teach" and block.get("evidence"):
        return [block["evidence"]["evidence_id"]]
    if block["type"] == "story":
        return [beat["quote"]["evidence_id"] for beat in block["beats"] if beat.get("quote")]
    return []


def referenced_source_ids(node: Any) -> list[str]:
    """Every source id referenced anywhere in ``node``, in order of first appearance."""
    found: list[str] = []

    def add(value: str) -> None:
        if value not in found:
            found.append(value)

    def walk(item: Any) -> None:
        if isinstance(item, dict):
            if "evidence_id" in item and isinstance(item["evidence_id"], str):
                add(item["evidence_id"])
            for key, value in item.items():
                if key == "source_id" and isinstance(value, str):
                    add(value)
                elif key == "source_ids" and isinstance(value, list):
                    for source_id in value:
                        add(source_id)
                else:
                    walk(value)
        elif isinstance(item, list):
            for value in item:
                walk(value)

    walk(node)
    return found


def display_roles(items: list[dict[str, Any]]) -> dict[str, str]:
    """source_id -> 'content' | 'activity' for the sources the learner sees on screen (§6.5.3)."""
    roles: dict[str, str] = {}
    for block in items:
        for source_id in _evidence_ids(block):
            roles.setdefault(source_id, "content")
        if block["type"] == "exercise" and block["exercise"]["type"] in ACTIVITY_TYPES:
            source_id = block["exercise"]["payload"].get("source_id")
            if source_id:
                roles.setdefault(source_id, "activity")
    return roles


def session_source_ids(items: list[dict[str, Any]]) -> list[str]:
    """Sources a session lists: everything referenced by its blocks, plus a recitation exercise's activity
    source. Evidence embedded in an exercise payload (``which_evidence`` options, the ``verse_meaning`` verse)
    is self-contained display data and is not listed (contract fixtures; factory §13.2 budget rule)."""
    found: list[str] = []
    for block in items:
        if block["type"] == "exercise":
            source_id = block["exercise"]["payload"].get("source_id")
            candidates = [source_id] if isinstance(source_id, str) else []
        else:
            candidates = referenced_source_ids(block)
        found += [s for s in candidates if s not in found]
    return found


def project_sources(package: LessonPackage, items: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Session/reader sources of a lesson version, from the version's own source records."""
    return project_source_records({s.source_id: s.model_dump(mode="json") for s in package.sources}, items)


def project_source_records(records: dict[str, dict[str, Any]], items: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Contract ``Source`` list for ``items``; ``records`` maps source_id -> the record without display flags."""
    roles = display_roles(items)
    projected = []
    for source_id in session_source_ids(items):
        if source_id not in records:
            raise KeyError(f"source {source_id} has no record")
        role = roles.get(source_id)
        projected.append(C.Source(**records[source_id], displayed=role is not None,
                                  display_role=role).model_dump(mode="json"))
    return projected


def source_count(sources: list[dict[str, Any]]) -> int:
    return sum(1 for s in sources if s["displayed"])


def term_ids(node: Any) -> list[str]:
    found: list[str] = []
    for span in spans_of(node):
        if span.get("type") == "term" and span["term_id"] not in found:
            found.append(span["term_id"])
    return found


def term_card(record: C.StoredGlossaryTerm, lang: str, *, state: str = "new", level: str = "basic",
              lesson_title: str | None = None) -> dict[str, Any]:
    """A learner ``TermCard`` (state and level come from the learner's term record)."""
    card = display_fields.project_term(record.model_dump(mode="json"), lang, state=state, level=level,
                                       lesson_title=lesson_title)
    projected: dict[str, Any] = C.TermCard.model_validate(card).model_dump(mode="json")
    return projected


def counts(items: list[dict[str, Any]]) -> dict[str, int]:
    exercises = [b["exercise"] for b in items if b["type"] == "exercise"]
    predicts = [b for b in items if b["type"] == "predict"]
    return {"interactions": len(exercises) + len(predicts), "exercises": len(exercises),
            "scored": sum(1 for e in exercises if e["scoring"]["accuracy"])}


def xp_for(package: LessonPackage) -> int:
    """Displayed lesson XP (``JLesson.xp``, decision D-31): what the fixed XP table (backend §10.1) lets a
    learner earn from this lesson: completion 10, a perfect lesson 3 when any exercise counts toward
    accuracy, and 3 per recitation exercise."""
    variant = next(iter(package.variants["ar"].values()))  # every variant shares the exercise skeleton
    exercises = [e for e in (package.exercise(eid) for eid in variant.exercise_ids()) if e is not None]
    perfect = 3 if any(e.scored for e in exercises) else 0
    recitation = 3 * sum(1 for e in exercises if e.type == "recite_verse")
    return 10 + perfect + recitation
