"""Resumable cold/warm comparisons, private reports and existing append-only metrics persistence."""
from __future__ import annotations

import base64
import json
import os
import uuid
from collections.abc import Awaitable, Callable
from dataclasses import replace
from datetime import UTC, datetime
from pathlib import Path
from typing import Any, Literal, Protocol

from app.errors import ApiError
from app.llm.batches import Request
from app.llm.budget import Ledger, UsageRecord
from app.llm.client import LLMResult
from app.llm.errors import BudgetExceeded, LLMError
from app.llm.vision import VisionImage
from app.raqeeb import benchmark
from app.raqeeb.inputs import InputUnreadable
from app.runtime import Resources
from app.sources.records import canonical_json, sha256_text
from bench import audit, evaluation
from bench.dataset import Case, load


class Driver(Protocol):
    async def answer(self, case: Case, namespace: uuid.UUID, *,
                     remaining_tokens: int | None = None) -> dict[str, Any]: ...
    async def baseline_request(self, case: Case, key: str) -> Request: ...
    async def audit(self, answer: dict[str, Any], case: Case, *,
                    system: str = "raqeeb") -> tuple[list[str], list[dict[str, Any]]]: ...
    async def warm(self, cases: list[Case], namespace: uuid.UUID, *,
                   already_answered: bool = False) -> dict[str, Any]: ...


class Batch(Protocol):
    async def run(self, requests: list[Request], ledger: Ledger, checkpoints: dict[str, Any],
                  save: Callable[[], Awaitable[None]], *, retry: bool = True
                  ) -> dict[str, LLMResult | LLMError]: ...


class State:
    def __init__(self, root: Path, run_id: uuid.UUID, *, synthetic: bool) -> None:
        if not synthetic and ".private" not in root.resolve().parts:
            raise ValueError("real benchmark reports must be private")
        self.root = root.resolve() / "runs" / str(run_id)
        self.root.mkdir(parents=True, exist_ok=True)
        self.path = self.root / "state.json"
        self.value: dict[str, Any] = json.loads(self.path.read_text(encoding="utf-8")) if self.path.exists() else {
            "schema": "qabas.raqeeb_evaluation/1", "run_id": str(run_id), "synthetic": synthetic,
            "run_at": datetime.now(UTC).isoformat(), "answers": {}, "scores": {}, "batches": {}}
        if self.value["run_id"] != str(run_id) or self.value["synthetic"] is not synthetic:
            raise ValueError("stored run identity/synthetic status differs from the requested evaluation")

    async def save(self) -> None:
        temporary = self.root / f".{uuid.uuid4().hex}.tmp"
        with temporary.open("w", encoding="utf-8", newline="\n") as stream:
            stream.write(canonical_json(self.value))
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, self.path)

    def immutable(self, name: str, value: dict[str, Any]) -> str:
        data = canonical_json(value)
        path = self.root / name
        if path.exists():
            if path.read_text(encoding="utf-8") != data:
                raise ValueError("a reviewed benchmark artifact cannot be overwritten")
        else:
            temporary = self.root / f".{uuid.uuid4().hex}.tmp"
            with temporary.open("w", encoding="utf-8", newline="\n") as stream:
                stream.write(data)
                stream.flush()
                os.fsync(stream.fileno())
            try:
                os.link(temporary, path)  # atomic create-if-absent; no partially written review artifact
            finally:
                temporary.unlink()
        return sha256_text(data)


