"""Mechanical gold-import scripture checks (factory 13.7.3), before any writes.

No fuzzy correction, no automatic repair, and no production fixture exceptions. Private source snapshots
carry adapter provenance; missing, stale or mismatching scripture is rejected even before specialist review.
"""

from __future__ import annotations

from typing import Any

from app.config import get_settings
from app.sources.errors import CapabilityMismatch
from app.sources.grades import classify
from app.sources.mushaf import Mushaf, get_mushaf
from app.sources.normalize import normalize_ar
from app.sources.records import SourceRecord
from app.sources.scripture import TRANSLATIONS, insert


def verify_scripture(package: dict[str, Any], records: dict[str, SourceRecord], *,
                     mushaf: Mushaf | None = None) -> None:
    sources = {item["source_id"]: item for item in package["sources"]}
    references: list[tuple[str, dict[str, Any], str | None]] = []
    hadiths: list[tuple[str, dict[str, Any]]] = []

    def walk(node: Any, language: str | None = None) -> None:
        if isinstance(node, dict):
            if node.get("kind") == "quran" and isinstance(node.get("quran"), dict):
                references.append((node["evidence_id"], node["quran"], language))
            if node.get("kind") == "hadith" and isinstance(node.get("hadith"), dict):
                hadiths.append((node["evidence_id"], node["hadith"]))
            if node.get("type") == "recite_verse" and isinstance(node.get("payload"), dict):
                payload = node["payload"]
                references.append((payload["source_id"], {"surah": payload["surah"], "ayah_start": payload["ayah"],
                    "ayah_end": payload["ayah"], "text_uthmani": payload["text_uthmani"],
                    "segment": None if payload["word_start"] is None else {
                        "word_start": payload["word_start"], "word_end": payload["word_end"]},
                    "audio": payload["audio"]}, None))
            for key, value in node.items():
                walk(value, key if key in {"ar", "en"} else language)
        elif isinstance(node, list):
            for value in node:
                walk(value, language)

    walk(package)
    for identifier, body in hadiths:
        record = records.get(identifier)
        if record is None or record.provider != "dorar" or record.kind != "hadith" or \
                not any(part.role == "grade" and part.provider == "dorar" for part in record.parts):
            raise CapabilityMismatch("dorar", f"{identifier}: verified Dorar binding is required")
        text_ar = body["text_ar"]
        if not text_ar.strip() or (text_ar not in record.text if body["excerpt"] else text_ar != record.text):
            raise CapabilityMismatch("dorar", f"{identifier}: hadith text/excerpt differs from provider record")
        for field, recorded in (("narrator", "narrator"), ("grade_label", "grade_label"), ("grade_source", "grader")):
            if not record.data.get(recorded) or body[field] != record.data[recorded]:
                raise CapabilityMismatch("dorar", f"{identifier}: {field} differs from recorded attribution")
        if body["grade_category"] != classify(record.data["grade_label"]) or body["collections"] != [record.reference]:
            raise CapabilityMismatch("dorar", f"{identifier}: grade category/collections need matching records")
        if body["translation"] is not None:
            if body["excerpt"]:
                raise CapabilityMismatch("hadeethenc", f"{identifier}: excerpt translation requires a reviewed binding")
            candidates = [item for item in records.values() if item.provider == "hadeethenc" and
                          item.text == body["translation"] and
                          normalize_ar(item.data.get("text_ar", "")) == normalize_ar(record.text) and
                          any(part.role == "translation" and part.provider == "hadeethenc" and
                              part.record_id == item.provider_record_id for part in record.parts)]
            if len(candidates) != 1:
                raise CapabilityMismatch("hadeethenc", f"{identifier}: translation binding is missing or ambiguous")
    for identifier, public in sources.items():
        if public["kind"] not in {"quran", "hadith"}:
            continue
        record = records.get(identifier)
        if record is None:
            raise CapabilityMismatch("sources", f"{identifier}: missing verified source provenance record")
        for field, private in (("provider", "provider"), ("kind", "kind"), ("title", "title"),
                               ("reference", "reference"), ("excerpt", "text"), ("url", "url")):
            if public[field] != getattr(record, private):
                raise CapabilityMismatch("sources", f"{identifier}: public metadata differs from verified record")
        if public["kind"] == "hadith":
            authoritative = record if record.provider == "dorar" else next((item for item in records.values()
                if item.provider == "dorar" and
                normalize_ar(item.text) == normalize_ar(record.data.get("text_ar", ""))), None)
            if authoritative is None or not any(part.role == "grade" and part.provider == "dorar"
                                                 for part in authoritative.parts):
                raise CapabilityMismatch("dorar", f"{identifier}: source needs a verified Dorar record binding")
            if not all(authoritative.data.get(field) for field in ("grade_label", "grader", "book", "number_or_page")):
                raise CapabilityMismatch("dorar", f"{identifier}: citation/grade metadata needs review")
    if not references and not any(item["kind"] == "quran" for item in sources.values()):
        return
    canonical = mushaf or get_mushaf(get_settings())
    referenced = {identifier for identifier, _, _ in references}
    for identifier, public in sources.items():
        if public["kind"] == "quran" and identifier not in referenced:
            record = records.get(identifier)
            if record is None or record.provider != "quran_com" or not any(
                    part.role == "text_authority" and part.provider == "mushaf" for part in record.parts):
                raise CapabilityMismatch("mushaf", f"{identifier}: uncited Quran source needs canonical provenance")
            args = record.retrieval.arguments
            ayahs, words = args["ayah_range"], args["word_range"]
            references.append((identifier, {"surah": args["surah"], "ayah_start": ayahs[0], "ayah_end": ayahs[1],
                "segment": None if words is None else {"word_start": words[0], "word_end": words[1]},
                "text_uthmani": record.text, "translation": record.data.get("translation"),
                "translation_source": record.data.get("translation_source"), "audio": record.data.get("audio")}, None))
    for identifier, body, content_language in references:
        if content_language == "en" and body.get("translation") is None:
            raise CapabilityMismatch("quranenc", f"{identifier}: English evidence requires a selected translation")
        segment = body.get("segment")
        passage = canonical.get(body["surah"], body["ayah_start"], body["ayah_end"],
                                word_start=segment["word_start"] if segment else None,
                                word_end=segment["word_end"] if segment else None)
        if body["text_uthmani"] != passage.text_uthmani:
            raise CapabilityMismatch("mushaf", f"{identifier}: text or word range differs from pinned mushaf")
        if body.get("surah_name") not in (None, passage.surah_name_ar, passage.surah_name_en):
            raise CapabilityMismatch("mushaf", f"{identifier}: surah name contradicts reference")
        record = records.get(identifier)
        if record is None:
            raise CapabilityMismatch("mushaf", f"{identifier}: verified source provenance is required")
        if record.provider != "quran_com" or record.text != passage.text_uthmani:
            raise CapabilityMismatch("mushaf", f"{identifier}: source text or provider differs")
        language = "ar"
        if body.get("translation") is not None:
            matches = [lang for lang, localized in record.data.get("translations", {}).items()
                       if localized["text"] == body["translation"] and
                       localized["source"] == body.get("translation_source")]
            if len(matches) != 1:
                raise CapabilityMismatch("mushaf", f"{identifier}: translation has no unambiguous verified binding")
            language = matches[0]
        translations = tuple(item for item in records.values() if item.provider == "quranenc" and
                             item.provider_record_id in {part.record_id for part in record.parts
                                                         if part.role == "translation"})
        audio_parts = [part for part in record.parts if part.role == "audio"]
        audio_record = next((item for item in records.values() if audio_parts and item.provider == "quran_com" and
                             item.provider_record_id == audio_parts[0].record_id), None)
        word_range = (passage.word_start, passage.word_end) if passage.word_start and passage.word_end else None
        verified = insert(canonical, passage.surah, (passage.ayah_start, passage.ayah_end), language=language,
                          word_range=word_range,
                          translations=translations, audio=audio_record,
                          reciter=(body.get("audio") or {}).get("reciter"), translation_manifest=TRANSLATIONS)
        for field in ("translation", "translation_source", "audio"):
            expected = verified.evidence.quran.model_dump(mode="json")[field]
            if body.get(field) != expected:
                raise CapabilityMismatch("mushaf", f"{identifier}: {field} lacks verified matching provenance")
        if record.provider_record_id != verified.source.provider_record_id or record.parts != verified.source.parts:
            raise CapabilityMismatch("mushaf", f"{identifier}: provenance differs from verified canonical source")
