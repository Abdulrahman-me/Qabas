"""The vendored contract is byte-identical to the handoff and exposes the expected 99 roots."""

from __future__ import annotations

import hashlib

from app.contract import CONTRACT_DIR, CONTRACT_ROOT, exported_schema, models

SUMS = CONTRACT_ROOT / "SHA256SUMS.public"
EXPECTED_SCHEMA_SHA256 = "9d67bda00d2edd04d47645b6b93a7747ab9d5646cddeb12a7b34a6910c97481c"


def test_vendored_files_match_handoff_checksums() -> None:
    lines = [line for line in SUMS.read_text(encoding="utf-8").splitlines() if line.strip()]
    assert len(lines) == 14
    for line in lines:
        digest, name = line.split("  ", 1)
        data = (CONTRACT_ROOT / name).read_bytes().replace(b"\r\n", b"\n")
        assert hashlib.sha256(data).hexdigest() == digest, name


def test_schema_identity_is_the_approved_revision_10_digest() -> None:
    data = (CONTRACT_DIR / "qabas_contract.schema.json").read_bytes().replace(b"\r\n", b"\n")
    assert hashlib.sha256(data).hexdigest() == EXPECTED_SCHEMA_SHA256


def test_exported_roots_match_models() -> None:
    schema = exported_schema()
    assert len(schema) == 99
    assert set(models.EXPORTED) == set(schema)
    assert "ErrorEnvelope" in schema


def test_models_forbid_extra_keys() -> None:
    body = models.ErrorBody(code="not_found", message="x", details={})
    assert body.model_config.get("extra") == "forbid"
