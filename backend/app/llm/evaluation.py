"""Bilingual model-validation harness skeleton (Phase 11; O-03 "validate model IDs on the bilingual tasks").

A case file (JSON lines) lists tasks: ``{"id", "language": "ar"|"en", "prompt_id", "data": {...}, "checks": [...]}``.
Each case runs through the real adapter (``LLMClient``), so the same framing, structured output, validation, retry
and refusal handling apply as in production. Deterministic checks then score the validated output:

* ``language``: a text field is written in the case language (share of Arabic vs Latin letters);
* ``max_words`` / ``min_words``: word count of a text field;
* ``equals`` / ``one_of``: exact expected values; ``absent``: none of the given substrings appear.

The report records, per system (a label for a model configuration): every case's outcome, error class, latency,
tokens and the exact model/prompt identity, plus pass rates by language, failure counts by error class, latency
p50/p95, total tokens and (only when every price is confirmed) cost. Release thresholds are a product decision; the
report states each metric and leaves the verdict to the evaluator. Judged (model-graded) checks and the Raqeeb
benchmark (§16) build on this in their own phases. Evaluation sets live in the private area (D-19); the repository
holds only a small neutral sample used by CI with the fake client.
"""

from __future__ import annotations

import json
import re
import statistics
import time
from collections.abc import Mapping, Sequence
from pathlib import Path
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field

from app.llm.budget import Ledger
from app.llm.client import LLMClient
from app.llm.errors import LLMError

ARABIC = re.compile(r"[؀-ۿݐ-ݿࢠ-ࣿ]")
LATIN = re.compile(r"[A-Za-z]")
LANGUAGE_SHARE = 0.8


class Check(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    type: Literal["language", "max_words", "min_words", "equals", "one_of", "absent"]
    field: str
    value: Any = None


class Case(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    id: str
    language: Literal["ar", "en"]
    prompt_id: str
    data: dict[str, Any]
    checks: list[Check] = Field(min_length=1)


def load_cases(path: Path) -> list[Case]:
    cases = [Case.model_validate_json(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]
    if len({c.id for c in cases}) != len(cases):
        raise ValueError(f"{path}: duplicate case ids")
    return cases


def _field(output: Mapping[str, Any], name: str) -> Any:
    value: Any = output
    for part in name.split("."):
        value = value[part]
    return value


def written_in(text: str, language: str) -> bool:
    arabic, latin = len(ARABIC.findall(text)), len(LATIN.findall(text))
    letters = arabic + latin
    if letters == 0:
        return False
    return (arabic if language == "ar" else latin) / letters >= LANGUAGE_SHARE


def run_check(check: Check, case: Case, output: Mapping[str, Any]) -> str | None:
    """None when the check passes, else a short reason."""
    try:
        value = _field(output, check.field)
    except (KeyError, TypeError):
        return f"{check.field} missing"
    words = len(str(value).split())
    if check.type == "language":
        return None if written_in(str(value), case.language) else f"{check.field} is not in {case.language}"
    if check.type == "max_words":
        return None if words <= int(check.value) else f"{check.field} has {words} words > {check.value}"
    if check.type == "min_words":
        return None if words >= int(check.value) else f"{check.field} has {words} words < {check.value}"
    if check.type == "equals":
        return None if value == check.value else f"{check.field} != expected"
    if check.type == "one_of":
        return None if value in check.value else f"{check.field} not among the expected values"
    return None if not any(s in str(value) for s in check.value) else f"{check.field} contains a forbidden string"


def _percentile(values: Sequence[float], q: float) -> float | None:
    if not values:
        return None
    ordered = sorted(values)
    return ordered[min(len(ordered) - 1, round(q * (len(ordered) - 1)))]


async def evaluate(cases: Sequence[Case], systems: Mapping[str, LLMClient], *,
                   budget_tokens: int | None = None) -> dict[str, Any]:
    report: dict[str, Any] = {"schema": "qabas.llm_evaluation/1", "cases": len(cases), "systems": {}}
    for label, client in systems.items():
        ledger = Ledger(budget_tokens)
        results = []
        for case in cases:
            started = time.perf_counter()
            entry: dict[str, Any] = {"id": case.id, "language": case.language, "prompt_id": case.prompt_id}
            try:
                result = await client.structured(case.prompt_id, case.data, ledger=ledger, call_key=f"eval:{case.id}")
            except LLMError as exc:
                entry.update(passed=False, error=exc.code, failures=[str(exc)])
            else:
                failures = [r for r in (run_check(c, case, result.data) for c in case.checks) if r]
                entry.update(passed=not failures, error=None, failures=failures, output=result.data,
                             model=result.model, prompt=result.prompt, attempts=len(result.usage),
                             tokens=sum(u.tokens for u in result.usage))
            entry["latency_ms"] = int((time.perf_counter() - started) * 1000)
            results.append(entry)
        latencies = [r["latency_ms"] for r in results]
        by_language = {}
        for language in ("ar", "en"):
            subset = [r for r in results if r["language"] == language]
            if subset:
                by_language[language] = {"cases": len(subset), "passed": sum(r["passed"] for r in subset),
                                         "pass_rate": round(sum(r["passed"] for r in subset) / len(subset), 4)}
        errors: dict[str, int] = {}
        for r in results:
            if r["error"]:
                errors[r["error"]] = errors.get(r["error"], 0) + 1
        cost = ledger.summary()
        report["systems"][label] = {
            "models": sorted({r["model"] for r in results if r.get("model")}),
            "pass_rate": round(sum(r["passed"] for r in results) / len(results), 4) if results else None,
            "by_language": by_language, "errors": errors,
            "latency_ms": {"p50": statistics.median(latencies) if latencies else None,
                           "p95": _percentile(latencies, 0.95)},
            "tokens": cost["tokens"], "usd": cost["usd"], "unpriced_models": cost["unpriced_models"],
            "results": results}
    return report


def write_report(report: Mapping[str, Any], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
