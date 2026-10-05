"""Factory orchestration and the Curriculum Architect stage over the real database with a deterministic fake model
(Phase 12.1): provenance, retries with feedback, classified failures, budgets, blockers, crash/resume, duplicate
deliveries, Gate 1 and the database invariants."""

from __future__ import annotations

import asyncio
import copy
from collections.abc import Iterator
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select, text
from sqlalchemy.exc import IntegrityError

from app.config import Settings
from app.contract import models as C
from app.errors import ApiError
from app.factory import gates
from app.factory.runs import create_run, start_run, to_contract
from app.llm.errors import LLMRefusal, LLMUnavailable
from app.llm.fake import FakeLLMClient
from app.llm.prompts import get_prompt
from app.models import FactoryRun, ReviewDecision, User
from app.runtime import Resources
from tests.factory.support import SLOT, InlineDispatcher, drive, orchestrator, plan, reviewer

pytestmark = pytest.mark.integration


@pytest.fixture
def curriculum(fresh_curriculum: tuple[TestClient, Settings]) -> Iterator[Settings]:
    yield fresh_curriculum[1]


@pytest.fixture
async def resources(curriculum: Settings) -> Any:
    created = Resources.create(curriculum)
    yield created
    await created.close()


class Scripted:
    """Answers per call from a list (dicts or exceptions), recording every data payload it was given."""

    def __init__(self, *answers: Any) -> None:
        self.answers, self.data = list(answers), []

    def __call__(self, data: Any) -> dict[str, Any]:
        self.data.append(copy.deepcopy(dict(data)))
        answer = self.answers.pop(0) if len(self.answers) > 1 else self.answers[0]
        if isinstance(answer, BaseException):
            raise answer
        return dict(answer)


async def start(resources: Resources, dispatcher: InlineDispatcher, **options: Any) -> str:
    who = await reviewer(resources)
    async with resources.sessionmaker() as db:
        user = await db.get(User, who)
    return await start_run(resources.sessionmaker, resources.settings, dispatcher, reviewer=user, lesson_id=SLOT,
                           lesson_type="concept", brief="Plan the lesson for this slot.", **options)


async def load(resources: Resources, run_id: str) -> FactoryRun:
    async with resources.sessionmaker() as db:
        run = await db.get(FactoryRun, run_id)
        assert run is not None
        return run


async def test_the_plan_reaches_gate1_with_durable_provenance(resources: Resources) -> None:
    script = Scripted(plan())
    dispatcher = InlineDispatcher()
    run_id = await start(resources, dispatcher)
    assert await drive(orchestrator(resources, FakeLLMClient({"factory_plan": script}), dispatcher), dispatcher) \
        == ["gate"]
    run = await load(resources, run_id)
    assert run.status == "awaiting_gate1" and run.plan == C.LessonPlan.model_validate(plan()).model_dump(mode="json")
    assert run.review_digest and len(run.review_digest) == 64 and dispatcher.queue == []
    artifact = run.artifacts["plan"]
    prompt = get_prompt("factory_plan")
    assert artifact["prompts"] == [{"prompt_id": "factory_plan", "prompt_version": prompt.version,
                                    "prompt_sha256": prompt.sha256}]
    assert artifact["models"] == ["fake-model"] and artifact["attempt"] == 1
    assert len(artifact["inputs_digest"]) == 64 and artifact["inputs"]["may_introduce"] == ["con_t2_1"]
    assert "con_t2_0" in artifact["inputs"]["may_require"] and "con_t1_0" not in artifact["inputs"]["may_require"]
    assert artifact["inputs"]["brief"] == "Plan the lesson for this slot."
    assert len(run.cost["calls"]) == 1 and run.cost["calls"][0]["call_key"] == f"{run_id}:plan:1"
    assert run.cost["tokens"]["total"] > 0 and run.cost["usd"] is None
    assert [s["status"] for s in run.stages if s["stage"] == "plan"] == ["done"]
    assert {s["stage"] for s in run.stages if s["status"] == "skipped"} == set()
    assert all(s["status"] == "pending" for s in run.stages if s["stage"] in {
        "visuals", "scene_author", "scene_render", "narration"})
    projected = to_contract(run)
    assert projected["status"] == "awaiting_gate1" and projected["review_digest"] == run.review_digest


