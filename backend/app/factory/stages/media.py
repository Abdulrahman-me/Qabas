"""Factory stages 8/8a/8b/9. No provider or storage SDK calls in Factory code."""

from __future__ import annotations

import copy
import json
from dataclasses import replace
from typing import Any

from app.config import BACKEND_DIR
from app.content.package import content_digest
from app.contract import CONTRACT_DIR
from app.contract import models as C
from app.factory.errors import StageOutputInvalid
from app.factory.orchestrator import StageContext, StageResult
from app.factory.stages.common import accepted, approved_plan, parse, require
from app.llm.prompts import get_prompt
from app.llm.vision import VisionImage
from app.media import coverage, jobs, medallions, objects, scenes
from app.media.errors import MediaInvalid, MediaNotConfigured
from app.media.policy import scene_author_inputs
from app.media.recitation import recitation_available, reference_audio
from app.media.service import service
from app.media.stage_models import AuthoredScene, VisualAudit, VisualSelection
from app.services.platform.storage import sha256_hex
from app.sources.store import source_id


def _material(ctx: StageContext) -> dict[str, Any]:
    return {
        "plan": approved_plan(ctx),
        "localized": accepted(ctx, "localize"),
        "claims": accepted(ctx, "verify_evidence"),
        "answer_keys": accepted(ctx, "exercises"),
    }


def _blank(kind: str, alt: str, **kwargs: Any) -> dict[str, Any]:
    return {
        "kind": kind,
        "key": None,
        "version": None,
        "params": None,
        "image": None,
        "scene": None,
        "fallback_image": None,
        "fallback_params": None,
        "alt": alt,
        "overlays": [],
        **kwargs,
    }


