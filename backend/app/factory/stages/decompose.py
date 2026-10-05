"""Stage 2 ``decompose`` — Objective Decomposer and Event Extractor (factory §13.1, §13.2 claim basis).

The approved plan and arc become the atomic assertions the lesson needs. Code checks that every claim belongs to
an approved arc step, that a reasoning claim uses one of the plan's approved reasoning tools (and a source claim
none), and that story events are claims of a story step, in order.
"""

from __future__ import annotations

from app.factory.orchestrator import StageContext, StageResult
from app.factory.stage_models import Decomposition
from app.factory.stages.common import approved_plan, duplicates, parse, require

MAX_CLAIMS = 40


def check(decomposition: Decomposition, plan: dict[str, object]) -> list[str]:
    errors: list[str] = []
    arc = plan["lesson_arc"]
    assert isinstance(arc, dict)
    steps = {s["step_id"]: s["technique"] for s in arc["steps"]}
    tools = {use["tool"] for use in plan["reasoning_tools"]}  # type: ignore[attr-defined]
    claims = decomposition.claims
    if not claims:
        errors.append("the lesson needs at least one claim; framing alone teaches nothing")
    if len(claims) > MAX_CLAIMS:
        errors.append(f"at most {MAX_CLAIMS} claims per lesson (found {len(claims)})")
    errors += [f"duplicate claim id {c}" for c in duplicates([c.claim_id for c in claims])]
    for claim in claims:
        where = claim.claim_id
        if claim.arc_step_id not in steps:
            errors.append(f"{where}: arc step {claim.arc_step_id} is not in the approved arc")
        if claim.basis == "reasoning":
            if claim.reasoning_tool is None:
                errors.append(f"{where}: a reasoning claim names its approved reasoning tool")
            elif claim.reasoning_tool not in tools:
                errors.append(f"{where}: reasoning tool {claim.reasoning_tool} is not approved in the plan")
        elif claim.reasoning_tool is not None:
            errors.append(f"{where}: a source claim carries no reasoning tool")
        if claim.kind == "reasoning" and claim.basis != "reasoning":
            errors.append(f"{where}: kind reasoning needs basis reasoning")
    ids = {c.claim_id: c for c in claims}
    events = decomposition.story_events
    errors += [f"duplicate event id {e}" for e in duplicates([e.event_id for e in events])]
    by_step: dict[str, list[int]] = {}
    for event in events:
        owner = ids.get(event.claim_id)
        if owner is None:
            errors.append(f"{event.event_id}: names unknown claim {event.claim_id}")
            continue
        if steps.get(event.arc_step_id) != "story":
            errors.append(f"{event.event_id}: story events belong to a sourced story step")
        if owner.arc_step_id != event.arc_step_id or owner.basis != "source":
            errors.append(f"{event.event_id}: an event is a source claim of the same story step")
        by_step.setdefault(event.arc_step_id, []).append(event.order)
    for step, orders in by_step.items():
        if sorted(orders) != list(range(len(orders))):
            errors.append(f"{step}: event order must run 0..n-1 without gaps")
    return errors


async def run(ctx: StageContext) -> StageResult:
    plan = approved_plan(ctx)
    data = {"plan": plan, "brief": ctx.run.brief, "previous_attempt_issues": ctx.run.previous_issues}
    result = await ctx.llm.structured("factory_decompose", data, ledger=ctx.ledger, call_key=ctx.call_key)
    decomposition = parse(Decomposition, result.data, "decomposition_invalid")
    require(check(decomposition, plan), "decomposition_invalid")
    output = decomposition.model_dump(mode="json")
    return StageResult(output=output, inputs=data, notes={"agent_issues": decomposition.issues})
