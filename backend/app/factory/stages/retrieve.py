"""Stage 3 ``retrieve`` — Evidence Retriever (factory §13.1; SOURCE_ADAPTERS §12).

The model proposes typed requests for the source claims; code executes each one through the Phase 9 layer
(:mod:`app.factory.evidence`) and records every outcome. A provider outage is retried with the stage; a definite
"no match" is recorded and the claim is later dropped by verification; a provider that is not approved or configured
is a human blocker when it leaves a claim with no candidate (O-03), never something generation works around.
"""

from __future__ import annotations

from typing import Any

from app.factory import evidence as E
from app.factory.errors import StageBlocked
from app.factory.orchestrator import StageContext, StageResult
from app.factory.stage_models import RetrievalPlan, RetrievalRequest
from app.factory.stages.common import accepted, duplicates, parse, require
from app.sources.errors import (
    CapabilityMismatch,
    OperationUnsupported,
    ProviderNotConfigured,
    RecordNotFound,
    SourceChanged,
)
from app.sources.mushaf import ReferenceNotFound

MAX_REQUESTS = 60
FIELDS = {"quran_reference": ("reference",), "quran_text": ("text",), "hadith_search": ("text",),
          "tafsir": ("reference", "book"), "hadeethenc_hadith": ("item_id",),
          "islamhouse_item": ("item_id", "language")}


def check(plan: RetrievalPlan, claims: dict[str, dict[str, Any]]) -> list[str]:
    errors = [f"duplicate request id {r}" for r in duplicates([r.request_id for r in plan.requests])]
    if len(plan.requests) > MAX_REQUESTS:
        errors.append(f"at most {MAX_REQUESTS} requests (found {len(plan.requests)})")
    for request in plan.requests:
        claim = claims.get(request.claim_id)
        if claim is None or claim["basis"] != "source":
            errors.append(f"{request.request_id}: {request.claim_id} is not a source claim of the decomposition")
        missing = [f for f in FIELDS[request.tool] if getattr(request, f) in (None, "")]
        if missing:
            errors.append(f"{request.request_id}: {request.tool} needs {', '.join(missing)}")
        if request.tool == "tafsir" and request.reference and ":" not in request.reference:
            errors.append(f"{request.request_id}: tafsir needs one verse as surah:ayah")
    return errors


async def _execute(tools: E.SourceTools, request: RetrievalRequest) -> list[dict[str, Any]]:
    common = {"claim_id": request.claim_id, "request_id": request.request_id, "tool": request.tool}
    if request.tool in ("quran_reference", "quran_text"):
        if request.tool == "quran_reference":
            references = [E.canonical_reference(tools.mushaf, request.reference or "")]
        else:
            references = E.locate_text(tools.mushaf, request.text or "")
            if not references:
                raise RecordNotFound("mushaf", "the text does not occur verbatim in the canonical mushaf")
        bindings = await tools.scripture(references)
        return [c for reference in references for c in E.quran_candidates(bindings, reference, **common)]
    if request.tool == "hadith_search":
        records = (await tools.hadith_search(request.text or ""))[:E.MAX_HADITH_RESULTS]
        if not records:
            raise RecordNotFound("dorar", "no hadith matched the search text")
        return [E.hadith_candidate(r, claim_id=request.claim_id, request_id=request.request_id, tool=request.tool)
                for r in records]
    if request.tool == "tafsir":
        surah, ayah = (int(x) for x in (request.reference or "").split("-")[0].split(":"))
        return [E.plain_candidate(await tools.tafsir(surah, ayah, request.book or "mukhtasar"), **common)]
    if request.tool == "hadeethenc_hadith":
        return [E.plain_candidate(await tools.hadeethenc(request.item_id or "", request.language or "ar"), **common)]
    return [E.plain_candidate(await tools.islamhouse(request.item_id or "", request.language or "ar"), **common)]


