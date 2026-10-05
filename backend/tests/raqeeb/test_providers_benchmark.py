from __future__ import annotations

import copy
import uuid
from datetime import UTC, datetime

import pytest
import yaml
from pydantic import SecretStr
from sqlalchemy import func, select, text
from sqlalchemy.exc import DBAPIError

from app.config import Environment, Settings
from app.contract import models as C
from app.llm.errors import LLMNotConfigured
from app.models import BenchmarkRun
from app.raqeeb import benchmark, policy, suggestions
from app.raqeeb.embedding_cli import approved
from app.raqeeb.providers import HostedClient
from app.sources.discovery import AssociationDiscovery
from app.sources.errors import ProviderNotConfigured, ProviderResponseInvalid
from app.sources.policy import policy as source_policy
from app.sources.resilience import RetryPolicy


class Mcp:
    def __init__(self, output):
        self.output = output
        self.calls = []

    async def call(self, name, args):
        self.calls.append((name, args))
        return self.output

    async def aclose(self):
        pass


def discovery(client):
    base = source_policy("islamhouse")
    spec = base.model_copy(update={"discovery": {"status": "confirmed", "confirmed_by": "synthetic tests",
        "name": "synthetic_search", "arguments": {"query": "q", "language": "lang"},
        "results_key": "hits", "id_key": "id"}})
    # Extra-field updates must be represented as the real parsed policy, rather than a Pydantic copy bypass.
    from app.sources.policy import ProviderPolicy
    spec = ProviderPolicy.model_validate(base.model_dump() | {"discovery": spec.discovery})
    return AssociationDiscovery("islamhouse", Settings(app_env=Environment.test), client=client,
        provider_policy=spec, retry=RetryPolicy(retries=0))


async def test_association_discovery_only_nominates_ids():
    client = Mcp({"structuredContent": {"hits": [{"id": 1, "text": "untrusted invented scripture"}, {"id": 1}]}})
    adapter = discovery(client)
    assert await adapter.search("question", "en") == ["1"]
    assert client.calls == [("synthetic_search", {"q": "question", "lang": "en"})]
    assert adapter.policy.cache_ttl_seconds == 0


@pytest.mark.parametrize("output", [{"isError": True}, {"structuredContent": {"hits": "wrong"}},
    {"structuredContent": {"hits": [{"id": "../../evil"}]}}, {"content": [None]}])
async def test_discovery_malformed_is_outage_not_not_found(output):
    with pytest.raises(ProviderResponseInvalid):
        await discovery(Mcp(output)).search("question", "en")


async def test_discovery_pending_mapping_and_production_provider_gate():
    with pytest.raises(ProviderNotConfigured):
        await AssociationDiscovery("islamhouse", Settings(app_env=Environment.test), client=Mcp({})).search("q", "en")
    production = Settings(app_env=Environment.production, auth_token_pepper=SecretStr("test"),
                          storage_signing_key=SecretStr("test"))
    with pytest.raises(ProviderNotConfigured):
        await AssociationDiscovery("islamhouse", production, client=Mcp({})).search("q", "en")


async def test_o09_blocks_hosted_questions_before_model_client_creation():
    settings = Settings(app_env=Environment.production, auth_token_pepper=SecretStr("test"),
                         storage_signing_key=SecretStr("test"))
    client = HostedClient(settings)
    with pytest.raises(LLMNotConfigured, match="O-09"):
        await client.structured("raqeeb_classify", {"question": "private question"})
    assert client.client is None


def test_policy_has_real_authority_and_no_invented_support_addresses():
    rules, referrals = policy.load()
    assert len(rules["labels"]) == 8
    for lang in ("ar", "en"):
        assert referrals["types"]["fatwa_authority"][lang]["targets"][0]["url"] == "https://www.alifta.gov.sa"
        assert all(t["contact"] is None for t in referrals["types"]["human_support"][lang]["targets"])


def test_cosine_threshold_and_invalid_vectors():
    assert suggestions.cosine([1, 0], [.6, .8]) == .6
    assert suggestions.cosine([1, 0], [.599, .801]) < .6
    assert suggestions.cosine([0, 0], [1, 0]) == 0
    with pytest.raises(ValueError):
        suggestions.cosine([1], [1, 0])
    with pytest.raises(ValueError):
        suggestions.cosine([float("nan")], [1])


async def test_no_embedding_model_never_downloads_or_fabricates_chips():
    with pytest.raises(ProviderNotConfigured):
        await suggestions.LocalBge(Settings(raqeeb_embedding_model_dir=None)).encode(["question"])


