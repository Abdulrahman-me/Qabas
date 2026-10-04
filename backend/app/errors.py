"""Error envelope (API §3.4): every non-2xx response is ``{"error": {code, message, details}}``.

Responses are built through the contract's ``ErrorEnvelope`` model so the shape can't drift.
Validation errors never echo submitted input (it may be learner text or an answer).
"""

from __future__ import annotations

import logging
from enum import StrEnum
from typing import Any

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.contract import models

log = logging.getLogger("qabas.errors")


class ErrorCode(StrEnum):
    """Codes from the API §3.4 table. Adding one is a contract change."""

    validation_error = "validation_error"
    unauthorized = "unauthorized"
    forbidden = "forbidden"
    not_found = "not_found"
    nothing_to_review = "nothing_to_review"
    out_of_order = "out_of_order"
    retry_not_allowed = "retry_not_allowed"
    session_finished = "session_finished"
    session_not_active = "session_not_active"
    recitation_check_mismatch = "recitation_check_mismatch"
    duel_not_joinable = "duel_not_joinable"
    invite_invalid = "invite_invalid"
    already_friends = "already_friends"
    run_not_at_gate = "run_not_at_gate"
    review_stale = "review_stale"
    idempotency_conflict = "idempotency_conflict"
    answer_in_progress = "answer_in_progress"
    prerequisite_unmet = "prerequisite_unmet"
    payload_too_large = "payload_too_large"
    unsupported_media_type = "unsupported_media_type"
    client_outdated = "client_outdated"
    rate_limited = "rate_limited"
    internal_error = "internal_error"
    upstream_unavailable = "upstream_unavailable"


STATUS_BY_CODE: dict[ErrorCode, int] = {
    ErrorCode.validation_error: 400,
    ErrorCode.unauthorized: 401,
    ErrorCode.forbidden: 403,
    ErrorCode.not_found: 404,
    ErrorCode.payload_too_large: 413,
    ErrorCode.unsupported_media_type: 415,
    ErrorCode.client_outdated: 426,
    ErrorCode.rate_limited: 429,
    ErrorCode.internal_error: 500,
    ErrorCode.upstream_unavailable: 503,
}


def status_for(code: ErrorCode) -> int:
    return STATUS_BY_CODE.get(code, 409)  # every remaining code in the table is a 409


class ApiError(Exception):
    """Raise from any handler or dependency to return a contract error envelope."""

    def __init__(self, code: ErrorCode, message: str, details: dict[str, Any] | None = None,
                 *, headers: dict[str, str] | None = None) -> None:
        super().__init__(message)
        self.code = code
        self.status_code = status_for(code)
        self.message = message
        self.details = details or {}
        self.headers = headers


def error_response(code: ErrorCode, message: str, details: dict[str, Any] | None = None,
                   *, headers: dict[str, str] | None = None) -> JSONResponse:
    envelope = models.ErrorEnvelope(error=models.ErrorBody(code=code.value, message=message,
                                                           details=details or {}))
    return JSONResponse(envelope.model_dump(mode="json"), status_code=status_for(code), headers=headers)


def _validation_details(exc: RequestValidationError) -> dict[str, Any]:
    errors = []
    for err in exc.errors():
        loc = [str(part) for part in err.get("loc", ())]
        errors.append({"loc": loc, "type": err.get("type"), "msg": err.get("msg")})  # no "input"
    first = errors[0]["loc"] if errors else []
    field = ".".join(part for part in first if part not in ("body", "query", "path", "header"))
    return {"field": field or None, "errors": errors}


async def _api_error_handler(_: Request, exc: Exception) -> JSONResponse:
    assert isinstance(exc, ApiError)
    return error_response(exc.code, exc.message, exc.details, headers=exc.headers)


async def _validation_handler(_: Request, exc: Exception) -> JSONResponse:
    assert isinstance(exc, RequestValidationError)
    return error_response(ErrorCode.validation_error, "Request validation failed.", _validation_details(exc))


async def _http_exception_handler(_: Request, exc: Exception) -> JSONResponse:
    assert isinstance(exc, StarletteHTTPException)
    if exc.status_code in (404, 405):
        # An unknown path, or a method the path doesn't have: no such resource (decision D-16).
        return error_response(ErrorCode.not_found, "Resource not found.")
    if exc.status_code == 413:
        return error_response(ErrorCode.payload_too_large, "Payload too large.")
    if exc.status_code == 415:
        return error_response(ErrorCode.unsupported_media_type, "Unsupported media type.")
    if exc.status_code in (401, 403):
        code = ErrorCode.unauthorized if exc.status_code == 401 else ErrorCode.forbidden
        return error_response(code, "Not allowed.")
    if exc.status_code < 500:
        return error_response(ErrorCode.validation_error, "Invalid request.")
    return error_response(ErrorCode.internal_error, "Internal error.")


async def _unhandled_handler(request: Request, exc: Exception) -> JSONResponse:
    log.exception("unhandled error", extra={"path": request.url.path})
    return error_response(ErrorCode.internal_error, "Internal error.")


def install_error_handlers(app: FastAPI) -> None:
    app.add_exception_handler(ApiError, _api_error_handler)
    app.add_exception_handler(RequestValidationError, _validation_handler)
    app.add_exception_handler(StarletteHTTPException, _http_exception_handler)
    app.add_exception_handler(Exception, _unhandled_handler)
