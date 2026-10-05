"""Decode real media bytes and cut licensed reference audio; never synthesize scripture."""

from __future__ import annotations

import io
from typing import Any, cast

import av

from app.media.errors import MediaInvalid
from app.services.platform.storage import sha256_hex


def mp3_duration(data: bytes) -> int:
    if not data or len(data) > 10_000_000:
        raise MediaInvalid("audio is empty or exceeds its byte limit")
    try:
        with cast(av.container.InputContainer, av.open(io.BytesIO(data), format="mp3")) as source:
            if len(source.streams.audio) != 1 or source.streams.video:
                raise MediaInvalid("narration must contain one MP3 audio stream")
            duration = 0.0
            for frame in source.decode(audio=0):
                duration += frame.samples / frame.sample_rate
                if duration > 600:
                    raise MediaInvalid("audio exceeds ten minutes")
    except (av.FFmpegError, ValueError) as exc:
        raise MediaInvalid("audio is not a decodable MP3") from exc
    if duration <= 0:
        raise MediaInvalid("audio contains no samples")
    return round(duration * 1000)


def reference_clip(
    data: bytes,
    *,
    expected_sha256: str,
    start_ms: int,
    end_ms: int,
    timings: list[list[int]],
    word_start: int,
    word_end: int,
    canonical_word_count: int,
) -> tuple[bytes, list[list[int]], dict[str, Any]]:
    """Cut an already licensed, verified recording. Indices are canonical, one-based, inclusive.

    The caller supplies the scholarly verse/word binding and licence; this function only verifies/cuts bytes.
    No network fetch, inferred passage, ASR or TTS is involved.
    """
    duration = mp3_duration(data)
    if sha256_hex(data) != expected_sha256 or not 0 <= start_ms < end_ms <= duration:
        raise MediaInvalid("reference audio hash or cut range is invalid")
    if not 1 <= word_start <= word_end <= canonical_word_count or len(timings) != canonical_word_count:
        raise MediaInvalid("reference timing count or canonical word range is invalid")
    previous = -1
    for index, segment in enumerate(timings, 1):
        if len(segment) != 3 or segment[0] != index or not 0 <= segment[1] < segment[2] <= duration:
            raise MediaInvalid("reference timings do not enumerate the canonical words")
        if segment[1] < previous:
            raise MediaInvalid("reference timings overlap")
        previous = segment[2]
    chosen = timings[word_start - 1 : word_end]
    if chosen[0][1] < start_ms or chosen[-1][2] > end_ms:
        raise MediaInvalid("cut would truncate a selected word")
    if (word_start > 1 and start_ms < timings[word_start - 2][2]) or (
        word_end < canonical_word_count and end_ms > timings[word_end][1]
    ):
        raise MediaInvalid("cut would include an unselected neighbouring word")
    try:
        output = io.BytesIO()
        with (
            cast(av.container.InputContainer, av.open(io.BytesIO(data), format="mp3")) as source,
            av.open(output, "w", format="mp3") as target,
        ):
            stream = target.add_stream("libmp3lame", rate=24000)
            stream.layout = "mono"
            resampler = av.AudioResampler(format="fltp", layout="mono", rate=24000)
            cursor = 0
            out_samples = 0

            def frames() -> Any:
                for incoming in source.decode(audio=0):
                    yield from resampler.resample(incoming)
                yield from resampler.resample(None)

            for frame in frames():
                lo = max(0, round(start_ms * 24) - cursor)
                hi = min(frame.samples, round(end_ms * 24) - cursor)
                if hi > lo:
                    selected = av.AudioFrame.from_ndarray(frame.to_ndarray()[:, lo:hi], format="fltp", layout="mono")
                    selected.sample_rate = 24000
                    selected.pts = out_samples
                    out_samples += selected.samples
                    for packet in stream.encode(selected):
                        target.mux(packet)
                cursor += frame.samples
            for packet in stream.encode(None):
                target.mux(packet)
        raw = output.getvalue()
        actual_duration = mp3_duration(raw)
    except (av.FFmpegError, ValueError) as exc:
        raise MediaInvalid("licensed reference clip could not be encoded") from exc
    rebased = [[i, a - start_ms, b - start_ms] for i, a, b in chosen]
    return (
        raw,
        rebased,
        {
            "original_sha256": expected_sha256,
            "start_ms": start_ms,
            "end_ms": end_ms,
            "word_start": word_start,
            "word_end": word_end,
            "duration_ms": actual_duration,
        },
    )
