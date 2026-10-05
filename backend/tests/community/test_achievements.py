"""Achievements (backend §10.7, ``GET /me/achievements``): seeded definitions in registry order, counters derived from
authoritative tables (completed Raqeeb answers, lessons, streaks, ...), refresh by the ``session.finished`` subscriber,
the ``raqeeb.completed`` consumer and reads, ``unlocked_at`` set once and never revoked, backfill, and exclusions."""

from __future__ import annotations

import json
from datetime import UTC, date, datetime, timedelta
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select, text

from app.config import Settings
from app.contract import models as C
from app.models import LearnerAchievement, User
from app.raqeeb import worker as raqeeb_worker  # noqa: F401  (registers its consumers)
from app.registries import registries
from app.runtime import Resources
from app.services.community import achievements
from app.services.platform import outbox
from tests.community.support import make_user, signed_in
from tests.learning.conftest import learner, user_id
from tests.learning.test_answers import start
from tests.learning.test_finish import filled, finish

pytestmark = pytest.mark.integration


def items(api: TestClient, headers: dict[str, str], lang: str = "en") -> dict[str, dict[str, Any]]:
    response = api.get("/v1/me/achievements", headers=headers | {"Accept-Language": lang})
    assert response.status_code == 200, response.text
    body = C.Achievements.model_validate(response.json()).model_dump()
    return {item["achievement_key"]: item for item in body["items"]}


async def test_definitions_follow_the_registry_and_start_locked(api: TestClient, resources: Resources) -> None:
    _, headers = await signed_in(resources)
    english = items(api, headers)
    registry = registries()["achievements"]["items"]
    assert list(english) == [a["achievement_key"] for a in registry]                  # the prototype's eight
    for definition in registry:
        item = english[definition["achievement_key"]]
        assert (item["title"], item["description"]) == (definition["title"]["en"], definition["description"]["en"])
        assert item["unlocked"] is False and item["unlocked_at"] is None
        assert item["progress"] == {"current": 0, "target": definition["target"]}
    assert items(api, headers, "ar")["seeker"]["title"] == "الباحث"


async def _days(resources: Resources, uid: str, days: list[date]) -> None:
    async with resources.sessionmaker() as db, db.begin():
        for day in days:
            await db.execute(text("INSERT INTO daily_activity (user_id, local_date, minutes, xp, qualifying) "
                                  "VALUES (:u, :d, 10, 10, true)"), {"u": uid, "d": day})


async def test_unlock_is_set_once_and_never_revoked(api: TestClient, resources: Resources) -> None:
    uid, headers = await signed_in(resources)
    await _days(resources, uid, [date(2026, 9, 1), date(2026, 9, 2)])
    assert items(api, headers)["kindled"]["progress"] == {"current": 2, "target": 3}
    await _days(resources, uid, [date(2026, 9, 3), date(2026, 9, 10)])
    first = items(api, headers)
    assert first["kindled"]["unlocked"] is True and first["kindled"]["progress"] == {"current": 3, "target": 3}
    assert first["steadyFlame"]["progress"] == {"current": 3, "target": 7}
    unlocked_at = first["kindled"]["unlocked_at"]
    assert items(api, headers)["kindled"]["unlocked_at"] == unlocked_at                # recomputing keeps it
    async with resources.sessionmaker() as db, db.begin():
        await db.execute(text("DELETE FROM daily_activity WHERE user_id = :u"), {"u": uid})
    again = items(api, headers)["kindled"]
    assert again["unlocked"] is True and again["unlocked_at"] == unlocked_at          # never revoked
    assert again["progress"] == {"current": 3, "target": 3}
    async with resources.sessionmaker() as db:
        row = await db.get(LearnerAchievement, (uid, "kindled"))
        assert row is not None and row.progress == 0                                   # stored progress is current


async def _raqeeb(resources: Resources, uid: str, replies: list[str | None]) -> None:
    """One conversation; one user message per entry, answered with that status (None: still unanswered)."""
    empty = json.dumps({})
    async with resources.sessionmaker() as db, db.begin():
        conv = f"conv_T{uid[-8:]}"
        await db.execute(text("INSERT INTO raqeeb_conversations (id, user_id, language, track, context_snapshot) "
                              "VALUES (:c, :u, 'en', 'explorer', '{}') ON CONFLICT DO NOTHING"), {"c": conv, "u": uid})
        for index, status in enumerate(replies):
            question = f"msg_Q{uid[-8:]}{index}"
            await db.execute(text(
                "INSERT INTO raqeeb_messages (id, conversation_id, role, status, stage, text, attachments, trace, "
                "input_snapshot) VALUES (:m, :c, 'user', 'received', 'received', 'q', '[]', :e, :e)"),
                {"m": question, "c": conv, "e": empty})
            if status is None:
                continue
            done = status == "completed"
            await db.execute(text(
                "INSERT INTO raqeeb_messages (id, conversation_id, reply_to, role, status, stage, attachments, "
                "trace, input_snapshot, completed_at, understood_input, classification, abstained, blocks, citations, "
                "terms, suggested_lessons, error) VALUES (:m, :c, :q, 'assistant', :s, :stage, '[]', :e, :e, "
                ":at, :ui, :ui, :ab, :list, :list, :list, :list, :err)"),
                {"m": f"msg_A{uid[-8:]}{index}", "c": conv, "q": question, "s": status,
                 "stage": "done" if done else "writing", "e": empty,
                 "at": datetime(2026, 10, 5, 10, tzinfo=UTC) if done else None,
                 "ui": empty if done else None, "ab": False if done else None, "list": "[]" if done else None,
                 "err": None if done else json.dumps({"code": "upstream_unavailable"})})