async def visuals(ctx: StageContext) -> StageResult:
    media = service(ctx)
    written = accepted(ctx, "write")
    briefs = [
        {
            "brief_id": item["scene_id"],
            "brief": item["visual"]["alt"],
            "figures": written.get("figures", {}).get(item["scene_id"], []),
            "anchors": [],
        }
        for item in written["visuals"]
    ]
    # F-108: a map_place exercise's scene must anchor each labelled target statically (factory 13.8 rules).
    briefs += [{"brief_id": eid, "brief": brief["brief"], "figures": [], "anchors": brief["anchors"]}
               for eid, brief in map_briefs(ctx).items()]
    material = _material(ctx)
    inputs = {
        "briefs": briefs,
        "content": material,
        "builtin_registry": (BACKEND_DIR / "content/visual_registry.yaml").read_text("utf-8"),
        "previous_attempt_issues": ctx.run.previous_issues,
        "prompt": get_prompt("factory_visuals").identity(),
    }

    async def select() -> dict[str, Any]:
        result = await ctx.llm.structured("factory_visuals", inputs, ledger=ctx.ledger, call_key=ctx.call_key)
        return parse(VisualSelection, result.data, "visual_selection_invalid").model_dump(mode="json")

    previous = ctx.run.artifacts.get("media_previous", {}).get("visuals", {}).get("output")
    chosen = (
        {"visuals": previous["selections"], "issues": []}
        if previous
        else await jobs.once(ctx, media.storage, "visual_selection", inputs, select)
    )
    selections = chosen["visuals"]
    ids = [item["brief_id"] for item in selections]
    require(
        ["selector must return every requested brief exactly once"]
        if sorted(ids) != sorted(item["brief_id"] for item in briefs)
        else [],
        "visual_selection_invalid",
    )
    output: dict[str, Any] = {
        "selections": selections,
        "replacements": {"ar": {}, "en": {}},
        "visuals": [],
        "objects": [],
        "issues": [],
        "overlays": {},
        "point_states": {},
    }
    expected_figures = {b["brief_id"]: b["figures"] for b in briefs}
    anchored = {b["brief_id"] for b in briefs if b["anchors"]}
    grouped: dict[str, list[dict[str, Any]]] = {}
    for item in selections:
        grouped.setdefault(item["group"], []).append(item)
        require(
            ["visual selector changed the writer's referenced figures"]
            if item["figures"] != expected_figures[item["brief_id"]]
            else [],
            "visual_selection_invalid",
        )
        require(
            [f"{item['brief_id']}: a hotspot exercise needs a generated scene with static anchors"]
            if item["brief_id"] in anchored and item["kind"] != "scene"
            else [],
            "visual_selection_invalid",
        )
        if item["point_params_json"] is not None:
            try:
                output["point_states"][item["brief_id"]] = [json.loads(p) for p in item["point_params_json"]]
            except ValueError as exc:
                raise StageOutputInvalid("visual_selection_invalid", ["invalid point-state JSON"]) from exc
    for members in grouped.values():
        require(
            ["a visual group cannot mix asset classes or map dimensions"]
            if len({(m["kind"], m["map"]) for m in members}) != 1
            else [],
            "visual_selection_invalid",
        )
    group_artwork = {}
    for item in selections:
        host, kind = item["brief_id"], item["kind"]
        try:
            overlays, receipts = await medallions.resolve(item["figures"], media.storage, ctx.run.id)
            output["objects"].extend(receipts)
        except MediaNotConfigured as exc:
            overlays = {"ar": [], "en": []}
            output["issues"].append({"kind": "image_policy", "scene_id": host, "message": str(exc)})
        output["overlays"][host] = overlays
        if kind == "scene":
            continue
        if kind == "none":
            # Hooks and story beats require a visual; optional slots are checked by the full package schema in QA.
            for language in ("ar", "en"):
                output["replacements"][language][host] = None
            continue
        if kind == "builtin":
            try:
                params = json.loads(item["params_json"])
                visual = C.Visual.model_validate(
                    _blank("builtin", item["alt"]["ar"], key=item["key"], version=1, params=params)
                ).model_dump(mode="json")
            except (ValueError, TypeError) as exc:
                raise StageOutputInvalid("builtin_invalid", [str(exc)]) from exc
            draft = {
                "scene_id": host,
                "origin": "builtin",
                "visual": visual,
                "audit": None,
                "attempts": 0,
                "previews": None,
            }
        else:
            if item["group"] not in group_artwork:
                members = grouped[item["group"]]
                group_artwork[item["group"]] = await media.artwork(
                    ctx,
                    name=members[0]["brief_id"],
                    brief={"group": item["group"], "occurrences": members},
                    content=material,
                    width=1600,
                    height=1200 if item["map"] else 1000,
                )
            result = group_artwork[item["group"]]
            record = objects.MediaObject.model_validate(result["object"])
            visual = _blank("image", item["alt"]["ar"], image=objects.image(record, media.storage))
            draft = {
                "scene_id": host,
                "origin": "generated",
                "visual": visual,
                "audit": result["audit"],
                "attempts": result["attempts"],
                "previews": None,
            }
            output["objects"].append(result["object"])
        visual["overlays"] = overlays["ar"]
        output["visuals"].append(C.DraftVisual.model_validate(draft).model_dump(mode="json"))
        for language in ("ar", "en"):
            output["replacements"][language][host] = {
                **visual,
                "alt": item["alt"][language],
                "overlays": overlays[language],
            }
    return StageResult(output=output, inputs=inputs, notes={"agent_issues": chosen["issues"]})


