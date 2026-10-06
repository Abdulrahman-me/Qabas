"""Secret-safe pilot preflight; optional exact model and strict-output smoke using Phase 11."""
from __future__ import annotations

import argparse
import asyncio
import json
import sys
import time
from pathlib import Path
from typing import Any

from pydantic import ValidationError

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.config import Settings
from app.llm.budget import Ledger
from app.llm.errors import LLMError
from app.llm.openai_client import OpenAIClient
from app.raqeeb.inputs import HostedWhisper


def placeholder(value: str) -> bool:
    return not value.strip() or "<" in value or value.lower() in {"changeme", "placeholder", "your-api-key"}


def inspect(settings: Settings) -> dict[str, Any]:
    required = {"DATABASE_URL": settings.database_url, "REDIS_URL": settings.redis_url}
    for name in ("auth_token_pepper", "storage_signing_key"):
        value = getattr(settings, name)
        required[name.upper()] = value.get_secret_value() if value else ""
    return {"environment": settings.app_env, "boot_fields": {k: "missing_or_placeholder" if placeholder(v)
            else "configured" for k, v in required.items()},
            "openai_key_present": bool(settings.openai_api_key and
                not placeholder(settings.openai_api_key.get_secret_value())),
            "factory_model": settings.factory_llm_model, "raqeeb_model": settings.raqeeb_llm_model,
            "stt_provider": settings.stt_provider, "stt_model": settings.stt_model,
            "stt_key_present": bool(settings.stt_api_key and not placeholder(settings.stt_api_key.get_secret_value())),
            "canonical_mushaf_installed": (settings.mushaf_dir / "kfgqpc_hafs_v30.json").is_file(),
            "image_provider_selected": bool(settings.image_provider),
            "narration_enabled": settings.media_narration_enabled,
            "notice": "Credential presence is not provider approval, connectivity or publication readiness."}


async def smoke(settings: Settings, args: argparse.Namespace) -> dict[str, Any]:
    report: dict[str, Any] = {}
    try:
        client = OpenAIClient(settings, model=settings.factory_llm_model or "gpt-6.1-sol")
        try:
            report["exact_account_model_available"] = await client.available()
            if not report["exact_account_model_available"]:
                return report
            started = time.monotonic()
            ledger = Ledger(budget_tokens=10_000)
            result = await client.structured("conversation_title", {"language": "en",
                "question": "A neutral structured-output connectivity check"}, ledger=ledger)
            report["structured_output"] = {"passed": True, "model": result.model,
                "latency_ms": round((time.monotonic() - started) * 1000), "tokens": ledger.tokens,
                "cost_usd": ledger.summary()["usd"]}
        finally:
            await client.aclose()
    except LLMError as exc:
        report["llm"] = {"passed": False, "category": type(exc).__name__, "reason": str(exc)}
    for language, path in (("ar", args.ar_audio), ("en", args.en_audio)):
        if path is None:
            report[f"stt_{language}"] = {"passed": False, "reason": "no operator-provided neutral WAV sample"}
            continue
        try:
            data = path.read_bytes()
            if not data.startswith(b"RIFF") or data[8:12] != b"WAVE" or len(data) > 5_000_000:
                raise ValueError("provide a neutral WAV sample below 5 MB")
            started = time.monotonic()
            transcript = await HostedWhisper(settings).transcribe(data, language_hint=language)
            report[f"stt_{language}"] = {"passed": True, "model": settings.stt_model,
                "latency_ms": round((time.monotonic() - started) * 1000), "text": transcript.text}
        except (LLMError, OSError, ValueError) as exc:
            report[f"stt_{language}"] = {"passed": False, "category": type(exc).__name__}
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--env-file", type=Path)
    parser.add_argument("--smoke", action="store_true", help="makes a small paid strict-output call when configured")
    parser.add_argument("--ar-audio", type=Path)
    parser.add_argument("--en-audio", type=Path)
    args = parser.parse_args()
    try:
        settings = Settings(_env_file=args.env_file) if args.env_file else Settings()
    except ValidationError as exc:
        print(json.dumps({"configuration_valid": False, "errors": [
            {"field": ".".join(str(p) for p in e["loc"]), "type": e["type"]}
            for e in exc.errors(include_input=False, include_context=False)]}))
        return
    report = inspect(settings)
    if args.smoke:
        report["smoke"] = asyncio.run(smoke(settings, args))
    print(json.dumps(report, ensure_ascii=True, indent=2))


if __name__ == "__main__":
    main()
