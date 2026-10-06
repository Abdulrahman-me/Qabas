"""Known provider identities must refresh without treating language suffixes as upstream IDs."""
from dataclasses import replace
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest

from app.raqeeb.providers import LiveTools
from app.raqeeb.retrieval import Pool
from app.raqeeb.source_checks import fresh
from app.sources.errors import RecordNotFound
from tests.raqeeb.support import record


@pytest.mark.parametrize("provider,identifier,args,method", [
    ("hadeethenc", "123:en:explanation", {"id": "123", "language": "en"}, "hadeethenc"),
    ("islamhouse", "123:en", {"item_id": "123", "language": "en"}, "islamhouse")])
async def test_multilingual_source_refresh_uses_original_upstream_identity(
        settings, provider, identifier, args, method):
    original = record(provider, identifier, explanation="Neutral explanation")
    original = replace(original, retrieval=replace(original.retrieval, arguments=args))
    resolved = replace(original, provider_record_id="123:en", text="Neutral provider text")
    upstream = AsyncMock(return_value=resolved)
    tools = LiveTools(settings)
    tools._tools = SimpleNamespace(**{method: upstream})
    result = await tools.resolve(original, "en")
    upstream.assert_awaited_once_with("123", "en")
    assert result.provider_record_id == identifier
    if provider == "hadeethenc":
        assert result.text == "Neutral explanation"


async def test_quran_translation_refresh_rechecks_approved_canonical_binding(settings):
    original = replace(record("quranenc", "neutral:1:1"), kind="quran")
    original = replace(original, retrieval=replace(original.retrieval, arguments={"surah": 1, "ayah": 1}))
    tools = LiveTools(settings)
    tools.quran = AsyncMock(return_value=SimpleNamespace(records=(original,)))
    pool = Pool()
    assert await fresh(original, tools, "en", pool) == original
    tools.quran.assert_awaited_once_with("1:1", "en")
    tools.quran.return_value = SimpleNamespace(records=())
    with pytest.raises(RecordNotFound):
        await fresh(original, tools, "en", Pool())
