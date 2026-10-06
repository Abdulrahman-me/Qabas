"""The selected text/speech path must not imply raster, TTS or Anthropic credentials."""
from pathlib import Path

from dotenv import dotenv_values


def test_example_selects_openai_text_speech_without_optional_media_secrets():
    values = dotenv_values(Path(__file__).resolve().parents[2] / ".env.example")
    assert values["OPENAI_API_KEY"] == values["STT_API_KEY"] == ""
    assert values["FACTORY_LLM_MODEL"] == values["RAQEEB_LLM_MODEL"] == "gpt-6.1-sol"
    assert values["STT_PROVIDER"] == "openai"
    assert values["STT_MODEL"] == "whisper-1"
    assert values["STT_BASE_URL"] == "https://api.openai.com/v1/"
    for key in ("ANTHROPIC_API_KEY", "TTS_PROVIDER", "TTS_API_KEY", "IMAGE_PROVIDER", "IMAGE_API_KEY"):
        assert values[key] == ""
    assert values["MEDIA_NARRATION_ENABLED"] == values["MEDIA_PRONUNCIATION_ENABLED"] == "false"
