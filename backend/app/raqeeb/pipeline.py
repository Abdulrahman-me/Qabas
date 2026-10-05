"""Raqeeb's bounded text pipeline; all model calls use Phase 11, all evidence uses Phase 9."""

from __future__ import annotations

import copy
from collections.abc import Awaitable, Callable
from typing import Any

from app.llm.budget import Ledger
from app.llm.client import LLMClient
from app.raqeeb import policy
from app.raqeeb import schemas as S
from app.raqeeb.retrieval import Pool, Tools, retrieve
from app.sources import grades
from app.sources.records import canonical_json, sha256_text

Stage = Callable[[str], Awaitable[None]]
Save = Callable[[dict[str, Any]], Awaitable[None]]


class Calls:
    """Committed checkpoints are reused only with identical inputs and registered prompt digests."""
    def __init__(self, client: LLMClient, ledger: Ledger, trace: dict[str, Any], save: Save) -> None:
        self.client, self.ledger, self.trace, self.save = client, ledger, trace, save

    async def __call__(self, prompt: str, data: dict[str, Any], *, key: str | None = None) -> dict[str, Any]:
        from app.llm.prompts import get_prompt
        identity = get_prompt(prompt).identity()
        fingerprint = sha256_text(canonical_json({"data": data, "prompt": identity}))
        call_key = key or prompt
        previous = self.trace.setdefault("calls", {}).get(call_key)
        if previous is not None and previous["fingerprint"] == fingerprint:
            return copy.deepcopy(previous["output"])
        try:
            result = await self.client.structured(prompt, data, ledger=self.ledger, call_key=call_key)
            self.trace["calls"][call_key] = {"fingerprint": fingerprint, "output": result.data,
                                             "prompt": result.prompt, "model": result.model}
            return result.data
        finally:
            self.trace["cost"] = self.ledger.summary()
            await self.save(self.trace)


def support_sources(pool: Pool, category: str) -> set[str]:
    allowed = set()
    for key, record in pool.records.items():
        if record.provider == "dorar" and record.retrieval.operation != "sharh" and not grades.citable(
                grades.classify(str(record.data.get("grade_label", "")))):
            continue
        if category == "text_explanation" and not (record.kind == "tafsir" or
                record.provider == "hadeethenc" or record.retrieval.operation == "sharh"):
            continue
        if category in ("differing_opinions", "doubt_or_deep_creed") and (
                record.provider != "islamhouse" or record.kind not in ("article", "fatwa")):
            continue
        allowed.add(key)
    return allowed


def spans_in(node: Any) -> list[dict[str, Any]]:
    if isinstance(node, dict):
        if node.get("type") in ("text", "strong", "term", "citation"):
            return [node]
        return [s for v in node.values() for s in spans_in(v)]
    if isinstance(node, list):
        return [s for v in node for s in spans_in(v)]
    return []


def guard(core: dict[str, Any], pool: Pool, category: str) -> list[str]:
    """Code guard: sources, grades, evidence and allowed block shapes are immutable tool-backed inputs."""
    issues = []
    refs, source_ids = set(), set()
    expected = {s["source_id"]: s for s in pool.sources()}
    for citation in core["citations"]:
        source = citation["source"]
        if citation["ref"] in refs or source["source_id"] not in expected or source != expected[source["source_id"]]:
            issues.append("invalid_source_binding")
        refs.add(citation["ref"])
        source_ids.add(source["source_id"])
    for s in spans_in(core["blocks"]):
        if s["type"] == "citation" and s["ref"] not in refs:
            issues.append("unknown_citation")
        if s["type"] == "term":
            issues.append("model_term_binding")  # term identity is assigned by the level service, not the writer
    allowed = {"paragraph", "evidence"}
    if category == "verification":
        allowed = {"verification", "paragraph"}
    elif category == "differing_opinions":
        allowed = {"differing_views"}
    evidence_count = 0
    for block in core["blocks"]:
        if block["type"] not in allowed:
            issues.append("unexpected_block")
        if block["type"] == "paragraph" and not any(s["type"] == "citation" for s in block["spans"]):
            issues.append("uncited_paragraph")
        if block["type"] == "evidence":
            evidence_count += 1
            e = block["evidence"]
            if pool.evidence.get(e["evidence_id"]) != e or e["evidence_id"] not in source_ids:
                issues.append("unverified_evidence")
        if block["type"] == "verification" and (block["items"] != pool.items or any(
                set(i["source_ids"]) - source_ids for i in block["items"])):
            issues.append("changed_verification")
        if block["type"] == "differing_views":
            views = block["views"]
            if len(views) < 2 or len({v["holder"].strip() for v in views}) < 2:
                issues.append("insufficient_views")
            for view in views:
                bound = {c["source"]["source_id"] for c in core["citations"]
                         if c["ref"] in {s["ref"] for s in view["spans"] if s["type"] == "citation"}}
                if not view["source_ids"] or set(view["source_ids"]) != bound or bound - source_ids:
                    issues.append("unbound_view")
    if not core["blocks"]:
        issues.append("empty_answer")
    if category == "verification" and not any(b["type"] == "verification" for b in core["blocks"]):
        issues.append("missing_verification")
    if category == "general_knowledge" and evidence_count > 1:
        issues.append("too_many_evidence")
    if category == "text_explanation" and evidence_count == 0:
        issues.append("missing_identified_text")
    return sorted(set(issues))


