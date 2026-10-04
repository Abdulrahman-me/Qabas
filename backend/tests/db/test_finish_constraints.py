"""Finish-time durability is enforced by PostgreSQL, including cross-session reward claims."""

import pytest
from sqlalchemy.ext.asyncio import AsyncConnection, AsyncSession

from app.models import User
from app.services.learning import finish
from app.services.learning.sessions import SessionIntegrityError
from tests.db import factories as f
from tests.support.db import SESSION_GUARD, UNIQUE_VIOLATION, expect_sqlstate, run

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


async def test_legacy_start_state_is_rejected_without_guessing_or_effects(conn: AsyncConnection) -> None:
    state = await f.learning_slice(conn)
    async with AsyncSession(bind=conn, join_transaction_mode="create_savepoint") as db:
        with pytest.raises(SessionIntegrityError, match="authoritative"):
            await finish.finish(db, User(id=state["user_id"]), state["session_id"], {"duration_ms": 0})
    status = await run(conn, "SELECT status FROM sessions WHERE id=:id", {"id": state["session_id"]})
    assert status.scalar() == "active"
    assert (await run(conn, "SELECT count(*) FROM xp_events")).scalar() == 0
