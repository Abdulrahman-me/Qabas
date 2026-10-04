"""Synthetic, neutral rows for database tests (no real lesson content).

Each helper inserts the minimum valid row through plain SQL and returns its key, so constraint
tests can build exactly the state they need.
"""

from __future__ import annotations

import hashlib
import json
from typing import Any

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncConnection

from app.db.ids import new_id


def digest(value: Any) -> str:
    return hashlib.sha256(json.dumps(value, sort_keys=True).encode()).hexdigest()


async def _insert(conn: AsyncConnection, table: str, values: dict[str, Any], returning: str = "id") -> Any:
    columns = ", ".join(values)
    params = ", ".join(f"CAST(:{k} AS jsonb)" if isinstance(v, dict | list) and not k.endswith("_ids")
                       and k not in ("tracks", "variants", "required_capabilities") else f":{k}"
                       for k, v in values.items())
    bound = {k: json.dumps(v) if isinstance(v, dict | list) and not k.endswith("_ids")
             and k not in ("tracks", "variants", "required_capabilities") else v for k, v in values.items()}
    result = await conn.execute(text(f"INSERT INTO {table} ({columns}) VALUES ({params}) RETURNING {returning}"),
                                bound)
    return result.scalar_one()


async def user(conn: AsyncConnection, **overrides: Any) -> str:
    values = {"id": new_id("usr"), "display_name": "Traveler 1", "avatar_key": "traveler_01",
              "timezone": "Asia/Riyadh", **overrides}
    return str(await _insert(conn, "users", values))


async def unit(conn: AsyncConnection, index: int = 1, **overrides: Any) -> str:
    values = {"id": f"unit_t{index}", "index": index, "title": {"en": {"explorer": "Unit"}},
              "subtitle": {"en": {"explorer": "Sub"}}, "tracks": ["explorer", "new_muslim"], **overrides}
    return str(await _insert(conn, "units", values))


async def concept(conn: AsyncConnection, unit_id: str, suffix: str = "a") -> str:
    return str(await _insert(conn, "concepts", {"id": f"con_t_{suffix}", "unit_id": unit_id,
                                                 "title": {"en": "Concept"}}))


async def slot(conn: AsyncConnection, unit_id: str, index: int = 0) -> str:
    """A curriculum slot; every lesson occupies one (decision D-30)."""
    values = {"lesson_id": f"les_t_{unit_id}_{index}", "unit_id": unit_id, "index": index,
              "working_title": {"en": "Slot"}}
    return str(await _insert(conn, "curriculum_slots", values, returning="lesson_id"))


async def lesson(conn: AsyncConnection, unit_id: str, index: int = 0, **overrides: Any) -> str:
    lesson_id = await slot(conn, unit_id, index)
    values = {"id": lesson_id, "unit_id": unit_id, "index": index, "lesson_type": "concept",
              "estimated_minutes": 8, **overrides}
    return str(await _insert(conn, "lessons", values))


async def lesson_version(conn: AsyncConnection, lesson_id: str, version: int = 1, *, published: bool = False) -> Any:
    content = {"en": {"explorer": {"title": "Lesson", "blocks": []}}}
    values: dict[str, Any] = {"lesson_id": lesson_id, "version": version, "origin": "test_fixture",
                              "plan": {"central_question": "Why?"},
                              "content": content, "content_sha256": digest(content), "contract_revision": 10}
    lv_id = await _insert(conn, "lesson_versions", values)
    if published:
        await conn.execute(text("UPDATE lesson_versions SET published_at = now() WHERE id = :id"), {"id": lv_id})
    return lv_id


async def exercise(conn: AsyncConnection, unit_id: str, lesson_id: str | None, *, purpose: str = "lesson",
                   type_: str = "multiple_choice", suffix: str = "1") -> str:
    values = {"id": f"ex_t_{suffix}", "lesson_id": lesson_id, "unit_id": unit_id, "purpose": purpose,
              "type": type_}
    return str(await _insert(conn, "exercises", values))


async def exercise_version(conn: AsyncConnection, exercise_id: str, version: int = 1, *,
                           published: bool = False) -> None:
    content = {"en": {"prompt": [{"type": "text", "text": "Pick one."}]}}
    values = {"exercise_id": exercise_id, "version": version, "content": content,
              "scoring": {"accuracy": True, "combo": True, "layer": "understand"},
              "answer_key": {"option_id": "opt_b"}, "content_sha256": digest(content)}
    await _insert(conn, "exercise_versions", values, returning="exercise_id")
    if published:
        await conn.execute(text("UPDATE exercise_versions SET published_at = now() "
                                "WHERE exercise_id = :e AND version = :v"), {"e": exercise_id, "v": version})


async def lesson_session(conn: AsyncConnection, user_id: str, lesson_id: str, unit_id: str, lv_id: Any,
                         **overrides: Any) -> str:
    values = {"id": new_id("ses"), "user_id": user_id, "kind": "lesson", "lesson_id": lesson_id,
              "lesson_version_id": lv_id, "unit_id": unit_id, "feedback_mode": "immediate", "language": "en",
              "variant": "explorer", "items_snapshot": {"items": []}, "served_exercises": [],
              "learning_snapshot": {"mastery": {}, "due": {}, "term_concepts": {}},
              "contract_revision": 10, **overrides}
    return str(await _insert(conn, "sessions", values))


async def learning_slice(conn: AsyncConnection) -> dict[str, Any]:
    """A user, unit, lesson with a published version and a published exercise, and an active session."""
    user_id = await user(conn)
    unit_id = await unit(conn)
    lesson_id = await lesson(conn, unit_id)
    lv_id = await lesson_version(conn, lesson_id, published=True)
    exercise_id = await exercise(conn, unit_id, lesson_id)
    await exercise_version(conn, exercise_id, published=True)
    session_id = await lesson_session(conn, user_id, lesson_id, unit_id, lv_id,
                                      served_exercises=[{"exercise_id": exercise_id, "version": 1}])
    return {"user_id": user_id, "unit_id": unit_id, "lesson_id": lesson_id, "lesson_version_id": lv_id,
            "exercise_id": exercise_id, "session_id": session_id}
