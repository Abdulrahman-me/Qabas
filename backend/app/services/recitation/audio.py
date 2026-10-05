"""Recitation uploads: signature sniffing (API process) and restricted decoding (``asr`` worker only).

API §3.7: the same audio types as Raqeeb voice (``audio/mp4`` AAC, ``audio/webm`` Opus, ``audio/wav``,
``audio/mpeg``), at most 30 s and 5 MB. The declared MIME type and filename are never trusted: the container is
identified from its magic bytes, and the decoded duration is measured.

Decoding uses FFmpeg's libraries in-process (PyAV) over an in-memory, seekable buffer (D-111): the demuxer is
forced to the sniffed container, the single audio stream must use one of that container's allowed decoders, no
protocol or file is ever opened (so no network and nothing on disk), and decoding stops as soon as the output
exceeds 30 s. A seekable buffer matters: phone recorders write M4A with the ``moov`` index after the audio, which a
piped ffmpeg cannot demux. Output is 16 kHz mono signed 16-bit PCM (backend §8 step 1).
"""

from __future__ import annotations

import io
import itertools
from dataclasses import dataclass

MAX_BYTES = 5 * 1024 * 1024
MAX_SECONDS = 30
SAMPLE_RATE = 16_000
BYTES_PER_SECOND = SAMPLE_RATE * 2          # mono s16le


@dataclass(frozen=True)
class Container:
    mime: str
    demuxer: str                      # the forced libavformat demuxer
    decoders: frozenset[str]          # decoders this container may carry


WAV = Container("audio/wav", "wav", frozenset({"pcm_s16le", "pcm_s24le", "pcm_s32le", "pcm_f32le", "pcm_u8"}))
WEBM = Container("audio/webm", "matroska", frozenset({"opus", "libopus"}))
MP4 = Container("audio/mp4", "mp4", frozenset({"aac", "aac_fixed"}))
MPEG = Container("audio/mpeg", "mp3", frozenset({"mp3", "mp3float"}))
CONTAINERS = (WAV, WEBM, MP4, MPEG)


def sniff(data: bytes) -> Container | None:
    """The container from its signature, or None (``415 unsupported_media_type``)."""
    if len(data) >= 12 and data[:4] == b"RIFF" and data[8:12] == b"WAVE":
        return WAV
    if data[:4] == b"\x1a\x45\xdf\xa3":
        return WEBM
    if len(data) >= 12 and data[4:8] == b"ftyp":
        return MP4
    if data[:3] == b"ID3" or (len(data) >= 2 and data[0] == 0xFF and data[1] & 0xE0 == 0xE0):
        return MPEG
    return None


class DecodeError(Exception):
    """``reason``: ``undecodable`` (415) or ``too_long`` (413)."""

    def __init__(self, reason: str) -> None:
        super().__init__(reason)
        self.reason = reason


def decode(data: bytes, container: Container) -> bytes:
    """16 kHz mono s16le PCM, or DecodeError."""
    import av  # the asr dependency group (FFmpeg libraries); never imported by the API process

    limit = MAX_SECONDS * BYTES_PER_SECOND
    chunks: list[bytes] = []
    size = 0
    try:
        with av.open(io.BytesIO(data), mode="r", format=container.demuxer) as source:
            if len(source.streams.audio) != 1 or len(source.streams) != 1:
                raise DecodeError("undecodable")
            stream = source.streams.audio[0]
            if stream.codec_context.name not in container.decoders:
                raise DecodeError("undecodable")
            resampler = av.AudioResampler(format="s16", layout="mono", rate=SAMPLE_RATE)
            for frame in itertools.chain(source.decode(stream), [None]):   # lazily: stop at the cap
                for out in resampler.resample(frame):
                    chunk = bytes(out.planes[0])[: out.samples * 2]
                    size += len(chunk)
                    if size > limit:
                        raise DecodeError("too_long")
                    chunks.append(chunk)
    except DecodeError:
        raise
    except (av.FFmpegError, ValueError, OSError, EOFError) as exc:
        raise DecodeError("undecodable") from exc
    if not size:
        raise DecodeError("undecodable")
    return b"".join(chunks)
