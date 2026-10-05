"""Private build receipts and immutable final identities. URLs never identify mutable bytes."""

from __future__ import annotations

import asyncio
import json
from collections.abc import Callable
from typing import Any
from urllib.parse import urlsplit

from botocore.exceptions import BotoCoreError, ClientError
from pydantic import BaseModel, ConfigDict, Field

from app.content.package import content_digest
from app.media.codecs import raster
from app.media.errors import MediaInvalid, MediaUnavailable
from app.services.platform.storage import (
    Bucket,
    ImmutableObjectError,
    ObjectStorage,
    StorageError,
    content_addressed_key,
    sha256_hex,
    validate_key,
)


async def io[T](operation: Callable[..., T], *args: Any, **kwargs: Any) -> T:
    """Classify storage failures at the media boundary without persisting SDK errors/credentials."""
    try:
        return await asyncio.to_thread(operation, *args, **kwargs)
    except ImmutableObjectError as exc:
        raise MediaInvalid("immutable media key is already bound to different bytes or MIME") from exc
    except FileNotFoundError as exc:
        raise MediaInvalid("reviewed media object is missing") from exc
    except ClientError as exc:
        if exc.response.get("Error", {}).get("Code") in {"NoSuchKey", "NotFound", "404"}:
            raise MediaInvalid("reviewed media object is missing") from exc
        raise MediaUnavailable("media object storage is unavailable") from exc
    except (StorageError, BotoCoreError, OSError) as exc:
        raise MediaUnavailable("media object storage is unavailable") from exc


class MediaObject(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    private_key: str
    content_key: str
    sha256: str = Field(pattern=r"^[0-9a-f]{64}$")
    size: int = Field(gt=0)
    mime_type: str
    width: int | None
    height: int | None
    kind: str
    provenance: dict[str, Any]
    licence: dict[str, Any]
    binding: dict[str, Any]

    def public_url(self, storage: ObjectStorage) -> str:
        return storage.public_url(self.content_key)

    def identity(self) -> str:
        return content_digest(self.model_dump(mode="json"))


async def stage(
    storage: ObjectStorage,
    *,
    run_id: str,
    prefix: str,
    data: bytes,
    mime_type: str,
    kind: str,
    provenance: dict[str, Any],
    licence: dict[str, Any],
    binding: dict[str, Any],
    width: int | None = None,
    height: int | None = None,
) -> MediaObject:
    extension = {
        "image/webp": "webp",
        "image/png": "png",
        "image/jpeg": "jpg",
        "image/svg+xml": "svg",
        "application/json": "scene.json",
        "audio/mpeg": "mp3",
        "video/webm": "webm",
    }.get(mime_type)
    if extension is None:
        raise MediaInvalid("unsupported media object MIME")
    key = content_addressed_key(prefix, data, extension)
    validate_key(key)
    private = f"factory/{validate_key(run_id)}/media/{key}"
    if mime_type.startswith("image/") and mime_type != "image/svg+xml":
        if width is None or height is None:
            raise MediaInvalid("image dimensions are required")
        raster(data, mime_type, width, height)
    await io(storage.put_immutable, Bucket.private, private, data, mime_type)
    return MediaObject(
        private_key=private,
        content_key=key,
        sha256=sha256_hex(data),
        size=len(data),
        mime_type=mime_type,
        width=width,
        height=height,
        kind=kind,
        provenance=provenance,
        licence=licence,
        binding=binding,
    )


async def verify(storage: ObjectStorage, record: MediaObject, *, bucket: Bucket = Bucket.private) -> bytes:
    key = record.private_key if bucket is Bucket.private else record.content_key
    raw = await io(storage.get, bucket, key)
    if len(raw) != record.size or sha256_hex(raw) != record.sha256:
        raise MediaInvalid("media object bytes no longer match the reviewed receipt")
    if record.mime_type.startswith("image/") and record.mime_type != "image/svg+xml":
        if record.width is None or record.height is None:
            raise MediaInvalid("missing image dimensions")
        raster(raw, record.mime_type, record.width, record.height)
    elif record.mime_type == "audio/mpeg":
        from app.media.audio import mp3_duration

        mp3_duration(raw)
    elif record.mime_type == "video/webm":
        from app.media.video import webm_info

        webm_info(raw)
    return raw


def image(record: MediaObject, storage: ObjectStorage) -> dict[str, Any]:
    return {
        "url": record.public_url(storage),
        "mime_type": record.mime_type,
        "width": record.width,
        "height": record.height,
    }


def sign_projection(node: Any, objects: list[dict[str, Any]], storage: ObjectStorage, ttl: int) -> Any:
    """Stored hash URLs are stable; only transport URLs in the reviewer response expire (review.py preamble)."""
    urls = {
        storage.public_url(item["content_key"]): storage.signed_url(item["private_key"], min(ttl, 900))
        for item in objects
    }

    def walk(value: Any) -> Any:
        if isinstance(value, str):
            return urls.get(value, value)
        if isinstance(value, list):
            return [walk(item) for item in value]
        if isinstance(value, dict):
            return {key: walk(item) for key, item in value.items()}
        return value

    return walk(node)


async def review_projection(node: Any, records: list[dict[str, Any]], storage: ObjectStorage, ttl: int,
                            *, published: bool) -> Any:
    """Sign private review assets, including dependencies inside a scene manifest.

    The canonical manifest is never edited. A private transport copy substitutes only asset URLs, and its
    SceneRef carries that copy's hash so the usual learner loader can verify it. Clients echo the stored
    review digest; they never recompute it from the expiring transport projection (review.py preamble).
    """
    selected = [r for r in records if not published or r["kind"] in {"review_frame", "review_animation"}]
    projected = sign_projection(node, selected, storage, ttl)
    manifests = {}
    for raw in selected:
        if raw["kind"] != "scene_manifest":
            continue
        record = MediaObject.model_validate(raw)
        canonical = json.loads(await verify(storage, record))
        transport = sign_projection(canonical, selected, storage, ttl)
        data = encode(transport)
        key = record.private_key.split("/media/", 1)[0] + "/review-transport/" + sha256_hex(data) + ".scene.json"
        await io(storage.put_immutable, Bucket.private, key, data, "application/json")
        manifests[(canonical["scene_id"], canonical["version"], record.sha256)] = {
            "url": storage.signed_url(key, min(ttl, 900)), "sha256": sha256_hex(data)}

    def walk(value: Any) -> Any:
        if isinstance(value, dict):
            identity = (value.get("scene_id"), value.get("version"), value.get("sha256"))
            if value.get("schema_version") == "qabas.scene/1" and identity in manifests:
                return {**value, **manifests[identity]}
            return {key: walk(child) for key, child in value.items()}
        if isinstance(value, list):
            return [walk(child) for child in value]
        return value
    return walk(projected)


def https(url: str) -> None:
    parsed = urlsplit(url)
    if parsed.scheme != "https" or not parsed.hostname or parsed.username or parsed.password or parsed.query:
        raise MediaInvalid("production media needs immutable HTTPS URLs without credentials or query strings")


def encode(value: Any) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False).encode()
