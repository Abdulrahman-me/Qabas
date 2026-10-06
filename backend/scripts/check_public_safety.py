"""Repository safety guard (decision D-19, which corrects D-14).

Rule: production/runtime data and tests may be public; internal evaluation material, unpublished
handoff material and secrets stay private. Arabic text, approved production content, application
answer keys and contract fixtures are legitimate repository content and are not flagged.

A tracked (or, with ``--staged``, a staged) file fails when it:
  1. lives under the frozen handoff or the git-ignored local private area (``backend/.private/``);
  2. is a secrets/credentials file (``.env``, private keys, keystores, credential JSON);
  3. contains a recognizable secret (private-key block, cloud/API/GitHub/Slack tokens);
  4. is named like a hidden evaluation dataset (held-out, adversarial, golden/reference answers,
     benchmark data). Those live in ``backend/.private/eval/``;
  5. is byte-identical (LF-normalized) to a fingerprinted private handoff artifact
     (``backend/security/private_fingerprints.json``), unless that exact runtime path and
     digest belong to the owner-imported Flutter application. This exception never skips
     secret/private/evaluation-path checks or secret-content scanning.

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

FORBIDDEN_PREFIXES = ("FINAL_ENGINEERING_HANDOFF/", "backend/.private/")
SECRET_FILE_PATTERNS = (
    "*.env", ".env.*", "*.pem", "*.key", "*.p12", "*.pfx", "*.jks", "*.keystore",
    "*id_rsa*", "*id_ed25519*", "*credentials*.json", "*service-account*.json", "*.secret*",
)
EVAL_DATASET_PATTERNS = (
    "*heldout*", "*held_out*", "*hidden_eval*", "*adversarial*", "*golden_eval*", "*gold_answers*",
    "*reference_answers*", "backend/bench/data/*",
)
ALLOWED_NAMES = (".env.example",)
SECRET_CONTENT = {
    "private key block": re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----"),
    "Anthropic API key": re.compile(r"sk-ant-[A-Za-z0-9_\-]{20,}"),
    "OpenAI-style API key": re.compile(r"\bsk-(?:proj-)?[A-Za-z0-9]{32,}"),
    "AWS access key id": re.compile(r"\b(?:AKIA|ASIA)[0-9A-Z]{16}\b"),
    "GitHub token": re.compile(r"\b(?:gh[pousr]_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{60,})"),
    "Slack token": re.compile(r"\bxox[abprs]-[A-Za-z0-9-]{10,}"),
    "Google API key": re.compile(r"\bAIza[0-9A-Za-z_\-]{35}\b"),
}
FINGERPRINTS = Path("backend/security/private_fingerprints.json")
PUBLIC_RUNTIME = Path("backend/security/public_runtime_fingerprints.json")


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


def load_fingerprints(root: Path) -> set[str]:
    path = root / FINGERPRINTS
    if not path.exists():
        return set()
    return set(json.loads(path.read_text(encoding="utf-8"))["sha256"])


def load_public_runtime(root: Path, staged: bool) -> dict[str, str]:
    """Explicit production import, bound to exact paths/bytes; staged checks use staged policy."""
    try:
        value = json.loads(read_blob(root, PUBLIC_RUNTIME.as_posix(), staged))
    except (FileNotFoundError, subprocess.CalledProcessError):
        return {}
    return {path: digest for path, digest in value["files"].items()
            if path.startswith("frontend/") and ".." not in path.split("/")
            and re.fullmatch(r"[0-9a-f]{64}", digest)}


def normalized_digest(data: bytes) -> str:
    return hashlib.sha256(data.replace(b"\r\n", b"\n")).hexdigest()


def digests(data: bytes) -> set[str]:
    """Raw digest (exact for binaries) and LF-normalized digest (text with Windows line endings)."""
    return {hashlib.sha256(data).hexdigest(), normalized_digest(data)}


def _matches(path: str, patterns: tuple[str, ...]) -> str | None:
    name = path.rsplit("/", 1)[-1]
    return next((p for p in patterns if fnmatch.fnmatch(path, p) or fnmatch.fnmatch(name, p)), None)


def check(root: Path, staged: bool) -> list[str]:
    problems: list[str] = []
    fingerprints = load_fingerprints(root)
    public_runtime = load_public_runtime(root, staged)
    for path in list_files(root, staged):
        if path.startswith(FORBIDDEN_PREFIXES):
            problems.append(f"{path}: handoff/private path must never be committed")
            continue
        if path.rsplit("/", 1)[-1] not in ALLOWED_NAMES:
            hit = _matches(path, SECRET_FILE_PATTERNS)
            if hit:
                problems.append(f"{path}: secrets/credentials file ({hit!r})")
                continue
            hit = _matches(path, EVAL_DATASET_PATTERNS)
            if hit:
                problems.append(f"{path}: looks like a hidden evaluation dataset ({hit!r}); "
                                "keep it in backend/.private/eval/")
                continue
        data = read_blob(root, path, staged)
        if (path != FINGERPRINTS.as_posix() and digests(data) & fingerprints
                and public_runtime.get(path) not in digests(data)):
            problems.append(f"{path}: identical to a private handoff artifact")
            continue
        if b"\0" in data[:8192]:
            continue  # binary
        text = data.decode("utf-8", errors="replace")
        for label, pattern in SECRET_CONTENT.items():
            match = pattern.search(text)
            if match:
                line_no = text.count("\n", 0, match.start()) + 1
                problems.append(f"{path}:{line_no}: possible {label}")
                break
    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--staged", action="store_true", help="check staged files (pre-commit)")
    args = parser.parse_args()
    problems = check(repo_root(), args.staged)
    for problem in problems:
        print(f"repo-safety: {problem}", file=sys.stderr)
    if problems:
        print(f"repo-safety: {len(problems)} problem(s); see decision D-19.", file=sys.stderr)
        return 1
    print("repo-safety: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
