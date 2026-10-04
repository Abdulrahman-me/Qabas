"""Guest accounts, onboarding and the learner profile (API §6.1-6.2, backend §5)."""

from __future__ import annotations

import secrets
from datetime import UTC, datetime
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError, available_timezones

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import Settings
from app.contract import models as C
from app.db.ids import new_id
from app.errors import ApiError, ErrorCode
from app.i18n import localized_number
from app.models import Unit, User
from app.registries import (
    deleted_learner_name,
    goal_anchor_keys,
    guest_name_words,
    guest_number_range,
    selectable_avatar_keys,
)
from app.services.adaptive import planner
from app.services.platform import auth_sessions
from app.services.platform.deletion import DELETED_DISPLAY_NAME

DEFAULT_LANGUAGE = "ar"


def iso(value: datetime) -> str:
    return value.astimezone(UTC).strftime("%Y-%m-%dT%H:%M:%SZ")


def to_contract_user(user: User) -> C.User:
    display_name = user.display_name
    if user.deleted_at is not None and display_name == DELETED_DISPLAY_NAME:
        display_name = deleted_learner_name(user.language)
    return C.User(
        user_id=user.id, display_name=display_name, role=user.role, language=user.language, track=user.track,
        daily_goal_minutes=user.daily_goal_minutes, timezone=user.timezone,
        onboarding_completed=user.onboarding_completed, avatar_key=user.avatar_key,
        familiarity=user.familiarity, private_profile=user.private_profile, created_at=iso(user.created_at),
        goal_anchor=user.goal_anchor,
    )


def validate_timezone(name: str) -> str:
    """An IANA zone name such as ``Asia/Riyadh`` (not ``localtime`` or file paths)."""
    candidate = name.strip()
    if candidate in available_timezones():
        try:
            ZoneInfo(candidate)
            return candidate
        except ZoneInfoNotFoundError:
            pass
    raise ApiError(ErrorCode.validation_error, "timezone must be an IANA time zone name, e.g. Asia/Riyadh.",
                   {"field": "timezone"})


def validate_goal_anchor(key: str | None) -> str | None:
    if key is not None and key not in goal_anchor_keys():
        raise ApiError(ErrorCode.validation_error, "Unknown goal_anchor.", {"field": "goal_anchor"})
    return key


def generate_display_name(language: str = DEFAULT_LANGUAGE) -> str:
    low, high = guest_number_range()
    word = secrets.choice(guest_name_words(language))
    return f"{word} {localized_number(low + secrets.randbelow(high - low + 1), language)}"


async def create_guest(db: AsyncSession, settings: Settings, timezone: str) -> tuple[User, str]:
    zone = validate_timezone(timezone)
    async with db.begin():
        user = User(id=new_id("usr"), display_name=generate_display_name(), avatar_key=secrets.choice(
            selectable_avatar_keys()), role="learner", language=DEFAULT_LANGUAGE, track="explorer",
            daily_goal_minutes=10, timezone=zone, onboarding_completed=False, private_profile=True)
        db.add(user)
        await db.flush()
        token = await auth_sessions.create_session(db, settings, user)
    await db.refresh(user)
    return user, token


async def start_unit_id(db: AsyncSession, track: str) -> str:
    """The first unit of the track's path (Explorer: Unit 0; New Muslim: Unit 1)."""
    unit_id = await db.scalar(select(Unit.id).where(Unit.tracks.contains([track])).order_by(Unit.index).limit(1))
    if unit_id is None:
        raise RuntimeError("the curriculum has no unit for this track; run scripts/seed.py")
    return unit_id


async def onboard(db: AsyncSession, user: User, request: C.OnboardingReq) -> C.OnboardingResp:
    """Store onboarding answers. No religion or worldview is asked, stored or inferred (AD-33)."""
    goal_anchor = validate_goal_anchor(request.goal_anchor)
    async with db.begin():
        user.track = "new_muslim" if request.track_choice == "new_muslim" else "explorer"
        user.language = request.language
        user.familiarity = request.familiarity
        user.daily_goal_minutes = request.daily_goal_minutes
        user.private_profile = request.private_profile
        user.goal_anchor = goal_anchor  # onboarding bridge only; never read by planner or access rules
        user.onboarding_completed = True
        db.add(user)
        await db.flush()
        start = await start_unit_id(db, user.track)
        step = await planner.next_step(db, user)
    await db.refresh(user)
    return C.OnboardingResp(user=to_contract_user(user), start_unit_id=start, next_step=step)


async def patch_me(db: AsyncSession, user: User, patch: C.MePatch) -> User:
    changes = patch.model_dump(exclude_unset=True)
    if "display_name" in changes:
        name = " ".join(changes["display_name"].split())
        if not 2 <= len(name) <= 24 or any(not ch.isprintable() for ch in name):
            raise ApiError(ErrorCode.validation_error, "display_name must be 2-24 printable characters.",
                           {"field": "display_name"})
        changes["display_name"] = name
    if "timezone" in changes:
        changes["timezone"] = validate_timezone(changes["timezone"])
    if "avatar_key" in changes and changes["avatar_key"] not in selectable_avatar_keys():
        raise ApiError(ErrorCode.validation_error, "Unknown avatar_key.", {"field": "avatar_key"})
    if "goal_anchor" in changes:
        validate_goal_anchor(changes["goal_anchor"])
    # Track changes keep all progress: completion is keyed by canonical lesson (AD-28). Active
    # session snapshots never change; the journey is recomputed on read.
    async with db.begin():
        for field, value in changes.items():
            setattr(user, field, value)
        db.add(user)
    await db.refresh(user)
    return user
