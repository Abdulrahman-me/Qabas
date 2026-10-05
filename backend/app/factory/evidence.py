"""Evidence retrieval for the factory (factory §13.1 stages 3-4; SOURCE_ADAPTERS §12).

The Evidence Retriever *proposes* requests; this module *executes* them, only through the Phase 9 source layer:
Qur'an passages come from the digest-pinned mushaf (``scripture.prepare_references``, never model text), hadith from
Dorar (text, verbatim grade, grader, book and number), explanations from HadeethEnc and the Tafsir Center, articles
from IslamHouse. Every candidate keeps its ``SourceRecord`` (request, response digest, parts), so the stage that
cites it and the publication that stores it can prove where each word came from.

Citability is decided here by code, never by a model: hadith support needs a Dorar grade category ``authentic`` or
``acceptable`` (§13.1 verify), a Dorar entry carrying an editorial gloss is not quotable (F-70), and HadeethEnc
cards explain or translate a hadith but never grade one.
"""

from __future__ import annotations

import re
from collections.abc import Callable, Sequence
from dataclasses import dataclass, replace
from pathlib import Path
from typing import Any, Protocol

from pydantic import TypeAdapter

from app.config import Settings
from app.contract import models as C
from app.sources import grades
from app.sources.errors import SourceError
from app.sources.mushaf import Mushaf, ReferenceNotFound
from app.sources.normalize import normalize_ar
from app.sources.records import Part, SourceRecord
from app.sources.scripture import TRANSLATIONS, ScriptureBindings, prepare_references
from app.sources.store import citable as store_citable
from app.sources.store import source_id

RECORD = TypeAdapter(SourceRecord)
MAX_QURAN_AYAHS = 10
MAX_TEXT_MATCHES = 3
MAX_HADITH_RESULTS = 5
EXCERPT_FOR_MODEL = 4000
QURAN_REFERENCE = re.compile(r"^\s*(\d{1,3}):(\d{1,3})(?:-(\d{1,3}))?\s*$")


class SourceTools(Protocol):
    """What the retrieve stage may call. Production: :class:`LiveSourceTools`; tests: a synthetic stand-in."""

    mushaf: Mushaf
    translation_manifest: Path               # the specialist's translation selection the bundles were verified with

    async def scripture(self, references: Sequence[str]) -> ScriptureBindings: ...
    async def hadith_search(self, text: str) -> list[SourceRecord]: ...
    async def hadeethenc(self, hadith_id: str, language: str) -> SourceRecord: ...
    async def islamhouse(self, item_id: str, language: str) -> SourceRecord: ...
    async def tafsir(self, surah: int, ayah: int, book: str) -> SourceRecord: ...
    async def quran_audio(self, surah: int, ayah: int, reciter_id: int) -> SourceRecord: ...
    async def aclose(self) -> None: ...


class LiveSourceTools:
    """The Phase 9 adapters, created on first use and closed after the stage. Each adapter enforces its own
    provider policy: unapproved providers refuse in production (O-03, ``ProviderNotConfigured``)."""

    def __init__(self, settings: Settings, mushaf: Mushaf) -> None:
        self.settings, self.mushaf = settings, mushaf
        self.translation_manifest = TRANSLATIONS
        self._adapters: dict[str, Any] = {}

    def _adapter(self, name: str) -> Any:
        if name not in self._adapters:
            if name == "dorar":
                from app.sources.providers.dorar import Dorar
                self._adapters[name] = Dorar.create(self.settings)
            elif name == "hadeethenc":
                from app.sources.providers.hadeethenc import HadeethEnc
                self._adapters[name] = HadeethEnc.create(self.settings)
            elif name == "islamhouse":
                from app.sources.providers.islamhouse import IslamHouse
                self._adapters[name] = IslamHouse.create(self.settings)
            elif name == "quran_com":
                from app.sources.providers.quran_foundation import QuranFoundation
                self._adapters[name] = QuranFoundation.create(self.settings)
            elif name == "tafsir_center":
                from app.sources.providers.tafsir_center import TafsirCenter
                self._adapters[name] = TafsirCenter(self.settings)
            else:  # pragma: no cover - programming error
                raise KeyError(name)
        return self._adapters[name]

    async def scripture(self, references: Sequence[str]) -> ScriptureBindings:
        return await prepare_references(self.mushaf, references, self.settings)

    async def hadith_search(self, text: str) -> list[SourceRecord]:
        records: list[SourceRecord] = await self._adapter("dorar").search(text)
        return records

    async def hadeethenc(self, hadith_id: str, language: str) -> SourceRecord:
        record: SourceRecord = await self._adapter("hadeethenc").get(hadith_id, language)
        return record

    async def islamhouse(self, item_id: str, language: str) -> SourceRecord:
        record: SourceRecord = await self._adapter("islamhouse").get_item(item_id, language)
        return record

    async def tafsir(self, surah: int, ayah: int, book: str) -> SourceRecord:
        record: SourceRecord = await self._adapter("tafsir_center").get(surah, ayah, book)
        return record

    async def quran_audio(self, surah: int, ayah: int, reciter_id: int) -> SourceRecord:
        """Capability data (audio URL + word timings) of the approved reciter; never cited, never the text."""
        record: SourceRecord = await self._adapter("quran_com").audio(surah, ayah, reciter_id)
        return record

    async def aclose(self) -> None:
        for adapter in self._adapters.values():
            await adapter.aclose()
        self._adapters.clear()


