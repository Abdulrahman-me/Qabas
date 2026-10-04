"""Source-layer failures. Callers map them to outcomes: an outage is never reported as "not found", and "not found"
is never reported as "fabricated" (SOURCE_ADAPTERS §12; backend §9.3)."""

from __future__ import annotations


class SourceError(RuntimeError):
    provider: str = ""

    def __init__(self, provider: str, message: str) -> None:
        super().__init__(f"{provider}: {message}")
        self.provider = provider


class UpstreamUnavailable(SourceError):
    """Timeout, transport failure, 429/5xx after retries, or an open circuit (API ``upstream_unavailable``)."""


class ProviderResponseInvalid(UpstreamUnavailable):
    """The provider answered with something that is not the documented shape. Treated as an outage, not as data."""


class ProviderNotConfigured(SourceError):
    """Credentials or live approval (O-03) are missing for this environment."""


class OperationUnsupported(SourceError):
    """The provider has no such capability (e.g. text search on an API without one, D-96)."""


class RecordNotFound(SourceError):
    """The provider answered and has no record for this request (a definite "no match")."""


class CapabilityMismatch(SourceError):
    """Capability data disagrees with the authority (verse text, word count, timings); it is dropped, never fixed."""


class SourceChanged(SourceError):
    """A provider now returns different text for a record already stored and cited; a reviewer must re-verify."""
