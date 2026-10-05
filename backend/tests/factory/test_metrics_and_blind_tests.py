"""Reviewer metrics and blind tests (Phase 15): outbox-fed learning facts (idempotent, backfillable, synthetic and
bot users excluded), factory timings, blind pairs served as previews without revealing the gold side, answers
recorded once, and reviewer-only access."""

from __future__ import annotations

import uuid
from collections.abc import Iterator
from datetime import UTC, datetime, timedelta
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import func, select, text

from app.config import Settings
from app.contract import models as C
from app.models import BlindPair, FactoryRun, MetricLearnerFact, MetricUnitFact
from app.runtime import Resources
from app.services import blind_test, metrics
from app.services.learning import finish_events
from app.services.platform import outbox
from tests.factory.support import reviewer
from tests.learning.conftest import learner, user_id

pytestmark = pytest.mark.integration
PASSWORD = "a long passphrase"


@pytest.fixture
def console(fresh_curriculum: tuple[TestClient, Settings]) -> Iterator[tuple[TestClient, Settings]]:
    yield fresh_curriculum


@pytest.fixture
async def resources(console: tuple[TestClient, Settings]) -> Any:
    created = Resources.create(console[1])
    yield created
    await created.close()


def login(client: TestClient) -> dict[str, str]:
    response = client.post("/v1/auth/reviewer", json={"email": "usr_factory_reviewer@example.test",
                                                      "password": PASSWORD})
    assert response.status_code == 200, response.text
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


async def unit_state(resources: Resources, uid: str, unit_id: str, **values: Any) -> None:
    columns = ", ".join(values)
    params = ", ".join(f":{k}" for k in values)
    async with resources.sessionmaker() as db, db.begin():
        await db.execute(text(f"INSERT INTO learner_units (user_id, unit_id, {columns}) VALUES (:u, :unit, {params})"),
                         {"u": uid, "unit": unit_id, **values})


async def finished(resources: Resources, uid: str) -> None:
    async with resources.sessionmaker() as db, db.begin():
        await outbox.enqueue(db, event_key=f"session:test_{uuid.uuid4().hex}:finished", kind=finish_events.KIND,
                             payload={"session_id": "ses_test", "user_id": uid})
    await outbox.relay(resources.sessionmaker)


async def test_learning_metrics_are_outbox_fed_and_exclude_synthetic_users(
        console: tuple[TestClient, Settings], resources: Resources) -> None:
    client, _ = console
    await reviewer(resources)
    now = datetime.now(UTC)
    learners = [user_id(client, learner(client)) for _ in range(3)]
    for uid, (pre, post) in zip(learners, ((40, 80), (51, 90), (60, None)), strict=True):
        await unit_state(resources, uid, "unit_test_1", started_at=now, pretest_taken_at=now, pretest_percent=pre,
                         first_post_percent=post, completed_at=now if post is not None else None)
    async with resources.sessionmaker() as db, db.begin():
        await db.execute(text("UPDATE users SET is_synthetic = true WHERE id = :u"), {"u": learners[2]})
        mis = ["mis_metrics_a", "mis_metrics_b"]
        for misconception in mis:
            await db.execute(text("INSERT INTO misconceptions (id, unit_id, title, card) VALUES (:m, 'unit_test_1', "
                                  "'{}'::jsonb, '{}'::jsonb)"), {"m": misconception})
        for index, misconception in enumerate(mis):
            await db.execute(text(
                "INSERT INTO learner_misconceptions (user_id, misconception_id, status, activated_at, resolved_at) "
                "VALUES (:u, :m, :s, now(), :r)"),
                {"u": learners[0], "m": misconception, "s": "resolved" if index == 0 else "active",
                 "r": now if index == 0 else None})
    headers = login(client)
    before = client.get("/v1/admin/metrics", headers=headers).json()
    assert before["learning"]["pre_post"] == [] and before["raqeeb_benchmark"] is None
    assert before["learning"]["misconceptions"] == {"activated": 0, "resolved": 0, "resolution_rate_percent": None}
    for uid in learners:
        await finished(resources, uid)
        await finished(resources, uid)                         # redelivery/replay converges on the same facts
    body = C.Metrics.model_validate(client.get("/v1/admin/metrics", headers=headers).json())
    assert [(p.unit_id, p.participants, p.pre_avg_percent, p.post_avg_percent, p.delta)
            for p in body.learning.pre_post] == [("unit_test_1", 2, 46, 85, 39)]   # 45.5 → 46 half up
    assert body.learning.misconceptions.model_dump() == {"activated": 2, "resolved": 1,
                                                         "resolution_rate_percent": 50}
    assert body.learning.completion.model_dump() == {"units_started": 2, "units_completed": 2}
    async with resources.sessionmaker() as db:
        assert await db.scalar(select(func.count()).select_from(MetricUnitFact)) == 2      # synthetic: no facts
        assert await db.scalar(select(func.count()).select_from(MetricLearnerFact)) == 2
    # A backfill recomputes from the authoritative tables and changes nothing.
    async with resources.sessionmaker() as db, db.begin():
        assert await metrics.refresh_all(db) == 2
    assert C.Metrics.model_validate(client.get("/v1/admin/metrics", headers=headers).json()) == body
    assert client.get("/v1/admin/metrics", headers=learner(client)).status_code == 403


