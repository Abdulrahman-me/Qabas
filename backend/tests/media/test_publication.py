from __future__ import annotations

from pathlib import Path
from typing import Any

import pytest
import yaml
from sqlalchemy import func, select

from app.config import BACKEND_DIR, Settings
from app.content.package import LessonPackage
from app.contract import FIXTURES_DIR
from app.contract import models as C
from app.errors import ApiError
from app.factory import regenerate
from app.factory.gate2 import ScriptureAuthority, decide_gate2
from app.factory.orchestrator import gate_digest
from app.llm.fake import FakeLLMClient
from app.media import objects
from app.media.policy import style_inputs
from app.media.service import MediaService
from app.media.types import GeneratedMedia
from app.models import MediaAssetRecord, ReviewDecision
from app.runtime import Resources
from app.services.platform.storage import Bucket, StorageError, sha256_hex
from tests.factory import pipeline_support as P
from tests.factory.support import drive
from tests.factory.test_pipeline import Harness
from tests.media.test_core import picture

pytestmark = pytest.mark.integration


class Images:
    calls = 0

    async def generate(self, **kwargs: Any) -> GeneratedMedia:
        self.calls += 1
        return GeneratedMedia(picture(kwargs["width"], kwargs["height"]), "image/webp", "openai", "synthetic-image")


def selected(data: dict[str, Any]) -> dict[str, Any]:
    value = P.visual_selection(data)
    for item in value["visuals"]:
        item.update(kind="image", key=None, image_brief="Neutral synthetic geometry", group="shared_setting")
    return value


@pytest.fixture
async def built(fresh_curriculum: Any, tmp_path: Path, request: Any) -> Any:
    approval = {"status": "approved", "approved_by": "synthetic test only", "approved_on": "2026-01-01"}
    path = tmp_path / "test-media-policy.yaml"
    style = {**approval, "references": []}
    for name, file in (("guide", "style.md"), ("characters", "characters.md")):
        relative = f"tests/media/fixtures/{file}"
        style[name] = {"path": relative, "sha256": sha256_hex((BACKEND_DIR / relative).read_bytes())}
    terms = {**approval, "licence": approval, "model": "synthetic-image", "size": "1536x1024"}
    scene_references = {**approval, "design_tokens": style["guide"], "examples": [
        {"path": str((FIXTURES_DIR / "scenes" / name).relative_to(BACKEND_DIR)),
         "sha256": sha256_hex((FIXTURES_DIR / "scenes" / name).read_bytes())}
        for name in ("asset_positive.scene.json", "scn_test_desert_well.v2.scene.json")]}
    path.write_text(
        yaml.safe_dump(
            {
                "schema": "qabas.media_policy/1",
                "fixture_only": True,
                "style": style,
                "providers": {"image": {"openai": terms}},
                "scene_author": scene_references,
                "renderer": {**approval, "renderer_version": "qabas_scene synthetic/1"},
            }
        )
    )
    settings: Settings = fresh_curriculum[1].model_copy(
        update={"media_policy_path": path, "image_provider": "openai", "cdn_base_url": "https://cdn.qabas.app/media"}
    )
    resources = Resources.create(settings)
    images = Images()

    def selection(data: dict[str, Any]) -> dict[str, Any]:
        value = selected(data)
        if getattr(request, "param", "image") in {"scene", "scene_retry", "scene_publish"}:
            for item in value["visuals"]:
                item.update(kind="scene", params_json='{"beat": 0, "focus": -1}')
        return value

    def authored(data: dict[str, Any]) -> dict[str, Any]:
        import json

        manifest = json.loads((FIXTURES_DIR / "scenes/asset_positive.scene.json").read_text("utf-8"))
        manifest.update(
            scene_id=data["scene_id"],
            version=data["version"],
            preview={"frames_ms": [0, 500], "states": [{"beat": 0, "focus": -1}]},
        )
        return {
            "manifest_json": json.dumps(manifest),
            "artwork": [
                {
                    "asset_id": a["asset_id"],
                    "brief": "Neutral synthetic geometry",
                    "width": a["width"],
                    "height": a["height"],
                }
                for a in manifest["assets"]
            ],
        }

    frame_audits = 0
    def audit(data: dict[str, Any]) -> dict[str, Any]:
        nonlocal frame_audits
        if "states" in data:
            frame_audits += 1
            if getattr(request, "param", "image") == "scene_retry" and frame_audits == 1:
                return {"passed": False, "issues": ["Synthetic frame composition needs correction"]}
        return {"passed": True, "issues": []}
    llm = FakeLLMClient(
        P.script(
            factory_visuals=selection,
            factory_scene_author=authored,
            factory_image_prompt={"prompt": "Neutral synthetic geometry, no text"},
            factory_visual_audit=audit,
        )
    )
    tools = P.SyntheticTools(translations=P.manifest(tmp_path))
    h = Harness(resources, llm, tools)
    from dataclasses import replace

    from app.media.preview import InspectionPreviewer
    class SyntheticNormativePreviewer(InspectionPreviewer):
        async def render(self, *args: Any, **kwargs: Any) -> Any:
            inspected = await super().render(*args, **kwargs)
            # Explicit test-only release evidence. Never selected by application code or committed policy.
            return replace(inspected, normative=True, renderer_version="qabas_scene synthetic/1",
                           timing={"build_raster_p95_ms": 1, "first_frame_ms": 10, "device": "synthetic fixture"},
                           evidence={"anchor_visibility_passed": True, "fallback_equality_passed": True})

    media = MediaService(
        resources.storage,
        image_provider=images,
        image_terms=terms,
        style=style_inputs(path),
        previewer=SyntheticNormativePreviewer() if getattr(request, "param", "image") == "scene_publish"
                  else InspectionPreviewer(),
    )
    h.orchestrator.services = {"sources": lambda: tools, "media": media}
    try:
        run_id, outcomes = await h.to_gate2()
        run = await h.load(run_id)
        assert run.status == "awaiting_gate2", (outcomes, run.error)
        yield resources, h, run_id, images, tmp_path
    finally:
        await resources.close()


