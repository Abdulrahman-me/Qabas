"""Stage 10 ``qa`` — QA Reviewer, Pedagogy Reviewer and the code checks (factory §13.5) → ``awaiting_gate2``.

Code assembles the complete lesson package from the accepted artifacts (both languages, term spans linked
deterministically) and the reviewer ``Draft``, then reports:

* every deterministic content validator (the same ones gold imports and publication use: ``validate_package``),
  as blockers, including placeholder media and visual readiness (no draft passes Gate 2 before audited media);
* the verifier's semantic reviews (``scholarly_review_issues``), reading level, the code pedagogy and writing
  checks, and the notes the agents themselves raised;
* two model reviewers on separate prompts (religious/factual/safety and pedagogy); their findings are typed,
  located on ids that must exist, and mapped onto the §13.5 severity policy.

Nothing here approves anything: the report is for the reviewer and the specialist at Gate 2, and a model's
opinion of the draft is never a reason to publish it.
"""

from __future__ import annotations

import re
from collections import Counter
from typing import Any

from pydantic import ValidationError
from sqlalchemy import select

from app.content import validation
from app.content.package import LessonPackage, content_digest, sentences_of
from app.content.projection import resolve_items
from app.contract import contextual
from app.contract import models as C
from app.factory import compose
from app.factory.errors import StageOutputInvalid
from app.factory.orchestrator import StageContext, StageResult
from app.factory.stage_models import ModelReview
from app.factory.stages.common import accepted, approved_plan, parse
from app.factory.stages.media import rebind
from app.media import scenes
from app.media.service import overlay_bundle
from app.models import Concept, Misconception, Source, Term, Unit

READING_WORDS = 25
MAX_EXCLAMATIONS = 2
STOCK_PHRASES = {
    "ar": ("لنستكشف", "هيا بنا", "في هذا الدرس سوف", "في هذا الدرس سن", "رحلة ممتعة", "من المهم أن نعرف",
           "لا شك أن", "دعونا نتعرف"),
    "en": ("let's explore", "let us explore", "in this lesson we will", "in this lesson, we will",
           "exciting journey", "it is important to know that", "without a doubt"),
}
SENSITIVE = {"ar": ("ردة", "المرتد", "جهاد", "تكفير", "الفرق", "طائفة"),
             "en": ("apostasy", "apostate", "jihad", "takfir", "sect")}
FIXED_SEVERITY = {"unsupported_sentence": "blocker", "fatwa_like": "blocker", "belief_grading": "blocker",
                  "circular_reasoning": "blocker", "sensitive": "info"}
QA_KINDS = {"unsupported_sentence", "fatwa_like", "consistency", "sensitive", "belief_grading",
            "circular_reasoning", "localization", "scholarly_review"}
AGENT_KIND = {"plan": "pedagogy", "decompose": "scholarly_review", "retrieve": "scholarly_review",
              "verify_evidence": "scholarly_review", "write": "pedagogy", "exercises": "pedagogy",
              "glossary": "pedagogy", "localize": "localization"}


def issue(severity: str, kind: str, message: str, *, sentence_id: str | None = None,
          exercise_id: str | None = None, scene_id: str | None = None) -> dict[str, Any]:
    return {"severity": severity, "kind": kind, "message": message[:2000],
            "location": {"sentence_id": sentence_id, "exercise_id": exercise_id, "scene_id": scene_id}}


# ------------------------------------------------------------------------------------------- assembly

