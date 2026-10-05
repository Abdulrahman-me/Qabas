"""Derive the scene design-token mapping from the delivered Flutter theme (factory §13.8 step 1).

    uv run python scripts/scene_design_tokens.py --tokens <flutter_reference>/lib/core/theme/tokens.dart
    uv run python scripts/scene_design_tokens.py --tokens <…/tokens.dart> --check

A scene palette entry may be ``token:<name>`` "from the app theme tokens" (scene.schema.json). The Animated Scene
Author receives the token names it may reference; this script extracts them mechanically from ``QColors`` in the
handoff's ``tokens.dart`` and records the source digest. It invents no colours and approves nothing: the naming
convention (``QColors.flameGold`` → ``token:flame_gold``) must be confirmed by the renderer owner (O-02) and the
mapping approved in ``content/media/policy.yaml`` (O-13) before the Scene Author may use it.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

BACKEND = Path(__file__).resolve().parents[1]
OUTPUT = BACKEND / "content" / "scene_design_tokens.json"
CLASS = re.compile(r"abstract final class QColors \{(?P<body>.*?)\n\}", re.S)
COLOR = re.compile(r"static const (?P<name>[a-zA-Z][a-zA-Z0-9]*) = Color\(0x(?P<argb>[0-9A-Fa-f]{8})\);")


def snake(name: str) -> str:
    return re.sub(r"(?<=[a-z0-9])(?=[A-Z])|(?<=[A-Za-z])(?=[0-9])", "_", name).lower()


def derive(source: bytes) -> dict[str, object]:
    match = CLASS.search(source.decode("utf-8"))
    if match is None:
        raise SystemExit("tokens.dart has no QColors class")
    tokens: dict[str, str] = {}
    for item in COLOR.finditer(match.group("body")):
        argb = item.group("argb").upper()
        alpha, rgb = argb[:2], argb[2:]
        name = snake(item.group("name"))
        if not re.fullmatch(r"[a-z0-9_]+", name) or name in tokens:
            raise SystemExit(f"token name {item.group('name')} does not map to a unique scene token")
        tokens[name] = f"#{rgb}" if alpha == "FF" else f"#{rgb}{alpha}"
    if not tokens:
        raise SystemExit("QColors defines no colours")
    return {"schema": "qabas.scene_design_tokens/1",
            "source": {"file": "flutter_reference/lib/core/theme/tokens.dart (handoff reply8)",
                       "class": "QColors", "sha256": hashlib.sha256(source).hexdigest()},
            "naming": "token:<snake_case of the QColors field>; pending renderer-owner confirmation (O-02)",
            "tokens": dict(sorted(tokens.items()))}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--tokens", type=Path, required=True)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    text = json.dumps(derive(args.tokens.read_bytes()), indent=1, ensure_ascii=False) + "\n"
    if args.check:
        current = OUTPUT.read_text(encoding="utf-8") if OUTPUT.is_file() else None
        if current != text:
            print("content/scene_design_tokens.json is stale", file=sys.stderr)
            return 1
        print("scene design tokens are up to date")
        return 0
    OUTPUT.write_text(text, encoding="utf-8", newline="\n")
    print(f"wrote {OUTPUT.relative_to(BACKEND)} ({hashlib.sha256(text.encode()).hexdigest()})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
