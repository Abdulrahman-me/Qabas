from __future__ import annotations

import io
import subprocess
import wave
import zipfile

import httpx
import pytest
from PIL import Image
from pydantic import SecretStr
from pypdf import PdfWriter

from app.config import Environment
from app.llm.errors import LLMNotConfigured, LLMUnavailable
from app.raqeeb import inputs
from app.sources.resilience import RetryPolicy
from tests.raqeeb.test_inputs import docx


def wav(seconds=1):
    out = io.BytesIO()
    with wave.open(out, "wb") as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(16000)
        stream.writeframes(b"\0\0" * (seconds * 16000))
    return out.getvalue()


@pytest.mark.parametrize("mime,codec,container", [("audio/wav", None, None),
    ("audio/mp4", "aac", "mp4"), ("audio/webm", "libopus", "webm"), ("audio/mpeg", "libmp3lame", "mp3")])
async def test_real_ffmpeg_accepts_all_supported_audio_formats(settings, tmp_path, mime, codec, container):
    data = wav()
    if codec:
        target = tmp_path / ("question." + container)
        subprocess.run([settings.ffmpeg_path, "-nostdin", "-hide_banner", "-loglevel", "error", "-i", "pipe:0",
            "-c:a", codec, "-f", container, str(target)], input=data, check=True, capture_output=True)
        data = target.read_bytes()
    decoded = await inputs.decode(settings, "audio", mime, data)
    assert 900 <= decoded["duration_ms"] <= 1200 and decoded["wav"]


async def test_audio_actual_duration_boundary_and_mime_mismatch(settings):
    assert (await inputs.decode(settings, "audio", "audio/wav", wav(60)))["duration_ms"] == 60000
    for data, mime in ((wav(61), "audio/wav"), (wav(), "audio/mp4"), (b"ID3corrupt", "audio/mpeg")):
        with pytest.raises(inputs.InputUnreadable):
            await inputs.decode(settings, "audio", mime, data)


async def test_decoded_image_limit_is_not_compressed_file_size(settings):
    buffer = io.BytesIO()
    Image.new("RGB", (6400, 6400), "white").save(buffer, format="PNG")
    assert len(buffer.getvalue()) < 8 * 1024**2
    with pytest.raises(inputs.InputUnreadable):
        await inputs.decode(settings, "image", "image/png", buffer.getvalue())


async def test_encrypted_pdf_and_macro_docx_are_rejected_before_models(settings):
    pdf = PdfWriter()
    pdf.add_blank_page(width=100, height=100)
    pdf.encrypt("owned synthetic password")
    buffer = io.BytesIO()
    pdf.write(buffer)
    with pytest.raises(inputs.InputUnreadable):
        await inputs.decode(settings, "document", "application/pdf", buffer.getvalue())
    buffer = io.BytesIO(docx())
    with zipfile.ZipFile(buffer, "a") as archive:
        archive.writestr("word/vbaProject.bin", b"neutral macro marker")
    with pytest.raises(inputs.InputUnreadable):
        await inputs.decode(settings, "document",
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document", buffer.getvalue())
    for marker, content_type in (("VbaPROJECT.bin", None), ("renamed.bin", "application/vnd.ms-office.vbaProject")):
        buffer = io.BytesIO()
        with zipfile.ZipFile(io.BytesIO(docx())) as original, zipfile.ZipFile(buffer, "w") as archive:
            for part in original.infolist():
                body = original.read(part.filename)
                if content_type and part.filename == "[Content_Types].xml":
                    body = body.replace(b"</Types>", f'<Override PartName="/word/{marker}" '
                        f'ContentType="{content_type}"/></Types>'.encode())
                archive.writestr(part, body)
            archive.writestr(f"word/{marker}", b"neutral macro marker")
        with pytest.raises(inputs.InputUnreadable):
            await inputs.decode(settings, "document",
                "application/vnd.openxmlformats-officedocument.wordprocessingml.document", buffer.getvalue())


async def test_docx_material_truncates_at_30000_and_native_timeout_is_unreadable(settings):
    decoded = await inputs.decode(settings, "document",
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document", docx("x" * 30001))
    assert len(decoded["text"]) == 30000 and decoded["truncated"]
    with pytest.raises(inputs.InputUnreadable):
        await inputs.decode(settings.model_copy(update={"raqeeb_input_timeout_seconds": .001}), "document",
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document", docx())


async def no_sleep(delay):
    pass


def stt(settings, statuses, *, text="Neutral transcript", environment=Environment.test):
    seen = []
    async def handler(request):
        seen.append(request)
        value = statuses.pop(0)
        if isinstance(value, Exception):
            raise value
        return httpx.Response(value, json={"text": text})
    configured = settings.model_copy(update={"app_env": environment, "stt_provider": "synthetic-" + str(id(seen)),
        "stt_api_key": SecretStr("synthetic-stt-key"), "stt_base_url": "https://speech.example.test/v1"})
    return inputs.HostedWhisper(configured, transport=httpx.MockTransport(handler),
                               retry=RetryPolicy(sleep=no_sleep)), seen


async def test_hosted_speech_retries_only_transient_and_sends_no_learner_identifiers(settings):
    provider, seen = stt(settings, [503, 429, 200])
    result = await provider.transcribe(wav(), language_hint="ar")
    assert result.text == "Neutral transcript" and len(seen) == 3
    assert seen[-1].url.path == "/v1/audio/transcriptions"
    body = seen[-1].content
    assert b"whisper-large-v3" in body and b"question.wav" in body and b"usr_" not in body and b"att_" not in body
    refused, requests = stt(settings, [403])
    with pytest.raises(LLMUnavailable):
        await refused.transcribe(wav(), language_hint="en")
    assert len(requests) == 1
    malformed, _ = stt(settings, [200], text="")
    with pytest.raises(inputs.InputUnreadable):
        await malformed.transcribe(wav(), language_hint="en")


@pytest.mark.parametrize("environment", [Environment.production, Environment.staging])
async def test_hosted_audio_never_leaves_pending_processing_gate(settings, environment):
    provider, seen = stt(settings, [200], environment=environment)
    with pytest.raises(LLMNotConfigured, match="pending"):
        await provider.transcribe(wav(), language_hint="en")
    assert not seen
