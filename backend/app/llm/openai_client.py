"""OpenAI Responses transport implementing the Phase 11 structured-call protocol.

Shared prompt/framing/schema/ledger controls remain authoritative. No religious retrieval,
tool execution, provider approval or publication is performed here. Responses are not stored.
"""
from __future__ import annotations

import asyncio
import json
import logging
import random
import time
from collections.abc import Mapping
from typing import Any

import httpx

from app.config import Settings
from app.llm.budget import Ledger, UsageRecord
from app.llm.client import CORRECTION, LLMResult, OutputProblem, provider_schema, validate_output
from app.llm.errors import (
    LLMNotConfigured,
    LLMOutputInvalid,
    LLMRefusal,
    LLMRequestRejected,
    LLMTruncated,
    LLMUnavailable,
    UnsafePromptData,
)
from app.llm.framing import frame
from app.llm.models import model_policy
from app.llm.prompts import Effort, get_prompt
from app.llm.vision import VisionImage

log = logging.getLogger("qabas.llm")


class OpenAIClient:
    def __init__(self, settings: Settings, *, model: str,
                 transport: httpx.AsyncBaseTransport | None = None) -> None:
        self.settings, self.model = settings, model
        policy = model_policy(model, settings)
        if policy.provider != "openai":
            raise LLMNotConfigured("selected model is not an OpenAI model")
        if not settings.openai_api_key or not settings.openai_api_key.get_secret_value():
            raise LLMNotConfigured("OPENAI_API_KEY is not configured")
        self.http = httpx.AsyncClient(base_url="https://api.openai.com/v1/", transport=transport,
            headers={"Authorization": f"Bearer {settings.openai_api_key.get_secret_value()}"},
            timeout=httpx.Timeout(settings.llm_timeout_seconds, connect=5), follow_redirects=False)

    async def aclose(self) -> None:
        await self.http.aclose()

    async def available(self) -> bool:
        """Read-only exact-ID check; it does not confer model/terms/release approval."""
        try:
            response = await self.http.get(f"models/{self.model}")
        except httpx.TransportError:
            raise LLMUnavailable("OpenAI model catalogue is unavailable") from None
        if response.status_code != 200:
            raise LLMNotConfigured("the configured account cannot retrieve the requested model ID")
        try:
            value = response.json()
            return bool(isinstance(value, dict) and value.get("id") == self.model)
        except ValueError:
            raise LLMUnavailable("OpenAI model catalogue returned malformed JSON") from None

    async def _request(self, arguments: dict[str, Any]) -> dict[str, Any]:
        for attempt in range(self.settings.llm_max_retries + 1):
            if attempt:
                await asyncio.sleep(random.uniform(0, 2 ** (attempt - 1)))  # noqa: S311
            try:
                async with self.http.stream("POST", "responses", json=arguments) as response:
                    data = bytearray()
                    async for chunk in response.aiter_bytes():
                        data.extend(chunk)
                        if len(data) > 8_000_000:
                            raise LLMUnavailable("model response exceeds the byte limit")
                    status = response.status_code
            except httpx.TransportError:
                continue
            if status == 429 or status >= 500:
                continue
            if status in (401, 403):
                raise LLMNotConfigured("OpenAI rejected account authentication or model access")
            if status != 200:
                raise LLMRequestRejected(f"OpenAI rejected the structured request (HTTP {status})")
            try:
                value = json.loads(data)
                if not isinstance(value, dict):
                    raise ValueError
                return value
            except (ValueError, TypeError):
                raise LLMUnavailable("OpenAI returned a malformed response envelope") from None
        raise LLMUnavailable("OpenAI is temporarily unavailable")

    async def structured(self, prompt_id: str, data: Mapping[str, Any], *, ledger: Ledger | None = None,
                         call_key: str | None = None, effort: Effort | None = None,
                         images: tuple[VisionImage, ...] = ()) -> LLMResult:
        prompt = get_prompt(prompt_id)
        policy = model_policy(self.model, self.settings)
        framed = frame(data)
        level = effort or prompt.meta.effort
        if not policy.capabilities.effort or level not in policy.capabilities.effort:
            raise LLMNotConfigured("requested reasoning effort is not declared for this model")
        if len(images) > 20:
            raise UnsafePromptData("too many vision images")
        content: list[dict[str, Any]] = [{"type": "input_text", "text": framed.text}]
        for image in images:
            source = image.block()["source"]  # shares decoded MIME/size/dimension validation
            content.append({"type": "input_image", "image_url":
                            f"data:{source['media_type']};base64,{source['data']}"})
        arguments: dict[str, Any] = {"model": self.model, "store": False,
            "instructions": prompt.system + "\n" + framed.instruction,
            "input": [{"role": "user", "content": content}],
            "reasoning": {"effort": level}, "max_output_tokens": prompt.meta.max_tokens,
            "text": {"format": {"type": "json_schema", "name": prompt.id,
                                "strict": True, "schema": provider_schema(prompt.schema)}}}
        records = []
        for attempt in (1, 2):
            if ledger is not None:
                ledger.check_available()
            started = time.monotonic()
            result = await self._request(arguments)
            usage = result.get("usage")
            if not isinstance(usage, dict):
                raise LLMUnavailable("model usage metadata is missing")
            try:
                total_input, output = int(usage["input_tokens"]), int(usage["output_tokens"])
                cached = int(usage.get("input_tokens_details", {}).get("cached_tokens", 0))
                if not 0 <= cached <= total_input or output < 0:
                    raise ValueError
            except (ValueError, TypeError, KeyError, AttributeError):
                raise LLMUnavailable("model usage metadata is malformed") from None
            record = UsageRecord(model=str(result.get("model", self.model)), prompt_id=prompt.id,
                prompt_version=prompt.version, prompt_sha256=prompt.sha256, effort=level, thinking="reasoning",
                attempt=attempt, input_tokens=total_input - cached, output_tokens=output,
                cache_creation_input_tokens=0, cache_read_input_tokens=cached,
                stop_reason=str(result.get("status")), latency_ms=int((time.monotonic() - started) * 1000),
                request_id=result.get("id"), call_key=call_key)
            records.append(record)
            if ledger is not None:
                ledger.charge(record)
            log.info("llm call", extra={"prompt_id": prompt.id, "model": record.model,
                                       "attempt": attempt, "latency_ms": record.latency_ms,
                                       "input_tokens": total_input, "output_tokens": output})
            if result.get("status") == "incomplete":
                raise LLMTruncated("OpenAI structured output was incomplete")
            try:
                items = result["output"]
                if not isinstance(items, list) or any(not isinstance(item, dict) for item in items):
                    raise ValueError
                blocks = [block for item in items if item.get("type") == "message"
                          for block in item.get("content", [])]
                if any(not isinstance(b, dict) or (b.get("type") == "output_text" and
                        not isinstance(b.get("text"), str)) for b in blocks):
                    raise ValueError
            except (ValueError, TypeError, KeyError):
                raise LLMUnavailable("OpenAI output envelope is malformed") from None
            if any(b.get("type") == "refusal" for b in blocks):
                raise LLMRefusal("OpenAI refused the request")
            if result.get("status") != "completed":
                raise LLMUnavailable("OpenAI response did not complete")
            text = "".join(b.get("text", "") for b in blocks if b.get("type") == "output_text")
            try:
                return LLMResult(validate_output(prompt, text), tuple(records), record.model, prompt.identity())
            except OutputProblem as problem:
                if attempt == 2:
                    raise LLMOutputInvalid(f"{prompt.id}: output failed validation twice") from None
                arguments["input"].append({"role": "user", "content": [{"type": "input_text",
                    "text": CORRECTION.format(error=str(problem))}]})
        raise LLMOutputInvalid("structured call failed")
