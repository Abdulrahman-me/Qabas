"""Bounded multipart intake and durable private-object receipts (API §3.7/§6.8)."""
from __future__ import annotations

import asyncio
from collections.abc import AsyncGenerator
from dataclasses import dataclass
from datetime import timedelta
from typing import Any

import yaml
from fastapi import Request
from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from starlette.datastructures import UploadFile
from starlette.formparsers import MultiPartException, MultiPartParser

from app.config import Environment, Settings
from app.errors import ApiError, ErrorCode
from app.models.raqeeb_memory import RaqeebUploadReceipt
from app.runtime import Resources
from app.services.platform.auth_sessions import utcnow
from app.services.platform.storage import Bucket, ObjectStorage, user_prefix
from app.sources.records import sha256_bytes, sha256_text

MIB = 1024 * 1024
ATTACHMENT_RETENTION_DAYS = 7  # owner-selected original-file policy, not provider retention
MIMES = {
    "audio": {"audio/mp4", "audio/webm", "audio/wav", "audio/mpeg"},
    "image": {"image/jpeg", "image/png", "image/webp"},
    "document": {"application/pdf", "application/vnd.openxmlformats-officedocument.wordprocessingml.document"},
}


@dataclass(frozen=True)
class Upload:
    kind: str
    filename: str
    mime: str
    data: bytes

    def identity(self) -> dict[str, Any]:
        return {"kind": self.kind, "filename": self.filename, "mime": self.mime,
                "size": len(self.data), "sha256": sha256_bytes(self.data)}


@dataclass(frozen=True)
class Payload:
    text: str | None
    uploads: tuple[Upload, ...]

    def identity(self) -> dict[str, Any]:
        return {"text": self.text, **({"uploads": [u.identity() for u in self.uploads]} if self.uploads else {})}


class BodyTooLarge(MultiPartException):
    pass


async def parse(request: Request) -> Payload:
    if not request.headers.get("content-type", "").startswith("multipart/form-data"):
        raise ApiError(ErrorCode.validation_error, "Send multipart/form-data.")
    total = 0

    async def stream() -> AsyncGenerator[bytes, None]:
        nonlocal total
        async for chunk in request.stream():
            total += len(chunk)
            if total > 44 * MIB + 64 * 1024:
                raise BodyTooLarge("Message exceeds the upload limit.")
            yield chunk

    parser = MultiPartParser(request.headers, stream(), max_files=5, max_fields=1, max_part_size=8192)
    try:
        form = await parser.parse()
    except BodyTooLarge:
        raise ApiError(ErrorCode.payload_too_large, "Message exceeds the upload limit.") from None
    except MultiPartException:
        raise ApiError(ErrorCode.validation_error, "Invalid multipart fields or too many files.") from None
    try:
        text, uploads = None, []
        counts = {"audio": 0, "image": 0, "document": 0}
        for field, value in form.multi_items():
            if field == "text" and isinstance(value, str):
                if text is not None or len(value) > 2000:
                    raise ApiError(ErrorCode.validation_error, "text must contain 1-2000 characters.")
                text = value
                continue
            if field not in {"audio", "images", "document"} or not isinstance(value, UploadFile):
                raise ApiError(ErrorCode.validation_error, "Unknown or invalid message field.")
            kind = "image" if field == "images" else field
            counts[kind] += 1
            if counts[kind] > (3 if kind == "image" else 1):
                raise ApiError(ErrorCode.validation_error, "Too many attachments of this kind.")
            name, mime = value.filename or "", value.content_type or ""
            if not name or len(name) > 255 or any(ord(c) < 32 or c in "/\\" for c in name):
                raise ApiError(ErrorCode.validation_error, "Invalid attachment filename.")
            if mime not in MIMES[kind]:
                raise ApiError(ErrorCode.unsupported_media_type, "Unsupported attachment type.")
            limit = (8 if kind == "image" else 10) * MIB
            data = await value.read(limit + 1)
            if len(data) > limit:
                raise ApiError(ErrorCode.payload_too_large, "Attachment exceeds its size limit.")
            if not data:
                raise ApiError(ErrorCode.validation_error, "Empty attachment.")
            uploads.append(Upload(kind, name, mime, data))
        if (text is None or not text.strip()) and not uploads:
            raise ApiError(ErrorCode.validation_error, "At least one input is required.")
        return Payload(text, tuple(uploads))
    finally:
        await form.close()


def retention_days(settings: Settings) -> int:
    if settings.app_env in (Environment.dev, Environment.test):
        return ATTACHMENT_RETENTION_DAYS
    try:
        value = yaml.safe_load(settings.raqeeb_input_policy_path.read_text(encoding="utf-8"))
        days = value.get("attachment_retention_days")
        if value.get("schema") != "qabas.raqeeb_input_policy/1" or value.get("status") != "approved" or \
                not all(value.get(k) for k in ("approved_by", "approved_on", "report", "private_storage",
                                              "learner_disclosure")) or \
                not isinstance(days, int) or isinstance(days, bool) or days != ATTACHMENT_RETENTION_DAYS:
            raise ValueError
        return days
    except (OSError, UnicodeError, yaml.YAMLError, ValueError, AttributeError):
        raise ApiError(ErrorCode.upstream_unavailable, "Private upload policy is pending approval (O-09).") from None


