"""Run the full revision 10 contract suites from the vendored folder (locally and in CI).

``validate.py`` rewrites schema/report/checksum files, so the suites run on a disposable copy of
``backend/contract/03_API``. Expected results are pinned in ``backend/contract/VENDORED.json``
(595 regressions, 279 focused checks, 105 examples, 382 fixtures), and the regenerated schema
must be byte-identical (after LF normalization) to the vendored one.

Usage (from backend/): uv run python scripts/dev/run_contract_suites.py
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
VENDORED = BACKEND / "contract"
SOURCE = VENDORED / "03_API"
SCHEMA = Path("contract_revision10/contract/qabas_contract.schema.json")


def run(tool: str, cwd: Path) -> str:
    env = {**os.environ, "PYTHONDONTWRITEBYTECODE": "1", "PYTHONUTF8": "1"}
    proc = subprocess.run([sys.executable, f"tools/{tool}"], cwd=cwd, env=env, capture_output=True,
                          text=True, encoding="utf-8")
    if proc.returncode != 0:
        raise SystemExit(f"{tool} failed (exit {proc.returncode}):\n{proc.stdout[-3000:]}\n{proc.stderr[-3000:]}")
    return proc.stdout


def lf_digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes().replace(b"\r\n", b"\n")).hexdigest()


def main() -> int:
    expected = json.loads((VENDORED / "VENDORED.json").read_text(encoding="utf-8"))["expected_suites"]
    with tempfile.TemporaryDirectory(prefix="qabas-contract-") as tmp:
        work = Path(tmp) / "03_API"
        shutil.copytree(SOURCE, work, ignore=shutil.ignore_patterns("__pycache__"))
        suite = work / "contract_revision10"
        regression = json.loads(run("regression.py", suite))
        focused = json.loads(run("rev10_checks.py", suite))
        report = run("validate.py", suite)
        regenerated = lf_digest(work / SCHEMA)
    examples = re.search(r"Handoff examples: \*\*(\d+)/(\d+)\*\*", report)
    fixtures = re.search(r"Fixtures: \*\*(\d+)/(\d+)\*\*", report)
    results = {
        "regressions": (regression["passed"], regression["tests"]),
        "focused": (focused["passed"], focused["tests"]),
        "examples": tuple(map(int, examples.groups())) if examples else (0, -1),
        "fixtures": tuple(map(int, fixtures.groups())) if fixtures else (0, -1),
    }
    passed = "Result: **PASS**" in report
    ok = passed
    for name, (got, total) in results.items():
        good = got == total == expected[name]
        ok &= good
        print(f"{'OK ' if good else 'BAD'} {name:12} {got}/{total} (expected {expected[name]})")
    vendored = lf_digest(SOURCE / SCHEMA)  # schema is text
    schema_ok = regenerated == vendored
    ok &= schema_ok
    status = "OK " if schema_ok else "BAD"
    print(f"{status} schema       regenerated {regenerated[:16]}... vs vendored {vendored[:16]}...")
    print(f"{'OK ' if passed else 'BAD'} validate.py  Result: {'PASS' if passed else 'FAIL'}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
