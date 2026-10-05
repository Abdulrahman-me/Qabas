"""Stage 4 ``verify_evidence`` — Evidence Verifier (factory §13.1 stage 4; §13.2 claim basis; pre-generation audit).

The model judges entailment and writes the semantic scholarly review; code owns everything checkable:

* a verdict for every claim, judging only the candidates retrieved for that claim (ids it was given);
* the text check: a Qur'an candidate is re-read from the pinned mushaf and must equal it word for word;
* citability: a candidate code marked not citable (weak or ungraded hadith, editorial gloss, HadeethEnc-only
  grade) can never support a claim — the model saying otherwise is invalid output, not something code repairs;
* the contract ``Claim``/``ClaimEvidence`` rules: supporting scripture needs a semantic review, a stretched or
  unrelated item cannot support, a reasoning claim uses its approved tool and never scripture.

The accepted artifact holds the contract claims and the evidence registry the Writer may cite (``E1``, ``E2``…):
the Qur'an and hadith items that support a supported claim, with their verified Arabic and English evidence.
"""

from __future__ import annotations

from typing import Any

from pydantic import ValidationError

from app.contract import models as C
from app.factory import evidence as E
from app.factory.errors import StageBlocked
from app.factory.orchestrator import StageContext, StageResult
from app.factory.stage_models import Verification
from app.factory.stages.common import accepted, approved_plan, duplicates, parse, require

DISPLAYABLE = ("quran", "hadith")


def _text_check(candidate: dict[str, Any], tools: E.SourceTools | None) -> str | None:
    """The deterministic text check behind ``verifier_note`` (None = passed)."""
    if candidate["kind"] == "quran":
        quran = (candidate["evidence"]["ar"] or {}).get("quran")
        if quran is None:
            return "no verified Qur'an evidence"
        if tools is not None:
            passage = tools.mushaf.get(quran["surah"], quran["ayah_start"], quran["ayah_end"])
            if passage.text_uthmani != quran["text_uthmani"] or passage.text_uthmani != candidate["excerpt"]:
                return "the Qur'an text differs from the pinned mushaf"
    if candidate["kind"] == "hadith" and candidate["provider"] == "dorar" and candidate["citable"]:
        hadith = (candidate["evidence"]["ar"] or {}).get("hadith")
        if hadith is None or hadith["text_ar"] != candidate["excerpt"]:
            return "the hadith text differs from the Dorar record"
    return None


def build(verification: Verification, claims: list[dict[str, Any]], candidates: list[dict[str, Any]],
          plan: dict[str, Any], tools: E.SourceTools | None) -> tuple[list[dict[str, Any]], list[str]]:
    errors: list[str] = []
    by_id = {c["candidate_id"]: c for c in candidates}
    decomposed = {c["claim_id"]: c for c in claims}
    verdicts = {v.claim_id: v for v in verification.claims}
    errors += [f"claim {c} judged twice" for c in duplicates([v.claim_id for v in verification.claims])]
    errors += [f"verdict for unknown claim {c}" for c in sorted(set(verdicts) - set(decomposed))]
    errors += [f"claim {c} has no verdict" for c in sorted(set(decomposed) - set(verdicts))]
    tools_approved = {use["tool"] for use in plan["reasoning_tools"]}
    built: list[dict[str, Any]] = []
    for claim_id, claim in decomposed.items():
        verdict = verdicts.get(claim_id)
        if verdict is None:
            continue
        mine = {k for k, c in by_id.items() if c["claim_id"] == claim_id}
        evidence = []
        errors += [f"{claim_id}: candidate {c} judged twice"
                   for c in duplicates([j.candidate_id for j in verdict.evidence])]
        for judgement in verdict.evidence:
            candidate = by_id.get(judgement.candidate_id)
            if candidate is None or judgement.candidate_id not in mine:
                errors.append(f"{claim_id}: {judgement.candidate_id} is not a candidate retrieved for this claim")
                continue
            if judgement.supports and not candidate["citable"]:
                errors.append(f"{claim_id}: {judgement.candidate_id} cannot support a claim "
                              f"({candidate['not_citable_reason']})")
                continue
            problem = _text_check(candidate, tools)
            if judgement.supports and problem is not None:
                errors.append(f"{claim_id}: {judgement.candidate_id}: {problem}")
                continue
            note = f"text check: {'passed' if problem is None else problem}. {judgement.verifier_note}"
            source = {**E.public_source(E.load_record(candidate["records"][0])), "displayed": False,
                      "display_role": None}
            evidence.append({"source": source, "supports": judgement.supports, "verifier_note": note,
                             "semantic_review": judgement.semantic_review.model_dump(mode="json")
                             if judgement.semantic_review else None, "candidate_id": candidate["candidate_id"]})
        reasoning = verdict.reasoning.model_dump(mode="json") if verdict.reasoning else None
        if claim["basis"] == "reasoning" and reasoning is not None and (
                reasoning["tool"] != claim["reasoning_tool"] or reasoning["tool"] not in tools_approved):
            errors.append(f"{claim_id}: reasoning must use its approved tool {claim['reasoning_tool']}")
        body = {"claim_id": claim_id, "text": claim["text_ar"], "status": verdict.status, "basis": claim["basis"],
                "evidence": [{k: v for k, v in e.items() if k != "candidate_id"} for e in evidence],
                "reasoning": reasoning}
        try:
            C.Claim.model_validate(body)
        except ValidationError as exc:
            errors.append(f"{claim_id}: {exc.errors()[0]['msg']}")
            continue
        built.append({"claim": body, "candidate_ids": [e["candidate_id"] for e in evidence],
                      "supporting": [e["candidate_id"] for e in evidence if e["supports"]],
                      "arc_step_id": claim["arc_step_id"]})
    return built, errors


