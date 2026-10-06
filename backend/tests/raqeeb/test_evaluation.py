"""Small public synthetic examples exercise the engine; they are never release-quality gold."""
from __future__ import annotations

import copy
import uuid

import pytest
import yaml
from sqlalchemy import func, select

from app.config import BACKEND_DIR
from app.contract import models as C
from app.llm.batches import Request
from app.llm.budget import Ledger, UsageRecord
from app.llm.client import LLMResult
from app.llm.errors import BudgetExceeded, LLMRefusal
from app.llm.fake import FakeLLMClient
from app.models import BenchmarkRun
from app.raqeeb import benchmark, policy
from app.sources.records import canonical_json, sha256_text
from bench import dataset, engine, evaluation


def case(identifier="neutral", category="general_knowledge", language="en", **kwargs):
    return dataset.Case(id=identifier, language=language, question=f"Neutral example {identifier}",
        attachments=None, expected_class=category, should_abstain=category in (
            "personal_fatwa", "sensitive_human", "out_of_scope"),
        expected_referral_type={"personal_fatwa": "fatwa_authority", "sensitive_human": "human_support",
                               "differing_opinions": "specialist"}.get(category),
        gold_points=["Neutral synthetic behavior only"], gold_refs=[], **kwargs)


def write_sets(root, *, overlap=False):
    root.mkdir(parents=True, exist_ok=True)
    values = {"questions": [case(f"neutral_{i}_{lang}", category, lang)
        for i, category in enumerate(C.QuestionClass.__args__) for lang in ("ar", "en")],
        "adversarial": [case("neutral_adversarial", must_not_reuse=True)],
        "warm": [case("neutral_warm")]}
    if overlap:
        values["warm"] = [values["questions"][0].model_copy(update={"id": "different_id"})]
    for name, cases in values.items():
        (root / f"{name}.jsonl").write_text("\n".join(c.model_dump_json() for c in cases), encoding="utf-8")
    return values


class Driver:
    def __init__(self, cases):
        self.cases = {c.question: c for group in cases.values() for c in group}
        self.calls, self.warms, self.problem = [], [], None

    def output(self, value):
        blocks = policy.abstention(value.expected_class, value.language) if value.should_abstain else []
        if value.expected_referral_type and not value.should_abstain:
            blocks.append(policy.referral(value.expected_referral_type, value.language))
        return {"question_class": value.expected_class, "abstained": value.should_abstain,
                "blocks": blocks, "citations": []}

    async def answer(self, value, namespace, *, remaining_tokens=None):
        self.calls.append((value.id, namespace))
        return {"answer": self.output(value), "error": None, "reused": False,
                "latency_ms": 100, "cost_usd": None}

    async def baseline_request(self, value, key):
        return Request(key, "raqeeb_baseline", {"question": value.question})

    async def audit(self, answer, value, *, system="raqeeb"):
        return ([self.problem] if self.problem else []), []

    async def warm(self, values, namespace, *, already_answered=False):
        self.warms.append(namespace)
        return {"count": len(values), "usage": []}


class Batches:
    def __init__(self, driver):
        self.failure = None
        self.client = FakeLLMClient({"raqeeb_baseline": lambda d: driver.output(driver.cases[d["question"]]),
            "raqeeb_judge": {"verdict": "correct", "missing_points": []},
            "raqeeb_grounding": lambda d: {"sentences": [{"text": s["text"], "factual": False,
                "supported": False, "citation_refs": s["citation_refs"]} for s in d["sentences"]]}})

    async def run(self, requests, ledger, checkpoints, save, *, retry=True):
        if self.failure:
            raise self.failure
        results = {r.key: await self.client.structured(r.prompt, r.data, ledger=ledger, call_key=r.key)
                   for r in requests}
        assert all(isinstance(r, LLMResult) for r in results.values())
        await save()
        return results


def identities():
    return {"policy": "synthetic/1", "prompts": {"judge": "synthetic/1"}, "adapters": {"neutral": "1"},
            "models": {"raqeeb_strong": "fake-model", "baseline_llm": "fake-model"}}


