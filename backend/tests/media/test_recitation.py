from __future__ import annotations

import copy
from dataclasses import replace
from pathlib import Path
from typing import Any

import pytest
import yaml

from app.config import Settings
from app.media import objects, recitation
from app.media.errors import MediaNotConfigured
from app.services.platform.storage import LocalStorage, sha256_hex
from app.sources.errors import CapabilityMismatch
from app.sources.gold import verify_scripture
from app.sources.scripture import insert
from app.sources.store import source_id
from tests.media.test_core import audio
from tests.sources.synthetic import mushaf
from tests.sources.test_scripture import audio as audio_source


async def test_licensed_segment_insertion_and_gold_verification_use_actual_cut_bytes(
    storage: LocalStorage, settings: Settings, tmp_path: Path,
) -> None:
    approval = {"status": "approved", "approved_by": "synthetic test", "approved_on": "2026-01-01"}
    path = tmp_path / "media.yaml"
    path.write_text(yaml.safe_dump({"schema": "qabas.media_policy/1", "fixture_only": True,
                                  "recitation": {**approval, "licence": approval,
                                                 "provider": "quran_com", "reciter": "Synthetic reciter",
                                                 "reciter_id": 7}}))
    settings = settings.model_copy(update={"media_policy_path": path})
    source = audio_source()
    source = replace(source, data={**source.data, "reciter_id": 7})
    clipped, record = await recitation.build(storage, settings, mushaf(), source, audio(), run_id="run_fixture",
        surah=1, ayah=1, word_start=2, word_end=4, reciter="Synthetic reciter", original_sha256=sha256_hex(audio()))
    assert len(await objects.verify(storage, record)) == record.size
    inserted = insert(mushaf(), 1, (1, 1), word_range=(2, 4), audio=clipped, reciter="Synthetic reciter")
    body = inserted.evidence.quran.model_dump(mode="json")
    assert body["audio"]["url"] == record.public_url(storage)
    assert [word["position"] for word in body["audio"]["words"]] == [2, 3, 4]
    assert body["audio"]["words"][0]["start_ms"] == 0
    canonical = inserted.source
    identifier = inserted.evidence.evidence_id
    package: dict[str, Any] = {"sources": [{"source_id": identifier, "kind": "quran", "provider": canonical.provider,
        "title": canonical.title, "reference": canonical.reference, "excerpt": canonical.text, "url": canonical.url}],
        "evidence": inserted.evidence.model_dump(mode="json")}
    records = {identifier: canonical, source_id(clipped): clipped}
    verify_scripture(package, records, mushaf=mushaf())
    corrupted = copy.deepcopy(clipped.data)
    corrupted["reference_clip"]["words"][0]["position"] = 1
    with pytest.raises(CapabilityMismatch, match="timings"):
        insert(mushaf(), 1, (1, 1), word_range=(2, 4), audio=replace(clipped, data=corrupted),
               reciter="Synthetic reciter")
    with pytest.raises(CapabilityMismatch, match="published clip"):
        insert(mushaf(), 1, (1, 1), word_range=(2, 4), audio=source, reciter="Synthetic reciter")
    for malformed in ({}, {**clipped.data["reference_clip"], "cut": {}}, "invalid"):
        with pytest.raises(CapabilityMismatch, match="malformed"):
            insert(mushaf(), 1, (1, 1), word_range=(2, 4),
                   audio=replace(clipped, data={**clipped.data, "reference_clip": malformed}),
                   reciter="Synthetic reciter")


async def test_unapproved_recitation_or_wrong_reciter_never_creates_an_object(
    storage: LocalStorage, settings: Settings,
) -> None:
    with pytest.raises(MediaNotConfigured):
        await recitation.build(storage, settings, mushaf(), audio_source(), audio(), run_id="run_fixture",
            surah=1, ayah=1, word_start=2, word_end=4, reciter="Synthetic reciter", original_sha256=sha256_hex(audio()))
