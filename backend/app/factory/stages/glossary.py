"""Stage 7 ``glossary`` — Glossary Editor (factory §13.1 stage 7, §13.2 terms).

One record per new term of the approved plan, in Arabic (English comes from ``localize``). Code checks that the
terms are exactly the plan's new terms, that a linked concept is one this lesson teaches or requires, and that
the term is not already a glossary record (an existing term is linked, never re-defined). Pronunciation audio
needs TTS (Phase 14) and stays null.
"""

from __future__ import annotations

from typing import Any

from sqlalchemy import select

from app.factory.orchestrator import StageContext, StageResult
from app.factory.stage_models import Glossary
from app.factory.stages.common import accepted, approved_plan, duplicates, key_of, parse, require
from app.models import Term
from app.sources.normalize import normalize_ar


def check(glossary: Glossary, plan: dict[str, Any], existing: dict[str, str]) -> list[str]:
    wanted = {normalize_ar(t["ar"]): t["ar"] for t in plan["new_terms"]}
    got = [normalize_ar(t.text_ar) for t in glossary.terms]
    errors = [f"duplicate term id {t}" for t in duplicates([t.term_id for t in glossary.terms])]
    errors += [f"term {t} defined twice" for t in duplicates(got)]
    missing = sorted(set(wanted) - set(got))
    extra = sorted(set(got) - set(wanted))
    if missing:
        errors.append(f"define every new term of the plan (missing {[wanted[m] for m in missing]})")
    if extra:
        errors.append(f"define only the plan's new terms (not {extra})")
    concepts = set(plan["introduced_concept_ids"]) | set(plan["prerequisite_concept_ids"])
    for term in glossary.terms:
        if term.concept_id is not None and term.concept_id not in concepts:
            errors.append(f"{term.term_id}: concept {term.concept_id} is not part of this lesson")
        if normalize_ar(term.text_ar) in existing:
            errors.append(f"{term.term_id}: {term.text_ar} already exists as {existing[normalize_ar(term.text_ar)]}"
                          "; an existing term is linked, not redefined")
    return errors


async def run(ctx: StageContext) -> StageResult:
    plan = approved_plan(ctx)
    written = accepted(ctx, "write")
    async with ctx.sessionmaker() as db:
        rows = (await db.execute(select(Term))).scalars()
        existing = {normalize_ar(str((t.text or {}).get("ar", ""))): t.id for t in rows}
    if not plan["new_terms"]:
        return StageResult(output={"terms": []}, inputs={"new_terms": []}, notes={"agent_issues": []})
    data = {"new_terms": plan["new_terms"],
            "concepts": {"introduced": plan["introduced_concept_ids"], "required": plan["prerequisite_concept_ids"]},
            "lesson_text": written["writer"]["variants"][0], "previous_attempt_issues": ctx.run.previous_issues}
    result = await ctx.llm.structured("factory_glossary", data, ledger=ctx.ledger, call_key=ctx.call_key)
    glossary = parse(Glossary, result.data, "glossary_invalid")
    require(check(glossary, plan, existing), "glossary_invalid")
    key = key_of(ctx.run.id)
    terms = [{"term_id": f"term_{key}_{i}", "text_ar": t.text_ar, "arabic": t.arabic,
              "transliteration": t.transliteration, "basic_ar": t.basic_ar, "intermediate_ar": t.intermediate_ar,
              "example_ar": t.example_ar, "concept_id": t.concept_id, "designer_id": t.term_id}
             for i, t in enumerate(glossary.terms, start=1)]
    return StageResult(output={"terms": terms}, inputs=data, notes={"agent_issues": glossary.issues})
