"""The whole Lesson Factory pipeline (Phase 12) over the real database, a scripted fake model and synthetic
sources: decompose → retrieve → verify → write → exercises → glossary → localize → qa → Gate 2, with the code
checks, blockers, retries, provenance and replay behaviour of every stage."""

from __future__ import annotations

import copy
from collections.abc import Iterator
from pathlib import Path
from typing import Any

import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.content.package import LessonPackage
from app.contract import models as C
from app.factory import gates, pipeline
from app.factory.orchestrator import Orchestrator, gate_digest
from app.factory.runs import start_run, to_contract
from app.factory.stages import EXECUTORS
from app.llm.fake import FakeLLMClient
from app.models import FactoryRun, User
from app.runtime import Resources
from tests.factory import pipeline_support as P
from tests.factory.support import SLOT, InlineDispatcher, drive, reviewer

pytestmark = pytest.mark.integration
STAGES = ["plan", "decompose", "retrieve", "verify_evidence", "write", "exercises", "glossary", "localize", "qa"]


@pytest.fixture
def curriculum(fresh_curriculum: tuple[TestClient, Settings]) -> Iterator[Settings]:
    yield fresh_curriculum[1]


@pytest.fixture
async def resources(curriculum: Settings) -> Any:
    created = Resources.create(curriculum)
    yield created
    await created.close()


class Harness:
    def __init__(self, resources: Resources, llm: FakeLLMClient, tools: P.SyntheticTools) -> None:
        self.resources, self.llm, self.tools = resources, llm, tools
        self.dispatcher = InlineDispatcher()
        self.orchestrator = Orchestrator(resources.sessionmaker, resources.settings, llm, self.dispatcher, EXECUTORS,
                                         services={"sources": lambda: tools})

    async def start(self) -> str:
        who = await reviewer(self.resources)
        async with self.resources.sessionmaker() as db:
            user = await db.get(User, who)
        return await start_run(self.resources.sessionmaker, self.resources.settings, self.dispatcher, reviewer=user,
                               lesson_id=SLOT, lesson_type="concept", brief="Plan the lesson for this slot.")

    async def approve_plan(self, run_id: str) -> None:
        assert await drive(self.orchestrator, self.dispatcher) == ["gate"]
        run = await self.load(run_id)
        await gates.decide_gate1(self.resources.sessionmaker, self.dispatcher, run_id=run_id,
                                 reviewer_id="usr_factory_reviewer",
                                 body=C.Gate1(decision="approve", plan=None, reason=None,
                                              review_digest=run.review_digest))

    async def to_gate2(self) -> tuple[str, list[str]]:
        run_id = await self.start()
        await self.approve_plan(run_id)
        return run_id, await drive(self.orchestrator, self.dispatcher)

    async def load(self, run_id: str) -> FactoryRun:
        async with self.resources.sessionmaker() as db:
            run = await db.get(FactoryRun, run_id)
            assert run is not None
            return run


def harness(resources: Resources, tmp_path: Path, *, tools: P.SyntheticTools | None = None,
            **answers: Any) -> Harness:
    return Harness(resources, FakeLLMClient(P.script(**answers)),
                   tools or P.SyntheticTools(translations=P.manifest(tmp_path)))


