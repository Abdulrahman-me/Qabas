"""Factory run orchestration (factory §13.1 "Stage execution (rev 10)").

Each stage is an idempotent task keyed by (``run_id``, ``stage``, ``attempt``):

1. **Claim** (short transaction, run row locked): the message must name the run's current stage and attempt and
   the stage must not be done; otherwise it is a stale or duplicate delivery and does nothing. A claim of a stage
   already ``running`` at the same attempt is a redelivery after a crash and is recorded as ``resumed``.
2. **Execute** (no lock held): the stage reads its inputs from the claimed snapshot (``factory_runs.artifacts``),
   calls models only through ``app.llm`` and sources only through ``app.sources``.
3. **Complete** (run row locked again): every model call of the attempt is appended to ``cost`` (spend is real
   even for rejected output); the stage's accepted artifact, its provenance and the stage status are written in
   one transaction; only then is the next stage dispatched. A worker crash therefore re-runs at most one stage, and
   a duplicate delivery that finishes second writes nothing but its spend.

Failures: model unavailability, truncated or invalid output, the stage's own code checks and unexpected errors are
retried (two retries, with the previous attempt's issues as feedback); a refusal, an exhausted budget, a missing
configuration or approval, and a human blocker (``StageBlocked``) fail the run at once (catalog: refusals are never
silently retried; D-85: generation never works around a blocker). Gates: after ``plan`` the run awaits Gate 1, after
``qa`` Gate 2, each with the digest of the artifact under review.
"""

from __future__ import annotations

import logging
from collections.abc import Awaitable, Callable, Mapping
from dataclasses import asdict, dataclass, field
from datetime import datetime
from typing import Any, Protocol

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.config import Settings
from app.content.package import content_digest
from app.factory import pipeline
from app.factory.errors import StageBlocked, StageOutputInvalid
from app.llm.budget import Ledger, UsageRecord
from app.llm.client import LLMClient
from app.llm.errors import (
    BudgetExceeded,
    LLMNotConfigured,
    LLMOutputInvalid,
    LLMRefusal,
    LLMRequestRejected,
    LLMTruncated,
    LLMUnavailable,
    UnsafePromptData,
)
from app.models import FactoryRun
from app.services.platform.auth_sessions import utcnow
from app.sources.errors import ProviderNotConfigured, UpstreamUnavailable
from app.sources.mushaf import MushafError

log = logging.getLogger("qabas.factory")
RETRY_BACKOFF_SECONDS = (0, 30, 120)
NOT_RETRIED: dict[type[BaseException], str] = {
    BudgetExceeded: "budget_exceeded", LLMRefusal: "refusal", LLMNotConfigured: "model_not_configured",
    LLMRequestRejected: "request_rejected", UnsafePromptData: "unsafe_prompt_data",
    ProviderNotConfigured: "source_not_configured", MushafError: "mushaf_unavailable",
}
RETRIED: dict[type[BaseException], str] = {
    LLMUnavailable: "model_unavailable", LLMTruncated: "output_truncated", LLMOutputInvalid: "output_invalid",
    UpstreamUnavailable: "source_unavailable",
}


@dataclass(frozen=True)
class RunSnapshot:
    id: str
    unit_id: str
    lesson_id: str
    position_index: int
    lesson_type: str
    brief: str
    stage: str
    attempt: int
    plan: dict[str, Any] | None
    artifacts: dict[str, Any]
    budget_tokens: int | None
    cost_calls: list[dict[str, Any]]
    previous_issues: list[str]


@dataclass(frozen=True)
class StageResult:
    output: dict[str, Any]                       # the accepted artifact of this stage
    inputs: dict[str, Any]                       # what the stage was given (digest recorded; ids kept)
    plan: dict[str, Any] | None = None
    qa_report: dict[str, Any] | None = None
    notes: dict[str, Any] = field(default_factory=dict)


@dataclass
class StageContext:
    run: RunSnapshot
    settings: Settings
    llm: LLMClient
    ledger: Ledger
    sessionmaker: async_sessionmaker[AsyncSession]
    services: Mapping[str, Any]

    @property
    def call_key(self) -> str:
        return f"{self.run.id}:{self.run.stage}:{self.run.attempt}"


