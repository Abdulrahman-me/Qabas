"""Deterministic composition of factory drafts into contract content (factory §13.2; contract §5.6, §6.5).

Models write plain text and refer to evidence by the ids they were given; code turns that into contract blocks,
inserts the verified evidence objects (never model text), attaches sentence sources from the claims, gives every
visual host a placeholder until the visual pipeline exists (D-129), localizes by substituting text leaves of the
Arabic structure (so ids, roles, claim links, keys and evidence cannot drift) and links terms deterministically.
"""

from __future__ import annotations

import copy
import re
from collections.abc import Callable, Iterator
from typing import Any

from app.contract import models as C

PLACEHOLDER_SIZE = (1200, 900)
TEXT_KEYS = frozenset({"text", "alt", "cta", "label", "title", "eyebrow", "subtitle", "secondary_label"})
OPAQUE_KEYS = frozenset({"evidence", "quote", "verse", "provenance", "answer_key", "visual_params", "params",
                         "image", "scene", "fallback_image", "overlays"})


def span(text: str) -> list[dict[str, Any]]:
    return [{"type": "text", "text": text}]


def sentence(sentence_id: str, text: str, source_ids: list[str]) -> dict[str, Any]:
    return {"sentence_id": sentence_id, "spans": span(text), "source_ids": source_ids}


def placeholder_visual(run_id: str, host_id: str, alt: str) -> dict[str, Any]:
    """A reserved ``mock-asset://`` image: valid structure, never publishable (placeholder readiness, §13.4)."""
    width, height = PLACEHOLDER_SIZE
    image = C.Image(url=f"mock-asset://factory/{run_id}/{host_id}.webp", mime_type="image/webp", width=width,
                    height=height)
    visual: dict[str, Any] = C.Visual(kind="image", key=None, version=None, params=None, scene=None,
                                      fallback_image=None, fallback_params=None, alt=alt, overlays=[],
                                      image=image).model_dump(mode="json")
    return visual


def draft_visual(host_id: str, visual: dict[str, Any]) -> dict[str, Any]:
    value: dict[str, Any] = C.DraftVisual(scene_id=host_id, origin="generated", visual=C.Visual.model_validate(visual),
                                          audit=None, attempts=0, previews=None).model_dump(mode="json")
    return value


# ------------------------------------------------------------------------------------------- text leaves

Leaf = tuple[tuple[Any, ...], str]


def text_leaves(node: Any, path: tuple[Any, ...] = ()) -> Iterator[Leaf]:
    """Every localizable string in a stored structure, with its path. Evidence objects (verified text with its
    own verified translation), ids, keys, media and visual parameters are never localizable."""
    if isinstance(node, dict):
        if "evidence_id" in node and "kind" in node:
            return
        for key, value in node.items():
            if key in OPAQUE_KEYS:
                continue
            if isinstance(value, str) and key in TEXT_KEYS and value.strip():
                if key == "text" and node.get("type") not in (None, "text", "strong", "term"):
                    continue
                yield (*path, key), value
            elif isinstance(value, dict | list):
                yield from text_leaves(value, (*path, key))
    elif isinstance(node, list):
        for index, value in enumerate(node):
            yield from text_leaves(value, (*path, index))


def replace_leaves(node: Any, texts: dict[tuple[Any, ...], str]) -> Any:
    out = copy.deepcopy(node)
    for path, text in texts.items():
        target = out
        for step in path[:-1]:
            target = target[step]
        target[path[-1]] = text
    return out


def swap_evidence(node: Any, english: Callable[[str], dict[str, Any]]) -> Any:
    """Replace every embedded Evidence object by its verified English counterpart (same evidence id)."""
    if isinstance(node, dict):
        if "evidence_id" in node and "kind" in node and ("quran" in node or "hadith" in node):
            return english(node["evidence_id"])
        return {k: swap_evidence(v, english) for k, v in node.items()}
    if isinstance(node, list):
        return [swap_evidence(v, english) for v in node]
    return node


# ------------------------------------------------------------------------------------------- terms

def _term_pattern(text: str, lang: str) -> re.Pattern[str]:
    escaped = re.escape(text.strip())
    if lang == "en":
        return re.compile(rf"(?<![A-Za-z]){escaped}(?![A-Za-z])", re.IGNORECASE)
    # Arabic: allow the definite article and attached prepositions/conjunctions before the term.
    return re.compile(rf"(?<![ء-ي]){escaped}(?![ء-ي])")


def link_terms(blocks: list[dict[str, Any]], terms: list[tuple[str, str]], lang: str) -> list[dict[str, Any]]:
    """The deterministic term linker (factory §13.6): the first occurrence of each term in a variant's sentences
    becomes a ``term`` span. Terms are ``(term_id, text)`` in this language; nothing else is changed."""
    out = copy.deepcopy(blocks)
    pending = list(terms)

    def visit(node: Any) -> None:
        if not pending:
            return
        if isinstance(node, dict):
            if "evidence_id" in node and "kind" in node:
                return
            if "sentence_id" in node and isinstance(node.get("spans"), list):
                node["spans"] = _link_spans(node["spans"], pending, lang)
                return
            for value in node.values():
                visit(value)
        elif isinstance(node, list):
            for value in node:
                visit(value)

    visit(out)
    return out


def _link_spans(spans: list[dict[str, Any]], pending: list[tuple[str, str]], lang: str) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    for item in spans:
        if item.get("type") != "text":
            result.append(item)
            continue
        text = item["text"]
        pieces: list[dict[str, Any]] = []
        while text:
            best = None
            for term_id, term_text in pending:
                match = _term_pattern(term_text, lang).search(text)
                if match and (best is None or match.start() < best[0].start()):
                    best = (match, term_id)
            if best is None:
                pieces.append({"type": "text", "text": text})
                break
            match, term_id = best
            if match.start():
                pieces.append({"type": "text", "text": text[:match.start()]})
            pieces.append({"type": "term", "text": match.group(0), "term_id": term_id})
            pending[:] = [p for p in pending if p[0] != term_id]
            text = text[match.end():]
        result.extend(pieces)
    return result
