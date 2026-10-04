from __future__ import annotations

from pathlib import Path
from urllib.parse import parse_qs, urlsplit

import pytest

from app.services.platform.storage import (
    Bucket,
    ImmutableObjectError,
    LocalStorage,
    StorageError,
    content_addressed_key,
    sha256_hex,
)


@pytest.fixture
def storage(tmp_path: Path) -> LocalStorage:
    return LocalStorage(tmp_path, public_base_url="https://cdn.example.test",
                        private_base_url="http://127.0.0.1:8000/private", signing_key=b"k" * 32)


def test_content_objects_are_immutable(storage: LocalStorage) -> None:
    stored = storage.put(Bucket.content, "scenes/scn_x/v1/manifest.json", b"{}", "application/json")
    assert stored.sha256 == sha256_hex(b"{}")
    again = storage.put(Bucket.content, "scenes/scn_x/v1/manifest.json", b"{}", "application/json")
    assert again == stored
    with pytest.raises(ImmutableObjectError):
        storage.put(Bucket.content, "scenes/scn_x/v1/manifest.json", b"{\"changed\":1}", "application/json")


def test_private_objects_can_be_replaced_and_deleted(storage: LocalStorage) -> None:
    storage.put(Bucket.private, "attachments/att_1", b"a", "image/png")
    storage.put(Bucket.private, "attachments/att_1", b"b", "image/png")
    assert storage.get(Bucket.private, "attachments/att_1") == b"b"
    storage.delete_private("attachments/att_1")
    assert not storage.exists(Bucket.private, "attachments/att_1")


def test_content_addressed_key() -> None:
    assert content_addressed_key("/media/img/", b"x", ".webp") == f"media/img/{sha256_hex(b'x')}.webp"


@pytest.mark.parametrize("key", ["", "/abs", "a/../b", "a//b", "a\\b", "./a"])
def test_invalid_keys_rejected(storage: LocalStorage, key: str) -> None:
    with pytest.raises(StorageError):
        storage.put(Bucket.private, key, b"x", "text/plain")


def test_public_url(storage: LocalStorage) -> None:
    assert storage.public_url("img/a b.webp") == "https://cdn.example.test/img/a%20b.webp"


def test_signed_urls_verify_and_expire(storage: LocalStorage) -> None:
    url = storage.signed_url("attachments/att_1", ttl_seconds=900)
    query = parse_qs(urlsplit(url).query)
    expires, signature = int(query["expires"][0]), query["signature"][0]
    assert storage.verify_signature("attachments/att_1", expires, signature)
    assert not storage.verify_signature("attachments/att_2", expires, signature)
    assert not storage.verify_signature("attachments/att_1", expires, signature, now=expires + 1)
