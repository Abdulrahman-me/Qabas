"""Stage 5 ``write`` — Lesson Writer and Story Narrator (factory §13.1 stage 5, §13.2 writing rules).

The Writer composes the ONE lesson along the approved arc in Arabic, for every track the unit serves, from the
supported claims and the verified evidence registry. Its output is typed plain text; code checks the structural
rules (shared skeleton, sentence roles and claim links, evidence ids and budget, story kinds, arc coverage and
technique fit, exercise slots = the plan's exercise budget) and composes the contract blocks: verified evidence is
inserted by id, sentence sources come from the claims, and every visual host gets a placeholder (D-129).

There is no approved gold lesson or ``content/style_guide.md`` yet (F-104): the prompt carries the handoff's
writing rules, and the run records that its few-shot examples were absent.
"""

from __future__ import annotations

from typing import Any

from sqlalchemy import select

from app.factory import compose
from app.factory.orchestrator import StageContext, StageResult
from app.factory.stage_models import WBeat, WriterDraft, WSentence, WVariant
from app.factory.stages.common import accepted, approved_plan, duplicates, parse, require
from app.models import Unit

STORY_TECHNIQUES = {"story", "scenario"}
PREDICT_TECHNIQUES = {"prediction", "reflection"}
MAX_CONTENT_EVIDENCE = 3


def variants_for(tracks: list[str]) -> list[str]:
    return [v for v in ("explorer", "new_muslim") if v in tracks]


def _sentences(variant: WVariant) -> list[WSentence]:
    found: list[WSentence] = []
    for block in variant.blocks:
        if block.type == "paragraph":
            found += block.sentences
        elif block.type == "teach":
            found += [p.sentence for p in block.points]
        elif block.type == "story":
            found += [s for beat in block.beats for s in beat.narration]
    return found


def _evidence_keys(variant: WVariant) -> list[str]:
    keys: list[str] = []
    for block in variant.blocks:
        if block.type == "evidence" or (block.type == "teach" and block.evidence_id):
            keys.append(block.evidence_id or "")
        elif block.type == "story":
            keys += [b.quote_evidence_id for b in block.beats if b.quote_evidence_id]
    return keys