async def run(root: Path, state: State, driver: Driver, batches: Batch, ledger: Ledger,
              versions: dict[str, Any]) -> dict[str, Any]:
    synthetic = bool(state.value["synthetic"])
    sets, digests = load(root, synthetic=synthetic)
    binding = {"digests": digests, "versions": versions, "synthetic": synthetic}
    if state.value.get("binding", binding) != binding:
        raise ValueError("resume inputs/model/prompt/policy versions changed; create a new run")
    state.value["binding"] = binding
    ledger.records = [UsageRecord(**{k: v for k, v in r.items() if k != "cost_usd"})
                      for r in state.value.get("evaluation_cost", {}).get("calls", [])]
    async def save() -> None:
        state.value["evaluation_cost"] = ledger.summary()
        await state.save()
    def charge(value: dict[str, Any], key: str) -> None:
        exceeded = False
        for index, raw in enumerate(value.get("usage", [])):
            usage = UsageRecord(**{k: v for k, v in raw.items() if k != "cost_usd"})
            usage = replace(usage, call_key=f"{key}:{index}")
            if not any(r.call_key == usage.call_key for r in ledger.records):
                try:
                    ledger.charge(usage)
                except BudgetExceeded:
                    exceeded = True  # preserve every paid call, including an over-budget answer
        if exceeded:
            raise BudgetExceeded("evaluation token budget exceeded")
    scores = state.value["scores"]
    def remaining() -> int | None:
        return None if ledger.budget_tokens is None else ledger.budget_tokens - ledger.tokens
    async def prepared_baseline(case: Case, key: str) -> Request:
        prepared = state.value.setdefault("baseline_requests", {})
        if key not in prepared:
            request = await driver.baseline_request(case, key)
            prepared[key] = {"prompt": request.prompt, "data": request.data, "images": [
                {"data": base64.b64encode(i.data).decode(), "mime": i.mime_type} for i in request.images]}
            await save()  # decoded/transcribed input remains identical when a submitted batch resumes
        value = prepared[key]
        return Request(key, value["prompt"], value["data"], tuple(
            VisionImage(base64.b64decode(i["data"]), i["mime"]) for i in value["images"]))
    async def baseline_request(case: Case, key: str) -> Request:
        history: list[dict[str, Any]] = []
        for index, question in enumerate(case.history):
            turn_key = f"{key}:history:{index}"
            if turn_key not in state.value["answers"]:
                prior = case.model_copy(update={"question": question, "attachments": None, "history": []})
                request = await prepared_baseline(prior, turn_key)
                request = replace(request, data=request.data | {"history": history})
                outcome = (await batches.run([request], ledger, state.value["batches"], save))[turn_key]
                if isinstance(outcome, LLMError):
                    raise outcome
                state.value["answers"][turn_key] = {"answer": outcome.data}
                await save()
            history.append({"question": question, "answer": state.value["answers"][turn_key]["answer"]})
        request = await prepared_baseline(case, key)
        state.value.setdefault("baseline_history", {})[key] = history
        return replace(request, data=request.data | {"history": history})
    for mode in ("cold", "warm"):
        state.value.setdefault("mode_run_at", {}).setdefault(mode, datetime.now(UTC).isoformat())
        namespace = uuid.uuid5(uuid.UUID(state.value["run_id"]), mode)
        if mode == "warm" and "warm_count" not in state.value:
            # Warming is paid work too: checkpoint and charge each case before admitting the next.
            for case in sets["warm"]:
                key = f"warming:raqeeb:{case.id}"
                if key not in state.value["answers"]:
                    ledger.check_available()
                    state.value["answers"][key] = await driver.answer(case, namespace, remaining_tokens=remaining())
                    try:
                        charge(state.value["answers"][key], key)
                    finally:
                        await save()
            # The stateless baseline receives the same disjoint inputs; it has no semantic memory to prime.
            if not state.value.get("baseline_warmed"):
                warm_jobs = []
                for case in sets["warm"]:
                    try:
                        warm_jobs.append(await baseline_request(case, f"warming:baseline:{case.id}"))
                    except (InputUnreadable, ApiError, LLMError):
                        continue
                for index in range(0, len(warm_jobs), 100):
                    await batches.run(warm_jobs[index:index + 100], ledger, state.value["batches"], save)
                state.value["baseline_warmed"] = True
                await save()
            warm = await driver.warm(sets["warm"], namespace, already_answered=True)
            state.value["warm_count"] = warm["count"]
            await save()
        jobs = []
        pending: list[tuple[str, Case, Literal["raqeeb", "baseline_llm"], dict[str, Any],
                            list[str], list[dict[str, Any]], list[dict[str, Any]]]] = []
        judge_jobs = []
        for case in sets["questions"] + sets["adversarial"]:
            key = f"{mode}:raqeeb:{case.id}"
            if key not in state.value["answers"]:
                ledger.check_available()
                state.value["answers"][key] = await driver.answer(case, namespace, remaining_tokens=remaining())
                try:
                    charge(state.value["answers"][key], key)
                finally:
                    await save()
            baseline_key = f"{mode}:baseline_llm:{case.id}"
            if baseline_key not in state.value["answers"]:
                try:
                    jobs.append(await baseline_request(case, baseline_key))
                except (InputUnreadable, ApiError, LLMError) as exc:
                    state.value["answers"][baseline_key] = {"answer": {}, "error": exc.code.value
                        if isinstance(exc, ApiError) else "input_unreadable" if isinstance(exc, InputUnreadable)
                        else type(exc).__name__, "latency_ms": 0, "cost_usd": None, "reused": False}
                    await save()
        if jobs:
            outcomes: dict[str, LLMResult | LLMError] = {}
            for index in range(0, len(jobs), 100):
                outcomes.update(await batches.run(jobs[index:index + 100], ledger, state.value["batches"], save))
            for key, result in outcomes.items():
                state.value["answers"][key] = ({"answer": result.data, "error": None,
                    "latency_ms": sum(u.latency_ms for u in result.usage), "cost_usd": None, "reused": False}
                if isinstance(result, LLMResult) else {"answer": {}, "error": type(result).__name__,
                    "latency_ms": 0, "cost_usd": None, "reused": False})
            await save()
        for case in sets["questions"] + sets["adversarial"]:
            for system in ("raqeeb", "baseline_llm"):
                key = f"{mode}:{system}:{case.id}"
                if key in scores:
                    continue
                value = state.value["answers"][key]
                answer = value["answer"]
                history = value.get("history", []) if system == "raqeeb" else \
                    state.value.get("baseline_history", {}).get(key, [])
                findings, sources = await driver.audit(answer, case, system=system) \
                    if value["error"] is None else ([], [])
                actual_class = answer.get("classification", {}).get("question_class", answer.get("question_class"))
                if value["error"] is None and actual_class != case.expected_class:
                    findings.append("wrong_classification")
                inventory = audit.inventory(answer)
                requests = [Request(key + ":judge", "raqeeb_judge", {
                    "question": case.question, "language": case.language, "gold_points": case.gold_points,
                    "history": history or case.history,
                    "understood_input": audit.understood(answer),
                    "gold_refs": case.gold_refs, "expected_class": case.expected_class,
                    "should_abstain": case.should_abstain, "expected_referral_type": case.expected_referral_type,
                    "expected_error": case.expected_error, "actual_error": value["error"],
                    "answer": {k: answer[k] for k in ("blocks", "citations", "classification", "abstained",
                                                       "question_class") if k in answer}, "source_findings": findings})]
                if inventory:
                    requests.append(Request(key + ":grounding", "raqeeb_grounding", {
                        "sentences": inventory,
                        "answer": {k: answer[k] for k in ("blocks", "citations") if k in answer}, "sources": sources}))
                judge_jobs.extend(requests)
                pending.append((key, case, system, value, findings, sources, inventory))
        judged: dict[str, LLMResult | LLMError] = {}
        for index in range(0, len(judge_jobs), 100):
            judged.update(await batches.run(judge_jobs[index:index + 100], ledger, state.value["batches"], save))
        for key, case, system, value, findings, sources, inventory in pending:
                answer = value["answer"]
                judgment = judged[key + ":judge"]
                if isinstance(judgment, LLMError):
                    raise judgment  # incomplete evaluation is not a negative or perfect answer score
                verdict = evaluation.Judge.model_validate(judgment.data)
                factual = unsupported = 0
                if inventory:
                    grounding = judged[key + ":grounding"]
                    if isinstance(grounding, LLMError):
                        raise grounding
                    marked = evaluation.Grounding.model_validate(grounding.data)
                    if [s.text for s in marked.sentences] != [s["text"] for s in inventory]:
                        raise ValueError("grounding judge omitted, changed or reordered the sentence inventory")
                    valid_refs = {c["ref"] for c in sources}
                    factual = sum(s.factual for s in marked.sentences)
                    unsupported = sum(s.factual and (not s.supported or not s.citation_refs or
                        bool(set(s.citation_refs) - valid_refs) or
                        bool(set(s.citation_refs) - set(expected["citation_refs"])))
                        for s, expected in zip(marked.sentences, inventory, strict=True))
                score = evaluation.Score(case=case, system=system, mode=mode,
                    adversarial=case in sets["adversarial"], answer=answer,
                    answer_sha256=sha256_text(canonical_json(answer)), judge=verdict,
                    factual_sentences=factual, unsupported_sentences=unsupported, source_issues=findings,
                    error=value["error"], reused=value["reused"], latency_ms=value["latency_ms"],
                    cost_usd=value["cost_usd"], history=value.get("history", []) if system == "raqeeb" else
                        state.value.get("baseline_history", {}).get(key, []))
                scores[key] = score.model_dump(mode="json")
                await save()
    rows = [evaluation.Score.model_validate(v) for v in scores.values()]
    report = {"schema": state.value["schema"], "run_id": state.value["run_id"],
        "run_at": state.value["run_at"], "synthetic": synthetic, "binding": binding,
        "mode_run_at": state.value["mode_run_at"],
        "warm_count": state.value.get("warm_count", 0), "evaluation_cost": ledger.summary(),
        "scores": scores, "summaries": {f"{mode}:{system}": evaluation.summary([
            r for r in rows if r.mode == mode and r.system == system])
            for mode in ("cold", "warm") for system in ("raqeeb", "baseline_llm")}}
    state.immutable("judged.json", report)
    return report


