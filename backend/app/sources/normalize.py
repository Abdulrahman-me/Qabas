"""Arabic normalization for matching (SOURCE_ADAPTERS §12.1). Used wherever text is compared, never for display.

The §12.1 rule removes harakat and Quranic annotation marks (U+064B-U+065F, U+0670, U+06D6-U+06ED) and
tatweel, unifies alef/ya/ta marbuta/hamza carriers, collapses whitespace and strips punctuation and ayah-number
glyphs. The canonical mushaf (KFGQPC Hafs v3.0, D-88) also writes the open tanween and other Quranic marks of
the Arabic Extended-A block (U+08D3-U+08FF); they are annotation marks too and are removed (F-66). Presentation
forms are folded first (NFKC) so pasted text in legacy encodings compares equal.
"""

from __future__ import annotations

import re
import unicodedata

_MARKS = re.compile("[ً-ٰٟۖ-ۭ࣓-ࣿـ​-‏⁠﻿]")
_LETTERS = str.maketrans({"أ": "\u0627", "إ": "\u0627", "آ": "\u0627", "ٱ": "\u0627",
                         "ى": "ي", "ة": "\u0647", "ؤ": "و", "ئ": "ي"})
_SPACE = re.compile(r"\s+")


def _is_separator(ch: str) -> bool:
    category = unicodedata.category(ch)
    # Punctuation, symbols (ayah ornaments, brackets) and digits (ayah numbers) all separate words.
    return category[0] in "PS" or category == "Nd"


def normalize_ar(text: str) -> str:
    text = unicodedata.normalize("NFKC", text)
    text = _MARKS.sub("", text)
    text = text.translate(_LETTERS)
    text = "".join(" " if _is_separator(ch) else ch for ch in text)
    return _SPACE.sub(" ", text).strip()


def tokens(text: str) -> list[str]:
    """Normalized words; a token that normalizes to nothing (a standalone mark) is not a word."""
    return [t for t in normalize_ar(text).split(" ") if t]
