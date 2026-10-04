"""Server-side localized labels (the contract sends labels only where a field says so)."""

from __future__ import annotations

NEXT_STEP_TITLES: dict[str, dict[str, str]] = {
    "pretest": {"ar": "اختبار قصير قبل البدء", "en": "A quick check before you start"},
    "review": {"ar": "مراجعة", "en": "Review"},
    "unit_test": {"ar": "اختبار الوحدة", "en": "Unit test"},
}

ARABIC_INDIC_DIGITS = str.maketrans("0123456789", "٠١٢٣٤٥٦٧٨٩")


def localized_number(value: int, language: str) -> str:
    text = str(value)
    return text.translate(ARABIC_INDIC_DIGITS) if language == "ar" else text
