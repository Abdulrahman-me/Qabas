from __future__ import annotations

import json
import logging

from app.logs import REDACTED, JsonFormatter, redact, redact_query


def test_redact_nested_sensitive_keys() -> None:
    data = {"user_id": "usr_1", "Authorization": "Bearer abc",
            "nested": {"answer": {"choice": "opt_2"}, "items": [{"token": "t", "ok": 1}]}}
    assert redact(data) == {"user_id": "usr_1", "Authorization": REDACTED,
                            "nested": {"answer": REDACTED, "items": [{"token": REDACTED, "ok": 1}]}}


def test_redact_query_hides_tickets() -> None:
    assert redact_query("ticket=secret&cursor=abc") == "ticket=%5Bredacted%5D&cursor=abc"
    assert redact_query("") == ""


def test_formatter_emits_json_with_redacted_extras() -> None:
    record = logging.LogRecord("qabas.test", logging.INFO, __file__, 1, "hello", None, None)
    record.request_id = "req1"
    record.password = "hunter2"
    payload = json.loads(JsonFormatter().format(record))
    assert payload["msg"] == "hello"
    assert payload["request_id"] == "req1"
    assert payload["password"] == REDACTED
    assert payload["ts"].endswith("Z")
