"""Speech recognition for recitation checks (backend §8 steps 2-3; system architecture: faster-whisper with
``tarteel-ai/whisper-base-ar-quran`` converted to CTranslate2 int8, CPU).

The engine is loaded once per ``asr`` worker process and never in the API process (AD-22). It returns only text
and confidence data; audio is passed as an in-memory array and released by the caller. The model and its licence
(Apache-2.0) and CPU throughput remain O-03 validation items; acceptance on held-out learner audio is O-06.
"""

from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Protocol

from app.services.recitation.audio import SAMPLE_RATE

UNCLEAR_LOGPROB = -1.0       # §8 step 3: mean avg_logprob below this is unclear
BEAM_SIZE = 5
MANIFEST = "qabas-model.json"


@dataclass(frozen=True)
class Transcription:
    text: str
    segments: int             # speech segments after VAD
    avg_logprob: float | None # mean of the segments' avg_logprob (None without segments)

    @property
    def unclear(self) -> bool:
        """No speech segments, empty text, or low mean confidence (§8 step 3)."""
        return (self.segments == 0 or not self.text.strip()
                or self.avg_logprob is None or self.avg_logprob < UNCLEAR_LOGPROB)


class Engine(Protocol):
    def transcribe(self, pcm: bytes) -> Transcription: ...


class ModelError(RuntimeError):
    pass


def verify_model(path: Path) -> dict[str, Any]:
    """The converted model directory carries ``qabas-model.json`` (written by scripts/convert_recitation_model.py)
    naming the source model, its revision and every file's SHA-256; a missing or altered file is refused."""
    manifest_path = path / MANIFEST
    if not manifest_path.is_file():
        raise ModelError(f"{path} has no {MANIFEST}; run scripts/convert_recitation_model.py")
    manifest: dict[str, Any] = json.loads(manifest_path.read_text(encoding="utf-8"))
    for name, digest in manifest["files"].items():
        file = path / name
        if not file.is_file() or hashlib.sha256(file.read_bytes()).hexdigest() != digest:
            raise ModelError(f"model file {name} is missing or altered")
    return manifest


class FasterWhisperEngine:
    """``language="ar"``, ``beam_size=5``, ``vad_filter=True``, int8 on CPU (§8 step 2)."""

    def __init__(self, model_path: Path, *, cpu_threads: int = 0) -> None:
        self.manifest = verify_model(model_path)
        from faster_whisper import WhisperModel  # the asr dependency group; never imported by the API

        self.model = WhisperModel(str(model_path), device="cpu", compute_type="int8", cpu_threads=cpu_threads)

    def transcribe(self, pcm: bytes) -> Transcription:
        import numpy as np

        audio = np.frombuffer(pcm, dtype=np.int16).astype(np.float32) / 32768.0
        segments, _ = self.model.transcribe(audio, language="ar", beam_size=BEAM_SIZE, vad_filter=True,
                                            condition_on_previous_text=False)
        texts, logprobs = [], []
        for segment in segments:
            texts.append(segment.text.strip())
            logprobs.append(float(segment.avg_logprob))
        del audio
        mean = sum(logprobs) / len(logprobs) if logprobs else None
        return Transcription(" ".join(t for t in texts if t), len(logprobs), mean)


def duration_ms(pcm: bytes) -> int:
    return len(pcm) * 1000 // (SAMPLE_RATE * 2)
