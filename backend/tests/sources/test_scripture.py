"""Insertion uses references and canonical neutral test text; fuzzy discovery never inserts."""

import copy
import json
from dataclasses import replace
from pathlib import Path

import pytest
import yaml

from app.config import Settings
from app.sources.errors import CapabilityMismatch
from app.sources.gold import verify_scripture
from app.sources.records import Part, Retrieval, SourceRecord, sha256_text, utcnow
from app.sources.scripture import TranslationUnselected, insert, prepare_references
from tests.sources.synthetic import mushaf


def translation() -> SourceRecord:
    return SourceRecord("quranenc", "fixture_key:1:1", "quran", "Synthetic translation", "1:1",
                        "Neutral translation sentence", None, "quranenc/1",
                        Retrieval("quranenc.translation", "translation", {}, {}, sha256_text("fixture"), utcnow()),
                        (Part("translation", "quranenc", "fixture_key:1:1", version="1"),),
                        {"language": "en", "translation_key": "fixture_key", "translation_version": "1",
                         "arabic_text": mushaf().get(1, 1).text_uthmani})


def manifest(tmp_path: Path) -> Path:
    path = tmp_path / "translations.yaml"
    path.write_text(yaml.safe_dump({"schema": "qabas.quran_translations/1", "status": "approved",
                                   "approved_by": "test specialist", "approved_on": "2026-10-05",
                                   "languages": {"en": {"key": "fixture_key", "version": "1"}}}))
    return path


def audio() -> SourceRecord:
    canonical = mushaf().get(1, 1)
    return SourceRecord("quran_com", "1:1@7", "quran", "Synthetic audio metadata", "1:1", canonical.text_uthmani,
                        None, "quran_foundation/1", Retrieval("quran_com.get", "get", {}, {},
                                                              sha256_text("fixture-audio"), utcnow()), (),
                        {"verse_key": "1:1", "words": [{"position": word.position, "char_type_name": "word",
                                                          "text_qpc_hafs": word.text} for word in canonical.words],
                         "audio": {"url": "fixture.mp3", "segments": [
                             [i, word.position, i * 100, i * 100 + 90] for i, word in enumerate(canonical.words)]}})


def test_whole_range_and_segment_are_loaded_without_typing_scripture() -> None:
    canonical = mushaf()
    whole = insert(canonical, 1, (1, 2))
    assert whole.evidence.quran.text_uthmani == canonical.get(1, 1, 2).text_uthmani
    assert whole.evidence.quran.translation is whole.evidence.quran.audio is None
    assert whole.source.parts[0].provider == "mushaf" and whole.source.provider == "quran_com"
    segment = insert(canonical, 1, (1, 1), word_range=(2, 4))
    assert segment.evidence.quran.text_uthmani == canonical.get(1, 1, word_start=2, word_end=4).text_uthmani
    with pytest.raises(TypeError):
        insert(canonical, "fuzzy query", (1, 1))  # type: ignore[arg-type]


def test_same_bilingual_bundle_has_one_identity_and_new_bindings_get_a_new_identity(tmp_path: Path) -> None:
    choice, selected = manifest(tmp_path), translation()
    ar = insert(mushaf(), 1, (1, 1), translations=(selected,), translation_manifest=choice)
    en = insert(mushaf(), 1, (1, 1), language="en", translations=(selected,), translation_manifest=choice)
    assert ar.evidence.evidence_id == en.evidence.evidence_id and ar.source.parts == en.source.parts
    bare = insert(mushaf(), 1, (1, 1))
    assert bare.evidence.evidence_id != ar.evidence.evidence_id


def test_translation_requires_selected_version_and_matching_arabic(tmp_path: Path) -> None:
    with pytest.raises(TranslationUnselected):
        insert(mushaf(), 1, (1, 1), language="en", translations=(translation(),))
    path = manifest(tmp_path)
    verified = insert(mushaf(), 1, (1, 1), language="en", translations=(translation(),), translation_manifest=path)
    assert verified.evidence.quran.translation == translation().text
    assert verified.source.parts[1].checks == (
        "verse_identity", "canonical_arabic", "specialist_selection", "translation_version")
    for field, value in (("arabic_text", "different neutral Arabic"), ("translation_version", "2"),
                         ("language", "fr"), ("translation_key", "wrong")):
        changed = replace(translation(), data={**translation().data, field: value})
        error = TranslationUnselected if field == "language" else CapabilityMismatch
        with pytest.raises(error):
            insert(mushaf(), 1, (1, 1), language="en", translations=(changed,), translation_manifest=path)
    with pytest.raises(TranslationUnselected, match="excerpt"):
        insert(mushaf(), 1, (1, 1), word_range=(2, 4), language="en",
               translations=(translation(),), translation_manifest=path)


@pytest.mark.parametrize("invalid", ["count", "position", "duration", "overlap", "bool"])
def test_invalid_timings_keep_audio_but_no_word_highlighting(invalid: str) -> None:
    record = audio()
    data = copy.deepcopy(record.data)
    segments = data["audio"]["segments"]
    if invalid == "count":
        segments.pop()
    elif invalid == "position":
        segments[0][1] = 99
    elif invalid == "duration":
        segments[0][3] = -1
    elif invalid == "overlap":
        segments[1][2] = 0
    else:
        segments[0][0] = False
    verified = insert(mushaf(), 1, (1, 1), audio=replace(record, data=data), reciter="Synthetic reciter")
    assert verified.evidence.quran.audio.url.endswith("fixture.mp3")
    assert verified.evidence.quran.audio.words is None
    assert "rejected" in verified.source.parts[-1].meta and not verified.source.parts[-1].checks


