"""Check actual bytes, not filename suffixes or provider declarations."""

from __future__ import annotations

import io

from PIL import Image

from app.media.errors import MediaInvalid

RASTER = {"image/png", "image/jpeg", "image/webp"}


def raster(data: bytes, mime_type: str, width: int, height: int) -> None:
    if mime_type not in RASTER or not 0 < len(data) <= 10_000_000 or width * height > 12_000_000:
        raise MediaInvalid("unsupported image format/size")
    try:
        with Image.open(io.BytesIO(data)) as image:
            if Image.MIME.get(image.format or "") != mime_type or image.size != (width, height):
                raise ValueError("image MIME/dimensions mismatch")
            if getattr(image, "is_animated", False):
                raise ValueError("static artwork cannot be animated")
            image.verify()
    except (OSError, ValueError, Image.DecompressionBombError) as exc:
        raise MediaInvalid("invalid image bytes or dimensions") from exc


def webp(data: bytes, mime_type: str, width: int, height: int, *, native: tuple[int, int]) -> bytes:
    raster(data, mime_type, *native)
    with Image.open(io.BytesIO(data)) as source:
        image = source.convert("RGB").resize((width, height), Image.Resampling.LANCZOS)
        output = io.BytesIO()
        image.save(output, "WEBP", lossless=True)
        if output.tell() > 1_000_000:
            output = io.BytesIO()
            image.save(output, "WEBP", quality=90)
    result = output.getvalue()
    raster(result, "image/webp", width, height)
    return result