def check(draft: WriterDraft, plan: dict[str, Any], tracks: list[str], supported: dict[str, dict[str, Any]],
          registry: dict[str, dict[str, Any]]) -> list[str]:
    errors: list[str] = []
    wanted = variants_for(tracks)
    names: list[str] = [v.variant for v in draft.variants]
    if sorted(names) != sorted(wanted) or duplicates(names):
        errors.append(f"write exactly the variants {wanted} (one each); got {names}")
        return errors
    skeletons: dict[str, list[tuple[str, str]]] = {v.variant: [(b.block_id, b.type) for b in v.blocks]
                                                  for v in draft.variants}
    reference = skeletons[wanted[0]]
    for name, skeleton in skeletons.items():
        if skeleton != reference:
            errors.append(f"{name}: every variant shares one block skeleton (ids, types, order)")
    roles: dict[str, tuple[str, list[str]]] = {}
    figures: dict[str, list[str]] = {}
    concepts = set(plan["introduced_concept_ids"]) | set(plan["prerequisite_concept_ids"])
    for variant in draft.variants:
        where = variant.variant
        errors += [f"{where}: duplicate block id {b}" for b in duplicates([b.block_id for b in variant.blocks])]
        sentences = _sentences(variant)
        errors += [f"{where}: duplicate sentence id {s}" for s in duplicates([s.sentence_id for s in sentences])]
        for item in sentences:
            seen = roles.setdefault(item.sentence_id, (item.role, sorted(item.claim_ids)))
            if seen != (item.role, sorted(item.claim_ids)):
                errors.append(f"{item.sentence_id}: the same sentence id keeps one role and claim links in "
                              "every variant")
            if (item.role == "claim") != bool(item.claim_ids):
                errors.append(f"{item.sentence_id}: a claim sentence links supported claims; other roles link none")
            for claim_id in item.claim_ids:
                if claim_id not in supported:
                    errors.append(f"{item.sentence_id}: {claim_id} is not a supported claim")
        keys = _evidence_keys(variant)
        for key in keys:
            if key not in registry:
                errors.append(f"{where}: evidence {key} is not in the verified evidence registry")
        if len(set(keys)) > MAX_CONTENT_EVIDENCE:
            errors.append(f"{where}: at most {MAX_CONTENT_EVIDENCE} displayed evidence items (found {len(set(keys))})")
        hooks = [b for b in variant.blocks if b.type == "hook"]
        summaries = [b for b in variant.blocks if b.type == "teach" and b.style == "summary"]
        if len(hooks) > 1 or len(summaries) > 1:
            errors.append(f"{where}: at most one hook and one summary card")
        for block in variant.blocks:
            if block.type == "teach" and block.style == "summary" and not 2 <= len(block.points) <= 5:
                errors.append(f"{block.block_id}: a summary card has 2-5 points")
            if block.type == "predict":
                errors += [f"{block.block_id}: duplicate option id {o}"
                           for o in duplicates([o.option_id for o in block.options])]
            if block.type == "story":
                errors += _story(block.block_id, block.sourced, block.origin_title, block.beats)
                for beat in block.beats:
                    host = f"{block.block_id}.{beat.beat_id}"
                    if figures.setdefault(host, beat.figures) != beat.figures:
                        errors.append(f"{host}: referenced figures must stay the same across tracks")
        slots = [b for b in variant.blocks if b.type == "exercise_slot"]
        if len(slots) != plan["exercise_budget"]:
            errors.append(f"{where}: place exactly the plan's exercise_budget ({plan['exercise_budget']}) "
                          f"exercise slots (found {len(slots)})")
        for topic in variant.completion.review_topics:
            unknown = set(topic.concept_ids) - concepts
            if unknown:
                errors.append(f"{where}/{topic.topic_id}: review topics name only concepts this lesson teaches or "
                              f"requires (not {sorted(unknown)})")
    errors += _arc(draft, plan, draft.variants[0])
    return errors


def _story(block_id: str, sourced: bool, origin_title: str | None, beats: list[WBeat]) -> list[str]:
    errors = [f"{block_id}: duplicate beat id {b}" for b in duplicates([b.beat_id for b in beats])]
    for beat in beats:
        if beat.quote_meaning and not beat.quote_evidence_id:
            errors.append(f"{block_id}/{beat.beat_id}: quote_meaning requires a quote")
        if not sourced:
            if beat.quote_evidence_id:
                errors.append(f"{block_id}/{beat.beat_id}: a teaching scenario has no quotes")
            for item in beat.narration:
                if item.role == "claim":
                    errors.append(f"{item.sentence_id}: a teaching scenario's narration asserts nothing")
    if sourced and not origin_title:
        errors.append(f"{block_id}: a sourced story names its origin")
    if not sourced and origin_title:
        errors.append(f"{block_id}: a teaching scenario has no origin")
    return errors


def _arc(draft: WriterDraft, plan: dict[str, Any], variant: WVariant) -> list[str]:
    errors: list[str] = []
    steps = [s["step_id"] for s in plan["lesson_arc"]["steps"]]
    technique = {s["step_id"]: s["technique"] for s in plan["lesson_arc"]["steps"]}
    mapped = [row.step_id for row in draft.arc_map]
    if mapped != steps:
        errors.append(f"arc_map lists every approved arc step once, in order {steps} (got {mapped})")
    position = {b.block_id: (i, b) for i, b in enumerate(variant.blocks)}
    seen: list[str] = []
    last = -1
    for row in draft.arc_map:
        for block_id in row.block_ids:
            if block_id not in position:
                errors.append(f"arc_map {row.step_id}: unknown block {block_id}")
                continue
            if block_id in seen:
                errors.append(f"arc_map {row.step_id}: block {block_id} realises only one arc step")
            seen.append(block_id)
            index, block = position[block_id]
            if index < last:
                errors.append(f"arc_map {row.step_id}: blocks follow the arc order")
            last = max(last, index)
            kind = technique.get(row.step_id)
            if block.type == "story" and kind not in STORY_TECHNIQUES:
                errors.append(f"{block_id}: a story block belongs to a story or scenario step")
            if block.type == "predict" and kind not in PREDICT_TECHNIQUES:
                errors.append(f"{block_id}: a predict block belongs to a prediction or reflection step")
            if block.type == "teach" and block.style == "summary" and kind != "takeaway":
                errors.append(f"{block_id}: a summary card belongs to the takeaway step")
    unmapped = [b for b in position if b not in seen]
    if unmapped:
        errors.append(f"blocks outside the arc: {unmapped} (nothing is added outside the approved arc)")
    return errors