async def test_a_lesson_reaches_gate2_with_provenance_for_every_stage(resources: Resources, tmp_path: Path) -> None:
    h = harness(resources, tmp_path)
    run_id, outcomes = await h.to_gate2()
    run = await h.load(run_id)
    assert run.error is None, run.error
    assert outcomes == ["done"] * 7 + ["gate"]
    assert run.status == "awaiting_gate2" and run.stage == "qa"
    statuses = {s["stage"]: s["status"] for s in run.stages}
    assert all(statuses[s] == "done" for s in STAGES)
    assert all(statuses[s] == "skipped" for s in pipeline.MEDIA_STAGES)
    # Provenance: which prompt (version + digest) and model produced each accepted artifact, from which inputs.
    for stage in STAGES:
        artifact = run.artifacts[stage]
        assert artifact["attempt"] == 1 and len(artifact["output_digest"]) == 64
        assert len(artifact["inputs_digest"]) == 64
    assert run.artifacts["qa"]["prompts"][0]["prompt_id"] in ("factory_pedagogy", "factory_qa")
    assert {p["prompt_id"] for p in run.artifacts["qa"]["prompts"]} == {"factory_qa", "factory_pedagogy"}
    assert run.artifacts["write"]["prompts"][0]["prompt_id"] == "factory_write"
    assert [c["prompt_id"] for c in run.cost["calls"]] == [
        "factory_plan", "factory_decompose", "factory_retrieve", "factory_verify", "factory_write",
        "factory_exercises", "factory_glossary", "factory_localize", "factory_qa", "factory_pedagogy"]
    assert run.cost["tokens"]["total"] > 0 and all(c["call_key"].startswith(run_id) for c in run.cost["calls"])
    # Gate 2 binds the reviewed draft and report; the contract projection validates.
    assert run.review_digest == gate_digest("awaiting_gate2", run)
    projected = to_contract(run)
    assert projected["draft"] is not None and projected["qa_report"] == run.qa_report
    package = LessonPackage.model_validate(run.artifacts["qa"]["output"]["package"])
    assert package.digest() == run.artifacts["qa"]["output"]["package_digest"]
    assert sorted(package.variants) == ["ar", "en"]
    # What the reviewer sees: only placeholder media and visual readiness block (D-129); flags are reported.
    blockers = [i for i in run.qa_report["issues"] if i["severity"] == "blocker"]
    assert {i["kind"] for i in blockers} == {"validation"}
    assert sum("placeholder" in i["message"] for i in blockers) == 4
    assert any(i["kind"] == "scholarly_review" and "needs_tafsir" in i["message"] for i in run.qa_report["issues"])
    assert any(i["location"]["sentence_id"] == "s_t1" and i["message"].startswith("[pedagogy]")
               for i in run.qa_report["issues"])
    assert h.tools.closed >= 2      # the source tools are closed after every stage that opened them


async def test_scripture_and_hadith_come_from_verified_records_only(resources: Resources, tmp_path: Path) -> None:
    h = harness(resources, tmp_path)
    run_id, _ = await h.to_gate2()
    run = await h.load(run_id)
    package = LessonPackage.model_validate(run.artifacts["qa"]["output"]["package"])
    canonical = P.synthetic.mushaf().get(1, 1).text_uthmani
    for lang in ("ar", "en"):
        for variant in package.variants[lang].values():
            teach = next(b for b in variant.blocks if b["block_id"] == "b_teach")
            assert teach["evidence"]["quran"]["text_uthmani"] == canonical
            hadith = next(b for b in variant.blocks if b["block_id"] == "b_ev")["evidence"]["hadith"]
            assert hadith["text_ar"] == P.HADITH_TEXT and hadith["grade_category"] == "authentic"
            assert hadith["grade_source"] == "محدث تجريبي" and hadith["collections"] == ["كتاب تجريبي (1)"]
            if lang == "en":
                assert teach["evidence"]["quran"]["translation"] == "Neutral translation sentence 1:1"
                assert hadith["translation"] == P.hadeethenc_record().text
            else:
                assert teach["evidence"]["quran"]["translation"] is None and hadith["translation"] is None
    records = run.artifacts["qa"]["output"]["source_records"]
    assert set(records) == {s.source_id for s in package.sources}
    assert all(r[0]["retrieval"]["response_sha256"] for r in records.values())
    # Claims keep the exact evidence, the verifier's note (with the code text check) and the semantic review.
    claims = {c.claim_id: c for c in package.claims}
    assert claims["c1"].status == "supported" and claims["c1"].evidence[0].semantic_review.fit == "exact"
    assert claims["c1"].evidence[0].verifier_note.startswith("text check: passed.")
    hadeethenc = [e for e in claims["c2"].evidence if e.source.provider == "hadeethenc"]
    assert hadeethenc and not hadeethenc[0].supports      # a HadeethEnc card never grades a hadith


