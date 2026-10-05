"""Exact/normalized Arabic term linking, after adaptation; no promotions or learning-state writes."""

from __future__ import annotations

import copy
import re
from typing import Any

from app.sources.normalize import normalize_ar


def link(blocks: list[dict[str, Any]], cards: dict[str, Any]) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    found: dict[str, Any] = {}
    terms = [(key, c["text"], normalize_ar(c["text"])) for key, c in cards.items() if c["text"].strip()]
    terms.sort(key=lambda t: len(t[1]), reverse=True)

    def split(text: str) -> list[dict[str, Any]]:
        # Candidate slices retain original glyphs, marks and spacing; normalization is for comparison only.
        words = list(re.finditer(r"\S+", text))
        matches: list[tuple[int, int, str]] = []
        cursor = 0
        for i, word in enumerate(words):
            if word.start() < cursor:
                continue
            for key, display, normalized in terms:
                count = len(display.split())
                if i + count > len(words):
                    continue
                end = words[i + count - 1].end()
                candidate = text[word.start():end]
                # Punctuation belongs to text, not the term span.
                trimmed = candidate.strip(".,;:!?،؛؟()[]«»\"'")
                offset = candidate.find(trimmed)
                if trimmed == display or normalize_ar(trimmed) == normalized:
                    start = word.start() + offset
                    stop = start + len(trimmed)
                    matches.append((start, stop, key))
                    cursor = stop
                    break
        output, cursor = [], 0
        for start, end, key in matches:
            if cursor < start:
                output.append({"type": "text", "text": text[cursor:start]})
            output.append({"type": "term", "text": text[start:end], "term_id": key})
            found[key] = cards[key]
            cursor = end
        if cursor < len(text):
            output.append({"type": "text", "text": text[cursor:]})
        return output or [{"type": "text", "text": text}]

    result = copy.deepcopy(blocks)
    for block in result:
        if block["type"] == "paragraph":
            block["spans"] = [piece for s in block["spans"] for piece in (
                split(s["text"]) if s["type"] == "text" else [s])]
    return result, found
