"""Licensed reference clips with canonical word identity. This is not TTS or learner recitation checking."""

from __future__ import annotations

from collections.abc import Mapping
from dataclasses import replace
from datetime import UTC, datetime
from pathlib import Path
from typing import Any, Protocol, cast

from app.config import Settings
from app.media import objects
from app.media.audio import reference_clip
from app.media.errors import MediaInvalid, MediaNotConfigured
from app.media.policy import POLICY, approved, policy, read_yaml
from app.services.platform.storage import ObjectStorage, sha256_hex
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
    # A clip is a derived capability snapshot: its identity names the cut, so two cuts of one ayah (a whole-ayah
    # evidence clip and a recited segment) never collide in a provenance map keyed by record identity (F-139).
    derived = f"{source.provider_record_id}#w{word_start}-{word_end}@{record.sha256[:16]}"
    return replace(source, provider_record_id=derived, data={**source.data, "reference_clip": clip}), record


class ReferenceRecordings(Protocol):
    """Licensed whole-ayah recordings of the approved reciter (O-06), supplied by an operator, never downloaded."""

    reciter_id: int

    def recording(self, surah: int, ayah: int) -> tuple[bytes, str]:
        """(MP3 bytes, their SHA-256) of exactly the recording whose timings the capability provider reports."""
        ...


class DirectoryRecordings:
    """``recordings.yaml`` (``schema: qabas.reference_recordings/1``, ``reciter_id``, ``items`` of
    ``{surah, ayah, file, sha256}``) beside the licensed MP3 files. Every read is verified against its digest."""

    def __init__(self, root: Path) -> None:
        if not (root / "recordings.yaml").is_file():
            raise MediaNotConfigured("the reference recordings directory has no recordings.yaml (O-06)")
        manifest = read_yaml(root / "recordings.yaml")
        if manifest.get("schema") != "qabas.reference_recordings/1" or type(manifest.get("reciter_id")) is not int:
            raise MediaNotConfigured("reference recordings manifest is missing or malformed")
        self.root, self.reciter_id = root.resolve(), int(manifest["reciter_id"])
        self.items: dict[tuple[int, int], dict[str, Any]] = {}
        for item in manifest.get("items", []):
            key = (int(item["surah"]), int(item["ayah"]))
            if key in self.items or not str(item.get("sha256", "")).isalnum() or len(str(item["sha256"])) != 64:
                raise MediaNotConfigured("reference recordings manifest repeats an ayah or lacks a digest")
            self.items[key] = item

    def recording(self, surah: int, ayah: int) -> tuple[bytes, str]:
        item = self.items.get((surah, ayah))
        if item is None:
            raise MediaNotConfigured(f"no licensed reference recording for {surah}:{ayah} (O-06)")
        path = (self.root / str(item["file"])).resolve()
        if not path.is_relative_to(self.root) or not path.is_file():
            raise MediaNotConfigured(f"licensed reference recording for {surah}:{ayah} is missing")
        data = path.read_bytes()
        if sha256_hex(data) != item["sha256"]:
            raise MediaInvalid(f"licensed reference recording for {surah}:{ayah} changed")
        return data, str(item["sha256"])


def recordings(settings: Settings, services: Mapping[str, Any]) -> ReferenceRecordings | None:
    supplied = services.get("recordings")
    if supplied is not None:
        return cast(ReferenceRecordings, supplied)
    if settings.media_reference_recordings_dir is None:
        return None
    return DirectoryRecordings(settings.media_reference_recordings_dir)


def approved_terms(settings: Settings) -> dict[str, Any] | None:
    """The approved recitation entry, or None while O-06 is pending (synthetic approvals only in dev/test)."""
    document = policy(settings.media_policy_path or POLICY)
    if document.get("fixture_only") and not settings.is_dev_like:
        return None
    terms = document.get("recitation")
    if not isinstance(terms, dict):
        return None
    try:
        approved(terms, "reference recording and reciter licence (O-06)")
        approved(terms["licence"], "recitation distribution licence")
    except MediaNotConfigured:
        return None
    return terms


def recitation_available(ctx: Any) -> bool:
    """Whether this run may author recitation activities and attach reference audio (factory §13.1 stage 9)."""
    terms = approved_terms(ctx.settings)
    library = recordings(ctx.settings, ctx.services) if terms is not None else None
    return library is not None and terms is not None and library.reciter_id == terms.get("reciter_id")


async def reference_audio(ctx: Any, storage: ObjectStorage, *, mushaf: Mushaf, tools: Any, surah: int, ayah: int,
                          word_range: tuple[int, int] | None,
                          translations: tuple[SourceRecord, ...] = ()) -> tuple[Any, Any, objects.MediaObject]:
    """Licensed reference audio for a canonical passage: the capability timings of the approved reciter, the
    licensed bytes of that same recording, an exact cut, and the verified scripture bundle carrying it.
    Returns (VerifiedScripture for Arabic, VerifiedScripture for English or None, clip receipt)."""
    from app.sources.scripture import insert

    terms = approved_terms(ctx.settings)
    library = recordings(ctx.settings, ctx.services)
    if terms is None or library is None or library.reciter_id != terms.get("reciter_id"):
        raise MediaNotConfigured("licensed reference recitation is not available (O-06)")
    capability = await tools.quran_audio(surah, ayah, int(terms["reciter_id"]))
    data, digest = library.recording(surah, ayah)
    words = len(mushaf.get(surah, ayah).words)
    start, end = word_range or (1, words)
    clip_source, receipt = await build(storage, ctx.settings, mushaf, capability, data, run_id=ctx.run.id,
                                       surah=surah, ayah=ayah, word_start=start, word_end=end,
                                       reciter=str(terms["reciter"]), original_sha256=digest)
    translations = translations if word_range is None else ()   # segment meanings need their own approval
    manifest = tools.translation_manifest
    arabic = insert(mushaf, surah, (ayah, ayah), word_range=word_range, translations=translations,
                    audio=clip_source, reciter=str(terms["reciter"]), translation_manifest=manifest)
    english = None
    if translations and word_range is None:
        english = insert(mushaf, surah, (ayah, ayah), language="en", translations=translations,
                         audio=clip_source, reciter=str(terms["reciter"]), translation_manifest=manifest)
    return arabic, english, receipt
