"""Export the factory's output schemas from the revision 10 contract and the factory's own stage models.

    uv run python scripts/export_llm_schemas.py           # write app/llm/json_schemas/<name>.json
    uv run python scripts/export_llm_schemas.py --check   # fail when a committed schema is stale (CI)

Schemas are generated, never hand-edited, so a model's structured output is always checked against the exact
contract shape the rest of Qabas validates (prompts name them in ``output_schema``).
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.factory.schemas import EXPORTS
from app.llm.prompts import SCHEMAS, strict_schema_problems
from app.raqeeb.schemas import exported

EXPORTS = EXPORTS | exported()


def render(name: str) -> str:
    schema = EXPORTS[name]()
    problems = strict_schema_problems(schema)
    if problems:
        raise SystemExit(f"{name}: not a strict structured-output schema: {problems[:3]}")
    return json.dumps(schema, ensure_ascii=False, indent=1, sort_keys=True) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    stale = []
    for name in sorted(EXPORTS):
        path = SCHEMAS / f"{name}.json"
        text = render(name)
        current = path.read_text(encoding="utf-8").replace("\r\n", "\n") if path.is_file() else None
        if args.check:
            if current != text:
                stale.append(name)
        elif current != text:
            path.write_text(text, encoding="utf-8", newline="\n")
            print(f"wrote {path.name}")
    if stale:
        print(f"stale LLM schemas (run scripts/export_llm_schemas.py): {stale}", file=sys.stderr)
        return 1
    if args.check:
        print("LLM schemas are up to date")
    return 0


if __name__ == "__main__":
    sys.exit(main())