async def test_all_classes_bilingual_cold_warm_resume_exact_report_and_changed_versions(tmp_path):
    values = write_sets(tmp_path)
    driver = Driver(values)
    batches = Batches(driver)
    state = engine.State(tmp_path, uuid.uuid4(), synthetic=True)
    report = await engine.run(tmp_path, state, driver, batches, Ledger(200_000), identities())
    rows = [evaluation.Score.model_validate(v) for v in report["scores"].values()]
    assert len(rows) == 68 and len(driver.calls) == 35 and len(driver.warms) == 1
    assert len(report["summaries"]["cold:raqeeb"]["by_class"]) == 8
    assert set(report["summaries"]["cold:raqeeb"]["by_language"]) == {"ar", "en"}
    assert {ns for _, ns in driver.calls} == {
        uuid.uuid5(uuid.UUID(report["run_id"]), "cold"), uuid.uuid5(uuid.UUID(report["run_id"]), "warm")}
    before = len(batches.client.calls)
    reloaded = engine.State(tmp_path, uuid.UUID(report["run_id"]), synthetic=True)
    assert await engine.run(tmp_path, reloaded, driver, batches, Ledger(200_000), identities()) == report
    assert len(batches.client.calls) == before and len(driver.calls) == 35
    with pytest.raises(ValueError, match="versions changed"):
        await engine.run(tmp_path, reloaded, driver, batches, Ledger(200_000), identities() | {"policy": "changed"})
    with pytest.raises(ValueError, match="cannot be overwritten"):
        state.immutable("judged.json", report | {"synthetic": False})


async def test_judge_outage_never_creates_completed_or_perfect_evaluation(tmp_path):
    driver = Driver(write_sets(tmp_path))
    batches = Batches(driver)
    batches.failure = LLMRefusal("Synthetic refusal")
    state = engine.State(tmp_path, uuid.uuid4(), synthetic=True)
    with pytest.raises(LLMRefusal):
        await engine.run(tmp_path, state, driver, batches, Ledger(200_000), identities())
    assert not (state.root / "judged.json").exists()


async def test_warming_budget_checkpoints_every_paid_call_before_next_case(tmp_path):
    values = write_sets(tmp_path)
    driver = Driver(values)
    usage = UsageRecord("fake-model", "synthetic", 1, "a" * 64, None, "disabled", 1,
                        1_000_000, 0, 0, 0, "end_turn", 1)
    original = driver.answer
    async def paid_answer(value, namespace, *, remaining_tokens=None):
        result = await original(value, namespace, remaining_tokens=remaining_tokens)
        if value.id == "neutral_warm":
            result["usage"] = [usage.__dict__, usage.__dict__]
        return result
    driver.answer = paid_answer
    state = engine.State(tmp_path, uuid.uuid4(), synthetic=True)
    with pytest.raises(BudgetExceeded):
        await engine.run(tmp_path, state, driver, Batches(driver), Ledger(200_000), identities())
    durable = engine.State(tmp_path, uuid.UUID(state.value["run_id"]), synthetic=True)
    assert durable.value["evaluation_cost"]["tokens"]["total"] >= 2_000_000
    assert "warming:raqeeb:neutral_warm" in durable.value["answers"]
    assert not (state.root / "judged.json").exists()


def test_policy_limits_are_closed_finite_and_human_signoff_binds_exact_policy():
    from pydantic import ValidationError

    for changes in ({"accuracy_min_percent": float("nan")}, {"unsupported_max_percent": 101},
                    {"mean_cost_max_usd": -1}, {"unknown_escape": True}):
        invalid = release_policy()
        invalid["thresholds"].update(changes)
        with pytest.raises(ValidationError):
            evaluation.release([score()], invalid, synthetic=True, manual=None, signoff=None, report_sha256="a" * 64)
    approved = release_policy()
    approval = {"status": "approved", "approved_by": "Synthetic reviewer",
                "approved_on": "2026-10-06", "report": "Synthetic test only"}
    approved.update(approval)
    approved["external_gates"] = {key: approval for key in approved["external_gates"]}
    signoff = approval | {"report_sha256": "a" * 64, "policy_sha256": sha256_text(canonical_json(approved))}
    result = evaluation.release([score()], approved, synthetic=False,
        manual={"count": 20, "agreement_percent": 100}, signoff=signoff, report_sha256="a" * 64)
    assert result["human_signoff"] and not result["release_approved"]  # incomplete private coverage
    approved["thresholds"]["accuracy_min_percent"] = 89
    assert not evaluation.release([score()], approved, synthetic=False, manual=None, signoff=signoff,
                                  report_sha256="a" * 64)["human_signoff"]


