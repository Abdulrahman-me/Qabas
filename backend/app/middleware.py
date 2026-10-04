"""HTTP middleware: request IDs, request logging and contract identity (API §3.2).

Contract identity rules (decision D-15 for the cases the spec leaves open):
* every response carries ``Qabas-Contract: <server revision>``;
* a missing or non-integer ``Qabas-Contract``, or one below ``MIN_CLIENT_CONTRACT``, is a client
  older than revision 10 and gets ``426 client_outdated``;
* a missing ``Qabas-Client`` also gets ``426``; a malformed one (not ``<android|ios|web>/<semver>``)
  is a client bug and gets ``400 validation_error``; an app version below ``MIN_APP_VERSION`` gets ``426``.
Operational paths (health, OpenAPI document, local media links) are exempt.
"""

from __future__ import annotations

import logging
import re
import time
import uuid
from collections.abc import Awaitable, Callable

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response
from starlette.types import ASGIApp

from app.config import Settings
from app.errors import ErrorCode, error_response
from app.logs import redact_query

log = logging.getLogger("qabas.request")

EXEMPT_PREFIXES = ("/health", "/openapi.json", "/docs", "/redoc", "/media/", "/private/")
CLIENT_RE = re.compile(r"^(android|ios|web)/(\d+)\.(\d+)\.(\d+)(?:[-+][0-9A-Za-z.\-+]*)?$")
SEMVER_RE = re.compile(r"^(\d+)\.(\d+)\.(\d+)")


def parse_semver(value: str) -> tuple[int, int, int]:
    match = SEMVER_RE.match(value)
    if not match:
        raise ValueError(f"not a semantic version: {value!r}")
    major, minor, patch = (int(g) for g in match.groups())
    return major, minor, patch


class ContractIdentityMiddleware(BaseHTTPMiddleware):
    def __init__(self, app: ASGIApp, settings: Settings) -> None:
        super().__init__(app)
        self.revision = str(settings.contract_revision)
        self.min_contract = settings.min_client_contract
        self.min_app_version = settings.min_app_version
        self.min_app = parse_semver(settings.min_app_version)

    def _outdated(self) -> Response:
        return error_response(
            ErrorCode.client_outdated,
            "This app version is no longer supported. Please update.",
            {"min_contract": self.min_contract, "min_app_version": self.min_app_version},
        )

    def _check(self, request: Request) -> Response | None:
        if request.method == "OPTIONS" or request.url.path.startswith(EXEMPT_PREFIXES):
            return None
        raw = request.headers.get("qabas-contract", "").strip()
        if not raw.isdigit() or int(raw) < self.min_contract:
            return self._outdated()
        client = request.headers.get("qabas-client")
        if client is None:
            return self._outdated()
        match = CLIENT_RE.match(client.strip())
        if not match:
            return error_response(ErrorCode.validation_error,
                                  "Qabas-Client must be <android|ios|web>/<semantic version>.",
                                  {"field": "Qabas-Client"})
        version = (int(match.group(2)), int(match.group(3)), int(match.group(4)))
        if version < self.min_app:
            return self._outdated()
        return None

    async def dispatch(self, request: Request, call_next: Callable[[Request], Awaitable[Response]]) -> Response:
        response = self._check(request) or await call_next(request)
        response.headers["Qabas-Contract"] = self.revision
        return response


class RequestContextMiddleware(BaseHTTPMiddleware):
    """Assigns a request ID and logs one redacted line per request."""

    async def dispatch(self, request: Request, call_next: Callable[[Request], Awaitable[Response]]) -> Response:
        request_id = request.headers.get("x-request-id") or uuid.uuid4().hex
        if not re.fullmatch(r"[0-9A-Za-z\-]{8,64}", request_id):
            request_id = uuid.uuid4().hex
        request.state.request_id = request_id
        started = time.perf_counter()
        status = 500
        try:
            response = await call_next(request)
            status = response.status_code
            response.headers["X-Request-ID"] = request_id
            return response
        finally:
            log.info("request", extra={
                "request_id": request_id,
                "method": request.method,
                "path": request.url.path,
                "query": redact_query(request.url.query),
                "status": status,
                "duration_ms": round((time.perf_counter() - started) * 1000, 1),
            })
