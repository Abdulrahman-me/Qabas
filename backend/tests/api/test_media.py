"""Local storage links: public content is cacheable; private objects need a valid, unexpired signature."""

from __future__ import annotations

from urllib.parse import parse_qs, urlsplit

import pytest
from fastapi.testclient import TestClient

from app.services.platform.storage import Bucket, LocalStorage

pytestmark = pytest.mark.integration


def test_public_and_private_media(api: TestClient) -> None:
    storage = api.app.state.resources.storage  # type: ignore[attr-defined]
    assert isinstance(storage, LocalStorage)
    storage.put(Bucket.content, "img/a.webp", b"webp-bytes", "image/webp")
    public = api.get("/media/img/a.webp")
    assert public.status_code == 200 and public.content == b"webp-bytes"
    assert public.headers["content-type"] == "image/webp"
    assert "immutable" in public.headers["cache-control"]
    assert api.get("/media/img/missing.webp").status_code == 404

    storage.put(Bucket.private, "users/usr_x/att.png", b"secret", "image/png")
    url = urlsplit(storage.signed_url("users/usr_x/att.png", 900))
    ok = api.get(f"{url.path}?{url.query}")
    assert ok.status_code == 200 and ok.content == b"secret" and ok.headers["cache-control"] == "private, no-store"
    query = parse_qs(url.query)
    tampered = api.get(f"{url.path}?expires={query['expires'][0]}&signature={'0' * 64}")
    assert tampered.status_code == 403
    expired = api.get(f"{url.path}?expires=1&signature={query['signature'][0]}")
    assert expired.status_code == 403
    assert api.get(url.path).status_code == 400  # unsigned: missing parameters
    assert api.get("/media/users/usr_x/att.png").status_code == 404  # private objects aren't public
