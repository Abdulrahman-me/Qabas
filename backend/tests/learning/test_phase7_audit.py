"""Regression tests for the Phase 7 audit corrections (F-48-F-52, decisions D-76-D-78)."""

from __future__ import annotations

import asyncio
from typing import Any

import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.models import OutboxEvent
from app.runtime import Resources
from app.services.learning import finish_events
from app.services.learning.progress import quest_title
from app.services.platform import outbox
from app.services.platform.rate_limits import PROFILES, Limit
from tests.api.helpers import query
from tests.learning.conftest import learner
from tests.learning.test_answers import start
from tests.learning.test_finish import filled, finish

pytestmark = pytest.mark.integration


def test_list_endpoints_follow_the_pagination_convention(learn_api: TestClient) -> None:
    # API §3.5: limit defaults to 20 and is at most 50; a cursor names an item of that list.
    headers = learner(learn_api)
    for path in ("/v1/glossary", "/v1/me/concepts"):
        assert learn_api.get(f"{path}?limit=50", headers=headers).status_code == 200
        assert learn_api.get(f"{path}?limit=51", headers=headers).status_code == 400
        assert learn_api.get(f"{path}?limit=0", headers=headers).status_code == 400
    assert learn_api.get("/v1/glossary?cursor=con_x", headers=headers).status_code == 400
    assert learn_api.get("/v1/me/concepts?cursor=term_x", headers=headers).status_code == 400


def test_finish_shares_the_answer_rate_limit(learn_api: TestClient, monkeypatch: pytest.MonkeyPatch) -> None:
    # Backend §5.1: "Session answers/finish 120 per minute per user" - one budget for both.
    monkeypatch.setitem(PROFILES["default"], "session_answer", (Limit(5, 60),))
    headers = learner(learn_api)
    session = start(learn_api, headers, {"kind": "lesson", "lesson_id": "les_t1_0"})
    filled(learn_api, headers, session)                                   # four answers
    finish(learn_api, headers, session)                                   # the fifth request
    response = learn_api.post(f"/v1/sessions/{session['session_id']}/finish", headers=headers,
                              json={"duration_ms": 0})
    assert response.status_code == 429 and response.json()["error"]["code"] == "rate_limited"


async def _relay(settings: Settings) -> None:
    resources = Resources.create(settings)
    try:
        while await outbox.relay_one(resources.sessionmaker):
            pass
    finally:
        await resources.close()


def test_finish_events_are_consumed_and_fan_out_once(learn_api: TestClient, curriculum_settings: Settings,
                                                     monkeypatch: pytest.MonkeyPatch) -> None:
    # D-77: the event completes with no subscriber yet; each subscriber applies its effect exactly once.
    assert outbox.CONSUMERS[finish_events.KIND] is finish_events.dispatch
    headers = learner(learn_api)
    session = start(learn_api, headers, {"kind": "lesson", "lesson_id": "les_t1_0"})
    filled(learn_api, headers, session)
    finish(learn_api, headers, session)
    key = f"session:{session['session_id']}:finished"
    asyncio.run(_relay(curriculum_settings))
    row = query(curriculum_settings.database_url, "SELECT processed_at, attempts, last_error FROM outbox_events "
                "WHERE event_key = $1", key)[0]
    assert row["processed_at"] is not None and row["attempts"] == 0 and row["last_error"] is None

    applied: list[str] = []

    async def achievements(db: Any, event: OutboxEvent) -> None:
        applied.append(event.event_key)

    monkeypatch.setitem(finish_events.SUBSCRIBERS, "achievements", achievements)
    for _ in range(2):                                                   # redelivery is harmless
        query(curriculum_settings.database_url, "UPDATE outbox_events SET processed_at = NULL WHERE event_key = $1",
              key)
        asyncio.run(_relay(curriculum_settings))
    assert applied == [key]


def test_quest_titles_agree_with_their_number() -> None:
    assert quest_title("complete_lessons", 1, "en") == "Complete a lesson"
    assert quest_title("complete_lessons", 2, "en") == "Complete 2 lessons"
    assert quest_title("complete_lessons", 2, "ar") == "أكمل درسين"            # the API §6.2 example
    assert quest_title("complete_lessons", 1, "ar") == "أكمل درساً"
    assert quest_title("earn_xp", 30, "ar") == "اجمع 30 جمرة"
    assert quest_title("perfect_lesson", 1, "en") == "Finish a lesson without mistakes"
