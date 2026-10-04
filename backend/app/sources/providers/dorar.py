"""Dorar (الدرر السنية) hadith encyclopedia through the local Node sidecar (authority for hadith text and grades).

Each record is one muhaddith's entry: the hadith text verbatim, narrator, the muhaddith, book and number, the
ruling verbatim (``grade_label``) and its category from the conservative table (D-94). Operations follow §12:
``search(text)``, ``get(hadith_id)``, ``alternate(hadith_id)`` (an authentic alternative to a weak entry) and
``sharh(sharh_id)``. The sidecar's sharh endpoint misplaces fields (its ``grade`` carries the takhrij, F-70), so
only the explanation text is taken from it. A search with no results is a definite ``[]`` ("not_found"), never
"fabricated"; a sidecar outage is ``UpstreamUnavailable``.
"""

from __future__ import annotations

from typing import Any, ClassVar

from app.config import Settings
from app.sources import grades
from app.sources.errors import ProviderResponseInvalid, RecordNotFound
from app.sources.providers.base import Fetched, HttpAdapter, require
from app.sources.records import Part, SourceRecord
from app.sources.resilience import ProviderHttp

SITE = "https://dorar.net"


class Dorar(HttpAdapter):
    provider: ClassVar[str] = "dorar"
    version: ClassVar[str] = "dorar/1"
    tools: ClassVar[frozenset[str]] = frozenset({"search", "get", "alternate", "sharh"})

    @classmethod
    def create(cls, settings: Settings, **kwargs: Any) -> Dorar:
        http = ProviderHttp(cls.provider, settings.dorar_base_url, transport=kwargs.pop("transport", None))
        return cls(settings, http, **kwargs)

    async def search(self, text: str, page: int = 1) -> list[SourceRecord]:
        arguments = {"text": text, "page": page}
        fetched = await self.fetch("search", arguments, "/v1/site/hadith/search",
                                   {"value": text, "page": page, "removehtml": "true", "specialist": "false"})
        entries = require(self.provider, fetched.data, "data", list)
        return [self._record("search", arguments, fetched, entry) for entry in entries]

    def validate_response(self, operation: str, arguments: dict[str, Any], data: Any) -> None:
        if operation == "search":
            entries = require(self.provider, data, "data", list)
        elif operation == "alternate":
            if not isinstance(data, dict) or "data" not in data:
                raise ProviderResponseInvalid(self.provider, "alternate response has no data field")
            if data["data"] is None:
                raise RecordNotFound(self.provider, "no authentic alternative recorded")
            entries = [require(self.provider, data, "data", dict)]
        elif operation == "sharh":
            item = require(self.provider, data, "data", dict)
            meta = require(self.provider, item, "sharhMetadata", dict)
            if str(meta.get("id")) != str(arguments["sharh_id"]):
                raise ProviderResponseInvalid(self.provider, "explanation identity differs from request")
            if meta.get("isContainSharh") is False:
                raise RecordNotFound(self.provider, "no explanation recorded")
            require(self.provider, meta, "sharh")
            return
        else:
            entry = require(self.provider, data, "data", dict)
            if str(entry.get("hadithId")) != str(arguments["hadith_id"]):
                raise ProviderResponseInvalid(self.provider, "hadith identity differs from request")
            entries = [entry]
        for entry in entries:
            require(self.provider, entry, "hadithId")
            require(self.provider, entry, "hadith")

    async def get(self, hadith_id: str) -> SourceRecord:
        arguments = {"hadith_id": hadith_id}
        fetched = await self.fetch("get", arguments, f"/v1/site/hadith/{hadith_id}")
        record = self._record("get", arguments, fetched, require(self.provider, fetched.data, "data", dict))
        if record.provider_record_id != hadith_id:
            raise ProviderResponseInvalid(self.provider, f"asked for {hadith_id}, got {record.provider_record_id}")
        return record

    async def alternate(self, hadith_id: str) -> SourceRecord:
        arguments = {"hadith_id": hadith_id}
        fetched = await self.fetch("alternate", arguments, f"/v1/site/hadith/alternate/{hadith_id}")
        entry = fetched.data.get("data") if isinstance(fetched.data, dict) else None
        if not entry:
            raise RecordNotFound(self.provider, f"no authentic alternative recorded for {hadith_id}")
        return self._record("alternate", arguments, fetched, require(self.provider, fetched.data, "data", dict))

    async def sharh(self, sharh_id: str) -> SourceRecord:
        arguments = {"sharh_id": sharh_id}
        fetched = await self.fetch("sharh", arguments, f"/v1/site/sharh/{sharh_id}")
        data = require(self.provider, fetched.data, "data", dict)
        meta = require(self.provider, data, "sharhMetadata", dict)
        if str(meta.get("id")) != str(sharh_id) or not meta.get("isContainSharh"):
            raise RecordNotFound(self.provider, f"sharh {sharh_id} has no explanation text")
        text = require(self.provider, meta, "sharh")
        return SourceRecord(
            provider=self.provider, provider_record_id=f"sharh:{sharh_id}", kind="book", title="الدرر السنية — شرح",
            reference=f"شرح {sharh_id}", text=text, url=f"{SITE}/hadith/sharh/{sharh_id}",
            adapter_version=self.version, retrieval=self.retrieval("sharh", arguments, fetched),
            parts=(Part("explanation", self.provider, f"sharh:{sharh_id}", sha256=fetched.sha256),),
            data={"hadith": data.get("hadith") or ""})

    def _record(self, operation: str, arguments: dict[str, Any], fetched: Fetched, entry: Any) -> SourceRecord:
        hadith_id = str(require(self.provider, entry, "hadithId"))
        text = require(self.provider, entry, "hadith").strip()
        label = str(entry.get("grade") or "").strip()
        category = grades.classify(label) if label else "other"
        book = str(entry.get("book") or "").strip()
        number = str(entry.get("numberOrPage") or "").strip()
        grader = str(entry.get("mohdith") or "").strip()
        sharh = entry.get("sharhMetadata") if isinstance(entry.get("sharhMetadata"), dict) else {}
        return SourceRecord(
            provider=self.provider, provider_record_id=hadith_id, kind="hadith", title=book or "الدرر السنية",
            reference=f"{book} ({number})" if number else book, text=text, url=f"{SITE}/h/{hadith_id}",
            adapter_version=self.version, retrieval=self.retrieval(operation, arguments, fetched),
            parts=(Part("text_authority", self.provider, hadith_id, sha256=fetched.sha256),
                   Part("grade", self.provider, hadith_id, sha256=fetched.sha256, checks=(grades.RULE,))),
            data={"narrator": str(entry.get("rawi") or "").strip("[] "), "grader": grader, "book": book,
                  "book_id": entry.get("bookId"), "number_or_page": number, "grade_label": label,
                  "grade_explanation": entry.get("explainGrade") or "", "grade_category": category,
                  "takhrij": entry.get("takhrij") or "", "has_alternate": bool(entry.get("hasAlternateHadithSahih")),
                  "sharh_id": sharh.get("id") if entry.get("hasSharhMetadata") else None,
                  # Dorar sometimes appends an editorial gloss "[يعني حديث: …]" to the entry text (F-70).
                  "editorial_brackets": "[" in text})
