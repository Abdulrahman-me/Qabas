"""Deterministic stand-ins for tests and CI (no live model calls; Phase 11 tracker "a deterministic fake client").

* ``FakeAnthropicSDK`` imitates ``AsyncAnthropic().messages.create`` with scripted responses, so tests drive the real
  ``AnthropicClient`` (framing, request shape, stop reasons, validation and corrective retry, usage, ledger).
* ``FakeLLMClient`` implements ``LLMClient`` for later phases' tests: scripted outputs per prompt id, passed through
  the same framing checks and output validation as live calls, with reproducible token counts.

Nothing in the application selects these; they are only constructed by tests and the offline evaluation dry run.
"""

from __future__ import annotations

import json
from collections.abc import Callable, Mapping
from dataclasses import dataclass, field
from types import SimpleNamespace
from typing import Any

from app.llm.budget import Ledger, UsageRecord
from app.llm.client import LLMResult, OutputProblem, validate_output
from app.llm.errors import LLMOutputInvalid
from app.llm.framing import frame
from app.llm.prompts import Effort, get_prompt


def message(text: str = "{}", *, stop_reason: str = "end_turn", model: str = "fake-model",
            input_tokens: int = 100, output_tokens: int = 20, cache_read: int = 0, cache_write: int = 0) -> Any:
    """A response shaped like ``anthropic.types.Message``."""
    return SimpleNamespace(
        id="msg_fake", model=model, stop_reason=stop_reason, content=[SimpleNamespace(type="text", text=text)],
        usage=SimpleNamespace(input_tokens=input_tokens, output_tokens=output_tokens,
                              cache_creation_input_tokens=cache_write, cache_read_input_tokens=cache_read))


@dataclass
class FakeAnthropicSDK:
    """``responses`` are returned in order; an exception instance is raised instead of returned."""

    responses: list[Any]
    calls: list[dict[str, Any]] = field(default_factory=list)

    def __post_init__(self) -> None:
        self.messages = SimpleNamespace(create=self._create)

    async def _create(self, **arguments: Any) -> Any:
        self.calls.append(arguments)
        if not self.responses:
            raise AssertionError("no scripted response left")
        response = self.responses.pop(0)
        if isinstance(response, BaseException):
            raise response
        return response


Script = Mapping[str, Callable[[Mapping[str, Any]], dict[str, Any]] | dict[str, Any]]


@dataclass
class FakeLLMClient:
    script: Script
    model: str = "fake-model"
    calls: list[tuple[str, dict[str, Any]]] = field(default_factory=list)

    async def structured(self, prompt_id: str, data: Mapping[str, Any], *, ledger: Ledger | None = None,
                         call_key: str | None = None, effort: Effort | None = None) -> LLMResult:
        prompt = get_prompt(prompt_id)
        framed = frame(data, nonce="0" * 16)                 # same identifier checks as a live call
        self.calls.append((prompt_id, dict(data)))
        if ledger is not None:
            ledger.check_available()
        answer = self.script[prompt_id]
        output = answer(data) if callable(answer) else answer
        text = json.dumps(output, ensure_ascii=False)
        record = UsageRecord(model=self.model, prompt_id=prompt.id, prompt_version=prompt.version,
                             prompt_sha256=prompt.sha256, effort=effort or prompt.meta.effort,
                             thinking=prompt.meta.thinking, attempt=1,
                             input_tokens=(len(prompt.system) + len(framed.text)) // 4, output_tokens=len(text) // 4,
                             cache_creation_input_tokens=0, cache_read_input_tokens=0, stop_reason="end_turn",
                             latency_ms=0, request_id=None, call_key=call_key)
        if ledger is not None:
            ledger.charge(record)
        try:
            return LLMResult(validate_output(prompt, text), (record,), self.model, prompt.identity())
        except OutputProblem as problem:
            raise LLMOutputInvalid(f"{prompt_id}: scripted output is invalid: {problem}") from None
