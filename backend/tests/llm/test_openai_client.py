"""Deterministic Responses transport checks; no live account or private evaluation data."""
from __future__ import annotations

import json
from typing import Any

import httpx
import pytest
from pydantic import SecretStr

from app.config import Environment, Settings
from app.llm.budget import Ledger
from app.llm.errors import BudgetExceeded, LLMNotConfigured, LLMOutputInvalid, LLMRefusal, LLMTruncated
from app.llm.factory_client import factory_client
from app.llm.openai_client import OpenAIClient


def response(text: str = '{"title":"A neutral title"}', *, status: str = "completed",
             refusal: bool = False) -> dict[str, Any]:
    block = {"type": "refusal", "refusal": "declined"} if refusal else {"type": "output_text", "text": text}
    return {"id": "synthetic-response", "model": "gpt-6.1-sol", "status": status,
            "usage": {"input_tokens": 100, "output_tokens": 20,
                      "input_tokens_details": {"cached_tokens": 40}},
            "output": [{"type": "message", "content": [block]}]}


def adapter(settings: Settings, replies: list[dict[str, Any]]) -> tuple[OpenAIClient, list[dict[str, Any]]]:
    calls: list[dict[str, Any]] = []

    def handle(request: httpx.Request) -> httpx.Response:
        calls.append(json.loads(request.content))
        return httpx.Response(200, json=replies.pop(0))

    selected = settings.model_copy(update={"openai_api_key": SecretStr("synthetic-not-a-secret")})
    return OpenAIClient(selected, model="gpt-6.1-sol", transport=httpx.MockTransport(handle)), calls


async def test_strict_output_framing_usage_and_no_provider_storage(settings: Settings) -> None:
    client, calls = adapter(settings, [response()])
    ledger = Ledger()
    try:
        result = await client.structured("conversation_title", {"language": "en", "question": "neutral"}, ledger=ledger)
    finally:
        await client.aclose()
    assert result.data == {"title": "A neutral title"}
    assert calls[0]["store"] is False and calls[0]["text"]["format"]["strict"] is True
    assert calls[0]["reasoning"]["effort"] == "low"
    assert "data-" in calls[0]["input"][0]["content"][0]["text"]
    assert ledger.tokens == 120 and ledger.records[0].input_tokens == 60
    assert ledger.records[0].cache_read_input_tokens == 40


@pytest.mark.parametrize(("reply", "error"), [(response(status="incomplete"), LLMTruncated),
                                               (response(refusal=True), LLMRefusal)])
async def test_stop_classification_and_paid_usage(settings: Settings, reply: dict[str, Any],
                                                  error: type[Exception]) -> None:
    client, calls = adapter(settings, [reply])
    ledger = Ledger()
    try:
        with pytest.raises(error):
            await client.structured("conversation_title", {"language": "ar", "question": "neutral"}, ledger=ledger)
        assert len(calls) == 1 and ledger.tokens == 120
    finally:
        await client.aclose()


async def test_corrective_retry_is_bounded_and_charged(settings: Settings) -> None:
    client, calls = adapter(settings, [response("{}"), response("{}")])
    ledger = Ledger()
    try:
        with pytest.raises(LLMOutputInvalid):
            await client.structured("conversation_title", {"language": "en", "question": "neutral"}, ledger=ledger)
        assert len(calls) == 2 and ledger.tokens == 240
    finally:
        await client.aclose()


async def test_budget_stops_before_second_call(settings: Settings) -> None:
    client, calls = adapter(settings, [response()])
    try:
        with pytest.raises(BudgetExceeded):
            await client.structured("conversation_title", {"question": "neutral"}, ledger=Ledger(budget_tokens=100))
        assert len(calls) == 1
    finally:
        await client.aclose()


def test_explicit_routing_and_pending_production_gate(settings: Settings) -> None:
    selected = settings.model_copy(update={"factory_llm_model": "gpt-6.1-sol",
                                           "openai_api_key": SecretStr("synthetic")})
    assert isinstance(factory_client(selected), OpenAIClient)
    with pytest.raises(LLMNotConfigured, match="O-03"):
        OpenAIClient(selected.model_copy(update={"app_env": Environment.production}), model="gpt-6.1-sol")
