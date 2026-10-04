"""Refresh the git-ignored private mirror ``backend/.private/`` from the frozen handoff (decision D-14).

Copies ``03_API/contract_revision10`` (fixtures, tools, private grading context) and
``03_API/API_REQUIREMENTS.md`` into ``backend/.private/handoff/03_API/``, and writes
``backend/.private/private_digests.json``: LF-normalized SHA-256 digests of private handoff
files, used by ``scripts/check_public_safety.py`` to block verbatim copies from being committed.

Usage: py -3.12 backend/scripts/dev/sync_private_contract.py
"""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import stat
import sys
from pathlib import Path

BACKEND = Path(__file__).resolve().parents[2]
REPO = BACKEND.parent
HANDOFF = REPO / "FINAL_ENGINEERING_HANDOFF"
PRIVATE = BACKEND / ".private"
MIRROR = PRIVATE / "handoff" / "03_API"
PUBLIC_SUMS = BACKEND / "contract" / "SHA256SUMS.public"

SKIP_DIRS = {".python_deps", ".gradle", "__pycache__", ".dart_tool", "build"}
MIN_DIGEST_BYTES = 64          # tiny generic files (empty __init__.py etc.) would cause false positives
MAX_DIGEST_BYTES = 20_000_000


def _make_writable(func, path, _exc):  # type: ignore[no-untyped-def]
    os.chmod(path, stat.S_IWRITE)
    func(path)


def copy_tree(src: Path, dst: Path) -> None:
    shutil.copytree(src, dst, ignore=shutil.ignore_patterns("__pycache__"))
    for path in dst.rglob("*"):
        if path.is_file():
            path.chmod(stat.S_IREAD | stat.S_IWRITE)  # handoff files are read-only; the copy is not


def normalized_digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes().replace(b"\r\n", b"\n")).hexdigest()


def private_digests() -> list[str]:
    public = {line.split()[0] for line in PUBLIC_SUMS.read_text(encoding="utf-8").splitlines() if line.strip()}
    digests: set[str] = set()
    for path in HANDOFF.rglob("*"):
        try:
            if not path.is_file() or SKIP_DIRS.intersection(path.relative_to(HANDOFF).parts):
                continue
            size = path.stat().st_size
            if size < MIN_DIGEST_BYTES or size > MAX_DIGEST_BYTES:
                continue
            digest = normalized_digest(path)
        except PermissionError:
            continue
        if digest not in public:
            digests.add(digest)
    return sorted(digests)


def main() -> int:
    if not HANDOFF.is_dir():
        print(f"handoff not found at {HANDOFF}", file=sys.stderr)
        return 1
    if MIRROR.exists():
        shutil.rmtree(MIRROR, onerror=_make_writable)
    MIRROR.mkdir(parents=True)
    copy_tree(HANDOFF / "03_API" / "contract_revision10", MIRROR / "contract_revision10")
    shutil.copy2(HANDOFF / "03_API" / "API_REQUIREMENTS.md", MIRROR / "API_REQUIREMENTS.md")
    (MIRROR / "API_REQUIREMENTS.md").chmod(stat.S_IREAD | stat.S_IWRITE)
    digests = private_digests()
    (PRIVATE / "private_digests.json").write_text(json.dumps({"sha256": digests}, indent=0), encoding="utf-8")
    print(f"private mirror refreshed at {MIRROR}; {len(digests)} private file digests recorded")
    return 0


if __name__ == "__main__":
    sys.exit(main())
