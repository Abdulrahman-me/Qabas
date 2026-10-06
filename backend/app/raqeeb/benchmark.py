"""Append-only benchmark persistence and existing metrics projection (F-145).

Phase 17 owns the private dataset runner/judge/cold+warm memory experiments. This module does not claim a
synthetic CI run meets release thresholds, and stores aggregate results/digests, never private questions.
"""

from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import Environment, Settings
from app.contract import models as C
from app.models import BenchmarkRun
from app.sources.records import canonical_json, sha256_text


class Provenance(BaseModel):
    model_config = ConfigDict(extra="forbid")
    dataset_sha256: str = Field(pattern=r"^[0-9a-f]{64}$")
    adversarial_sha256: str = Field(pattern=r"^[0-9a-f]{64}$")
    policy_version: str
    prompt_versions: dict[str, str]
    adapter_versions: dict[str, str]
    models: dict[str, str]
    language_counts: dict[str, int]
    adversarial_count: int = Field(ge=0)
    manual_review_count: int = Field(ge=0)
    judge_agreement_percent: int | None = Field(ge=0, le=100)
    manual_report_sha256: str | None = Field(pattern=r"^[0-9a-f]{64}$")
    mode: Literal["cold", "warm"]
    latency_p50_ms: int = Field(ge=0)
    latency_p95_ms: int = Field(ge=0)
    cost_usd: float | None = Field(ge=0, allow_inf_nan=False)
    false_memory_reuse: int = Field(ge=0)
    evaluation: dict[str, Any] | None = None


async def record(db: AsyncSession, settings: Settings, run_id: uuid.UUID, results: dict[str, Any],
                 provenance: Provenance, *, synthetic: bool = False) -> bool:
    metrics = C.BenchmarkMetrics.model_validate(results).model_dump(mode="json")
    if {s["name"] for s in metrics["systems"]} != {"raqeeb", "baseline_llm"} or len(metrics["systems"]) != 2:
        raise ValueError("benchmark must compare exactly Raqeeb and the same strong baseline")
    for row in metrics["systems"] + metrics["by_class"]:
        if any(not 0 <= v <= 100 for k, v in row.items() if k.endswith("percent")):
            raise ValueError("benchmark percentages must be in 0-100")
    if synthetic and settings.app_env not in (Environment.dev, Environment.test):
        raise ValueError("synthetic benchmark rows are allowed only in dev/test")
    if not synthetic:
        classes = set(C.QuestionClass.__args__)
        if not 60 <= metrics["question_count"] <= 80 or len(metrics["by_class"]) != 8 or {
                c["question_class"] for c in metrics["by_class"]} != classes:
            raise ValueError("a real benchmark requires 60-80 cases and all eight classes")
        if set(provenance.language_counts) != {"ar", "en"} or min(provenance.language_counts.values()) <= 0 or \
                sum(provenance.language_counts.values()) != metrics["question_count"] or \
                provenance.adversarial_count < 20:
            raise ValueError("a real benchmark requires bilingual coverage and at least twenty adversarial cases")
        if provenance.manual_review_count < 20 or provenance.judge_agreement_percent is None or \
                provenance.manual_report_sha256 is None:
            raise ValueError("a real benchmark requires recorded manual review and judge agreement")
        if not provenance.policy_version or not provenance.prompt_versions or not provenance.adapter_versions or \
                not provenance.models.get("raqeeb_strong") or \
                provenance.models["raqeeb_strong"] != provenance.models.get("baseline_llm"):
            raise ValueError("a real benchmark records versions and compares the same strong model")
    value = provenance.model_dump(mode="json")
    if value["evaluation"] is None:
        del value["evaluation"]  # preserve exact replay digests of Phase 16 rows
    digest = sha256_text(canonical_json({"results": metrics, "provenance": value, "synthetic": synthetic}))
    result = await db.execute(insert(BenchmarkRun).values(id=run_id,
        run_at=datetime.fromisoformat(metrics["run_at"].replace("Z", "+00:00")),
        question_count=metrics["question_count"], results=metrics, provenance=value, digest=digest, synthetic=synthetic
    ).on_conflict_do_nothing(index_elements=[BenchmarkRun.id]))
    previous = await db.get(BenchmarkRun, run_id)
    assert previous is not None
    if previous.digest != digest:
        raise ValueError("a benchmark run ID cannot be reused for different results")
    return bool(result.rowcount)  # type: ignore[attr-defined]


async def latest(db: AsyncSession) -> dict[str, Any] | None:
    # Reading authoritative immutable rows means rebuild/backfill and event replay cannot double-count.
    row = (await db.execute(select(BenchmarkRun).where(BenchmarkRun.synthetic.is_(False))
        .order_by(BenchmarkRun.run_at.desc(), BenchmarkRun.id.desc()).limit(1))).scalar_one_or_none()
    return C.BenchmarkMetrics.model_validate(row.results).model_dump(mode="json") if row else None
