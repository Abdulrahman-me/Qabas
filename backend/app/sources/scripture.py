"""Verified scripture insertion. Discovery results never enter this path.

Arabic always comes from Mushaf.get. A specialist-selected, versioned QuranEnc translation must identify
the same ayah and agree with its Arabic. Audio is optional capability data; invalid timings become null.
"""

from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from urllib.parse import urljoin, urlsplit

import yaml
from pydantic import BaseModel, ConfigDict

from app.config import BACKEND_DIR, Settings
from app.contract import models as C
from app.sources.errors import CapabilityMismatch, SourceError
from app.sources.mushaf import Mushaf, Passage, ReferenceNotFound
from app.sources.normalize import normalize_ar
from app.sources.records import Part, Retrieval, SourceRecord, sha256_text, utcnow
from app.sources.store import source_id

TRANSLATIONS = BACKEND_DIR / "content" / "sources" / "translations.yaml"


class TranslationUnselected(SourceError):
    pass


class TranslationChoice(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    key: str
    version: str


def translation_choice(language: str, path: Path = TRANSLATIONS) -> TranslationChoice:
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    if data.get("schema") != "qabas.quran_translations/1":
        raise TranslationUnselected("quranenc", "unknown translation manifest schema")
    choice = (data.get("languages") or {}).get(language)
    if data.get("status") != "approved" or not data.get("approved_by") or not data.get("approved_on") or not choice:
        raise TranslationUnselected("quranenc", f"{language} translation is unselected; specialist approval required")
    return TranslationChoice.model_validate(choice)


@dataclass(frozen=True)
class VerifiedScripture:
    evidence: Any  # revision 10 contract Evidence (contract models are deliberately isolated from mypy)
    source: SourceRecord
    records: tuple[SourceRecord, ...]


def _translation(mushaf: Mushaf, passage: Passage, language: str, records: tuple[SourceRecord, ...],
                 manifest: Path) -> tuple[str, str, tuple[Part, ...]]:
    choice = translation_choice(language, manifest)
    if passage.word_start is not None:
        raise TranslationUnselected("quranenc", "word-segment meanings require a separately approved excerpt")
    wanted = {f"{choice.key}:{passage.surah}:{ayah}" for ayah in range(passage.ayah_start, passage.ayah_end + 1)}
    found = {record.provider_record_id: record for record in records}
    if len(found) != len(records) or set(found) != wanted:
        raise CapabilityMismatch("quranenc", "translation records do not exactly cover the requested ayahs")
    text, parts, titles = [], [], set()
    for ayah in range(passage.ayah_start, passage.ayah_end + 1):
        record = found[f"{choice.key}:{passage.surah}:{ayah}"]
        canonical = mushaf.get(passage.surah, ayah)
        if record.provider != "quranenc" or record.reference != f"{passage.surah}:{ayah}" or \
                record.data.get("language") != language or record.data.get("translation_key") != choice.key or \
                str(record.data.get("translation_version")) != choice.version or \
                normalize_ar(record.data.get("arabic_text", "")) != normalize_ar(canonical.text_uthmani):
            raise CapabilityMismatch("quranenc", "translation identity, version or Arabic differs from canonical verse")
        if not record.text.strip():
            raise CapabilityMismatch("quranenc", "translation is empty")
        text.append(record.text)
        titles.add(record.title)
        parts.append(Part("translation", "quranenc", record.provider_record_id, version=choice.version,
                          sha256=record.retrieval.response_sha256,
                          checks=("verse_identity", "canonical_arabic", "specialist_selection", "translation_version")))
    if len(titles) != 1:
        raise CapabilityMismatch("quranenc", "translation titles disagree")
    return "\n".join(text), next(iter(titles)), tuple(parts)


def _audio(mushaf: Mushaf, passage: Passage, record: SourceRecord, reciter: str,
           base_url: str) -> tuple[Any, tuple[Part, ...]]:
    if passage.ayah_start != passage.ayah_end or record.provider != "quran_com" or \
            record.data.get("verse_key") != f"{passage.surah}:{passage.ayah_start}":
        raise CapabilityMismatch("quran_com", "audio does not identify this single ayah")
    whole = mushaf.get(passage.surah, passage.ayah_start, passage.ayah_end)
    words = [word for word in record.data.get("words", [])
             if isinstance(word, dict) and word.get("char_type_name") == "word"]
    if len(words) != len(whole.words) or any(
            word.get("position") != canonical.position or
            normalize_ar(word.get("text_qpc_hafs", "")) != normalize_ar(canonical.text)
            for word, canonical in zip(words, whole.words, strict=True)):
        raise CapabilityMismatch("quran_com", "audio word identity differs from canonical verse")
    audio = record.data.get("audio")
    if not isinstance(audio, dict) or not isinstance(audio.get("url"), str) or not reciter.strip():
        raise CapabilityMismatch("quran_com", "audio URL or reciter is missing")
    url = urljoin(base_url, audio["url"])
    if urlsplit(url).scheme != "https" or not urlsplit(url).hostname:
        raise CapabilityMismatch("quran_com", "audio URL must use HTTPS")
    timings, reason = [], None
    segments = audio.get("segments")
    if not isinstance(segments, list) or len(segments) != len(whole.words):
        reason = "timing_count_mismatch"
    else:
        previous = -1
        for index, (segment, canonical) in enumerate(zip(segments, whole.words, strict=True)):
            if not isinstance(segment, list) or len(segment) != 4 or any(type(n) is not int for n in segment) or \
                    segment[0] != index or segment[1] != canonical.position or \
                    segment[2] < 0 or segment[3] <= segment[2] or segment[2] < previous:
                reason = "invalid_timing_segments"
                break
            previous = segment[3]
            if passage.word_start is None or passage.word_start <= canonical.position <= (passage.word_end or 0):
                timings.append(C.WordTiming(ayah=canonical.ayah, position=canonical.position, text=canonical.text,
                                            start_ms=segment[2], end_ms=segment[3]))
    parts = [Part("audio", record.provider, record.provider_record_id, sha256=record.retrieval.response_sha256,
                  checks=("verse_identity", "canonical_words"))]
    parts.append(Part("timing", record.provider, record.provider_record_id, sha256=record.retrieval.response_sha256,
                      checks=("word_count", "positions", "chronological") if reason is None else (),
                      meta={} if reason is None else {"rejected": reason}))
    return C.Audio(reciter=reciter, url=url, words=timings if reason is None else None), tuple(parts)


def insert(mushaf: Mushaf, surah: int, ayah_range: tuple[int, int], *, language: str = "ar",
           word_range: tuple[int, int] | None = None, translations: tuple[SourceRecord, ...] = (),
           translation_manifest: Path = TRANSLATIONS, audio: SourceRecord | None = None,
           reciter: str | None = None, audio_base: str = "https://verses.quran.com/") -> VerifiedScripture:
    passage = mushaf.get(surah, *ayah_range, word_start=word_range[0] if word_range else None,
                        word_end=word_range[1] if word_range else None)
    translation, title = None, None
    translation_parts: tuple[Part, ...] = ()
    localized: dict[str, dict[str, str]] = {}
    for selected_language in sorted({str(record.data.get("language")) for record in translations}):
        selected_records = tuple(record for record in translations if record.data.get("language") == selected_language)
        text, source_title, selected_parts = _translation(
            mushaf, passage, selected_language, selected_records, translation_manifest)
        localized[selected_language] = {"text": text, "source": source_title}
        translation_parts += selected_parts
    if language != "ar":
        if language not in localized:
            translation_choice(language, translation_manifest)
            raise CapabilityMismatch("quranenc", "selected translation records are missing")
        translation, title = localized[language]["text"], localized[language]["source"]
    parts: tuple[Part, ...] = (Part("text_authority", "mushaf", passage.key, version=passage.dataset.version,
                  sha256=passage.dataset.member_sha256, checks=("pinned_dataset_digest", "canonical_reference"),
                  meta=passage.dataset.provenance()), *translation_parts)
    capability_audio = None
    audio_parts: tuple[Part, ...] = ()
    if audio is not None:
        capability_audio, audio_parts = _audio(mushaf, passage, audio, reciter or "", audio_base)
        parts += audio_parts
    from app.sources.records import canonical_json
    binding = sha256_text(canonical_json([part.as_dict() for part in (*translation_parts, *audio_parts)]))[:20]
    record_id = f"mushaf:{passage.dataset.id}:{passage.key}:{binding}"
    response = {"dataset": passage.dataset.provenance(), "reference": passage.key,
                "text_uthmani": passage.text_uthmani, "translations": [r.raw() for r in translations],
                "audio": audio.raw() if audio is not None else None}
    record = SourceRecord("quran_com", record_id, "quran", passage.dataset.title, passage.key,
                          passage.text_uthmani, passage.dataset.url, "scripture/1",
                          Retrieval("mushaf.get", "get", {"surah": surah, "ayah_range": list(ayah_range),
                                                         "word_range": list(word_range) if word_range else None,
                                                         "translation_languages": sorted(localized)}, response,
                                    sha256_text(canonical_json(response)), utcnow()), parts,
                          {"dataset": passage.dataset.id, "translations": localized,
                           "audio": capability_audio.model_dump(mode="json") if capability_audio else None})
    evidence = C.Evidence(evidence_id=source_id(record), kind="quran", hadith=None, quran=C.QuranBody(
        surah=surah, surah_name=passage.surah_name_ar if language == "ar" else passage.surah_name_en,
        ayah_start=ayah_range[0], ayah_end=ayah_range[1],
        segment=C.Segment(word_start=word_range[0], word_end=word_range[1]) if word_range else None,
        text_uthmani=passage.text_uthmani, translation=translation, translation_source=title, audio=capability_audio))
    return VerifiedScripture(evidence, record, translations + ((audio,) if audio is not None else ()))


@dataclass(frozen=True)
class ScriptureBindings:
    bindings: dict[tuple[str, str], VerifiedScripture]
    errors: dict[tuple[str, str], SourceError | ReferenceNotFound]

    def __call__(self, reference: str, language: str) -> VerifiedScripture:
        key = (reference, language)
        if key in self.errors:
            raise self.errors[key]
        if key not in self.bindings:
            raise TranslationUnselected("mushaf", "reference/language was not prepared for this authoring package")
        return self.bindings[key]


async def prepare_references(mushaf: Mushaf, references: Sequence[str], settings: Settings, *,
                             translator: Any = None, translation_manifest: Path = TRANSLATIONS) -> ScriptureBindings:
    """Prepare one shared bilingual bundle per reference. Pending translations perform no provider calls."""
    from app.sources.providers.quranenc import QuranEnc
    bindings: dict[tuple[str, str], VerifiedScripture] = {}
    errors: dict[tuple[str, str], SourceError | ReferenceNotFound] = {}
    choice, selection_error = None, None
    try:
        choice = translation_choice("en", translation_manifest)
    except TranslationUnselected as exc:
        selection_error = exc
    owned = translator is None and choice is not None
    if owned:
        translator = QuranEnc.create(settings)
    fetched: dict[tuple[int, int], SourceRecord] = {}
    try:
        for reference in dict.fromkeys(references):
            try:
                passage = mushaf.resolve(reference)
            except ReferenceNotFound as exc:
                errors[reference, "ar"] = errors[reference, "en"] = exc
                continue
            selected: tuple[SourceRecord, ...] = ()
            if selection_error is not None:
                errors[reference, "en"] = selection_error
            else:
                try:
                    assert choice is not None and translator is not None
                    for ayah in range(passage.ayah_start, passage.ayah_end + 1):
                        key = (passage.surah, ayah)
                        if key not in fetched:
                            fetched[key] = await translator.translation(passage.surah, ayah, choice.key, "en")
                    selected = tuple(fetched[passage.surah, ayah]
                                     for ayah in range(passage.ayah_start, passage.ayah_end + 1))
                    bindings[reference, "en"] = insert(mushaf, passage.surah,
                        (passage.ayah_start, passage.ayah_end), language="en", translations=selected,
                        translation_manifest=translation_manifest)
                except SourceError as exc:
                    errors[reference, "en"] = exc
                    selected = ()
            bindings[reference, "ar"] = insert(mushaf, passage.surah, (passage.ayah_start, passage.ayah_end),
                translations=selected, translation_manifest=translation_manifest)
    finally:
        if owned:
            await translator.aclose()
    return ScriptureBindings(bindings, errors)