def registry(built: list[dict[str, Any]], candidates: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Displayable evidence (Qur'an and graded hadith) supporting supported claims, one entry per source."""
    by_id = {c["candidate_id"]: c for c in candidates}
    items: dict[str, dict[str, Any]] = {}
    for row in built:
        if row["claim"]["status"] != "supported":
            continue
        for candidate_id in row["supporting"]:
            candidate = by_id[candidate_id]
            if candidate["kind"] not in DISPLAYABLE or candidate["evidence"]["ar"] is None:
                continue
            item = items.setdefault(candidate["source_id"], {
                "source_id": candidate["source_id"], "kind": candidate["kind"], "provider": candidate["provider"],
                "reference": candidate["reference"],
                "title": candidate["title"], "text": candidate["excerpt"], "evidence": candidate["evidence"],
                "en_unavailable": candidate["en_unavailable"], "claim_ids": []})
            item["claim_ids"].append(row["claim"]["claim_id"])
    ordered = sorted(items.values(), key=lambda i: i["source_id"])
    for index, item in enumerate(ordered, start=1):
        item["evidence_key"] = f"E{index}"
    return ordered


async def run(ctx: StageContext) -> StageResult:
    plan = approved_plan(ctx)
    claims = accepted(ctx, "decompose")["claims"]
    retrieved = accepted(ctx, "retrieve")
    candidates = retrieved["candidates"]
    data = {"plan": {k: plan[k] for k in ("title", "central_question", "primary_learning_outcome",
                                          "reasoning_tools", "lesson_type")},
            "claims": claims, "candidates": [E.for_model(c) | {"claim_id": c["claim_id"]} for c in candidates],
            "previous_attempt_issues": ctx.run.previous_issues}
    result = await ctx.llm.structured("factory_verify", data, ledger=ctx.ledger, call_key=ctx.call_key)
    verification = parse(Verification, result.data, "verification_invalid")
    make_tools = ctx.services.get("sources")
    tools = make_tools() if make_tools is not None else None
    try:
        built, errors = build(verification, claims, candidates, plan, tools)
    finally:
        if tools is not None:
            await tools.aclose()
    require(errors, "verification_invalid")
    supported = [row for row in built if row["claim"]["status"] == "supported"]
    if not supported:
        raise StageBlocked("no_supported_claims", "no claim survived verification; the lesson cannot be written "
                           "until a person supplies or approves sources for it (D-85)")
    output = {"claims": built, "evidence": registry(built, candidates)}
    return StageResult(output=output, inputs=data,
                       notes={"agent_issues": verification.issues,
                              "dropped": [r["claim"]["claim_id"] for r in built if r["claim"]["status"] == "dropped"]})
