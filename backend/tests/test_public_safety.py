"""The public-repo guard (D-14) catches private paths, names, Arabic text and verbatim private copies."""

from __future__ import annotations

import importlib.util
import json
import subprocess
from pathlib import Path
from types import ModuleType

import pytest

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "check_public_safety.py"


@pytest.fixture(scope="module")
def guard() -> ModuleType:
    spec = importlib.util.spec_from_file_location("check_public_safety", SCRIPT)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _repo(tmp_path: Path, files: dict[str, bytes]) -> Path:
    subprocess.run(["git", "init", "-q", str(tmp_path)], check=True)
    for name, data in files.items():
        path = tmp_path / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    subprocess.run(["git", "add", "-A"], cwd=tmp_path, check=True)
    return tmp_path


def test_clean_repo_passes(guard: ModuleType, tmp_path: Path) -> None:
    root = _repo(tmp_path, {"backend/app/x.py": b"print('ok')\n", "backend/.env.example": b"A=1\n"})
    assert guard.check(root, staged=True) == []
    assert guard.check(root, staged=False) == []


@pytest.mark.parametrize("name", [
    "FINAL_ENGINEERING_HANDOFF/README.md",
    "backend/.private/handoff/x.json",
    "backend/tests/fixtures/PRIVATE_GRADING_KEYS.json",
    "backend/content/gold/lesson.json",
    "backend/.env",
])
def test_private_paths_and_names_fail(guard: ModuleType, tmp_path: Path, name: str) -> None:
    root = _repo(tmp_path, {name: b"{}\n"})
    problems = guard.check(root, staged=True)
    assert len(problems) == 1 and problems[0].startswith(name)


def test_arabic_text_needs_allow_list(guard: ModuleType, tmp_path: Path) -> None:
    arabic = "".join(map(chr, (0x645, 0x631, 0x62D, 0x628, 0x627)))  # a neutral greeting, kept out of the source
    root = _repo(tmp_path, {"notes.md": f"line one\n{arabic}\n".encode()})
    assert guard.check(root, staged=True) == ["notes.md:2: Arabic-script text outside .public-safety-allow"]
    (root / ".public-safety-allow").write_text("notes.md  # test\n", encoding="utf-8")
    subprocess.run(["git", "add", "-A"], cwd=root, check=True)
    assert guard.check(root, staged=True) == []


def test_verbatim_private_copy_fails(guard: ModuleType, tmp_path: Path) -> None:
    secret = b'{"exercise": "synthetic", "key": "opt_b"}\r\n'
    root = _repo(tmp_path, {"backend/tests/data.json": secret})
    private = root / "backend" / ".private"
    private.mkdir(parents=True)
    digest = guard.normalized_digest(secret)
    (private / "private_digests.json").write_text(json.dumps({"sha256": [digest]}))
    assert guard.check(root, staged=True) == ["backend/tests/data.json: identical to a private handoff file"]
