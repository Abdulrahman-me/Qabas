"""Tafsir stdio MCP adapter. Actual server/tool mappings remain an O-03 approval gate.

The adapter's normalized record schema is tested against a fake server. It makes no claim about the
undelivered server's tool names. Mapping and argument schemas must be confirmed before production use.
"""

from __future__ import annotations

import asyncio
import json
from typing import Any, ClassVar

from app.config import Settings
from app.sources.errors import ProviderNotConfigured, ProviderResponseInvalid, RecordNotFound, UpstreamUnavailable
from app.sources.mcp import StdioMcp
from app.sources.providers.base import Adapter, Fetched, require
from app.sources.records import Part, SourceRecord, canonical_json, sha256_text
from app.sources.resilience import CircuitBreaker, RetryPolicy, breaker_for

BOOKS = frozenset({"mukhtasar", "saadi", "ibn_kathir", "tabari", "baghawi", "muyassar"})


class TafsirCenter(Adapter):
    provider: ClassVar[str] = "tafsir_center"
    version: ClassVar[str] = "tafsir_center/1"
    tools: ClassVar[frozenset[str]] = frozenset({"get", "asbab"})

    def __init__(self, settings: Settings, *, client: StdioMcp | None = None,
                 breaker: CircuitBreaker | None = None, retry: RetryPolicy | None = None, **kwargs: Any) -> None:
        super().__init__(settings, **kwargs)
        self.client = client
        self.breaker, self.retry = breaker or breaker_for(self.provider), retry or RetryPolicy()

    def _configured(self) -> dict[str, Any]:
        mapping = self.policy.option("tools") or {}
        if mapping.get("status") != "confirmed":
            raise ProviderNotConfigured(self.provider, "MCP tool mapping is pending (O-03)")
        if self.client is None:
            try:
                command = json.loads(self.settings.tafsir_mcp_command or "null")
            except ValueError as exc:
                raise ProviderNotConfigured(self.provider, "TAFSIR_MCP_COMMAND must be a JSON argv array") from exc
            if not isinstance(command, list) or not command or not all(
                    isinstance(item, str) and item for item in command):
                raise ProviderNotConfigured(self.provider, "TAFSIR_MCP_COMMAND must be a JSON argv array (O-03)")
            self.client = StdioMcp(self.provider, command)
        return dict(mapping)

    async def aclose(self) -> None:
        if self.client is not None:
            await self.client.aclose()

    def _payload(self, response: Any, arguments: dict[str, Any]) -> dict[str, Any]:
        if not isinstance(response, dict) or response.get("isError"):
            raise ProviderResponseInvalid(self.provider, "MCP tool failed")
        payload = response.get("structuredContent")
        if payload is None:
            content = require(self.provider, response, "content", list)
            if len(content) != 1 or not isinstance(content[0], dict) or content[0].get("type") != "text":
                raise ProviderResponseInvalid(self.provider, "MCP tool has no unambiguous JSON record")
            try:
                payload = json.loads(require(self.provider, content[0], "text"))
            except ValueError as exc:
                raise ProviderResponseInvalid(self.provider, "MCP tool text is not a JSON record") from exc
        if isinstance(payload, dict) and payload.get("status") == "not_found":
            raise RecordNotFound(self.provider, "no matching tafsir record")
        for key in ("surah", "ayah", "book"):
            if payload is None or not isinstance(payload, dict) or payload.get(key) != arguments[key]:
                raise ProviderResponseInvalid(self.provider, "MCP record identity differs from request")
        for field in ("id", "text", "title", "reference"):
            require(self.provider, payload, field)
        return dict(payload)

    async def _lookup(self, operation: str, arguments: dict[str, Any]) -> SourceRecord:
        self.policy.require_live(self.settings)
        mapping = self._configured()
        spec = mapping.get(operation)
        if not isinstance(spec, dict) or not isinstance(spec.get("name"), str):
            raise ProviderNotConfigured(self.provider, "operation mapping is missing (O-03)")
        names = spec.get("arguments")
        expected = set(arguments) - ({"book"} if operation == "asbab" else set())
        if not isinstance(names, dict) or set(names) != expected or not all(isinstance(v, str) for v in names.values()):
            raise ProviderNotConfigured(self.provider, "argument mapping is missing (O-03)")
        fetched = await self.cached(operation, arguments)
        if fetched is None:
            self.breaker.before_call()
            try:
                for attempt in range(self.retry.retries + 1):
                    if attempt:
                        await self.retry.sleep(self.retry.delay(attempt - 1))
                    try:
                        assert self.client is not None
                        response = await self.client.call(spec["name"], {v: arguments[k] for k, v in names.items()})
                        self._payload(response, arguments)
                    except (ProviderResponseInvalid, RecordNotFound):
                        raise
                    except UpstreamUnavailable:
                        if attempt == self.retry.retries:
                            raise
                        continue
                    fetched = Fetched(response, sha256_text(canonical_json(response)), self.clock(), False)
                    break
            except RecordNotFound:
                self.breaker.record_success()
                raise
            except UpstreamUnavailable:
                self.breaker.record_failure()
                raise
            except asyncio.CancelledError:
                self.breaker.trial_in_flight = False
                raise
            self.breaker.record_success()
            assert fetched is not None
            await self.remember(operation, arguments, fetched)
        payload = self._payload(fetched.data, arguments)
        return SourceRecord(self.provider, payload["id"], "tafsir", payload["title"], payload["reference"],
                            payload["text"], payload.get("url"), self.version,
                            self.retrieval(operation, arguments, fetched),
                            (Part("explanation", self.provider, payload["id"], version=payload.get("version"),
                                  sha256=fetched.sha256),), {**arguments, "server_tool": spec["name"]})

    async def get(self, surah: int, ayah: int, book: str = "mukhtasar") -> SourceRecord:
        if book not in BOOKS or not 1 <= surah <= 114 or ayah < 1:
            raise ValueError("unsupported tafsir book or verse reference")
        return await self._lookup("get", {"surah": surah, "ayah": ayah, "book": book})

    async def asbab(self, surah: int, ayah: int) -> SourceRecord:
        if not 1 <= surah <= 114 or ayah < 1:
            raise ValueError("invalid verse reference")
        return await self._lookup("asbab", {"surah": surah, "ayah": ayah, "book": "asbab"})
