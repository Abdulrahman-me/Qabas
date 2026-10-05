"""Validate exact reviewed receipts, then promote immutable objects before the publication commit (F-114).

Object storage is not transactional. If the DB transaction aborts, only unreferenced immutable objects remain.
There is never a published row whose upload still needs to happen, and a retry never overwrites reviewed bytes.
"""

from __future__ import annotations

import uuid
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.config import Settings
from app.content.package import LessonPackage, content_digest
from app.media import objects, scenes
from app.media.errors import MediaInvalid
from app.media.policy import POLICY, approved, policy, provider_policy, scene_author_inputs, style_inputs
from app.models import MediaAssetRecord, SceneAsset, SceneVersion
from app.services.platform.auth_sessions import utcnow
from app.services.platform.storage import Bucket, ObjectStorage, sha256_hex

REVIEW_ONLY = frozenset({"review_frame", "review_animation"})


def receipts(output: dict[str, Any]) -> list[objects.MediaObject]:
    return [objects.MediaObject.model_validate(row) for row in output.get("media_objects", [])]


def media_urls(value: Any) -> set[str]:
    found: set[str] = set()

    def walk(node: Any) -> None:
        if isinstance(node, dict):
            for key, child in node.items():
                if key in {"narration_audio_url", "pronunciation_audio_url", "asset_url"} and isinstance(child, str):
                    found.add(child)
                elif key == "url" and ("mime_type" in node or "audio" in node):
                    if isinstance(child, str):
                        found.add(child)
                elif key == "audio" and isinstance(child, dict) and isinstance(child.get("url"), str):
                    found.add(child["url"])
                elif key != "sources":
                    walk(child)
        elif isinstance(node, list):
            for child in node:
                walk(child)

    walk(value)
    return found


def narration_text(package: LessonPackage, name: str) -> str:
    raw = package.model_dump(mode="json")
    parts = name.split("/")
    if len(parts) == 2 and parts[0] == "term":
        term = next((t for t in raw["glossary"] if t["term_id"] == parts[1]), None)
        if term is None:
            raise MediaInvalid("pronunciation is bound to a missing term")
        return str(term["text"]["ar"])
    if len(parts) != 4:
        raise MediaInvalid("invalid narration binding")
    language, variant, block_id, beat_id = parts
    try:
        block = next(b for b in raw["variants"][language][variant]["blocks"] if b["block_id"] == block_id)
        beat = next(b for b in block["beats"] if b["beat_id"] == beat_id)
    except (KeyError, StopIteration) as exc:
        raise MediaInvalid("narration is bound to a missing story beat") from exc
    return " ".join("".join(span.get("text", "") for span in s["spans"]) for s in beat["narration"])


