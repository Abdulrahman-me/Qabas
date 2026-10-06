"""AD-20/API section 8: caller/duel-bound, single-use 60-second connection tickets, never bearer URLs."""

from __future__ import annotations

import hashlib
import json
import secrets
import uuid
from datetime import datetime, timedelta
from typing import Literal

import redis.asyncio as aioredis
from pydantic import BaseModel, ConfigDict
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import Settings
from app.errors import ApiError, ErrorCode
from app.models import AuthSession, User
from app.runtime import redis_key


class Ticket(BaseModel):
    model_config = ConfigDict(extra="forbid")
    user_id: str
    session_id: uuid.UUID
    duel_id: str
    language: Literal["ar", "en"]


def key(settings: Settings, token: str) -> str:
    return redis_key(settings, "ws-ticket", hashlib.sha256(token.encode()).hexdigest())


def unauthorized() -> ApiError:
    return ApiError(ErrorCode.unauthorized, "Fetch a fresh challenge connection URL.")


async def mint(redis: aioredis.Redis, settings: Settings, user_id: str, session_id: uuid.UUID,
               duel_id: str, language: str) -> str:
    token = secrets.token_urlsafe(32)
    data = Ticket(user_id=user_id, session_id=session_id, duel_id=duel_id, language=language)
    await redis.set(key(settings, token), data.model_dump_json(), ex=settings.ws_ticket_ttl_seconds, nx=True)
    return token


async def consume(redis: aioredis.Redis, settings: Settings, duel_id: str, token: str | None) -> Ticket:
    if token is None or not token or len(token) > 128:
        raise unauthorized()
    raw = await redis.getdel(key(settings, token))
    if raw is None:
        raise unauthorized()
    try:
        result = Ticket.model_validate(json.loads(raw))
    except (ValueError, TypeError):
        raise unauthorized() from None
    if result.duel_id != duel_id:
        raise unauthorized()
    return result


async def principal(db: AsyncSession, ticket: Ticket, settings: Settings, now: datetime, *, touch: bool = False
                    ) -> User:
    row = (await db.execute(select(AuthSession, User).join(User, User.id == AuthSession.user_id).where(
        AuthSession.id == ticket.session_id, AuthSession.user_id == ticket.user_id)
        .execution_options(populate_existing=True))).first()
    if row is None:
        raise unauthorized()
    auth, user = row
    if (auth.revoked_at is not None or user.deleted_at is not None or user.deactivated_at is not None
            or (auth.expires_at is not None and auth.expires_at <= now)
            or auth.last_used_at <= now - timedelta(days=settings.guest_inactivity_days)):
        raise unauthorized()
    if auth.role != "learner" or user.role != "learner" or user.is_bot or user.is_synthetic:
        raise ApiError(ErrorCode.forbidden, "Learner access required.")
    if touch and now - auth.last_used_at >= timedelta(seconds=settings.last_seen_throttle_seconds):
        auth.last_used_at = now
        user.last_seen_at = now
    return user
