"""Fetch the reciter clips of tests/recitation/clip_set.yaml into backend/var/recitation_bench/ (git-ignored, O-06).

    uv run python scripts/recitation_clip_set.py [--system-ca]

The clips are published verse audio used only to evaluate the local pipeline; they are never committed or served.
Each file's SHA-256 is written to ``var/recitation_bench/SHA256SUMS`` on first fetch and checked afterwards.
"""

from __future__ import annotations

import argparse
import hashlib
import ssl
import sys
from pathlib import Path

import httpx
import yaml

BACKEND = Path(__file__).resolve().parents[1]
CLIP_SET = BACKEND / "tests" / "recitation" / "clip_set.yaml"
BENCH = BACKEND / "var" / "recitation_bench"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--system-ca", action="store_true", help="verify TLS with the OS certificate store")
    args = parser.parse_args()
    spec = yaml.safe_load(CLIP_SET.read_text(encoding="utf-8"))
    BENCH.mkdir(parents=True, exist_ok=True)
    sums_path = BENCH / "SHA256SUMS"
    sums = dict(line.split("  ", 1)[::-1] for line in sums_path.read_text().splitlines()) if sums_path.exists() else {}
    files = sorted({clip["file"] for clip in spec["clips"] if "file" in clip})
    verify: ssl.SSLContext | bool = ssl.create_default_context() if args.system_ca else True
    with httpx.Client(timeout=httpx.Timeout(30, connect=10), verify=verify) as client:
        for name in files:
            target = BENCH / name
            if not target.exists():
                response = client.get(spec["base_url"] + name)
                response.raise_for_status()
                target.write_bytes(response.content)
            digest = hashlib.sha256(target.read_bytes()).hexdigest()
            if sums.setdefault(name, digest) != digest:
                print(f"{name}: SHA-256 changed since the first fetch", file=sys.stderr)
                return 1
    sums_path.write_text("".join(f"{sums[n]}  {n}\n" for n in sorted(sums)), encoding="utf-8")
    print(f"{len(files)} clips in {BENCH}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
