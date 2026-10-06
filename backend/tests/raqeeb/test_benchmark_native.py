from __future__ import annotations

import copy
import uuid

import pytest
from sqlalchemy import func, select

from app.config import Environment
from app.models import RaqeebConversation, RaqeebMemory
from bench.native import Native
from tests.raqeeb.support import Tools
from tests.raqeeb.test_evaluation import case
from tests.raqeeb.test_inputs import docx, image
from tests.raqeeb.test_memory import Embedder, script

pytestmark = pytest.mark.integration


async def test_native_driver_full_pipeline_replay_source_audit_and_namespace_warming(tmp_path, resources):
    native = Native(resources, tmp_path, synthetic=True, client_factory=script, tools_factory=Tools,
                    embedder=Embedder())
    namespace = uuid.uuid4()
    question = case()
    first = await native.answer(question, namespace)
    assert first["error"] is None and first["answer"]["classification"]["question_class"] == "general_knowledge"
    assert await native.answer(question, namespace) == first
    issues, sources = await native.audit(first["answer"], question)
    assert issues == [] and sources
    malformed = copy.deepcopy(first["answer"])
    malformed["citations"][0]["source"]["excerpt"] = "A made-up excerpt"
    assert "wrong_source_binding" in (await native.audit(malformed, question))[0]
    malformed["citations"][0]["source"]["source_id"] = "src_unknown"
    assert "hallucinated_source" in (await native.audit(malformed, question))[0]
    warm = await native.warm([case("warm")], namespace)
    assert warm["count"] > 0
    async with resources.sessionmaker() as db:
        assert await db.scalar(select(func.count()).select_from(RaqeebConversation)) == 2
        assert await db.scalar(select(func.count()).select_from(RaqeebMemory)) == 2


async def test_native_baseline_receives_original_material_and_no_gold_or_learner_data(tmp_path, resources):
    (tmp_path / "neutral.png").write_bytes(image())
    (tmp_path / "neutral.docx").write_bytes(docx("Neutral untrusted document material."))
    native = Native(resources, tmp_path, synthetic=True)
    question = case().model_copy(update={"attachments": ["neutral.png", "neutral.docx"]})
    request = await native.baseline_request(question, "opaque")
    assert request.images and "Neutral untrusted document material" in request.data["material"]
    assert set(request.data) == {"question", "material", "history", "language"}
    assert "gold" not in str(request.data) and "usr_" not in str(request.data)


def test_native_runner_refuses_shared_database_and_production_fake_mode(tmp_path, resources):
    with pytest.raises(ValueError, match="dedicated"):
        Native(resources, tmp_path)
    resources.settings = resources.settings.model_copy(update={"app_env": Environment.production})
    with pytest.raises(ValueError, match="test-only"):
        Native(resources, tmp_path, synthetic=True)