async def test_localization_keeps_every_id_role_link_and_key(resources: Resources, tmp_path: Path) -> None:
    h = harness(resources, tmp_path)
    run_id, _ = await h.to_gate2()
    run = await h.load(run_id)
    package = LessonPackage.model_validate(run.artifacts["qa"]["output"]["package"])
    for variant in package.variants["ar"]:
        ar, en = package.variants["ar"][variant], package.variants["en"][variant]
        assert ar.skeleton() == en.skeleton()
    for record in package.exercises:
        ar, en = record.exercise["ar"], record.exercise["en"]
        assert ar.answer_key == en.answer_key and ar.option_misconceptions == en.option_misconceptions
        assert record.exercise_id.startswith("ex_") and record.exercise_id[3:].split("_")[0] in run_id.lower()
    # The linker marked the plan's new term on first use, in Arabic; the glossary record belongs to this lesson.
    teach = next(b for b in package.variants["ar"]["explorer"].blocks if b["block_id"] == "b_teach")
    spans = teach["points"][1]["sentence"]["spans"]
    assert [s["type"] for s in spans] == ["text", "term", "text"] and spans[1]["text"] == P.TERM_AR
    assert spans[1]["term_id"] == package.glossary[0].term_id and package.glossary[0].lesson_id == SLOT


async def test_served_banks_never_spell_out_the_private_key(resources: Resources, tmp_path: Path) -> None:
    h = harness(resources, tmp_path)
    run_id, _ = await h.to_gate2()
    run = await h.load(run_id)
    package = LessonPackage.model_validate(run.artifacts["qa"]["output"]["package"])
    by_type = {r.type: r.exercise["ar"] for r in package.exercises}
    order = by_type["order_steps"]
    assert [s["step_id"] for s in order.payload["steps"]] != order.answer_key.order
    assert [s["step_id"] for s in order.payload["steps"]] == ["s1", "s2", "s3"]     # ids follow served position
    match = by_type["match_pairs"]
    pairs = {p.left_id: p.right_id for p in match.answer_key.pairs}
    assert [pairs[i["item_id"]] for i in match.payload["left"]] != [i["item_id"] for i in match.payload["right"]]
    fill = by_type["fill_blank"]
    assert [w["word_id"] for w in fill.payload["word_bank"]][:2] != [f.word_id for f in fill.answer_key.fills]
    scenario = by_type["scenario"]
    assert scenario.option_misconceptions == {"o2": package.misconceptions[0].misconception_id}
    tfr = by_type["true_false_reason"]
    assert tfr.framing is not None and tfr.framing.kind == "myth"
    # Learner previews carry the learner projection only: no key, no misconception mapping.
    draft = run.artifacts["qa"]["output"]["draft"]
    for preview in draft["previews"]:
        for block in preview["items"]:
            if block["type"] == "exercise":
                assert "answer_key" not in block["exercise"] and "option_misconceptions" not in block["exercise"]


def sequence(*answers: Any) -> Any:
    """A model that answers each call with the next answer (callables get the stage data)."""
    pending = list(answers)
    seen: list[dict[str, Any]] = []

    def answer(data: dict[str, Any]) -> dict[str, Any]:
        seen.append(copy.deepcopy(dict(data)))
        value = pending.pop(0) if len(pending) > 1 else pending[0]
        result: dict[str, Any] = value(data) if callable(value) else value
        return result

    answer.seen = seen  # type: ignore[attr-defined]
    return answer


async def test_a_quran_passage_without_a_selected_translation_blocks_before_localization(
        resources: Resources, tmp_path: Path) -> None:
    h = harness(resources, tmp_path, tools=P.SyntheticTools(translations=None))
    run_id, outcomes = await h.to_gate2()
    run = await h.load(run_id)
    assert outcomes[-1] == "failed" and run.status == "failed" and run.stage == "localize"
    assert run.error["code"] == "translation_unselected" and "D-93" in run.error["message"]
    assert "factory_localize" not in [c["prompt_id"] for c in run.cost["calls"]]     # no spend on a human blocker


async def test_an_unconfigured_provider_leaving_a_claim_without_evidence_is_a_human_blocker(
        resources: Resources, tmp_path: Path) -> None:
    tools = P.SyntheticTools(translations=P.manifest(tmp_path), not_configured={"dorar", "hadeethenc"})
    h = harness(resources, tmp_path, tools=tools)
    run_id, _ = await h.to_gate2()
    run = await h.load(run_id)
    assert run.status == "failed" and run.stage == "retrieve" and run.error["code"] == "sources_not_configured"
    assert "c2" in run.error["message"] and "O-03" in run.error["message"]


