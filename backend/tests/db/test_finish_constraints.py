"""Finish-time durability is enforced by PostgreSQL, including cross-session reward claims."""

from datetime import UTC, datetime

import pytest
from sqlalchemy.exc import DBAPIError
from sqlalchemy.ext.asyncio import AsyncConnection

from tests.db import factories as f
from tests.support.db import CHECK_VIOLATION, SESSION_GUARD, UNIQUE_VIOLATION, expect_sqlstate, run, sqlstate

pytestmark = pytest.mark.integration


async def test_reward_key_is_unique_across_distinct_sessions(conn: AsyncConnection) -> None:
    uid = await f.user(conn)
    statement = """INSERT INTO xp_events(user_id,reason,xp,ref_type,ref_id,reward_key,week_key,local_date)
                   VALUES(:u,'lesson_complete',10,'session',:ref,'lesson:les_a','2026-W41','2026-10-04')"""
    await run(conn, statement, {"u": uid, "ref": "ses_a"})
    await expect_sqlstate(conn, UNIQUE_VIOLATION, statement, {"u": uid, "ref": "ses_b"})


async def test_private_start_snapshot_cannot_be_rewritten(conn: AsyncConnection) -> None:
    state = await f.learning_slice(conn)
    sid = state["session_id"]
    await expect_sqlstate(conn, SESSION_GUARD,
                          "UPDATE sessions SET learning_snapshot='{}'::jsonb WHERE id=:id", {"id": sid})


async def test_an_active_session_always_has_its_learning_snapshot(conn: AsyncConnection) -> None:
    # D-76: a snapshot-less active session could never finish truthfully, so the database refuses it;
    # finished or abandoned rows without one (history from before migration 0003) remain valid.
    state = await f.learning_slice(conn)
    args = (conn, state["user_id"], state["lesson_id"], state["unit_id"], state["lesson_version_id"])
    with pytest.raises(DBAPIError) as exc:
        async with conn.begin_nested():
            await f.lesson_session(*args, learning_snapshot=None, id="ses_legacy_active")
    assert sqlstate(exc.value) == CHECK_VIOLATION
    await f.lesson_session(*args, learning_snapshot=None, status="abandoned",
                           abandoned_at=datetime(2026, 10, 4, 9, tzinfo=UTC))
