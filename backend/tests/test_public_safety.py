"""Repository safety guard (D-19): blocks secrets, private handoff material and hidden evaluation data,
while Arabic text, production content and application answer keys are legitimate repository content."""

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


def test_production_content_with_arabic_and_answer_keys_passes(guard: ModuleType, tmp_path: Path) -> None:
    exercise = {
        "exercise_id": "ex_example",
        "prompt": [{"type": "text", "text": "ما معنى التوحيد؟"}],
        "answer_key": {"option_id": "opt_b"},
    }
    root = _repo(tmp_path, {
        "backend/content/lessons/les_example.json": json.dumps(exercise, ensure_ascii=False).encode(),
        "backend/app/x.py": "LABEL = 'مسافر'\n".encode(),
        "backend/.env.example": b"AUTH_TOKEN_PEPPER=<random secret>\n",
    })
    assert guard.check(root, staged=True) == []
    assert guard.check(root, staged=False) == []


@pytest.mark.parametrize("name", [
    "FINAL_ENGINEERING_HANDOFF/README.md",
    "backend/.private/eval/questions.jsonl",
    "backend/.env",
    ".env.production",
    "deploy/server.pem",
    "deploy/gcp-service-account.json",
    "backend/bench/data/questions.jsonl",
    "backend/tests/data/raqeeb_adversarial.jsonl",
    "backend/eval/heldout_learner_audio.json",
    "backend/eval/reference_answers.json",
])
def test_private_secret_and_eval_paths_fail(guard: ModuleType, tmp_path: Path, name: str) -> None:
    root = _repo(tmp_path, {name: b"{}\n"})
    problems = guard.check(root, staged=True)
    assert len(problems) == 1 and problems[0].startswith(name), problems


# Secret-looking values are assembled at runtime so this source file never contains one.
@pytest.mark.parametrize("secret", [
    "-----BEGIN " + "RSA PRIVATE KEY-----\nMIIB\n",
    "ANTHROPIC_API_KEY=" + "sk-ant-" + "a1" * 20,
    "aws = " + "AKIA" + "ABCDEFGHIJKLMNOP",
    "token: " + "ghp_" + "x" * 36,
    "SLACK=" + "xoxb-" + "1234567890-abc",
])
def test_secret_content_fails(guard: ModuleType, tmp_path: Path, secret: str) -> None:
    root = _repo(tmp_path, {"backend/app/settings_notes.md": f"intro\n{secret}\n".encode()})
    problems = guard.check(root, staged=True)
    assert len(problems) == 1 and problems[0].startswith("backend/app/settings_notes.md:2: possible"), problems


def test_fingerprinted_private_artifact_fails(guard: ModuleType, tmp_path: Path) -> None:
    private = b'{"draft": "unapproved lesson draft", "status": "pending review"}\r\n'
    digest = guard.normalized_digest(private)
    fingerprints = json.dumps({"sha256": [digest]}).encode()
    root = _repo(tmp_path, {"backend/content/copied.json": private,
                            "backend/security/private_fingerprints.json": fingerprints})
    assert guard.check(root, staged=True) == ["backend/content/copied.json: identical to a private handoff artifact"]


def test_repository_fingerprints_exclude_vendored_contract(guard: ModuleType) -> None:
    root = Path(__file__).resolve().parents[2]
    fingerprints = guard.load_fingerprints(root)
    assert fingerprints, "backend/security/private_fingerprints.json must be committed"
    vendored = root / "backend" / "contract"
    for path in vendored.rglob("*"):
        if path.is_file():
            assert not guard.digests(path.read_bytes()) & fingerprints, path
