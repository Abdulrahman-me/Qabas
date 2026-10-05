"""The model-calling adapter (system architecture "LLM"; agent catalog calling rules; AD-27).

One call = one registered prompt + its output schema + framed data:

* the model comes from the prompt's tier (``LLM_MODEL_STRONG`` / ``LLM_MODEL_FAST``) and its policy (unknown models
  are refused; unapproved ones are refused in production, O-03);
* data is framed as untrusted, nonce-tagged elements and checked for learner identifiers before anything is sent;
* the request asks for structured output (``output_config.format`` = the prompt's JSON schema) and sets
  ``output_config.effort`` explicitly where the model declares it; sampling parameters and forced ``tool_choice``
  are never sent; adaptive thinking only where the prompt asks for it and the model declares it;
* ``stop_reason`` is checked before content: ``refusal`` -> ``LLMRefusal``; ``max_tokens`` / context window ->
  ``LLMTruncated``;
* the text is parsed and validated against the prompt's schema and, where named, the revision 10 contract model;
  on failure the call is repeated once with the validation error appended, then ``LLMOutputInvalid``;
* transport failures, 429 and 5xx/overload are retried with backoff by the SDK (``LLM_MAX_RETRIES``) within
  ``LLM_TIMEOUT_SECONDS``, then ``LLMUnavailable``; other 4xx are ``LLMRequestRejected`` (our defect, not retried);
* every attempt is recorded (model, prompt id/version/digest, effort, tokens incl. cache, latency) and charged to
  the caller's ``Ledger``; logs carry this metadata only, never prompt data or model output.

The fixed system preamble is marked for prompt caching (ephemeral) so repeated stage calls reuse it.
"""

from __future__ import annotations

import json
import logging
import time
from collections.abc import Callable, Mapping
from dataclasses import dataclass
from typing import Any, Protocol

from jsonschema import Draft202012Validator
from pydantic import ValidationError

from app.config import Settings
from app.contract import models as C
from app.llm.budget import Ledger, UsageRecord
from app.llm.errors import (
    LLMNotConfigured,
    LLMOutputInvalid,
    LLMRefusal,
    LLMRequestRejected,
    LLMTruncated,
    LLMUnavailable,
)
from app.llm.framing import frame
from app.llm.models import ModelPolicy, model_policy
from app.llm.prompts import Effort, Prompt, get_prompt

log = logging.getLogger("qabas.llm")
FORBIDDEN_PARAMETERS = frozenset({"temperature", "top_p", "top_k", "tool_choice"})
CORRECTION = ("Your previous output did not validate: {error}. Return the complete corrected JSON object only, "
              "following the same schema.")


@dataclass(frozen=True)
class LLMResult:
    data: dict[str, Any]
    usage: tuple[UsageRecord, ...]          # one record per attempt
    model: str
    prompt: dict[str, Any]                  # prompt identity (id, version, digests)


class LLMClient(Protocol):
    async def structured(self, prompt_id: str, data: Mapping[str, Any], *, ledger: Ledger | None = None,
                         call_key: str | None = None, effort: Effort | None = None) -> LLMResult: ...


class OutputProblem(Exception):
    pass


def validate_output(prompt: Prompt, text: str) -> dict[str, Any]:
    """Parse and validate model output: JSON object, the prompt's schema, the named contract model."""
    try:
        data = json.loads(text)
    except json.JSONDecodeError as exc:
        raise OutputProblem(f"not JSON ({exc.msg})") from exc
    if not isinstance(data, dict):
        raise OutputProblem("the top level must be a JSON object")
    errors = sorted(Draft202012Validator(prompt.schema).iter_errors(data), key=lambda e: list(e.path))
    if errors:
        first = errors[0]
        raise OutputProblem(f"{'/'.join(map(str, first.path)) or '$'}: {first.message}")
    if prompt.meta.contract_model:
        try:
            getattr(C, prompt.meta.contract_model).model_validate(data)
        except ValidationError as exc:
            raise OutputProblem(f"contract {prompt.meta.contract_model}: {exc.errors()[0]['msg']}") from exc
    return data


def request_arguments(prompt: Prompt, policy: ModelPolicy, model: str, system: list[dict[str, Any]],
                      messages: list[dict[str, Any]], effort: Effort | None) -> dict[str, Any]:
    output_config: dict[str, Any] = {"format": {"type": "json_schema", "schema": prompt.schema}}
    level = effort or prompt.meta.effort
    declared = policy.capabilities.effort
    if declared is not None and level in declared:
        output_config["effort"] = level
    arguments: dict[str, Any] = {"model": model, "max_tokens": prompt.meta.max_tokens, "system": system,
                                 "messages": messages, "output_config": output_config}
    if prompt.meta.thinking == "adaptive" and policy.capabilities.adaptive_thinking:
        arguments["thinking"] = {"type": "adaptive"}
    assert not FORBIDDEN_PARAMETERS & arguments.keys()
    return arguments


