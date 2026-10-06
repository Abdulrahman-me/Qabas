from __future__ import annotations

import asyncio
import uuid
from datetime import timedelta

import pytest
from sqlalchemy import func, select

from app.adapters import Transcript
from app.models import RaqeebMessage, RaqeebUploadReceipt
from app.raqeeb import intake, worker
from app.services.platform.auth_sessions import utcnow
from app.services.platform.storage import Bucket
from tests.raqeeb.support import Tools, model
from tests.raqeeb.test_api_worker import guest, send, start
from tests.raqeeb.test_input_decoders import wav
from tests.raqeeb.test_inputs import image, scripted, submit

pytestmark = pytest.mark.integration


class Speech:
    def __init__(self, text="Neutral voice question"):
        self.calls, self.text = 0, text

    async def transcribe(self, audio_wav, *, language_hint):
        self.calls += 1
        assert audio_wav.startswith(b"RIFF")
        return Transcript(self.text, language_hint)


async def test_voice_only_conversion_understood_input_and_dependent_referral_history(api, resources):
    headers, speech = guest(api), Speech()
    conv = start(api, headers)
    response = submit(api, headers, conv, [("audio", ("question.wav", wav(), "audio/wav"))])
    aid = response.json()["assistant_message"]["message_id"]
    assert await worker.process(resources, aid, client=model("personal_fatwa"), tools=Tools(),
                                speech=speech) == "completed"
    result = api.get(f"/v1/raqeeb/messages/{aid}", headers=headers).json()
    assert result["understood_input"]["transcript"] == speech.text and result["abstained"]
    history = api.get(f"/v1/raqeeb/conversations/{conv}", headers=headers).json()
    assert history["messages"][0]["attachments"][0]["duration_ms"] == 1000
    next_id = send(api, headers, conv, question="And in my situation?").json()["assistant_message"]["message_id"]
    client = model("general_knowledge", confidence=.1)
    client.script["raqeeb_classify"]["standalone"] = False
    assert await worker.process(resources, next_id, client=client, tools=Tools()) == "completed"
    result = api.get(f"/v1/raqeeb/messages/{next_id}", headers=headers).json()
    assert result["classification"]["question_class"] == "personal_fatwa" and result["abstained"]
    classifier = next(data for prompt, data in client.calls if prompt == "raqeeb_classify")
    assert any((t["understood_input"] or {}).get("transcript") == speech.text for t in classifier["history"])
    assert "att_" not in str(classifier["history"])


async def test_image_history_has_semantic_content_without_private_attachment_identity(api, resources):
    headers, conv = guest(api), None
    conv = start(api, headers)
    first = submit(api, headers, conv, [("images", ("private.png", image(), "image/png"))])
    assert await worker.process(resources, first.json()["assistant_message"]["message_id"],
                                client=scripted(), tools=Tools()) == "completed"
    next_id = send(api, headers, conv).json()["assistant_message"]["message_id"]
    client = scripted()
    assert await worker.process(resources, next_id, client=client, tools=Tools()) == "completed"
    classifier = next(data for prompt, data in client.calls if prompt == "raqeeb_classify")
    assert "Neutral supplied material" in str(classifier["history"])
    assert "att_" not in str(classifier["history"]) and "private.png" not in str(classifier["history"])


async def test_crash_after_input_checkpoint_resumes_without_retranscribing(api, resources):
    headers, speech = guest(api), Speech()
    response = submit(api, headers, start(api, headers), [("audio", ("question.wav", wav(), "audio/wav"))])
    aid = response.json()["assistant_message"]["message_id"]
    failing = model("out_of_scope")
    def crash(data):
        raise asyncio.CancelledError
    failing.script["raqeeb_classify"] = crash
    with pytest.raises(asyncio.CancelledError):
        await worker.process(resources, aid, client=failing, tools=Tools(), speech=speech)
    assert await worker.process(resources, aid, client=model("out_of_scope"), tools=Tools(),
                                speech=speech) == "completed"
    assert speech.calls == 1


async def test_object_failure_leaves_durable_receipt_retry_and_pending_cleanup(api, resources, monkeypatch):
    headers, key = guest(api), str(uuid.uuid4())
    conv = start(api, headers)
    files = [("images", ("sample.png", image(), "image/png"))]
    storage = api.app.state.resources.storage
    actual = storage.put_immutable
    def fail(*args, **kwargs):
        raise OSError("Synthetic object-storage outage")
    monkeypatch.setattr(storage, "put_immutable", fail)
    assert submit(api, headers, conv, files, key=key).status_code == 500
    async with resources.sessionmaker() as db:
        assert await db.scalar(select(func.count()).select_from(RaqeebUploadReceipt)) == 1
        assert await db.scalar(select(func.count()).select_from(RaqeebMessage)) == 0
    monkeypatch.setattr(storage, "put_immutable", actual)
    assert submit(api, headers, conv, files, key=key).status_code == 202
    async with resources.sessionmaker() as db:
        assert await db.scalar(select(func.count()).select_from(RaqeebUploadReceipt)) == 1
    pending = await intake.prepare(resources, (await _receipt(resources)).user_id, "pending-only",
        "b" * 64, (intake.Upload("image", "unused.png", "image/png", image()),))
    async with resources.sessionmaker() as db, db.begin():
        receipt = await db.get(RaqeebUploadReceipt, pending[0])
        receipt.expires_at = utcnow() - timedelta(seconds=1)
        object_key = receipt.object_key
    assert await intake.sweep(resources) == 1 and not resources.storage.exists(Bucket.private, object_key)


async def _receipt(resources):
    async with resources.sessionmaker() as db:
        return (await db.execute(select(RaqeebUploadReceipt))).scalar_one()


async def test_private_attachment_hash_mismatch_is_unreadable_not_fabricated(api, resources, monkeypatch):
    headers = guest(api)
    response = submit(api, headers, start(api, headers), [("images", ("sample.png", image(), "image/png"))])
    aid = response.json()["assistant_message"]["message_id"]
    monkeypatch.setattr(resources.storage, "get", lambda *args: b"changed bytes")
    client = scripted()
    assert await worker.process(resources, aid, client=client, tools=Tools()) == "failed"
    assert api.get(f"/v1/raqeeb/messages/{aid}", headers=headers).json()["error"]["code"] == "input_unreadable"
    assert not client.calls
