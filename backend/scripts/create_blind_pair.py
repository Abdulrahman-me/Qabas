"""Create a blind-test pair and backfill learning metrics (factory §14; Phase 15).

    uv run python scripts/create_blind_pair.py --gold <lesson_id> --generated <lesson_id>
    uv run python scripts/create_blind_pair.py --refresh-metrics

A pair compares the current published versions of a gold (handwritten) lesson and a factory-generated lesson; the
gold side is drawn at random and never shown to reviewers. ``--refresh-metrics`` recomputes every learner's metric
facts from the authoritative tables (the ``session.finished`` subscriber keeps them current afterwards).
"""

from __future__ import annotations

import argparse
import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.config import get_settings
from app.runtime import Resources
from app.services import blind_test, metrics


async def run(args: argparse.Namespace) -> int:
    resources = Resources.create(get_settings())
    try:
        async with resources.sessionmaker() as db, db.begin():
            if args.refresh_metrics:
                print(f"refreshed metric facts for {await metrics.refresh_all(db)} learners")
                return 0
            pair = await blind_test.create_pair(db, gold=args.gold, generated=args.generated)
            print(f"created {pair.id}")
            return 0
    except blind_test.BlindTestError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    finally:
        await resources.close()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--gold")
    parser.add_argument("--generated")
    parser.add_argument("--refresh-metrics", action="store_true")
    args = parser.parse_args()
    if not args.refresh_metrics and not (args.gold and args.generated):
        parser.error("--gold and --generated are required (or --refresh-metrics)")
    return asyncio.run(run(args))


if __name__ == "__main__":
    sys.exit(main())
