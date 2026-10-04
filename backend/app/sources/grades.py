"""Hadith grade categories from a muhaddith's verbatim ruling (D-94).

The contract asks for a ``grade_category`` next to the verbatim ``grade_label``. Only a ruling that is exactly
one of the standard words below is classified; every other phrasing — "إسناده صحيح" (a ruling on the chain only),
"صحيح على شرط مسلم", "ثابت", "موقوف", combined or qualified rulings — is ``other`` and goes to a specialist
(``needs_specialist``). The table is deliberately small: widening it is a specialist decision, not code.
"""

from __future__ import annotations

from typing import Literal

from app.sources.normalize import normalize_ar

GradeCategory = Literal["authentic", "acceptable", "weak", "fabricated", "other"]

_EXACT: dict[str, GradeCategory] = {
    "صحيح": "authentic",
    "حسن": "acceptable",
    "ضعيف": "weak",
    "ضعيف جدا": "weak",
    "موضوع": "fabricated",
}
RULE = "qabas.grade_table/1: exact standard ruling only, otherwise other"


def classify(label: str) -> GradeCategory:
    return _EXACT.get(normalize_ar(label.replace("[", " ").replace("]", " ")), "other")


def citable(category: GradeCategory) -> bool:
    """Factory §13: only authentic or acceptable hadith may support a claim or be quoted."""
    return category in ("authentic", "acceptable")
