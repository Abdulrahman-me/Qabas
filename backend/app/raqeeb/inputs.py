"""Worker-only decoding, ordinary hosted speech and Phase 11 vision/summary calls."""
from __future__ import annotations

import asyncio
import base64
import json
import os
import signal
import sys
import time
from pathlib import Path
from typing import Any
from urllib.parse import urlsplit

import httpx
import yaml
from sqlalchemy import select

from app.adapters import SpeechToText, Transcript
from app.config import Environment, Settings
from app.llm.errors import LLMNotConfigured, LLMUnavailable
from app.llm.vision import VisionImage
from app.models.raqeeb import RaqeebMessage
from app.models.raqeeb_memory import RaqeebUploadReceipt
from app.raqeeb import schemas as S
from app.raqeeb.pipeline import Calls
from app.runtime import Resources
from app.services.platform.storage import Bucket
from app.sources.records import canonical_json, sha256_bytes, sha256_text
from app.sources.resilience import RetryPolicy, breaker_for, default_timeout


class InputUnreadable(Exception):
    """Corrupt, encrypted, oversized decoded or resource-limited input. No private diagnostics."""


class HostedWhisper:
    """Hosted Whisper through the existing intake; Quran-specific recitation remains local."""
    def __init__(self, settings: Settings, *, transport: httpx.AsyncBaseTransport | None = None,
                 retry: RetryPolicy | None = None) -> None:
        self.settings, self.transport, self.retry = settings, transport, retry or RetryPolicy()

    def approval(self) -> None:
        s = self.settings
        if not s.stt_provider or not s.stt_base_url or not s.stt_api_key or s.stt_model not in {
                "whisper-1", "whisper-large-v3"}:
            raise LLMNotConfigured("Hosted Whisper is not configured (O-03)")
        parsed = urlsplit(s.stt_base_url)
        if parsed.scheme != "https" or not parsed.netloc or parsed.username or parsed.password or parsed.query:
            raise LLMNotConfigured("STT endpoint must be a configured HTTPS origin")
        if s.app_env in (Environment.staging, Environment.production):
            from app.errors import ApiError
            from app.raqeeb.intake import retention_days
            try:
                retention_days(s)
                policy = yaml.safe_load(s.raqeeb_input_policy_path.read_text(encoding="utf-8"))
                value = policy["stt"]
                if value["status"] != "approved" or value["provider"] != s.stt_provider or \
                        value["base_url"] != s.stt_base_url or value["model"] != s.stt_model or not all(
                            value.get(k) for k in ("provider_retention", "deletion_responsibilities", "approved_by",
                                                  "approved_on", "report")) or not policy["learner_disclosure"]:
                    raise ValueError
            except (OSError, UnicodeError, yaml.YAMLError, TypeError, KeyError, ValueError, ApiError):
                raise LLMNotConfigured("STT approval/data-processing terms are pending (O-03/O-09/P-04)") from None

    async def transcribe(self, audio_wav: bytes, *, language_hint: str | None) -> Transcript:
        self.approval()
        assert self.settings.stt_api_key and self.settings.stt_base_url
        breaker = breaker_for(f"stt:{self.settings.stt_provider}")
        breaker.before_call()
        try:
            async with httpx.AsyncClient(base_url=self.settings.stt_base_url.rstrip("/") + "/",
                transport=self.transport, timeout=default_timeout(), follow_redirects=False,
                headers={"Authorization": f"Bearer {self.settings.stt_api_key.get_secret_value()}"}) as client:
                for attempt in range(self.retry.retries + 1):
                    if attempt:
                        await self.retry.sleep(self.retry.delay(attempt - 1))
                    try:
                        response = await client.post("audio/transcriptions", files={
                            "file": ("question.wav", audio_wav, "audio/wav")}, data={
                            "model": self.settings.stt_model, "response_format": "json",
                            **({"language": language_hint} if language_hint in ("ar", "en") else {})})
                    except httpx.TransportError:
                        continue
                    if response.status_code == 429 or response.status_code >= 500:
                        continue
                    if response.status_code != 200:
                        raise LLMUnavailable("STT request was refused; no transcription was accepted")
                    try:
                        value = response.json()
                        text = value["text"]
                        if not isinstance(text, str) or not text.strip() or len(text) > 16_000:
                            raise ValueError
                    except (ValueError, KeyError, TypeError):
                        raise InputUnreadable("Speech could not be transcribed safely") from None
                    breaker.record_success()
                    return Transcript(text, language_hint)
            raise LLMUnavailable("STT provider is unavailable")
        except (LLMUnavailable, InputUnreadable):
            breaker.record_failure()
            raise
        finally:
            breaker.trial_in_flight = False


