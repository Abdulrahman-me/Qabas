"""Association MCP discovery nominates record IDs; authority adapters fetch the actual content (D-96).

The real tool/argument/result mapping is still pending O-03. No guessed endpoint or tool name is shipped.
An operator-installed stdio bridge may connect the approved association server. Search responses are never
citable and are not cached or persisted with the learner's query.
"""

from __future__ import annotations

import json
import re
from typing import Any

from app.config import Settings
from app.sources.errors import ProviderNotConfigured, ProviderResponseInvalid, UpstreamUnavailable
from app.sources.mcp import StdioMcp
from app.sources.policy import ProviderPolicy, policy
from app.sources.records import canonical_json, sha256_text
from app.sources.resilience import RetryPolicy, breaker_for


class AssociationDiscovery:
    def __init__(self, provider: str, settings: Settings, *, client: Any = None,
                 provider_policy: ProviderPolicy | None = None, retry: RetryPolicy | None = None) -> None:
        if provider not in ("islamhouse", "hadeethenc"):
            raise ValueError("association discovery supports only IslamHouse and HadeethEnc")
        self.provider, self.settings, self.client = provider, settings, client
        self.policy = provider_policy or policy(provider)
        self.retry = retry or RetryPolicy()
        self.breaker = breaker_for(f"association:{provider}")
        self.last_sha256: str | None = None

    def configured(self) -> dict[str, Any]:
        self.policy.require_live(self.settings)
        policy("islamiccontent_mcp").require_live(self.settings)
        mapping = self.policy.option("discovery") or {}
        if mapping.get("status") != "confirmed" or not mapping.get("confirmed_by"):
            raise ProviderNotConfigured(self.provider, "association MCP discovery schemas are pending (O-03/D-96)")
        if not all(isinstance(mapping.get(k), str) and mapping[k] for k in ("name", "results_key", "id_key")) or \
                not isinstance(mapping.get("arguments"), dict) or set(mapping["arguments"]) != {"query", "language"}:
            raise ProviderNotConfigured(self.provider, "incomplete discovery mapping")
        if self.client is None:
            try:
                command = json.loads(self.settings.association_mcp_command or "null")
            except ValueError:
                raise ProviderNotConfigured(self.provider, "association command must be JSON argv") from None
            if not isinstance(command, list) or not command or not all(isinstance(s, str) and s for s in command):
                raise ProviderNotConfigured(self.provider, "approved association stdio bridge is not installed")
            self.client = StdioMcp(self.provider, command)
        return dict(mapping)

    def parse(self, response: Any, spec: dict[str, Any]) -> list[str]:
        if not isinstance(response, dict) or response.get("isError"):
            raise ProviderResponseInvalid(self.provider, "discovery tool failed")
        payload = response.get("structuredContent")
        if payload is None:
            blocks = response.get("content")
            if not isinstance(blocks, list) or len(blocks) != 1 or not isinstance(blocks[0], dict) or \
                    blocks[0].get("type") != "text":
                raise ProviderResponseInvalid(self.provider, "ambiguous discovery response")
            try:
                payload = json.loads(blocks[0]["text"])
            except (ValueError, KeyError):
                raise ProviderResponseInvalid(self.provider, "invalid discovery JSON") from None
        hits = payload.get(spec["results_key"]) if isinstance(payload, dict) else None
        if not isinstance(hits, list) or len(hits) > 100:
            raise ProviderResponseInvalid(self.provider, "invalid discovery results")
        ids = []
        for hit in hits:
            value = hit.get(spec["id_key"]) if isinstance(hit, dict) else None
            if not isinstance(value, (str, int)) or isinstance(value, bool) or not re.fullmatch(
                    r"[0-9A-Za-z_-]{1,100}", str(value)):
                raise ProviderResponseInvalid(self.provider, "invalid discovered record ID")
            ids.append(str(value))
        return list(dict.fromkeys(ids))[:5]

    async def search(self, query: str, language: str) -> list[str]:
        spec = self.configured()
        arguments = {spec["arguments"]["query"]: query, spec["arguments"]["language"]: language}
        self.breaker.before_call()
        try:
            for attempt in range(self.retry.retries + 1):
                if attempt:
                    await self.retry.sleep(self.retry.delay(attempt - 1))
                try:
                    response = await self.client.call(spec["name"], arguments)
                    result = self.parse(response, spec)
                    self.last_sha256 = sha256_text(canonical_json(response))
                except UpstreamUnavailable:
                    if attempt == self.retry.retries:
                        raise
                    continue
                self.breaker.record_success()
                return result
            raise AssertionError("retry loop did not return")
        except UpstreamUnavailable:
            self.breaker.record_failure()
            raise
        finally:
            self.breaker.trial_in_flight = False

    async def aclose(self) -> None:
        if self.client is not None:
            await self.client.aclose()