def assemble(ctx: StageContext) -> tuple[dict[str, Any], dict[str, list[dict[str, Any]]], list[dict[str, Any]]]:
    """(package JSON, source records by source id, draft visuals) from the accepted artifacts."""
    plan = approved_plan(ctx)
    verified = accepted(ctx, "verify_evidence")
    retrieved = accepted(ctx, "retrieve")
    written = accepted(ctx, "write")
    designed = accepted(ctx, "exercises")
    glossary = accepted(ctx, "glossary")
    localized = (accepted(ctx, "narration")["localized"] if "narration" in ctx.run.artifacts
                 else accepted(ctx, "localize"))
    if "scene_render" in ctx.run.artifacts:
        media = accepted(ctx, "scene_render")
        localized = {lang: overlay_bundle(localized[lang], media["replacements"][lang], media["point_states"])
                     for lang in ("ar", "en")}
        localized = {lang: place_pins(localized[lang], media.get("pins", {})) for lang in ("ar", "en")}
    narrated = accepted(ctx, "narration") if "narration" in ctx.run.artifacts else {}
    rebinds, scripture = narrated.get("rebinds", {}), narrated.get("scripture", {})
    terms = {lang: [(t["term_id"], (t["text_ar"] if lang == "ar" else
                                    localized["en"]["glossary"][t["term_id"]]["title"]))
                    for t in glossary["terms"]] for lang in ("ar", "en")}
    variants: dict[str, dict[str, Any]] = {}
    for lang in ("ar", "en"):
        variants[lang] = {}
        for name, content in localized[lang]["variants"].items():
            variants[lang][name] = {
                "title": content["title"], "subtitle": content["subtitle"],
                "objectives": [compose.span(o[lang]) for o in plan["objectives"]],
                "blocks": compose.link_terms(content["blocks"], terms[lang], lang),
                "completion": content["completion"]}
    exercises = []
    for record in designed["exercises"]:
        eid = record["exercise_id"]
        exercises.append({"exercise_id": eid, "purpose": record["purpose"],
                          "exercise": {"ar": localized["ar"]["exercises"][eid]["exercise"],
                                       "en": localized["en"]["exercises"][eid]["exercise"]},
                          "feedback": {"ar": localized["ar"]["exercises"][eid]["feedback"],
                                       "en": localized["en"]["exercises"][eid]["feedback"]},
                          "targets_misconception_id": record["targets_misconception_id"],
                          "source_ids": record["source_ids"]})
    stored_terms = []
    for term in glossary["terms"]:
        ar, en = localized["ar"]["glossary"][term["term_id"]], localized["en"]["glossary"][term["term_id"]]
        stored_terms.append({
            "term_id": term["term_id"], "text": {"ar": ar["title"], "en": en["title"]}, "arabic": term["arabic"],
            "transliteration": term["transliteration"],
            "definition": {"basic": {"ar": ar["basic"], "en": en["basic"]},
                           "intermediate": {"ar": ar["intermediate"], "en": en["intermediate"]}
                           if ar["intermediate"] else None},
            "example": {"ar": ar["example"], "en": en["example"]}, "concept_id": term["concept_id"],
            "lesson_id": ctx.run.lesson_id, "source_id": None,
            "pronunciation_audio_url": accepted(ctx, "narration").get("pronunciation", {}).get(term["term_id"])
            if "narration" in ctx.run.artifacts else None})
    misconceptions = []
    for card in designed["misconceptions"]:
        mid = card["misconception_id"]
        misconceptions.append({"misconception_id": mid, "concept_id": card["concept_id"],
                               "title": {"ar": localized["ar"]["misconceptions"][mid]["title"],
                                         "en": localized["en"]["misconceptions"][mid]["title"]},
                               "card": {"ar": localized["ar"]["misconceptions"][mid]["card"],
                                        "en": localized["en"]["misconceptions"][mid]["card"]},
                               "source_ids": []})
    candidates = {c["source_id"]: c for c in retrieved["candidates"]}
    cited = {e["source"]["source_id"] for row in verified["claims"] for e in row["claim"]["evidence"]}
    cited |= {s for r in designed["exercises"] for s in r["source_ids"]}
    cited |= {item["source_id"] for item in verified["evidence"]}
    # Reference audio (narration) rebinds Qur'an evidence to its audio-bearing bundle and adds the recitation
    # activity sources; their verified bundles replace the retrieval candidates as citations and provenance.
    cited = {rebinds[s]["source_id"] if s in rebinds else s for s in cited}
    cited |= {r["source_id"] for r in narrated.get("recitations", {}).values()}
    sources, records = [], {}
    for source_id in sorted(cited):
        if source_id in scripture:
            sources.append(scripture[source_id]["source"])
            records[source_id] = scripture[source_id]["records"]
            continue
        candidate = candidates[source_id]
        sources.append({k: candidate[k] for k in ("source_id", "kind", "provider", "title", "reference", "url")}
                       | {"excerpt": candidate["excerpt"]})
        records[source_id] = candidate["records"]
    package = {"lesson_id": ctx.run.lesson_id, "unit_id": ctx.run.unit_id, "index": ctx.run.position_index,
               "plan": plan, "variants": variants, "claims": [row["claim"] for row in verified["claims"]],
               "sentence_map": written["sentence_map"], "arc_map": written["arc_map"], "exercises": exercises,
               "glossary": stored_terms, "misconceptions": misconceptions, "sources": sources}
    package = rebind(package, rebinds, None)
    visuals = accepted(ctx, "scene_render")["visuals"] if "scene_render" in ctx.run.artifacts else written["visuals"]
    return package, records, visuals


