"""Serves local filesystem storage when ``STORAGE_BACKEND=local`` (deployments use the CDN and S3).

``/media/<key>``: published content, immutable and publicly cacheable.
``/private/<key>?expires=&signature=``: private objects, only with a valid unexpired signature.
Not part of the public contract (excluded from OpenAPI).
"""

from __future__ import annotations

import asyncio

from fastapi import APIRouter, Query
from fastapi.responses import Response

from app.api.deps import StorageDep
from app.errors import ApiError, ErrorCode
from app.services.platform.storage import Bucket, LocalStorage, StorageError

router = APIRouter(include_in_schema=False)


def _local(storage: StorageDep) -> LocalStorage:
    if not isinstance(storage, LocalStorage):
        raise ApiError(ErrorCode.not_found, "Resource not found.")
    return storage


async def _read(storage: LocalStorage, bucket: Bucket, key: str) -> tuple[bytes, str]:
    try:
        data = await asyncio.to_thread(storage.get, bucket, key)
        return data, await asyncio.to_thread(storage.content_type, bucket, key)
    except (StorageError, FileNotFoundError):
        raise ApiError(ErrorCode.not_found, "Resource not found.") from None


@router.get("/media/{key:path}")
async def public_media(key: str, storage: StorageDep) -> Response:
    data, content_type = await _read(_local(storage), Bucket.content, key)
    return Response(data, media_type=content_type,
                    headers={"Cache-Control": "public, max-age=31536000, immutable"})


@router.get("/private/{key:path}")
async def private_media(key: str, storage: StorageDep, expires: int = Query(...),
                        signature: str = Query(..., max_length=128)) -> Response:
    local = _local(storage)
    try:
        valid = local.verify_signature(key, expires, signature)
    except StorageError:
        valid = False
    if not valid:
        raise ApiError(ErrorCode.forbidden, "This link is invalid or has expired.")
    data, content_type = await _read(local, Bucket.private, key)
    return Response(data, media_type=content_type, headers={"Cache-Control": "private, no-store"})
