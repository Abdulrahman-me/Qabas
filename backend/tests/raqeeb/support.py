"""Neutral, public synthetic fixtures; no religious assertions or live providers."""

from dataclasses import dataclass, field
from typing import Any

from app.llm.fake import FakeLLMClient
from app.sources.records import Part, Retrieval, SourceRecord, sha256_text, utcnow
from app.sources.scripture import insert
from tests.sources import synthetic


def record(provider: str = "islamhouse", identifier: str = "1", text: str = "A neutral classroom example.",
           **data: Any) -> SourceRecord:
    return SourceRecord(provider, identifier, "hadith" if provider == "dorar" else "article",
        "Synthetic source", "Synthetic reference", text, "https://example.test/source", "synthetic/1",
        Retrieval(f"{provider}.get", "get", {"id": identifier}, {"synthetic": True}, sha256_text(text), utcnow()),
        (Part("text_authority", provider, identifier),), data)


@dataclass
class Tools:
    mushaf: Any = field(default_factory=synthetic.mushaf)
    calls: list[Any] = field(default_factory=list)
    articles: list[SourceRecord] = field(default_factory=lambda: [record(), record(identifier="2")])
    hadith_records: list[SourceRecord] = field(default_factory=list)
    error: Exception | None = None

    async def quran(self, reference: str, language: str) -> Any:
        self.calls.append(("quran", reference, language))
        surah, ayahs = reference.split(":")
        start, _, end = ayahs.partition("-")
        return insert(self.mushaf, int(surah), (int(start), int(end or start)))

    async def search(self, provider: str, query: str, language: str) -> list[SourceRecord]:
        self.calls.append(("search", provider, query, language))
        if self.error:
            raise self.error
        return self.hadith_records if provider == "dorar" else self.articles if provider == "islamhouse" else []

    async def hadith(self, identifier: str) -> SourceRecord:
        self.calls.append(("get", identifier))
        return next(r for r in self.hadith_records if r.provider_record_id == identifier)

    async def alternate(self, identifier: str) -> SourceRecord:
        from app.sources.errors import RecordNotFound
        raise RecordNotFound("dorar", "no alternative")

    async def explanation(self, source: SourceRecord, language: str) -> list[SourceRecord]:
        return []

    async def tafsir(self, surah: int, ayah: int, book: str) -> SourceRecord:
        self.calls.append(("tafsir", surah, ayah, book))
        from dataclasses import replace
        return replace(record("tafsir_center"), kind="tafsir")

    async def aclose(self) -> None:
        pass


def model(category: str, *, language: str = "en", quote: str | None = None,
          kind: str = "quran", confidence: float = 1) -> FakeLLMClient:
    def verify(data: dict[str, Any]) -> dict[str, Any]:
        return {"claims": [{"text": s["excerpt"], "supported": True, "source_ids": [s["source_id"]], "note": "direct"}
                           for s in data["sources"]]}

    def write(data: dict[str, Any]) -> dict[str, Any]:
        citations = [{"ref": i, "source": s} for i, s in enumerate(data["sources"], 1)]
        spans = [{"type": "text", "text": data["supported_claims"][0]["text"]}, {"type": "citation", "ref": 1}]
        if category == "differing_opinions":
            blocks = [{"type": "differing_views", "intro": [{"type": "text", "text": "Attributed examples"}],
                       "views": [{"holder": f"Author {i}", "spans": [{"type": "text", "text": s["excerpt"]},
                           {"type": "citation", "ref": i}], "source_ids": [s["source_id"]]}
                           for i, s in enumerate(data["sources"], 1)]}]
        elif category == "verification":
            blocks = [{"type": "verification", "items": data["verification"]}]
        else:
            blocks = [{"type": "paragraph", "spans": spans}]
            if category == "text_explanation":
                blocks.insert(0, {"type": "evidence", "evidence": data["evidence"][0]})
                explanation = next(c for c in citations if c["source"]["kind"] == "tafsir")
                blocks[-1]["spans"] = [{"type": "text", "text": explanation["source"]["excerpt"]},
                                       {"type": "citation", "ref": explanation["ref"]}]
        return {"blocks": blocks, "citations": citations}

    return FakeLLMClient({
        "raqeeb_classify": {"question_class": category, "confidence": confidence, "language": language,
            "quotes": [{"text": quote, "kind_guess": kind}] if quote else [], "retrieval_queries": ["example"],
            "concept_hint": None, "standalone": True, "canonical_question": "Neutral example"},
        "raqeeb_verify": verify, "raqeeb_write": write,
        "raqeeb_rewrite": lambda data: {"paragraphs": data["paragraphs"]},
        "raqeeb_rewrite_check": {"same_meaning": True, "new_claims": False},
        "raqeeb_guard": {"violations": []}, "conversation_title": {"title": "Learning example"},
    })


def snapshot(language: str = "en") -> dict[str, Any]:
    return {"profile": {"level": "basic", "language": language, "track": "explorer", "known_terms": [],
                         "active_misconceptions": []}, "history": [], "context": {}, "cards": {}}