async def test_a_source_outage_retries_the_stage_and_then_succeeds(resources: Resources, tmp_path: Path) -> None:
    tools = P.SyntheticTools(translations=P.manifest(tmp_path), outages=["dorar"])
    h = harness(resources, tmp_path, tools=tools)
    run_id, outcomes = await h.to_gate2()
    run = await h.load(run_id)
    assert "retry" in outcomes and run.status == "awaiting_gate2"
    failed = [a for a in run.attempts if a["event"] == "failed"]
    assert [(a["stage"], a["code"], a["retryable"]) for a in failed] == [("retrieve", "source_unavailable", True)]
    assert run.artifacts["retrieve"]["attempt"] == 2
    # Both retrieve attempts were paid for and recorded; only the accepted one proceeded.
    assert [c["prompt_id"] for c in run.cost["calls"]].count("factory_retrieve") == 2


async def test_a_weak_hadith_can_never_support_a_claim(resources: Resources, tmp_path: Path) -> None:
    tools = P.SyntheticTools(translations=P.manifest(tmp_path), hadith=[P.dorar_record(grade="ضعيف")])
    verifier = sequence(lambda d: P.verify(d, weak_supports=True))
    h = harness(resources, tmp_path, tools=tools, factory_verify=verifier)
    run_id, outcomes = await h.to_gate2()
    run = await h.load(run_id)
    assert outcomes[-3:] == ["retry", "retry", "failed"]
    assert run.error["code"] == "verification_invalid" and "cannot support a claim" in run.error["message"]
    # The validator's issues reach the next attempt as feedback.
    assert any("weak" in issue for issue in verifier.seen[1]["previous_attempt_issues"])


async def test_a_dropped_claim_cannot_be_asserted_and_a_corrected_draft_proceeds(
        resources: Resources, tmp_path: Path) -> None:
    def unsupported(data: dict[str, Any]) -> dict[str, Any]:
        draft = P.write(data)
        for variant in draft["variants"]:
            variant["blocks"][3]["points"][0]["sentence"]["claim_ids"] = ["c9"]
            variant["blocks"] = [b for b in variant["blocks"] if b["block_id"] != "b_x3"]
        draft["arc_map"][3]["block_ids"] = ["b_x2"]
        return draft

    writer = sequence(unsupported, P.write)
    h = harness(resources, tmp_path, factory_write=writer)
    run_id, _ = await h.to_gate2()
    run = await h.load(run_id)
    assert run.status == "awaiting_gate2" and run.artifacts["write"]["attempt"] == 2
    issues = writer.seen[1]["previous_attempt_issues"]
    assert any("c9 is not a supported claim" in i for i in issues)
    assert any("exercise_budget" in i for i in issues)


async def test_a_teaching_scenario_cannot_carry_an_assertion(resources: Resources, tmp_path: Path) -> None:
    def disguised(data: dict[str, Any]) -> dict[str, Any]:
        draft = P.write(data)
        for variant in draft["variants"]:
            variant["blocks"][1]["beats"][0]["narration"][0] = P.sentence("s_sc1", "ادعاء مخفي", "claim", ["c1"])
        return draft

    h = harness(resources, tmp_path, factory_write=sequence(disguised))
    run_id, _ = await h.to_gate2()
    run = await h.load(run_id)
    assert run.status == "failed" and run.error["code"] == "draft_invalid"
    assert "a teaching scenario's narration asserts nothing" in run.error["message"]


async def test_localization_must_cover_exactly_the_given_texts(resources: Resources, tmp_path: Path) -> None:
    def partial(data: dict[str, Any]) -> dict[str, Any]:
        out = P.localize(data)
        out["texts"] = [*out["texts"][1:], {"id": "t9999", "text": "invented"}]
        return out

    localizer = sequence(partial, P.localize)
    h = harness(resources, tmp_path, factory_localize=localizer)
    run_id, _ = await h.to_gate2()
    run = await h.load(run_id)
    assert run.status == "awaiting_gate2" and run.artifacts["localize"]["attempt"] == 2
    assert {"t1 is missing", "t9999 is not an id you were given"} <= set(localizer.seen[1]["previous_attempt_issues"])