def compose_variant(run_id: str, variant: WVariant, supported: dict[str, dict[str, Any]],
                    registry: dict[str, dict[str, Any]]) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    """Arabic contract blocks (exercise slots kept as ``exercise`` blocks without an id yet) and draft visuals."""
    visuals: list[dict[str, Any]] = []

    def sources_of(claim_ids: list[str]) -> list[str]:
        return sorted({s for c in claim_ids for s in supported[c]["supporting_sources"]})

    def sent(item: WSentence) -> dict[str, Any]:
        return compose.sentence(item.sentence_id, item.text, sources_of(item.claim_ids))

    def visual(host: str, brief: str) -> dict[str, Any]:
        value = compose.placeholder_visual(run_id, host, brief)
        visuals.append(compose.draft_visual(host, value))
        return value

    def evidence(key: str) -> dict[str, Any]:
        value: dict[str, Any] = registry[key]["evidence"]["ar"]
        return value

    blocks: list[dict[str, Any]] = []
    for block in variant.blocks:
        common = {"block_id": block.block_id, "type": block.type}
        if block.type == "hook":
            blocks.append({**common, "situation": compose.span(block.situation),
                           "question": compose.span(block.question), "cta": block.cta,
                           "visual": visual(block.block_id, block.visual_brief)})
        elif block.type == "predict":
            blocks.append({**common, "prompt": compose.span(block.prompt), "reveal": compose.span(block.reveal),
                           "options": [{"option_id": o.option_id, "spans": compose.span(o.text)}
                                       for o in block.options],
                           "visual": visual(block.block_id, block.visual_brief) if block.visual_brief else None})
        elif block.type == "story":
            beats: list[dict[str, Any]] = []
            story_sources: list[str] = []
            for index, beat in enumerate(block.beats):
                quote = evidence(beat.quote_evidence_id) if beat.quote_evidence_id else None
                if quote is not None:
                    story_sources.append(quote["evidence_id"])
                story_sources += sources_of([c for s in beat.narration for c in s.claim_ids])
                beats.append({"beat_id": beat.beat_id, "beat_index": index,
                              "narration": [sent(s) for s in beat.narration], "narration_audio_url": None,
                              "quote": quote, "quote_meaning": compose.span(beat.quote_meaning)
                              if beat.quote_meaning and quote else None,
                              "visual": visual(f"{block.block_id}.{beat.beat_id}", beat.visual_brief)})
            origin: dict[str, Any] | None = None
            provenance: dict[str, Any] | None = None
            if block.sourced:
                origin = {"title": block.origin_title, "source_ids": list(dict.fromkeys(story_sources)),
                          "show_card": False}
                first: dict[str, Any] | None = next((b["quote"] for b in beats if b["quote"]), None)
                if first is not None:
                    key = next(k for k, v in registry.items() if v["source_id"] == first["evidence_id"])
                    item = registry[key]
                    body = first.get("hadith") or {}
                    provenance = {"source_id": first["evidence_id"], "provider": item["provider"],
                                  "reference": item["reference"], "grade_label": body.get("grade_label")}
            blocks.append({**common, "label": block.label, "title": block.title, "provenance": provenance,
                           "beats": beats, "origin": origin})
        elif block.type == "teach":
            blocks.append({**common, "eyebrow": block.eyebrow, "title": compose.span(block.title),
                           "style": block.style,
                           "visual": visual(block.block_id, block.visual_brief) if block.visual_brief else None,
                           "evidence": evidence(block.evidence_id) if block.evidence_id else None,
                           "points": [{"point_id": p.point_id, "sentence": sent(p.sentence), "visual_params": None}
                                      for p in block.points]})
        elif block.type == "paragraph":
            blocks.append({**common, "sentences": [sent(s) for s in block.sentences]})
        elif block.type == "callout":
            blocks.append({**common, "variant": block.variant, "spans": compose.span(block.text)})
        elif block.type == "evidence":
            blocks.append({**common, "evidence": evidence(block.evidence_id),
                           "caption": compose.span(block.caption) if block.caption else None})
        else:
            blocks.append({"block_id": block.block_id, "type": "exercise", "exercise_id": None,
                           "intent": block.intent})
    return blocks, visuals