def test_judge_semantic_input_excludes_private_attachment_identifiers():
    from bench.audit import understood

    result = understood({"understood_input": {"transcript": "Neutral spoken question", "images": [
        {"attachment_id": "att_private", "extracted_text": "Neutral caption", "description": "A shape"}],
        "document": {"attachment_id": "att_private", "summary": "Neutral summary"}}})
    assert "att_private" not in str(result) and result["transcript"] == "Neutral spoken question"


def test_identity_does_not_claim_unverified_model_effort(settings):
    from types import SimpleNamespace

    from bench.run import identities as configured_identities
    unknown = settings.model_copy(update={"llm_model_strong": "claude-sonnet-5-5"})
    value = configured_identities(SimpleNamespace(settings=unknown))
    assert value["models"]["judge_effort"] == value["models"]["writer_effort"] == "not_sent"
    declared = configured_identities(SimpleNamespace(settings=settings))
    assert declared["models"]["judge_effort"] == "medium" and declared["models"]["writer_effort"] == "high"


def test_private_absence_path_traversal_and_warm_overlap(tmp_path):
    with pytest.raises(ValueError, match="private"):
        dataset.load(tmp_path)
    write_sets(tmp_path, overlap=True)
    with pytest.raises(ValueError, match="disjoint"):
        dataset.load(tmp_path, synthetic=True)
    with pytest.raises(ValueError, match="inside"):
        dataset.attachment(tmp_path, "../unknown")
    private = tmp_path / ".private" / "eval"
    private.mkdir(parents=True)
    with pytest.raises(ValueError, match="existing"):
        dataset.load(private)


def score(**updates):
    answer = {"blocks": [], "abstained": False, "citations": []}
    return evaluation.Score(case=case(), system="raqeeb", mode="cold", adversarial=False,
        answer=answer, answer_sha256=sha256_text(canonical_json(answer)),
        judge=evaluation.Judge(verdict="correct", missing_points=[]), factual_sentences=50,
        unsupported_sentences=1, source_issues=[], error=None, reused=False, latency_ms=100,
        cost_usd=None).model_copy(update=updates)


def release_policy():
    return yaml.safe_load((BACKEND_DIR / "content" / "raqeeb_release_policy.yaml").read_text(encoding="utf-8"))


def test_threshold_boundaries_unrounded_measures_and_mandatory_protective_referral():
    rows = []
    for mode in ("cold", "warm"):
        for i in range(10):
            rows.append(score(mode=mode, judge=evaluation.Judge(
                verdict="incorrect" if i == 0 else "correct", missing_points=[])))
        for category in ("personal_fatwa", "sensitive_human"):
            value = case(category, category)
            rows.append(score(mode=mode, case=value, factual_sentences=0, unsupported_sentences=0,
                answer={"blocks": policy.abstention(category, "en"), "abstained": True}))
    proposed = evaluation.release(rows, release_policy(), synthetic=False,
        manual={"count": 20, "agreement_percent": 80}, signoff=None, report_sha256="a" * 64)
    assert proposed["proposed_thresholds_pass"] is True and proposed["release_approved"] is False
    wrong = copy.deepcopy(rows)
    wrong[-1].answer["blocks"] = []
    assert not evaluation.release(wrong, release_policy(), synthetic=False,
        manual={"count": 20, "agreement_percent": 80}, signoff=None,
        report_sha256="a" * 64)["checks"]["warm:protective_referrals"]
    assert evaluation.aggregate([score(unsupported_sentences=1, factual_sentences=49)])[
        "unsupported_claim_rate_percent"] > 2


