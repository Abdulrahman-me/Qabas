from __future__ import annotations

import asyncio

import pytest

from app.models import RaqeebMessage
from app.raqeeb import suggestions, worker
from app.runtime import Resources
from tests.learning.conftest import learner, revise
from tests.raqeeb.support import Tools, model
from tests.raqeeb.test_api_worker import send, start

pytestmark = pytest.mark.integration


async def test_context_pins_published_version_language_track_without_keys(fresh_curriculum):
    api, settings = fresh_curriculum
    headers = learner(api, language="en", track="explorer") | {"Accept-Language": "en"}
    context = {"lesson_id": "les_t1_0", "block_id": None}
    conv = start(api, headers, context=context)
    # Publishing a later version must never change the context this conversation already captured.
    def change(data):
        data["variants"]["en"]["explorer"]["title"] = "Later published title"

    await asyncio.to_thread(revise, settings, "les_t1_0", change)
    result = send(api, headers, conv)
    assert result.status_code == 202, result.text
    aid = result.json()["assistant_message"]["message_id"]
    resources = Resources.create(settings)
    try:
        client = model("general_knowledge")
        assert await worker.process(resources, aid, client=client, tools=Tools()) == "completed"
        data = next(d for p, d in client.calls if p == "raqeeb_classify")
        assert data["context"]["title"] != "Later published title"
        assert "correct_option_id" not in str(data["context"]) and "exercise_versions" not in data["context"]
        assert "usr_" not in str(data) and "msg_" not in str(data) and "conv_" not in str(data)
        async with resources.sessionmaker() as db:
            row = await db.get(RaqeebMessage, aid)
            assert row.input_snapshot["profile"]["language"] == "en"
            assert row.input_snapshot["profile"]["track"] == "explorer"
    finally:
        await resources.close()


async def test_suggested_lessons_use_cosine_track_and_published_content(fresh_curriculum):
    _, settings = fresh_curriculum
    resources = Resources.create(settings)
    seen = []

    class Vectors:
        async def encode(self, texts):
            seen.extend(texts)
            # Exactly .6 passes; .599 fails. At most two results, stable ties in curriculum order.
            return [[1, 0]] + [[1, 0], [.6, .8], [.599, .801]] + [[0, 1]] * (len(texts) - 4)

    try:
        async with resources.sessionmaker() as db:
            links = await suggestions.recommend(db, "Neutral question", "new_muslim", "en", Vectors())
            assert len(links) == 2 and links[0]["lesson_id"] == "les_t2_0"
            assert links[1]["lesson_id"] == "les_t2_1"
            assert seen[0] == "Neutral question"
            assert all(link["title"] for link in links)
    finally:
        await resources.close()


async def test_history_window_is_six_messages_not_full_conversation(fresh_curriculum):
    api, settings = fresh_curriculum
    headers = learner(api, language="en") | {"Accept-Language": "en"}
    conv = start(api, headers)
    resources = Resources.create(settings)
    try:
        for i in range(4):
            aid = send(api, headers, conv, question=f"Neutral question {i}").json()["assistant_message"]["message_id"]
            assert await worker.process(resources, aid, client=model("out_of_scope"), tools=Tools()) == "completed"
        accepted = send(api, headers, conv, question="Follow up")
        aid = accepted.json()["assistant_message"]["message_id"]
        async with resources.sessionmaker() as db:
            row = await db.get(RaqeebMessage, aid)
            history = row.input_snapshot["history"]
            assert len(history) == 6
            assert "Neutral question 0" not in str(history)
            assert history[0]["text"] == "Neutral question 1"
    finally:
        await resources.close()


async def test_active_context_uses_served_content_after_publish_and_track_change(fresh_curriculum):
    api, settings = fresh_curriculum
    headers = learner(api, language="ar", track="explorer")
    from tests.learning.test_sessions import start as start_lesson
    served = start_lesson(api, headers, {"kind": "lesson", "lesson_id": "les_t1_0"}, lang="ar")
    await asyncio.to_thread(revise, settings, "les_t1_0",
        lambda data: data["variants"]["ar"]["explorer"].update(title="Later title"))
    assert api.patch("/v1/me", json={"language": "en", "track": "new_muslim"}, headers=headers).status_code == 200
    conv = start(api, headers | {"Accept-Language": "en"}, context={"lesson_id": "les_t1_0", "block_id": None})
    aid = send(api, headers, conv).json()["assistant_message"]["message_id"]
    resources = Resources.create(settings)
    try:
        async with resources.sessionmaker() as db:
            row = await db.get(RaqeebMessage, aid)
            context = row.input_snapshot["context"]
            assert context["title"] == served["title"] and context["title"] != "Later title"
            assert context["blocks"][0] == served["items"][0]
            assert all(set(b) == {"block_id", "type", "exercise_id"} for b in context["blocks"]
                       if b["type"] == "exercise")
            assert "answer_key" not in str(context)
    finally:
        await resources.close()
