from __future__ import annotations

from dataclasses import replace
from typing import Any

import pytest

from app.media import objects
from app.media.errors import MediaInvalid
from app.media.service import MediaService
from app.media.types import GeneratedMedia
from tests.media.test_core import audio
from tests.media.test_jobs import ctx as ctx  # shared database-backed StageContext fixture


class Speech:
    calls: list[dict[str, Any]]

    def __init__(self) -> None:
        self.calls = []

    async def synthesize(self, **kwargs: Any) -> GeneratedMedia:
        self.calls.append(kwargs)
        return GeneratedMedia(audio(), "audio/mpeg", "fake", "synthetic-tts", {"language": kwargs["language"]})


async def test_narration_replays_exact_text_and_language_but_changed_text_gets_new_receipt(ctx: Any) -> None:
    context, resources = ctx
    provider = Speech()
    media = MediaService(
        resources.storage,
        narration_provider=provider,
        narration_terms={"licence": {"status": "approved", "approved_by": "synthetic", "approved_on": "2026-01-01"}},
    )
    first = await media.speech(context, name="ar/explorer/story/beat", text="Neutral teaching narration", language="ar")
    assert (
        await media.speech(context, name="ar/explorer/story/beat", text="Neutral teaching narration", language="ar")
        == first
    )
    changed = await media.speech(
        context, name="ar/explorer/story/beat", text="Revised teaching narration", language="ar"
    )
    assert len(provider.calls) == 2 and first != changed
    assert objects.MediaObject.model_validate(first["object"]).provenance["synthetic_audio"]


async def test_copied_verified_quote_never_reaches_a_tts_provider(ctx: Any) -> None:
    context, resources = ctx
    provider = Speech()
    media = MediaService(resources.storage, narration_provider=provider)
    context = replace(
        context,
        run=replace(
            context.run,
            artifacts={
                "verify_evidence": {"output": {"evidence": [{"quran": {"text_uthmani": "Neutral synthetic quote"}}]}}
            },
        ),
    )
    with pytest.raises(MediaInvalid, match="cannot be synthesized"):
        await media.speech(context, name="ar/explorer/story/beat", text="Neutral synthetic quote", language="ar")
    assert provider.calls == []