async def scene_author(ctx: StageContext) -> StageResult:
    media = service(ctx)
    selected = accepted(ctx, "visuals")
    groups: dict[str, list[dict[str, Any]]] = {}
    for item in selected["selections"]:
        if item["kind"] == "scene":
            groups.setdefault(item["group"], []).append(item)
    output: dict[str, Any] = {"scenes": [], "objects": [], "issues": []}
    material = _material(ctx)
    for members in groups.values():
        item = members[0]
        _, style, _ = media.image_inputs(ctx)  # final-quality scene authoring uses approved style/character inputs too
        references = media.scene_references if media.scene_references is not None else scene_author_inputs(ctx.settings)
        regeneration = ctx.run.artifacts.get("media_regeneration")
        identity = content_digest(
            {
                "run": ctx.run.id,
                "group": item["group"],
                "content": material,
                "regeneration": regeneration if regeneration and regeneration["group"] == item["group"] else None,
            }
        )[:20]
        base = {
            "brief": item,
            "occurrences": members,
            "content": material,
            "style": {k: v for k, v in style.items() if k != "references"},
            "scene_id": f"scn_{identity}",
            "version": 1,
            "view_box": {"width": 1600, "height": 1000},
            "schema": json.loads((CONTRACT_DIR / "scene.schema.json").read_text("utf-8")),
            "capabilities": scenes.registry(),
            "authoring_references": references,
            "prompt": get_prompt("factory_scene_author").identity(),
            "visual_audit_feedback": ctx.run.artifacts.get("media_scene_audit_feedback", []),
            "required_anchors": [a for m in members for a in map_briefs(ctx).get(m["brief_id"], {}).get("anchors", [])],
        }
        errors: list[str] = []
        manifest: dict[str, Any] = {}
        scene_objects: list[dict[str, Any]] = []
        for attempt in range(1, 4):
            inputs = {**base, "attempt": attempt, "checker_errors": errors}

            async def execute(
                inputs: dict[str, Any] = inputs,
                identity: str = identity,
                attempt: int = attempt,
                base: dict[str, Any] = base,
                item: dict[str, Any] = item,
                members: list[dict[str, Any]] = members,
            ) -> dict[str, Any]:
                result = await ctx.llm.structured(
                    "factory_scene_author", inputs, ledger=ctx.ledger, call_key=f"{ctx.call_key}:{identity}:{attempt}"
                )
                value = parse(AuthoredScene, result.data, "scene_author_invalid")
                try:
                    authored = json.loads(value.manifest_json)
                    if authored["scene_id"] != base["scene_id"] or authored["version"] != 1:
                        raise ValueError("scene identity differs from the assigned identity")
                    if authored["view_box"] != base["view_box"]:
                        raise ValueError("scene view box differs from the assigned identity")
                    assets = {a["asset_id"]: a for a in authored["assets"]}
                    if len(assets) != len(authored["assets"]) or len({a.asset_id for a in value.artwork}) != len(
                        value.artwork
                    ):
                        raise ValueError("duplicate artwork/asset identifiers")
                    if set(assets) != {a.asset_id for a in value.artwork}:
                        raise ValueError("every generated scene asset requires an artwork brief")
                except (ValueError, KeyError, TypeError) as exc:
                    return {"errors": [str(exc)], "manifest": {}, "objects": []}
                receipts = []
                raw_assets = {}
                failed_assets = []
                for art in value.artwork:
                    built = await media.artwork(
                        ctx,
                        name=f"{identity}:{attempt}:{art.asset_id}",
                        brief={"brief": art.brief, "scene": item,
                               "visual_audit_feedback": base["visual_audit_feedback"]},
                        content=material,
                        width=art.width,
                        height=art.height,
                    )
                    record = objects.MediaObject.model_validate(built["object"])
                    raw_assets[record.public_url(media.storage)] = await objects.verify(media.storage, record)
                    assets[art.asset_id].update(
                        url=record.public_url(media.storage),
                        mime_type=record.mime_type,
                        width=record.width,
                        height=record.height,
                        bytes=record.size,
                        sha256=record.sha256,
                    )
                    receipts.append(built["object"])
                    if not built["audit"]["passed"]:
                        failed_assets.append(art.asset_id)
                found = scenes.validate(authored, raw_assets)
                declared = {a["anchor_id"] for a in authored.get("anchors", [])}
                found += [f"required hotspot anchor {a['anchor_id']} ({a['label']}) is not declared"
                          for a in base["required_anchors"] if a["anchor_id"] not in declared]
                if not found:
                    try:
                        for member in members:
                            scenes.state(authored, json.loads(member["params_json"]))
                            for state in member["point_params_json"] or []:
                                scenes.state(authored, {**json.loads(member["params_json"]), **json.loads(state)})
                    except (MediaInvalid, ValueError, TypeError) as exc:
                        found.append(str(exc))
                return {
                    "manifest": authored,
                    "errors": found,
                    "objects": receipts,
                    "author": result.prompt,
                    "author_model": result.model,
                    "failed_assets": failed_assets,
                }

            result = await jobs.once(ctx, media.storage, f"scene_author:{identity}:{attempt}", inputs, execute)
            manifest, errors, scene_objects = result["manifest"], result["errors"], result["objects"]
            if not errors:
                break
        if errors:
            raise StageOutputInvalid("scene_author_invalid", errors)
        output["objects"].extend(scene_objects)
        for asset in result.get("failed_assets", []):
            output["issues"].append(
                {
                    "kind": "image_policy",
                    "scene_id": item["brief_id"],
                    "message": f"scene artwork {asset} failed its pixel audit after three attempts",
                }
            )
        output["scenes"].append(
            {
                "brief": item,
                "occurrences": members,
                "manifest": manifest,
                "objects": scene_objects,
                "attempts": attempt,
                "author": result["author"],
                "author_model": result["author_model"],
                "authoring_references": references["identity"],
                "style": style["identity"],
            }
        )
    return StageResult(output=output, inputs={"visuals_digest": content_digest(selected)})