OUTCOMES: tuple[tuple[type[BaseException], str], ...] = (
    (ProviderNotConfigured, "not_configured"), (RecordNotFound, "not_found"), (ReferenceNotFound, "not_found"),
    (OperationUnsupported, "unsupported"), (CapabilityMismatch, "mismatch"), (SourceChanged, "mismatch"),
    (ValueError, "invalid_request"))


async def gather(tools: E.SourceTools, plan: RetrievalPlan) -> tuple[list[dict[str, Any]], list[E.Failure]]:
    candidates: list[dict[str, Any]] = []
    failures: list[E.Failure] = []
    for request in plan.requests:
        try:
            found = await _execute(tools, request)
        except tuple(kind for kind, _ in OUTCOMES) as exc:   # UpstreamUnavailable propagates: the stage retries
            outcome = next(code for kind, code in OUTCOMES if isinstance(exc, kind))
            failures.append(E.Failure(request.request_id, request.claim_id, request.tool, outcome, str(exc)))
            continue
        candidates.extend(found)
    # The English binding of a Dorar hadith is a HadeethEnc card with the identical Arabic, retrieved for the
    # same claim (as in the gold import's translation binding); without one the English evidence has no translation.
    cards: dict[str, list[Any]] = {}
    for candidate in candidates:
        if candidate["provider"] == "hadeethenc":
            cards.setdefault(candidate["claim_id"], []).append(E.load_record(candidate["records"][0]))
    rebound = []
    for candidate in candidates:
        if candidate["provider"] == "dorar" and candidate["citable"] and candidate["claim_id"] in cards:
            candidate = E.hadith_candidate(E.load_record(candidate["records"][0]), claim_id=candidate["claim_id"],
                                           request_id=candidate["request_id"], tool=candidate["tool"],
                                           translations=cards[candidate["claim_id"]])
        rebound.append(candidate)
    for index, candidate in enumerate(rebound, start=1):
        candidate["candidate_id"] = f"k{index}"
    return rebound, failures


async def run(ctx: StageContext) -> StageResult:
    decomposition = accepted(ctx, "decompose")
    claims = {c["claim_id"]: c for c in decomposition["claims"]}
    source_claims = [c for c in decomposition["claims"] if c["basis"] == "source"]
    if not source_claims:
        return StageResult(output={"requests": [], "candidates": [], "failures": []},
                           inputs={"source_claims": []}, notes={"agent_issues": []})
    data = {"plan": ctx.run.plan, "source_claims": source_claims,
            "previous_attempt_issues": ctx.run.previous_issues}
    result = await ctx.llm.structured("factory_retrieve", data, ledger=ctx.ledger, call_key=ctx.call_key)
    plan = parse(RetrievalPlan, result.data, "retrieval_invalid")
    require(check(plan, claims), "retrieval_invalid")
    make_tools = ctx.services.get("sources")
    if make_tools is None:
        raise StageBlocked("source_tools_unavailable", "this worker has no source tools configured")
    tools: E.SourceTools = make_tools()
    try:
        candidates, failures = await gather(tools, plan)
    finally:
        await tools.aclose()
    covered = {c["claim_id"] for c in candidates}
    blocked = sorted({f.claim_id for f in failures if f.outcome == "not_configured"} - covered)
    if blocked:
        providers = sorted({f.tool for f in failures if f.outcome == "not_configured" and f.claim_id in blocked})
        raise StageBlocked("sources_not_configured", f"claims {blocked} have no evidence because {providers} are "
                           "not approved or configured in this environment (O-03)")
    output = {"requests": plan.model_dump(mode="json")["requests"], "candidates": candidates,
              "failures": [f.as_dict() for f in failures]}
    return StageResult(output=output, inputs=data,
                       notes={"agent_issues": plan.issues, "candidates": len(candidates), "failures": len(failures),
                              "unsupported_claims": sorted({c["claim_id"] for c in source_claims} - covered)})