def place_pins(bundle: dict[str, Any], pins: dict[str, list[dict[str, Any]]]) -> dict[str, Any]:
    """map_place pins at the scene's static anchors (F-108); labels and ids are untouched."""
    for exercise_id, rows in pins.items():
        payload = bundle["exercises"][exercise_id]["exercise"]["payload"]
        located = {row["pin_id"]: row for row in rows}
        if {pin["pin_id"] for pin in payload["pins"]} != set(located):
            raise StageOutputInvalid("map_pins_invalid", [f"{exercise_id}: anchors do not cover every pin"])
        payload["pins"] = [{**pin, **{k: located[pin["pin_id"]][k] for k in ("x_pct", "y_pct", "radius_pct",
                                                                             "anchor_id")}}
                           for pin in payload["pins"]]
    return bundle


def build_draft(package: LessonPackage, visuals: list[dict[str, Any]]) -> dict[str, Any]:
    previews = []
    for lang, variant in package.variant_keys():
        content = package.variants[lang][variant]
        previews.append({"language": lang, "variant": variant,
                         "objectives": [[s.model_dump(mode="json") for s in o] for o in content.objectives],
                         "items": resolve_items(package, lang, variant),
                         "completion": content.completion.model_dump(mode="json") if content.completion else None})
    draft = C.Draft.model_validate({
        "languages": ["ar", "en"], "variants": sorted(package.variants["ar"]), "previews": previews,
        "claims": [c.model_dump(mode="json") for c in package.claims],
        "sentence_map": [s.model_dump(mode="json") for s in package.sentence_map],
        "arc_map": [a.model_dump(mode="json") for a in package.arc_map],
        "exercises": [r.exercise["ar"].model_dump(mode="json") for r in package.exercises],
        "glossary": [t.model_dump(mode="json") for t in package.glossary],
        "misconceptions": [{"misconception_id": m.misconception_id, "title": m.title["ar"],
                            "card": [s.model_dump(mode="json") for s in m.card["ar"]], "source_ids": m.source_ids}
                           for m in package.misconceptions],
        "visuals": visuals})
    value: dict[str, Any] = draft.model_dump(mode="json")
    return value


# ------------------------------------------------------------------------------------------- code checks

def _text(spans: list[Any]) -> str:
    return "".join(s.get("text", "") for s in spans if isinstance(s, dict))


def validation_issues(found: list[validation.Issue], sentence_ids: set[str],
                      exercise_ids: set[str]) -> list[dict[str, Any]]:
    out, media = [], []
    for item in found:
        if item.code == "validation" and "media URL" in item.message:
            media.append(item.message)
            continue
        kind = item.code if item.code in ("unsupported_sentence", "localization") else "validation"
        head = item.location.split("/")[0]
        out.append(issue("blocker", kind, str(item), sentence_id=item.location if item.location in sentence_ids
                         else None, exercise_id=head if head in exercise_ids else None))
    if media:
        out.append(issue("blocker", "validation",
                         f"{len(media)} placeholder or non-https media URLs; first: {media[0]}"))
    return out


def readiness_issues(visuals: list[dict[str, Any]]) -> list[dict[str, Any]]:
    out = []
    for visual in visuals:
        state = contextual.visual_readiness(visual, released_capabilities=scenes.released())
        if state not in contextual.VISUAL_PUBLISHABLE:
            out.append(issue("blocker", "validation", f"visual readiness {state}: Gate 2 needs a compiled or "
                             "audited visual", scene_id=visual["scene_id"]))
    return out


