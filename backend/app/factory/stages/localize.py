"""Stage 7a ``localize`` — Localizer and code parity check (factory §13.1 stage 7a; AD: Arabic is the source).

The Localizer sees every Arabic text leaf of the composed lesson (variants, completion, exercises with their
feedback, glossary records, misconception cards, visual alt text), each under an opaque id, and returns English for
exactly those ids. Code then builds the English structure by substituting those leaves into the Arabic one, so
block, sentence, exercise, option ids, roles, claim links, answer keys and evidence references are identical by
construction; what the model can change is only wording, which model QA (``localization``) and Gate 2 review.

Qur'an and hadith never pass through this stage: the English evidence is the verified binding from retrieval (a
specialist-selected QuranEnc translation). A lesson that displays a Qur'an passage while no English translation
is selected stops here with ``translation_unselected`` before any model spend (D-85, F-105).
"""

from __future__ import annotations

from typing import Any

from app.factory import compose
from app.factory.errors import StageBlocked
from app.factory.orchestrator import StageContext, StageResult
from app.factory.stage_models import Localization
from app.factory.stages.common import accepted, duplicates, parse, require


def arabic_bundle(ctx: StageContext) -> dict[str, Any]:
    """The Arabic lesson as one structure, exercise slots resolved to exercise blocks."""
    written = accepted(ctx, "write")
    designed = accepted(ctx, "exercises")
    glossary = accepted(ctx, "glossary")
    slots = designed["slots"]
    variants = {}
    for name, content in written["variants"].items():
        blocks = [{"block_id": b["block_id"], "type": "exercise", "exercise_id": slots[b["block_id"]]}
                  if b["type"] == "exercise" else b for b in content["blocks"]]
        variants[name] = {"title": content["title"], "subtitle": content["subtitle"], "blocks": blocks,
                          "completion": content["completion"]}
    return {
        "variants": variants,
        "exercises": {r["exercise_id"]: {"exercise": r["exercise"], "feedback": r["feedback"]}
                      for r in designed["exercises"]},
        "glossary": {t["term_id"]: {"title": t["text_ar"], "basic": compose.span(t["basic_ar"]),
                                    "intermediate": compose.span(t["intermediate_ar"]) if t["intermediate_ar"]
                                    else None, "example": compose.span(t["example_ar"])}
                     for t in glossary["terms"]},
        "misconceptions": {m["misconception_id"]: {"title": m["title"], "card": m["card"]}
                           for m in designed["misconceptions"]},
    }


def used_evidence(node: Any) -> set[str]:
    found: set[str] = set()

    def walk(item: Any) -> None:
        if isinstance(item, dict):
            if "evidence_id" in item and "kind" in item and ("quran" in item or "hadith" in item):
                found.add(item["evidence_id"])
                return
            for value in item.values():
                walk(value)
        elif isinstance(item, list):
            for value in item:
                walk(value)

    walk(node)
    return found


def _hint(path: tuple[Any, ...]) -> str:
    return "/".join(str(p) for p in path[:-1])


async def run(ctx: StageContext) -> StageResult:
    verified = accepted(ctx, "verify_evidence")
    english_evidence = {item["source_id"]: item for item in verified["evidence"]}
    bundle = arabic_bundle(ctx)
    missing = sorted(e for e in used_evidence(bundle)
                     if english_evidence.get(e, {}).get("evidence", {}).get("en") is None)
    if missing:
        reasons = sorted({str(english_evidence.get(e, {}).get("en_unavailable")) for e in missing})
        raise StageBlocked("translation_unselected", f"evidence {missing} has no verified English rendering "
                           f"({'; '.join(reasons)}); a specialist selects the English Qur'an translation (D-93)")
    leaves = list(compose.text_leaves(bundle))
    ids = {f"t{i}": path for i, (path, _) in enumerate(leaves, start=1)}
    data = {"texts": [{"id": f"t{i}", "where": _hint(path), "ar": text}
                      for i, (path, text) in enumerate(leaves, start=1)],
            "previous_attempt_issues": ctx.run.previous_issues}
    result = await ctx.llm.structured("factory_localize", data, ledger=ctx.ledger, call_key=ctx.call_key)
    localization = parse(Localization, result.data, "localization_invalid")
    returned = [t.id for t in localization.texts]
    errors = [f"{i} localized twice" for i in duplicates(returned)]
    errors += [f"{i} is missing" for i in sorted(set(ids) - set(returned), key=lambda x: int(x[1:]))]
    errors += [f"{i} is not an id you were given" for i in sorted(set(returned) - set(ids))]
    errors += [f"{t.id} is empty" for t in localization.texts if not t.text.strip()]
    require(errors, "localization_invalid")
    english = compose.replace_leaves(bundle, {ids[t.id]: t.text for t in localization.texts})
    english = compose.swap_evidence(english, lambda eid: english_evidence[eid]["evidence"]["en"])
    return StageResult(output={"ar": bundle, "en": english}, inputs=data,
                       notes={"agent_issues": localization.issues, "leaves": len(leaves)})
