"""Refresh ``app/llm/prompts/LOCK.json`` (prompt id -> version, SHA-256).

    uv run python scripts/lock_prompts.py

A prompt whose file changed must have a higher ``version`` than the locked one; otherwise nothing is written. This
keeps "prompt version" meaningful in every recorded call (agent catalog: record exact prompt versions per call).
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.llm.prompts import LOCK, all_prompts, read_lock


def main() -> int:
    locked = read_lock()
    new: dict[str, dict[str, object]] = {}
    for prompt in all_prompts():
        previous = locked.get(prompt.id)
        if previous and previous["sha256"] != prompt.sha256 and prompt.version <= int(previous["version"]):
            print(f"{prompt.id}: file changed but version {prompt.version} was not raised above "
                  f"{previous['version']}", file=sys.stderr)
            return 1
        new[prompt.id] = {"version": prompt.version, "sha256": prompt.sha256}
    LOCK.write_text(json.dumps(new, indent=1, sort_keys=True) + "\n", encoding="utf-8")
    print(f"locked {len(new)} prompt(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
