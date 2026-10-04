"""Quran Foundation capabilities, with scoped OAuth tokens kept only in process memory.

Verse text/search results are discovery or cross-check data. Scripture insertion uses the pinned mushaf.
Translations are selected through QuranEnc (D-93), not this adapter. Search uses the Search API and its own
scope, never the retired public v4 endpoint. One 401 may refresh OAuth; 403 and other 4xx are not retried.
"""

from __future__ import annotations

import asyncio
import time
from collections.abc import Mapping
from typing import Any, ClassVar

import httpx

from app.config import Settings
from app.sources.errors import (
    AuthenticationRejected,
    OperationUnsupported,
    ProviderNotConfigured,
    ProviderResponseInvalid,
)
from app.sources.providers.base import Fetched, HttpAdapter, require
from app.sources.records import Part, SourceRecord
from app.sources.resilience import ProviderHttp, Response


class QuranFoundation(HttpAdapter):
    provider: ClassVar[str] = "quran_com"
    version: ClassVar[str] = "quran_foundation/1"
    tools: ClassVar[frozenset[str]] = frozenset({"get", "audio", "reciters", "search", "translation"})

    def __init__(self, settings: Settings, http: ProviderHttp, *, oauth: ProviderHttp,
                 search_http: ProviderHttp, **kwargs: Any) -> None:
        super().__init__(settings, http, **kwargs)
        self.oauth, self.search_http = oauth, search_http
        self._tokens: dict[str, tuple[str, float]] = {}
        self._token_lock = asyncio.Lock()

    @classmethod
    def create(cls, settings: Settings, **kwargs: Any) -> QuranFoundation:
        transport = kwargs.pop("transport", None)
        return cls(settings, ProviderHttp(cls.provider, settings.quran_foundation_api_base, transport=transport),
                   oauth=ProviderHttp(cls.provider, settings.quran_foundation_auth_url, transport=transport),
                   search_http=ProviderHttp(cls.provider, settings.quran_foundation_search_base, transport=transport),
                   **kwargs)

    async def aclose(self) -> None:
        self._tokens.clear()
        await self.http.aclose()
        await self.oauth.aclose()
        await self.search_http.aclose()

    async def _token(self, scope: str, rejected: str | None = None) -> str:
        async with self._token_lock:
            current = self._tokens.get(scope)
            if current and current[1] > time.monotonic() and current[0] != rejected:
                return current[0]
            client_id, secret = self.settings.quran_foundation_client_id, self.settings.quran_foundation_client_secret
            if not client_id or not secret:
                raise ProviderNotConfigured(self.provider, "OAuth client credentials are missing (O-03)")

            def validate(data: Any) -> None:
                require(self.provider, data, "access_token")
                if require(self.provider, data, "token_type").lower() != "bearer":
                    raise ProviderResponseInvalid(self.provider, "unsupported OAuth token type")
                ttl = require(self.provider, data, "expires_in", (int, float))
                if isinstance(ttl, bool) or ttl <= 0:
                    raise ProviderResponseInvalid(self.provider, "invalid OAuth token lifetime")

            response = await self.oauth.request("POST", "", auth=httpx.BasicAuth(client_id, secret.get_secret_value()),
                                                data={"grant_type": "client_credentials", "scope": scope},
                                                validate=validate)
            token = str(response.data["access_token"])
            ttl = float(response.data["expires_in"])
            self._tokens[scope] = (token, time.monotonic() + max(0, ttl - min(30, ttl / 10)))
            return token

    async def request_json(self, operation: str, arguments: dict[str, Any], path: str,
                           params: Mapping[str, Any] | None, headers: Mapping[str, str] | None) -> Response:
        scope = "search" if operation == "search" else "content"
        http = self.search_http if operation == "search" else self.http
        token = await self._token(scope)

        async def request(value: str) -> Response:
            auth_headers = {**(headers or {}), "x-auth-token": value,
                            "x-client-id": str(self.settings.quran_foundation_client_id)}
            return await http.get_json(path, params, headers=auth_headers,
                                       validate=lambda data: self.validate_response(operation, arguments, data))

        try:
            return await request(token)
        except AuthenticationRejected:
            return await request(await self._token(scope, rejected=token))

    def validate_response(self, operation: str, arguments: dict[str, Any], data: Any) -> None:
        if operation == "search":
            result = require(self.provider, data, "result", dict)
            entries = require(self.provider, result, "verses", list)
            for entry in entries:
                require(self.provider, entry, "key")
                require(self.provider, entry, "name")
        elif operation == "reciters":
            for entry in require(self.provider, data, "recitations", list):
                require(self.provider, entry, "id", int)
                require(self.provider, entry, "reciter_name")
        else:
            verse = require(self.provider, data, "verse", dict)
            if verse.get("verse_key") != arguments["verse_key"]:
                raise ProviderResponseInvalid(self.provider, "verse identity differs from request")
            require(self.provider, verse, "text_qpc_hafs")
            require(self.provider, verse, "words", list)

    def _record(self, operation: str, arguments: dict[str, Any], fetched: Fetched, record_id: str,
                text: str, parts: tuple[Part, ...], data: dict[str, Any]) -> SourceRecord:
        return SourceRecord(self.provider, record_id, "quran", "Quran Foundation", record_id, text,
                            f"https://quran.com/{record_id.split('@')[0]}", self.version,
                            self.retrieval(operation, arguments, fetched), parts, data)

    async def get(self, surah: int, ayah: int, reciter_id: int | None = None) -> SourceRecord:
        key = f"{surah}:{ayah}"
        arguments = {"verse_key": key, "reciter_id": reciter_id}
        params: dict[str, Any] = {"words": "true", "fields": "text_qpc_hafs", "word_fields": "text_qpc_hafs"}
        if reciter_id is not None:
            params["audio"] = reciter_id
        fetched = await self.fetch("get", arguments, f"/verses/by_key/{key}", params)
        verse = fetched.data["verse"]
        parts = [Part("metadata", self.provider, key, sha256=fetched.sha256)]
        if isinstance(verse.get("audio"), dict):
            parts.extend(Part(role, self.provider, f"{key}@{reciter_id}", sha256=fetched.sha256)
                         for role in ("audio", "timing"))
        return self._record("get", arguments, fetched, f"{key}@{reciter_id}", verse["text_qpc_hafs"],
                            tuple(parts), {"verse_key": key, "words": verse["words"], "audio": verse.get("audio"),
                                           "reciter_id": reciter_id})

    async def audio(self, surah: int, ayah: int, reciter_id: int) -> SourceRecord:
        return await self.get(surah, ayah, reciter_id)

    async def reciters(self, language: str = "ar") -> list[SourceRecord]:
        arguments = {"language": language}
        fetched = await self.fetch("reciters", arguments, "/resources/recitations", arguments)
        return [self._record("reciters", arguments, fetched, f"reciter:{item['id']}", item["reciter_name"],
                             (Part("metadata", self.provider, str(item["id"]), sha256=fetched.sha256),), item)
                for item in fetched.data["recitations"]]

    async def search(self, query: str, page: int = 1, size: int = 20) -> list[SourceRecord]:
        arguments = {"query": query, "page": page, "size": size}
        fetched = await self.fetch("search", arguments, "/api/v1/search",
                                   {**arguments, "mode": "advanced", "get_text": "1", "highlight": "0"})
        return [self._record("search", arguments, fetched, entry["key"], entry.get("arabic") or entry["name"],
                             (Part("search", self.provider, entry["key"], sha256=fetched.sha256),), entry)
                for entry in fetched.data["result"]["verses"] if entry.get("result_type") == "ayah"]

    async def translation(self, **arguments: Any) -> SourceRecord:
        raise OperationUnsupported(self.provider, "translations are selected through QuranEnc (D-93)")