async def validate(
    storage: ObjectStorage, settings: Settings, output: dict[str, Any], package: LessonPackage
) -> tuple[list[objects.MediaObject], dict[str, bytes]]:
    records = receipts(output)
    by_url = {record.public_url(storage): record for record in records if record.kind not in REVIEW_ONLY}
    used = media_urls(
        {
            "variants": package.model_dump(mode="json")["variants"],
            "exercises": package.model_dump(mode="json")["exercises"],
            "glossary": package.model_dump(mode="json")["glossary"],
        }
    )
    missing = used - set(by_url)
    if missing:
        raise MediaInvalid("production media URLs lack reviewed immutable receipts")
    raw_by_url = {}
    for record in records:
        raw = await objects.verify(storage, record)
        raw_by_url[record.public_url(storage)] = raw
        if record.kind in REVIEW_ONLY:
            continue
        if record.binding.get("reviewed_package_sha256") != output.get("package_digest"):
            raise MediaInvalid("media receipt is bound to a different reviewed lesson package")
        objects.https(record.public_url(storage))
        approved(record.licence, "media distribution licence")
        provenance = record.provenance
        if record.kind in {"illustration", "narration"}:
            kind = "tts" if record.kind == "narration" else "image"
            terms = provider_policy(settings, kind, settings.media_policy_path or POLICY)
            if (
                provenance.get("provider") != getattr(settings, f"{kind}_provider")
                or provenance.get("model") != terms["model"]
                or record.licence != terms["licence"]
                or provenance.get("provider_policy") != terms
            ):
                raise MediaInvalid("media provider/model/licence differs from the approved policy")
        if record.kind == "illustration":
            style = style_inputs(settings.media_policy_path or POLICY)
            if provenance.get("style") != style["identity"]:
                raise MediaInvalid("illustration belongs to a different/unapproved style reference")
            if not provenance.get("audit", {}).get("passed") or provenance.get("audit", {}).get("issues"):
                raise MediaInvalid("an illustration did not pass its pixel audit")
            if provenance.get("audit_image_sha256") != record.sha256:
                raise MediaInvalid("pixel audit is bound to different image bytes")
        elif record.kind == "narration":
            text = narration_text(package, record.binding["name"])
            if sha256_hex(text.encode()) != record.binding.get("text_sha256"):
                raise MediaInvalid("narration is stale after a teaching-text edit; regenerate and review it")
        elif record.kind == "medallion":
            from app.media.medallions import verify_receipt

            verify_receipt(record, raw)
        elif record.kind == "reference_clip":
            document = policy(settings.media_policy_path or POLICY)
            terms = document["recitation"]
            approved(terms, "reference recording and reciter licence (O-06)")
            if document.get("fixture_only") and not settings.is_dev_like:
                raise MediaInvalid("synthetic recitation approval is not production approval")
            if (record.licence != terms["licence"] or record.binding.get("reciter") != terms.get("reciter")
                    or record.binding.get("reciter_id") != terms.get("reciter_id")
                    or provenance.get("provider") != terms.get("provider")):
                raise MediaInvalid("reference clip differs from the approved recording licence")
            snapshots = [snapshot for rows in output.get("source_records", {}).values() for snapshot in rows]
            matches = [part["meta"] for snapshot in snapshots for part in snapshot.get("parts", [])
                       if part.get("provider") == "qabas_media" and part.get("sha256") == record.sha256]
            if not matches or any(clip["binding"] != {k: v for k, v in record.binding.items()
                                                      if k != "reviewed_package_sha256"}
                                  or clip["licence"] != record.licence
                                  or clip["cut"] != provenance.get("cut")
                                  or clip["url"] != record.public_url(storage) for clip in matches):
                raise MediaInvalid("reference clip lacks matching verified scripture/source provenance")
        elif record.kind in {"scene_manifest", "scene_fallback"}:
            if not provenance.get("normative") or not provenance.get("audit", {}).get("passed"):
                raise MediaInvalid("scene is preview_only or its audit failed")
            if record.kind == "scene_fallback" and provenance.get("audit_image_sha256") != record.sha256:
                raise MediaInvalid("scene fallback pixel audit is bound to different bytes")
            evidence = provenance.get("release_evidence", {})
            if not evidence.get("anchor_visibility_passed") or not evidence.get("fallback_equality_passed"):
                raise MediaInvalid("normative scene lacks anchor/fallback verification evidence")
            entry = policy(settings.media_policy_path or POLICY)["renderer"]
            approved(entry, "normative renderer/release approval")
            if provenance.get("renderer_version") != entry["renderer_version"]:
                raise MediaInvalid("scene renderer differs from the approved build")
            if record.kind == "scene_manifest" and (
                    provenance.get("authoring_references") != scene_author_inputs(settings)["identity"]
                    or provenance.get("style") != style_inputs(settings.media_policy_path or POLICY)["identity"]):
                raise MediaInvalid("scene belongs to different/unapproved authoring/style references")
        else:
            raise MediaInvalid("unsupported production media receipt class")
    for row in output.get("media_scenes", []):
        manifest = row["manifest"]
        record = objects.MediaObject.model_validate(row["object"])
        if objects.encode(manifest) != raw_by_url.get(record.public_url(storage)):
            raise MediaInvalid("scene manifest differs from its reviewed bytes")
        found = scenes.validate(manifest, raw_by_url, publication=True)
        if found:
            raise MediaInvalid("scene publication validation: " + "; ".join(found[:10]))
        expected_ref = {"scene_id": manifest["scene_id"], "version": manifest["version"],
                        "schema_version": manifest["schema_version"], "url": record.public_url(storage),
                        "sha256": record.sha256, "mime_type": record.mime_type,
                        "view_box": manifest["view_box"], "required_capabilities": manifest["required_capabilities"]}
        scenes.bindings(manifest, package.model_dump(mode="json"), expected_ref)
    return records, raw_by_url


async def promote(
    db: AsyncSession,
    storage: ObjectStorage,
    settings: Settings,
    output: dict[str, Any],
    package: LessonPackage,
    *,
    decision_id: uuid.UUID,
    run_id: str,
) -> None:
    records, raw_by_url = await validate(storage, settings, output, package)
    for record in records:
        if record.kind in REVIEW_ONLY:
            continue
        await objects.io(
            storage.put_immutable,
            Bucket.content,
            record.content_key,
            raw_by_url[record.public_url(storage)],
            record.mime_type,
        )
        identity = content_digest({"receipt": record.model_dump(mode="json"), "decision": str(decision_id)})
        if await db.get(MediaAssetRecord, identity) is None:
            db.add(
                MediaAssetRecord(
                    id=identity,
                    content_key=record.content_key,
                    sha256=record.sha256,
                    receipt=record.model_dump(mode="json"),
                    review_decision_id=decision_id,
                )
            )
    for row in output.get("media_scenes", []):
        manifest = row["manifest"]
        record = objects.MediaObject.model_validate(row["object"])
        existing = await db.get(SceneVersion, (manifest["scene_id"], manifest["version"]))
        if existing is not None:
            if existing.sha256 != record.sha256 or existing.status != "published":
                raise MediaInvalid("scene identity is already bound to different/unpublished bytes")
            continue
        scene = SceneVersion(
            scene_id=manifest["scene_id"],
            version=manifest["version"],
            sha256=record.sha256,
            bytes=record.size,
            manifest_url=record.public_url(storage),
            view_box=manifest["view_box"],
            states=manifest["states"],
            required_capabilities=manifest["required_capabilities"],
            anchors=manifest["anchors"],
            fallback_image=row["preview"]["reduced_motion_still"],
            preview=row["preview"],
            audit=row["audit"],
            status="draft",
            published_at=None,
            created_by_run_id=run_id,
        )
        db.add(scene)
        await db.flush()
        for asset in manifest["assets"]:
            db.add(
                SceneAsset(
                    scene_id=manifest["scene_id"],
                    version=manifest["version"],
                    asset_id=asset["asset_id"],
                    url=asset["url"],
                    mime_type=asset["mime_type"],
                    width=asset["width"],
                    height=asset["height"],
                    bytes=asset["bytes"],
                    sha256=asset["sha256"],
                )
            )
        await db.flush()
        scene.status, scene.published_at = "published", utcnow()
    await db.flush()
