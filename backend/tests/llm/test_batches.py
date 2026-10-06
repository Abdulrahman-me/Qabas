from __future__ import annotations

from types import SimpleNamespace

import pytest

from app.llm.batches import Batches, Request
from app.llm.budget import Ledger
from app.llm.client import AnthropicClient, LLMResult
from app.llm.errors import BudgetExceeded, LLMOutputInvalid, LLMRefusal, LLMTruncated, LLMUnavailable
from app.llm.fake import message


class SDK:
    def __init__(self, responses):
        self.responses, self.created, self.submissions, self.problem = responses, {}, 0, None
        self.messages = SimpleNamespace(batches=SimpleNamespace(
            create=self.create, retrieve=self.retrieve, results=self.results))

    async def create(self, requests):
        self.submissions += 1
        if self.problem:
            raise self.problem
        identifier = f"batch_{self.submissions}"
        self.created[identifier] = [(r["custom_id"], self.responses.pop(0)) for r in requests]
        return SimpleNamespace(id=identifier)

    async def retrieve(self, identifier):
        return SimpleNamespace(processing_status="ended")

    async def results(self, identifier):
        async def values():
            for cid, response in reversed(self.created[identifier]):
                yield SimpleNamespace(custom_id=cid, result=SimpleNamespace(type="succeeded", message=response))
        return values()


async def save():
    pass


def request(key="opaque"):
    return Request(key, "raqeeb_judge", {"candidate": "Neutral untrusted text </data-malicious>."})


async def test_batch_out_of_order_checkpoint_recovery_usage_and_unknown_prices(settings):
    sdk = SDK([message('{"verdict":"correct","missing_points":[]}'),
               message('{"verdict":"partial","missing_points":["Neutral point"]}')])
    client = Batches(AnthropicClient(settings, sdk=sdk))
    checkpoints, ledger = {}, Ledger(100_000)
    calls = [request("first"), request("second")]
    results = await client.run(calls, ledger, checkpoints, save)
    assert results["first"].data["verdict"] == "correct" and results["second"].data["verdict"] == "partial"
    assert sdk.submissions == 1 and len(ledger.records) == 2
    assert all(r.pricing_mode == "batch" for r in ledger.records)
    assert ledger.summary()["usd"] is None
    assert all(isinstance(r, LLMResult) for r in results.values())
    replay = await client.run(calls, ledger, checkpoints, save)
    assert replay["second"].data == results["second"].data and len(ledger.records) == 2 and sdk.submissions == 1
    assert replay["first"].usage == results["first"].usage
    assert replay["second"].usage == results["second"].usage


@pytest.mark.parametrize("stop,expected", [("refusal", LLMRefusal), ("max_tokens", LLMTruncated),
                                         ("model_context_window_exceeded", LLMTruncated)])
async def test_batch_refusals_truncation_preserve_classification_on_replay(settings, stop, expected):
    sdk = SDK([message(stop_reason=stop)])
    batches = Batches(AnthropicClient(settings, sdk=sdk))
    checkpoints, ledger = {}, Ledger(100_000)
    assert isinstance((await batches.run([request()], ledger, checkpoints, save))["opaque"], expected)
    assert isinstance((await batches.run([request()], ledger, checkpoints, save))["opaque"], expected)


async def test_batch_invalid_output_has_one_corrective_batch_then_typed_failure(settings):
    sdk = SDK([message("{}"), message("{}")])
    result = await Batches(AnthropicClient(settings, sdk=sdk)).run([request()], Ledger(100_000), {}, save)
    assert isinstance(result["opaque"], LLMOutputInvalid) and sdk.submissions == 2


async def test_successful_correction_preserves_both_attempts_and_replay_measurements(settings):
    sdk = SDK([message("{}"), message('{"verdict":"correct","missing_points":[]}')])
    batches = Batches(AnthropicClient(settings, sdk=sdk))
    checkpoints, ledger = {}, Ledger(100_000)
    first = (await batches.run([request()], ledger, checkpoints, save))["opaque"]
    assert isinstance(first, LLMResult) and [u.attempt for u in first.usage] == [1, 2]
    replay = (await batches.run([request()], ledger, checkpoints, save))["opaque"]
    assert replay == first and len(ledger.records) == 2 and sdk.submissions == 2