async def approve(resources: Resources, h: Harness, run_id: str, tmp_path: Path) -> Any:
    run = await h.load(run_id)
    try:
        return await decide_gate2(
            resources.sessionmaker,
            resources.settings,
            h.dispatcher,
            run_id=run_id,
            reviewer_id="usr_factory_reviewer",
            body=C.Gate2(
                decision="approve",
                review_digest=run.review_digest or "0" * 64,
                sentence_edits=[],
                exercise_removals=[],
                reason=None,
            ),
            authority=ScriptureAuthority(mushaf=P.synthetic.mushaf(), translations=P.manifest(tmp_path)),
            storage=resources.storage,
        )
    except ApiError as exc:
        if exc.details:
            exc.add_note(str(exc.details))
        raise


async def test_shared_images_publish_exact_reviewed_bytes_once_and_approval_publishes(built: Any) -> None:
    resources, h, run_id, provider, tmp_path = built
    before = await h.load(run_id)
    output = before.artifacts["qa"]["output"]
    assert provider.calls == 1  # three occurrences share one setting and one audited image
    for raw in output["media_objects"]:
        record = objects.MediaObject.model_validate(raw)
        assert not resources.storage.exists(Bucket.content, record.content_key)
    result = await approve(resources, h, run_id, tmp_path)
    assert result["status"] == "published"
    async with resources.sessionmaker() as db:
        assert await db.scalar(select(func.count()).select_from(MediaAssetRecord)) == 1
    for raw in output["media_objects"]:
        record = objects.MediaObject.model_validate(raw)
        assert await objects.verify(resources.storage, record, bucket=Bucket.content) == picture()
    with pytest.raises(ApiError, match="Gate 2"):
        await approve(resources, h, run_id, tmp_path)
    assert provider.calls == 1


async def test_upload_failure_does_not_publish_or_record_approval(built: Any, monkeypatch: Any) -> None:
    resources, h, run_id, _, tmp_path = built
    real = resources.storage.put_immutable

    def unavailable(bucket: Bucket, *args: Any, **kwargs: Any) -> Any:
        if bucket == Bucket.content:
            raise StorageError("synthetic upload failure")
        return real(bucket, *args, **kwargs)

    monkeypatch.setattr(resources.storage, "put_immutable", unavailable)
    with pytest.raises(ApiError, match="cannot be approved"):
        await approve(resources, h, run_id, tmp_path)
    assert (await h.load(run_id)).status == "awaiting_gate2"
    async with resources.sessionmaker() as db:
        assert await db.scalar(select(func.count()).select_from(MediaAssetRecord)) == 0
        assert await db.scalar(select(func.count()).select_from(ReviewDecision).where(ReviewDecision.gate == 2)) == 0


async def test_db_failure_after_promotion_leaves_only_unreferenced_immutable_objects(
    built: Any, monkeypatch: Any
) -> None:
    resources, h, run_id, provider, tmp_path = built
    from app.factory import gate2

    real = gate2.publish

    async def failure(*args: Any, **kwargs: Any) -> None:
        raise RuntimeError("synthetic DB failure")

    monkeypatch.setattr(gate2, "publish", failure)
    with pytest.raises(RuntimeError, match="DB failure"):
        await approve(resources, h, run_id, tmp_path)
    run = await h.load(run_id)
    assert run.status == "awaiting_gate2"
    async with resources.sessionmaker() as db:
        assert await db.scalar(select(func.count()).select_from(MediaAssetRecord)) == 0
    record = objects.MediaObject.model_validate(run.artifacts["qa"]["output"]["media_objects"][0])
    assert resources.storage.exists(Bucket.content, record.content_key)
    monkeypatch.setattr(gate2, "publish", real)
    assert (await approve(resources, h, run_id, tmp_path))["status"] == "published"
    assert provider.calls == 1


