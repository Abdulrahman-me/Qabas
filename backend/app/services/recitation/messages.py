"""Localized recitation messages: fixed templates chosen by outcome, never generated (backend §8 step 9).

Arabic follows API §6.6: the passed and unclear sentences verbatim, and the errors sentence with its noun and
adjective agreeing with the number of highlighted words (one / two / more). "أحسنت في البداية!" opens the errors
message only when the learner's first word was correct, so the praise is never false. The English sentences are
translations of these templates; their wording is pending product copy review together with the other open copy
items (D-110). Nothing here is religious content: the verse itself is always the canonical text.
"""

from __future__ import annotations

from typing import Any

PASSED = {"ar": "ما شاء الله، قراءة صحيحة!", "en": "Excellent — your recitation is correct!"}
UNCLEAR = {"ar": "لم نسمعك بوضوح. اقترب من الميكروفون وأعد المحاولة في مكان هادئ.",
           "en": "We couldn't hear you clearly. Move closer to the microphone and try again somewhere quiet."}
GOOD_START = {"ar": "أحسنت في البداية! ", "en": "Good start! "}
HIGHLIGHTED = {
    "ar": {1: "انتبه إلى الكلمة المظللة، اضغط عليها لتسمع نطقها ثم أعد المحاولة.",
           2: "انتبه إلى الكلمتين المظللتين، اضغط على كل كلمة لتسمع نطقها ثم أعد المحاولة.",
           3: "انتبه إلى الكلمات المظللة، اضغط على كل كلمة لتسمع نطقها ثم أعد المحاولة."},
    "en": {1: "Look at the highlighted word: tap it to hear how it is pronounced, then try again.",
           2: "Look at the highlighted words: tap each word to hear how it is pronounced, then try again.",
           3: "Look at the highlighted words: tap each word to hear how it is pronounced, then try again."},
}


def message(language: str, *, status: str, passed: bool, words: list[dict[str, Any]]) -> list[dict[str, str]]:
    lang = language if language in PASSED else "ar"
    if status == "unclear":
        text = UNCLEAR[lang]
    elif passed:
        text = PASSED[lang]
    else:
        highlighted = sum(1 for w in words if w["result"] in ("missing", "substituted"))
        expected = [w for w in words if w["expected"] is not None]
        start = GOOD_START[lang] if expected and expected[0]["result"] == "correct" else ""
        text = start + HIGHLIGHTED[lang][min(highlighted, 3)]
    return [{"type": "text", "text": text}]
