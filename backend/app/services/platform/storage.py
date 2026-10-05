"""Object storage with two buckets (AD-21).

* ``content``: published media only. Immutable, versioned/content-addressed keys, served from the public CDN.
  Writing different bytes to an existing key is refused; writing identical bytes is a no-op.
* ``private``: learner attachments, reviewer drafts/previews, gold candidates. Reachable only through
  short-lived signed URLs; objects can be deleted (retention, account purge). Per-user objects live
  under ``users/<user_id>/`` so an account purge can remove them by prefix.

``LocalStorage`` stores files on disk (development/test; D-03). ``S3Storage`` targets any
S3-compatible store (deployments). The API is synchronous; async callers use ``asyncio.to_thread``.
"""

from __future__ import annotations

import hashlib
import hmac
import json
import os
import shutil
import tempfile
import time
from contextlib import suppress
from dataclasses import dataclass
from enum import StrEnum
from pathlib import Path
from typing import TYPE_CHECKING, Protocol
from urllib.parse import quote, urlencode

if TYPE_CHECKING:
    from mypy_boto3_s3 import S3Client

    from app.config import Settings


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


def user_prefix(user_id: str) -> str:
    """Private-bucket prefix for everything belonging to one user (purged with the account)."""
    return f"users/{validate_key(user_id)}/"


def validate_key(key: str) -> str:
    # Check raw segments: PurePosixPath would silently normalize "a//b" and "./a".
    if not key or key.startswith("/") or "\\" in key or any(seg in ("", ".", "..") for seg in key.split("/")):
        raise StorageError(f"invalid object key: {key!r}")
    return key


def _validate_prefix(prefix: str) -> str:
    if not prefix.endswith("/"):
        raise StorageError(f"prefix must end with '/': {prefix!r}")
    validate_key(prefix[:-1])
    return prefix


class ObjectStorage(Protocol):
    def put(self, bucket: Bucket, key: str, data: bytes, content_type: str) -> StoredObject: ...
    def put_immutable(self, bucket: Bucket, key: str, data: bytes, content_type: str) -> StoredObject: ...
    def get(self, bucket: Bucket, key: str) -> bytes: ...
    def exists(self, bucket: Bucket, key: str) -> bool: ...
    def delete_private(self, key: str) -> None: ...
    def delete_private_prefix(self, prefix: str) -> int: ...
    def public_url(self, key: str) -> str: ...
    def signed_url(self, key: str, ttl_seconds: int) -> str: ...


class LocalStorage:
    """Filesystem storage. Signed URLs are HMAC-signed paths verified by the local media route."""

    def __init__(self, root: Path, *, public_base_url: str, private_base_url: str, signing_key: bytes) -> None:
        self.root = root
        self.public_base_url = public_base_url.rstrip("/")
        self.private_base_url = private_base_url.rstrip("/")
        self._signing_key = signing_key

    def _path(self, bucket: Bucket, key: str) -> Path:
        return self.root / bucket.value / validate_key(key)

    def put(self, bucket: Bucket, key: str, data: bytes, content_type: str) -> StoredObject:
        if bucket is Bucket.content:
            return self.put_immutable(bucket, key, data, content_type)
        path = self._path(bucket, key)
        digest = sha256_hex(data)
        path.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as stream:
            tmp = Path(stream.name)
            stream.write(data)
        try:
            tmp.replace(path)
        finally:
            tmp.unlink(missing_ok=True)
        self._meta_path(path).write_text(json.dumps({"content_type": content_type, "sha256": digest}))
        return StoredObject(bucket, key, digest, len(data), content_type)

    def put_immutable(self, bucket: Bucket, key: str, data: bytes, content_type: str) -> StoredObject:
        path = self._path(bucket, key)
        digest = sha256_hex(data)
        path.parent.mkdir(parents=True, exist_ok=True)
        self._create_once(path, data)
        if path.read_bytes() != data:
            raise ImmutableObjectError(f"immutable object has different bytes: {key}")
        metadata = json.dumps({"content_type": content_type, "sha256": digest}).encode()
        meta = self._meta_path(path)
        self._create_once(meta, metadata)
        if json.loads(meta.read_bytes()) != json.loads(metadata):
            raise ImmutableObjectError(f"immutable object has different metadata: {key}")
        return StoredObject(bucket, key, digest, len(data), content_type)

    @staticmethod
    def _create_once(path: Path, data: bytes) -> None:
        # A hard-link claims the destination atomically, without exposing partial bytes or overwriting a winner.
        with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as stream:
            tmp = Path(stream.name)
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        try:
            with suppress(FileExistsError):
                os.link(tmp, path)
        finally:
            tmp.unlink(missing_ok=True)

    def get(self, bucket: Bucket, key: str) -> bytes:
        path = self._path(bucket, key)
        if not path.is_file():
            raise StorageError(f"no such object: {bucket}/{key}")
        return path.read_bytes()

    def content_type(self, bucket: Bucket, key: str) -> str:
        meta: dict[str, str] = json.loads(self._meta_path(self._path(bucket, key)).read_text())
        return meta["content_type"]

    def exists(self, bucket: Bucket, key: str) -> bool:
        return self._path(bucket, key).is_file()

    def delete_private(self, key: str) -> None:
        path = self._path(Bucket.private, key)
        path.unlink(missing_ok=True)
        self._meta_path(path).unlink(missing_ok=True)

    def delete_private_prefix(self, prefix: str) -> int:
        directory = self.root / Bucket.private.value / _validate_prefix(prefix)
        if not directory.is_dir():
            return 0
        count = sum(1 for p in directory.rglob("*") if p.is_file() and not p.name.endswith(".meta.json"))
        shutil.rmtree(directory)
        return count

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


