"""Usage records and spend accounting (agent catalog cost controls; factory: ``factory_runs.cost``,
``error.code = budget_exceeded``).

Every attempt of every call is recorded with the exact model, prompt identity, effort and token counts (including
prompt-cache reads/writes). A ``Ledger`` accumulates the records of one run, refuses to start a call once the run's
token budget is spent, and raises ``BudgetExceeded`` when a call takes the run past it (the call has already been
paid for, so it is still recorded). USD is computed only when every price involved is confirmed in
``content/llm/models.yaml``; otherwise the cost is reported as unpriced, never estimated.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass, field
from typing import Any

from app.llm.errors import BudgetExceeded
from app.llm.models import load_models


@dataclass(frozen=True)
class UsageRecord:
    model: str                      # the model ID the provider reports having used
    prompt_id: str
    prompt_version: int
    prompt_sha256: str
    effort: str | None              # None when the model's effort control is unverified (not sent)
    thinking: str
    attempt: int                    # 1, or 2 for the corrective retry
    input_tokens: int
    output_tokens: int
    cache_creation_input_tokens: int
    cache_read_input_tokens: int
    stop_reason: str | None
    latency_ms: int
    request_id: str | None = None
    call_key: str | None = None     # caller identity, e.g. "<run_id>:<stage>:<attempt>"
    pricing_mode: str = "standard"

    @property
    def tokens(self) -> int:
        return (self.input_tokens + self.output_tokens + self.cache_creation_input_tokens
                + self.cache_read_input_tokens)

    def cost_usd(self) -> float | None:
        if self.pricing_mode == "batch":
            return None  # Batch pricing/terms are not approved in O-03; never apply assumed discounts.
        policy = load_models().get(self.model)
        prices = policy.price_per_mtok if policy else None
        if prices is None or not prices.complete:
            return None
        assert prices.input is not None and prices.output is not None
        assert prices.cache_write is not None and prices.cache_read is not None
        return (self.input_tokens * prices.input + self.output_tokens * prices.output
                + self.cache_creation_input_tokens * prices.cache_write
                + self.cache_read_input_tokens * prices.cache_read) / 1_000_000


@dataclass
class Ledger:
    budget_tokens: int | None = None
    records: list[UsageRecord] = field(default_factory=list)

    @property
    def tokens(self) -> int:
        return sum(r.tokens for r in self.records)

    def check_available(self) -> None:
        if self.budget_tokens is not None and self.tokens >= self.budget_tokens:
            raise BudgetExceeded(f"token budget {self.budget_tokens} is spent ({self.tokens})")

    def charge(self, record: UsageRecord) -> None:
        self.records.append(record)
        if self.budget_tokens is not None and self.tokens > self.budget_tokens:
            raise BudgetExceeded(f"token budget {self.budget_tokens} exceeded ({self.tokens})")

    def summary(self) -> dict[str, Any]:
        """The ``cost`` document of a run: every call, token totals and USD only when fully priced."""
        costs = [r.cost_usd() for r in self.records]
        unpriced = sorted({r.model for r, c in zip(self.records, costs, strict=True) if c is None})
        return {"calls": [asdict(r) | {"cost_usd": c} for r, c in zip(self.records, costs, strict=True)],
                "tokens": {"input": sum(r.input_tokens for r in self.records),
                           "output": sum(r.output_tokens for r in self.records),
                           "cache_write": sum(r.cache_creation_input_tokens for r in self.records),
                           "cache_read": sum(r.cache_read_input_tokens for r in self.records),
                           "total": self.tokens},
                "budget_tokens": self.budget_tokens,
                "usd": None if unpriced else round(sum(c for c in costs if c is not None), 6),
                "unpriced_models": unpriced}
