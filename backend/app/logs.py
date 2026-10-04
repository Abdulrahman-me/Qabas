"""Structured JSON logging with redaction (OPERATIONS: logging baseline).

Never log tokens, WebSocket tickets, ``Authorization``, passwords, learner text, transcripts,
attachment content or answers. Redaction is by key name; callers must still avoid putting
learner content into log messages.
"""

from __future__ import annotations

import json
import logging
import sys
from datetime import UTC, datetime
from typing import Any
from urllib.parse import parse_qsl, urlencode

REDACTED = "[redacted]"
SENSITIVE_KEYS = frozenset({
    "authorization", "access_token", "token", "ticket", "password", "pepper", "secret",
    "api_key", "answer", "answers", "text", "transcript", "attachment", "attachments",
    "content", "body", "idempotency_key",
})
SENSITIVE_QUERY_PARAMS = frozenset({"ticket", "token", "access_token", "signature", "sig"})

_STANDARD_ATTRS = frozenset(vars(logging.LogRecord("", 0, "", 0, "", None, None))) | {"message", "asctime"}


def redact(value: Any) -> Any:
    """Recursively replace values of sensitive keys."""
    if isinstance(value, dict):
        return {k: (REDACTED if str(k).lower() in SENSITIVE_KEYS else redact(v)) for k, v in value.items()}
    if isinstance(value, list | tuple):
        return [redact(v) for v in value]
    return value


def redact_query(query: str) -> str:
    if not query:
        return ""
    pairs = parse_qsl(query, keep_blank_values=True)
    return urlencode([(k, REDACTED if k.lower() in SENSITIVE_QUERY_PARAMS else v) for k, v in pairs])


class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload: dict[str, Any] = {
            "ts": datetime.fromtimestamp(record.created, UTC).isoformat().replace("+00:00", "Z"),
            "level": record.levelname,
            "logger": record.name,
            "msg": record.getMessage(),
        }
        extras = {k: v for k, v in record.__dict__.items() if k not in _STANDARD_ATTRS and not k.startswith("_")}
        payload.update(redact(extras))
        if record.exc_info:
            payload["exc"] = self.formatException(record.exc_info)
        return json.dumps(payload, ensure_ascii=False, default=str)


def configure_logging(level: str = "INFO") -> None:
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(JsonFormatter())
    root = logging.getLogger()
    root.handlers[:] = [handler]
    root.setLevel(level.upper())
    # Uvicorn's access log prints raw URLs (query strings could hold tickets); we log requests ourselves.
    logging.getLogger("uvicorn.access").disabled = True