async def scene_render(ctx: StageContext) -> StageResult:
    media = service(ctx)
    authored = accepted(ctx, "scene_author")
    selected = accepted(ctx, "visuals")
    output = {
        "visuals": copy.deepcopy(selected["visuals"]),
        "objects": list(selected["objects"]),
        "replacements": copy.deepcopy(selected["replacements"]),
        "scenes": [],
        "issues": [*selected["issues"], *authored["issues"]],
        "point_states": selected["point_states"],
        "pins": {},
    }
    maps = map_briefs(ctx)
    for row in authored["scenes"]:
        if media.previewer is None:
            from app.media.preview_cli import configured

            media.previewer = configured(ctx.settings)
        manifest, brief = row["manifest"], row["brief"]
        inputs = {"authored": row, "content": _material(ctx),
                  "audit_prompt": get_prompt("factory_visual_audit").identity(),
                  "renderer": {"type": type(media.previewer).__name__,
                               "version": getattr(media.previewer, "renderer_version", "inspection/resvg/1"),
                               "executable_sha256": getattr(media.previewer, "executable_sha256", None),
                               "launcher_sha256": getattr(media.previewer, "launcher_sha256", None)}}

        async def execute(
            row: dict[str, Any] = row, manifest: dict[str, Any] = manifest, brief: dict[str, Any] = brief
        ) -> dict[str, Any]:
            assert media.previewer is not None
            raw_assets = {}
            for obj in row["objects"]:
                record = objects.MediaObject.model_validate(obj)
                raw_assets[record.public_url(media.storage)] = await objects.verify(media.storage, record)
            states = coverage.requested(manifest, row["occurrences"], _material(ctx))
            rendered = await media.previewer.render(manifest, raw_assets, states)
            coverage.validate(manifest, states, rendered)
            terms = media.image_inputs(ctx)[2]["licence"]
            receipts = []
            frames: list[dict[str, Any]] = []
            fallbacks: list[dict[str, Any]] = []
            audits = []
            for index in range(0, len(rendered.files), 20):
                batch = rendered.files[index : index + 20]
                audit = await ctx.llm.structured(
                    "factory_visual_audit",
                    {
                        "brief": brief,
                        "content": _material(ctx),
                        "states": [f.state for f in batch],
                        "style": {k: v for k, v in media.image_inputs(ctx)[1].items() if k != "references"},
                    },
                    images=tuple(VisionImage(file.data, file.mime_type) for file in batch),
                    ledger=ctx.ledger,
                    call_key=f"{ctx.call_key}:{manifest['scene_id']}:audit:{index}",
                )
                audits.append(parse(VisualAudit, audit.data, "scene_audit_invalid").model_dump())
            audit_value: dict[str, Any] = {
                "passed": all(a["passed"] and not a["issues"] for a in audits),
                "issues": [value for a in audits for value in a["issues"]],
            }
            if not rendered.normative:
                audit_value["passed"] = False
                audit_value["issues"].append("preview_only: normative Flutter renderer/release evidence is pending")
            for file in rendered.files:
                record = await objects.stage(
                    media.storage,
                    run_id=ctx.run.id,
                    prefix=f"scenes/{manifest['scene_id']}/v{manifest['version']}/fallbacks" if file.reduced_motion
                           else f"scene-previews/{manifest['scene_id']}/v{manifest['version']}/frames",
                    data=file.data,
                    mime_type=file.mime_type,
                    kind="scene_fallback" if file.reduced_motion else "review_frame",
                    width=file.width,
                    height=file.height,
                    licence=terms,
                    binding={
                        "scene_id": manifest["scene_id"],
                        "version": manifest["version"],
                        "state": file.state,
                        "time_ms": file.time_ms,
                        "reduced_motion": file.reduced_motion,
                        "manifest_sha256": content_digest(manifest),
                    },
                    provenance={
                        "renderer_version": rendered.renderer_version,
                        "normative": rendered.normative,
                        "release_evidence": rendered.evidence,
                        "audit": audit_value,
                        "audit_prompt": get_prompt("factory_visual_audit").identity(),
                        "audit_model": audit.model,
                        "audit_image_sha256": sha256_hex(file.data),
                    },
                )
                receipts.append(record.model_dump(mode="json"))
                frame = {
                    "state": file.state,
                    "time_ms": file.time_ms,
                    "reduced_motion": file.reduced_motion,
                    "image": objects.image(record, media.storage),
                }
                (fallbacks if file.reduced_motion else frames).append(frame)
            from app.media.video import webm_info

            animation_width, animation_height, actual_duration = webm_info(rendered.animation)
            if abs(actual_duration - rendered.duration_ms) > 200:
                raise MediaInvalid("scene preview animation duration differs from its bytes")
            animation = await objects.stage(
                media.storage,
                run_id=ctx.run.id,
                prefix="scene-previews",
                data=rendered.animation,
                mime_type="video/webm",
                kind="review_animation",
                licence=terms,
                width=animation_width,
                height=animation_height,
                binding={"scene_id": manifest["scene_id"]},
                provenance={"renderer_version": rendered.renderer_version, "normative": rendered.normative},
            )
            receipts.append(animation.model_dump(mode="json"))
            scene_object = await objects.stage(
                media.storage,
                run_id=ctx.run.id,
                prefix=f"scenes/{manifest['scene_id']}/v{manifest['version']}",
                data=objects.encode(manifest),
                mime_type="application/json",
                kind="scene_manifest",
                licence=terms,
                binding={
                    "scene_id": manifest["scene_id"],
                    "version": manifest["version"],
                    "content_sha256": content_digest(_material(ctx)),
                },
                provenance={
                    "author": row["author"],
                    "author_model": row["author_model"],
                    "authoring_references": row["authoring_references"],
                    "style": row["style"],
                    "renderer_version": rendered.renderer_version,
                    "normative": rendered.normative,
                    "release_evidence": rendered.evidence,
                    "audit": audit_value,
                    "audit_prompt": get_prompt("factory_visual_audit").identity(),
                    "audit_model": audit.model,
                },
            )
            receipts.append(scene_object.model_dump(mode="json"))
            params = json.loads(brief["params_json"])
            fallback = next((file for file in fallbacks if file["state"] == params), None)
            if fallback is None or not frames:
                raise MediaInvalid("preview did not render the exact visual fallback state")
            visual = _blank(
                "scene",
                brief["alt"]["ar"],
                params=params,
                fallback_params=params,
                fallback_image=fallback["image"],
                scene={
                    "scene_id": manifest["scene_id"],
                    "version": manifest["version"],
                    "schema_version": "qabas.scene/1",
                    "url": scene_object.public_url(media.storage),
                    "mime_type": "application/json",
                    "sha256": scene_object.sha256,
                    "view_box": manifest["view_box"],
                    "required_capabilities": manifest["required_capabilities"],
                },
            )
            preview = {
                "frames": frames,
                "fallbacks": fallbacks,
                "reduced_motion_still": fallback["image"],
                "animation": {
                    "url": animation.public_url(media.storage),
                    "mime_type": "video/webm",
                    "width": animation_width,
                    "height": animation_height,
                    "duration_ms": actual_duration,
                },
                "timing": rendered.timing,
                "renderer_version": rendered.renderer_version,
            }
            draft = C.DraftVisual.model_validate(
                {
                    "scene_id": brief["brief_id"],
                    "origin": "generated_scene",
                    "visual": visual,
                    "audit": audit_value,
                    "attempts": row["attempts"],
                    "previews": preview,
                }
            )
            return {
                "vision_passed": all(a["passed"] and not a["issues"] for a in audits),
                "vision_issues": [value for a in audits for value in a["issues"]],
                "draft_visual": draft.model_dump(mode="json"),
                "objects": receipts,
                "scene": {
                    "manifest": manifest,
                    "object": scene_object.model_dump(mode="json"),
                    "preview": preview,
                    "audit": audit_value,
                    "normative": rendered.normative,
                    "evidence": rendered.evidence,
                },
            }

        for audit_attempt in range(1, 4):
            async def current_render(row: dict[str, Any] = row) -> dict[str, Any]:
                return await execute(row=row, manifest=row["manifest"], brief=row["brief"])
            inputs = {**inputs, "authored": row, "audit_attempt": audit_attempt}
            rendered = await jobs.once(ctx, media.storage, f"scene_render:{manifest['scene_id']}",
                                       inputs, current_render)
            if rendered["vision_passed"] or audit_attempt == 3:
                break
            # Concrete pixel feedback re-authors this group only; an unavailable normative renderer is
            # a publication gate, not an excuse to retry a passing visual or choose a different asset class.
            narrowed = {**selected, "selections": row["occurrences"]}
            revised = replace(ctx, run=replace(ctx.run, artifacts={**ctx.run.artifacts,
                "visuals": {"output": narrowed},
                "media_scene_audit_feedback": rendered["vision_issues"]}))
            reauthored = await scene_author(revised)
            row = reauthored.output["scenes"][0]
        rendered["draft_visual"]["attempts"] = max(row["attempts"], audit_attempt)
        output["objects"].extend([*row["objects"], *rendered["objects"]])
        output["scenes"].append(rendered["scene"])
        for member in row["occurrences"]:
            params = json.loads(member["params_json"])
            fallback = next(f for f in rendered["scene"]["preview"]["fallbacks"] if f["state"] == params)
            overlays = selected["overlays"][member["brief_id"]]
            visual = {
                **rendered["draft_visual"]["visual"],
                "params": params,
                "fallback_params": params,
                "fallback_image": fallback["image"],
                "alt": member["alt"]["ar"],
                "overlays": overlays["ar"],
            }
            output["visuals"].append({**rendered["draft_visual"], "scene_id": member["brief_id"], "visual": visual})
            if member["brief_id"] in maps:
                output["pins"][member["brief_id"]] = pins_from_anchors(rendered["scene"]["manifest"],
                                                                       maps[member["brief_id"]])
            for language in ("ar", "en"):
                output["replacements"][language][member["brief_id"]] = {
                    **visual,
                    "alt": member["alt"][language],
                    "overlays": overlays[language],
                }
    return StageResult(
        output=output, inputs={"author_digest": content_digest(authored), "selection_digest": content_digest(selected)}
    )


