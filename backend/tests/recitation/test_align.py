"""Alignment, outcome classes, the unclear rule, messages and the expected-text digest (backend §8 steps 3-9)."""

from __future__ import annotations

from typing import Any

import pytest

from app.contract import models as C
from app.services.recitation import align, messages
from app.services.recitation.engine import Transcription
from app.services.recitation.service import evaluate
from tests.recitation.support import NEUTRAL, heard, mushaf


def results(expected: list[str], spoken: list[str]) -> list[tuple[str, int | None, int | None]]:
    return [(a.result, a.expected, a.heard) for a in align.align(expected, spoken)]


def test_alignment_classes_and_deterministic_backtrace() -> None:
    words = ["قل", "هو", "الله", "احد"]
    assert results(words, words) == [("correct", i, i) for i in range(4)]
    assert results(words, ["قل", "هو", "احد"]) == [
        ("correct", 0, 0), ("correct", 1, 1), ("missing", 2, None), ("correct", 3, 2)]
    assert results(words, ["قل", "هو", "الكتاب", "احد"])[2] == ("substituted", 2, 2)
    assert results(words, ["قل", "هو", "هو", "الله", "احد"]) == [
        ("correct", 0, 0), ("correct", 1, 1), ("extra", None, 2), ("correct", 2, 3), ("correct", 3, 4)]
    assert results(words, []) == [("missing", i, None) for i in range(4)]
    assert results([], ["هو"]) == [("extra", None, 0)]


def test_match_threshold_is_ratio_80_on_normalized_tokens() -> None:
    assert align.similar("الرحمن", "الرحمان")          # 92: a spelling variant still matches
    assert align.similar("قل", "قال")                  # exactly 80: the specified threshold is inclusive
    assert not align.similar("قل", "هو")
    assert align.similar("مومنين", "مومنين")


def test_digest_is_over_normalized_words_so_diacritics_do_not_change_it() -> None:
    plain, marked = "قل هو الله احد", "قُلۡ هُوَ ٱللَّهُ أَحَدٌ"
    assert align.expected_text_digest(plain) == align.expected_text_digest(marked)
    assert align.expected_text_digest(plain) != align.expected_text_digest("قل هو الله")
    assert align.expected_text_digest("قُلۡ  هُوَ ۚ") == align.expected_text_digest("قل هو")


def test_heard_tokens_drop_marks_and_split_joined_punctuation() -> None:
    display, norm = align.heard_tokens("قُلْ، هُوَ ۚ")
    assert norm == ["قل", "هو"] and display == ["قُلْ،", "هُوَ"]


@pytest.mark.parametrize(("transcription", "unclear"), [
    (Transcription("", 0, None), True), (Transcription("قل", 0, None), True), (Transcription("   ", 1, -0.1), True),
    (Transcription("قل", 1, -1.01), True), (Transcription("قل", 1, -1.0), False), (Transcription("قل", 2, -0.2), False),
])
def test_unclear_rule(transcription: Transcription, unclear: bool) -> None:
    assert transcription.unclear is unclear


def body(passage_words: int = 25, spoken: str = "", language: str = "ar",
         segments: dict[int, dict[str, Any]] | None = None, logprob: float = -0.1) -> dict[str, Any]:
    passage = mushaf().get(2, 1, word_start=1, word_end=passage_words) if passage_words < 25 else mushaf().get(2, 1)
    return evaluate(passage, heard(spoken, logprob), language, segments or {})


def check(data: dict[str, Any]) -> C.RecitationCheck:
    return C.RecitationCheck.model_validate({"check_id": "rchk_test", **data})


def test_evaluated_pass_errors_and_extra_indices() -> None:
    passed = check(body(4, " ".join(NEUTRAL[:4])))
    assert passed.passed and passed.status == "evaluated" and [w.index for w in passed.words] == [0, 1, 2, 3]
    assert passed.words[0].expected == mushaf().get(2, 1).words[0].text           # canonical display text
    # An inserted word followed by a dropped last word (the cheapest alignment is unique here).
    errors = check(body(4, f"{NEUTRAL[0]} {NEUTRAL[10]} {NEUTRAL[1]} {NEUTRAL[2]}"))
    assert not errors.passed
    assert [(w.index, w.result) for w in errors.words] == [
        (0, "correct"), (1, "extra"), (1, "correct"), (2, "correct"), (3, "missing")]
    assert errors.summary.model_dump() == {"correct": 3, "missing": 1, "substituted": 0, "extra": 1}
    assert errors.words[1].heard == NEUTRAL[10] and errors.words[4].heard is None
    extra_only = check(body(4, " ".join(NEUTRAL[:4]) + " " + NEUTRAL[10]))
    assert extra_only.passed and extra_only.words[-1].index == 4 and extra_only.words[-1].expected is None


def test_unclear_check_has_no_words_and_never_passes() -> None:
    unclear = check(body(4, " ".join(NEUTRAL[:4]), logprob=-3.0))
    assert unclear.status == "unclear" and not unclear.passed and unclear.words == []
    assert unclear.message[0].text == messages.UNCLEAR["ar"]


def test_audio_segments_attach_to_expected_words_only() -> None:
    segments = {0: {"url": "https://cdn.example/clip.mp3", "start_ms": 0, "end_ms": 400}}
    data = check(body(4, f"{NEUTRAL[0]} {NEUTRAL[5]} {NEUTRAL[1]} {NEUTRAL[2]} {NEUTRAL[3]}", segments=segments))
    assert data.words[0].audio_segment is not None and data.words[0].audio_segment.end_ms == 400
    assert all(w.audio_segment is None for w in data.words[1:])


def test_messages_follow_outcome_number_and_language() -> None:
    def text(language: str, results_: list[str]) -> str:
        words = [{"expected": "x", "result": r} for r in results_]
        passed = not any(r in ("missing", "substituted") for r in results_)
        return messages.message(language, status="evaluated", passed=passed, words=words)[0]["text"]

    assert text("ar", ["correct"] * 3) == "ما شاء الله، قراءة صحيحة!"
    assert text("ar", ["correct", "correct", "substituted", "missing"]) == (
        "أحسنت في البداية! انتبه إلى الكلمتين المظللتين، اضغط على كل كلمة لتسمع نطقها ثم أعد المحاولة.")
    assert text("ar", ["missing", "correct"]).startswith("انتبه إلى الكلمة المظللة")     # no false praise
    assert "الكلمات المظللة" in text("ar", ["correct", "missing", "missing", "substituted"])
    assert text("en", ["correct", "missing"]).startswith("Good start! Look at the highlighted word:")
    assert text("fr", ["correct"]) == messages.PASSED["ar"]