async def finalize(resources: Resources, state: State, report: dict[str, Any], labels: list[dict[str, Any]],
                   policy: dict[str, Any], signoff: dict[str, Any] | None = None, *,
                   metrics_resources: Resources | None = None) -> dict[str, Any]:
    rows = [evaluation.Score.model_validate(v) for v in report["scores"].values()]
    synthetic = bool(report["synthetic"])
    if (state.root / "judged.json").read_text(encoding="utf-8") != canonical_json(report):
        raise ValueError("finalization must use the exact immutable judged report")
    if not synthetic and (report["warm_count"] <= 0 or report["binding"] != state.value["binding"]):
        raise ValueError("genuine benchmark requires a populated disjoint warm namespace and exact run binding")
    manual = evaluation.manual_review(rows, labels, synthetic=synthetic)
    manual_sha = sha256_text(canonical_json(labels))
    artifact = {"report": report, "manual": manual, "manual_labels": labels, "manual_report_sha256": manual_sha}
    reviewed_sha = state.immutable("reviewed.json", artifact)
    assessment = evaluation.release(rows, policy, synthetic=synthetic, manual=manual, signoff=signoff,
                                    report_sha256=reviewed_sha)
    state.immutable("release-" + sha256_text(canonical_json({"policy": policy, "signoff": signoff})) + ".json",
                    assessment | {"reviewed_report_sha256": reviewed_sha, "policy": policy, "signoff": signoff})
    versions = report["binding"]["versions"]
    destination = metrics_resources or resources
    async with destination.sessionmaker() as db, db.begin():
        for mode in ("cold", "warm"):
            measured = [r for r in rows if r.mode == mode and not r.adversarial]
            systems = [{"name": system, **{k: round(v) for k, v in evaluation.aggregate([
                r for r in measured if r.system == system]).items()}}
                       for system in ("raqeeb", "baseline_llm")]
            classes = sorted({r.case.expected_class for r in measured})
            results = {"run_at": report["mode_run_at"][mode], "question_count": len(measured) // 2, "systems": systems,
                "by_class": [{"question_class": c,
                    "raqeeb_accuracy_percent": round(evaluation.aggregate([r for r in measured
                        if r.system == "raqeeb" and r.case.expected_class == c])["accuracy_percent"]),
                    "baseline_accuracy_percent": round(evaluation.aggregate([r for r in measured
                        if r.system == "baseline_llm" and r.case.expected_class == c])["accuracy_percent"])}
                    for c in classes]}
            mode_rows = [r for r in rows if r.mode == mode and r.system == "raqeeb"]
            summary = evaluation.summary(mode_rows)
            provenance = benchmark.Provenance(dataset_sha256=report["binding"]["digests"]["questions"],
                adversarial_sha256=report["binding"]["digests"]["adversarial"],
                policy_version=versions["policy"], prompt_versions=versions["prompts"],
                adapter_versions=versions["adapters"], models=versions["models"],
                language_counts={lang: sum(r.case.language == lang and not r.adversarial for r in mode_rows)
                                 for lang in ("ar", "en")},
                adversarial_count=sum(r.adversarial for r in mode_rows), manual_review_count=manual["count"],
                judge_agreement_percent=round(manual["agreement_percent"]), manual_report_sha256=manual_sha,
                mode=mode, latency_p50_ms=summary["latency_p50_ms"], latency_p95_ms=summary["latency_p95_ms"],
                cost_usd=summary["cost_usd"], false_memory_reuse=summary["false_memory_reuse"],
                evaluation={"reviewed_report_sha256": reviewed_sha, "summary": summary,
                            "warm_set_sha256": report["binding"]["digests"]["warm"],
                            "warm_count": report["warm_count"]})
            await benchmark.record(db, destination.settings,
                uuid.uuid5(uuid.UUID(report["run_id"]), "benchmark:" + mode), results, provenance, synthetic=synthetic)
    return assessment | {"reviewed_report_sha256": reviewed_sha}
