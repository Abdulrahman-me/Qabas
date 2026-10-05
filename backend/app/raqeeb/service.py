"""Conversation transactions and exact revision 10 projections. Lock order: user → conversation → message."""

from __future__ import annotations

import base64
import uuid
from datetime import datetime, timedelta
from typing import Any

from sqlalchemy import select, tuple_
from sqlalchemy.ext.asyncio import AsyncSession

from app.content import catalog
from app.content.package import VariantContent
from app.content.projection import select_variant, term_card
from app.contract import models as C
from app.errors import ApiError, ErrorCode
from app.models import (
    LearnerMisconception,
    LearnerTerm,
    LearningSession,
    LessonVersion,
    Misconception,
    RaqeebConversation,
    RaqeebMessage,
    User,
)
from app.raqeeb.pipeline import spans_in
from app.services.learning.journey import load_view, soft_lock_details
from app.services.learning.terms import learner_level
from app.services.platform import outbox
from app.services.platform.auth_sessions import utcnow
from app.services.users import iso

DEADLINE = 75
STALL = 90


def new_id(prefix: str) -> str:
    return f"{prefix}_{uuid.uuid4().hex}"


async def active_user(db: AsyncSession, user_id: str) -> User:
    row = (await db.execute(select(User).where(User.id == user_id).with_for_update())).scalar_one_or_none()
    if row is None or row.deleted_at is not None or row.deactivated_at is not None:
        raise ApiError(ErrorCode.unauthorized, "Authentication required.")
    return row


async def conversation(db: AsyncSession, user_id: str, conversation_id: str, *, lock: bool = False
                       ) -> RaqeebConversation:
    query = select(RaqeebConversation).where(RaqeebConversation.id == conversation_id,
                                            RaqeebConversation.user_id == user_id)
    row = (await db.execute(query.with_for_update() if lock else query)).scalar_one_or_none()
    if row is None:
        raise ApiError(ErrorCode.not_found, "Conversation was not found.")
    return row


def project_conversation(row: RaqeebConversation) -> dict[str, Any]:
    return {"conversation_id": row.id, "title": row.title, "context": row.context,
            "created_at": iso(row.created_at), "updated_at": iso(row.updated_at)}


def project_message(row: RaqeebMessage) -> dict[str, Any]:
    value: dict[str, Any] = {"message_id": row.id, "role": row.role, "status": row.status,
                             "created_at": iso(row.created_at)}
    if row.role == "user":
        return value | {"text": row.text, "attachments": row.attachments}
    value["stage"] = row.stage
    if row.status == "failed":
        return value | {"error": row.error}
    if row.status == "completed":
        assert row.completed_at is not None
        value["completed_at"] = iso(row.completed_at)
        value.update({key: getattr(row, key) for key in ("understood_input", "classification", "abstained", "blocks",
            "citations", "terms", "suggested_lessons", "feedback")})
    return value


def expire(row: RaqeebMessage, *, seconds: int = DEADLINE, code: str = "upstream_unavailable") -> bool:
    if row.status == "processing" and row.created_at <= utcnow() - timedelta(seconds=seconds):
        row.status = "failed"
        row.error = {"code": code, "message": "The answer could not finish in time."}
        row.lease = None
        return True
    return False