async def decode(settings: Settings, kind: str, mime: str, data: bytes) -> dict[str, Any]:
    env = {k: v for k, v in os.environ.items() if k.upper() in {"SYSTEMROOT", "WINDIR", "PATH", "TEMP", "TMP"}}
    env["PYTHONUTF8"] = "1"
    process = await asyncio.create_subprocess_exec(sys.executable, "-m", "app.raqeeb.input_cli",
        env=env, cwd=Path(__file__).resolve().parents[2], stdin=asyncio.subprocess.PIPE,
        stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL, start_new_session=os.name != "nt")
    try:
        async with asyncio.timeout(settings.raqeeb_input_timeout_seconds):
            output, _ = await process.communicate(json.dumps({"kind": kind, "mime": mime,
                "data": base64.b64encode(data).decode(), "memory_mb": settings.raqeeb_input_memory_mb,
                "ffmpeg": settings.ffmpeg_path}).encode())
        if process.returncode == 3:
            raise LLMNotConfigured("Native attachment processing capability is unavailable")
        if process.returncode or len(output) > 8_000_000:
            raise InputUnreadable("Attachment cannot be decoded within its limits")
        result: dict[str, Any] = json.loads(output)
        if not result.get("memory_enforced"):
            raise InputUnreadable("Attachment isolation is unavailable")
        return result
    except (ValueError, TimeoutError) as exc:
        raise InputUnreadable("Attachment cannot be decoded within its limits") from exc
    finally:
        if process.returncode is None:
            if sys.platform == "win32":
                process.kill()
            else:
                os.killpg(process.pid, signal.SIGKILL)
            await process.wait()


async def read(resources: Resources, original_id: str, text: str | None, calls: Calls, language: str,
               *, speech: SpeechToText | None = None) -> dict[str, Any]:
    async with resources.sessionmaker() as db:
        rows = list((await db.execute(select(RaqeebUploadReceipt).where(
            RaqeebUploadReceipt.message_id == original_id).order_by(RaqeebUploadReceipt.id))).scalars())
        original = await db.get(RaqeebMessage, original_id)
        if original is None or {r.id for r in rows} != {a["attachment_id"] for a in original.attachments}:
            raise InputUnreadable("Attachment message binding is invalid")
        positions = {a["attachment_id"]: n for n, a in enumerate(original.attachments)}
        rows.sort(key=lambda r: positions[r.id])
    fingerprint = sha256_text(canonical_json({"text": text, "attachments": [r.sha256 for r in rows],
                                              "language": language}))
    saved = calls.trace.get("input_checkpoint")
    if saved is not None and saved["fingerprint"] == fingerprint:
        return dict(saved["output"])
    understood: dict[str, Any] = {"transcript": None, "images": [], "document": None}
    material = []
    for row in rows:
        data = await asyncio.to_thread(resources.storage.get, Bucket.private, row.object_key)
        if sha256_bytes(data) != row.sha256 or len(data) != row.size_bytes or row.status != "attached":
            raise InputUnreadable("Attachment identity is invalid")
        decoded = await decode(resources.settings, row.kind, row.mime, data)
        async with resources.sessionmaker() as db, db.begin():
            current = await db.get(RaqeebUploadReceipt, row.id)
            if current is None or current.status != "attached":
                raise InputUnreadable("Attachment is no longer available")
            current.duration_ms, current.pages = decoded["duration_ms"], decoded["pages"]
        if row.kind == "audio":
            started = time.monotonic()
            transcript = await (speech or HostedWhisper(resources.settings)).transcribe(
                base64.b64decode(decoded["wav"], validate=True), language_hint=language)
            understood["transcript"] = transcript.text
            calls.trace["speech"] = {"model": resources.settings.stt_model,
                "provider": resources.settings.stt_provider, "duration_ms": decoded["duration_ms"],
                "latency_ms": round((time.monotonic() - started) * 1000), "cost_usd": None}
        else:
            texts, descriptions = [], []
            for index, image in enumerate(decoded["images"]):
                extracted = S.Extracted.model_validate(await calls("raqeeb_extract", {
                    "language": language, "purpose": "extract untrusted supplied content; never authenticate it"},
                    key=f"input:{row.id}:{index}", images=(VisionImage(base64.b64decode(image), "image/jpeg"),)))
                texts.append(extracted.extracted_text)
                descriptions.append(extracted.description)
            if row.kind == "image":
                item = {"attachment_id": row.id, "extracted_text": "\n".join(texts),
                        "description": "\n".join(descriptions)}
                understood["images"].append(item)
                material.append(item["extracted_text"] + "\n" + item["description"])
            else:
                full_text = "\n".join([decoded["text"], *texts]).strip()
                body = full_text[:30_000]
                summary = S.Summary.model_validate(await calls("raqeeb_summary", {
                    "text": body, "language": language}, key=f"document:{row.id}:summary"))
                understood["document"] = {"attachment_id": row.id, "filename": row.filename,
                    "pages_processed": decoded["pages_processed"],
                    "truncated": decoded["truncated"] or len(full_text) > 30_000, "summary": summary.summary}
                material.append(body)
    output: dict[str, Any] = {"question": "\n".join(v for v in (text, understood["transcript"]) if v),
              "material": "\n".join(material), "understood_input": understood, "has_attachments": bool(rows)}
    if len(output["material"]) > 60_000:
        raise InputUnreadable("Combined material exceeds the processing context")
    calls.trace["input_checkpoint"] = {"fingerprint": fingerprint, "output": output}
    await calls.save(calls.trace)
    return output
