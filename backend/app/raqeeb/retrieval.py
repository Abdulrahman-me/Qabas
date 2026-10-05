"""Class strategies execute Phase 9 tools. Models cannot authenticate texts or select arbitrary tools."""

from __future__ import annotations

import asyncio
import re
from dataclasses import dataclass, field
from typing import Any, Protocol

from app.factory.evidence import hadith_candidate, public_source
from app.raqeeb import schemas as S
from app.raqeeb.policy import span
from app.sources import grades
from app.sources.errors import OperationUnsupported, ProviderResponseInvalid, RecordNotFound, SourceError
from app.sources.mushaf import Mushaf, ReferenceNotFound
from app.sources.normalize import normalize_ar
from app.sources.records import SourceRecord
from app.sources.scripture import VerifiedScripture
from app.sources.store import citable, source_id


class Tools(Protocol):
    @property
    def mushaf(self) -> Mushaf: ...
    async def quran(self, reference: str, language: str) -> VerifiedScripture: ...
    async def search(self, provider: str, query: str, language: str) -> list[SourceRecord]: ...
    async def hadith(self, record_id: str) -> SourceRecord: ...
    async def alternate(self, record_id: str) -> SourceRecord: ...
    async def explanation(self, record: SourceRecord, language: str) -> list[SourceRecord]: ...
    async def tafsir(self, surah: int, ayah: int, book: str) -> SourceRecord: ...
    async def aclose(self) -> None: ...


@dataclass
class Pool:
    records: dict[str, SourceRecord] = field(default_factory=dict)
    evidence: dict[str, dict[str, Any]] = field(default_factory=dict)
    items: list[dict[str, Any]] = field(default_factory=list)
    issues: list[dict[str, str]] = field(default_factory=list)
    identified: bool = False

    def add(self, record: SourceRecord) -> str:
        if not citable(record) or not record.text.strip():
            raise ValueError("a capability or empty record is not evidence")
        key = source_id(record)
        if len(record.text) > 30_000 or sum(len(r.text) for k, r in self.records.items() if k != key) + \
                len(record.text) > 60_000:
            raise ProviderResponseInvalid(record.provider, "retrieved evidence exceeds the bounded text context")
        self.records[key] = record
        return key

    def sources(self) -> list[dict[str, Any]]:
        return [public_source(record) | {"displayed": False, "display_role": None}
                for record in self.records.values()]

    def model_data(self) -> dict[str, Any]:
        return {"sources": self.sources(), "evidence": list(self.evidence.values()), "verification": self.items}


def hadith_evidence(record: SourceRecord) -> dict[str, Any] | None:
    candidate = hadith_candidate(record, claim_id="raqeeb", request_id="identified", tool="dorar.get")
    return candidate["evidence"]["ar"] if candidate["citable"] else None


def same_quote(quote: str, record: SourceRecord) -> bool:
    """A discovery result grades only the same quotation, never an unrelated search hit or editorial gloss."""
    a, b = normalize_ar(quote), normalize_ar(record.text)
    return bool(a and b and not record.data.get("editorial_brackets") and
                (a == b or f" {a} " in f" {b} "))


async def quran_quote(pool: Pool, tools: Tools, quote: S.Quote, language: str) -> dict[str, Any]:
    exact = await asyncio.to_thread(tools.mushaf.find_exact, quote.text)
    fuzzy = None if exact else await asyncio.to_thread(tools.mushaf.find_fuzzy, quote.text)
    item: dict[str, Any] = {"item_id": f"vi_{len(pool.items) + 1}", "quote_text": quote.text,
                           "detected_kind": "quran", "status": "not_found", "hadith_grade": None,
                           "correct_text": None, "alternative": None, "note": [], "source_ids": []}
    passage = exact[0].passage if exact else fuzzy.passage if fuzzy else None
    if passage is not None:
        # Discovery does not insert its text: quran() re-reads the exact canonical reference via Mushaf.get.
        reference = f"{passage.surah}:{passage.ayah_start}-{passage.ayah_end}"
        verified = await tools.quran(reference, language)
        key = pool.add(verified.source)
        pool.evidence[key] = verified.evidence.model_dump(mode="json")
        for record in verified.records:
            if citable(record):
                pool.add(record)
        item.update(status="quran_exact" if exact else "quran_inexact", correct_text=pool.evidence[key],
                    source_ids=[key])
        pool.identified = True
    return item


