"""Install the repository's local pre-commit hook (runs the public-safety guard on staged files).

Usage: py -3.12 backend/scripts/dev/install_git_hooks.py
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

HOOK = """#!/bin/sh
# Installed by backend/scripts/dev/install_git_hooks.py: blocks private material from the public repo (D-14).
exec py -3.12 backend/scripts/check_public_safety.py --staged
"""


def main() -> int:
    git_dir = subprocess.run(["git", "rev-parse", "--git-path", "hooks"], capture_output=True, text=True,
                             check=True).stdout.strip()
    hooks = Path(git_dir)
    hooks.mkdir(parents=True, exist_ok=True)
    target = hooks / "pre-commit"
    target.write_text(HOOK, encoding="utf-8", newline="\n")
    target.chmod(0o755)
    print(f"installed {target}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
