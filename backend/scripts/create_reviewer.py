"""Operator command: create (or re-key) a reviewer account. The password is prompted, never passed
on the command line or stored in the environment (backend §5, O-11).

Usage (from backend/): uv run python scripts/create_reviewer.py --email reviewer@example.org --name "Reviewer"
"""

from __future__ import annotations

import argparse
import asyncio
import getpass
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.db.engine import make_engine
from app.db.ids import new_id
from app.models import User
from app.registries import default_avatar_key
from app.services.platform import auth_sessions, passwords
from app.services.users import validate_timezone


async def create(email: str, name: str, timezone: str, password: str) -> str:
    engine = make_engine(get_settings().database_url)
    try:
        async with AsyncSession(engine, expire_on_commit=False) as db, db.begin():
            user = (await db.execute(select(User).where(func.lower(User.email) == email))).scalar_one_or_none()
            if user is not None and user.role != "reviewer":
                raise SystemExit("that email belongs to a non-reviewer account")
            if user is None:
                user = User(id=new_id("usr"), display_name=name, avatar_key=default_avatar_key(), role="reviewer",
                            timezone=timezone, onboarding_completed=True, email=email,
                            password_hash=passwords.hash_password(password))
                db.add(user)
                action = "created"
            else:
                user.password_hash = passwords.hash_password(password)
                user.display_name = name
                user.deactivated_at = None
                await auth_sessions.revoke_all(db, user.id)  # a re-key signs out existing sessions
                action = "updated"
        return f"{action} reviewer {user.id} <{email}>"
    finally:
        await engine.dispose()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--email", required=True)
    parser.add_argument("--name", required=True, help="display name shown to learners as the reviewer")
    parser.add_argument("--timezone", default="Asia/Riyadh")
    args = parser.parse_args()
    email = args.email.strip().lower()
    if "@" not in email:
        parser.error("invalid email")
    if not 2 <= len(args.name.strip()) <= 60:
        parser.error("name must be 2-60 characters")
    timezone = validate_timezone(args.timezone)
    password = getpass.getpass("Password (min 12 characters): ")
    if getpass.getpass("Repeat password: ") != password:
        parser.error("passwords do not match")
    try:
        print(asyncio.run(create(email, args.name.strip(), timezone, password)))
    except ValueError as exc:
        parser.error(str(exc))
    return 0


if __name__ == "__main__":
    sys.exit(main())
