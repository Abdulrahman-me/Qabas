"""Operator command: after restoring a database backup, purge every deleted account again before
reopening traffic (data model: data protection; OPERATIONS: backups). ``deletion_jobs`` survives
purges, so the list of deleted users is always complete.

Usage (from backend/): uv run python scripts/repurge_deleted_users.py
"""

from __future__ import annotations

import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.config import get_settings
from app.runtime import Resources
from app.services.platform import deletion


async def main() -> int:
    resources = Resources.create(get_settings())
    try:
        async with resources.sessionmaker() as db, db.begin():
            count = await deletion.repurge_all(db, resources.storage)
    finally:
        await resources.close()
    print(f"re-purged {count} deleted account(s)")
    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
