"""What the source layer returns: one record per retrieved item, with the provenance §12 requires.

A :class:`SourceRecord` is the normalized form of one provider record (``kind``/``title``/``reference``/``text`` map
to the contract ``Source``). ``parts`` keeps every provider that contributed and in which role, so evidence that
combines an authority with capability data (canonical verse + Quran Foundation audio) is never collapsed into a
single attribution (D-89).
"""

from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass, field
from datetime import UTC, datetime
from typing import Any, Literal

Role = Literal["text_authority", "translation", "explanation", "grade", "metadata", "audio", "timing", "search"]


def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def canonical_json(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


@dataclass(frozen=True)
class Part:
    """One contributing provider record."""

    role: Role
    provider: str                     # contract provider id, or an internal id such as ``mushaf``
    record_id: str
    version: str | None = None        # adapter version, dataset version or translation version
    sha256: str | None = None         # of the response payload (or the dataset file)
    checks: tuple[str, ...] = ()      # cross-checks this part passed
    meta: dict[str, Any] = field(default_factory=dict)

    def as_dict(self) -> dict[str, Any]:
        out: dict[str, Any] = {"role": self.role, "provider": self.provider, "record_id": self.record_id}
        for key in ("version", "sha256"):
            if getattr(self, key) is not None:
                out[key] = getattr(self, key)
        if self.checks:
            out["checks"] = list(self.checks)
        if self.meta:
            out["meta"] = self.meta
        return out


@dataclass(frozen=True)
class Retrieval:
    """The exact request and response behind a record (what ``sources.raw`` stores)."""

    tool: str
    operation: str
    arguments: dict[str, Any]
    response: Any
    response_sha256: str
    retrieved_at: datetime

    def as_dict(self) -> dict[str, Any]:
        return {"request": {"tool": self.tool, "operation": self.operation, "arguments": self.arguments},
                "response_sha256": self.response_sha256, "response": self.response,
                "retrieved_at": self.retrieved_at.isoformat()}


@dataclass(frozen=True)
class SourceRecord:
    provider: str                     # contract ``Provider`` the row is attributed to
    provider_record_id: str
    kind: str                         # contract ``SourceKind``
    title: str
    reference: str
    text: str                         # the exact text a citation would quote
    url: str | None
    adapter_version: str
    retrieval: Retrieval
    parts: tuple[Part, ...]
    data: dict[str, Any] = field(default_factory=dict)   # normalized provider fields (grade, narrator, …)

    @property
    def text_sha256(self) -> str:
        return sha256_text(self.text)

    @property
    def retrieved_at(self) -> datetime:
        return self.retrieval.retrieved_at

    def raw(self) -> dict[str, Any]:
        """The ``sources.raw`` document (docs/SOURCE_POLICY.md §5)."""
        return {"schema": "qabas.source_raw/1", "provider": self.provider,
                "provider_record_id": self.provider_record_id, "adapter_version": self.adapter_version,
                "text_sha256": self.text_sha256, **self.retrieval.as_dict(),
                "parts": [p.as_dict() for p in self.parts], "data": self.data}


def utcnow() -> datetime:
    return datetime.now(UTC)
