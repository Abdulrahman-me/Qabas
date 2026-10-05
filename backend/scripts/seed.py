"""Seed the curriculum structure (SEED_AND_IMPORT §15).

    uv run python scripts/seed.py                    # production structure from content/curriculum.yaml
    uv run python scripts/seed.py --check            # validate curriculum.yaml only (no database)
    uv run python scripts/seed.py --test-curriculum  # dev/test only: the contract's synthetic test curriculum

The production seed creates units, track framing, curriculum slots and the concept graph. It creates no lesson
content: a slot becomes learner-facing only when an approved lesson version for it is published. Units without
a published lesson are ``coming_soon``. Re-running is a no-op when nothing changed; changes that would move an
occupied slot or drop curriculum that holds lessons are refused.

Every run also syncs the seeded community configuration (league tiers and achievements) with
``content/registries.json`` and, only when ``SYNTHETIC_LEAGUE_MEMBERS=true`` (demo/staging; refused in production,
P-01), creates the synthetic league members of ``content/synthetic_league_members.json``.

The test curriculum and the production curriculum use different unit ids and positions; load the test curriculum
into its own (dev/test) database.
"""

from __future__ import annotations

import argparse
import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.config import get_settings
from app.content.curriculum import CurriculumError, load_curriculum
from app.content.store import apply_curriculum
from app.content.test_curriculum import load_test_curriculum
from app.content.validation import ContentValidationError
from app.runtime import Resources
from app.services.community import seeding, synthetic


async def run(test_curriculum: bool) -> int:
    settings = get_settings()
    resources = Resources.create(settings)
    try:
        async with resources.sessionmaker() as db, db.begin():
            if test_curriculum:
                result = await load_test_curriculum(db, settings)
                print(f"test curriculum: {result['lessons']} lessons, {result['published']} newly published, "
                      f"{result['scenes']} scene version(s)")
            else:
                report = await apply_curriculum(db, load_curriculum())
                print("curriculum:", "unchanged" if not report.changed else
                      f"created {report.created}, updated {report.updated}, removed {report.removed}")
            print("community registries:", await seeding.sync_registries(db))
            if settings.synthetic_league_members:
                print(f"synthetic league members: {await synthetic.seed(db)}")
    except (CurriculumError, ContentValidationError, seeding.RegistryDrift) as exc:
        print(exc, file=sys.stderr)
        return 1
    finally:
        await resources.close()
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true", help="validate content/curriculum.yaml and exit")
    parser.add_argument("--test-curriculum", action="store_true", help="load the synthetic test curriculum")
    args = parser.parse_args()
    if args.check:
        try:
            curriculum = load_curriculum()
        except CurriculumError as exc:
            print(exc, file=sys.stderr)
            return 1
        print(f"curriculum.yaml OK: {len(curriculum.units)} units, {len(curriculum.slots())} lesson slots, "
              f"{len(curriculum.concepts)} concepts")
        return 0
    return asyncio.run(run(args.test_curriculum))


if __name__ == "__main__":
    sys.exit(main())
