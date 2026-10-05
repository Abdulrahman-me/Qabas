"""Upload signatures, restricted decoding and the worker's in-memory task body (API §3.7, backend §8 step 1).

Test audio is a generated tone (never recitation), encoded here with FFmpeg's libraries in every accepted
container - including a standard M4A whose ``moov`` index follows the audio, as phone recorders write it.
"""

from __future__ import annotations

import base64
import io
import math
from collections.abc import Callable

import av
import pytest

from app.services.recitation import audio
from app.services.recitation.engine import Transcription
from app.workers import tasks_asr
from tests.recitation.support import wav

ENCODERS = {audio.WAV: ("wav", "pcm_s16le"), audio.WEBM: ("webm", "libopus"), audio.MP4: ("mp4", "aac"),
            audio.MPEG: ("mp3", "libmp3lame")}


def generate(container: audio.Container, seconds: float, *, rate: int = 48_000) -> bytes:
    fmt, codec = ENCODERS[container]
    buffer = io.BytesIO()
    with av.open(buffer, mode="w", format=fmt) as out:
        stream = out.add_stream(codec, rate=rate)
        stream.layout = "mono"
        step = 1024
        for start in range(0, int(seconds * rate), step):
            count = min(step, int(seconds * rate) - start)
            frame = av.AudioFrame(format="s16", layout="mono", samples=count)
            frame.planes[0].update(b"".join(
                int(6000 * math.sin(2 * math.pi * 440 * (start + n) / rate)).to_bytes(2, "little", signed=True)
                for n in range(count)) + b"\x00" * (frame.planes[0].buffer_size - 2 * count))
            frame.rate = rate
            frame.pts = start
            for packet in stream.encode(frame):
                out.mux(packet)
        for packet in stream.encode(None):
            out.mux(packet)
    return buffer.getvalue()


@pytest.mark.parametrize("container", list(ENCODERS), ids=lambda c: c.mime)
def test_every_accepted_container_is_sniffed_and_decoded(container: audio.Container) -> None:
    data = generate(container, 2.0)
    assert audio.sniff(data) == container
    pcm = audio.decode(data, container)
    assert abs(len(pcm) / audio.BYTES_PER_SECOND - 2.0) < 0.15        # 16 kHz mono s16le, measured duration


def test_m4a_with_the_index_after_the_audio_is_decoded_from_memory() -> None:
    data = generate(audio.MP4, 1.0)
    assert data.find(b"moov") > data.find(b"mdat") > 0                # the phone-recorder layout
    assert len(audio.decode(data, audio.MP4)) > 0


def test_signatures_not_names_or_mime_types_decide() -> None:
    assert audio.sniff(b"") is None and audio.sniff(b"%PDF-1.7 not audio") is None
    assert audio.sniff(b"RIFF\x00\x00\x00\x00AVI LIST") is None             # RIFF but not WAVE
    assert audio.sniff(wav(0.1)) == audio.WAV


def test_decoded_duration_is_enforced() -> None:
    data = generate(audio.MPEG, 31.0, rate=16_000)
    assert len(data) < audio.MAX_BYTES                                      # a small file, too long when decoded
    with pytest.raises(audio.DecodeError) as error:
        audio.decode(data, audio.MPEG)
    assert error.value.reason == "too_long"
    assert len(audio.decode(generate(audio.MPEG, 29.0, rate=16_000), audio.MPEG)) > 0


def test_restricted_decoder_refuses_other_containers_codecs_and_garbage() -> None:
    mp3 = generate(audio.MPEG, 1.0)
    broken_wav = b"RIFF\x24\x00\x00\x00WAVEfmt " + b"\x00" * 64
    cases = ((mp3, audio.WEBM), (mp3, audio.WAV), (generate(audio.WEBM, 1.0), audio.MP4), (broken_wav, audio.WAV),
             (b"\xff\xfb" * 50, audio.MPEG))
    for data, container in cases:
        with pytest.raises(audio.DecodeError) as error:
            audio.decode(data, container)
        assert error.value.reason == "undecodable"


class Engine:
    def __init__(self, answer: Transcription | Callable[[bytes], Transcription]) -> None:
        self.answer, self.seen = answer, 0

    def transcribe(self, pcm: bytes) -> Transcription:
        self.seen = len(pcm)
        return self.answer(pcm) if callable(self.answer) else self.answer


def test_worker_task_body_decodes_in_memory_and_returns_text_only() -> None:
    engine = Engine(Transcription("ذهب الطالب", 1, -0.2))
    payload = base64.b64encode(generate(audio.WEBM, 1.5)).decode()
    assert tasks_asr.run(payload, "audio/webm", engine) == {"text": "ذهب الطالب", "segments": 1, "avg_logprob": -0.2}
    assert abs(engine.seen / audio.BYTES_PER_SECOND - 1.5) < 0.15
    assert tasks_asr.run(payload, "audio/wav", engine) == {"error": "undecodable"}     # declared type disagrees
    long = base64.b64encode(generate(audio.MPEG, 31.0, rate=16_000)).decode()
    assert tasks_asr.run(long, "audio/mpeg", engine) == {"error": "too_long"}