def test_generation_minutes_exclude_the_wait_at_gate1() -> None:
    created = datetime(2026, 10, 5, 10, 0, tzinfo=UTC)
    run = FactoryRun(created_at=created, gate1_decision={"decided_at": (created + timedelta(minutes=50)).isoformat()},
                     attempts=[{"stage": "plan", "event": "done", "at": (created + timedelta(minutes=2)).isoformat()},
                               {"stage": "qa", "event": "done", "at": (created + timedelta(minutes=60)).isoformat()}])
    assert metrics.generation_minutes(run) == 12                # 60 total - 48 waiting at Gate 1
    assert metrics.generation_minutes(FactoryRun(created_at=created, gate1_decision=None, attempts=[])) is None


async def test_blind_pairs_are_previews_answered_once_and_feed_the_metrics(
        console: tuple[TestClient, Settings], resources: Resources) -> None:
    client, _ = console
    await reviewer(resources)
    async with resources.sessionmaker() as db:
        with pytest.raises(blind_test.BlindTestError, match="gold"):
            async with db.begin():
                await blind_test.create_pair(db, gold="les_t1_0", generated="les_t2_0")   # fixtures are neither
        versions = (await db.execute(text("SELECT id FROM lesson_versions WHERE lesson_id IN ('les_t1_0', "
                                          "'les_t2_0') ORDER BY lesson_id"))).scalars().all()
    async with resources.sessionmaker() as db, db.begin():
        db.add(BlindPair(id="pair_test1", lesson_version_a=versions[0], lesson_version_b=versions[1], gold_side="a"))
    headers = login(client) | {"Accept-Language": "en"}
    served = client.get("/v1/admin/blind-test/next", headers=headers)
    assert served.status_code == 200
    pair = C.BlindPair.model_validate(served.json())
    assert pair.pair_id == "pair_test1" and pair.lesson_a.items and pair.lesson_b.items
    assert "gold" not in served.text and "answer_key" not in served.text
    answer = {"clearer": "b", "more_accurate": "same", "guessed_handwritten": "a"}
    assert client.post("/v1/admin/blind-test/pair_test1", json=answer, headers=headers).status_code == 204
    assert client.post("/v1/admin/blind-test/pair_test1", json=answer, headers=headers).status_code == 204
    changed = client.post("/v1/admin/blind-test/pair_test1", json=answer | {"clearer": "a"}, headers=headers)
    assert changed.status_code == 400
    assert client.post("/v1/admin/blind-test/pair_nope", json=answer, headers=headers).status_code == 404
    assert client.get("/v1/admin/blind-test/next", headers=headers).status_code == 204
    blind = client.get("/v1/admin/metrics", headers=headers).json()["factory"]["blind_test"]
    assert blind == {"responses": 1, "handwritten_identified_percent": 100, "generated_preferred_or_same_percent": 100}
    assert client.get("/v1/admin/blind-test/next", headers=learner(client)).status_code == 403
    async with resources.sessionmaker() as db:
        with pytest.raises(Exception, match="insert-only"):
            async with db.begin():
                await db.execute(text("UPDATE blind_responses SET clearer = 'a'"))