async def narration(ctx: StageContext) -> StageResult:
    media = service(ctx)
    localized = copy.deepcopy(accepted(ctx, "localize"))
    output: dict[str, Any] = {"localized": localized, "objects": [], "issues": []}
    if ctx.settings.media_narration_enabled:
        for language in ("ar", "en"):
            for variant, content in localized[language]["variants"].items():
                for block in content["blocks"]:
                    if block["type"] != "story":
                        continue
                    for beat in block["beats"]:
                        # Only the explicit narration field; never quote/evidence/scripture spans.
                        sentences = beat["narration"]
                        text = " ".join("".join(span.get("text", "") for span in s["spans"]) for s in sentences)
                        if not text.strip():
                            continue
                        name = f"{language}/{variant}/{block['block_id']}/{beat['beat_id']}"
                        result = await media.speech(ctx, name=name, text=text, language=language)
                        record = objects.MediaObject.model_validate(result["object"])
                        beat["narration_audio_url"] = record.public_url(media.storage)
                        output["objects"].append(result["object"])
    if ctx.settings.media_pronunciation_enabled:
        for term in accepted(ctx, "glossary")["terms"]:
            result = await media.speech(ctx, name=f"term/{term['term_id']}", text=term["text_ar"], language="ar")
            output.setdefault("pronunciation", {})[term["term_id"]] = objects.MediaObject.model_validate(
                result["object"]
            ).public_url(media.storage)
            output["objects"].append(result["object"])
    await reference_recitation(ctx, media, output)
    return StageResult(
        output=output,
        inputs={
            "localized_digest": content_digest(accepted(ctx, "localize")),
            "narration_enabled": ctx.settings.media_narration_enabled,
            "pronunciation_enabled": ctx.settings.media_pronunciation_enabled,
            "recitation_available": recitation_available(ctx),
        },
    )


