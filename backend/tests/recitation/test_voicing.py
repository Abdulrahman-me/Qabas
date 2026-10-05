"""Speech regions are kept through sustained recitation (madd) and nothing else (D-118, F-95). Generated PCM only."""

from __future__ import annotations

import math
import random
import struct

from app.services.recitation import voicing

RATE = 16_000


def tone(seconds: float, amplitude: float, frequency: float = 220.0) -> bytes:
    return b"".join(struct.pack("<h", int(amplitude * math.sin(2 * math.pi * frequency * n / RATE)))
                    for n in range(int(seconds * RATE)))


def noise(seconds: float, amplitude: float) -> bytes:
    rng = random.Random(3)  # noqa: S311 - reproducible test noise
    return b"".join(struct.pack("<h", int(amplitude * (rng.random() * 2 - 1))) for _ in range(int(seconds * RATE)))


def test_a_sustained_vowel_after_the_vad_region_is_kept_until_the_voice_stops() -> None:
    pcm = tone(1.0, 9000) + tone(3.0, 8000, 330.0) + tone(1.0, 0)        # speech, held madd, silence
    assert voicing.extend(pcm, [(0, RATE)]) == [(0, 4 * RATE)]


def test_silence_or_quiet_background_after_speech_is_not_added() -> None:
    assert voicing.extend(tone(1.0, 9000) + tone(2.0, 0), [(0, RATE)]) == [(0, RATE)]
    quiet = tone(1.0, 9000) + noise(2.0, 600)                           # far below a quarter of the voice level
    assert voicing.extend(quiet, [(0, RATE)]) == [(0, RATE)]


def test_regions_are_merged_clamped_and_never_shortened() -> None:
    pcm = tone(2.0, 9000) + tone(1.0, 0) + tone(1.0, 9000)
    assert voicing.extend(pcm, [(int(2.5 * RATE), 3 * RATE), (0, RATE)]) == [(0, 2 * RATE), (int(2.5 * RATE), 4 * RATE)]
    assert voicing.extend(pcm, [(0, RATE), (RATE // 2, int(1.5 * RATE))]) == [(0, 2 * RATE)]
    assert voicing.extend(pcm, [(3 * RATE, 4 * RATE)]) == [(3 * RATE, 4 * RATE)]
    assert voicing.extend(pcm, []) == []
