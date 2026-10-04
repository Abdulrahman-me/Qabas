"""Common adapter behaviour: policy gate, cache, retrieval provenance and the allow-listed tool dispatcher."""

from __future__ import annotations

from collections.abc import Callable, Mapping
from dataclasses import dataclass
from datetime import datetime
from typing import Any, ClassVar

from app.config import Settings
from app.sources.cache import CachedResponse, SourceCache
from app.sources.errors import OperationUnsupported, ProviderResponseInvalid
from app.sources.policy import ProviderPolicy, policy
from app.sources.records import Retrieval, SourceRecord, canonical_json, sha256_bytes, sha256_text, utcnow
from app.sources.resilience import ProviderHttp, Response


@dataclass(frozen=True)
class Fetched:
    data: Any
    sha256: str
    retrieved_at: datetime
    cached: bool


class Adapter:
    """One provider. ``tools`` is the allow-list of record-returning operations the pipeline may call (§12)."""

    provider: ClassVar[str]
    version: ClassVar[str]
    tools: ClassVar[frozenset[str]] = frozenset()

    def __init__(self, settings: Settings, *, cache: SourceCache | None = None,
                 clock: Callable[[], datetime] = utcnow, provider_policy: ProviderPolicy | None = None) -> None:
        self.settings = settings
        self.cache = cache
        self.clock = clock
        self.policy = provider_policy or policy(self.provider)

    async def call(self, operation: str, **arguments: Any) -> list[SourceRecord]:
        """Dispatch an allow-listed tool call; anything else is refused (tool calls never come from content)."""
        if operation not in self.tools:
            raise OperationUnsupported(self.provider, f"{operation!r} is not an allow-listed tool")
        result = await getattr(self, operation)(**arguments)
        return list(result) if isinstance(result, list) else [result]

    async def aclose(self) -> None:
        return None

    def tool(self, operation: str) -> str:
        return f"{self.provider}.{operation}"

    def retrieval(self, operation: str, arguments: dict[str, Any], fetched: Fetched) -> Retrieval:
        return Retrieval(self.tool(operation), operation, arguments, fetched.data, fetched.sha256,
                         fetched.retrieved_at)

    async def cached(self, operation: str, arguments: dict[str, Any]) -> Fetched | None:
        if self.cache is None:
            return None
        hit = await self.cache.get(self.tool(operation), self.version, arguments, self.policy.cache_ttl_seconds)
        return None if hit is None else Fetched(hit.data, hit.sha256, hit.retrieved_at, True)

    async def remember(self, operation: str, arguments: dict[str, Any], fetched: Fetched) -> None:
        if self.cache is not None and not fetched.cached:
            await self.cache.put(self.tool(operation), self.version, arguments, self.policy.cache_ttl_seconds,
                                 CachedResponse(fetched.data, fetched.sha256, fetched.retrieved_at))


class HttpAdapter(Adapter):
    def __init__(self, settings: Settings, http: ProviderHttp, **kwargs: Any) -> None:
        super().__init__(settings, **kwargs)
        self.http = http

    async def aclose(self) -> None:
        await self.http.aclose()

    async def fetch(self, operation: str, arguments: dict[str, Any], path: str,
                    params: Mapping[str, Any] | None = None, *, headers: Mapping[str, str] | None = None) -> Fetched:
        """Cache first (only where the provider's terms allow), then the live provider (only where O-03 allows)."""
        hit = await self.cached(operation, arguments)
        if hit is not None:
            self.validate_response(operation, arguments, hit.data)
            return hit
        self.policy.require_live(self.settings)
        response = await self.request_json(operation, arguments, path, params, headers)
        fetched = Fetched(self.safe_response(response.data), sha256_bytes(response.body), self.clock(), False)
        await self.remember(operation, arguments, fetched)
        return fetched

    async def request_json(self, operation: str, arguments: dict[str, Any], path: str,
                           params: Mapping[str, Any] | None, headers: Mapping[str, str] | None) -> Response:
        return await self.http.get_json(path, params,
                                       headers={**(headers or {}), **(await self.auth_headers() or {})},
                                       validate=lambda data: self.validate_response(operation, arguments, data))

    def safe_response(self, data: Any) -> Any:
        return data

    async def auth_headers(self) -> dict[str, str] | None:
        return None

    def validate_response(self, operation: str, arguments: dict[str, Any], data: Any) -> None:
        """Validate documented payloads before caching or counting an upstream call as healthy."""
        if not isinstance(data, dict):
            raise ProviderResponseInvalid(self.provider, "response must be an object")


def combine(parts: Mapping[str, Fetched]) -> Fetched:
    """Several responses behind one record: the payloads by name, the digest over their individual digests."""
    data = {name: f.data for name, f in parts.items()}
    digest = sha256_text(canonical_json({name: f.sha256 for name, f in parts.items()}))
    return Fetched(data, digest, max(f.retrieved_at for f in parts.values()), all(f.cached for f in parts.values()))


def require(provider: str, data: Any, key: str, kind: type | tuple[type, ...] = str) -> Any:
    """A documented field, or ProviderResponseInvalid (the response is treated as an outage, never as data)."""
    if not isinstance(data, dict) or key not in data or not isinstance(data[key], kind):
        raise ProviderResponseInvalid(provider, f"missing or malformed field {key!r}")
    value = data[key]
    if isinstance(value, str) and not value.strip():
        raise ProviderResponseInvalid(provider, f"empty field {key!r}")
    return value
