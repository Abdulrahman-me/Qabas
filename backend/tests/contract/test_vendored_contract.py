"""The vendored contract folder is byte-identical to the handoff and exposes the expected 99 roots."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from app.contract import CONTRACT_DIR, CONTRACT_ROOT, FIXTURES_DIR, VENDOR_ROOT, exported_schema, models

VENDORED = json.loads((VENDOR_ROOT / "VENDORED.json").read_text(encoding="utf-8"))


def lf_digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes().replace(b"\r\n", b"\n")).hexdigest()


def digests(path: Path) -> set[str]:
    """Raw digest (binaries) and LF-normalized digest (text checked out on Windows)."""
    return {hashlib.sha256(path.read_bytes()).hexdigest(), lf_digest(path)}


def test_anchor_files_match_handoff_manifest() -> None:
    for rel, digest in VENDORED["anchors"].items():
        assert digest in digests(VENDOR_ROOT / rel), rel


def test_every_contract_file_matches_its_checksum() -> None:
    lines = [line for line in (CONTRACT_ROOT / "SHA256SUMS").read_text(encoding="utf-8").splitlines() if line]
    assert len(lines) == 455
    for line in lines:
        digest, name = line.split("  ", 1)
        assert digest in digests(CONTRACT_ROOT / name), name


def test_no_unlisted_files_in_vendored_folder() -> None:
    listed = {line.split("  ", 1)[1] for line in (CONTRACT_ROOT / "SHA256SUMS").read_text(encoding="utf-8").splitlines()
              if line}
    present = {p.relative_to(CONTRACT_ROOT).as_posix() for p in CONTRACT_ROOT.rglob("*")
               if p.is_file() and "__pycache__" not in p.parts}
    assert present - listed == {"SHA256SUMS", "VALIDATION_REPORT.md"}  # both excluded from SHA256SUMS by design


def test_schema_identity_is_the_approved_revision_10_digest() -> None:
    assert lf_digest(CONTRACT_DIR / "qabas_contract.schema.json") == VENDORED["schema_sha256"]


def test_exported_roots_match_models() -> None:
    schema = exported_schema()
    assert len(schema) == 99
    assert set(models.EXPORTED) == set(schema)


def test_fixture_manifest_is_complete() -> None:
    manifest = json.loads((FIXTURES_DIR / "MANIFEST.json").read_text(encoding="utf-8"))
    entries = manifest if isinstance(manifest, list) else manifest.get("fixtures", manifest)
    assert len(entries) == VENDORED["expected_suites"]["fixtures"]
