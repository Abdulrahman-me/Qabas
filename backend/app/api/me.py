"""Onboarding and profile: ``POST /onboarding``, ``GET/PATCH/DELETE /me`` (API §6.1-6.2)."""

from __future__ import annotations

from fastapi import APIRouter, Response

from app.api.deps import CurrentLearner, CurrentUser, DbDep
from app.contract import models as C
from app.services import users
from app.services.platform import deletion

router = APIRouter(tags=["profile"])


@router.post("/onboarding", response_model=C.OnboardingResp)
async def onboarding(body: C.OnboardingReq, user: CurrentLearner, db: DbDep) -> C.OnboardingResp:
    return await users.onboard(db, user, body)


@router.get("/me", response_model=C.User)
async def get_me(user: CurrentUser) -> C.User:
    return users.to_contract_user(user)


@router.patch("/me", response_model=C.User)
async def patch_me(body: C.MePatch, user: CurrentUser, db: DbDep) -> C.User:
    return users.to_contract_user(await users.patch_me(db, user, body))


@router.delete("/me", status_code=204, response_class=Response)
async def delete_me(user: CurrentUser, db: DbDep) -> Response:
    """Revoke sessions and mark the account deleted now; the purge job removes the data (<= 30 days)."""
    await deletion.request_deletion(db, user)
    return Response(status_code=204)