async def adapt(core: dict[str, Any], calls: Calls, profile: dict[str, Any], *, key: str) -> dict[str, Any]:
    paragraphs = [b for b in core["blocks"] if b["type"] == "paragraph"]
    if not paragraphs:
        return core
    rewrite = S.Rewritten.model_validate(await calls("raqeeb_rewrite", {
        "paragraphs": paragraphs, "profile": profile}, key=f"{key}:rewrite")).model_dump(mode="json")
    proposed = rewrite["paragraphs"]
    old_refs = [[s["ref"] for s in p["spans"] if s["type"] == "citation"] for p in paragraphs]
    new_refs = [[s["ref"] for s in p["spans"] if s["type"] == "citation"] for p in proposed]
    if len(proposed) != len(paragraphs) or old_refs != new_refs:
        return core
    check = S.RewriteCheck.model_validate(await calls("raqeeb_rewrite_check", {
        "original": paragraphs, "adapted": proposed}, key=f"{key}:rewrite_check"))
    if not check.same_meaning or check.new_claims:
        return core
    adapted = copy.deepcopy(core)
    it = iter(proposed)
    adapted["blocks"] = [next(it) if b["type"] == "paragraph" else b for b in core["blocks"]]
    return adapted


async def run(question: str, snapshot: dict[str, Any], calls: Calls, tools: Tools, stage: Stage) -> dict[str, Any]:
    language = snapshot["profile"]["language"]
    await stage("reading_inputs")
    await stage("classifying")
    if policy.matches(question, "sensitive_human"):
        classified = S.Classified(question_class="sensitive_human", confidence=1, language=language,
                                  quotes=[], retrieval_queries=[], concept_hint=None, standalone=False,
                                  canonical_question="")
    else:
        classified = S.Classified.model_validate(await calls("raqeeb_classify", {
            "question": question, "history": snapshot["history"], "context": snapshot["context"],
            "language": language}))
        if policy.matches(question, "personal_fatwa") and (classified.confidence < .6 or
                classified.question_class not in ("personal_fatwa", "sensitive_human")):
            classified.question_class = "personal_fatwa"
        if classified.confidence < .6 and not classified.standalone:
            for protective in ("sensitive_human", "personal_fatwa"):
                if any(policy.matches(h["text"], protective) for h in snapshot["history"] if h["role"] == "user"):
                    classified.question_class = protective
                    break
        # Exact input binding: an injected classifier cannot fabricate quotes for verification or retrieval.
        if len(classified.quotes) > 10 or any(not q.text.strip() or q.text not in question for q in classified.quotes):
            raise ValueError("classifier quotes do not bind to submitted text")
    category = classified.question_class
    calls.trace["classification"] = classified.model_dump(mode="json")
    result: dict[str, Any] = {"understood_input": {"transcript": None, "images": [], "document": None},
        "classification": {"question_class": category, "label": policy.label(category, language)},
        "abstained": True, "blocks": policy.abstention(category, language), "citations": [],
        "terms": {}, "suggested_lessons": [], "feedback": None}
    def finish(value: dict[str, Any], pool: Pool | None = None) -> dict[str, Any]:
        # Even offline templates and deterministic cards pass a final code guard. Only generated prose
        # needs a fast-model judgment; a hosted outage must not suppress human-support referrals.
        static = value["abstained"] and value["blocks"] == policy.abstention(category, language)
        if static:
            if value["citations"]:
                raise ValueError("static referral cannot carry model citations")
        else:
            assert pool is not None
            referrals = [b for b in value["blocks"] if b["type"] == "referral"]
            if any(b != policy.referral("specialist", language) for b in referrals):
                raise ValueError("unapproved referral")
            issues = guard({"blocks": [b for b in value["blocks"] if b["type"] != "referral"],
                            "citations": value["citations"]}, pool, category)
            if issues:
                raise ValueError("final deterministic guard failed")
        calls.trace["final_guard"] = {"passed": True, "mode": "code_owned" if static else "tool_bound"}
        return value
    if category in ("personal_fatwa", "sensitive_human", "out_of_scope"):
        return finish(result)
    await stage("retrieving")
    from app.factory.evidence import dump_record, load_record
    retrieval_key = sha256_text(canonical_json({"classified": classified.model_dump(mode="json"),
                                               "language": language}))
    previous_pool = calls.trace.get("retrieval_checkpoint")
    if previous_pool is not None and previous_pool["fingerprint"] == retrieval_key:
        pool = Pool(records={k: load_record(r) for k, r in previous_pool["records"].items()},
                    evidence=copy.deepcopy(previous_pool["evidence"]), items=copy.deepcopy(previous_pool["items"]),
                    issues=copy.deepcopy(previous_pool["issues"]), identified=previous_pool["identified"])
    else:
        pool = await retrieve(classified, tools, language)
        calls.trace["retrieval_checkpoint"] = {"fingerprint": retrieval_key,
            "records": {k: dump_record(r) for k, r in pool.records.items()}, "evidence": pool.evidence,
            "items": copy.deepcopy(pool.items), "issues": pool.issues, "identified": pool.identified}
    calls.trace["retrieved"] = [dump_record(r) for r in pool.records.values()]
    calls.trace["source_issues"] = pool.issues
    await calls.save(calls.trace)
    await stage("verifying")
    candidates = support_sources(pool, category)
    verified = S.Verified.model_validate(await calls("raqeeb_verify", {
        "question": question, "sources": [s for s in pool.sources() if s["source_id"] in candidates],
        "verification": pool.items})) if candidates else S.Verified(claims=[])
    supported = [c.model_dump(mode="json") for c in verified.claims if c.supported and c.source_ids
                 and not set(c.source_ids) - candidates]
    calls.trace["verified"] = verified.model_dump(mode="json")
    if category == "verification":
        if not pool.items:
            return finish(result, pool)
        # A claim card never becomes a verdict without a direct matching source-backed verifier finding.
        for item in pool.items:
            if item["detected_kind"] == "claim":
                direct = [c for c in supported if c["text"] == item["quote_text"]]
                if direct:
                    item["source_ids"] = list(dict.fromkeys(s for c in direct for s in c["source_ids"]))
                    note = ("Direct source support was found; specialist review remains appropriate."
                            if language == "en" else "وُجد دعم مباشر من المصدر؛ تبقى مراجعة المختص مناسبة.")
                    item["note"] = policy.span(note)
        result["blocks"] = [{"type": "verification", "items": pool.items}]
        result["citations"] = [{"ref": n, "source": s} for n, s in enumerate(pool.sources(), 1)]
        def needs_human(item: dict[str, Any]) -> bool:
            return item["status"] == "needs_specialist" or (item["hadith_grade"] is not None and
                                                           item["hadith_grade"]["grade_category"] == "other")
        result["abstained"] = all(needs_human(i) for i in pool.items)
        if any(needs_human(i) for i in pool.items):
            result["blocks"].append(policy.referral("specialist", language))
        # Authoritative cards require no model-authored prose. The optional writer is still subject to the guard.
        if not supported:
            return finish(result, pool)
    elif not supported or (category == "text_explanation" and not pool.identified):
        return finish(result, pool)
    for attempt in range(2):
        await stage("writing")
        key = f"answer:{attempt}"
        previous_findings = [] if attempt == 0 else calls.trace.get("guard_findings", [])
        core = S.Core.model_validate(await calls("raqeeb_write", {
            "question": question, "language": language, "question_class": category,
            "history": snapshot["history"], "supported_claims": supported,
            **pool.model_data(), "guard_findings": previous_findings}, key=f"{key}:write"
        )).model_dump(mode="json")
        await stage("adapting")
        core = await adapt(core, calls, snapshot["profile"], key=key)
        issues = guard(core, pool, category)
        model_guard = S.Guarded.model_validate(await calls("raqeeb_guard", {
            "question": question, "question_class": category, "answer": core,
            "supported_claims": supported, "sources": pool.sources(), "verification": pool.items,
            "canonical_evidence": list(pool.evidence.values())}, key=f"{key}:guard"))
        issues += model_guard.violations
        attempts = [a for a in calls.trace.get("guard_attempts", []) if a["attempt"] != attempt]
        calls.trace["guard_attempts"] = [*attempts, {"attempt": attempt, "findings": issues}]
        calls.trace["guard_findings"] = issues
        await calls.save(calls.trace)
        if issues:
            continue
        result.update(abstained=False, blocks=core["blocks"], citations=core["citations"])
        if category == "differing_opinions" or (category == "verification" and any(needs_human(i) for i in pool.items)):
            result["blocks"].append(policy.referral("specialist", language))
        calls.trace["core"] = copy.deepcopy(core)
        return finish(result, pool)
    if category == "verification":
        # Keep valid deterministic cards when optional prose fails; never discard verified grades in favor of guesses.
        return finish(result, pool)
    return finish({**result, "abstained": True, "blocks": policy.abstention(category, language), "citations": []}, pool)