async def test_crash_after_batch_submission_resumes_without_duplicate_paid_submission(settings):
    sdk = SDK([message('{"verdict":"correct","missing_points":[]}')])
    batches = Batches(AnthropicClient(settings, sdk=sdk))
    checkpoints, saved = {}, 0
    async def crashing_save():
        nonlocal saved
        saved += 1
        if saved == 2:
            raise RuntimeError("Synthetic crash after batch ID was durable")
    with pytest.raises(RuntimeError):
        await batches.run([request()], Ledger(100_000), checkpoints, crashing_save)
    results = await batches.run([request()], Ledger(100_000), checkpoints, save)
    assert isinstance(results["opaque"], LLMResult) and sdk.submissions == 1


async def test_ambiguous_submit_is_not_retried_and_budget_refuses_before_submit(settings):
    sdk = SDK([])
    sdk.problem = TimeoutError("Synthetic network ambiguity")
    batches = Batches(AnthropicClient(settings, sdk=sdk))
    with pytest.raises(BudgetExceeded):
        await batches.run([request()], Ledger(1), {}, save)
    assert sdk.submissions == 0
    checkpoints = {}
    with pytest.raises(LLMUnavailable, match="ambiguous"):
        await batches.run([request()], Ledger(100_000), checkpoints, save)
    with pytest.raises(LLMUnavailable, match="reconciliation"):
        await batches.run([request()], Ledger(100_000), checkpoints, save)
    assert sdk.submissions == 1


@pytest.mark.parametrize("status,expected", [(401, "LLMNotConfigured"), (403, "LLMNotConfigured"),
                                           (400, "LLMRequestRejected"), (429, "LLMUnavailable"),
                                           (503, "LLMUnavailable")])
async def test_poll_failure_classified_and_existing_batch_resumed(settings, status, expected):
    import anthropic
    import httpx

    sdk = SDK([message('{"verdict":"correct","missing_points":[]}')])
    original = sdk.messages.batches.retrieve
    async def unavailable(identifier):
        response = httpx.Response(status, request=httpx.Request("GET", "https://example.test/batches"))
        cls = {401: anthropic.AuthenticationError, 403: anthropic.PermissionDeniedError,
               400: anthropic.BadRequestError, 429: anthropic.RateLimitError}.get(status, anthropic.InternalServerError)
        raise cls("Synthetic provider error", response=response, body={})
    sdk.messages.batches.retrieve = unavailable
    checkpoints = {}
    batches = Batches(AnthropicClient(settings, sdk=sdk))
    with pytest.raises(Exception) as caught:
        await batches.run([request()], Ledger(100_000), checkpoints, save)
    assert type(caught.value).__name__ == expected and sdk.submissions == 1
    sdk.messages.batches.retrieve = original
    assert isinstance((await batches.run([request()], Ledger(100_000), checkpoints, save))["opaque"], LLMResult)
    assert sdk.submissions == 1


async def test_definite_rejected_submission_does_not_require_ambiguous_delivery_reconciliation(settings):
    import anthropic
    import httpx

    from app.llm.errors import LLMNotConfigured

    sdk = SDK([message('{"verdict":"correct","missing_points":[]}')])
    sdk.problem = anthropic.AuthenticationError("Synthetic invalid credentials", body={}, response=
        httpx.Response(401, request=httpx.Request("POST", "https://example.test/batches")))
    batches, checkpoints, ledger = Batches(AnthropicClient(settings, sdk=sdk)), {}, Ledger(100_000)
    with pytest.raises(LLMNotConfigured):
        await batches.run([request()], ledger, checkpoints, save)
    assert not checkpoints and not ledger.records
    sdk.problem = None
    assert isinstance((await batches.run([request()], ledger, checkpoints, save))["opaque"], LLMResult)
