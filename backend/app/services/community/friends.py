"""Friends: invite codes, accept, list and remove (backend §10.4, API §6.9).

* A code is ``QBS-`` + 4 Crockford base32 characters, single use, valid 7 days, unique among unexpired invites:
  creation takes a per-code advisory lock and regenerates on collision.
* The 4-character space is guessable, so accept allows at most 10 failed codes per learner per hour and 100 per
  client address per day (``429``); only failed codes count. ``already_friends`` leaves the invite unused.
* Accept locks the invite row, so a code is consumed exactly once; friendships are one ordered row per pair, so
  two learners accepting each other's codes at once end with one friendship and one ``already_friends``.
* Friends with ``private_profile`` are listed with ``xp_week`` and ``streak_current`` null; ``online`` means the
  friend was seen in the last 60 s. Synthetic members and the challenge bot have no invites and cannot be added.
"""

from __future__ import annotations

import re
import secrets
from datetime import datetime, timedelta
from typing import Any

from sqlalchemy import Subquery, delete, func, select, text, union_all
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.contract import models as C
from app.db.ids import CROCKFORD, new_id
from app.errors import ApiError, ErrorCode
from app.models import FriendInvite, Friendship, User, XpEvent
from app.services.learning import progress, xp
from app.services.learning.profile import page_args
from app.services.users import iso

INVITE_TTL = timedelta(days=7)
ONLINE_WINDOW = timedelta(seconds=60)
CODE = re.compile(r"QBS-[0-9A-HJKMNP-TV-Z]{4}")
SHARE_TEXT = {"ar": "انضم إليّ في قبس! استخدم الرمز {code}", "en": "Join me on Qabas! Use the code {code}"}
MAX_CODE_ATTEMPTS = 50


def new_code() -> str:
    return "QBS-" + "".join(secrets.choice(CROCKFORD) for _ in range(4))


def normalize_code(raw: str) -> str | None:
    """Upper-case and trim; Crockford's readable aliases (O→0, I/L→1) are accepted as typed."""
    code = raw.strip().upper().translate(str.maketrans("OIL", "011"))
    if not code.startswith("QBS-") and len(code) == 4:
        code = "QBS-" + code
    return code if CODE.fullmatch(code) else None


def pair(a: str, b: str) -> tuple[str, str]:
    return (a, b) if a < b else (b, a)


def can_befriend(user: User | None) -> bool:
    return (user is not None and user.role == "learner" and not user.is_bot and not user.is_synthetic
            and user.deleted_at is None)


# ------------------------------------------------------------------------------------------- invites

async def create_invite(db: AsyncSession, user: User, lang: str, now: datetime) -> dict[str, Any]:
    for _ in range(MAX_CODE_ATTEMPTS):
        code = new_code()
        await db.execute(text("SELECT pg_advisory_xact_lock(hashtextextended(:k, 0))"), {"k": f"invite:{code}"})
        taken = await db.scalar(select(func.count()).select_from(FriendInvite).where(
            FriendInvite.code == code, FriendInvite.expires_at > now))
        if not taken:
            invite = FriendInvite(id=new_id("inv"), code=code, inviter_id=user.id, created_at=now,
                                  expires_at=now + INVITE_TTL)
            db.add(invite)
            await db.flush()
            body: dict[str, Any] = C.Invite(
                invite_id=invite.id, code=code, share_text=SHARE_TEXT[lang].format(code=code),
                expires_at=iso(invite.expires_at)).model_dump(mode="json")
            return body
    raise RuntimeError("no free invite code after repeated attempts")   # ~1M codes; practically unreachable


class InvalidInvite(Exception):
    """A code that does not name a usable invite (counts as a failed attempt)."""


async def accept(db: AsyncSession, user: User, raw_code: str, now: datetime) -> C.Friend:
    """Consume the invite and create the friendship (caller's transaction). Raises :class:`InvalidInvite`."""
    code = normalize_code(raw_code)
    if code is None:
        raise InvalidInvite
    invite = (await db.execute(select(FriendInvite).where(FriendInvite.code == code, FriendInvite.expires_at > now)
                               .with_for_update())).scalar_one_or_none()
    if invite is None or invite.used_at is not None:
        raise InvalidInvite
    inviter = await db.get(User, invite.inviter_id)
    if invite.inviter_id == user.id:
        raise ApiError(ErrorCode.invite_invalid, "This is your own invite code.")
    if not can_befriend(inviter):
        raise InvalidInvite
    assert inviter is not None
    a, b = pair(user.id, inviter.id)
    created = (await db.execute(insert(Friendship).values(user_a=a, user_b=b, created_at=now)
                                .on_conflict_do_nothing().returning(Friendship.user_a))).scalar_one_or_none()
    if created is None:
        raise ApiError(ErrorCode.already_friends, "You are already friends.")
    invite.used_by, invite.used_at = user.id, now
    await db.flush()
    return await friend_item(db, inviter, now)


# ------------------------------------------------------------------------------------------- friends

async def friend_item(db: AsyncSession, friend: User, now: datetime) -> C.Friend:
    online = friend.last_seen_at is not None and friend.last_seen_at >= now - ONLINE_WINDOW
    if friend.private_profile:
        weekly = streak = None
    else:
        weekly = int(await db.scalar(select(func.coalesce(func.sum(XpEvent.xp), 0)).where(
            XpEvent.user_id == friend.id, XpEvent.week_key == xp.week_key(now))) or 0)
        streak = (await progress.streak(db, friend, xp.local_date(now, friend.timezone))).current
    return C.Friend(user_id=friend.id, display_name=friend.display_name, xp_week=weekly, streak_current=streak,
                    online=online, avatar_key=friend.avatar_key)


def friend_ids(user_id: str) -> Subquery:
    return union_all(select(Friendship.user_b.label("friend_id")).where(Friendship.user_a == user_id),
                     select(Friendship.user_a.label("friend_id")).where(Friendship.user_b == user_id)).subquery()


async def page(db: AsyncSession, user: User, cursor: str | None, limit: int, now: datetime) -> dict[str, object]:
    page_args(cursor, limit, "usr_")
    ids = friend_ids(user.id)
    query = select(User).join(ids, ids.c.friend_id == User.id).where(User.deleted_at.is_(None))
    if cursor is not None:
        query = query.where(User.id > cursor)
    rows = list((await db.execute(query.order_by(User.id).limit(limit + 1))).scalars())
    more = len(rows) > limit
    rows = rows[:limit]
    items = [(await friend_item(db, friend, now)).model_dump(mode="json") for friend in rows]
    return {"items": items, "next_cursor": rows[-1].id if more else None}


async def remove(db: AsyncSession, user: User, friend_id: str) -> None:
    """Unfriend (idempotent: removing someone who is not a friend is a no-op)."""
    a, b = pair(user.id, friend_id)
    await db.execute(delete(Friendship).where(Friendship.user_a == a, Friendship.user_b == b))


async def are_friends(db: AsyncSession, a: str, b: str) -> bool:
    x, y = pair(a, b)
    return await db.get(Friendship, (x, y)) is not None