async def reference_recitation(ctx: StageContext, media: Any, output: dict[str, Any]) -> None:
    """Factory 13.1 stage 9, Qur'an part: licensed reference audio and word timings, never TTS (D-155).

    * Each ``recite_verse`` gets an exact cut of the approved reciter's licensed recording; its audio and its own
      activity source (the verified segment bundle carrying that clip) replace the reserved placeholders.
    * Each displayed single-ayah Qur'an evidence gets the whole-ayah clip with word timings. The scripture source
      identity binds its audio, so the evidence's source id changes; ``rebinds`` maps old → new and the package is
      rebound consistently in QA (claims, blocks, exercises, sources). Multi-ayah passages stay without audio
      (the capability timings identify one ayah).
    Without an approved licence and library (O-06) nothing is attached: recitation activities were never offered
    and evidence audio stays null, which the contract allows.
    """
    output.update(recitations={}, rebinds={}, scripture={})
    if not recitation_available(ctx):
        return
    make_tools = ctx.services.get("sources")
    if make_tools is None:
        raise MediaNotConfigured("reference recitation needs the source tools")
    tools = make_tools()
    try:
        localized = output["localized"]
        for record in accepted(ctx, "exercises")["exercises"]:
            binding = (record.get("media") or {}).get("recitation")
            if not binding:
                continue
            word_range = tuple(binding["word_range"]) if binding["word_range"] else None
            arabic, _, receipt = await reference_audio(ctx, media.storage, mushaf=tools.mushaf, tools=tools,
                                                       surah=binding["surah"], ayah=binding["ayah"],
                                                       word_range=word_range)
            identity = source_id(arabic.source)
            audio = arabic.evidence.quran.audio.model_dump(mode="json")
            output["recitations"][record["exercise_id"]] = {"audio": audio, "source_id": identity}
            output["scripture"][identity] = _scripture(arabic)
            output["objects"].append(receipt.model_dump(mode="json"))
            for language in ("ar", "en"):
                payload = localized[language]["exercises"][record["exercise_id"]]["exercise"]["payload"]
                payload.update(audio=audio, source_id=identity)
        candidates = {c["source_id"]: c for c in accepted(ctx, "retrieve")["candidates"]}
        used = _evidence_ids(localized)
        for item in accepted(ctx, "verify_evidence")["evidence"]:
            quran = (item["evidence"]["ar"] or {}).get("quran")
            if item["kind"] != "quran" or item["source_id"] not in used or quran is None:
                continue
            if quran["ayah_start"] != quran["ayah_end"]:
                output["issues"].append({"kind": "validation", "scene_id": None, "message":
                                         f"{item['source_id']}: multi-ayah evidence has no reference audio"})
                continue
            from app.factory.evidence import load_record
            chain = [load_record(r) for r in candidates[item["source_id"]]["records"][1:]]
            translations = tuple(r for r in chain if r.provider == "quranenc")
            arabic, english, receipt = await reference_audio(ctx, media.storage, mushaf=tools.mushaf, tools=tools,
                                                             surah=quran["surah"], ayah=quran["ayah_start"],
                                                             word_range=None, translations=translations)
            identity = source_id(arabic.source)
            output["rebinds"][item["source_id"]] = {
                "source_id": identity, "ar": arabic.evidence.model_dump(mode="json"),
                "en": (english or arabic).evidence.model_dump(mode="json")}
            output["scripture"][identity] = _scripture(arabic)
            output["objects"].append(receipt.model_dump(mode="json"))
        for language in ("ar", "en"):
            localized[language] = rebind(localized[language], output["rebinds"], language)
    finally:
        await tools.aclose()