async def test_regeneration_preserves_old_draft_then_requires_a_new_digest(built: Any) -> None:
    resources, h, run_id, provider, _ = built
    before = await h.load(run_id)
    old_digest = before.review_digest
    await regenerate.request(
        resources.sessionmaker,
        h.dispatcher,
        run_id=run_id,
        scene_id="b_hook",
        reviewer_id="usr_factory_reviewer",
        reason="Synthetic new composition",
    )
    running = await h.load(run_id)
    assert running.status == "running" and running.review_digest is None
    assert running.artifacts["media_revisions"][-1]["review_digest"] == old_digest
    outcomes = await drive(h.orchestrator, h.dispatcher)
    after = await h.load(run_id)
    assert outcomes[-1] == "gate" and after.review_digest != old_digest
    assert provider.calls == 2
    assert (
        LessonPackage.model_validate(after.artifacts["qa"]["output"]["package"]).digest()
        == after.artifacts["qa"]["output"]["package_digest"]
    )
    assert after.review_digest == gate_digest("awaiting_gate2", after)


@pytest.mark.parametrize("built", ["scene"], indirect=True)
async def test_full_asset_bearing_scene_reaches_review_but_inspection_cannot_publish_it(built: Any) -> None:
    resources, h, run_id, provider, tmp_path = built
    run = await h.load(run_id)
    output = run.artifacts["qa"]["output"]
    assert provider.calls == 1 and len(output["media_scenes"]) == 1
    scene = output["media_scenes"][0]
    assert scene["manifest"]["assets"] and scene["manifest"]["anchors"]
    assert not scene["normative"] and not scene["audit"]["passed"]
    assert scene["preview"]["animation"]["mime_type"] == "video/webm"
    assert scene["preview"]["fallbacks"][0]["state"] == {"beat": 0, "focus": -1}
    assert any(issue["severity"] == "blocker" for issue in run.qa_report["issues"])
    with pytest.raises(ApiError, match="cannot be approved"):
        await approve(resources, h, run_id, tmp_path)
    for raw in output["media_objects"]:
        assert not resources.storage.exists(Bucket.content, raw["content_key"])


@pytest.mark.parametrize("built", ["scene_retry"], indirect=True)
async def test_failed_scene_pixels_reauthor_with_concrete_feedback_instead_of_downgrading(built: Any) -> None:
    _, h, run_id, provider, _ = built
    run = await h.load(run_id)
    assert provider.calls == 2
    authored_calls = [data for name, data in h.llm.calls if name == "factory_scene_author"]
    assert len(authored_calls) == 2
    assert "Synthetic frame composition needs correction" in authored_calls[-1]["visual_audit_feedback"]
    assert run.artifacts["qa"]["output"]["media_scenes"][0]["manifest"]["assets"]


@pytest.mark.parametrize("built", ["scene_publish"], indirect=True)
async def test_scene_promotion_publishes_children_before_parent_and_keeps_review_frames_private(
    built: Any, monkeypatch: Any,
) -> None:
    from app.media import scenes
    from app.models import SceneAsset, SceneVersion
    resources, h, run_id, _, tmp_path = built
    original = scenes.registry()
    for item in original["capabilities"]:
        item.update(status="released", release_evidence={"synthetic_test_only": True})
    monkeypatch.setattr(scenes, "registry", lambda: original)
    run = await h.load(run_id)
    output = run.artifacts["qa"]["output"]
    result = await approve(resources, h, run_id, tmp_path)
    assert result["status"] == "published"
    manifest = output["media_scenes"][0]["manifest"]
    async with resources.sessionmaker() as db:
        version = await db.get(SceneVersion, (manifest["scene_id"], 1))
        assert version is not None and version.status == "published"
        assert await db.scalar(select(func.count()).select_from(SceneAsset).where(
            SceneAsset.scene_id == manifest["scene_id"])) == len(manifest["assets"])
    for raw in output["media_objects"]:
        if raw["kind"] in {"review_frame", "review_animation"}:
            assert not resources.storage.exists(Bucket.content, raw["content_key"])
        else:
            await objects.verify(resources.storage, objects.MediaObject.model_validate(raw), bucket=Bucket.content)
