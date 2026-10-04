"""IslamHouse item metadata; attachments are links, not automatically trusted book contents."""

from __future__ import annotations

import ast
from typing import Any, ClassVar
from urllib.parse import quote

from app.config import Settings
from app.sources.errors import OperationUnsupported, ProviderNotConfigured, ProviderResponseInvalid, RecordNotFound
from app.sources.providers.base import HttpAdapter, require
from app.sources.records import Part, SourceRecord
from app.sources.redaction import install_url_filter, redact_response
from app.sources.resilience import ProviderHttp


def list_field(value: Any, field: str) -> list[dict[str, Any]]:
    if isinstance(value, str):
        try:
            value = ast.literal_eval(value)
        except (ValueError, SyntaxError, RecursionError) as exc:
            raise ProviderResponseInvalid("islamhouse", f"malformed {field}") from exc
    if not isinstance(value, list) or not all(isinstance(item, dict) for item in value):
        raise ProviderResponseInvalid("islamhouse", f"malformed {field}")
    return value


class IslamHouse(HttpAdapter):
    provider: ClassVar[str] = "islamhouse"
    version: ClassVar[str] = "islamhouse/1"
    tools: ClassVar[frozenset[str]] = frozenset({"get_item", "search"})

    @classmethod
    def create(cls, settings: Settings, **kwargs: Any) -> IslamHouse:
        install_url_filter()
        http = ProviderHttp(cls.provider, settings.islamhouse_base_url or "https://api3.islamhouse.com/v3",
                            transport=kwargs.pop("transport", None))
        return cls(settings, http, **kwargs)

    def safe_response(self, data: Any) -> Any:
        assert self.settings.islamhouse_api_key is not None
        return redact_response(data, self.settings.islamhouse_api_key.get_secret_value())

    def validate_response(self, operation: str, arguments: dict[str, Any], data: Any) -> None:
        if isinstance(data, dict) and "error" in data:
            if data["error"] == "Error: There is no Data":
                raise RecordNotFound(self.provider, "item not found")
            raise ProviderResponseInvalid(self.provider, "provider returned an undocumented error")
        if str(require(self.provider, data, "id", (str, int))) != arguments["item_id"]:
            raise ProviderResponseInvalid(self.provider, "item identity differs from request")
        require(self.provider, data, "title")
        require(self.provider, data, "description")
        if data.get("type") not in {"books", "articles", "fatwa", "fatwas"}:
            raise ProviderResponseInvalid(self.provider, "item type is not supported for citation")
        if data.get("translation_language") != arguments["language"]:
            raise ProviderResponseInvalid(self.provider, "item language differs from request")
        for field in ("prepared_by", "attachments"):
            list_field(data.get(field, []), field)

    async def get_item(self, item_id: str, language: str) -> SourceRecord:
        self.policy.require_live(self.settings)
        key = self.settings.islamhouse_api_key
        if key is None or not key.get_secret_value():
            raise ProviderNotConfigured(self.provider, "API key is missing (O-03)")
        if not str(item_id).isdigit() or not language.isalpha():
            raise ValueError("item ID must be numeric and language must be an ISO language code")
        arguments = {"item_id": str(item_id), "language": language}
        fetched = await self.fetch("get_item", arguments,
                                   f"/{quote(key.get_secret_value(), safe='')}/main/get-item/{item_id}/{language}/json")
        data = fetched.data
        kind = {"books": "book", "articles": "article", "fatwa": "fatwa", "fatwas": "fatwa"}[data["type"]]
        record_id = f"{item_id}:{language}"
        return SourceRecord(self.provider, record_id, kind, data["title"], f"IslamHouse {item_id}",
                            data["description"], f"https://islamhouse.com/{language}/{data['type']}/{item_id}/",
                            self.version, self.retrieval("get_item", arguments, fetched),
                            (Part("metadata", self.provider, record_id, sha256=fetched.sha256,
                                  meta={"quoted_field": "description", "response_credentials_redacted": True}),),
                            {"language": language, "description": data["description"],
                             "full_description": data.get("full_description"),
                             "authors": list_field(data.get("prepared_by", []), "prepared_by"),
                             "attachments": list_field(data.get("attachments", []), "attachments")})

    async def search(self, query: str, language: str) -> list[SourceRecord]:
        raise OperationUnsupported(self.provider, "the IslamHouse REST API has no text search (D-96)")
