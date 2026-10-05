"""The model-calling adapter against an SDK-shaped fake (no network): request shape, stop reasons, validation with
one corrective retry, error classification, data rules, the O-03 production gate and spend accounting."""

from __future__ import annotations

import json
import logging
from typing import Any

import anthropic
import httpx
import pytest
from pydantic import SecretStr

from app.config import Environment, Settings
from app.llm.budget import Ledger
from app.llm.client import FORBIDDEN_PARAMETERS, AnthropicClient, provider_schema
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
from app.llm.fake import FakeAnthropicSDK, message
from app.llm.prompts import get_prompt

DATA = {"language": "en", "question": "Why do Muslims fast during Ramadan?"}
GOOD = json.dumps({"title": "Fasting in Ramadan"})


def client(settings: Settings, *responses: Any, **overrides: Any) -> tuple[AnthropicClient, FakeAnthropicSDK]:
    sdk = FakeAnthropicSDK(list(responses))
    return AnthropicClient(settings.model_copy(update=overrides), sdk=sdk), sdk


def status_error(kind: type[anthropic.APIStatusError], status: int) -> anthropic.APIStatusError:
    request = httpx.Request("POST", "https://api.anthropic.com/v1/messages")
    return kind("error", response=httpx.Response(status, request=request), body=None)


async def test_request_shape_follows_the_calling_rules(settings: Settings) -> None:
    adapter, sdk = client(settings, message(GOOD, model="claude-haiku-4-5"))
    result = await adapter.structured("conversation_title", DATA)
    assert result.data == {"title": "Fasting in Ramadan"} and result.model == "claude-haiku-4-5"
    (call,) = sdk.calls
    prompt = get_prompt("conversation_title")
    assert call["model"] == settings.llm_model_fast and call["max_tokens"] == prompt.meta.max_tokens
    assert call["output_config"] == {"format": {"type": "json_schema", "schema": provider_schema(prompt.schema)}}
    assert not FORBIDDEN_PARAMETERS & call.keys() and "thinking" not in call
    assert call["system"][0] == {"type": "text", "text": prompt.system, "cache_control": {"type": "ephemeral"}}
    tag = call["system"][1]["text"].split("<", 1)[1].split(" ", 1)[0]
    assert tag.startswith("data-") and f'<{tag} name="question">' in call["messages"][0]["content"]
    assert result.prompt["prompt_version"] == prompt.version and result.prompt["prompt_sha256"] == prompt.sha256
    (usage,) = result.usage
    assert usage.effort is None and usage.attempt == 1 and usage.tokens == 120 and usage.prompt_id == prompt.id


async def test_effort_is_explicit_where_the_model_declares_it(settings: Settings) -> None:
    adapter, sdk = client(settings, message(GOOD), llm_model_fast="claude-opus-5-5")
    result = await adapter.structured("conversation_title", DATA)
    assert sdk.calls[0]["output_config"]["effort"] == "low" and result.usage[0].effort == "low"
    adapter, sdk = client(settings, message(GOOD), llm_model_fast="claude-opus-5-5")
    await adapter.structured("conversation_title", DATA, effort="high")
    assert sdk.calls[0]["output_config"]["effort"] == "high"


@pytest.mark.parametrize(("stop", "error"), [("refusal", LLMRefusal), ("max_tokens", LLMTruncated),
                                             ("model_context_window_exceeded", LLMTruncated)])
async def test_stop_reason_is_checked_before_content_and_never_retried(settings: Settings, stop: str,
                                                                      error: type[Exception]) -> None:
    adapter, sdk = client(settings, message(GOOD, stop_reason=stop), message(GOOD))
    ledger = Ledger()
    with pytest.raises(error):
        await adapter.structured("conversation_title", DATA, ledger=ledger)
    assert len(sdk.calls) == 1 and len(ledger.records) == 1 and ledger.records[0].stop_reason == stop


@pytest.mark.parametrize("first", ["not json", "[]", json.dumps({"title": 7}),
                                   json.dumps({"title": "x", "extra": 1}), ""])
async def test_invalid_output_is_corrected_once_with_the_error_appended(settings: Settings, first: str) -> None:
    adapter, sdk = client(settings, message(first), message(GOOD))
    result = await adapter.structured("conversation_title", DATA)
    assert result.data["title"] == "Fasting in Ramadan" and [u.attempt for u in result.usage] == [1, 2]
    retry = sdk.calls[1]["messages"]
    assert retry[0] == sdk.calls[0]["messages"][0] and retry[1]["role"] == "assistant"
    assert retry[2]["role"] == "user" and "did not validate" in retry[2]["content"]


