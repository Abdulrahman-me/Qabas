"""Write the served OpenAPI document to ``backend/docs/openapi.json`` for the frontend's contract check.

Usage: python scripts/export_openapi.py [--check]   (--check fails if the committed file is stale)
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.main import create_app

TARGET = Path(__file__).resolve().parents[1] / "docs" / "openapi.json"


def render() -> str:
    return json.dumps(create_app().openapi(), indent=1, ensure_ascii=False, sort_keys=True) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    document = render()
    if args.check:
        current = TARGET.read_text(encoding="utf-8") if TARGET.exists() else ""
        if current != document:
            print("docs/openapi.json is stale; run scripts/export_openapi.py", file=sys.stderr)
            return 1
        print("docs/openapi.json is up to date")
        return 0
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    TARGET.write_text(document, encoding="utf-8", newline="\n")
    print(f"wrote {TARGET}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
