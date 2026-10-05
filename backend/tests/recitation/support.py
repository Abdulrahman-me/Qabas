"""Recitation test support: a canonical stand-in mushaf, generated audio and an in-process transcriber.

No scripture is typed here. Surah 112 ayah 1 takes its text programmatically from the vendored contract fixture
(the ``recite_verse`` exercise the test curriculum serves); every other ayah is neutral generated Arabic. The real
canonical dataset is exercised only where it is installed (tests/recitation/test_clip_set.py, test_mushaf_canonical).
"""

from __future__ import annotations

import asyncio
import hashlib
import io
import json
import math
import struct
import wave
from collections.abc import Callable
from typing import Any

from app.contract import FIXTURES_DIR
from app.services.recitation.audio import Container
from app.services.recitation.engine import Transcription
from app.services.recitation.service import AsrUnavailable
from app.sources.mushaf import DatasetSpec, Mushaf

NEUTRAL = ["ذهب", "الطالب", "الى", "المدرسة", "صباحا", "وقرا", "الكتاب", "مع", "اصدقائه", "ثم", "رجع", "الى",
           "البيت", "وكتب", "الدرس", "في", "دفتره", "الجديد", "وجلس", "تحت", "الشجرة", "الكبيرة", "حتى", "المساء",
           "مسرورا"]
LONG_SURAH, LONG_AYAH = 2, 1            # 25 neutral words: the 1-7 / 14-20 range test


def fixture_payload() -> dict[str, Any]:
    exercise = json.loads((FIXTURES_DIR / "exercises/recite_verse/exercise.json").read_text(encoding="utf-8"))
    return dict(exercise["payload"])


def records() -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    for surah in range(1, 113):
        ayahs = [" ".join(NEUTRAL[(surah + i) % len(NEUTRAL)] for i in range(4)) for _ in range(2)]
        if surah == LONG_SURAH:
            ayahs[0] = " ".join(NEUTRAL)
        if surah == 112:
            ayahs[0] = fixture_payload()["text_uthmani"]
        for ayah, text in enumerate(ayahs, start=1):
            out.append({"sura_no": surah, "aya_no": ayah, "sura_name_ar": f"اختبار {surah}",
                        "sura_name_en": f"Test {surah}", "aya_text_unicode": text, "aya_text_emlaey": text})
    return out


def mushaf() -> Mushaf:
    data = json.dumps(records(), ensure_ascii=False).encode("utf-8")
    spec = DatasetSpec(id="recitation_test", title="Recitation test stand-in (not scripture)", publisher="tests",
                       riwaya="none", version="0", member="recitation_test.json",
                       member_sha256=hashlib.sha256(data).hexdigest(), ayah_count=len(records()),
                       authority="tests only", citation="نص تجريبي", redistribution="permitted", synthetic=True)
    return Mushaf.from_records(records(), spec)


def wav(seconds: float = 1.0, frequency: float = 440.0, rate: int = 16_000) -> bytes:
    """A generated tone (not speech); the in-process transcriber decides what was "heard"."""
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(rate)
        frames = b"".join(struct.pack("<h", int(8000 * math.sin(2 * math.pi * frequency * n / rate)))
                          for n in range(int(seconds * rate)))
        out.writeframes(frames)
    return buffer.getvalue()


class FakeTranscriber:
    """Returns scripted transcriptions (or raises) and counts calls; ``delay`` simulates a busy worker."""

    def __init__(self, answer: Transcription | Exception | Callable[[], Transcription] | None = None, *,
                 delay: float = 0.0) -> None:
        self.answer = answer if answer is not None else Transcription("", 0, None)
        self.delay = delay
        self.calls: list[tuple[int, str]] = []

    async def transcribe(self, data: bytes, container: Container, *, timeout: float) -> Transcription:
        self.calls.append((len(data), container.mime))
        if self.delay:
            if self.delay >= timeout:
                await asyncio.sleep(timeout)
                raise AsrUnavailable("timed out")
            await asyncio.sleep(self.delay)
        if isinstance(self.answer, Exception):
            raise self.answer
        if callable(self.answer):
            return self.answer()
        return self.answer


def heard(text: str, logprob: float = -0.1) -> Transcription:
    return Transcription(text, 1, logprob)