async def test_model_qa_findings_follow_the_severity_policy_and_must_be_located(
        resources: Resources, tmp_path: Path) -> None:
    def belief(data: dict[str, Any]) -> dict[str, Any]:
        exercise = data["exercises"][0]["exercise_id"]
        return {"issues": [{"severity": "warning", "kind": "belief_grading", "sentence_id": None,
                            "exercise_id": exercise, "message": "grades agreement"}]}

    lost = {"issues": [{"severity": "info", "kind": "consistency", "sentence_id": "s_nowhere", "exercise_id": None,
                        "message": "x"}]}
    h = harness(resources, tmp_path, factory_qa=sequence(lost, belief))
    run_id, _ = await h.to_gate2()
    run = await h.load(run_id)
    assert run.status == "awaiting_gate2" and run.artifacts["qa"]["attempt"] == 2
    found = [i for i in run.qa_report["issues"] if i["kind"] == "belief_grading"]
    assert found and found[0]["severity"] == "blocker"            # factory 13.5: belief grading always blocks


async def test_no_supported_claim_stops_the_run_for_a_person(resources: Resources, tmp_path: Path) -> None:
    def drop_all(data: dict[str, Any]) -> dict[str, Any]:
        out = P.verify(data)
        for verdict in out["claims"]:
            verdict["status"] = "dropped"
            for judged in verdict["evidence"]:
                judged.update(supports=False, semantic_review=None)
        return out

    h = harness(resources, tmp_path, factory_verify=sequence(drop_all))
    run_id, _ = await h.to_gate2()
    run = await h.load(run_id)
    assert run.status == "failed" and run.error["code"] == "no_supported_claims"


async def test_a_redelivered_stage_resumes_once_and_a_late_duplicate_changes_nothing(
        resources: Resources, tmp_path: Path) -> None:
    h = harness(resources, tmp_path)
    run_id = await h.start()
    await h.approve_plan(run_id)
    assert (await drive(h.orchestrator, h.dispatcher, until="retrieve"))[-1] == "done"
    h.dispatcher.queue.clear()
    # A worker claims verify_evidence and dies before completing (the claim is durable, the work is not).
    assert await h.orchestrator._claim(run_id, "verify_evidence", 1) is not None
    assert await h.orchestrator.run_stage(run_id, "verify_evidence", 1) == "done"        # broker redelivery
    run = await h.load(run_id)
    events = [a["event"] for a in run.attempts if a["stage"] == "verify_evidence"]
    assert events == ["started", "resumed", "done"]
    before = (run.artifacts["verify_evidence"]["output_digest"], len(run.cost["calls"]))
    assert await h.orchestrator.run_stage(run_id, "verify_evidence", 1) == "stale"
    run = await h.load(run_id)
    assert (run.artifacts["verify_evidence"]["output_digest"], len(run.cost["calls"])) == before


async def test_a_run_never_writes_published_content(resources: Resources, tmp_path: Path) -> None:
    from sqlalchemy import func, select

    from app.models import Exercise, Lesson, LessonVersion, Source, Term

    async def counts() -> tuple[int, ...]:
        async with resources.sessionmaker() as db:
            return tuple([(await db.execute(select(func.count()).select_from(model))).scalar_one()
                          for model in (Lesson, LessonVersion, Exercise, Term, Source)])

    before = await counts()
    h = harness(resources, tmp_path)
    run_id, _ = await h.to_gate2()
    assert (await h.load(run_id)).status == "awaiting_gate2"
    assert await counts() == before      # drafts live in the run; only Gate 2 publication writes content (Phase 13)


async def test_a_missing_mushaf_fails_the_run_without_retrying(resources: Resources, tmp_path: Path) -> None:
    from app.sources.mushaf import MushafError

    def missing() -> P.SyntheticTools:
        raise MushafError("mushaf dataset is not installed")

    h = harness(resources, tmp_path)
    h.orchestrator.services = {"sources": missing}
    run_id, outcomes = await h.to_gate2()
    run = await h.load(run_id)
    assert outcomes[-1] == "failed" and run.stage == "retrieve" and run.error["code"] == "mushaf_unavailable"
    assert [a["attempt"] for a in run.attempts if a["event"] == "failed"] == [1]
