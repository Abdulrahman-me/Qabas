"""Build-time media orchestration, behind injectable providers and the Phase 11 model layer."""

from __future__ import annotations

import copy
from datetime import UTC, datetime
from typing import Any

from app.content.package import content_digest
from app.factory.orchestrator import StageContext
from app.llm.prompts import get_prompt
from app.llm.vision import VisionImage
from app.media import jobs, objects
from app.media.audio import mp3_duration
from app.media.codecs import webp
from app.media.errors import MediaInvalid, MediaNotConfigured
from app.media.policy import POLICY, approved, policy, provider_policy, style_inputs
from app.media.providers import OpenAIImages, OpenAISpeech
from app.media.stage_models import ImagePrompt, VisualAudit
from app.media.types import ImageProvider, NarrationProvider, ScenePreviewer
from app.services.platform.storage import ObjectStorage, sha256_hex


class MediaService:
    def __init__(
        self,
        storage: ObjectStorage,
        *,
        image_provider: ImageProvider | None = None,
        narration_provider: NarrationProvider | None = None,
        previewer: ScenePreviewer | None = None,
        style: dict[str, Any] | None = None,
        image_terms: dict[str, Any] | None = None,
        narration_terms: dict[str, Any] | None = None,
        scene_references: dict[str, Any] | None = None,
    ) -> None:
        self.storage = storage
        self.image_provider = image_provider
        self.narration_provider = narration_provider
        self.previewer = previewer
        self.style = style
        self.image_terms = image_terms
        self.narration_terms = narration_terms
        self.scene_references = scene_references

    def image_inputs(self, ctx: StageContext) -> tuple[ImageProvider, dict[str, Any], dict[str, Any]]:
        path = ctx.settings.media_policy_path or POLICY
        style = self.style if self.style is not None else style_inputs(path)
        terms = self.image_terms if self.image_terms is not None else provider_policy(ctx.settings, "image", path)
        approved(terms["licence"], "image distribution licence")
        if self.image_provider is None:
            self.image_provider = OpenAIImages(ctx.settings)
        return self.image_provider, style, terms

    def scene_inputs(self, ctx: StageContext) -> tuple[dict[str, Any], dict[str, Any]]:
        """Code-rendered output needs reviewed style/rights, not an image-provider key.

        Explicit injected fixture terms remain test-only; actual scene output rights have
        their own policy entry and cannot be authorized by an unrelated provider licence.
        """
        path = ctx.settings.media_policy_path or POLICY
        style = self.style if self.style is not None else style_inputs(path)
        document = policy(path)
        if document.get("fixture_only") and not ctx.settings.is_dev_like:
            raise MediaNotConfigured("synthetic scene rights cannot enable staging or production output")
        terms = (self.image_terms if ctx.settings.is_dev_like and self.image_terms is not None
                 else document.get("scene_outputs", {}))
        if "licence" not in terms:
            raise MediaNotConfigured("code-rendered scene distribution approval is pending")
        approved(terms["licence"], "code-rendered scene distribution licence")
        return style, terms

    async def artwork(
        self, ctx: StageContext, *, name: str, brief: dict[str, Any], content: dict[str, Any], width: int, height: int
    ) -> dict[str, Any]:
        provider, style, terms = self.image_inputs(ctx)
        guide = {k: v for k, v in style.items() if k != "references"}
        regeneration = ctx.run.artifacts.get("media_regeneration")
        inputs = {
            "brief": brief,
            "content": content,
            "style": guide,
            "width": width,
            "height": height,
            "provider_policy": terms,
            "regeneration": regeneration
            if regeneration and (regeneration["scene_id"] == name or regeneration["group"] == brief.get("group"))
            else None,
            "prompts": {p: get_prompt(p).identity() for p in ("factory_image_prompt", "factory_visual_audit")},
        }
        feedback: list[str] = []
        result: dict[str, Any] = {}
        for attempt in range(1, 4):
            attempt_inputs = {**inputs, "attempt": attempt, "audit_feedback": feedback}

            async def execute(
                attempt_inputs: dict[str, Any] = attempt_inputs, attempt: int = attempt
            ) -> dict[str, Any]:
                prompt = await ctx.llm.structured(
                    "factory_image_prompt",
                    attempt_inputs,
                    ledger=ctx.ledger,
                    call_key=f"{ctx.call_key}:{name}:prompt:{attempt}",
                )
                authored = ImagePrompt.model_validate(prompt.data)
                generated = await provider.generate(
                    prompt=authored.prompt,
                    width=width,
                    height=height,
                    references=style.get("references", []),
                    request_key=content_digest(attempt_inputs),
                )
                native_value = generated.parameters.get("native_size", f"{width}x{height}")
                try:
                    native = tuple(int(n) for n in native_value.split("x"))
                    if len(native) != 2:
                        raise ValueError("dimensions")
                    data = webp(generated.data, generated.mime_type, width, height, native=(native[0], native[1]))
                except (ValueError, TypeError, AttributeError) as exc:
                    raise MediaInvalid("image provider did not return valid native dimensions") from exc
                review = await ctx.llm.structured(
                    "factory_visual_audit",
                    {"brief": brief, "content": content, "style": guide, "image_sha256": sha256_hex(data)},
                    images=(VisionImage(data, "image/webp"),),
                    ledger=ctx.ledger,
                    call_key=f"{ctx.call_key}:{name}:audit:{attempt}",
                )
                reported = VisualAudit.model_validate(review.data)
                # Findings are failures even if the model's redundant boolean says "passed". Keep its
                # original report in provenance; the public readiness state must not discard findings.
                audit = VisualAudit(passed=reported.passed and not reported.issues, issues=reported.issues)
                if audit.passed and audit.issues:
                    raise MediaInvalid("a passing visual audit cannot contain unresolved issues")
                record = await objects.stage(
                    self.storage,
                    run_id=ctx.run.id,
                    prefix="images",
                    data=data,
                    mime_type="image/webp",
                    kind="illustration",
                    width=width,
                    height=height,
                    licence=terms["licence"],
                    binding={"inputs_sha256": content_digest(inputs), "name": name},
                    provenance={
                        "provider": generated.provider,
                        "model": generated.model,
                        "provider_policy": terms,
                        "parameters": generated.parameters,
                        "request_id": generated.request_id,
                        "created_at": datetime.now(UTC).isoformat(),
                        "prompt": prompt.prompt,
                        "prompt_text_sha256": sha256_hex(authored.prompt.encode()),
                        "style": style["identity"],
                        "original_sha256": sha256_hex(generated.data),
                        "transformation": {
                            "native_size": list(native),
                            "final_size": [width, height],
                            "format": "webp",
                            "algorithm": "Pillow LANCZOS",
                        },
                        "audit": audit.model_dump(),
                        "auditor_report": reported.model_dump(),
                        "audit_prompt": review.prompt,
                        "audit_model": review.model,
                        "audit_image_sha256": sha256_hex(data),
                    },
                )
                return {"object": record.model_dump(mode="json"), "audit": audit.model_dump(), "attempts": attempt}

            result = await jobs.once(ctx, self.storage, f"{name}:image:{attempt}", attempt_inputs, execute)
            record = objects.MediaObject.model_validate(result["object"])
            await objects.verify(self.storage, record)
            feedback = result["audit"]["issues"]
            if result["audit"]["passed"]:
                break
        return result

    async def speech(self, ctx: StageContext, *, name: str, text: str, language: str) -> dict[str, Any]:
        _reject_scripture(ctx, text)
        terms = (
            self.narration_terms
            if self.narration_terms is not None
            else provider_policy(ctx.settings, "tts", ctx.settings.media_policy_path or POLICY)
        )
        approved(terms["licence"], "narration distribution licence")
        if self.narration_provider is None:
            self.narration_provider = OpenAISpeech(ctx.settings)
        provider = self.narration_provider
        inputs = {
            "name": name,
            "text": text,
            "language": language,
            "provider_policy": terms,
            "text_sha256": sha256_hex(text.encode()),
        }

        async def execute() -> dict[str, Any]:
            generated = await provider.synthesize(text=text, language=language, request_key=content_digest(inputs))
            if generated.mime_type != "audio/mpeg":
                raise MediaInvalid("narration must be MP3")
            duration = mp3_duration(generated.data)
            record = await objects.stage(
                self.storage,
                run_id=ctx.run.id,
                prefix="narration",
                data=generated.data,
                mime_type="audio/mpeg",
                kind="narration",
                licence=terms["licence"],
                binding={"name": name, "language": language, "text_sha256": inputs["text_sha256"]},
                provenance={
                    "provider": generated.provider,
                    "model": generated.model,
                    "provider_policy": terms,
                    "parameters": generated.parameters,
                    "request_id": generated.request_id,
                    "created_at": datetime.now(UTC).isoformat(),
                    "duration_ms": duration,
                    "synthetic_audio": True,
                    "text_sha256": inputs["text_sha256"],
                },
            )
            return {"object": record.model_dump(mode="json"), "duration_ms": duration}

        result = await jobs.once(ctx, self.storage, f"{name}:narration", inputs, execute)
        await objects.verify(self.storage, objects.MediaObject.model_validate(result["object"]))
        return result

    async def aclose(self) -> None:
        for provider in (self.image_provider, self.narration_provider):
            if isinstance(provider, OpenAIImages | OpenAISpeech):
                await provider.aclose()