class S3Storage:
    """S3-compatible storage (e.g. Cloudflare R2). Content objects carry their SHA-256 as metadata."""

    def __init__(self, client: S3Client, *, content_bucket: str, private_bucket: str, cdn_base_url: str) -> None:
        self.client = client
        self.buckets = {Bucket.content: content_bucket, Bucket.private: private_bucket}
        self.cdn_base_url = cdn_base_url.rstrip("/")

    def put(self, bucket: Bucket, key: str, data: bytes, content_type: str) -> StoredObject:
        if bucket is Bucket.content:
            return self.put_immutable(bucket, key, data, content_type)
        validate_key(key)
        digest = sha256_hex(data)
        name = self.buckets[bucket]
        self.client.put_object(Bucket=name, Key=key, Body=data, ContentType=content_type,
                               CacheControl="private, no-store", Metadata={"sha256": digest})
        return StoredObject(bucket, key, digest, len(data), content_type)

    def put_immutable(self, bucket: Bucket, key: str, data: bytes, content_type: str) -> StoredObject:
        validate_key(key)
        digest, name = sha256_hex(data), self.buckets[bucket]
        for _ in range(3):
            existing = self._head(name, key)
            if existing is not None:
                metadata = existing.get("Metadata")
                stored = metadata.get("sha256") if isinstance(metadata, dict) else None
                if stored != digest or existing.get("ContentType") != content_type:
                    raise ImmutableObjectError(f"content object already exists with different bytes: {key}")
                return StoredObject(bucket, key, digest, len(data), content_type)
            try:
                self.client.put_object(Bucket=name, Key=key, Body=data, ContentType=content_type,
                                       IfNoneMatch="*", Metadata={"sha256": digest}, CacheControl=(
                                           "public, max-age=31536000, immutable" if bucket is Bucket.content
                                           else "private, no-store"))
                return StoredObject(bucket, key, digest, len(data), content_type)
            except self.client.exceptions.ClientError as exc:
                if exc.response.get("Error", {}).get("Code") not in (
                        "PreconditionFailed", "ConditionalRequestConflict", "409", "412"):
                    raise
        raise StorageError("immutable object write contention; retry later")

    def _head(self, bucket_name: str, key: str) -> dict[str, object] | None:
        try:
            return dict(self.client.head_object(Bucket=bucket_name, Key=key))
        except self.client.exceptions.ClientError as exc:
            if exc.response.get("Error", {}).get("Code") in ("404", "NoSuchKey", "NotFound"):
                return None
            raise

    def get(self, bucket: Bucket, key: str) -> bytes:
        response = self.client.get_object(Bucket=self.buckets[bucket], Key=validate_key(key))
        return response["Body"].read()

    def exists(self, bucket: Bucket, key: str) -> bool:
        return self._head(self.buckets[bucket], validate_key(key)) is not None

    def delete_private(self, key: str) -> None:
        self.client.delete_object(Bucket=self.buckets[Bucket.private], Key=validate_key(key))

    def delete_private_prefix(self, prefix: str) -> int:
        name = self.buckets[Bucket.private]
        deleted = 0
        paginator = self.client.get_paginator("list_objects_v2")
        for page in paginator.paginate(Bucket=name, Prefix=_validate_prefix(prefix)):
            keys = [{"Key": item["Key"]} for item in page.get("Contents", [])]
            if keys:
                self.client.delete_objects(
                    Bucket=name, Delete={"Objects": keys, "Quiet": True})  # type: ignore[typeddict-item]
                deleted += len(keys)
        return deleted

    def public_url(self, key: str) -> str:
        return f"{self.cdn_base_url}/{quote(validate_key(key))}"

    def signed_url(self, key: str, ttl_seconds: int) -> str:
        return self.client.generate_presigned_url(
            "get_object", Params={"Bucket": self.buckets[Bucket.private], "Key": validate_key(key)},
            ExpiresIn=ttl_seconds)


def build_storage(settings: Settings) -> ObjectStorage:
    from app.config import StorageBackend

    if settings.storage_backend is StorageBackend.s3:
        import boto3

        required = ("s3_endpoint", "s3_content_bucket", "s3_private_bucket", "s3_access_key", "s3_secret_key")
        missing = [n for n in required if getattr(settings, n) is None]
        if missing:
            raise RuntimeError(f"S3 storage needs: {', '.join(missing)}")
        assert settings.s3_access_key and settings.s3_secret_key and settings.s3_content_bucket
        assert settings.s3_private_bucket
        client = boto3.client("s3", endpoint_url=settings.s3_endpoint,
                              aws_access_key_id=settings.s3_access_key.get_secret_value(),
                              aws_secret_access_key=settings.s3_secret_key.get_secret_value())
        return S3Storage(client, content_bucket=settings.s3_content_bucket,
                         private_bucket=settings.s3_private_bucket, cdn_base_url=settings.cdn_base_url)
    key = settings.storage_signing_key.get_secret_value().encode() if settings.storage_signing_key else None
    if key is None:
        if not settings.is_dev_like:
            raise RuntimeError("STORAGE_SIGNING_KEY is required")
        key = b"dev-only-signing-key"  # dev/test without .env secrets; staging/production require a real key
    return LocalStorage(settings.local_storage_dir, public_base_url=settings.cdn_base_url,
                        private_base_url=settings.cdn_base_url.rsplit("/", 1)[0] + "/private", signing_key=key)
