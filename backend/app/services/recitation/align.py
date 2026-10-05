"""Word alignment of a transcript against the expected canonical words (backend §8 steps 4-7).

Both sides are normalized with the same ``normalize_ar`` as every other Qur'an match (§12.1). Two tokens match when
``rapidfuzz.fuzz.ratio`` of their normalized forms is at least 80. Dynamic programming minimizes the edit distance
over tokens (match 0, substitution / missing / extra 1 each); the result is deterministic: earlier words are paired
first, and on equal cost a diagonal step (match, then substitution) wins over a missing expected word, which wins
over an extra heard word.

``passed`` = no missing and no substituted word; extra words are allowed and shown (§8 step 7).
"""

from __future__ import annotations

import hashlib
from dataclasses import dataclass
from typing import Literal

from rapidfuzz import fuzz

from app.sources.normalize import normalize_ar, tokens

MATCH_RATIO = 80

Result = Literal["correct", "missing", "substituted", "extra"]


def expected_text_digest(text_uthmani: str) -> str:
    """``checked_text_sha256``: SHA-256 of the normalized expected words joined by single spaces (data model
    ``recitation_checks``; D-109). The answer binding computes the same digest from the served payload text."""
    return hashlib.sha256(" ".join(tokens(text_uthmani)).encode("utf-8")).hexdigest()


@dataclass(frozen=True)
class Aligned:
    result: Result
    expected: int | None     # 0-based index into the expected words (None for an extra word)
    heard: int | None        # 0-based index into the heard tokens (None for a missing word)


def similar(a: str, b: str) -> bool:
    return fuzz.ratio(a, b) >= MATCH_RATIO


def align(expected: list[str], heard: list[str]) -> list[Aligned]:
    """Align normalized expected words with normalized heard tokens. Among equally cheap alignments the earliest
    words are paired first (a repeated word is the later one), so the DP runs on the reversed sequences."""
    n, m = len(expected), len(heard)
    reversed_steps = _align(expected[::-1], heard[::-1])
    return [Aligned(s.result, None if s.expected is None else n - 1 - s.expected,
                    None if s.heard is None else m - 1 - s.heard) for s in reversed(reversed_steps)]


def _align(expected: list[str], heard: list[str]) -> list[Aligned]:
    n, m = len(expected), len(heard)
    cost = [[0] * (m + 1) for _ in range(n + 1)]
    for i in range(1, n + 1):
        cost[i][0] = i
    for j in range(1, m + 1):
        cost[0][j] = j
    same = [[similar(expected[i], heard[j]) for j in range(m)] for i in range(n)]
    for i in range(1, n + 1):
        for j in range(1, m + 1):
            diagonal = cost[i - 1][j - 1] + (0 if same[i - 1][j - 1] else 1)
            cost[i][j] = min(diagonal, cost[i - 1][j] + 1, cost[i][j - 1] + 1)
    out: list[Aligned] = []
    i, j = n, m
    while i > 0 or j > 0:
        if i > 0 and j > 0 and cost[i][j] == cost[i - 1][j - 1] + (0 if same[i - 1][j - 1] else 1):
            out.append(Aligned("correct" if same[i - 1][j - 1] else "substituted", i - 1, j - 1))
            i, j = i - 1, j - 1
        elif i > 0 and cost[i][j] == cost[i - 1][j] + 1:
            out.append(Aligned("missing", i - 1, None))
            i -= 1
        else:
            out.append(Aligned("extra", None, j - 1))
            j -= 1
    out.reverse()
    return out


def heard_tokens(transcript: str) -> tuple[list[str], list[str]]:
    """The transcript's display tokens and their normalized forms (standalone marks/punctuation dropped)."""
    display, norm = [], []
    for raw in transcript.split():
        normalized = normalize_ar(raw)
        for part in normalized.split():
            display.append(raw if normalized == part else part)
            norm.append(part)
    return display, norm