async def test_an_invalid_plan_is_retried_with_its_issues_then_the_run_fails(resources: Resources) -> None:
    bad = plan(introduced_concept_ids=["con_t3_0"], depth_profile="standard")
    script = Scripted(bad)
    dispatcher = InlineDispatcher()
    run_id = await start(resources, dispatcher)
    outcomes = await drive(orchestrator(resources, FakeLLMClient({"factory_plan": script}), dispatcher), dispatcher)
    assert outcomes == ["retry", "retry", "failed"] and dispatcher.countdowns[1:] == [30, 120]
    run = await load(resources, run_id)
    assert run.status == "failed" and run.error is not None and run.error["code"] == "plan_invalid"
    failed = [a for a in run.attempts if a["event"] == "failed"]
    assert [a["attempt"] for a in failed] == [1, 2, 3] and all(a["retryable"] for a in failed)
    assert any("con_t3_0" in issue for issue in failed[0]["issues"])
    assert any("foundational" in issue for issue in failed[0]["issues"])
    assert script.data[0]["previous_attempt_issues"] == [] and script.data[1]["previous_attempt_issues"]
    assert len(run.cost["calls"]) == 3                      # rejected output was still paid for and is recorded
    assert run.plan is None and "plan" not in run.artifacts


async def test_a_corrected_plan_is_accepted_on_retry(resources: Resources) -> None:
    script = Scripted(plan(prerequisite_concept_ids=["con_t1_0"]), plan())
    dispatcher = InlineDispatcher()
    run_id = await start(resources, dispatcher)
    assert await drive(orchestrator(resources, FakeLLMClient({"factory_plan": script}), dispatcher), dispatcher) \
        == ["retry", "gate"]
    run = await load(resources, run_id)
    assert run.status == "awaiting_gate1" and run.artifacts["plan"]["attempt"] == 2
    assert "every track" in script.data[1]["previous_attempt_issues"][0]


@pytest.mark.parametrize(("answers", "outcomes", "status", "code"), [
    ((LLMRefusal("refused"),), ["failed"], "failed", "refusal"),
    ((LLMUnavailable("down"), LLMUnavailable("down"), plan()), ["retry", "retry", "gate"], "awaiting_gate1", None),
    ((LLMUnavailable("down"),), ["retry", "retry", "failed"], "failed", "model_unavailable"),
])
async def test_failures_are_classified(resources: Resources, answers: tuple[Any, ...], outcomes: list[str],
                                       status: str, code: str | None) -> None:
    dispatcher = InlineDispatcher()
    run_id = await start(resources, dispatcher)
    llm = FakeLLMClient({"factory_plan": Scripted(*answers)})
    assert await drive(orchestrator(resources, llm, dispatcher), dispatcher) == outcomes
    run = await load(resources, run_id)
    assert run.status == status and (run.error or {}).get("code") == code


async def test_the_budget_stops_the_run(resources: Resources) -> None:
    dispatcher = InlineDispatcher()
    run_id = await start(resources, dispatcher, budget_tokens=10)
    llm = FakeLLMClient({"factory_plan": Scripted(plan())})
    assert await drive(orchestrator(resources, llm, dispatcher), dispatcher) == ["failed"]
    run = await load(resources, run_id)
    assert run.error == {"code": "budget_exceeded", "message": run.error["message"]}  # type: ignore[index]
    assert len(run.cost["calls"]) == 1 and run.cost["tokens"]["total"] > 10