def service(ctx: StageContext) -> MediaService:
    value = ctx.services.get("media")
    if not isinstance(value, MediaService):
        raise MediaNotConfigured("the build-time media service is not configured")
    return value


def _reject_scripture(ctx: StageContext, text: str) -> None:
    """Evidence stays reference audio; a writer copying a verified quotation cannot send it to TTS."""
    from app.sources.normalize import normalize_ar

    normalized = normalize_ar(text)

    def walk(node: Any) -> None:
        if isinstance(node, dict):
            for key in ("quran", "hadith"):
                payload = node.get(key)
                if isinstance(payload, dict):
                    for field in ("text_uthmani", "text_ar", "translation"):
                        value = payload.get(field)
                        if (
                            isinstance(value, str)
                            and normalize_ar(value)
                            and (normalize_ar(value) == normalized
                                 or (len(normalize_ar(value)) >= 12 and normalize_ar(value) in normalized))
                        ):
                            raise MediaInvalid("verified scripture/quotation cannot be synthesized as narration")
            for child in node.values():
                walk(child)
        elif isinstance(node, list):
            for child in node:
                walk(child)

    walk(ctx.run.artifacts.get("verify_evidence", {}))


def overlay_bundle(
    bundle: dict[str, Any],
    replacements: dict[str, dict[str, Any] | None],
    point_states: dict[str, list[dict[str, Any]]] | None = None,
) -> dict[str, Any]:
    """Replace reserved visual bindings only; do not alter teaching text or evidence."""

    def walk(node: Any) -> Any:
        if isinstance(node, dict):
            image = node.get("image")
            if node.get("kind") == "image" and isinstance(image, dict):
                url = image.get("url", "")
                if url.startswith("mock-asset://factory/"):
                    host = url.split("/", 4)[-1].removesuffix(".webp")
                    if host not in replacements:
                        raise MediaInvalid("a reserved visual has no media-stage binding")
                    return copy.deepcopy(replacements[host])
            updated = {k: walk(v) for k, v in node.items()}
            selected = (point_states or {}).get(node.get("block_id", ""))
            if selected is not None:
                if (
                    node.get("type") != "teach"
                    or len(selected) != len(updated["points"])
                    or (updated.get("visual") or {}).get("kind") not in {"builtin", "scene"}
                ):
                    raise MediaInvalid("point states must match a standard card with a state-driven visual")
                for point, params in zip(updated["points"], selected, strict=True):
                    point["visual_params"] = params
            return updated
        if isinstance(node, list):
            return [walk(v) for v in node]
        return node

    result: dict[str, Any] = walk(bundle)
    return result