async def test_invalid_output_twice_fails_the_call(settings: Settings) -> None:
    adapter, sdk = client(settings, message("{}"), message(json.dumps({"title": None})))
    with pytest.raises(LLMOutputInvalid):
        await adapter.structured("conversation_title", DATA)
    assert len(sdk.calls) == 2


@pytest.mark.parametrize(("raised", "error"), [
    (status_error(anthropic.RateLimitError, 429), LLMUnavailable),
    (status_error(anthropic.InternalServerError, 500), LLMUnavailable),
    (status_error(anthropic.APIStatusError, 529), LLMUnavailable),
    (anthropic.APITimeoutError(request=httpx.Request("POST", "https://api.anthropic.com")), LLMUnavailable),
    (anthropic.APIConnectionError(request=httpx.Request("POST", "https://api.anthropic.com")), LLMUnavailable),
    (status_error(anthropic.BadRequestError, 400), LLMRequestRejected),
    (status_error(anthropic.AuthenticationError, 401), LLMNotConfigured),
    (status_error(anthropic.PermissionDeniedError, 403), LLMNotConfigured),
])
async def test_provider_failures_are_classified(settings: Settings, raised: Exception, error: type[Exception]) -> None:
    adapter, _ = client(settings, raised)
    with pytest.raises(error):
        await adapter.structured("conversation_title", DATA)


@pytest.mark.parametrize("data", [{"language": "en", "question": "user usr_01J9ZX4ABCDE asked"},
                                  {"language": "en", "user_id": "x", "question": "q"},
                                  {"language": "en", "context": {"email": "a@b.c"}, "question": "q"}])
async def test_learner_identifiers_never_reach_the_provider(settings: Settings, data: dict[str, Any]) -> None:
    adapter, sdk = client(settings, message(GOOD))
    with pytest.raises(UnsafePromptData):
        await adapter.structured("conversation_title", data)
    assert sdk.calls == []


async def test_models_are_gated_by_policy(settings: Settings) -> None:
    production = Settings(_env_file=None, app_env=Environment.production, anthropic_api_key=SecretStr("k"),
                          auth_token_pepper=SecretStr("test-pepper-" * 4), storage_signing_key=SecretStr("s"))
    adapter, sdk = client(production, message(GOOD))
    with pytest.raises(LLMNotConfigured, match="O-03"):
        await adapter.structured("conversation_title", DATA)
    adapter, sdk = client(settings, message(GOOD), llm_model_fast="some-unlisted-model")
    with pytest.raises(LLMNotConfigured, match=r"models\.yaml"):
        await adapter.structured("conversation_title", DATA)
    assert sdk.calls == []
    with pytest.raises(LLMNotConfigured, match="ANTHROPIC_API_KEY"):
        AnthropicClient(settings.model_copy(update={"anthropic_api_key": None}))
    with pytest.raises(LLMNotConfigured, match="unknown prompt"):
        await client(settings)[0].structured("no_such_prompt", DATA)


async def test_budget_stops_the_run_and_still_records_the_paid_call(settings: Settings) -> None:
    ledger = Ledger(budget_tokens=100)
    adapter, sdk = client(settings, message(GOOD, input_tokens=90, output_tokens=30), message(GOOD))
    with pytest.raises(BudgetExceeded):
        await adapter.structured("conversation_title", DATA, ledger=ledger, call_key="run_1:plan:1")
    assert ledger.tokens == 120 and ledger.records[0].call_key == "run_1:plan:1"
    with pytest.raises(BudgetExceeded):
        await adapter.structured("conversation_title", DATA, ledger=ledger)
    assert len(sdk.calls) == 1                                      # refused before calling again


async def test_logs_carry_metadata_only(settings: Settings, caplog: pytest.LogCaptureFixture) -> None:
    caplog.set_level(logging.INFO, logger="qabas.llm")
    adapter, _ = client(settings, message(GOOD))
    await adapter.structured("conversation_title", DATA)
    (record,) = [r for r in caplog.records if r.name == "qabas.llm"]
    assert record.prompt_id == "conversation_title" and record.output_tokens == 20     # type: ignore[attr-defined]
    everything = caplog.text + " ".join(str(v) for v in vars(record).values())
    assert "Ramadan" not in everything and "Fasting" not in everything
