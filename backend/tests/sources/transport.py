"""Replay real recorded HTTP bodies without any outbound network or credentials."""

import json
from pathlib import Path
from typing import Any

import httpx

RECORDINGS = Path(__file__).parent / "recordings"


def recording(provider: str, filename: str) -> dict[str, Any]:
    return dict(json.loads((RECORDINGS / provider / filename).read_text(encoding="utf-8")))


class RecordedTransport(httpx.AsyncBaseTransport):
    def __init__(self, provider: str, *, prefix: str = "") -> None:
        self.records = [json.loads(p.read_text(encoding="utf-8")) for p in (RECORDINGS / provider).glob("*.json")]
        self.prefix = prefix
        self.requests: list[httpx.Request] = []

    async def handle_async_request(self, request: httpx.Request) -> httpx.Response:
        self.requests.append(request)
        for item in self.records:
            spec = item["request"]
            query = {str(k): str(v) for k, v in spec["query"].items()}
            if request.method == spec["method"] and request.url.path == self.prefix + spec["path"] \
                    and dict(request.url.params) == query:
                response = item["response"]
                body = response["body"]
                content = body.encode() if isinstance(body, str) else json.dumps(body, ensure_ascii=False).encode()
                return httpx.Response(response["status"], content=content,
                                      headers={"Content-Type": response["content_type"]}, request=request)
        raise AssertionError(f"unrecorded request: {request.method} {request.url.path}")
