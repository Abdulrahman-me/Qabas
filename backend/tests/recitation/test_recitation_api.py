"""``POST /recitation/checks`` end to end (API §6.6, §3.7; backend §8): canonical expected words, outcomes,
privacy, idempotency, validation, exercise binding and the bound answer's XP/mastery effects."""

from __future__ import annotations

import uuid

import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.contract import models as C
from app.services.platform import rate_limits
from app.services.recitation import service
from app.services.recitation.align import expected_text_digest
from app.sources.mushaf import MushafError
from tests.api.helpers import query
from tests.learning.conftest import learner, user_id
from tests.learning.test_misconceptions_and_recitation import (
    ORDER,
    RECITE,
    SCENARIO,
    SPOT,
    WHICH,
    recite,
    start,
    submit,
)
from tests.recitation.conftest import post_check
from tests.recitation.support import NEUTRAL, FakeTranscriber, fixture_payload, heard, mushaf, wav

pytestmark = pytest.mark.integration
App = tuple[TestClient, Settings, FakeTranscriber]


def test_a_passing_check_is_stored_without_audio_and_answers_the_exercise(recitation_app: App) -> None:
    client, settings, fake = recitation_app
    headers = learner(client)
    session = start(client, headers)
    payload = fixture_payload()
    fake.answer = heard(payload["text_uthmani"])
    response = post_check(client, headers, exercise_id=RECITE)
    assert response.status_code == 200, response.text
    check = C.RecitationCheck.model_validate(response.json())
    assert check.passed and check.status == "evaluated" and check.check_id.startswith("rchk_")
    assert [w.expected for w in check.words] == [w.text for w in mushaf().get(112, 1).words]   # canonical words
    timing = payload["audio"]["words"][0]
    assert check.words[0].audio_segment == C.AudioSeg(url=payload["audio"]["url"], start_ms=timing["start_ms"],
                                                      end_ms=timing["end_ms"])
    assert check.message[0].text == "ما شاء الله، قراءة صحيحة!"
    (row,) = query(settings.database_url, "SELECT * FROM recitation_checks WHERE id = $1", check.check_id)
    assert row["user_id"] == user_id(client, headers) and (row["surah"], row["ayah"]) == (112, 1)
    assert row["checked_text_sha256"] == expected_text_digest(payload["text_uthmani"])
    assert set(row.keys()) == {"id", "user_id", "surah", "ayah", "word_start", "word_end",   # no audio column
                               "checked_text_sha256", "status", "passed", "words", "summary", "created_at"}
    assert fake.calls and fake.calls[0][1] == "audio/wav"          # sniffed, not the declared audio/mp4

    for exercise_id in (SPOT, WHICH, ORDER, SCENARIO):              # the recitation is served after these
        submit(client, headers, session, exercise_id, "correct")
    evaluation = recite(client, headers, session, {"check_id": check.check_id})
    assert evaluation["correct"] is True and evaluation["xp_awarded"] == 3
    assert evaluation["mastery_changes"] and evaluation["mastery_changes"][0]["after"] > \
        evaluation["mastery_changes"][0]["before"]


def test_errors_and_unclear_outcomes_in_the_learners_language(recitation_app: App) -> None:
    client, _, fake = recitation_app
    headers = learner(client, language="en")
    words = fixture_payload()["text_uthmani"].split()
    fake.answer = heard(" ".join([*words[:2], "الكتاب"]))
    errors = C.RecitationCheck.model_validate(post_check(client, headers).json())
    # «قل هو الكتاب» against «قل هو الله أحد»: the third word substituted, the fourth missing.
    assert not errors.passed
    assert errors.summary.model_dump() == {"correct": 2, "missing": 1, "substituted": 1, "extra": 0}
    assert errors.message[0].text.startswith("Good start! Look at the highlighted words")
    assert all(w.audio_segment is None for w in errors.words)       # outside a session: no clip timings
    fake.answer = heard("", 0.0)
    unclear = C.RecitationCheck.model_validate(post_check(client, headers).json())
    assert unclear.status == "unclear" and unclear.words == [] and not unclear.passed
    assert unclear.message[0].text.startswith("We couldn't hear you clearly")


