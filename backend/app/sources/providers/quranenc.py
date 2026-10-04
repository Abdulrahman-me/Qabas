"""QuranEnc: approved translations of the meanings of the Qur'an (authority for translations, D-93).

``translation(surah, ayah, translation_key, language)`` returns the translation record with the translation's
version from the provider's own catalogue for that language (a key missing from the catalogue is refused).
QuranEnc also returns its Arabic text; the insertion layer only compares it with the canonical mushaf (a
disagreement rejects the record) and never uses it as Qur'an text.
"""

from __future__ import annotations

from typing import Any, ClassVar

from app.config import Settings
from app.sources.errors import ProviderResponseInvalid, RecordNotFound
from app.sources.providers.base import Fetched, HttpAdapter, combine, require
from app.sources.records import Part, SourceRecord
from app.sources.resilience import ProviderHttp

BASE_URL = "https://quranenc.com/api/v1"


class QuranEnc(HttpAdapter):
    provider: ClassVar[str] = "quranenc"
    version: ClassVar[str] = "quranenc/1"
    tools: ClassVar[frozenset[str]] = frozenset({"translation"})

    @classmethod
    def create(cls, settings: Settings, **kwargs: Any) -> QuranEnc:
        http = ProviderHttp(cls.provider, settings.quranenc_base_url or BASE_URL,
                            transport=kwargs.pop("transport", None))
        return cls(settings, http, **kwargs)

    async def _catalogue(self, language: str) -> Fetched:
        return await self.fetch("catalogue", {"language": language}, f"/translations/list/{language}")

    def validate_response(self, operation: str, arguments: dict[str, Any], data: Any) -> None:
        if operation == "catalogue":
            for item in require(self.provider, data, "translations", list):
                require(self.provider, item, "key")
                require(self.provider, item, "title")
                require(self.provider, item, "version", (str, int))
        else:
            item = require(self.provider, data, "result", dict)
            if str(item.get("sura")) != str(arguments["surah"]) or str(item.get("aya")) != str(arguments["ayah"]):
                raise ProviderResponseInvalid(self.provider, "translation verse identity differs from request")
            require(self.provider, item, "translation")
            require(self.provider, item, "arabic_text")

    async def catalogue(self, language: str) -> dict[str, dict[str, Any]]:
        items = require(self.provider, (await self._catalogue(language)).data, "translations", list)
        return {i["key"]: i for i in items if isinstance(i, dict) and isinstance(i.get("key"), str)}

    async def translation(self, surah: int, ayah: int, translation_key: str, language: str) -> SourceRecord:
        arguments = {"surah": surah, "ayah": ayah, "translation_key": translation_key, "language": language}
        aya = await self.fetch("translation", arguments, f"/translation/aya/{translation_key}/{surah}/{ayah}")
        result = require(self.provider, aya.data, "result", dict)
        if str(result.get("sura")) != str(surah) or str(result.get("aya")) != str(ayah):
            raise ProviderResponseInvalid(self.provider,
                                          f"answered {result.get('sura')}:{result.get('aya')} for {surah}:{ayah}")
        text = require(self.provider, result, "translation").strip()
        catalogue = await self._catalogue(language)
        entries = {i.get("key"): i for i in require(self.provider, catalogue.data, "translations", list)
                   if isinstance(i, dict)}
        meta = entries.get(translation_key)
        if meta is None:
            raise RecordNotFound(self.provider, f"translation {translation_key!r} is not in the {language} catalogue")
        record_id = f"{translation_key}:{surah}:{ayah}"
        version = str(meta.get("version") or "")
        return SourceRecord(
            provider=self.provider, provider_record_id=record_id, kind="quran", title=str(meta.get("title") or ""),
            reference=f"{surah}:{ayah}", text=text,
            url=f"https://quranenc.com/{language}/browse/{translation_key}/{surah}#{ayah}",
            adapter_version=self.version,
            retrieval=self.retrieval("translation", arguments, combine({"aya": aya, "catalogue": catalogue})),
            parts=(Part("translation", self.provider, record_id, version=version, sha256=aya.sha256,
                        meta={"last_update": meta.get("last_update")}),),
            data={"translation_key": translation_key, "translation_version": version, "language": language,
                  "footnotes": result.get("footnotes") or "", "arabic_text": result.get("arabic_text") or ""})
