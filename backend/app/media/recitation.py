"""Licensed reference clips with canonical word identity. This is not TTS or learner recitation checking."""

from __future__ import annotations

from dataclasses import replace
from datetime import UTC, datetime
from typing import Any

from app.config import Settings
from app.media import objects
from app.media.audio import reference_clip
from app.media.errors import MediaInvalid, MediaNotConfigured
from app.media.policy import POLICY, approved, policy
from app.services.platform.storage import ObjectStorage
from app.sources.mushaf import Mushaf
from app.sources.records import SourceRecord
from app.sources.scripture import _audio


async def build(
    storage: ObjectStorage,
    settings: Settings,
    mushaf: Mushaf,
    source: SourceRecord,
    data: bytes,
    *,
    run_id: str,
    surah: int,
    ayah: int,
    word_start: int,
    word_end: int,
    reciter: str,
    original_sha256: str,
    audio_base: str = "https://verses.quran.com/",
) -> tuple[SourceRecord, objects.MediaObject]:
    """Only explicit source bindings and licensed bytes; never discover/download arbitrary model URLs.

    The returned capability snapshot can be used by scripture.insert/gold verification. Its object receipt
    must also be included in the reviewed media bundle for immutable promotion at Gate 2.
    """
    document = policy(settings.media_policy_path or POLICY)
    if document.get("fixture_only") and not settings.is_dev_like:
        raise MediaNotConfigured("synthetic recitation policy cannot enable production clips")
    terms = document["recitation"]
    approved(terms, "reference recording and reciter licence (O-06)")
    approved(terms["licence"], "recitation distribution licence")
    if terms.get("provider") != source.provider or terms.get("reciter") != reciter:
        raise MediaNotConfigured("reference recording provider/reciter differs from its approved licence")
    reciter_id = terms.get("reciter_id")
    if type(reciter_id) is not int or reciter_id < 1 or source.data.get("reciter_id") != reciter_id:
        raise MediaNotConfigured("reference recording reciter ID differs from its approved licence")
    whole = mushaf.get(surah, ayah)
    selected = mushaf.get(surah, ayah, word_start=word_start, word_end=word_end)
    audio, _ = _audio(mushaf, whole, source, reciter, audio_base)
    if not audio.words or source.data.get("reference_clip"):
        raise MediaInvalid("reference clips need verified whole-ayah audio with every word timing")
    timings = [[word.position, word.start_ms, word.end_ms] for word in audio.words]
    start, end = timings[word_start - 1][1], timings[word_end - 1][2]
    raw, rebased, cut = reference_clip(
        data,
        expected_sha256=original_sha256,
        start_ms=start,
        end_ms=end,
        timings=timings,
        word_start=word_start,
        word_end=word_end,
        canonical_word_count=len(whole.words),
    )
    binding: dict[str, Any] = {
        "surah": surah,
        "ayah": ayah,
        "word_start": word_start,
        "word_end": word_end,
        "reciter": reciter,
        "reciter_id": reciter_id,
        "dataset_sha256": whole.dataset.member_sha256,
    }
    record = await objects.stage(
        storage,
        run_id=run_id,
        prefix="recitation-clips",
        data=raw,
        mime_type="audio/mpeg",
        kind="reference_clip",
        licence=terms["licence"],
        binding=binding,
        provenance={
            "provider": source.provider,
            "source_record_id": source.provider_record_id,
            "source_response_sha256": source.retrieval.response_sha256,
            "original_url": audio.url,
            "cut": cut,
            "created_at": datetime.now(UTC).isoformat(),
        },
    )
    words = [
        {"ayah": ayah, "position": position, "text": word.text, "start_ms": lo, "end_ms": hi}
        for (position, lo, hi), word in zip(rebased, selected.words, strict=True)
    ]
    clip = {
        "url": record.public_url(storage),
        "sha256": record.sha256,
        "binding": binding,
        "words": words,
        "cut": cut,
        "licence": terms["licence"],
    }
    return replace(source, data={**source.data, "reference_clip": clip}), record