def live_tools(settings: Settings) -> Callable[[], SourceTools]:
    def make() -> SourceTools:
        from app.sources.mushaf import get_mushaf
        return LiveSourceTools(settings, get_mushaf(settings))
    return make


def dump_record(record: SourceRecord) -> dict[str, Any]:
    value: dict[str, Any] = RECORD.dump_python(record, mode="json")
    return value


def load_record(value: dict[str, Any]) -> SourceRecord:
    return RECORD.validate_python(value)


def public_source(record: SourceRecord) -> dict[str, Any]:
    """The contract ``Source`` fields of a record (display flags are decided per session, not here)."""
    return {"source_id": source_id(record), "kind": record.kind, "provider": record.provider,
            "title": record.title, "reference": record.reference, "excerpt": record.text, "url": record.url}


@dataclass(frozen=True)
class Failure:
    request_id: str
    claim_id: str
    tool: str
    outcome: str        # not_found | not_configured | unsupported | mismatch | invalid_request
    message: str

    def as_dict(self) -> dict[str, str]:
        return {"request_id": self.request_id, "claim_id": self.claim_id, "tool": self.tool,
                "outcome": self.outcome, "message": self.message[:500]}


def _candidate(record: SourceRecord, *, claim_id: str, request_id: str, tool: str, citable: bool,
               reason: str | None, evidence_ar: Any = None, evidence_en: Any = None, en_unavailable: str | None = None,
               extra_records: Sequence[SourceRecord] = (), grade_category: str | None = None) -> dict[str, Any]:
    if citable and not store_citable(record):
        citable, reason = False, "capability data is never cited (D-106)"
    return {
        "claim_id": claim_id, "request_id": request_id, "tool": tool, "source_id": source_id(record),
        "kind": record.kind, "provider": record.provider, "title": record.title, "reference": record.reference,
        "excerpt": record.text, "url": record.url, "citable": citable, "not_citable_reason": reason,
        "grade_category": grade_category,
        "evidence": {"ar": evidence_ar.model_dump(mode="json") if evidence_ar is not None else None,
                     "en": evidence_en.model_dump(mode="json") if evidence_en is not None else None},
        "en_unavailable": en_unavailable,
        "records": [dump_record(r) for r in (record, *extra_records)],
    }


def quran_candidates(bindings: ScriptureBindings, reference: str, *, claim_id: str, request_id: str,
                     tool: str) -> list[dict[str, Any]]:
    """One candidate per canonical passage; the Arabic text is the mushaf's, never the model's."""
    verified = bindings(reference, "ar")
    english, unavailable = None, None
    try:
        english = bindings(reference, "en").evidence
    except (SourceError, ReferenceNotFound) as exc:
        unavailable = f"{type(exc).__name__}: {exc}"
    return [_candidate(verified.source, claim_id=claim_id, request_id=request_id, tool=tool, citable=True,
                       reason=None, evidence_ar=verified.evidence, evidence_en=english, en_unavailable=unavailable,
                       extra_records=verified.records)]


def canonical_reference(mushaf: Mushaf, reference: str) -> str:
    """``"2:255"``/``"2:255-257"`` checked against the mushaf (exists, ≤ ``MAX_QURAN_AYAHS`` ayahs)."""
    match = QURAN_REFERENCE.fullmatch(reference)
    if match is None:
        raise ReferenceNotFound(f"unreadable reference {reference!r}: use surah:ayah or surah:ayah-ayah")
    surah, start = int(match[1]), int(match[2])
    end = int(match[3]) if match[3] else start
    if end - start + 1 > MAX_QURAN_AYAHS:
        raise ReferenceNotFound(f"{reference}: at most {MAX_QURAN_AYAHS} ayahs per evidence item")
    passage = mushaf.get(surah, start, end)
    return f"{passage.surah}:{passage.ayah_start}" + (
        f"-{passage.ayah_end}" if passage.ayah_end != passage.ayah_start else "")


