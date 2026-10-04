"""Run the full revision 10 contract suites against the private mirror (local only, decision D-14).

The suites need fixtures and the API prose, which are not in the public repository. ``validate.py``
rewrites schema/report/checksum files, so everything runs on a disposable copy. Expected results
were recorded in Phase 0 (D-08): 595 regressions, 279 focused checks, 105 examples, 382 fixtures.

Usage: backend/.venv/Scripts/python backend/scripts/dev/run_contract_suites.py
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

BACKEND = Path(__file__).resolve().parents[2]
MIRROR = BACKEND / ".private" / "handoff" / "03_API"
VENDORED = BACKEND / "contract"
EXPECTED = {"regressions": 595, "focused": 279, "examples": 105, "fixtures": 382}


def run(tool: str, cwd: Path) -> str:
    env = {**os.environ, "PYTHONDONTWRITEBYTECODE": "1", "PYTHONUTF8": "1"}
    proc = subprocess.run([sys.executable, f"tools/{tool}"], cwd=cwd, env=env, capture_output=True,
                          text=True, encoding="utf-8")
    if proc.returncode != 0:
        raise SystemExit(f"{tool} failed (exit {proc.returncode}):\n{proc.stdout[-3000:]}\n{proc.stderr[-3000:]}")
    return proc.stdout


def check_vendored_matches_mirror() -> None:
    for line in (VENDORED / "SHA256SUMS.public").read_text(encoding="utf-8").splitlines():
        digest, name = line.split("  ", 1)
        mirrored = hashlib.sha256((MIRROR / "contract_revision10" / name).read_bytes().replace(b"\r\n", b"\n"))
        if mirrored.hexdigest() != digest:
            raise SystemExit(f"private mirror differs from vendored contract: {name}")


def main() -> int:
    if not MIRROR.is_dir():
        print("private mirror missing; run scripts/dev/sync_private_contract.py first", file=sys.stderr)
        return 1
    check_vendored_matches_mirror()
    with tempfile.TemporaryDirectory(prefix="qabas-contract-") as tmp:
        work = Path(tmp) / "03_API"
        shutil.copytree(MIRROR, work)
        suite = work / "contract_revision10"
        regression = json.loads(run("regression.py", suite))
        focused = json.loads(run("rev10_checks.py", suite))
        report = run("validate.py", suite)
        examples = re.search(r"Handoff examples: \*\*(\d+)/(\d+)\*\*", report)
        fixtures = re.search(r"Fixtures: \*\*(\d+)/(\d+)\*\*", report)
        passed = "Result: **PASS**" in report
        schema = (suite / "contract" / "qabas_contract.schema.json").read_bytes().replace(b"\r\n", b"\n")
    results = {
        "regressions": (regression["passed"], regression["tests"]),
        "focused": (focused["passed"], focused["tests"]),
        "examples": tuple(map(int, examples.groups())) if examples else (0, -1),
        "fixtures": tuple(map(int, fixtures.groups())) if fixtures else (0, -1),
    }
    ok = passed
    for name, (got, total) in results.items():
        good = got == total == EXPECTED[name]
        ok &= good
        print(f"{'OK ' if good else 'BAD'} {name:12} {got}/{total} (expected {EXPECTED[name]})")
    regenerated = hashlib.sha256(schema).hexdigest()
    vendored = hashlib.sha256((VENDORED / "contract" / "qabas_contract.schema.json").read_bytes()).hexdigest()
    schema_ok = regenerated == vendored
    ok &= schema_ok
    status = "OK " if schema_ok else "BAD"
    print(f"{status} schema       regenerated {regenerated[:16]}... vs vendored {vendored[:16]}...")
    print(f"{'OK ' if passed else 'BAD'} validate.py  Result: {'PASS' if passed else 'FAIL'}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
