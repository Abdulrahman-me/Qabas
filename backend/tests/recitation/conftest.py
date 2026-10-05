"""Recitation integration fixtures: the real app and curriculum, the stand-in mushaf and an in-process transcriber."""

from __future__ import annotations

import uuid
from collections.abc import Callable, Iterator
from typing import Any

import pytest
from fastapi.testclient import TestClient

from app.api.recitation import get_transcriber
from app.config import Settings
from app.services.recitation import service
from tests.learning.conftest import fresh_curriculum, learner, revise  # noqa: F401  (fixture re-export)
from tests.learning.test_misconceptions_and_recitation import RECITE, _with_misconception_and_recitation
from tests.recitation.support import FakeTranscriber, fixture_payload, mushaf, wav


@pytest.fixture
def stand_in_mushaf(monkeypatch: pytest.MonkeyPatch) -> None:
    canonical = mushaf()
    monkeypatch.setattr(service, "get_mushaf", lambda settings: canonical)


@pytest.fixture
def recitation_app(fresh_curriculum: tuple[TestClient, Settings],  # noqa: F811
                   stand_in_mushaf: None) -> Iterator[tuple[TestClient, Settings, FakeTranscriber]]:
    """``les_t2_2`` serving the contract's ``recite_verse`` (112:1) and a transcriber the test scripts."""
    client, settings = fresh_curriculum
    revise(settings, "les_t2_2", _with_misconception_and_recitation)
    fake = FakeTranscriber()
    client.app.dependency_overrides[get_transcriber] = lambda: fake  # type: ignore[attr-defined]
    yield client, settings, fake
    client.app.dependency_overrides.clear()  # type: ignore[attr-defined]


def post_check(client: TestClient, headers: dict[str, str], *, surah: int = 112, ayah: int = 1,
               word_start: int | None = None, word_end: int | None = None, exercise_id: str | None = None,
               audio: bytes | None = None, key: str | None = None,
               extra: dict[str, Any] | None = None) -> Any:
    fields: dict[str, Any] = {"surah": str(surah), "ayah": str(ayah)}
    for name, value in (("word_start", word_start), ("word_end", word_end), ("exercise_id", exercise_id)):
        if value is not None:
            fields[name] = str(value)
    fields.update(extra or {})
    return client.post("/v1/recitation/checks", data=fields,
                       files={"audio": ("recitation.m4a", wav() if audio is None else audio, "audio/mp4")},
                       headers={**headers, "Idempotency-Key": key or str(uuid.uuid4())})


__all__ = ["RECITE", "fixture_payload", "post_check"]
Checker = Callable[..., Any]