Executor = Callable[[StageContext], Awaitable[StageResult]]


class Dispatcher(Protocol):
    def send(self, run_id: str, stage: str, attempt: int, countdown: float = 0) -> None: ...


def _usage(record: dict[str, Any]) -> UsageRecord:
    known = {k: v for k, v in record.items() if k in UsageRecord.__dataclass_fields__}
    return UsageRecord(**known)


def gate_digest(gate: str, run: FactoryRun) -> str:
    """The digest of the artifact a reviewer decides on (FactoryRun.review_digest)."""
    if gate == "awaiting_gate1":
        return content_digest({"gate": 1, "plan": run.plan})
    return content_digest({"gate": 2, "draft": pipeline.current_draft(run.artifacts), "qa_report": run.qa_report})


class Orchestrator:
    def __init__(self, sessionmaker: async_sessionmaker[AsyncSession], settings: Settings, llm: LLMClient,
                 dispatcher: Dispatcher, executors: Mapping[str, Executor], *,
                 services: Mapping[str, Any] | None = None, clock: Callable[[], datetime] = utcnow) -> None:
        self.sessionmaker, self.settings, self.llm, self.dispatcher = sessionmaker, settings, llm, dispatcher
        self.executors, self.services, self.clock = executors, services or {}, clock

    async def run_stage(self, run_id: str, stage: str, attempt: int) -> str:
        """``done``, ``gate``, ``retry``, ``failed`` or ``stale``."""
        snapshot = await self._claim(run_id, stage, attempt)
        if snapshot is None:
            return "stale"
        ledger = Ledger(snapshot.budget_tokens, [_usage(c) for c in snapshot.cost_calls])
        spent_before = len(ledger.records)
        context = StageContext(snapshot, self.settings, self.llm, ledger, self.sessionmaker, self.services)
        result: StageResult | None = None
        failure: tuple[str, str, list[str], bool] | None = None
        try:
            executor = self.executors.get(stage)
            if executor is None:
                raise StageBlocked("stage_unavailable", f"stage {stage} is not available in this release")
            result = await executor(context)
        except StageOutputInvalid as exc:
            failure = (exc.code, str(exc), exc.issues, True)
        except StageBlocked as exc:
            failure = (exc.code, exc.message, [], False)
        except Exception as exc:  # classified below; anything unknown is retried as a crash
            failure = self._classify(exc)
        return await self._complete(snapshot, result, failure, ledger.records[spent_before:])

    @staticmethod
    def _classify(exc: BaseException) -> tuple[str, str, list[str], bool]:
        for kind, code in NOT_RETRIED.items():
            if isinstance(exc, kind):
                return code, str(exc), [], False
        for kind, code in RETRIED.items():
            if isinstance(exc, kind):
                return code, str(exc), [], True
        log.exception("factory stage crashed", exc_info=exc)
        return "internal_error", f"{type(exc).__name__}", [], True

    async def _claim(self, run_id: str, stage: str, attempt: int) -> RunSnapshot | None:
        now = self.clock().isoformat()
        async with self.sessionmaker() as db, db.begin():
            run = await db.get(FactoryRun, run_id, with_for_update=True)
            if run is None or run.status != "running" or run.stage != stage or run.attempt != attempt:
                return None
            stages = [dict(s) for s in run.stages]
            entry = next(s for s in stages if s["stage"] == stage)
            if entry["status"] == "done":
                return None
            resumed = entry["status"] == "running" and any(
                a["stage"] == stage and a["attempt"] == attempt and a["event"] in ("started", "resumed")
                for a in run.attempts)
            entry.update(status="running", started_at=entry["started_at"] or now)
            run.stages = stages
            run.attempts = [*run.attempts, {"stage": stage, "attempt": attempt,
                                            "event": "resumed" if resumed else "started", "at": now}]
            previous = [a for a in run.attempts if a["stage"] == stage and a["event"] == "failed"]
            return RunSnapshot(run.id, run.unit_id, run.lesson_id, run.position_index, run.lesson_type, run.brief,
                               stage, attempt, run.plan, dict(run.artifacts), run.budget_tokens,
                               list(run.cost.get("calls", [])),
                               list(previous[-1].get("issues", [])) if previous else [])

    async def _complete(self, snapshot: RunSnapshot, result: StageResult | None,
                        failure: tuple[str, str, list[str], bool] | None, spent: list[UsageRecord]) -> str:
        now = self.clock()
        stage, attempt = snapshot.stage, snapshot.attempt
        dispatch: tuple[str, int, float] | None = None
        async with self.sessionmaker() as db, db.begin():
            run = await db.get(FactoryRun, snapshot.id, with_for_update=True)
            assert run is not None
            calls = [*run.cost.get("calls", []), *(asdict(r) for r in spent)]
            run.cost = Ledger(run.budget_tokens, [_usage(c) for c in calls]).summary() | {"calls": calls}
            current = next(s for s in run.stages if s["stage"] == stage)
            if run.status != "running" or run.stage != stage or run.attempt != attempt or current["status"] == "done":
                run.attempts = [*run.attempts, {"stage": stage, "attempt": attempt, "event": "discarded",
                                                "at": now.isoformat()}]
                return "stale"
            stages = [dict(s) for s in run.stages]
            entry = next(s for s in stages if s["stage"] == stage)
            if result is not None:
                outcome = self._accept(run, stages, entry, snapshot, result, spent, now)
                if outcome == "done":
                    run.stage, run.attempt = pipeline.next_stage(stage) or stage, 1
                    dispatch = (run.stage, 1, 0)
            else:
                assert failure is not None
                code, message, issues, retryable = failure
                run.attempts = [*run.attempts, {"stage": stage, "attempt": attempt, "event": "failed", "code": code,
                                                "message": message[:2000], "issues": issues[:50],
                                                "retryable": retryable, "at": now.isoformat()}]
                if retryable and attempt < pipeline.MAX_ATTEMPTS:
                    run.attempt = attempt + 1
                    dispatch = (stage, attempt + 1, RETRY_BACKOFF_SECONDS[attempt])
                    outcome = "retry"
                else:
                    entry.update(status="failed", finished_at=now.isoformat())
                    run.status, run.error = "failed", {"code": code, "message": message[:2000]}
                    outcome = "failed"
                    log.warning("factory run failed", extra={"run_id": run.id, "stage": stage, "code": code})
            run.stages = stages
        if dispatch is not None:
            self.dispatcher.send(snapshot.id, *dispatch[:2], countdown=dispatch[2])
        return outcome

    def _accept(self, run: FactoryRun, stages: list[dict[str, Any]], entry: dict[str, Any], snapshot: RunSnapshot,
                result: StageResult, spent: list[UsageRecord], now: datetime) -> str:
        stage = snapshot.stage
        prompts = sorted({(r.prompt_id, r.prompt_version, r.prompt_sha256) for r in spent})
        run.artifacts = {**run.artifacts, stage: {
            "output": result.output, "attempt": snapshot.attempt, "completed_at": now.isoformat(),
            "inputs_digest": content_digest(result.inputs), "output_digest": content_digest(result.output),
            "inputs": result.inputs, "notes": result.notes,
            "prompts": [{"prompt_id": p, "prompt_version": v, "prompt_sha256": s} for p, v, s in prompts],
            "models": sorted({r.model for r in spent}), "call_keys": sorted({r.call_key or "" for r in spent})}}
        entry.update(status="done", finished_at=now.isoformat())
        started = datetime.fromisoformat(entry["started_at"]) if entry["started_at"] else now
        run.stage_timings = {**run.stage_timings, stage: {"ms": int((now - started).total_seconds() * 1000),
                                                          "attempts": snapshot.attempt}}
        run.attempts = [*run.attempts, {"stage": stage, "attempt": snapshot.attempt, "event": "done",
                                        "at": now.isoformat()}]
        if result.plan is not None:
            run.plan = result.plan
        if result.qa_report is not None:
            run.qa_report = result.qa_report
        gate = pipeline.GATE_AFTER.get(stage)
        if gate is not None:
            run.stages = stages
            run.status = gate
            run.review_digest = gate_digest(gate, run)
            return "gate"
        return "done"