async def create(db: AsyncSession, user: User, language: str, context: dict[str, Any] | None
                 ) -> tuple[int, dict[str, Any]]:
    user = await active_user(db, user.id)
    snapshot: dict[str, Any] = {}
    if context is not None:
        if set(context) - {"lesson_id", "block_id"} or not context.get("lesson_id"):
            raise ApiError(ErrorCode.validation_error, "Context requires a lesson_id and optional block_id.")
        block_id = context.get("block_id")
        served = (await db.execute(select(LearningSession).where(LearningSession.user_id == user.id,
            LearningSession.lesson_id == context["lesson_id"], LearningSession.kind == "lesson",
            LearningSession.status == "active"))).scalar_one_or_none()
        if served is not None:
            snapshot = served.items_snapshot
            blocks = [{"block_id": b["block_id"], "type": "exercise", "exercise_id": b["exercise"]["exercise_id"]}
                      if b["type"] == "exercise" else b for b in snapshot["items"]]
            title, version_id = snapshot["title"], served.lesson_version_id
        else:
            view = await load_view(db, user)
            lesson = view.lesson(context["lesson_id"])
            if lesson is None:
                raise ApiError(ErrorCode.not_found, "The context lesson is not published for your track.")
            if view.lesson_state(lesson) == "locked":
                raise ApiError(ErrorCode.prerequisite_unmet, "Start with an earlier lesson first.",
                               soft_lock_details(view, lesson))
            version = await catalog.current_version(db, context["lesson_id"])
            assert version is not None
            variants = version.content["variants"][language]
            variant = select_variant(set(variants), user.track)
            content = VariantContent.model_validate(variants[variant])
            blocks, title, version_id = content.blocks, content.title, version.id
        blocks = [b for b in blocks if not block_id or b["block_id"] == block_id]
        if not blocks:
            raise ApiError(ErrorCode.not_found, "The context block was not found.")
        # Stored exercise blocks contain only exercise_id; never send reviewer keys/exercise_versions.
        snapshot = {"version_id": str(version_id), "title": title, "blocks": blocks}
    now = utcnow()
    row = RaqeebConversation(id=new_id("conv"), user_id=user.id, title=None, context=context,
        context_snapshot=snapshot, language=language, track=user.track, created_at=now, updated_at=now)
    db.add(row)
    await db.flush()
    return 201, project_conversation(row)


async def profile_snapshot(db: AsyncSession, user: User, conv: RaqeebConversation) -> dict[str, Any]:
    level = await learner_level(db, user.id)
    states = {r.term_id: r.state for r in (await db.execute(select(LearnerTerm).where(
        LearnerTerm.user_id == user.id))).scalars()}
    cards: dict[str, Any] = {}
    for lesson in await catalog.published_lessons(db):
        version = await db.get(LessonVersion, lesson.lesson_version_id)
        assert version is not None
        variants = version.content["variants"][conv.language]
        variant = select_variant(set(variants), conv.track)
        title = VariantContent.model_validate(variants[variant]).title
        for raw in version.content["glossary"]:
            record = C.StoredGlossaryTerm.model_validate(raw)
            cards.setdefault(record.term_id, term_card(record, conv.language, level=level,
                state=states.get(record.term_id, "new"), lesson_title=title))
    titles = (await db.execute(select(Misconception.title).join(LearnerMisconception,
        LearnerMisconception.misconception_id == Misconception.id).where(
        LearnerMisconception.user_id == user.id, LearnerMisconception.status == "active"))).scalars()
    profile = {"level": level, "track": conv.track, "language": conv.language,
        "known_terms": [c["text"] for c in cards.values() if c["state"] in ("learning", "mastered")],
        "active_misconceptions": [t.get(conv.language, "") for t in titles]}
    return {"profile": profile, "cards": cards}


def answer_text(row: RaqeebMessage) -> str:
    if row.role == "user":
        return row.text or ""
    text = [s.get("text", "") for s in spans_in(row.blocks or [])]
    for block in row.blocks or []:
        if block["type"] == "evidence":
            evidence = block["evidence"]
            text.append(evidence["quran"]["text_uthmani"] if evidence["kind"] == "quran"
                        else evidence["hadith"]["text_ar"])
        elif block["type"] == "verification":
            for item in block["items"]:
                text += [item["quote_text"], item["status"]]
                if item["hadith_grade"]:
                    text.append(item["hadith_grade"]["grade_label"])
    return " ".join(text)


async def submit(db: AsyncSession, user: User, conversation_id: str, text: str,
                 rate_limit: Any) -> tuple[int, dict[str, Any]]:
    user = await active_user(db, user.id)
    conv = await conversation(db, user.id, conversation_id, lock=True)
    previous = (await db.execute(select(RaqeebMessage).where(
        RaqeebMessage.conversation_id == conv.id).order_by(RaqeebMessage.created_at.desc(), RaqeebMessage.role,
                                                         RaqeebMessage.id.desc()).with_for_update())).scalars().all()
    for row in previous:
        expire(row)
        if row.status == "processing":
            raise ApiError(ErrorCode.answer_in_progress, "An answer is already in progress.")
    await db.flush()  # release partial unique processing slot before inserting the replacement
    await rate_limit()
    snapshot = await profile_snapshot(db, user, conv)
    snapshot["context"] = conv.context_snapshot
    snapshot["history"] = [{"role": r.role, "text": answer_text(r), "understood_input": r.understood_input}
                           for r in reversed(previous[:6])]
    now = utcnow()
    common = {"conversation_id": conv.id, "created_at": now, "attachments": [], "trace": {}, "input_snapshot": {}}
    original = RaqeebMessage(id=new_id("msg_u"), role="user", status="received", stage="received", text=text,
                             **common)
    db.add(original)
    await db.flush()
    assistant = RaqeebMessage(id=new_id("msg_a"), role="assistant", status="processing", stage="received",
                              reply_to=original.id, **(common | {"input_snapshot": snapshot}))
    db.add(assistant)
    conv.updated_at = now
    await db.flush()
    await outbox.enqueue(db, event_key=f"raqeeb:{assistant.id}:requested", kind="raqeeb.requested",
                         payload={"message_id": assistant.id})
    return 202, {"user_message": project_message(original), "assistant_message": project_message(assistant)}


