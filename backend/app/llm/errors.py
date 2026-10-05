"""Classified outcomes of a model call (agent catalog calling rules). Callers map them, never retry around them:
a refusal is a normal outcome (factory: QA blocker; Raqeeb: ``upstream_unavailable``), invalid output fails the stage
after one corrective retry, and nothing is silently re-run on a weaker path that skips guards."""

from __future__ import annotations


class LLMError(RuntimeError):
    code: str = "llm_error"


class LLMNotConfigured(LLMError):
    """No API key, an unknown prompt/model, or a model not approved for this environment (O-03)."""

    code = "not_configured"


class LLMUnavailable(LLMError):
    """Timeouts, connection failures, 429/5xx/overload after the SDK's bounded retries."""

    code = "upstream_unavailable"


class LLMRequestRejected(LLMError):
    """The provider rejected the request itself (4xx other than 429): a defect in our request, not an outage."""

    code = "request_rejected"


class LLMRefusal(LLMError):
    """``stop_reason == "refusal"``."""

    code = "refusal"


class LLMTruncated(LLMError):
    """The output hit ``max_tokens`` (or the context window) before completing the schema."""

    code = "truncated"


class LLMOutputInvalid(LLMError):
    """The output failed schema/contract validation twice (once corrected with the error appended)."""

    code = "output_invalid"


class BudgetExceeded(LLMError):
    """A run's configured token budget is exhausted (factory ``error.code = budget_exceeded``)."""

    code = "budget_exceeded"


class UnsafePromptData(LLMError):
    """Prompt data carries a learner identifier or a sampling parameter was requested (catalog data rules)."""

    code = "unsafe_prompt_data"
