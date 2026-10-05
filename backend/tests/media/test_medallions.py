from __future__ import annotations

from pathlib import Path
from typing import Any

import pytest
import yaml

from app.media import medallions, objects
from app.media.errors import MediaInvalid, MediaNotConfigured
from app.services.platform.storage import LocalStorage, sha256_hex


async def test_only_digest_bound_human_svg_with_bilingual_labels_can_be_consumed(
    tmp_path: Path,
    monkeypatch: Any,
    storage: LocalStorage,
) -> None:
    # Neutral shape, not sacred-figure art or a production medallion registry.
    svg = (b'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'
           b'<circle cx="50" cy="50" r="40" fill="#0B5A52"/></svg>')
    artwork = tmp_path / "neutral.svg"
    artwork.write_bytes(svg)
    approval = {"status": "approved", "approved_by": "synthetic test", "approved_on": "2026-01-01"}
    item = {
        **approval,
        "licence": approval,
        "file": artwork.name,
        "sha256": sha256_hex(svg),
        "width": 100,
        "height": 100,
        "labels": {"ar": "Synthetic Arabic label", "en": "Synthetic label"},
        "anchor": "top_start",
        "size_pct": 22,
    }
    path = tmp_path / "test-registry.yaml"
    path.write_text(yaml.safe_dump({"schema": "qabas.medallions/1", "figures": {"synthetic": item}}))
    monkeypatch.setattr(medallions, "BACKEND_DIR", tmp_path)
    overlays, receipts = await medallions.resolve(["synthetic"], storage, "run_fixture", path)
    record = objects.MediaObject.model_validate(receipts[0])
    medallions.verify_receipt(record, svg, path)
    assert overlays["ar"][0]["asset_url"] == record.public_url(storage)
    forged = record.model_copy(update={"provenance": {**record.provenance, "approved_by": "forged"}})
    with pytest.raises(MediaInvalid, match="receipt"):
        medallions.verify_receipt(forged, svg, path)
    artwork.write_bytes(svg.replace(b"40", b"30"))
    with pytest.raises(MediaInvalid, match="approved bytes"):
        medallions.verify_receipt(record, svg, path)
    with pytest.raises(MediaNotConfigured, match="missing"):
        await medallions.resolve(["unknown"], storage, "run_fixture", path)


async def test_missing_registry_never_silently_substitutes_generated_art(
    tmp_path: Path,
    storage: LocalStorage,
) -> None:
    with pytest.raises(MediaNotConfigured, match="missing"):
        await medallions.resolve(["unavailable"], storage, "run_fixture", tmp_path / "absent.yaml")