async def prepare(resources: Resources, user_id: str, key: str, request_hash: str,
                  uploads: tuple[Upload, ...]) -> list[str]:
    if not uploads:
        return []
    retention_days(resources.settings)
    from app.raqeeb.service import active_user
    ids = []
    # A durable receipt exists BEFORE any object write. A crashed/rolled-back admission leaves an auditable
    # pending receipt, not an untracked object. Identical retries claim the same content-addressed identity.
    for index, upload in enumerate(uploads):
        day = utcnow().date().isoformat()  # an expired 24-hour key cannot bind a new message to old attachments
        identifier = "att_" + sha256_text(f"{user_id}\0{key}\0{request_hash}\0{day}\0{index}")[:32]
        ids.append(identifier)
        object_key = f"{user_prefix(user_id)}raqeeb/{identifier}/{sha256_bytes(upload.data)}"
        async with resources.sessionmaker() as db, db.begin():
            await active_user(db, user_id)
            await db.execute(insert(RaqeebUploadReceipt).values(
                id=identifier, user_id=user_id, request_hash=request_hash, object_key=object_key,
                sha256=sha256_bytes(upload.data), kind=upload.kind, filename=upload.filename, mime=upload.mime,
                size_bytes=len(upload.data), expires_at=utcnow() + timedelta(hours=1)).on_conflict_do_nothing())
        async with resources.sessionmaker() as db, db.begin():
            await active_user(db, user_id)  # user → receipt; purge cannot race an object write/resurrect it
            row = (await db.execute(select(RaqeebUploadReceipt).where(RaqeebUploadReceipt.id == identifier)
                                   .with_for_update())).scalar_one()
            if row.status == "deleted":
                if row.message_id is not None:
                    raise ApiError(ErrorCode.idempotency_conflict, "This upload already belongs to a message.")
                row.status = "pending"  # retry an uncommitted admission whose pending object was cleaned up
            if row.request_hash != request_hash or row.sha256 != sha256_bytes(upload.data):
                raise ApiError(ErrorCode.idempotency_conflict, "Upload identity conflicts with its receipt.")
            if row.status == "pending":
                row.expires_at = utcnow() + timedelta(hours=1)
                await asyncio.to_thread(resources.storage.put_immutable, Bucket.private, object_key,
                                        upload.data, upload.mime)
    return ids


def project(row: RaqeebUploadReceipt, storage: ObjectStorage, settings: Settings) -> dict[str, Any]:
    return {"attachment_id": row.id, "kind": row.kind, "filename": row.filename, "mime": row.mime,
            "size_bytes": row.size_bytes,
            "url": None if row.status == "deleted" else storage.signed_url(row.object_key,
                                                                           min(900, settings.signed_url_ttl_seconds)),
            "duration_ms": row.duration_ms, "pages": row.pages}


async def refresh(db: Any, value: dict[str, Any], user_id: str, storage: ObjectStorage,
                  settings: Settings) -> dict[str, Any]:
    if value.get("role") == "user":
        attachments = []
        for attachment in value["attachments"]:
            row = await db.get(RaqeebUploadReceipt, attachment["attachment_id"])
            if row is None or row.user_id != user_id:
                raise ApiError(ErrorCode.internal_error, "Attachment ownership binding is invalid.")
            attachments.append(project(row, storage, settings))
        value = value | {"attachments": attachments}
    return value


async def sweep(resources: Resources) -> int:
    count = 0
    async with resources.sessionmaker() as db, db.begin():
        rows = (await db.execute(select(RaqeebUploadReceipt).where(RaqeebUploadReceipt.status != "deleted",
            RaqeebUploadReceipt.expires_at <= utcnow()).with_for_update(skip_locked=True))).scalars()
        for row in rows:
            if row.status == "attached":
                from app.models import RaqeebMessage
                original = await db.get(RaqeebMessage, row.message_id)
                assistant = (await db.execute(select(RaqeebMessage).where(
                    RaqeebMessage.reply_to == row.message_id))).scalar_one_or_none() if original else None
                if assistant is not None and assistant.status == "processing":
                    continue
            await asyncio.to_thread(resources.storage.delete_private, row.object_key)
            row.status = "deleted"
            count += 1
    return count


async def complete(db: Any, original_id: str, completed_at: Any, settings: Settings) -> None:
    rows = (await db.execute(select(RaqeebUploadReceipt).where(
        RaqeebUploadReceipt.message_id == original_id, RaqeebUploadReceipt.status == "attached")
        .order_by(RaqeebUploadReceipt.id).with_for_update())).scalars()
    for row in rows:
        row.expires_at = completed_at + timedelta(days=retention_days(settings))