async def hadith_quote(pool: Pool, tools: Tools, quote: S.Quote, language: str) -> dict[str, Any]:
    found = await tools.search("dorar", quote.text, "ar")
    item: dict[str, Any] = {"item_id": f"vi_{len(pool.items) + 1}", "quote_text": quote.text,
                           "detected_kind": "hadith", "status": "not_found", "hadith_grade": None,
                           "correct_text": None, "alternative": None, "note": [], "source_ids": []}
    for hit in found[:5]:
        try:
            record = await tools.hadith(hit.provider_record_id)
        except RecordNotFound:
            continue
        if not same_quote(quote.text, record) or record.provider != "dorar":
            continue
        data = record.data
        if not all(data.get(k) for k in ("grade_label", "grader", "book")):
            item["status"] = "needs_specialist"
            continue
        key = pool.add(record)
        category = grades.classify(str(data["grade_label"]))
        item.update(status="hadith_graded", source_ids=[key], hadith_grade={
            "grade_label": data["grade_label"], "grade_category": category,
            "grader": data["grader"], "source_book": data["book"], "reference": data.get("number_or_page")})
        evidence = hadith_evidence(record)
        if evidence is not None:
            pool.evidence[key] = evidence
            pool.identified = True
        if category in ("weak", "fabricated"):
            try:
                alternate = await tools.alternate(record.provider_record_id)
                evidence = hadith_evidence(alternate)
                if evidence is not None:
                    alternate_id = pool.add(alternate)
                    pool.evidence[alternate_id] = evidence
                    item["alternative"] = evidence
                    item["source_ids"].append(alternate_id)
            except RecordNotFound:
                pass
            except SourceError as exc:
                pool.issues.append({"category": "alternative_unavailable", "provider": exc.provider})
                item["note"] = span("The authentic-alternative lookup is unavailable." if language == "en"
                                    else "البحث عن بديل صحيح غير متاح.")
        return item
    return item


async def retrieve(classified: S.Classified, tools: Tools, language: str) -> Pool:
    pool = Pool()
    category = classified.question_class
    if category in ("personal_fatwa", "sensitive_human", "out_of_scope"):
        return pool
    for quote in classified.quotes[:10]:
        try:
            if quote.kind_guess == "quran":
                item = await quran_quote(pool, tools, quote, language)
            elif quote.kind_guess == "hadith":
                item = await hadith_quote(pool, tools, quote, language)
            else:
                records = await tools.search("islamhouse", quote.text, language)
                keys = [pool.add(r) for r in records[:5] if r.kind in ("article", "fatwa")]
                # Retrieval only nominates a claim source; the strong verifier must decide direct support.
                item = {"item_id": f"vi_{len(pool.items) + 1}", "quote_text": quote.text,
                        "detected_kind": "claim", "status": "needs_specialist", "hadith_grade": None,
                        "correct_text": None, "alternative": None, "note": [], "source_ids": keys}
            pool.items.append(item)
        except SourceError as exc:
            pool.issues.append({"category": "source_unavailable", "provider": exc.provider})
            pool.items.append({"item_id": f"vi_{len(pool.items) + 1}", "quote_text": quote.text,
                               "detected_kind": quote.kind_guess, "status": "needs_specialist",
                               "hadith_grade": None, "correct_text": None, "alternative": None,
                               "source_ids": [], "note": span("Source verification is unavailable." if language == "en"
                                                              else "التحقق من المصدر غير متاح.")})
    if category == "verification":
        return pool
    if category == "text_explanation" and not classified.quotes:
        # Quran search is discovery only: ignore provider scripture and insert from the canonical mushaf.
        for query in classified.retrieval_queries[:3]:
            try:
                for hit in (await tools.search("quran_com", query[:500], language))[:5]:
                    reference = str(hit.data.get("verse_key", ""))
                    if not re.fullmatch(r"[0-9]{1,3}:[0-9]{1,3}", reference):
                        raise ProviderResponseInvalid("quran_com", "invalid verse discovery identity")
                    verified = await tools.quran(reference, language)
                    key = pool.add(verified.source)
                    pool.evidence[key] = verified.evidence.model_dump(mode="json")
                    pool.identified = True
            except (SourceError, ReferenceNotFound) as exc:
                pool.issues.append({"category": "source_unavailable", "provider":
                                    exc.provider if isinstance(exc, SourceError) else "quran_com"})
    if category in ("text_explanation", "doubt_or_deep_creed"):
        for evidence in list(pool.evidence.values())[:3]:
            try:
                if evidence["kind"] == "quran":
                    q = evidence["quran"]
                    for ayah in range(q["ayah_start"], q["ayah_end"] + 1):
                        try:
                            record = await tools.tafsir(q["surah"], ayah, "mukhtasar")
                        except RecordNotFound:
                            record = await tools.tafsir(q["surah"], ayah, "saadi")
                        pool.add(record)
                elif category == "text_explanation":
                    record = pool.records[evidence["evidence_id"]]
                    for explanation in await tools.explanation(record, language):
                        pool.add(explanation)
            except SourceError as exc:
                pool.issues.append({"category": "source_unavailable", "provider": exc.provider})
        if category == "text_explanation":
            return pool
    providers = ("islamhouse",) if category in ("differing_opinions", "doubt_or_deep_creed") else (
        "islamhouse", "hadeethenc", "quran_com")
    for query in classified.retrieval_queries[:3]:
        for provider in providers:
            try:
                records = await tools.search(provider, query[:500], language)
                for record in records[:5]:
                    if provider == "quran_com":
                        reference = str(record.data.get("verse_key", ""))
                        if reference:
                            verified = await tools.quran(reference, language)
                            key = pool.add(verified.source)
                            pool.evidence[key] = verified.evidence.model_dump(mode="json")
                            surah, ayah = map(int, reference.split(":"))
                            pool.add(await tools.tafsir(surah, ayah, "mukhtasar"))
                    else:
                        pool.add(record)
            except (SourceError, OperationUnsupported) as exc:
                pool.issues.append({"category": "source_unavailable", "provider": exc.provider})
    return pool
