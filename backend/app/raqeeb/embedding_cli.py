"""Isolated optional bge-m3 CPU runtime. No downloads, credentials or private data files.

Install ``uv sync --group embeddings`` and an O-03-approved model directory. ``qabas-model.yaml`` names all
model files by relative path and SHA-256, the fixed model ID, licence review and approving owner/date/report.
"""

from __future__ import annotations

import hashlib
import importlib
import json
import sys
from pathlib import Path
from typing import Any

import yaml

from app.sources.errors import ProviderNotConfigured


def approved(directory: Path) -> dict[str, Any]:
    try:
        manifest = yaml.safe_load((directory / "qabas-model.yaml").read_text(encoding="utf-8"))
    except (OSError, ValueError):
        raise ProviderNotConfigured("bge_m3", "local model approval manifest is absent") from None
    if not isinstance(manifest, dict) or manifest.get("model") != "BAAI/bge-m3" or \
            manifest.get("status") != "approved" or not all(manifest.get(k) for k in (
                "approved_by", "approved_on", "report", "revision", "licence")) or not manifest.get("files"):
        raise ProviderNotConfigured("bge_m3", "local model and licence approval are pending O-03")
    root = directory.resolve()
    actual = {p.relative_to(root).as_posix() for p in root.rglob("*") if p.is_file()
              and p.name != "qabas-model.yaml"}
    if actual != set(manifest["files"]):
        raise ProviderNotConfigured("bge_m3", "model directory differs from approved inventory")
    for name, expected in manifest["files"].items():
        path = (root / name).resolve()
        if not path.is_relative_to(root) or path.is_symlink():
            raise ProviderNotConfigured("bge_m3", "installed model path escapes approval")
        with path.open("rb") as stream:
            digest = hashlib.file_digest(stream, "sha256").hexdigest()
        if digest != expected:
            raise ProviderNotConfigured("bge_m3", "installed model digest differs from approval")
    return dict(manifest)


def main() -> None:
    directory = Path(sys.argv[1])
    approved(directory)
    payload = json.loads(sys.stdin.buffer.read(256_000))
    texts = payload["texts"]
    if not isinstance(texts, list) or not texts or len(texts) > 200 or any(not isinstance(t, str) for t in texts):
        raise ValueError("invalid embedding input")
    module = importlib.import_module("sentence_transformers")
    model = module.SentenceTransformer(str(directory), device="cpu", local_files_only=True, trust_remote_code=False)
    vectors = model.encode(texts, normalize_embeddings=True, show_progress_bar=False, convert_to_numpy=True)
    sys.stdout.write(json.dumps(vectors.tolist()))


if __name__ == "__main__":
    main()
