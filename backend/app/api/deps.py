"""Request dependencies: resources, database session, client address and the authenticated user."""

from __future__ import annotations

from collections.abc import AsyncIterator
from typing import Annotated

import redis.asyncio as aioredis
from fastapi import Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import Settings
from app.errors import ApiError, ErrorCode
from app.models import User
from app.runtime import Resources
from app.services.platform import auth_sessions
from app.services.platform.storage import ObjectStorage


def get_resources(request: Request) -> Resources:
    resources: Resources = request.app.state.resources
    return resources


ResourcesDep = Annotated[Resources, Depends(get_resources)]


def get_settings_dep(resources: ResourcesDep) -> Settings:
    return resources.settings


def get_redis(resources: ResourcesDep) -> aioredis.Redis:
    return resources.redis


def get_storage(resources: ResourcesDep) -> ObjectStorage:
    return resources.storage


async def get_db(resources: ResourcesDep) -> AsyncIterator[AsyncSession]:
    async with resources.sessionmaker() as session:
        yield session


SettingsDep = Annotated[Settings, Depends(get_settings_dep)]
RedisDep = Annotated[aioredis.Redis, Depends(get_redis)]
StorageDep = Annotated[ObjectStorage, Depends(get_storage)]
DbDep = Annotated[AsyncSession, Depends(get_db)]


def client_address(request: Request, settings: SettingsDep) -> str:
    """The caller's network address, honouring only the configured number of trusted proxies."""
    hops = settings.trusted_proxy_hops
    if hops > 0:
        forwarded = [p.strip() for p in request.headers.get("x-forwarded-for", "").split(",") if p.strip()]
        if len(forwarded) >= hops:
            return forwarded[-hops]
    return request.client.host if request.client else "unknown"


ClientAddressDep = Annotated[str, Depends(client_address)]


def _bearer_token(request: Request) -> str:
    header = request.headers.get("authorization", "")
    scheme, _, token = header.partition(" ")
    if scheme.lower() != "bearer" or not token.strip():
        raise ApiError(ErrorCode.unauthorized, "Authentication required.",
                       headers={"WWW-Authenticate": "Bearer"})
    return token.strip()


async def current_user(request: Request, resources: ResourcesDep, db: DbDep) -> User:
    token = _bearer_token(request)
    principal = await auth_sessions.authenticate(db, resources.settings, token)
    request.state.user_id = principal.user.id
    return principal.user


CurrentUser = Annotated[User, Depends(current_user)]


async def current_learner(user: CurrentUser) -> User:
    if user.role != "learner":
        raise ApiError(ErrorCode.forbidden, "This action is only available to learners.")
    return user


async def current_reviewer(user: CurrentUser) -> User:
    if user.role != "reviewer":
        raise ApiError(ErrorCode.forbidden, "Reviewer access required.")
    return user


CurrentLearner = Annotated[User, Depends(current_learner)]
CurrentReviewer = Annotated[User, Depends(current_reviewer)]


SUPPORTED_LANGUAGES = ("ar", "en")


def negotiate_language(header: str | None, profile_language: str) -> str:
    """API §3.2: ``Accept-Language: ar|en`` is optional; without a supported value the profile language is used.

    Standard q-weighted lists are honoured (``en;q=0.8, ar``); region subtags match their language (``ar-SA``).
    A header naming no supported language falls back to the profile instead of failing (decision D-43).
    """
    best: tuple[float, int, str] | None = None
    for position, part in enumerate((header or "").split(",")):
        tag, _, params = part.strip().partition(";")
        language = tag.strip().lower().split("-")[0]
        if language not in SUPPORTED_LANGUAGES:
            continue
        weight = 1.0
        for param in params.split(";"):
            name, _, value = param.strip().partition("=")
            if name.strip() == "q":
                try:
                    weight = float(value)
                except ValueError:
                    weight = 0.0
        if weight > 0 and (best is None or (weight, -position) > (best[0], best[1])):
            best = (weight, -position, language)
    return best[2] if best else profile_language


def request_language(request: Request, user: CurrentUser) -> str:
    return negotiate_language(request.headers.get("accept-language"), user.language)


RequestLanguage = Annotated[str, Depends(request_language)]
