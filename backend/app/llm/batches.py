"""Message Batches for noninteractive evaluations, sharing Phase 11 policy/framing/schema/accounting.

Checkpoint batch IDs before polling. Callers supply a durable private checkpoint map and callback: recovery
retrieves the submitted batch instead of paying twice. A transport ambiguity during submission is recorded by
the caller for operator reconciliation, never blindly retried. No case/golden IDs are sent to the provider.
"""
from __future__ import annotations

import asyncio
import dataclasses
import time
from collections.abc import Awaitable, Callable
from dataclasses import dataclass
from typing import Any

from app.llm.budget import Ledger
from app.llm.client import AnthropicClient, LLMResult, OutputProblem, request_arguments, validate_output
from app.llm.errors import (
    BudgetExceeded,
    LLMError,
    LLMNotConfigured,
    LLMOutputInvalid,
    LLMRefusal,
    LLMRequestRejected,
    LLMTruncated,
    LLMUnavailable,
)
from app.llm.framing import frame
from app.llm.models import model_policy
from app.llm.prompts import get_prompt
from app.llm.vision import VisionImage
from app.sources.records import canonical_json, sha256_text


@dataclass(frozen=True)
class Request:
    key: str
    prompt: str
    data: dict[str, Any]
    images: tuple[VisionImage, ...] = ()


class Batches:
    def __init__(self, client: AnthropicClient, *, poll_seconds: float = 5, deadline_seconds: float = 86400) -> None:
        self.client, self.poll_seconds, self.deadline_seconds = client, poll_seconds, deadline_seconds

    async def run(self, requests: list[Request], ledger: Ledger, checkpoints: dict[str, Any],
                  save: Callable[[], Awaitable[None]], *, retry: bool = True
                  ) -> dict[str, LLMResult | LLMError]:
        if not requests or len(requests) > 200 or len({r.key for r in requests}) != len(requests):
            raise ValueError("batch requires 1-200 unique requests")
        fingerprint = sha256_text(canonical_json([{"key": r.key, "prompt": get_prompt(r.prompt).identity(),
            "data": r.data, "images": [i.sha256 for i in r.images]} for r in requests]))
        prepared: list[dict[str, Any]] = []
        owners, reservation = {}, 0
        sdk: Any = self.client.sdk
        for index, request in enumerate(requests):
            prompt, framed = get_prompt(request.prompt), frame(request.data)
            model = self.client.model_for(prompt)
            policy = model_policy(model, self.client.settings)
            arguments = request_arguments(prompt, policy, model,
                [{"type": "text", "text": prompt.system}, {"type": "text", "text": framed.instruction}],
                [{"role": "user", "content": [*(i.block() for i in request.images),
                                                {"type": "text", "text": framed.text}]}], None)
            custom_id = f"{fingerprint[:24]}-{index}"
            prepared.append({"custom_id": custom_id, "params": arguments})
            owners[custom_id] = (request, prompt, arguments)
            # Conservative preflight reservation; exact provider usage is still charged for every result.
            reservation += prompt.meta.max_tokens + len((prompt.system + framed.text).encode()) + \
                sum(len(i.data) * 2 for i in request.images)
        previous = checkpoints.get(fingerprint)
        if previous is None:
            ledger.check_available()
            if ledger.budget_tokens is not None and ledger.tokens + reservation > ledger.budget_tokens:
                raise BudgetExceeded("batch worst-case reservation exceeds the evaluation budget")
            checkpoints[fingerprint] = {"state": "submitting"}
            await save()
            try:
                batch = await sdk.messages.batches.create(requests=prepared)
            except Exception:
                raise LLMUnavailable("batch submission outcome is ambiguous; reconcile before retrying") from None
            previous = {"state": "submitted", "id": batch.id, "started": time.time()}
            checkpoints[fingerprint] = previous
            await save()
        if previous.get("state") == "submitting":
            raise LLMUnavailable("unfinished batch submission requires operator reconciliation")
        if previous.get("state") == "completed":
            # Cached results are private structured outputs, not provider-side prompt caching.
            return {key: LLMResult(value["data"], (), value["model"], value["prompt"])
                    if "data" in value else {"LLMRefusal": LLMRefusal, "LLMTruncated": LLMTruncated,
                        "LLMOutputInvalid": LLMOutputInvalid}.get(value["error"], LLMUnavailable)(value["error"])
                    for key, value in previous["results"].items()}
        started = self.client.clock()
        results: dict[str, LLMResult | LLMError] = {}
        corrections = []
        try:
            async with asyncio.timeout(max(0, self.deadline_seconds - (time.time() - previous["started"]))):
                while True:
                    status = await sdk.messages.batches.retrieve(previous["id"])
                    if status.processing_status == "ended":
                        break
                    await asyncio.sleep(self.poll_seconds)
                async for item in await sdk.messages.batches.results(previous["id"]):
                    if item.custom_id not in owners:
                        raise LLMOutputInvalid("unexpected batch result identity")
                    request, prompt, arguments = owners[item.custom_id]
                    if request.key in results:
                        raise LLMOutputInvalid("duplicate batch result identity")
                    if item.result.type != "succeeded":
                        results[request.key] = LLMUnavailable(f"batch request {item.result.type}")
                        continue
                    response = item.result.message
                    usage = dataclasses.replace(self.client._record(prompt, response, arguments, 1,
                        started, f"{fingerprint}:{request.key}"), pricing_mode="batch")
                    if not any(r.call_key == usage.call_key and r.request_id == usage.request_id
                               for r in ledger.records):
                        try:
                            ledger.charge(usage)
                        finally:
                            await save()  # recovery preserves paid usage even when the budget was exceeded
                    if response.stop_reason == "refusal":
                        results[request.key] = LLMRefusal("batch model refused")
                        continue
                    if response.stop_reason in ("max_tokens", "model_context_window_exceeded"):
                        results[request.key] = LLMTruncated("batch output truncated")
                        continue
                    try:
                        data = validate_output(prompt, "".join(b.text for b in response.content if b.type == "text"))
                        results[request.key] = LLMResult(data, (usage,), str(response.model), prompt.identity())
                    except OutputProblem as exc:
                        results[request.key] = LLMOutputInvalid("batch output failed registered schema")
                        if retry:
                            corrections.append(dataclasses.replace(request, data=request.data |
                                {"validation_error": str(exc), "instruction": "Return complete schema-valid JSON."}))
        except TimeoutError:
            raise LLMUnavailable("evaluation batch deadline exceeded; existing batch ID is preserved") from None
        except LLMError:
            raise
        except Exception as exc:
            import anthropic

            if isinstance(exc, (anthropic.AuthenticationError, anthropic.PermissionDeniedError)):
                raise LLMNotConfigured("batch provider refused configured credentials") from None
            if isinstance(exc, anthropic.APIStatusError) and 400 <= exc.status_code < 500 and \
                    exc.status_code != 429:
                raise LLMRequestRejected("batch provider rejected the request") from None
            if isinstance(exc, (anthropic.APIConnectionError, anthropic.APIStatusError)):
                raise LLMUnavailable("batch provider unavailable; existing batch ID is preserved") from None
            raise  # local defects are not mislabeled as provider outages
        for request in requests:
            results.setdefault(request.key, LLMUnavailable("batch result is missing"))
        if corrections:
            results.update(await self.run(corrections, ledger, checkpoints, save, retry=False))
        previous["state"], previous["results"] = "completed", {
            key: {"data": value.data, "model": value.model, "prompt": value.prompt}
                 if isinstance(value, LLMResult) else {"error": type(value).__name__}
            for key, value in results.items()}
        await save()
        return results