def locate_text(mushaf: Mushaf, text: str) -> list[str]:
    """Whole-ayah references of every exact canonical occurrence of ``text`` (``mushaf.find_exact``). A quotation
    the mushaf does not contain verbatim locates nothing: a misremembered verse is never "corrected" into one."""
    found = []
    for match in mushaf.find_exact(text):
        passage = match.passage
        found.append(f"{passage.surah}:{passage.ayah_start}" + (
            f"-{passage.ayah_end}" if passage.ayah_end != passage.ayah_start else ""))
    return list(dict.fromkeys(found))[:MAX_TEXT_MATCHES]


def hadith_candidate(record: SourceRecord, *, claim_id: str, request_id: str, tool: str,
                     translations: Sequence[SourceRecord] = ()) -> dict[str, Any]:
    """A Dorar hadith: citable only with an authentic/acceptable verbatim grade and complete attribution."""
    data = record.data
    label = str(data.get("grade_label") or "")
    category = grades.classify(label) if label else "other"
    reason = None
    if not grades.citable(category):
        reason = f"Dorar grade category {category} ({label or 'no ruling'}) cannot support a claim"
    elif data.get("editorial_brackets"):
        reason = "the Dorar entry carries an editorial gloss, so its text is not a verbatim quotation (F-70)"
    elif not all(data.get(f) for f in ("grader", "book", "number_or_page", "narrator")):
        reason = "the Dorar entry lacks grader, book, number or narrator"
    citable = reason is None
    evidence_ar = evidence_en = None
    unavailable = None
    extra: list[SourceRecord] = []
    if citable:
        body = {"text_ar": record.text, "narrator": data["narrator"], "collections": [record.reference],
                "grade_label": label, "grade_category": category, "grade_source": data["grader"], "excerpt": False}
        evidence_ar = C.Evidence(evidence_id=source_id(record), kind="hadith", quran=None,
                                 hadith=C.HadithBody(translation=None, **body))
        match = [t for t in translations if t.provider == "hadeethenc" and t.data.get("language") == "en"
                 and normalize_ar(str(t.data.get("text_ar", ""))) == normalize_ar(record.text)]
        if len(match) == 1:
            # The binding is part of the hadith's provenance, exactly as a gold file records it (F-111): the
            # Dorar record names the HadeethEnc card whose identical Arabic carries the reviewed translation.
            card = match[0]
            record = replace(record, parts=(*record.parts, Part(
                "translation", "hadeethenc", card.provider_record_id, sha256=card.retrieval.response_sha256,
                checks=("identical_normalized_arabic",))))
            extra.append(card)
            evidence_en = C.Evidence(evidence_id=source_id(record), kind="hadith", quran=None,
                                     hadith=C.HadithBody(translation=match[0].text, **body))
        else:
            evidence_en = evidence_ar
            unavailable = "no HadeethEnc English card with the identical Arabic text was retrieved"
    return _candidate(record, claim_id=claim_id, request_id=request_id, tool=tool, citable=citable, reason=reason,
                      evidence_ar=evidence_ar, evidence_en=evidence_en, en_unavailable=unavailable,
                      extra_records=extra, grade_category=category)


def plain_candidate(record: SourceRecord, *, claim_id: str, request_id: str, tool: str) -> dict[str, Any]:
    """Tafsir, IslamHouse and HadeethEnc records: cited as written sources, never displayed as evidence blocks.
    A HadeethEnc card explains a hadith; only a Dorar grade lets a hadith support a claim."""
    if record.provider == "hadeethenc":
        return _candidate(record, claim_id=claim_id, request_id=request_id, tool=tool, citable=False,
                          reason="HadeethEnc explains and translates; hadith support needs a Dorar grade (§13.1)")
    return _candidate(record, claim_id=claim_id, request_id=request_id, tool=tool, citable=True, reason=None)


def for_model(candidate: dict[str, Any]) -> dict[str, Any]:
    """What a model sees of a candidate (its text is untrusted data; ids are the only handle it gets)."""
    return {"candidate_id": candidate["candidate_id"], "kind": candidate["kind"], "provider": candidate["provider"],
            "title": candidate["title"], "reference": candidate["reference"],
            "text": candidate["excerpt"][:EXCERPT_FOR_MODEL], "grade_category": candidate["grade_category"],
            "citable": candidate["citable"], "not_citable_reason": candidate["not_citable_reason"]}