def test_idempotency_replays_without_a_second_transcription(recitation_app: App) -> None:
    client, settings, fake = recitation_app
    headers = learner(client)
    fake.answer = heard(fixture_payload()["text_uthmani"])
    key = str(uuid.uuid4())
    first = post_check(client, headers, key=key)
    second = post_check(client, headers, key=key)
    assert first.status_code == second.status_code == 200 and first.json() == second.json()
    assert len(fake.calls) == 1
    assert len(query(settings.database_url, "SELECT id FROM recitation_checks")) == 1
    other = post_check(client, headers, key=key, audio=wav(0.5))         # same key, different (valid) audio
    assert other.status_code == 409 and other.json()["error"]["code"] == "idempotency_conflict"
    missing = client.post("/v1/recitation/checks", data={"surah": "112", "ayah": "1"},
                          files={"audio": ("a.wav", b"RIFF", "audio/wav")}, headers=headers)
    assert missing.status_code == 400 and missing.json()["error"]["details"]["field"] == "Idempotency-Key"


@pytest.mark.parametrize(("change", "status", "code", "field"), [
    ({"audio": b"\x00" * (5 * 1024 * 1024 + 1)}, 413, "payload_too_large", "audio"),
    ({"audio": b"%PDF-1.7 not audio at all"}, 415, "unsupported_media_type", "audio"),
    ({"audio": b""}, 400, "validation_error", "audio"),
    ({"ayah": 9}, 400, "validation_error", "ayah"),
    ({"surah": 115}, 400, "validation_error", "surah"),
    ({"word_start": 2}, 400, "validation_error", "word_end"),
    ({"word_start": 3, "word_end": 9}, 400, "validation_error", "word_start"),
    ({"word_start": 3, "word_end": 2}, 400, "validation_error", "word_start"),
    ({"extra": {"surah": "one"}}, 400, "validation_error", "surah"),
    ({"exercise_id": "les_not_an_exercise"}, 400, "validation_error", "exercise_id"),
])
def test_invalid_requests_are_refused_before_any_transcription(recitation_app: App, change: dict[str, object],
                                                               status: int, code: str, field: str) -> None:
    client, _, fake = recitation_app
    response = post_check(client, learner(client), **change)  # type: ignore[arg-type]
    assert response.status_code == status, response.text
    assert response.json()["error"]["code"] == code
    if status != 413 or field:
        assert response.json()["error"]["details"].get("field") == field
    assert fake.calls == []


def test_exercise_binding_refuses_anything_but_the_callers_matching_served_exercise(recitation_app: App) -> None:
    client, _, fake = recitation_app
    headers, other = learner(client), learner(client)
    start(client, headers)
    fake.answer = heard(fixture_payload()["text_uthmani"])
    for kwargs in ({"exercise_id": "ex_unknown"}, {"exercise_id": RECITE, "word_start": 1, "word_end": 2},
                   {"exercise_id": RECITE, "ayah": 2}):
        response = post_check(client, headers, **kwargs)  # type: ignore[arg-type]
        assert response.status_code == 409 and response.json()["error"]["code"] == "recitation_check_mismatch"
    foreign = post_check(client, other, exercise_id=RECITE)          # not served to this learner
    assert foreign.status_code == 409 and foreign.json()["error"]["code"] == "recitation_check_mismatch"
    assert fake.calls == []
    assert post_check(client, headers, exercise_id=RECITE).status_code == 200


def test_checks_without_the_canonical_mushaf_are_unavailable(recitation_app: App,
                                                             monkeypatch: pytest.MonkeyPatch) -> None:
    client, _, fake = recitation_app

    def missing(settings: Settings) -> None:
        raise MushafError("not installed")

    monkeypatch.setattr(service, "get_mushaf", missing)
    response = post_check(client, learner(client))
    assert response.status_code == 503 and response.json()["error"]["code"] == "upstream_unavailable"
    assert response.json()["error"]["details"]["retry_after_ms"] > 0 and fake.calls == []


def test_authentication_and_rate_limit(recitation_app: App, monkeypatch: pytest.MonkeyPatch) -> None:
    client, _, fake = recitation_app
    assert client.post("/v1/recitation/checks", data={"surah": "112", "ayah": "1"}).status_code == 401
    monkeypatch.setitem(rate_limits.PROFILES["default"], "recitation_check", (rate_limits.Limit(1, 60),))
    headers = learner(client)
    fake.answer = heard(" ".join(NEUTRAL[:2]))
    assert post_check(client, headers).status_code == 200
    limited = post_check(client, headers)
    assert limited.status_code == 429 and limited.json()["error"]["code"] == "rate_limited"