def writing_issues(package: LessonPackage) -> list[dict[str, Any]]:
    out = []
    questions = {s.sentence_id for s in package.sentence_map if s.role == "question"}
    for lang, variant in package.variant_keys():
        content = package.variants[lang][variant]
        all_text = []
        for block in content.blocks:
            for item in sentences_of(block):
                text = _text(item["spans"])
                all_text.append(text)
                if len(text.split()) > READING_WORDS:
                    out.append(issue("warning", "reading_level", f"{lang}/{variant}: sentence above {READING_WORDS} "
                                     "words", sentence_id=item["sentence_id"]))
            if block["type"] == "teach":
                asked = [p for p in block["points"] if p["sentence"]["sentence_id"] in questions]
                if len(asked) > 1:
                    out.append(issue("warning", "pedagogy", f"{lang}/{variant}/{block['block_id']}: more than one "
                                     "question sentence in a teach card"))
            for key in ("situation", "question", "prompt", "reveal", "spans", "title"):
                if isinstance(block.get(key), list):
                    all_text.append(_text(block[key]))
        joined = "\n".join(all_text)
        lowered = joined.lower()
        stock = [p for p in STOCK_PHRASES[lang] if p in (lowered if lang == "en" else joined)]
        if stock:
            out.append(issue("warning", "pedagogy", f"{lang}/{variant}: stock or scripted phrasing {stock}"))
        if joined.count("!") > MAX_EXCLAMATIONS:
            out.append(issue("warning", "pedagogy", f"{lang}/{variant}: {joined.count('!')} exclamation marks"))
        sensitive = [w for w in SENSITIVE[lang] if re.search(rf"(?<!\w){re.escape(w)}", lowered)]
        if sensitive:
            out.append(issue("info", "sensitive", f"{lang}/{variant}: mentions {sensitive}; specialist attention"))
    return out


def pedagogy_issues(package: LessonPackage) -> list[dict[str, Any]]:
    out = []
    plan = package.plan
    lang, variant = package.variant_keys()[0]
    blocks = package.variants[lang][variant].blocks
    placed = [package.exercise(b["exercise_id"]) for b in blocks if b["type"] == "exercise"]
    graded = [r for r in placed if r is not None and r.scored]
    interactive = [b["type"] in ("exercise", "predict") for b in blocks]
    if plan.estimated_minutes > 12:
        out.append(issue("warning", "pedagogy", "estimated duration above about 12 minutes: review whether the "
                         "lesson holds more than one outcome (never an automatic split)"))
    if plan.depth_profile == "foundational" and plan.estimated_minutes < 6:
        out.append(issue("info", "pedagogy", "a foundational lesson estimated well below its range: check "
                         "completeness (never a reason to pad)"))
    if len(graded) > 5:
        out.append(issue("warning", "pedagogy", f"{len(graded)} graded exercises: quiz-heavy"))
    if len(graded) > interactive.count(False):
        out.append(issue("warning", "pedagogy", "graded exercises outnumber the lesson's other steps"))
    if plan.lesson_type == "concept" and len(plan.new_terms) > 2:
        out.append(issue("warning", "pedagogy", "a concept lesson with more than two new terms"))
    step_of = {block_id: index for index, row in enumerate(package.arc_map) for block_id in row.block_ids}
    first = next((step_of.get(b["block_id"], 0) for b in blocks if b["type"] in ("exercise", "predict")), None)
    if first is None or first > 2:
        out.append(issue("warning", "pedagogy", "the first interaction comes later than the third arc step"))
    run = longest = 0
    for flag in interactive:
        run = 0 if flag else run + 1
        longest = max(longest, run)
    if longest > 3:
        out.append(issue("warning", "pedagogy", f"{longest} consecutive non-interactive blocks"))
    layers = {r.exercise["ar"].scoring.layer for r in graded}
    if graded and layers == {"remember"}:
        out.append(issue("warning", "pedagogy", "every graded exercise is remember-layer although the outcome asks "
                         "for understanding or application"))
    types = [r.type for r in placed if r is not None]
    if any(types[i] == types[i + 1] == types[i + 2] for i in range(len(types) - 2)):
        out.append(issue("info", "pedagogy", "the same exercise type three times in a row"))
    seen: Counter[tuple[str, frozenset[str]]] = Counter()
    for record in placed:
        if record is None:
            continue
        payload = record.exercise["ar"].payload
        texts = frozenset(_text(o["spans"]) for o in payload.get("options", []) or payload.get("items", []))
        if texts:
            seen[(record.type, texts)] += 1
        if record.type == "multiple_choice" and len(payload["options"]) == 2:
            out.append(issue("info", "pedagogy", "a lesson multiple-choice item with only 2 options",
                             exercise_id=record.exercise_id))
    if any(n > 1 for n in seen.values()):
        out.append(issue("warning", "pedagogy", "exercises of the same type over the same options (likely "
                         "duplicates)"))
    for block in blocks:
        if block["type"] == "story":
            beats = len(block["beats"])
            if beats == 1:
                out.append(issue("warning", "pedagogy", f"{block['block_id']}: a one-beat story"))
            if plan.lesson_type != "story" and beats > 4:
                out.append(issue("warning", "pedagogy", f"{block['block_id']}: a supporting story longer than about "
                                 "four beats in a non-story lesson"))
            if block["origin"] is None:
                out.append(issue("info", "pedagogy", f"{block['block_id']}: teaching scenario (fictional, asserts "
                                 "nothing); check it is recognisably hypothetical"))
    return out


