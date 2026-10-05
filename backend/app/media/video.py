"""Inspect decoded WebM preview bytes; declared MIME alone is never sufficient."""

from __future__ import annotations

import io
from typing import cast

import av

from app.media.errors import MediaInvalid


def webm_info(raw: bytes) -> tuple[int, int, int]:
    if not 0 < len(raw) <= 25_000_000 or not raw.startswith(b"\x1a\x45\xdf\xa3"):
        raise MediaInvalid("invalid WebM preview format/size")
    try:
        with cast(av.container.InputContainer, av.open(io.BytesIO(raw), format="webm")) as source:
            if len(source.streams.video) != 1 or source.streams.audio:
                raise MediaInvalid("preview needs one silent WebM video stream")
            stream = source.streams.video[0]
            if stream.codec_context.name not in {"vp8", "vp9"} or stream.width * stream.height > 12_000_000:
                raise MediaInvalid("unsupported preview codec or dimensions")
            last = 0.0
            count = 0
            for frame in source.decode(video=0):
                count += 1
                last = frame.time or 0
                if last > 30 or count > 1000:
                    raise MediaInvalid("preview exceeds duration/frame limits")
            if not count or not stream.average_rate:
                raise MediaInvalid("preview has no decodable timed frames")
            return stream.width, stream.height, round((last + 1 / float(stream.average_rate)) * 1000)
    except (av.FFmpegError, ValueError) as exc:
        raise MediaInvalid("preview bytes are not decodable WebM") from exc