def test_adversarial_protective_case_cannot_escape_mandatory_referral():
    value = case("adversarial_fatwa", "personal_fatwa")
    rows = [score(case=value, answer={"blocks": policy.abstention("personal_fatwa", "en"), "abstained": True}),
            score(case=value, adversarial=True)]
    result = evaluation.release(rows, release_policy(), synthetic=True, manual=None,
                                signoff=None, report_sha256="a" * 64)
    assert not result["checks"]["cold:protective_referrals"]


def test_durable_state_refuses_changed_run_identity_or_synthetic_status(tmp_path):
    tmp_path = tmp_path / ".private"
    run_id = uuid.uuid4()
    state = engine.State(tmp_path, run_id, synthetic=True)
    state.path.write_text(canonical_json(state.value), encoding="utf-8")
    with pytest.raises(ValueError, match="identity/synthetic"):
        engine.State(tmp_path, run_id, synthetic=False)
    state.value["run_id"] = str(uuid.uuid4())
    state.path.write_text(canonical_json(state.value), encoding="utf-8")
    with pytest.raises(ValueError, match="identity/synthetic"):
        engine.State(tmp_path, run_id, synthetic=True)


@pytest.mark.parametrize("issue", ["wrong_scripture", "wrong_hadith_grade", "wrong_hadith_attribution",
    "hallucinated_source", "unverified_evidence", "wrong_source_binding", "source_unavailable", "source_not_found"])
def test_judge_correct_cannot_override_critical_tool_findings(issue):
    result = evaluation.release([score(source_issues=[issue]), score(mode="warm")], release_policy(),
        synthetic=False, manual={"count": 20, "agreement_percent": 100}, signoff=None, report_sha256="a" * 64)
    assert not result["checks"]["cold:scripture_and_grades"] and not result["release_approved"]


def test_manual_labels_bind_exact_answers_no_duplicate_and_all_partials_required():
    row = score(judge=evaluation.Judge(verdict="partial", missing_points=["Neutral missing point"]))
    label = {"case_id": row.case.id, "system": row.system, "mode": row.mode,
             "answer_sha256": row.answer_sha256, "verdict": "partial", "reviewer": "Synthetic reviewer",
             "reviewed_at": "2026-10-06T00:00:00Z"}
    assert evaluation.manual_review([row], [label], synthetic=True)["agreement_percent"] == 100
    for labels in ([], [label, label], [label | {"answer_sha256": "b" * 64}]):
        with pytest.raises(ValueError):
            evaluation.manual_review([row], labels, synthetic=True)


@pytest.mark.integration
async def test_finalized_synthetic_rows_append_once_and_do_not_appear_in_staff_metrics(tmp_path, resources):
    driver = Driver(write_sets(tmp_path))
    state = engine.State(tmp_path, uuid.uuid4(), synthetic=True)
    report = await engine.run(tmp_path, state, driver, Batches(driver), Ledger(200_000), identities())
    key, row = next(iter(report["scores"].items()))
    mode, system, cid = key.split(":")
    labels = [{"case_id": cid, "system": system, "mode": mode, "answer_sha256": row["answer_sha256"],
               "verdict": "correct", "reviewer": "Synthetic reviewer", "reviewed_at": "2026-10-06T00:00:00Z"}]
    source = copy.copy(resources)
    def source_must_remain_private():
        raise AssertionError("aggregate transfer must not touch the source conversation database")
    source.sessionmaker = source_must_remain_private
    first = await engine.finalize(source, state, report, labels, release_policy(), metrics_resources=resources)
    assert not first["release_approved"]
    assert await engine.finalize(resources, state, report, labels, release_policy()) == first
    async with resources.sessionmaker() as db:
        assert await db.scalar(select(func.count()).select_from(BenchmarkRun)) == 2
        assert await benchmark.latest(db) is None
        for stored in (await db.execute(select(BenchmarkRun))).scalars():
            assert "Neutral example" not in canonical_json(stored.provenance)
            assert "manual_labels" not in canonical_json(stored.provenance)
