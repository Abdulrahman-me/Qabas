"""Specialist decisions on imported gold lessons (factory §13.6-13.7; the reviewer console arrives in Phase 13).

    uv run python scripts/review_gold.py show --lesson les_u3_l2 [--version 1]
    uv run python scripts/review_gold.py approve --lesson les_u3_l2 --version 1 --digest <sha256> --reviewer <email>
    uv run python scripts/review_gold.py reject  --lesson les_u3_l2 --version 1 --digest <sha256> --reviewer <email>

``approve`` is the Gate 2-equivalent approval: the reviewer authenticates with their own password (prompted,
never an argument), confirms the exact content digest they reviewed, and the approval record and publication
commit together. A digest that differs from the stored version is refused, so nothing is approved blind.
"""

from __future__ import annotations

import argparse
import asyncio
import getpass
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from sqlalchemy import func, select

from app.config import get_settings
from app.content.gold import GoldError, approve_and_publish, authenticate_reviewer, reject, version_of
from app.content.validation import ContentValidationError
from app.models import LessonVersion
from app.runtime import Resources


async def run(args: argparse.Namespace, password: str | None) -> int:
    settings = get_settings()
    resources = Resources.create(settings)
    try:
        async with resources.sessionmaker() as db, db.begin():
            if args.command == "show":
                version = args.version or await db.scalar(select(func.max(LessonVersion.version)).where(
                    LessonVersion.lesson_id == args.lesson))
                if version is None:
                    raise GoldError(f"{args.lesson} has no stored version")
                pending = await version_of(db, args.lesson, version)
                state = "published" if pending.published else "unpublished"
                print(f"{pending.lesson_id} v{pending.version} ({pending.origin}, {state})")
                print(f"digest {pending.content_sha256}")
                return 0
            assert password is not None
            reviewer_id = await authenticate_reviewer(db, args.reviewer, password)
            if args.command == "approve":
                decision = await approve_and_publish(db, settings, reviewer_id=reviewer_id, lesson_id=args.lesson,
                                                     version=args.version, reviewed_digest=args.digest)
                print(f"{args.lesson} v{args.version} approved and published (decision {decision})")
            else:
                decision = await reject(db, reviewer_id=reviewer_id, lesson_id=args.lesson, version=args.version,
                                        reviewed_digest=args.digest, reason=args.reason)
                print(f"{args.lesson} v{args.version} rejected (decision {decision})")
        return 0
    except GoldError as exc:
        print(exc, file=sys.stderr)
        return 1
    except ContentValidationError as exc:
        print("publication refused:", file=sys.stderr)
        for issue in exc.issues:
            print(f"  [{issue.code}] {issue.message}", file=sys.stderr)
        return 1
    finally:
        await resources.close()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command", required=True)
    show = commands.add_parser("show")
    show.add_argument("--lesson", required=True)
    show.add_argument("--version", type=int)
    for name in ("approve", "reject"):
        decide = commands.add_parser(name)
        decide.add_argument("--lesson", required=True)
        decide.add_argument("--version", type=int, required=True)
        decide.add_argument("--digest", required=True)
        decide.add_argument("--reviewer", required=True, help="the reviewer's email; the password is prompted")
        if name == "reject":
            decide.add_argument("--reason", help="why the version is rejected (kept in the decision record)")
    args = parser.parse_args()
    password = None if args.command == "show" else getpass.getpass("Reviewer password: ")
    return asyncio.run(run(args, password))


if __name__ == "__main__":
    sys.exit(main())