async def detail(db: AsyncSession, user_id: str, conversation_id: str) -> dict[str, Any]:
    conv = await conversation(db, user_id, conversation_id, lock=True)
    messages = (await db.execute(select(RaqeebMessage).where(RaqeebMessage.conversation_id == conv.id)
        .order_by(RaqeebMessage.created_at, RaqeebMessage.role.desc(), RaqeebMessage.id).with_for_update())).scalars()
    values = []
    for message in messages:
        expire(message)
        values.append(project_message(message))
    return {"conversation": project_conversation(conv), "messages": values}


async def get_message(db: AsyncSession, user_id: str, message_id: str) -> RaqeebMessage:
    row = (await db.execute(select(RaqeebMessage).join(RaqeebConversation,
        RaqeebMessage.conversation_id == RaqeebConversation.id).where(RaqeebMessage.id == message_id,
        RaqeebConversation.user_id == user_id, RaqeebMessage.role == "assistant").with_for_update(
            of=RaqeebMessage))).scalar_one_or_none()
    if row is None:
        raise ApiError(ErrorCode.not_found, "Message was not found.")
    expire(row)
    return row


async def page(db: AsyncSession, user_id: str, cursor: str | None, limit: int) -> dict[str, Any]:
    if not 1 <= limit <= 50:
        raise ApiError(ErrorCode.validation_error, "Invalid limit.", {"field": "limit"})
    query = select(RaqeebConversation).where(RaqeebConversation.user_id == user_id)
    if cursor:
        try:
            if len(cursor) > 200:
                raise ValueError
            stamp, identifier = base64.b64decode(cursor.encode(), altchars=b"-_", validate=True).decode().split("|", 1)
            timestamp = datetime.fromisoformat(stamp)
            if timestamp.tzinfo is None or not identifier.startswith("conv_"):
                raise ValueError
        except (ValueError, UnicodeError):
            raise ApiError(ErrorCode.validation_error, "Invalid cursor.", {"field": "cursor"}) from None
        query = query.where(tuple_(RaqeebConversation.updated_at, RaqeebConversation.id) <
                            tuple_(timestamp, identifier))
    rows = (await db.execute(query.order_by(RaqeebConversation.updated_at.desc(),
        RaqeebConversation.id.desc()).limit(limit + 1))).scalars().all()
    items = []
    for row in rows[:limit]:
        recent = (await db.execute(select(RaqeebMessage).where(RaqeebMessage.conversation_id == row.id)
            .order_by(RaqeebMessage.created_at.desc(), RaqeebMessage.id).limit(1))).scalar_one_or_none()
        items.append({"conversation_id": row.id, "title": row.title,
                      "last_message_preview": answer_text(recent)[:200] if recent else "",
                      "updated_at": iso(row.updated_at)})
    cursor = None
    if len(rows) > limit:
        last = rows[limit - 1]
        cursor = base64.urlsafe_b64encode(f"{last.updated_at.isoformat()}|{last.id}".encode()).decode()
    return {"items": items, "next_cursor": cursor}


async def feedback(db: AsyncSession, user_id: str, message_id: str, body: Any) -> None:
    row = await get_message(db, user_id, message_id)
    if row.status != "completed":
        raise ApiError(ErrorCode.validation_error, "Only completed answers accept feedback.")
    if body.comment is not None and len(body.comment) > 2000:
        raise ApiError(ErrorCode.validation_error, "Feedback comment is too long.")
    row.feedback, row.feedback_reason, row.feedback_comment = body.rating, body.reason, body.comment
