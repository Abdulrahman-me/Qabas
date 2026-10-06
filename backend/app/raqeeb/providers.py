"""Production composition: Phase 11 model client, Phase 9 authority/capability adapters and O-09 gate."""

from __future__ import annotations

from collections.abc import Mapping
from dataclasses import replace
from typing import Any

import yaml

from app.config import Environment, Settings
from app.factory.evidence import LiveSourceTools
from app.llm.budget import Ledger
from app.llm.client import AnthropicClient, LLMResult
from app.llm.errors import LLMNotConfigured
from app.llm.models import model_policy
from app.llm.openai_client import OpenAIClient
from app.llm.prompts import Effort
from app.llm.vision import VisionImage
from app.sources.discovery import AssociationDiscovery
from app.sources.errors import RecordNotFound
from app.sources.mushaf import Mushaf, get_mushaf
from app.sources.records import Part, SourceRecord
from app.sources.scripture import VerifiedScripture


class HostedClient:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings
        self.client: AnthropicClient | OpenAIClient | None = None

    async def aclose(self) -> None:
        if self.client is not None:
            await self.client.aclose()

    async def structured(self, prompt_id: str, data: Mapping[str, Any], *, ledger: Ledger | None = None,
                         call_key: str | None = None, effort: Effort | None = None,
                         images: tuple[VisionImage, ...] = ()) -> LLMResult:
        if self.client is None:
            selected = self.settings.raqeeb_llm_model
            provider = model_policy(selected, self.settings).provider if selected else "anthropic"
            if self.settings.app_env in (Environment.production, Environment.staging):
                try:
                    policy = yaml.safe_load(self.settings.raqeeb_data_policy_path.read_text(encoding="utf-8"))
                except (OSError, UnicodeError, yaml.YAMLError):
                    raise LLMNotConfigured("Raqeeb data-processing approval is unavailable (O-09)") from None
                if not isinstance(policy, dict) or policy.get("schema") != "qabas.raqeeb_data_policy/1" or \
                        policy.get("status") != "approved" or \
                        not all(policy.get(k) for k in ("approved_by", "approved_on", "report")) or \
                        policy.get("provider") != provider or not all(policy.get(k) for k in (
                            "provider_retention", "deletion_responsibilities", "learner_disclosure")):
                    raise LLMNotConfigured("Raqeeb hosted question processing is pending O-09")
            self.client = (OpenAIClient(self.settings, model=selected) if provider == "openai" and selected
                           else AnthropicClient(self.settings))
        return await self.client.structured(prompt_id, data, ledger=ledger, call_key=call_key, effort=effort,
                                            images=images)


class LiveTools:
    """Lazy: safety/referral-only paths neither load a mushaf nor initialize a religious provider."""
    def __init__(self, settings: Settings) -> None:
        self.settings = settings
        self._tools: LiveSourceTools | None = None
        self.discovery: dict[str, AssociationDiscovery] = {}

    @property
    def tools(self) -> LiveSourceTools:
        if self._tools is None:
            self._tools = LiveSourceTools(self.settings, get_mushaf(self.settings))
        return self._tools

    @property
    def mushaf(self) -> Mushaf:
        return self.tools.mushaf

    async def quran(self, reference: str, language: str) -> VerifiedScripture:
        # English still requires the approved D-93 translation; never translate scripture with a model.
        return (await self.tools.scripture([reference]))(reference, language)

    async def search(self, provider: str, query: str, language: str) -> list[SourceRecord]:
        if provider in ("islamhouse", "hadeethenc"):
            if provider not in self.discovery:
                self.discovery[provider] = AssociationDiscovery(provider, self.settings)
            ids = await self.discovery[provider].search(query, language)
            records = []
            for record_id in ids:
                try:
                    record = await (self.tools.islamhouse(record_id, language) if provider == "islamhouse"
                                    else self.tools.hadeethenc(record_id, language))
                    records.append(replace(record, parts=(*record.parts, Part("search", "islamiccontent_mcp", record_id,
                        version="association_mcp/1", sha256=self.discovery[provider].last_sha256,
                        checks=("discovery_only", "authority_get_identity")))))
                except RecordNotFound:
                    continue
            return records
        if provider == "dorar":
            return await self.tools.hadith_search(query)
        if provider == "quran_com":
            hits: list[SourceRecord] = await self.tools._adapter("quran_com").search(query)
            hits = [replace(r, data=r.data | {"verse_key": r.data.get("key")}) for r in hits]
            return hits
        raise ValueError("provider is outside the Raqeeb allow-list")

    async def hadith(self, record_id: str) -> SourceRecord:
        record: SourceRecord = await self.tools._adapter("dorar").get(record_id)
        return record

    async def alternate(self, record_id: str) -> SourceRecord:
        record: SourceRecord = await self.tools._adapter("dorar").alternate(record_id)
        return record

    async def explanation(self, record: SourceRecord, language: str) -> list[SourceRecord]:
        found: list[SourceRecord] = []
        if record.data.get("sharh_id"):
            found.append(await self.tools._adapter("dorar").sharh(record.data["sharh_id"]))
        # HadeethEnc discovery is only a locator. A result must bind to the identical Arabic quotation.
        try:
            from app.sources.normalize import normalize_ar
            found += [replace(r, provider_record_id=f"{r.provider_record_id}:explanation",
                              text=str(r.data["explanation"]))
                      for r in await self.search("hadeethenc", record.text, language)
                      if r.data.get("explanation") and
                      normalize_ar(str(r.data.get("text_ar", r.text))) == normalize_ar(record.text)]
        except RecordNotFound:
            pass
        return found

    async def tafsir(self, surah: int, ayah: int, book: str) -> SourceRecord:
        return await self.tools.tafsir(surah, ayah, book)

    async def resolve(self, record: SourceRecord, language: str) -> SourceRecord:
        """Refresh a known identity, not a search query or a model's proposed citation."""
        from app.sources.errors import OperationUnsupported
        args = record.retrieval.arguments
        if record.provider == "dorar":
            if record.retrieval.operation == "sharh":
                result: SourceRecord = await self.tools._adapter("dorar").sharh(args["sharh_id"])
                return result
            return await self.hadith(record.provider_record_id)
        if record.provider == "hadeethenc":
            identifier = str(args["id"])
            result = await self.tools.hadeethenc(identifier, language)
            if record.provider_record_id.endswith(":explanation"):
                result = replace(result, provider_record_id=record.provider_record_id,
                                 text=str(result.data["explanation"]))
            return result
        if record.provider == "islamhouse":
            return await self.tools.islamhouse(str(args["item_id"]), language)
        if record.provider == "quranenc":
            verified = await self.quran(f"{args['surah']}:{args['ayah']}", language)
            for translation in verified.records:
                if translation.provider == "quranenc" and translation.provider_record_id == record.provider_record_id:
                    return translation
            raise RecordNotFound("quranenc", "approved canonical binding no longer includes this translation")
        if record.provider == "tafsir_center":
            return await self.tafsir(args["surah"], args["ayah"], args["book"])
        raise OperationUnsupported(record.provider, "record has no approved identity resolver")

    async def aclose(self) -> None:
        for discovery in self.discovery.values():
            await discovery.aclose()
        if self._tools is not None:
            await self._tools.aclose()
