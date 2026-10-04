"""Abandon active sessions that started before the private learning snapshot existed (migration 0004).

    uv run python scripts/abandon_legacy_sessions.py            # list them (no change)
    uv run python scripts/abandon_legacy_sessions.py --confirm  # abandon them

Such a session cannot be finished truthfully: its start mastery and review due dates were never recorded and
are not reconstructed. Abandoning is the defined, honest outcome (API §6.5): effects its recorded answers
already applied (mastery, misconceptions, recitation XP) stay, finish effects never happen, and the learner
starts the activity again. Run it against a database at revision 0003, then ``alembic upgrade head``.
Every abandoned session id is printed for the operator's record.
"""

from __future__ import annotations

import argparse
import asyncio
import sys
from pathlib import Path

import asyncpg

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.config import get_settings

LEGACY = "SELECT id, user_id, kind, started_at FROM sessions WHERE status = 'active' AND learning_snapshot IS NULL " \
         "ORDER BY started_at, id"


async def abandon_legacy(database_url: str, *, confirm: bool) -> list[str]:
    """Return the legacy active session ids; abandon them when ``confirm``."""
    conn = await asyncpg.connect(database_url.replace("postgresql+asyncpg://", "postgresql://", 1))
    try:
        async with conn.transaction():
            rows = await conn.fetch(LEGACY + " FOR UPDATE")
            if confirm and rows:
                await conn.execute("UPDATE sessions SET status = 'abandoned', abandoned_at = now() "
                                   "WHERE id = ANY($1::text[])", [r["id"] for r in rows])
        return [r["id"] for r in rows]
    finally:
        await conn.close()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--confirm", action="store_true", help="abandon the listed sessions")
    args = parser.parse_args()
    ids = asyncio.run(abandon_legacy(get_settings().database_url, confirm=args.confirm))
    for session_id in ids:
        print(("abandoned " if args.confirm else "legacy active ") + session_id)
    print(f"{len(ids)} legacy active session(s)" + (" abandoned" if args.confirm and ids else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