def test_embedding_artifact_requires_approval_and_all_digests(tmp_path):
    with pytest.raises(ProviderNotConfigured):
        approved(tmp_path)
    (tmp_path / "config.json").write_text("synthetic model config", encoding="utf-8")
    from app.sources.records import sha256_text
    manifest = {"model": "BAAI/bge-m3", "status": "approved", "approved_by": "synthetic tests",
        "approved_on": "2026-10-05", "report": "synthetic", "revision": "synthetic", "licence": "synthetic",
        "files": {"config.json": sha256_text("synthetic model config")}}
    (tmp_path / "qabas-model.yaml").write_text(yaml.safe_dump(manifest), encoding="utf-8")
    assert approved(tmp_path)["model"] == "BAAI/bge-m3"
    (tmp_path / "config.json").write_text("changed", encoding="utf-8")
    with pytest.raises(ProviderNotConfigured, match="digest"):
        approved(tmp_path)


def results():
    return {"run_at": datetime.now(UTC).isoformat(), "question_count": 60,
        "systems": [{"name": name, "accuracy_percent": 0, "unsupported_claim_rate_percent": 0,
                     "correct_abstention_percent": 0, "correct_referral_percent": 0}
                    for name in ("raqeeb", "baseline_llm")],
        "by_class": [{"question_class": c, "raqeeb_accuracy_percent": 0, "baseline_accuracy_percent": 0}
                     for c in C.QuestionClass.__args__]}


def provenance():
    return benchmark.Provenance(dataset_sha256="a" * 64, adversarial_sha256="b" * 64, policy_version="synthetic/1",
        prompt_versions={"synthetic": "1"}, adapter_versions={"synthetic": "1"},
        models={"raqeeb_strong": "fake", "baseline_llm": "fake"}, language_counts={"ar": 30, "en": 30},
        adversarial_count=20, manual_review_count=20, judge_agreement_percent=0, manual_report_sha256="c" * 64,
        mode="cold", latency_p50_ms=0, latency_p95_ms=0, cost_usd=None, false_memory_reuse=0)


@pytest.mark.integration
async def test_benchmark_append_only_replay_metrics_and_no_synthetic_leak(resources):
    data, meta, run_id = results(), provenance(), uuid.uuid4()
    async with resources.sessionmaker() as db, db.begin():
        assert await benchmark.record(db, resources.settings, run_id, data, meta, synthetic=True)
        assert not await benchmark.record(db, resources.settings, run_id, data, meta, synthetic=True)
        assert await benchmark.latest(db) is None
    async with resources.sessionmaker() as db:
        with pytest.raises(ValueError, match="different results"):
            async with db.begin():
                changed = copy.deepcopy(data)
                changed["systems"][0]["accuracy_percent"] = 10
                await benchmark.record(db, resources.settings, run_id, changed, meta, synthetic=True)
    async with resources.sessionmaker() as db:
        with pytest.raises(DBAPIError):
            async with db.begin():
                await db.execute(text("UPDATE benchmark_runs SET question_count = 1 WHERE id=:id"), {"id": run_id})
    async with resources.sessionmaker() as db, db.begin():
        assert await db.scalar(select(func.count()).select_from(BenchmarkRun)) == 1
        # Explicit public stand-in for a non-synthetic row, in the isolated test DB only. No release result claimed.
        await benchmark.record(db, resources.settings, uuid.uuid4(), data, meta, synthetic=False)
        from app.services.metrics import metrics
        assert (await metrics(db, "en"))["raqeeb_benchmark"] == data
    async with resources.sessionmaker() as db:
        assert await benchmark.latest(db) == data  # projection rebuild is a read of authoritative rows


@pytest.mark.integration
@pytest.mark.parametrize("change", ["count", "classes", "languages", "adversarial", "manual", "model", "percent"])
async def test_real_benchmark_composition_checks(resources, change):
    data, meta = results(), provenance()
    if change == "count":
        data["question_count"] = 59
    elif change == "classes":
        data["by_class"].pop()
    elif change == "languages":
        meta.language_counts = {"ar": 60}
    elif change == "adversarial":
        meta.adversarial_count = 19
    elif change == "manual":
        meta.manual_review_count = 19
    elif change == "model":
        meta.models["baseline_llm"] = "different"
    else:
        data["systems"][0]["accuracy_percent"] = 101
    async with resources.sessionmaker() as db, db.begin():
        with pytest.raises(ValueError):
            await benchmark.record(db, resources.settings, uuid.uuid4(), data, meta)
