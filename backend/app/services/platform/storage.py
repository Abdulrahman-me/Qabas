"""Object storage with two buckets (AD-21).

* ``content``: published media only. Immutable, versioned/content-addressed keys, served from the public CDN.
  Writing different bytes to an existing key is refused; writing identical bytes is a no-op.
* ``private``: learner attachments, reviewer drafts/previews, gold candidates. Reachable only through
  short-lived signed URLs; objects can be deleted (retention, account purge).

``LocalStorage`` backs dev/test with the filesystem (no Docker/MinIO, D-03). The S3 implementation arrives in Phase 3.
"""

from __future__ import annotations

import hashlib
import hmac
import json
import time
from dataclasses import dataclass
from enum import StrEnum
from pathlib import Path
from typing import Protocol
from urllib.parse import quote, urlencode


class Bucket(StrEnum):
    content = "content"
    private = "private"


class StorageError(Exception):
    pass


class ImmutableObjectError(StorageError):
    """Raised when different bytes are written to an existing content key."""


@dataclass(frozen=True)
class StoredObject:
    bucket: Bucket
    key: str
    sha256: str
    size: int
    content_type: str


def sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def content_addressed_key(prefix: str, data: bytes, extension: str) -> str:
    """``<prefix>/<sha256>.<ext>``: a key that can never point at different bytes."""
    return f"{prefix.strip('/')}/{sha256_hex(data)}.{extension.lstrip('.')}"


def validate_key(key: str) -> str:
    # Check raw segments: PurePosixPath would silently normalize "a//b" and "./a".
    if not key or key.startswith("/") or "\\" in key or any(seg in ("", ".", "..") for seg in key.split("/")):
        raise StorageError(f"invalid object key: {key!r}")
    return key


class ObjectStorage(Protocol):
    def put(self, bucket: Bucket, key: str, data: bytes, content_type: str) -> StoredObject: ...
    def get(self, bucket: Bucket, key: str) -> bytes: ...
    def exists(self, bucket: Bucket, key: str) -> bool: ...
    def delete_private(self, key: str) -> None: ...
    def public_url(self, key: str) -> str: ...
    def signed_url(self, key: str, ttl_seconds: int) -> str: ...


class LocalStorage:
    """Filesystem storage for dev/test. Signed URLs are HMAC-signed paths that a dev route verifies."""

    def __init__(self, root: Path, *, public_base_url: str, private_base_url: str, signing_key: bytes) -> None:
        self.root = root
        self.public_base_url = public_base_url.rstrip("/")
        self.private_base_url = private_base_url.rstrip("/")
        self._signing_key = signing_key

    def _path(self, bucket: Bucket, key: str) -> Path:
        return self.root / bucket.value / validate_key(key)

    def put(self, bucket: Bucket, key: str, data: bytes, content_type: str) -> StoredObject:
        path = self._path(bucket, key)
        digest = sha256_hex(data)
        if bucket is Bucket.content and path.exists():
            if sha256_hex(path.read_bytes()) != digest:
                raise ImmutableObjectError(f"content object already exists with different bytes: {key}")
            return StoredObject(bucket, key, digest, len(data), self._meta(path)["content_type"])
        path.parent.mkdir(parents=True, exist_ok=True)
        tmp = path.with_name(path.name + ".tmp")
        tmp.write_bytes(data)
        tmp.replace(path)
        self._meta_path(path).write_text(json.dumps({"content_type": content_type, "sha256": digest}))
        return StoredObject(bucket, key, digest, len(data), content_type)

    def get(self, bucket: Bucket, key: str) -> bytes:
        path = self._path(bucket, key)
        if not path.is_file():
            raise StorageError(f"no such object: {bucket}/{key}")
        return path.read_bytes()

    def exists(self, bucket: Bucket, key: str) -> bool:
        return self._path(bucket, key).is_file()

    def delete_private(self, key: str) -> None:
        path = self._path(Bucket.private, key)
        path.unlink(missing_ok=True)
        self._meta_path(path).unlink(missing_ok=True)

    def public_url(self, key: str) -> str:
        return f"{self.public_base_url}/{quote(validate_key(key))}"

    def signed_url(self, key: str, ttl_seconds: int) -> str:
        expires = int(time.time()) + ttl_seconds
        query = urlencode({"expires": expires, "signature": self._signature(key, expires)})
        return f"{self.private_base_url}/{quote(validate_key(key))}?{query}"

    def verify_signature(self, key: str, expires: int, signature: str, *, now: float | None = None) -> bool:
        if (now if now is not None else time.time()) > expires:
            return False
        return hmac.compare_digest(self._signature(key, expires), signature)

    def _signature(self, key: str, expires: int) -> str:
        message = f"{validate_key(key)}\n{expires}".encode()
        return hmac.new(self._signing_key, message, hashlib.sha256).hexdigest()

    @staticmethod
    def _meta_path(path: Path) -> Path:
        return path.with_name(path.name + ".meta.json")

    def _meta(self, path: Path) -> dict[str, str]:
        data: dict[str, str] = json.loads(self._meta_path(path).read_text())
        return data
