"""Inventory before bounded Factory admission; no automatic Gate 1/2 approval.

    python scripts/curriculum_batch.py inventory --output .private/content/inventory.json
    python scripts/curriculum_batch.py enqueue --unit unit_0 --reviewer-id usr_... --lesson-type concept --limit 1

Run with the configured application DB, factory/media workers and private credentials.
Repeat inventory to observe gates/errors. Already authored or attempted slots are skipped.
"""
from __future__ import annotations

import argparse
import asyncio
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.config import get_settings
from app.content.curriculum import load_curriculum
from app.errors import ApiError
from app.factory import batch
from app.llm.errors import LLMNotConfigured
from app.models import FactoryRun, User
from app.runtime import Resources
from app.workers.tasks_factory import CeleryDispatcher


async def execute(args: argparse.Namespace) -> int:
    settings = get_settings()
    curriculum = load_curriculum()
    resources = Resources.create(settings)
    try:
        async with resources.sessionmaker() as db:
            report = await batch.inventory(db, curriculum)
        if args.command == "inventory":
            path = args.output.resolve()
            if ".private" not in path.parts:
                raise ValueError("operator inventory must stay under a private directory (D-19)")
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            print(json.dumps(report["totals"]))
            return 0
        # This command always reconstructs inventory before admitting anything.
        async with resources.sessionmaker() as db, db.begin():
            reviewer = await db.get(User, args.reviewer_id)
            if reviewer is None:
                raise ValueError("an existing active reviewer account is required")
            if reviewer.role != "reviewer" or reviewer.deactivated_at is not None or reviewer.deleted_at is not None:
                raise ValueError("an existing active reviewer account is required")
            if args.command == "resume":
                run = await db.get(FactoryRun, args.run_id)
                if run is None or run.status != "running" or not any(
                        s["stage"] == run.stage and s["status"] == "pending" for s in run.stages):
                    raise ValueError("resume only redispatches a durable pending stage; gates remain unchanged")
                messages = [(run.id, run.stage, run.attempt)]
            else:
                created = await batch.admit(db, settings, curriculum, reviewer=reviewer,
                                            unit_id=args.unit, lesson_type=args.lesson_type, limit=args.limit)
                messages = [(r.id, r.stage, r.attempt) for r in created]
        dispatcher = CeleryDispatcher()
        for identifier, stage, attempt in messages:
            try:
                dispatcher.send(identifier, stage, attempt)
            except Exception:
                # Never print a broker URL/credential; the committed run is recoverable.
                print(f"Dispatch failed for durable run {identifier}; use resume after broker recovery.",
                      file=sys.stderr)
                return 2
            print(f"queued {identifier}; specialist gates remain required")
        return 0
    except (ValueError, ApiError, LLMNotConfigured) as exc:
        print(str(exc), file=sys.stderr)
        return 2
    finally:
        await resources.close()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command", required=True)
    inv = commands.add_parser("inventory")
    inv.add_argument("--output", type=Path, required=True)
    enqueue = commands.add_parser("enqueue")
    enqueue.add_argument("--unit", required=True)
    enqueue.add_argument("--reviewer-id", required=True)
    enqueue.add_argument("--lesson-type", choices=("concept", "story", "practice"), required=True)
    enqueue.add_argument("--limit", type=int, default=1)
    resume = commands.add_parser("resume")
    resume.add_argument("--run-id", required=True)
    resume.add_argument("--reviewer-id", required=True)
    return asyncio.run(execute(parser.parse_args()))


if __name__ == "__main__":
    sys.exit(main())