def _scripture(verified: Any) -> dict[str, Any]:
    from app.factory.evidence import dump_record, public_source
    return {"source": public_source(verified.source),
            "records": [dump_record(r) for r in (verified.source, *verified.records)]}


def _evidence_ids(node: Any) -> set[str]:
    found: set[str] = set()

    def walk(value: Any) -> None:
        if isinstance(value, dict):
            if "evidence_id" in value and "kind" in value:
                found.add(value["evidence_id"])
            for child in value.values():
                walk(child)
        elif isinstance(value, list):
            for child in value:
                walk(child)

    walk(node)
    return found


def rebind(node: Any, rebinds: dict[str, dict[str, Any]], language: str | None) -> Any:
    """Replace verified evidence objects by their audio-bearing bundle and rename the source id everywhere it is
    cited (``evidence_id``/``source_id``/``source_ids``). Ids are hashes, so exact matches cannot collide."""
    if not rebinds:
        return node
    renamed = {old: new["source_id"] for old, new in rebinds.items()}

    def walk(value: Any, lang: str | None) -> Any:
        if isinstance(value, dict):
            if value.get("evidence_id") in rebinds and "kind" in value and lang in ("ar", "en"):
                return copy.deepcopy(rebinds[value["evidence_id"]][lang])
            out = {}
            for key, child in value.items():
                child_lang = key if key in ("ar", "en") else lang
                if key in ("evidence_id", "source_id") and isinstance(child, str):
                    out[key] = renamed.get(child, child)
                elif key == "source_ids" and isinstance(child, list):
                    out[key] = [renamed.get(s, s) if isinstance(s, str) else s for s in child]
                else:
                    out[key] = walk(child, child_lang)
            return out
        if isinstance(value, list):
            return [walk(child, lang) for child in value]
        return value

    return walk(node, language)