def sentence_map(draft: WriterDraft) -> list[dict[str, Any]]:
    rows: dict[str, dict[str, Any]] = {}
    for variant in draft.variants:
        for item in _sentences(variant):
            rows.setdefault(item.sentence_id, {"sentence_id": item.sentence_id, "role": item.role,
                                               "claim_ids": list(item.claim_ids)})
    return list(rows.values())


async def run(ctx: StageContext) -> StageResult:
    plan = approved_plan(ctx)
    verified = accepted(ctx, "verify_evidence")
    async with ctx.sessionmaker() as db:
        unit = (await db.execute(select(Unit).where(Unit.id == ctx.run.unit_id))).scalar_one()
    tracks = list(unit.tracks)
    supported = {}
    for row in verified["claims"]:
        claim = row["claim"]
        if claim["status"] == "supported":
            supported[claim["claim_id"]] = {
                "claim_id": claim["claim_id"], "text": claim["text"], "basis": claim["basis"],
                "arc_step_id": row["arc_step_id"],
                "supporting_sources": [e["source"]["source_id"] for e in claim["evidence"] if e["supports"]]}
    registry = {item["evidence_key"]: item for item in verified["evidence"]}
    data = {"plan": plan, "variants_to_write": variants_for(tracks), "unit": {"unit_id": unit.id,
            "index": unit.index, "title": unit.title}, "supported_claims": list(supported.values()),
            "evidence": [{"evidence_id": k, "kind": v["kind"], "reference": v["reference"], "text": v["text"],
                          "supports_claims": v["claim_ids"]} for k, v in registry.items()],
            "style_guide": None, "gold_examples": [],
            # Gate 2 ``request_changes``: the reviewer's reasons, oldest first (untrusted data, factory §13.1).
            "reviewer_change_requests": [r["reason"] for r in ctx.run.artifacts.get("revisions", [])],
            "previous_attempt_issues": ctx.run.previous_issues}
    result = await ctx.llm.structured("factory_write", data, ledger=ctx.ledger, call_key=ctx.call_key)
    draft = parse(WriterDraft, result.data, "draft_invalid")
    require(check(draft, plan, tracks, supported, registry), "draft_invalid")
    composed: dict[str, Any] = {}
    visuals: list[dict[str, Any]] = []
    for variant in draft.variants:
        blocks, made = compose_variant(ctx.run.id, variant, supported, registry)
        composed[variant.variant] = {"title": variant.title, "subtitle": variant.subtitle, "blocks": blocks,
                                     "completion": {"challenge": compose.span(variant.completion.challenge)
                                                    if variant.completion.challenge else None,
                                                    "review_topics": [t.model_dump(mode="json")
                                                                      for t in variant.completion.review_topics],
                                                    "check_in": compose.span(variant.completion.check_in)
                                                    if variant.completion.check_in else None}}
        if not visuals:
            visuals = made
    output = {"writer": draft.model_dump(mode="json"), "variants": composed, "sentence_map": sentence_map(draft),
              "arc_map": [row.model_dump(mode="json") for row in draft.arc_map], "visuals": visuals,
              "few_shot": {"style_guide": False, "gold_examples": 0}}
    output["figures"] = {f"{block.block_id}.{beat.beat_id}": beat.figures
                         for block in draft.variants[0].blocks if block.type == "story" for beat in block.beats}
    return StageResult(output=output, inputs=data, notes={"agent_issues": draft.issues,
                                                          "few_shot_missing": "F-104"})
