"""Remove credential-bearing provider URLs from HTTP diagnostics and stored responses."""

import logging
import re
from typing import Any

_KEY_PATH = re.compile(r"(https?://[^\s\"']+/v3/)[^/\s\"']+(/)")


def redact_urls(text: str) -> str:
    return _KEY_PATH.sub(r"\1{key}\2", text)


class ProviderUrlFilter(logging.Filter):
    def filter(self, record: logging.LogRecord) -> bool:
        record.msg, record.args = redact_urls(record.getMessage()), ()
        return True


def install_url_filter() -> None:
    logger = logging.getLogger("httpx")
    if not any(isinstance(item, ProviderUrlFilter) for item in logger.filters):
        logger.addFilter(ProviderUrlFilter())


def redact_response(value: Any, credential: str) -> Any:
    if isinstance(value, str):
        return redact_urls(value.replace(credential, "{key}"))
    if isinstance(value, dict):
        return {str(key): redact_response(item, credential) for key, item in value.items()}
    if isinstance(value, list):
        return [redact_response(item, credential) for item in value]
    return value
