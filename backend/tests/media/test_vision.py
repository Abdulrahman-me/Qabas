from __future__ import annotations

from app.config import Settings
from app.llm.client import AnthropicClient
from app.llm.fake import FakeAnthropicSDK, message
from app.llm.vision import VisionImage
from tests.media.test_core import picture


async def test_real_adapter_sends_actual_pixels_alongside_framed_data(settings: Settings) -> None:
    sdk = FakeAnthropicSDK([message('{"passed":true,"issues":[]}', model=settings.llm_model_strong)])
    client = AnthropicClient(settings, sdk=sdk)
    image = VisionImage(picture(), "image/webp")
    result = await client.structured("factory_visual_audit", {"brief": "Synthetic geometry"}, images=(image,))
    assert result.data["passed"]
    content = sdk.calls[0]["messages"][0]["content"]
    assert content[0] == image.block()
    assert content[1]["type"] == "text" and "Synthetic geometry" in content[1]["text"]