def test_audio_cross_checks_words_and_uses_canonical_timing_text() -> None:
    verified = insert(mushaf(), 1, (1, 1), audio=audio(), reciter="Synthetic reciter")
    assert [word.position for word in verified.evidence.quran.audio.words] == [1, 2, 3, 4, 5]
    assert [part.role for part in verified.source.parts] == ["text_authority", "audio", "timing"]
    # A segment never borrows the whole-ayah clip (F-79): its clip is cut to the exact words at publish time.
    with pytest.raises(CapabilityMismatch, match="segment"):
        insert(mushaf(), 1, (1, 1), audio=audio(), reciter="Synthetic reciter", word_range=(2, 4))
    data = copy.deepcopy(audio().data)
    data["words"][0]["text_qpc_hafs"] = "different"
    with pytest.raises(CapabilityMismatch, match="word identity"):
        insert(mushaf(), 1, (1, 1), audio=replace(audio(), data=data), reciter="Synthetic reciter")
    with pytest.raises(CapabilityMismatch):
        insert(mushaf(), 1, (1, 2), audio=audio(), reciter="Synthetic reciter")


def test_gold_recursive_verification_and_segment_mismatch() -> None:
    verified = insert(mushaf(), 1, (1, 1), word_range=(2, 4))
    record = verified.source
    identifier = verified.evidence.evidence_id
    package = {"sources": [{"source_id": identifier, "kind": record.kind, "provider": record.provider,
                            "title": record.title, "reference": record.reference, "excerpt": record.text,
                            "url": record.url}], "nested": [{"payload": {"verse": verified.evidence.model_dump()}}]}
    verify_scripture(package, {identifier: record}, mushaf=mushaf())
    changed = json.loads(json.dumps(package))
    changed["nested"][0]["payload"]["verse"]["quran"]["segment"]["word_end"] = 5
    with pytest.raises(CapabilityMismatch, match="word range"):
        verify_scripture(changed, {identifier: record}, mushaf=mushaf())
    with pytest.raises(CapabilityMismatch, match="provenance"):
        verify_scripture(package, {}, mushaf=mushaf())


async def test_pending_selection_prepares_arabic_without_any_provider_calls() -> None:
    class ForbiddenTranslator:
        async def translation(self, *args: object) -> SourceRecord:
            raise AssertionError("unselected translation attempted provider access")
    prepared = await prepare_references(mushaf(), ["1:1", "1:1"], Settings(), translator=ForbiddenTranslator())
    assert prepared("1:1", "ar").evidence.quran.text_uthmani == mushaf().get(1, 1).text_uthmani
    with pytest.raises(TranslationUnselected):
        prepared("1:1", "en")


async def test_approved_selection_prepares_shared_bundle_and_rejects_source_mismatch(tmp_path: Path) -> None:
    class FixtureTranslator:
        calls = 0
        async def translation(self, *args: object) -> SourceRecord:
            self.calls += 1
            return translation()
    client = FixtureTranslator()
    prepared = await prepare_references(mushaf(), ["1:1", "1:1"], Settings(), translator=client,
                                         translation_manifest=manifest(tmp_path))
    assert client.calls == 1
    assert prepared("1:1", "ar").evidence.evidence_id == prepared("1:1", "en").evidence.evidence_id
    class WrongTranslator:
        async def translation(self, *args: object) -> SourceRecord:
            return replace(translation(), data={**translation().data, "arabic_text": "different"})
    refused = await prepare_references(mushaf(), ["1:1"], Settings(), translator=WrongTranslator(),
                                        translation_manifest=manifest(tmp_path))
    assert refused("1:1", "ar").evidence.quran.translation is None
    with pytest.raises(CapabilityMismatch):
        refused("1:1", "en")


async def test_gold_hadith_binding_grades_and_excerpts_are_verified_from_recordings() -> None:
    from app.sources.providers.dorar import Dorar
    from app.sources.store import source_id
    from tests.sources.transport import RecordedTransport
    adapter = Dorar.create(Settings(), transport=RecordedTransport("dorar"))
    try:
        record = await adapter.get("JIDbtVSz")
    finally:
        await adapter.aclose()
    identifier = source_id(record)
    body = {"text_ar": record.text, "translation": None, "narrator": record.data["narrator"],
            "collections": [record.reference], "grade_label": record.data["grade_label"],
            "grade_category": record.data["grade_category"], "grade_source": record.data["grader"], "excerpt": False}
    package = {"sources": [{"source_id": identifier, "kind": record.kind, "provider": record.provider,
                            "title": record.title, "reference": record.reference, "excerpt": record.text,
                            "url": record.url}], "evidence": {"evidence_id": identifier, "kind": "hadith",
                                                                  "quran": None, "hadith": body}}
    verify_scripture(package, {identifier: record})
    body["grade_category"] = "fabricated"
    with pytest.raises(CapabilityMismatch, match="grade category"):
        verify_scripture(package, {identifier: record})
    body["grade_category"] = record.data["grade_category"]
    body["excerpt"] = True
    body["text_ar"] = record.text[:len(record.text) // 2]
    verify_scripture(package, {identifier: record})
    body["text_ar"] = "invented neutral replacement"
    with pytest.raises(CapabilityMismatch, match="excerpt"):
        verify_scripture(package, {identifier: record})
