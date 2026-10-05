"""Published lesson recommendations: bge-m3 cosine >= .6, at most two, current track and language only."""

from __future__ import annotations

import asyncio
import json
import math
import os
import sys
from pathlib import Path
from typing import Protocol

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import Settings
from app.content import catalog
from app.content.projection import select_variant
from app.models import LessonVersion, Unit
from app.raqeeb.pipeline import spans_in
from app.sources.errors import ProviderNotConfigured, ProviderResponseInvalid


class Embedder(Protocol):
    async def encode(self, texts: list[str]) -> list[list[float]]: ...


def cosine(a: list[float], b: list[float]) -> float:
    if not a or len(a) != len(b) or any(not math.isfinite(x) for x in (*a, *b)):
        raise ValueError("invalid embedding vector")
    den = math.sqrt(sum(x * x for x in a) * sum(x * x for x in b))
    return sum(x * y for x, y in zip(a, b, strict=True)) / den if den else 0


class LocalBge:
    """Isolated CPU inference. An installed approved bge-m3 model is required; no runtime downloads or SDKs.

    Phase 17 may reuse this provider for its embeddings worker. A killed recommendation subprocess leaves no
    files, DB rows or background threads. Recommendations are optional; timeout never invalidates an answer.
    """
    def __init__(self, settings: Settings) -> None:
        self.settings = settings

    async def encode(self, texts: list[str]) -> list[list[float]]:
        directory = self.settings.raqeeb_embedding_model_dir
        if directory is None:
            raise ProviderNotConfigured("bge_m3", "approved local recommendation model is not installed (O-03)")
        env = {k: v for k, v in os.environ.items() if k.upper() in {"SYSTEMROOT", "WINDIR", "PATH", "TEMP", "TMP"}}
        env.update(PYTHONUTF8="1", HF_HUB_OFFLINE="1", TRANSFORMERS_OFFLINE="1")
        process = await asyncio.create_subprocess_exec(
            sys.executable, "-m", "app.raqeeb.embedding_cli", str(directory),
            env=env, cwd=Path(__file__).resolve().parents[2], stdin=asyncio.subprocess.PIPE,
            stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL, limit=2_000_000)
        try:
            async with asyncio.timeout(self.settings.raqeeb_embedding_timeout_seconds):
                output, _ = await process.communicate(json.dumps({"texts": texts}, ensure_ascii=False).encode())
            if process.returncode or len(output) > 2_000_000:
                raise ProviderResponseInvalid("bge_m3", "local embedding process failed")
            vectors = json.loads(output)
            if not isinstance(vectors, list) or len(vectors) != len(texts) or any(
                    not isinstance(v, list) or len(v) != 1024 or
                    any(not isinstance(x, (float, int)) or isinstance(x, bool) or not math.isfinite(x) for x in v)
                    for v in vectors):
                raise ProviderResponseInvalid("bge_m3", "invalid embedding output")
            return [[float(x) for x in v] for v in vectors]
        except (ValueError, TimeoutError) as exc:
            raise ProviderResponseInvalid("bge_m3", "local embeddings are unavailable") from exc
        finally:
            if process.returncode is None:
                process.kill()
                await process.wait()


async def recommend(db: AsyncSession, question: str, track: str, language: str, embedder: Embedder
                    ) -> list[dict[str, str]]:
    links, texts = [], []
    units = list((await db.execute(select(Unit.id).where(Unit.tracks.contains([track]),
                                                        Unit.coming_soon.is_(False)))).scalars())
    for lesson in await catalog.published_lessons(db, units):
        variant = select_variant(set(lesson.variants), track)
        version = await db.get(LessonVersion, lesson.lesson_version_id)
        assert version is not None
        wording = version.content["variants"][language][variant]
        links.append({"lesson_id": lesson.lesson_id, "title": wording["title"]})
        texts.append(wording["title"] + " " + " ".join(s.get("text", "") for s in spans_in(wording["objectives"])))
    if not links:
        return []
    vectors = await embedder.encode([question, *texts])
    if len(vectors) != len(texts) + 1:
        raise ProviderResponseInvalid("bge_m3", "embedding count mismatch")
    scores = [(cosine(vectors[0], v), i) for i, v in enumerate(vectors[1:])]
    return [links[i] for score, i in sorted(scores, key=lambda x: (-x[0], x[1]))[:2] if score >= .6]