async def test_a_unit_without_registered_concepts_is_a_curriculum_blocker(resources: Resources) -> None:
    async with resources.sessionmaker() as db, db.begin():
        await db.execute(text("INSERT INTO units (id, index, title, subtitle, tracks) VALUES ('unit_test_9', 9, "
                              "'{}'::jsonb, '{}'::jsonb, ARRAY['explorer'])"))
        await db.execute(text("INSERT INTO curriculum_slots (lesson_id, unit_id, index, working_title) VALUES "
                              "('les_t9_0', 'unit_test_9', 0, '{\"en\": \"x\"}'::jsonb)"))
    who = await reviewer(resources)
    dispatcher = InlineDispatcher()
    async with resources.sessionmaker() as db:
        user = await db.get(User, who)
    run_id = await start_run(resources.sessionmaker, resources.settings, dispatcher, reviewer=user,
                             lesson_id="les_t9_0", lesson_type="concept", brief="Plan it.")
    llm = FakeLLMClient({"factory_plan": Scripted(plan())})
    assert await drive(orchestrator(resources, llm, dispatcher), dispatcher) == ["failed"]
    run = await load(resources, run_id)
    assert run.error is not None and run.error["code"] == "concepts_unregistered" and "O-12" in run.error["message"]
    assert llm.calls == [] and run.cost["calls"] == []       # refused before any model call


async def test_a_crashed_stage_is_resumed_and_duplicates_change_nothing(resources: Resources) -> None:
    dispatcher = InlineDispatcher()
    run_id = await start(resources, dispatcher)
    llm = FakeLLMClient({"factory_plan": Scripted(plan())})
    orch = orchestrator(resources, llm, dispatcher)
    assert await orch._claim(run_id, "plan", 1) is not None    # a worker claimed the stage, then died
    assert await orch.run_stage(run_id, "plan", 1) == "gate"   # the broker redelivers the same message
    run = await load(resources, run_id)
    assert [a["event"] for a in run.attempts] == ["started", "resumed", "done"]
    digest = run.review_digest
    assert await orch.run_stage(run_id, "plan", 1) == "stale"   # a late duplicate
    assert await orch.run_stage(run_id, "decompose", 1) == "stale"
    run = await load(resources, run_id)
    assert run.review_digest == digest and len(run.cost["calls"]) == 1


async def test_concurrent_duplicate_deliveries_write_one_artifact(resources: Resources) -> None:
    dispatcher = InlineDispatcher()
    run_id = await start(resources, dispatcher)
    llm = FakeLLMClient({"factory_plan": Scripted(plan())})
    first, second = orchestrator(resources, llm, dispatcher), orchestrator(resources, llm, dispatcher)
    outcomes = sorted(await asyncio.gather(first.run_stage(run_id, "plan", 1), second.run_stage(run_id, "plan", 1)))
    assert outcomes in (["gate", "stale"],)
    run = await load(resources, run_id)
    assert run.status == "awaiting_gate1" and sum(a["event"] == "done" for a in run.attempts) == 1


async def test_one_active_run_per_slot(resources: Resources) -> None:
    dispatcher = InlineDispatcher()
    await start(resources, dispatcher)
    async with resources.sessionmaker() as db, db.begin():
        user = await db.get(User, "usr_factory_reviewer")
        assert user is not None
        with pytest.raises(ApiError, match="active factory run"):
            await create_run(db, resources.settings, reviewer=user, lesson_id=SLOT, lesson_type="concept",
                             brief="again")
        learner = User(id="usr_not_reviewer", display_name="L", avatar_key="traveler_01", timezone="UTC")
        db.add(learner)
        await db.flush()
        with pytest.raises(ApiError, match="reviewer"):
            await create_run(db, resources.settings, reviewer=learner, lesson_id="les_t2_2", lesson_type="concept",
                             brief="b")