# ------------------------------------------------------------------------------------------- model review

def review_material(package: LessonPackage) -> dict[str, Any]:
    roles = {s.sentence_id: s for s in package.sentence_map}
    variants = {}
    for lang, variant in package.variant_keys():
        rows = []
        for block in package.variants[lang][variant].blocks:
            row: dict[str, Any] = {"block_id": block["block_id"], "type": block["type"]}
            if block["type"] == "exercise":
                row["exercise_id"] = block["exercise_id"]
            sentences = sentences_of(block)
            if sentences:
                row["sentences"] = [{"sentence_id": s["sentence_id"], "text": _text(s["spans"]),
                                     "role": roles[s["sentence_id"]].role,
                                     "claim_ids": roles[s["sentence_id"]].claim_ids} for s in sentences]
            for key in ("situation", "question", "prompt", "reveal", "spans", "title", "caption"):
                if isinstance(block.get(key), list):
                    row[key] = _text(block[key])
            if block["type"] == "predict":
                row["options"] = [_text(o["spans"]) for o in block["options"]]
            if block["type"] == "story":
                row["kind"] = "sourced story" if block["origin"] else "teaching scenario (fictional)"
                row["quotes"] = [b["quote"]["evidence_id"] for b in block["beats"] if b["quote"]]
            if block.get("evidence"):
                row["evidence"] = block["evidence"]["evidence_id"]
            rows.append(row)
        variants[f"{lang}/{variant}"] = rows
    exercises = []
    for record in package.exercises:
        item: dict[str, Any] = {"exercise_id": record.exercise_id, "purpose": record.purpose, "type": record.type}
        for lang in ("ar", "en"):
            exercise = record.exercise[lang].model_dump(mode="json")
            item[lang] = {"prompt": _text(exercise["prompt"]), "payload": exercise["payload"],
                          "answer_key": exercise["answer_key"],
                          "explanation": _text(record.feedback[lang].model_dump(mode="json")["explanation"])}
        exercises.append(item)
    claims = [{"claim_id": c.claim_id, "text": c.text, "status": c.status, "basis": c.basis,
               "reasoning": c.reasoning.model_dump(mode="json") if c.reasoning else None,
               "evidence": [{"source": e.source.title + " — " + e.source.reference, "supports": e.supports,
                             "excerpt": e.source.excerpt[:1500],
                             "semantic_review": e.semantic_review.model_dump(mode="json")
                             if e.semantic_review else None} for e in c.evidence]} for c in package.claims]
    return {"plan": package.plan.model_dump(mode="json"), "claims": claims, "variants": variants,
            "exercises": exercises, "glossary": [t.model_dump(mode="json") for t in package.glossary],
            "misconceptions": [m.model_dump(mode="json") for m in package.misconceptions]}


def map_review(review: ModelReview, *, allowed: set[str], sentence_ids: set[str], exercise_ids: set[str],
               reasoning_lesson: bool, reviewer: str) -> list[dict[str, Any]]:
    errors, out = [], []
    for item in review.issues:
        if item.kind not in allowed:
            errors.append(f"{reviewer} reports {item.kind}, which is not its responsibility")
        if item.sentence_id is not None and item.sentence_id not in sentence_ids:
            errors.append(f"{item.sentence_id} is not a sentence of this draft")
        if item.exercise_id is not None and item.exercise_id not in exercise_ids:
            errors.append(f"{item.exercise_id} is not an exercise of this draft")
        severity = FIXED_SEVERITY.get(item.kind, item.severity)
        if item.kind == "pedagogy" and severity == "blocker" and not (reasoning_lesson or item.exercise_id):
            severity = "warning"   # §13.5: reasoning-integrity flaws block only in reasoning lessons or keys
        out.append(issue(severity, item.kind, f"[{reviewer}] {item.message}", sentence_id=item.sentence_id,
                         exercise_id=item.exercise_id))
    if errors:
        raise StageOutputInvalid("qa_review_invalid", errors)
    return out


# ------------------------------------------------------------------------------------------- stage

