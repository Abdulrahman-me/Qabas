"""Convert and import gold lessons (factory §13.7, SEED_AND_IMPORT). Nothing here publishes.

    # Convert upstream authoring into gold files + a blocker report (no database needed)
    uv run python scripts/import_gold.py convert unit0 --source <UNIT_0_CONTENT/lessons> [--out DIR] [--report FILE]
    uv run python scripts/import_gold.py convert salah --source <reply8/reference_export> [--completion FILE]

    # Store gold files as unpublished versions (validators, slot placement, concept registration all apply)
    uv run python scripts/import_gold.py import <gold.json>...

Pending (unapproved) gold files belong in the git-ignored ``backend/.private/content/gold/`` (D-19, the
default ``--out``); approved ones are committed under ``content/gold/`` and imported the same way. A lesson
with blockers produces no gold file; the report says what is missing and who supplies it (D-81). Approval
and publication are separate: ``scripts/review_gold.py``.
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
from app.content.gold import GoldError, GoldFile, Provenance, import_gold, issues_text, read_gold, write_gold
from app.content.importers import salah, unit0
from app.content.importers.report import Conversion, summary
from app.content.package import LessonPackage
from app.content.validation import ContentValidationError
from app.runtime import Resources

PRIVATE_GOLD = Path(__file__).resolve().parents[1] / ".private" / "content" / "gold"


def _convert(args: argparse.Namespace) -> int:
    curriculum = load_curriculum()
    conversions: list[Conversion] = []
    if args.kind == "unit0":
        mapping = unit0.load_mapping()
        records = unit0.load_records(Path(args.source))
        # Production scene media come from the visual pipeline (Phase 14); none is published yet (O-13).
        conversions = [unit0.convert(r, curriculum, mapping=mapping, scenes={}) for r in records]
        provenance = {c.lesson: Provenance(source="unit0_authoring", source_digest=unit0.digest(r),
                                           converter=unit0.CONVERTER, notes=c.notes)
                      for c, r in zip(conversions, records, strict=True)}
    else:
        export = salah.load_export(Path(args.source))
        completion = None
        if args.completion:
            completion = salah.Completion.model_validate(json.loads(Path(args.completion).read_text("utf-8")))
        conversions = [salah.convert(export, curriculum, completion)]
        provenance = {conversions[0].lesson: Provenance(source="salah_reference", converter=salah.CONVERTER)}
    out = Path(args.out)
    for conversion in conversions:
        if conversion.ready and conversion.package is not None:
            gold = GoldFile(provenance=provenance[conversion.lesson],
                            lesson=LessonPackage.model_validate(conversion.package))
            write_gold(out / f"{conversion.lesson}.json", gold)
    report = summary(conversions)
    text = json.dumps(report, ensure_ascii=False, indent=1)
    if args.report:
        Path(args.report).write_text(text + "\n", encoding="utf-8")
    ready = sum(1 for c in conversions if c.ready)
    print(f"{ready}/{len(conversions)} lesson(s) ready; blockers: {report['blocker_counts'] or 'none'}")
    for code, owner in report["owners"].items():
        print(f"  {code}: {owner}")
    return 0 if ready == len(conversions) else 2


async def _import(paths: list[Path]) -> int:
    settings = get_settings()
    resources = Resources.create(settings)
    failures = 0
    try:
        for path in paths:
            try:
                gold = read_gold(path)
                async with resources.sessionmaker() as db, db.begin():
                    result = await import_gold(db, gold)
                    digest = gold.lesson.digest()
                state = "stored" if result.created else "unchanged"
                print(f"{gold.lesson.lesson_id} v{result.version} {state} (unpublished) digest {digest}")
            except GoldError as exc:
                failures += 1
                print(exc, file=sys.stderr)
            except ContentValidationError as exc:
                failures += 1
                print(f"{path}: rejected", file=sys.stderr)
                for line in issues_text(exc):
                    print(f"  {line}", file=sys.stderr)
    finally:
        await resources.close()
    return 1 if failures else 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command", required=True)
    convert = commands.add_parser("convert", help="convert upstream authoring into gold files")
    convert.add_argument("kind", choices=("unit0", "salah"))
    convert.add_argument("--source", required=True)
    convert.add_argument("--completion", help="salah: the content team's completion record (JSON)")
    convert.add_argument("--out", default=str(PRIVATE_GOLD))
    convert.add_argument("--report", help="also write the JSON blocker report here")
    store = commands.add_parser("import", help="store gold files as unpublished versions")
    store.add_argument("paths", nargs="+", type=Path)
    args = parser.parse_args()
    if args.command == "convert":
        return _convert(args)
    return asyncio.run(_import(args.paths))


if __name__ == "__main__":
    sys.exit(main())
