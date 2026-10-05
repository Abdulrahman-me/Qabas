"""Account deletion (API §6.2 ``DELETE /me``, backend §5, AD-21).

Request transaction (:func:`request_deletion`): revoke every auth session, mark the user deleted,
remove what other users see at once (friendships, invites and league seats, :func:`forget_community`), run
any further request-time steps, record a ``deletion_jobs`` row and enqueue ``user:{id}:purge``.

Purge (:func:`purge_user`, an outbox consumer): delete the learner's data, private objects and
derived rows, and anonymize the profile row (kept only as a placeholder for records other users
still need). Every step is idempotent, so redelivery and re-purge after a backup restore
(``scripts/repurge_deleted_users.py``) are safe.
"""

from __future__ import annotations

import asyncio
import logging
from collections.abc import Awaitable, Callable
from datetime import datetime
from typing import Any

from sqlalchemy import delete, or_, select, update
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.errors import ApiError, ErrorCode
from app.models import (
    AuthSession,
    DailyActivity,
    DeletionJob,
    FriendInvite,
    Friendship,
    IdempotencyKey,
    LeagueMember,
    LearnerAchievement,
    LearnerConcept,
    LearnerLesson,
    LearnerMisconception,
    LearnerTerm,
    LearnerTier,
    LearnerUnit,
    LearningSession,
    MetricLearnerFact,
    MetricUnitFact,
    OutboxEvent,
    Quest,
    RaqeebConversation,
    RecitationCheckRecord,
    User,
    XpEvent,
)
from app.registries import default_avatar_key
from app.services.platform import auth_sessions, outbox
from app.services.platform.storage import ObjectStorage, user_prefix

log = logging.getLogger("qabas.deletion")

PURGE_KIND = "user.purge"
DELETED_DISPLAY_NAME = "deleted"  # rendered as the localized "Deleted learner" placeholder

# Further steps other features add for request-time removal (e.g. open challenges, Phase 19).
RequestStep = Callable[[AsyncSession, str], Awaitable[None]]
REQUEST_STEPS: list[RequestStep] = []

# Learner-owned rows deleted by the purge, in dependency-safe order (answers cascade from sessions).
PURGED_TABLES: tuple[Any, ...] = (
    LearningSession, RecitationCheckRecord, LearnerConcept, LearnerTerm, LearnerMisconception, LearnerLesson,
    LearnerUnit, XpEvent, DailyActivity, Quest, IdempotencyKey, AuthSession, MetricUnitFact, MetricLearnerFact,
    RaqeebConversation, LeagueMember, LearnerTier, LearnerAchievement,
)


async def forget_community(db: AsyncSession, user_id: str) -> None:
    """Remove the learner from other learners' views: friendships, open and past invites they sent, and league
    seats. Invites they accepted stay with the inviter without their id. Idempotent (request time and purge)."""
    await db.execute(delete(Friendship).where(or_(Friendship.user_a == user_id, Friendship.user_b == user_id)))
    await db.execute(delete(FriendInvite).where(FriendInvite.inviter_id == user_id))
    await db.execute(update(FriendInvite).where(FriendInvite.used_by == user_id).values(used_by=None))
    await db.execute(delete(LeagueMember).where(LeagueMember.user_id == user_id))


def purge_event_key(user_id: str) -> str:
    return f"user:{user_id}:purge"


async def request_deletion(db: AsyncSession, user: User, *, now: datetime | None = None) -> None:
    """Delete the account inside one transaction (the caller's session must be idle)."""
    if user.role != "learner":
        raise ApiError(ErrorCode.forbidden, "Reviewer accounts are deactivated by an operator.")
    now = now or auth_sessions.utcnow()
    async with db.begin():
        await auth_sessions.revoke_all(db, user.id, now=now)
        await db.execute(update(User).where(User.id == user.id, User.deleted_at.is_(None)).values(deleted_at=now))
        await forget_community(db, user.id)
        for step in REQUEST_STEPS:
            await step(db, user.id)
        await db.execute(insert(DeletionJob).values(user_id=user.id, requested_at=now)
                         .on_conflict_do_nothing(index_elements=[DeletionJob.user_id],
                                                 index_where=DeletionJob.completed_at.is_(None)))
        await outbox.enqueue(db, event_key=purge_event_key(user.id), kind=PURGE_KIND, payload={"user_id": user.id})


async def purge_user(db: AsyncSession, storage: ObjectStorage, user_id: str) -> dict[str, int]:
    """Delete one deleted user's data (idempotent). Runs inside the caller's transaction."""
    user = await db.get(User, user_id, with_for_update=True)
    if user is None or user.deleted_at is None:
        raise RuntimeError(f"refusing to purge {user_id}: not a deleted user")
    steps: dict[str, int] = {}
    await forget_community(db, user_id)
    for model in PURGED_TABLES:
        result = await db.execute(delete(model).where(model.user_id == user_id))
        steps[model.__tablename__] = int(result.rowcount or 0)  # type: ignore[attr-defined]
    steps["private_objects"] = await asyncio.to_thread(storage.delete_private_prefix, user_prefix(user_id))
    user.display_name = DELETED_DISPLAY_NAME
    user.avatar_key = default_avatar_key()
    user.familiarity = None
    user.goal_anchor = None
    user.timezone = "UTC"
    user.private_profile = True
    user.last_seen_at = None
    job = (await db.execute(select(DeletionJob).where(DeletionJob.user_id == user_id)
                            .order_by(DeletionJob.requested_at.desc()).limit(1))).scalar_one_or_none()
    if job is not None:
        job.steps = {**job.steps, "purge": steps}
        job.completed_at = auth_sessions.utcnow()
    log.info("user purged", extra={"user_id": user_id, "steps": steps})
    return steps


_storage: ObjectStorage | None = None


def configure_storage(storage: ObjectStorage) -> None:
    """Give the purge consumer this process's object storage (API lifespan and worker startup)."""
    global _storage
    _storage = storage


@outbox.consumer(PURGE_KIND)
async def _purge_consumer(db: AsyncSession, event: OutboxEvent) -> None:
    if _storage is None:
        raise RuntimeError("deletion storage is not configured in this process")
    await purge_user(db, _storage, event.payload["user_id"])


async def repurge_all(db: AsyncSession, storage: ObjectStorage) -> int:
    """After a backup restore: purge every user that was ever deleted again (deletion_jobs survives)."""
    user_ids = (await db.execute(select(DeletionJob.user_id).distinct())).scalars().all()
    count = 0
    for user_id in user_ids:
        user = await db.get(User, user_id)
        if user is None:
            continue
        if user.deleted_at is None:  # the restore predates the deletion: delete again
            user.deleted_at = auth_sessions.utcnow()
            await auth_sessions.revoke_all(db, user_id)
        await purge_user(db, storage, user_id)
        count += 1
    return count