async def at_gate1(resources: Resources, dispatcher: InlineDispatcher) -> tuple[str, str]:
    run_id = await start(resources, dispatcher)
    await drive(orchestrator(resources, FakeLLMClient({"factory_plan": Scripted(plan())}), dispatcher), dispatcher)
    run = await load(resources, run_id)
    assert run.review_digest is not None
    return run_id, run.review_digest


async def test_gate1_approve_records_the_decision_and_resumes(resources: Resources) -> None:
    dispatcher = InlineDispatcher()
    run_id, digest = await at_gate1(resources, dispatcher)
    edited = plan(estimated_minutes=9)
    result = await gates.decide_gate1(resources.sessionmaker, dispatcher, run_id=run_id,
                                      reviewer_id="usr_factory_reviewer",
                                      body=C.Gate1(decision="approve", plan=C.LessonPlan.model_validate(edited),
                                                   reason=None, review_digest=digest))
    assert result == {"run_id": run_id, "status": "running", "stage": "decompose"}
    assert dispatcher.queue == [(run_id, "decompose", 1)]
    run = await load(resources, run_id)
    assert run.plan is not None and run.plan["estimated_minutes"] == 9 and run.review_digest is None
    assert run.gate1_decision is not None and run.gate1_decision["edited"] is True
    async with resources.sessionmaker() as db:
        (decision,) = (await db.execute(select(ReviewDecision).where(ReviewDecision.run_id == run_id))).scalars()
    assert decision.gate == 1 and decision.reviewed_digest == digest and decision.edits["plan"] == run.plan
    with pytest.raises(ApiError) as again:
        await gates.decide_gate1(resources.sessionmaker, dispatcher, run_id=run_id, reviewer_id="usr_factory_reviewer",
                                 body=C.Gate1(decision="approve", plan=None, reason=None, review_digest=digest))
    assert again.value.code.value == "run_not_at_gate"


async def test_gate1_refuses_stale_digests_invalid_edits_and_inactive_reviewers(resources: Resources) -> None:
    dispatcher = InlineDispatcher()
    run_id, digest = await at_gate1(resources, dispatcher)
    await reviewer(resources, user_id="usr_former_reviewer", active=False)

    async def decide(body: C.Gate1, who: str = "usr_factory_reviewer") -> str:
        with pytest.raises(ApiError) as error:
            await gates.decide_gate1(resources.sessionmaker, dispatcher, run_id=run_id, reviewer_id=who, body=body)
        return str(error.value.code.value)

    assert await decide(C.Gate1(decision="approve", plan=None, reason=None, review_digest="0" * 64)) == "review_stale"
    invalid = C.LessonPlan.model_validate(plan(prerequisite_concept_ids=["con_t3_1"]))
    assert await decide(C.Gate1(decision="approve", plan=invalid, reason=None, review_digest=digest)) \
        == "validation_error"
    assert await decide(C.Gate1(decision="reject", plan=None, reason="x", review_digest=digest),
                        who="usr_former_reviewer") == "forbidden"
    rejected = await gates.decide_gate1(resources.sessionmaker, dispatcher, run_id=run_id,
                                        reviewer_id="usr_factory_reviewer",
                                        body=C.Gate1(decision="reject", plan=None, reason="Too broad.",
                                                     review_digest=digest))
    assert rejected["status"] == "rejected" and dispatcher.queue == []


async def test_database_enforces_the_run_invariants(resources: Resources) -> None:
    dispatcher = InlineDispatcher()
    run_id, _ = await at_gate1(resources, dispatcher)
    for statement in ("UPDATE factory_runs SET review_digest = NULL WHERE id = :id",
                      "UPDATE factory_runs SET status = 'failed' WHERE id = :id",
                      "UPDATE factory_runs SET status = 'published' WHERE id = :id",
                      "UPDATE factory_runs SET plan = NULL WHERE id = :id"):
        with pytest.raises(IntegrityError):
            async with resources.sessionmaker() as db, db.begin():
                await db.execute(text(statement), {"id": run_id})
