"""League, friends and achievements (API §6.9, ``GET /me/achievements``; Phase 18)."""

from __future__ import annotations

from datetime import timedelta
from typing import Any

from fastapi import APIRouter, Request, Response
from starlette.responses import JSONResponse

from app.api.deps import ClientAddressDep, CurrentLearner, DbDep, RedisDep, RequestLanguage, SettingsDep
from app.contract import models as C
from app.errors import ApiError, ErrorCode
from app.services.community import achievements, friends, leagues
from app.services.learning.profile import PAGE_DEFAULT
from app.services.platform import idempotency
from app.services.platform.auth_sessions import utcnow
from app.services.platform.rate_limits import FAILURE_LIMITS, FailureCounter, RateLimiter

router = APIRouter(tags=["community"])


@router.get("/leagues/current", response_model=C.League)
async def current_league(user: CurrentLearner, db: DbDep, lang: RequestLanguage) -> C.League:
    async with db.begin():
        return await leagues.current(db, user, lang, utcnow())


@router.get("/friends", response_model=C.EXPORTED["FriendPage"])
async def friend_page(user: CurrentLearner, db: DbDep, cursor: str | None = None,
                      limit: int = PAGE_DEFAULT) -> Any:
    async with db.begin():
        return await friends.page(db, user, cursor, limit, utcnow())


@router.post("/friends/invites", status_code=201, response_model=C.Invite)
async def create_invite(request: Request, user: CurrentLearner, db: DbDep, redis: RedisDep, settings: SettingsDep,
                        lang: RequestLanguage) -> Any:
    key = idempotency.parse_key(request.headers.get(idempotency.HEADER), required=False)

    async def action() -> tuple[int, dict[str, Any]]:
        await RateLimiter(redis, settings).hit("friend_invite", user.id)
        return 201, await friends.create_invite(db, user, lang, utcnow())

    if key:
        request_hash = idempotency.fingerprint("POST", request.url.path, {"language": lang})
        stored = await idempotency.run_idempotent(db, user_id=user.id, key=key, request_hash=request_hash,
                                                  ttl=timedelta(hours=settings.idempotency_ttl_hours), create=action)
        return JSONResponse(stored.body, status_code=stored.status)
    async with db.begin():
        return (await action())[1]


@router.post("/friends/invites/accept", response_model=C.Friend)
async def accept_invite(body: C.InviteAccept, user: CurrentLearner, db: DbDep, redis: RedisDep,
                        settings: SettingsDep, address: ClientAddressDep) -> C.Friend:
    """At most 10 failed codes per learner per hour and 100 per address per day (backend §10.4).

    Each attempt is counted before it runs (atomically, so a concurrent burst cannot outrun the limit) and the
    count is given back when the attempt is not a failed code."""
    learner_id = user.id   # read before the transaction: a rollback expires the loaded user
    by_user = FailureCounter(redis, settings, "invite_accept_user", FAILURE_LIMITS["invite_accept_user"])
    by_address = FailureCounter(redis, settings, "invite_accept_address", FAILURE_LIMITS["invite_accept_address"])
    await by_user.reserve(learner_id)
    try:
        await by_address.reserve(address)
    except ApiError:
        await by_user.release(learner_id)
        raise
    try:
        async with db.begin():
            friend = await friends.accept(db, user, body.code, utcnow())
    except friends.InvalidInvite:
        raise ApiError(ErrorCode.invite_invalid, "This invite code is not valid.") from None
    except BaseException:
        await by_user.release(learner_id)
        await by_address.release(address)
        raise
    await by_user.release(learner_id)
    await by_address.release(address)
    return friend


@router.delete("/friends/{user_id}", status_code=204, response_class=Response)
async def remove_friend(user_id: str, user: CurrentLearner, db: DbDep) -> Response:
    async with db.begin():
        await friends.remove(db, user, user_id)
    return Response(status_code=204)


@router.get("/me/achievements", response_model=C.Achievements)
async def my_achievements(user: CurrentLearner, db: DbDep, lang: RequestLanguage) -> C.Achievements:
    async with db.begin():
        return await achievements.response(db, user, lang)
