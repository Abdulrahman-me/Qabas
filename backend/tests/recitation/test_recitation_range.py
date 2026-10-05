"""QUALITY §18.1 ``test_recitation_range``: a check of words 1-7 cannot answer an exercise serving words 14-20 of the
same ayah (``409 recitation_check_mismatch``); the matching range succeeds. Checks are produced by the real endpoint.
"""

from __future__ import annotations

import copy
from typing import Any

import pytest
from fastapi.testclient import TestClient

from app.api.recitation import get_transcriber
from app.config import Settings
from tests.learning.conftest import learner, revise
from tests.learning.test_misconceptions_and_recitation import (
    ORDER,
    RECITE,
    SCENARIO,
    SPOT,
    WHICH,
    _with_misconception_and_recitation,
    recite,
    start,
    submit,
)
from tests.recitation.conftest import post_check
from tests.recitation.support import LONG_AYAH, LONG_SURAH, FakeTranscriber, heard, mushaf

pytestmark = pytest.mark.integration


def _serving_words_14_to_20(data: dict[str, Any]) -> None:
    _with_misconception_and_recitation(data)
    segment = mushaf().get(LONG_SURAH, LONG_AYAH, word_start=14, word_end=20)
    exercise = next(e for e in data["exercises"] if e["exercise_id"] == RECITE)
    for lang in ("ar", "en"):
        payload = copy.deepcopy(exercise["exercise"][lang]["payload"])
        payload.update({"surah": LONG_SURAH, "ayah": LONG_AYAH, "word_start": 14, "word_end": 20,
                        "text_uthmani": segment.text_uthmani})
        payload["audio"] = {**payload["audio"], "words": None}
        exercise["exercise"][lang]["payload"] = payload


def test_a_check_of_other_words_of_the_same_ayah_cannot_answer(fresh_curriculum: tuple[TestClient, Settings],
                                                               stand_in_mushaf: None) -> None:
    client, settings = fresh_curriculum
    revise(settings, "les_t2_2", _serving_words_14_to_20)
    fake = FakeTranscriber()
    client.app.dependency_overrides[get_transcriber] = lambda: fake  # type: ignore[attr-defined]
    headers = learner(client)
    session = start(client, headers)
    for exercise_id in (SPOT, WHICH, ORDER, SCENARIO):
        submit(client, headers, session, exercise_id, "correct")
    words = [w.text for w in mushaf().get(LONG_SURAH, LONG_AYAH).words]

    fake.answer = heard(" ".join(words[0:7]))
    first_seven = post_check(client, headers, surah=LONG_SURAH, ayah=LONG_AYAH, word_start=1, word_end=7)
    assert first_seven.status_code == 200 and first_seven.json()["passed"] is True
    mismatch = recite(client, headers, session, {"check_id": first_seven.json()["check_id"]}, status=409)
    assert mismatch["error"]["code"] == "recitation_check_mismatch"

    fake.answer = heard(" ".join(words[13:20]))
    served = post_check(client, headers, surah=LONG_SURAH, ayah=LONG_AYAH, word_start=14, word_end=20,
                        exercise_id=RECITE)
    assert served.status_code == 200 and [w["index"] for w in served.json()["words"]] == list(range(7))
    evaluation = recite(client, headers, session, {"check_id": served.json()["check_id"]})
    assert evaluation["correct"] is True and evaluation["xp_awarded"] == 3
    client.app.dependency_overrides.clear()  # type: ignore[attr-defined]