async def test_raqeeb_questions_count_completed_answers_only(api: TestClient, resources: Resources) -> None:
    uid, headers = await signed_in(resources)
    await _raqeeb(resources, uid, ["completed", "failed", None, "completed"])
    assert items(api, headers)["seeker"]["progress"] == {"current": 2, "target": 5}
    await _raqeeb(resources, uid, [])                                                  # polling changes nothing
    assert items(api, headers)["seeker"]["progress"]["current"] == 2


async def test_completed_raqeeb_answer_refreshes_through_the_outbox(resources: Resources) -> None:
    uid = await make_user(resources)
    await _raqeeb(resources, uid, ["completed"] * 5)
    async with resources.sessionmaker() as db, db.begin():
        await outbox.enqueue(db, event_key=f"raqeeb:msg_A{uid[-8:]}4:completed", kind="raqeeb.completed",
                             payload={"message_id": f"msg_A{uid[-8:]}4", "user_id": uid})
    await outbox.relay(resources.sessionmaker)
    async with resources.sessionmaker() as db:
        failure = await db.scalar(text("SELECT last_error FROM outbox_events WHERE kind = 'raqeeb.completed'"))
        assert failure is None, failure
        row = await db.get(LearnerAchievement, (uid, "seeker"))
        assert row is not None and row.progress == 5 and row.unlocked_at is not None


async def test_finished_lesson_unlocks_first_step_through_the_outbox(learn_api: TestClient,
                                                                    curriculum_settings: Settings) -> None:
    headers = learner(learn_api)
    uid = user_id(learn_api, headers)
    session = start(learn_api, headers, {"kind": "lesson", "lesson_id": "les_t1_0"})
    filled(learn_api, headers, session)
    result = finish(learn_api, headers, session)
    # The same finish placed the learner in this week's league with exactly the XP it awarded (one ledger).
    league = learn_api.get("/v1/leagues/current", headers=headers)
    assert league.status_code == 200, league.text
    assert league.json()["members"][0]["xp_week"] == result["xp"]["total"] > 0
    resources = Resources.create(curriculum_settings)
    try:
        await outbox.relay(resources.sessionmaker)
        async with resources.sessionmaker() as db:
            row = await db.get(LearnerAchievement, (uid, "firstStep"))
            assert row is not None and row.progress == 1 and row.unlocked_at is not None   # before any read
    finally:
        await resources.close()
    body = items(learn_api, headers)
    assert body["firstStep"]["unlocked"] is True and body["firstStep"]["progress"] == {"current": 1, "target": 1}
    assert body["quickLight"]["progress"] == {"current": 0, "target": 1}                 # challenges: Phase 19


async def test_synthetic_and_bot_users_are_not_tracked_and_backfill_converges(resources: Resources) -> None:
    learners = [await make_user(resources) for _ in range(2)]
    ignored = [await make_user(resources, is_synthetic=True), await make_user(resources, is_bot=True)]
    for uid in learners + ignored:
        await _days(resources, uid, [date(2026, 9, 1) + timedelta(days=i) for i in range(3)])
    assert await achievements.refresh_all(resources.sessionmaker) == 2
    assert await achievements.refresh_all(resources.sessionmaker) == 2                 # idempotent
    async with resources.sessionmaker() as db:
        rows = (await db.execute(select(LearnerAchievement.user_id, LearnerAchievement.achievement_key)
                                 .where(LearnerAchievement.unlocked_at.is_not(None)))).all()
        user = await db.get(User, ignored[0])
        assert user is not None
        await achievements.refresh(db, user)
    assert sorted(rows) == sorted((uid, "kindled") for uid in learners)


def test_counters_cover_the_spec_and_phase_19_supplies_challenges() -> None:
    from app.models.social import COUNTERS
    assert set(achievements.COUNTERS) == set(COUNTERS)
    assert {a["counter"] for a in registries()["achievements"]["items"]} <= set(COUNTERS)
    with pytest.raises(ValueError):
        achievements.register_counter("duels_played", achievements.challenges_won)
