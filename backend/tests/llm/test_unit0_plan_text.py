"""Authoring translation may not edit scripture, claims, concepts, keys or review decisions."""
from __future__ import annotations

from copy import deepcopy

import pytest

from scripts.prepare_unit0_plan_text import apply_translations


def record():
    return {"plan": {"lesson_arc": {"rationale": "Compare two everyday explanations.",
        "steps": [{"step_id": "s1", "experience": "Observe a neutral example."}]},
        "reasoning_tools": [{"tool": "comparison", "justification": "Compare the examples."}],
        "introduced_concept_ids": ["con_existing"]},
        "claims": [{"claim_id": "clm_existing", "text": "unchanged authored text"}],
        "answer_keys": {"exe_existing": {"correct_answer": "a"}},
        "evidence": {"verified_source": "preserve opaque original"}}


def test_only_missing_plan_language_changes_and_original_english_survives():
    authored = record()
    original = deepcopy(authored)
    apply_translations(authored, {"translations": [
        {"id": "arc/rationale", "ar": "قارن تفسيرين من الحياة اليومية."},
        {"id": "arc/s1", "ar": "لاحظ مثالًا بسيطًا."},
        {"id": "tool/0", "ar": "قارن بين المثالين."}]})
    assert authored["claims"] == original["claims"]
    assert authored["answer_keys"] == original["answer_keys"]
    assert authored["evidence"] == original["evidence"]
    assert authored["plan"]["introduced_concept_ids"] == original["plan"]["introduced_concept_ids"]
    assert authored["plan"]["lesson_arc"]["rationale"]["en"] == original["plan"]["lesson_arc"]["rationale"]


@pytest.mark.parametrize("translations", [[], [{"id": "invented", "ar": "نص"}],
    [{"id": "arc/rationale", "ar": "نص"}, {"id": "arc/rationale", "ar": "نص"}]])
def test_missing_extra_or_duplicate_translation_does_not_partially_edit_authoring(translations):
    authored = record()
    original = deepcopy(authored)
    with pytest.raises(ValueError):
        apply_translations(authored, {"translations": translations})
    assert authored == original
