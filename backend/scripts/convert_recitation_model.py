"""Convert the recitation ASR model to CTranslate2 int8 and pin every file (system architecture; backend §8).

Run once per environment, in a separate tooling environment (it needs transformers and torch, which the API and
the asr worker do not):

    uv venv tools-venv && uv pip install --python tools-venv "ctranslate2==4.8.2" "transformers>=4.46,<5" torch \
        truststore --extra-index-url https://download.pytorch.org/whl/cpu
    tools-venv/Scripts/python scripts/convert_recitation_model.py [--out DIR] [--system-ca]

It downloads ``tarteel-ai/whisper-base-ar-quran`` at the pinned revision (Apache-2.0), converts it with int8
weights, writes the tokenizer and preprocessor next to it (so the worker never fetches anything at runtime) and
writes ``qabas-model.json`` with the source, revision, licence and the SHA-256 of every file. The worker refuses a
model directory whose files differ from that manifest. The model directory is not committed (size; O-03 keeps
the model licence/throughput validation open).
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import sys
import tempfile
from datetime import UTC, datetime
from pathlib import Path

BACKEND = Path(__file__).resolve().parents[1]
MODEL = "tarteel-ai/whisper-base-ar-quran"
REVISION = "5c3c53fdf9272c4f6ee0bee09a1e5a4a615ee25c"
LICENCE = "Apache-2.0"
DEFAULT_OUT = BACKEND / "var" / "models" / "whisper-base-ar-quran-ct2"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--system-ca", action="store_true", help="verify TLS with the OS certificate store")
    args = parser.parse_args()
    if args.system_ca:
        import truststore

        truststore.inject_into_ssl()
    import ctranslate2
    from huggingface_hub import snapshot_download
    from transformers import WhisperProcessor

    if args.out.exists():
        print(f"{args.out} exists; remove it first", file=sys.stderr)
        return 1
    with tempfile.TemporaryDirectory() as tmp:
        source = snapshot_download(MODEL, revision=REVISION, local_dir=str(Path(tmp) / "source"),
                                   allow_patterns=["*.json", "*.txt", "pytorch_model.bin", "*.safetensors"])
        staging = Path(tmp) / "ct2"
        ctranslate2.converters.TransformersConverter(source).convert(str(staging), quantization="int8")
        WhisperProcessor.from_pretrained(source).save_pretrained(str(staging))
        if not (staging / "tokenizer.json").is_file() or not (staging / "preprocessor_config.json").is_file():
            print("conversion did not produce tokenizer.json and preprocessor_config.json", file=sys.stderr)
            return 1
        args.out.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(staging, args.out)
    files = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(args.out.iterdir()) if p.is_file()}
    manifest = {"schema": "qabas.recitation_model/1", "source": MODEL, "revision": REVISION, "licence": LICENCE,
                "format": "ctranslate2", "quantization": "int8", "ctranslate2": ctranslate2.__version__,
                "converted_at": datetime.now(UTC).isoformat(), "files": files}
    (args.out / "qabas-model.json").write_text(json.dumps(manifest, indent=1) + "\n", encoding="utf-8")
    print(f"converted {MODEL}@{REVISION[:12]} to {args.out} ({len(files)} files)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
