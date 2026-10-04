"""Revocable opaque bearer tokens (AD-20, backend §5).

* A token is 32 CSPRNG bytes, base64url-encoded. Only HMAC-SHA-256(pepper, token) is stored.
* Every request looks the session up in the database (one indexed query, no cache), so a
  revocation takes effect immediately, stricter than the specified 30 s (decision D-24).
* Guest sessions have no fixed expiry but end after 180 days without use; reviewer sessions
  expire 12 h after login. Deleted or deactivated users never authenticate.
* Pepper rotation: the previous pepper is still accepted, and a match re-hashes the row with the
  current pepper, so rotation needs no downtime and no forced sign-out.
"""

from __future__ import annotations

import base64
import hashlib
import hmac
import secrets
import uuid
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import Settings
from app.errors import ApiError, ErrorCode
from app.models import AuthSession, User

TOKEN_BYTES = 32
MAX_TOKEN_LENGTH = 128


def utcnow() -> datetime:
    return datetime.now(UTC)


def new_token() -> str:
    return base64.urlsafe_b64encode(secrets.token_bytes(TOKEN_BYTES)).rstrip(b"=").decode()


def token_hmac(pepper: bytes, token: str) -> bytes:
    return hmac.new(pepper, token.encode(), hashlib.sha256).digest()


@dataclass(frozen=True)
class Principal:
    user: User
    session_id: uuid.UUID
    role: str


def _unauthorized() -> ApiError:
    return ApiError(ErrorCode.unauthorized, "Your session has ended. Please sign in again.",
                    headers={"WWW-Authenticate": "Bearer"})


async def create_session(db: AsyncSession, settings: Settings, user: User, *, now: datetime | None = None) -> str:
    """Create an auth session for ``user`` inside the caller's transaction; returns the raw token."""
    now = now or utcnow()
    token = new_token()
    expires_at = now + timedelta(hours=settings.reviewer_session_hours) if user.role == "reviewer" else None
    db.add(AuthSession(user_id=user.id, token_hmac=token_hmac(settings.peppers()[0], token), role=user.role,
                       created_at=now, last_used_at=now, expires_at=expires_at))
    return token


async def authenticate(db: AsyncSession, settings: Settings, token: str, *, now: datetime | None = None) -> Principal:
    if not token or len(token) > MAX_TOKEN_LENGTH:
        raise _unauthorized()
    now = now or utcnow()
    candidates = [token_hmac(pepper, token) for pepper in settings.peppers()]
    row = (await db.execute(
        select(AuthSession, User).join(User, User.id == AuthSession.user_id)
        .where(AuthSession.token_hmac.in_(candidates), AuthSession.revoked_at.is_(None))
    )).first()
    if row is None:
        await db.rollback()
        raise _unauthorized()
    auth, user = row
    if auth.expires_at is not None and auth.expires_at <= now:
        raise _unauthorized()
    if user.deleted_at is not None or user.deactivated_at is not None:
        raise _unauthorized()
    if auth.role == "learner" and auth.last_used_at <= now - timedelta(days=settings.guest_inactivity_days):
        auth.revoked_at = now
        await db.commit()
        raise _unauthorized()

    if auth.token_hmac != candidates[0]:  # matched the previous pepper: re-hash with the current one
        auth.token_hmac = candidates[0]
    if now - auth.last_used_at >= timedelta(seconds=settings.last_seen_throttle_seconds):
        auth.last_used_at = now
        user.last_seen_at = now
    # Always end the lookup transaction (committing any touch/re-hash), so request handlers start
    # their own explicit transactions on a clean session.
    # (commit, not rollback: a rollback would expire the loaded user even with expire_on_commit=False)
    await db.commit()
    return Principal(user=user, session_id=auth.id, role=auth.role)


async def revoke_all(db: AsyncSession, user_id: str, *, now: datetime | None = None) -> int:
    """Revoke every active session of a user inside the caller's transaction."""
    result = await db.execute(
        update(AuthSession).where(AuthSession.user_id == user_id, AuthSession.revoked_at.is_(None))
        .values(revoked_at=now or utcnow()))
    return int(result.rowcount or 0)  # type: ignore[attr-defined]


async def expire_inactive_guest_sessions(db: AsyncSession, settings: Settings, *, now: datetime | None = None) -> int:
    """Maintenance: revoke guest sessions unused for the inactivity period."""
    now = now or utcnow()
    result = await db.execute(
        update(AuthSession)
        .where(AuthSession.role == "learner", AuthSession.revoked_at.is_(None),
               AuthSession.last_used_at <= now - timedelta(days=settings.guest_inactivity_days))
        .values(revoked_at=now))
    return int(result.rowcount or 0)  # type: ignore[attr-defined]
