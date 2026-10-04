"""Public-repository safety guard (decision D-14).

The repository is public. This check fails if a tracked (or, with ``--staged``, a staged) file:
  1. lives under the frozen handoff or the local private mirror;
  2. has a private-material name (grading keys, evaluation context, private_keys, gold lessons, .env);
  3. contains Arabic-script text, unless its path matches ``.public-safety-allow``
     (Arabic in this project is almost always lesson/religious content, which stays private);
  4. is byte-identical (after LF normalization) to a private handoff file. Needs the local digest
     list written by ``scripts/dev/sync_private_contract.py``; skipped where it is absent (CI).

Usage: python scripts/check_public_safety.py [--staged]
"""

from __future__ import annotations

import argparse
import fnmatch
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

# Arabic, Arabic Supplement, Arabic Extended-A and Arabic Presentation Forms A/B.
ARABIC = re.compile(r"[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]")
FORBIDDEN_PREFIXES = ("FINAL_ENGINEERING_HANDOFF/", "backend/.private/")
FORBIDDEN_NAME_PATTERNS = (
    "*PRIVATE_GRADING_KEYS*", "*EVALUATION_CONTEXT*", "*private_keys/*", "*/gold/*", "*salah-01*",
    "*session_salah_*", "*.env", "*/.env.*", "*answer_keys*", "*UNIT_0_REVIEW*",
)
ENV_EXAMPLE = ".env.example"


def repo_root() -> Path:
    out = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True, check=True)
    return Path(out.stdout.strip())


def list_files(root: Path, staged: bool) -> list[str]:
    if staged:
        cmd = ["git", "diff", "--cached", "--name-only", "--diff-filter=ACMR", "-z"]
    else:
        cmd = ["git", "ls-files", "-z"]
    out = subprocess.run(cmd, cwd=root, capture_output=True, check=True)
    return [p for p in out.stdout.decode("utf-8").split("\0") if p]


def read_blob(root: Path, path: str, staged: bool) -> bytes:
    if staged:
        return subprocess.run(["git", "show", f":{path}"], cwd=root, capture_output=True, check=True).stdout
    return (root / path).read_bytes()


def load_allow_list(root: Path) -> list[str]:
    allow = root / ".public-safety-allow"
    if not allow.exists():
        return []
    patterns = []
    for line in allow.read_text(encoding="utf-8").splitlines():
        line = line.split("#", 1)[0].strip()
        if line:
            patterns.append(line)
    return patterns


def load_private_digests(root: Path) -> set[str]:
    path = root / "backend" / ".private" / "private_digests.json"
    if not path.exists():
        return set()
    return set(json.loads(path.read_text(encoding="utf-8"))["sha256"])


def normalized_digest(data: bytes) -> str:
    return hashlib.sha256(data.replace(b"\r\n", b"\n")).hexdigest()


def check(root: Path, staged: bool) -> list[str]:
    problems: list[str] = []
    allow = load_allow_list(root)
    private_digests = load_private_digests(root)
    for path in list_files(root, staged):
        if path.startswith(FORBIDDEN_PREFIXES):
            problems.append(f"{path}: private/handoff path must never be committed")
            continue
        name_hit = next((p for p in FORBIDDEN_NAME_PATTERNS if fnmatch.fnmatch(path, p)), None)
        if name_hit and not path.endswith(ENV_EXAMPLE):
            problems.append(f"{path}: matches private-material pattern {name_hit!r}")
            continue
        data = read_blob(root, path, staged)
        if private_digests and normalized_digest(data) in private_digests:
            problems.append(f"{path}: identical to a private handoff file")
            continue
        if b"\0" in data[:8192]:
            continue  # binary
        text = data.decode("utf-8", errors="replace")
        if ARABIC.search(text) and not any(fnmatch.fnmatch(path, p) for p in allow):
            line_no = next(i for i, line in enumerate(text.splitlines(), 1) if ARABIC.search(line))
            problems.append(f"{path}:{line_no}: Arabic-script text outside .public-safety-allow")
    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--staged", action="store_true", help="check staged files (pre-commit)")
    args = parser.parse_args()
    root = repo_root()
    problems = check(root, args.staged)
    for problem in problems:
        print(f"public-safety: {problem}", file=sys.stderr)
    if problems:
        print(f"public-safety: {len(problems)} problem(s); see decision D-14.", file=sys.stderr)
        return 1
    print("public-safety: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
