"""HadeethEnc: reviewed hadith cards with translations and explanations (authority for hadith translation).

The Arabic record carries the provenance fields (``reference``, ``attribution``, ``grade``) that translated records
lack, so ``get`` always fetches the Arabic record and joins the requested language to it by id (reply7 review).
HadeethEnc's grade is HadeethEnc's own statement and stays attributed to it; it is never merged with Dorar's.
Display verbatim and credit the source. The API has no text search (D-96): ``search`` is unsupported.
"""

from __future__ import annotations

from typing import Any, ClassVar

from app.config import Settings
from app.sources.errors import OperationUnsupported, RecordNotFound
from app.sources.providers.base import Fetched, HttpAdapter, combine, require
from app.sources.records import Part, SourceRecord
from app.sources.resilience import ProviderHttp

BASE_URL = "https://hadeethenc.com/api/v1"


class HadeethEnc(HttpAdapter):
    provider: ClassVar[str] = "hadeethenc"
    version: ClassVar[str] = "hadeethenc/1"
    tools: ClassVar[frozenset[str]] = frozenset({"get", "search"})

    @classmethod
    def create(cls, settings: Settings, **kwargs: Any) -> HadeethEnc:
        http = ProviderHttp(cls.provider, settings.hadeethenc_base_url or BASE_URL,
                            transport=kwargs.pop("transport", None))
        return cls(settings, http, **kwargs)

    async def _one(self, hadith_id: str, language: str) -> Fetched:
        fetched = await self.fetch("one", {"id": hadith_id, "language": language}, "/hadeeths/one/",
                                   {"language": language, "id": hadith_id})
        if str(require(self.provider, fetched.data, "id")) != str(hadith_id):
            raise RecordNotFound(self.provider, f"hadith {hadith_id} ({language}) answered with another id")
        return fetched

    async def get(self, hadith_id: str, language: str) -> SourceRecord:
        arguments = {"id": str(hadith_id), "language": language}
        ar = await self._one(str(hadith_id), "ar")
        arabic = ar.data
        if language != "ar" and language not in (arabic.get("translations") or []):
            raise RecordNotFound(self.provider, f"hadith {hadith_id} has no {language} translation")
        local = ar if language == "ar" else await self._one(str(hadith_id), language)
        card = local.data
        text_ar = require(self.provider, arabic, "hadeeth")
        text = require(self.provider, card, "hadeeth")
        parts = [Part("text_authority", self.provider, f"{hadith_id}:ar", sha256=ar.sha256,
                      meta={"reference": arabic.get("reference"), "attribution": arabic.get("attribution"),
                            "grade": arabic.get("grade")})]
        if language != "ar":
            parts.append(Part("translation", self.provider, f"{hadith_id}:{language}", sha256=local.sha256))
        fetched = combine({"ar": ar} if language == "ar" else {"ar": ar, language: local})
        return SourceRecord(
            provider=self.provider, provider_record_id=f"{hadith_id}:{language}", kind="hadith",
            title=require(self.provider, card, "title"),
            reference=" — ".join(x for x in (arabic.get("attribution"), arabic.get("grade")) if x),
            text=text, url=f"https://hadeethenc.com/{language}/browse/hadith/{hadith_id}",
            adapter_version=self.version, retrieval=self.retrieval("get", arguments, fetched), parts=tuple(parts),
            data={"language": language, "text_ar": text_ar, "reference_ar": arabic.get("reference") or "",
                  "attribution_ar": arabic.get("attribution") or "", "grade_ar": arabic.get("grade") or "",
                  "attribution": card.get("attribution") or "", "grade": card.get("grade") or "",
                  "explanation": card.get("explanation") or "", "hints": list(card.get("hints") or []),
                  "grade_source": "HadeethEnc"})

    async def search(self, query: str, language: str) -> list[SourceRecord]:
        raise OperationUnsupported(self.provider, "the HadeethEnc API has no text search (D-96)")