class AnthropicClient:
    def __init__(self, settings: Settings, *, sdk: Any | None = None,
                 clock: Callable[[], float] = time.perf_counter) -> None:
        self.settings, self.clock = settings, clock
        if sdk is None:
            if settings.anthropic_api_key is None or not settings.anthropic_api_key.get_secret_value():
                raise LLMNotConfigured("ANTHROPIC_API_KEY is not configured")
            import anthropic

            sdk = anthropic.AsyncAnthropic(api_key=settings.anthropic_api_key.get_secret_value(),
                                           timeout=settings.llm_timeout_seconds,
                                           max_retries=settings.llm_max_retries)
        self.sdk = sdk

    def model_for(self, prompt: Prompt) -> str:
        return self.settings.llm_model_strong if prompt.meta.tier == "strong" else self.settings.llm_model_fast

    async def structured(self, prompt_id: str, data: Mapping[str, Any], *, ledger: Ledger | None = None,
                         call_key: str | None = None, effort: Effort | None = None) -> LLMResult:
        prompt = get_prompt(prompt_id)
        model = self.model_for(prompt)
        policy = model_policy(model, self.settings)
        framed = frame(data)
        system: list[dict[str, Any]] = [
            {"type": "text", "text": prompt.system, "cache_control": {"type": "ephemeral"}},
            {"type": "text", "text": framed.instruction}]
        messages: list[dict[str, Any]] = [{"role": "user", "content": framed.text}]
        records: list[UsageRecord] = []
        for attempt in (1, 2):
            if ledger is not None:
                ledger.check_available()
            arguments = request_arguments(prompt, policy, model, system, messages, effort)
            started = self.clock()
            response = await self._create(arguments)
            record = self._record(prompt, response, arguments, attempt, started, call_key)
            records.append(record)
            log.info("llm call", extra={"prompt_id": prompt.id, "prompt_version": prompt.version,
                                        "model": record.model, "attempt": attempt, "stop_reason": record.stop_reason,
                                        "input_tokens": record.input_tokens, "output_tokens": record.output_tokens,
                                        "latency_ms": record.latency_ms, "call_key": call_key})
            if ledger is not None:
                ledger.charge(record)
            if response.stop_reason == "refusal":
                raise LLMRefusal(f"{prompt.id}: the model refused")
            if response.stop_reason in ("max_tokens", "model_context_window_exceeded"):
                raise LLMTruncated(f"{prompt.id}: output truncated ({response.stop_reason})")
            text = "".join(getattr(block, "text", "") for block in response.content
                           if getattr(block, "type", None) == "text")
            try:
                return LLMResult(validate_output(prompt, text), tuple(records), record.model, prompt.identity())
            except OutputProblem as problem:
                if attempt == 2:
                    raise LLMOutputInvalid(f"{prompt.id}: {problem}") from None
                messages = [*messages, {"role": "assistant", "content": text or "{}"},
                            {"role": "user", "content": CORRECTION.format(error=problem)}]
        raise AssertionError("unreachable")

    async def _create(self, arguments: dict[str, Any]) -> Any:
        import anthropic

        try:
            return await self.sdk.messages.create(**arguments)
        except (anthropic.APITimeoutError, anthropic.APIConnectionError, anthropic.RateLimitError,
                anthropic.InternalServerError) as exc:
            raise LLMUnavailable(f"model provider unavailable ({type(exc).__name__})") from None
        except (anthropic.AuthenticationError, anthropic.PermissionDeniedError) as exc:
            raise LLMNotConfigured(f"model provider refused the credentials ({type(exc).__name__})") from None
        except anthropic.APIStatusError as exc:
            if exc.status_code >= 500:
                raise LLMUnavailable(f"model provider unavailable (HTTP {exc.status_code})") from None
            raise LLMRequestRejected(f"model provider rejected the request (HTTP {exc.status_code})") from None

    def _record(self, prompt: Prompt, response: Any, arguments: dict[str, Any], attempt: int, started: float,
                call_key: str | None) -> UsageRecord:
        usage = response.usage
        return UsageRecord(
            model=str(response.model), prompt_id=prompt.id, prompt_version=prompt.version,
            prompt_sha256=prompt.sha256, effort=arguments["output_config"].get("effort"),
            thinking=arguments.get("thinking", {}).get("type", "disabled"), attempt=attempt,
            input_tokens=int(usage.input_tokens), output_tokens=int(usage.output_tokens),
            cache_creation_input_tokens=int(getattr(usage, "cache_creation_input_tokens", 0) or 0),
            cache_read_input_tokens=int(getattr(usage, "cache_read_input_tokens", 0) or 0),
            stop_reason=response.stop_reason, latency_ms=int((self.clock() - started) * 1000),
            request_id=getattr(response, "id", None), call_key=call_key)
