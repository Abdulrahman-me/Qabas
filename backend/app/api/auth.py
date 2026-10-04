"""``POST /auth/guest`` and ``POST /auth/reviewer`` (API §6.1)."""

from __future__ import annotations

from fastapi import APIRouter
from sqlalchemy import func, select

from app.api.deps import ClientAddressDep, DbDep, RedisDep, SettingsDep
from app.contract import models as C
from app.errors import ApiError, ErrorCode
from app.models import User
from app.services import users
from app.services.platform import auth_sessions, passwords
from app.services.platform.rate_limits import FailureCounter, Limit, RateLimiter

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/guest", status_code=201, response_model=C.AuthResp)
async def create_guest(body: C.GuestReq, db: DbDep, redis: RedisDep, settings: SettingsDep,
                       address: ClientAddressDep) -> C.AuthResp:
    await RateLimiter(redis, settings).hit("auth_guest", address)
    user, token = await users.create_guest(db, settings, body.timezone)
    return C.AuthResp(access_token=token, user=users.to_contract_user(user))


def _lockouts(redis: RedisDep, settings: SettingsDep) -> tuple[FailureCounter, FailureCounter]:
    limit = Limit(settings.reviewer_lockout_attempts, settings.reviewer_lockout_window_seconds)
    return (FailureCounter(redis, settings, "reviewer_login_account", limit),
            FailureCounter(redis, settings, "reviewer_login_address", limit))


@router.post("/reviewer", response_model=C.AuthResp)
async def reviewer_login(body: C.ReviewerReq, db: DbDep, redis: RedisDep, settings: SettingsDep,
                         address: ClientAddressDep) -> C.AuthResp:
    """Email/password sign-in with a lockout after 5 failures per account or address in 15 min.

    Every failure, including an unknown email, gets the same generic answer and timing.
    """
    email = body.email.strip().lower()
    by_account, by_address = _lockouts(redis, settings)
    await by_account.check(email)
    await by_address.check(address)
    async with db.begin():
        user = (await db.execute(select(User).where(func.lower(User.email) == email, User.role == "reviewer")
                                 )).scalar_one_or_none()
        valid = passwords.verify_password(user.password_hash if user else None, body.password)
        if not valid or user is None or user.deactivated_at is not None or user.deleted_at is not None:
            invalid = True
        else:
            invalid = False
            if user.password_hash and passwords.needs_rehash(user.password_hash):
                user.password_hash = passwords.hash_password(body.password)
            token = await auth_sessions.create_session(db, settings, user)
    if invalid:
        await by_account.record_failure(email)
        await by_address.record_failure(address)
        raise ApiError(ErrorCode.unauthorized, "Invalid email or password.")
    await by_account.reset(email)
    assert user is not None
    await db.refresh(user)
    return C.AuthResp(access_token=token, user=users.to_contract_user(user))
