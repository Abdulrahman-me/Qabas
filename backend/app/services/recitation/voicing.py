"""Keep sustained recitation inside the VAD's speech regions (D-118, F-95).

The specified VAD (Silero through faster-whisper, default options) is trained on conversational speech. It scores
a sustained, melodic Qur'anic elongation - the obligatory six-count madd of «ٱلضَّآلِّينَ», the opening letters
«الٓمٓ» - as non-speech, so the end of a correct recitation was cut off before recognition (measured: speech
probability 0.02-0.06 for four seconds of voice at full level). The VAD still decides whether there is speech at
all and where each region starts; a region is only extended forward while the voice continues at a level relative
to that region's own speech, so silence, a pause or quiet background still ends it. Pure Python on 16 kHz mono
s16le PCM, so it is tested without the model.
"""

from __future__ import annotations

import math
import statistics
import sys
from array import array

FRAME = 800                    # 50 ms at 16 kHz
RELATIVE_FLOOR = 0.25          # a continuing voice keeps at least a quarter of its region's median level
ABSOLUTE_FLOOR = 300.0         # and is above near-silence (s16 RMS ≈ -40 dBFS)


def frame_levels(pcm: bytes) -> list[float]:
    samples = array("h")
    samples.frombytes(pcm[: len(pcm) - len(pcm) % 2])
    if sys.byteorder == "big":
        samples.byteswap()
    return [math.sqrt(sum(s * s for s in samples[i:i + FRAME]) / len(samples[i:i + FRAME]))
            for i in range(0, len(samples), FRAME)]


def extend(pcm: bytes, regions: list[tuple[int, int]]) -> list[tuple[int, int]]:
    """``regions`` are VAD speech spans in samples; returns them extended through continuing voice, merged."""
    if not regions:
        return []
    levels = frame_levels(pcm)
    total = len(pcm) // 2
    spans: list[tuple[int, int]] = []
    for start, end in sorted(regions):
        inside = levels[start // FRAME: max(start // FRAME + 1, end // FRAME)]
        floor = max(ABSOLUTE_FLOOR, RELATIVE_FLOOR * statistics.median(inside)) if inside else ABSOLUTE_FLOOR
        frame = end // FRAME
        while frame < len(levels) and levels[frame] >= floor:
            frame += 1
        spans.append((start, max(end, min(total, frame * FRAME))))
    merged = [spans[0]]
    for start, end in spans[1:]:
        if start <= merged[-1][1]:
            merged[-1] = (merged[-1][0], max(merged[-1][1], end))
        else:
            merged.append((start, end))
    return merged