async def validation_context(ctx: StageContext) -> validation.Context:
    async with ctx.sessionmaker() as db:
        unit = (await db.execute(select(Unit).where(Unit.id == ctx.run.unit_id))).scalar_one()
        return validation.Context(
            unit_tracks=list(unit.tracks),
            known_terms=set((await db.execute(select(Term.id))).scalars()),
            known_sources=set((await db.execute(select(Source.id))).scalars()),
            known_misconceptions=set((await db.execute(select(Misconception.id))).scalars()),
            known_concepts=set((await db.execute(select(Concept.id))).scalars()))


async def run(ctx: StageContext) -> StageResult:
    package_json, records, visuals = assemble(ctx)
    try:
        package = LessonPackage.model_validate(package_json)
    except ValidationError as exc:
        # The stages' own checks should make this unreachable; if not, it is a defect, never repaired here.
        raise StageOutputInvalid("package_invalid", [f"{'/'.join(map(str, e['loc']))}: {e['msg']}"
                                                     for e in exc.errors()[:20]]) from exc
    context = await validation_context(ctx)
    sentence_ids = {s.sentence_id for s in package.sentence_map}
    exercise_ids = {e.exercise_id for e in package.exercises}
    issues = validation_issues(validation.validate_package(package, context), sentence_ids, exercise_ids)
    issues += readiness_issues(visuals)
    issues += contextual.scholarly_review_issues([c.model_dump(mode="json") for c in package.claims])
    issues += writing_issues(package)
    issues += pedagogy_issues(package)
    for stage, kind in AGENT_KIND.items():
        notes = (ctx.run.artifacts.get(stage) or {}).get("notes") or {}
        for note in notes.get("agent_issues", []) or notes.get("warnings", []):
            issues.append(issue("warning", kind, f"[{stage}] {note}"))
    dropped = (ctx.run.artifacts.get("verify_evidence") or {}).get("notes", {}).get("dropped", [])
    if dropped:
        issues.append(issue("info", "scholarly_review", f"claims dropped by verification: {dropped}"))
    for item in accepted(ctx, "verify_evidence")["evidence"]:
        if item["en_unavailable"] and item["kind"] == "hadith":
            issues.append(issue("warning", "localization", f"{item['source_id']}: English shows the hadith without "
                                f"a verified translation ({item['en_unavailable']})"))
    material = review_material(package)
    reasoning_lesson = bool(package.plan.reasoning_tools)
    qa = await ctx.llm.structured("factory_qa", material, ledger=ctx.ledger, call_key=f"{ctx.call_key}:qa")
    issues += map_review(parse(ModelReview, qa.data, "qa_review_invalid"), allowed=QA_KINDS,
                         sentence_ids=sentence_ids, exercise_ids=exercise_ids, reasoning_lesson=reasoning_lesson,
                         reviewer="qa")
    pedagogy = await ctx.llm.structured("factory_pedagogy", material, ledger=ctx.ledger,
                                        call_key=f"{ctx.call_key}:pedagogy")
    issues += map_review(parse(ModelReview, pedagogy.data, "qa_review_invalid"), allowed={"pedagogy"},
                         sentence_ids=sentence_ids, exercise_ids=exercise_ids, reasoning_lesson=reasoning_lesson,
                         reviewer="pedagogy")
    media_objects: list[dict[str, Any]] = []
    media_scenes: list[dict[str, Any]] = []
    if "scene_render" in ctx.run.artifacts:
        media = accepted(ctx, "scene_render")
        media_objects, media_scenes = media["objects"], media["scenes"]
        for finding in media["issues"]:
            issues.append(issue("blocker", finding["kind"], finding["message"], scene_id=finding["scene_id"]))
    if "narration" in ctx.run.artifacts:
        media_objects = [*media_objects, *accepted(ctx, "narration")["objects"]]
        for finding in accepted(ctx, "narration").get("issues", []):
            issues.append(issue("info", finding["kind"], finding["message"]))
    if media_objects:
        media_objects = [{**record, "binding": {**record["binding"], "reviewed_package_sha256": package.digest()}}
                         for record in media_objects]
        issues.append(issue("info", "validation", "reviewed media receipts: " + content_digest(media_objects)))
    report = C.QAReport.model_validate({"issues": issues}).model_dump(mode="json")
    draft = build_draft(package, visuals)
    blockers = sum(1 for i in report["issues"] if i["severity"] == "blocker")
    output = {"draft": draft, "package": package.model_dump(mode="json"), "package_digest": package.digest(),
              "source_records": records, "media_objects": media_objects, "media_scenes": media_scenes}
    return StageResult(output=output, inputs={"material": material}, qa_report=report,
                       notes={"blockers": blockers, "issues": len(report["issues"])})
