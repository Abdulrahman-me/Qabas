"""Bounded, decoded vision inputs. Provider URLs never enter the model request."""
from __future__ import annotations

import base64
import hashlib
import io
from dataclasses import dataclass
from typing import Any

from PIL import Image

from app.llm.errors import UnsafePromptData


@dataclass(frozen=True)
class VisionImage:
    data: bytes
    mime_type: str

    def block(self) -> dict[str, Any]:
        if self.mime_type not in {"image/png", "image/jpeg", "image/webp"} or not 0 < len(self.data) <= 5_000_000:
            raise UnsafePromptData("invalid vision image format/size")
        try:
            with Image.open(io.BytesIO(self.data)) as image:
                if Image.MIME.get(image.format or "") != self.mime_type or image.width * image.height > 12_000_000:
                    raise ValueError("vision dimensions or MIME mismatch")
                image.verify()
        except (OSError, ValueError, Image.DecompressionBombError) as exc:
            raise UnsafePromptData("vision image cannot be decoded") from exc
        return {"type": "image", "source": {"type": "base64", "media_type": self.mime_type,
                                             "data": base64.b64encode(self.data).decode("ascii")}}

    @property
    def sha256(self) -> str:
        return hashlib.sha256(self.data).hexdigest()
