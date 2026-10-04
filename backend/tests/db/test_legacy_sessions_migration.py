"""Migration 0004 refuses to run over legacy active sessions until an operator abandons them (D-76)."""

from __future__ import annotations

import asyncio
import json

import asyncpg
import pytest
from alembic import command

from scripts.abandon_legacy_sessions import abandon_legacy
from tests.support.db import alembic_config, asyncpg_url, truncate_all

pytestmark = pytest.mark.integration


async def _legacy_session(url: str) -> None:
    conn = await asyncpg.connect(asyncpg_url(url))
    try:
        await conn.execute("INSERT INTO users (id, display_name, avatar_key, timezone) "
                           "VALUES ('usr_legacy', 'Traveler 1', 'traveler_01', 'UTC')")
        await conn.execute(
            "INSERT INTO sessions (id, user_id, kind, mode, feedback_mode, language, variant, items_snapshot, "
            "served_exercises, contract_revision) VALUES ('ses_legacy', 'usr_legacy', 'review', 'cards', "
            "'immediate', 'en', 'explorer', $1::jsonb, '[]'::jsonb, 10)", json.dumps({"items": []}))
    finally:
        await conn.close()


async def _status(url: str) -> str:
    conn = await asyncpg.connect(asyncpg_url(url))
    try:
        return str(await conn.fetchval("SELECT status FROM sessions WHERE id = 'ses_legacy'"))
    finally:
        await conn.close()


def test_legacy_active_sessions_block_the_upgrade_until_abandoned(migrated_url: str) -> None:
    config = alembic_config(migrated_url)
    asyncio.run(truncate_all(migrated_url))
    command.downgrade(config, "0003")
    try:
        asyncio.run(_legacy_session(migrated_url))
        with pytest.raises(Exception, match=r"active session.*abandon_legacy_sessions"):
            command.upgrade(config, "head")
        assert asyncio.run(abandon_legacy(migrated_url, confirm=False)) == ["ses_legacy"]
        assert asyncio.run(_status(migrated_url)) == "active"            # listing changes nothing
        assert asyncio.run(abandon_legacy(migrated_url, confirm=True)) == ["ses_legacy"]
        assert asyncio.run(_status(migrated_url)) == "abandoned"
        command.upgrade(config, "head")
        assert asyncio.run(abandon_legacy(migrated_url, confirm=True)) == []
    finally:
        asyncio.run(truncate_all(migrated_url))
        command.upgrade(config, "head")