def map_briefs(ctx: StageContext) -> dict[str, dict[str, Any]]:
    """map_place exercises authored by the Exercise Designer: their scene brief and labelled targets."""
    if "exercises" not in ctx.run.artifacts:
        return {}
    found = {}
    for record in accepted(ctx, "exercises")["exercises"]:
        brief = (record.get("media") or {}).get("map")
        if brief:
            found[record["exercise_id"]] = {
                "brief": brief["brief"], "targets": brief["targets"],
                "anchors": [{"anchor_id": t["target_id"], "label": t["label"]} for t in brief["targets"]]}
    return found


def pins_from_anchors(manifest: dict[str, Any], brief: dict[str, Any]) -> list[dict[str, Any]]:
    """Hotspot pins at the authored static anchors (percent of the view box, tap radius at most 25 %)."""
    anchors = {a["anchor_id"]: a for a in manifest["anchors"]}
    width, height = manifest["view_box"]["width"], manifest["view_box"]["height"]
    pins = []
    for target in brief["targets"]:
        anchor = anchors.get(target["target_id"])
        if anchor is None:
            raise MediaInvalid(f"hotspot target {target['target_id']} has no static anchor")
        pins.append({"pin_id": target["pin_id"], "anchor_id": anchor["anchor_id"],
                     "x_pct": round(100 * anchor["x"] / width, 4), "y_pct": round(100 * anchor["y"] / height, 4),
                     "radius_pct": min(25.0, round(100 * anchor["radius"] / width, 4))})
    return pins
