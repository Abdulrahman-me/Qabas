"""The recorded clip set through the real production pipeline: restricted decode, the converted faster-whisper
model, canonical expected words from the pinned mushaf, alignment and outcome (Phase 10 tracker, backend §8).

Runs only where the model (scripts/convert_recitation_model.py), the canonical mushaf (scripts/fetch_mushaf.py) and
the clips (scripts/recitation_clip_set.py) are installed: none may be fetched by CI (no live calls; O-03 model
validation, O-06 audio licence). Every behaviour it relies on is also covered in CI with generated audio and an
in-process engine. It prints per-clip latency and the p95 for the O-03 throughput record.
"""

from __future__ import annotations

import math
import random
import statistics
import struct
import time
from pathlib import Path
from typing import Any

import pytest
import yaml

from app.config import Settings
from app.services.recitation import audio
from app.services.recitation.engine import ModelError, verify_model
from app.services.recitation.service import evaluate
from app.sources.mushaf import MushafError, get_mushaf

HERE = Path(__file__).parent
BENCH = Path(__file__).resolve().parents[2] / "var" / "recitation_bench"
SPEC = yaml.safe_load((HERE / "clip_set.yaml").read_text(encoding="utf-8"))


def _ready() -> str | None:
    settings = Settings()
    try:
        verify_model(settings.recitation_model_path)
        get_mushaf(settings)
    except (ModelError, MushafError, OSError) as exc:
        return f"model or canonical mushaf not installed ({type(exc).__name__})"
    if any(not (BENCH / c["file"]).is_file() for c in SPEC["clips"] if "file" in c):
        return "reciter clips not fetched (scripts/recitation_clip_set.py)"
    return None


pytestmark = pytest.mark.skipif(_ready() is not None, reason=str(_ready()))


def _generated(kind: str, seconds: float = 3.0) -> bytes:
    rng = random.Random(7)  # noqa: S311 - reproducible test noise, not security
    samples = int(seconds * audio.SAMPLE_RATE)
    amplitude = 0 if kind == "silence" else 2500
    return b"".join(struct.pack("<h", int(amplitude * (rng.random() * 2 - 1))) for _ in range(samples))


@pytest.fixture(scope="module")
def engine() -> Any:
    from app.services.recitation.engine import FasterWhisperEngine
    return FasterWhisperEngine(Settings().recitation_model_path)


def test_clip_set(engine: Any) -> None:
    assert len(SPEC["clips"]) >= 10
    mushaf = get_mushaf(Settings())
    outcomes, latencies = {}, []
    for clip in SPEC["clips"]:
        if "file" in clip:
            data = (BENCH / clip["file"]).read_bytes()
            container = audio.sniff(data)
            assert container is not None
            pcm = audio.decode(data, container)
        else:
            pcm = _generated(clip["generated"])
        if "cut" in clip:
            pcm = pcm[: math.floor(len(pcm) * clip["cut"] / 2) * 2]
        check = clip.get("check", {})
        surah, ayah = check.get("verse", clip["verse"])
        start, end = check.get("words", (None, None))
        passage = mushaf.get(surah, ayah, word_start=start, word_end=end)
        began = time.perf_counter()
        transcription = engine.transcribe(pcm)
        latencies.append(time.perf_counter() - began)
        body = evaluate(passage, transcription, "ar", {})
        outcomes[clip["id"]] = "unclear" if body["status"] == "unclear" else ("passed" if body["passed"] else "failed")
    p95 = statistics.quantiles(latencies, n=20)[-1]
    print(f"\nclip set: {len(latencies)} clips, median {statistics.median(latencies):.2f} s, p95 {p95:.2f} s")
    errors = sum(1 for clip in SPEC["clips"] if outcomes[clip["id"]] != clip["expect"])
    print(f"model errors against the correct outcome: {errors}/{len(SPEC['clips'])}")
    # The pipeline must reproduce every expected outcome except the recorded model errors (which must still occur:
    # if the model changes, the record is updated deliberately).
    assert outcomes == {clip["id"]: clip.get("observed", clip["expect"]) for clip in SPEC["clips"]}
