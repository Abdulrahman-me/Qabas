"""Regenerate ``backend/security/private_fingerprints.json`` from the local handoff (decision D-19).

The file holds only SHA-256 digests (LF-normalized), never content. It covers handoff artifacts that
must stay out of the repository: unpublished review and history material, unapproved content drafts
(Unit 0, reference gold candidates), their answer-key exports, and internal evaluation material.
Files deliberately vendored into ``backend/contract/`` are excluded, as are third-party
dependency folders and tiny generic files (which would cause false positives).

``scripts/check_public_safety.py`` rejects any committed file whose digest is listed, in CI too.
When content is approved for production, add its handoff path to APPROVED_FOR_PUBLICATION and rerun.

Usage (from the repo root): py -3.12 backend/scripts/dev/update_private_fingerprints.py
"""

from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

BACKEND = Path(__file__).resolve().parents[2]
REPO = BACKEND.parent
HANDOFF = REPO / "FINAL_ENGINEERING_HANDOFF"
TARGET = BACKEND / "security" / "private_fingerprints.json"

VENDORED_PREFIXES = ("03_API/contract_revision10/", "03_API/API_REQUIREMENTS.md")
THIRD_PARTY_PARTS = {".python_deps", ".gradle", "__pycache__", ".dart_tool", "build", ".idea", ".vscode"}
APPROVED_FOR_PUBLICATION: tuple[str, ...] = ()  # handoff-relative paths approved as production content
MIN_BYTES = 64
MAX_BYTES = 50_000_000


def file_digests(data: bytes) -> set[str]:
    """Raw digest (exact for binaries) plus the LF-normalized digest (text checked out with CRLF)."""
    return {hashlib.sha256(data).hexdigest(), hashlib.sha256(data.replace(b"\r\n", b"\n")).hexdigest()}


def main() -> int:
    if not HANDOFF.is_dir():
        print(f"handoff not found at {HANDOFF}", file=sys.stderr)
        return 1
    vendored: set[str] = set()
    for p in (BACKEND / "contract").rglob("*"):
        if p.is_file():
            vendored |= file_digests(p.read_bytes())
    digests: set[str] = set()
    for path in HANDOFF.rglob("*"):
        try:
            if not path.is_file():
                continue
            rel = path.relative_to(HANDOFF).as_posix()
            if rel.startswith(VENDORED_PREFIXES) or rel in APPROVED_FOR_PUBLICATION:
                continue
            if THIRD_PARTY_PARTS.intersection(path.relative_to(HANDOFF).parts):
                continue
            if not MIN_BYTES <= path.stat().st_size <= MAX_BYTES:
                continue
            found = file_digests(path.read_bytes())
        except PermissionError:
            continue
        if not found & vendored:
            digests |= found
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "about": "SHA-256 (raw and LF-normalized) of private handoff artifacts; content is never stored here. "
                 "Regenerate with backend/scripts/dev/update_private_fingerprints.py.",
        "sha256": sorted(digests),
    }
    TARGET.write_text(json.dumps(payload, indent=0) + "\n", encoding="utf-8", newline="\n")
    print(f"wrote {len(digests)} fingerprints to {TARGET}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
