"""Independent Phase 9 checks and a complete sentence inventory for the grounding verifier."""
from __future__ import annotations

import re
from datetime import datetime
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.factory.evidence import public_source
from app.models import Source
from app.raqeeb import pipeline, source_checks
from app.raqeeb.retrieval import Pool, Tools, hadith_quote, quran_quote
from app.raqeeb.schemas import Quote
from app.sources.errors import RecordNotFound, SourceError
from app.sources.records import Part, Retrieval, SourceRecord


def understood(answer: dict[str, Any]) -> dict[str, Any]:
    """Semantic learner input only; private attachment identities never reach a judge."""
    value = answer.get("understood_input") or {}
    document = value.get("document")
    return {"transcript": value.get("transcript"),
        "images": [{k: image[k] for k in ("extracted_text", "description")}
                   for image in value.get("images", [])],
        "document": {"summary": document["summary"]} if document else None}


def source_record(row: Source) -> SourceRecord:
    raw = row.raw
    request = raw["request"]
    return SourceRecord(row.provider, str(row.provider_record_id), row.kind, row.title, row.reference,
        row.excerpt, row.url, str(row.adapter_version), Retrieval(request["tool"], request["operation"],
            request["arguments"], raw["response"], raw["response_sha256"],
            datetime.fromisoformat(raw["retrieved_at"])),
        tuple(Part(p["role"], p["provider"], p["record_id"], p.get("version"), p.get("sha256"),
                   tuple(p.get("checks", [])), p.get("meta", {})) for p in raw["parts"]), raw["data"])


async def inspect(db: AsyncSession, answer: dict[str, Any], tools: Tools, language: str
                  ) -> tuple[list[str], list[dict[str, Any]]]:
    issues, verified_sources, pool, aliases = [], [], Pool(), {}
    for citation in answer.get("citations", []):
        supplied = citation["source"]
        row = await db.get(Source, supplied["source_id"])
        if row is None:
            issues.append("hallucinated_source")
            continue
        try:
            original = source_record(row)
            resolved = await source_checks.fresh(original, tools, language, pool)
            actual = public_source(resolved) | {"displayed": False, "display_role": None}
            aliases[row.id] = actual["source_id"]
            if actual != supplied | {"source_id": actual["source_id"]}:
                issues.append("wrong_source_binding")
            if source_checks.identity(original) != source_checks.identity(resolved):
                issues.append("source_changed")
            else:
                verified_sources.append(citation)
        except RecordNotFound:
            issues.append("source_not_found")
        except SourceError:
            issues.append("source_unavailable")
        except (ValueError, KeyError, TypeError):
            issues.append("unverified_evidence")
    # Recompute verification cards from their actual quotations, not the supplied verdict/grade.
    rebound = source_checks.rebind(answer, aliases)
    for block in rebound.get("blocks", []):
        if block["type"] == "verification":
            for item in block["items"]:
                try:
                    quote = Quote(text=item["quote_text"], kind_guess=item["detected_kind"])
                    if quote.kind_guess == "quran":
                        expected = await quran_quote(pool, tools, quote, language)
                        if item["status"] != expected["status"] or item["correct_text"] != expected["correct_text"]:
                            issues.append("wrong_scripture")
                    elif quote.kind_guess == "hadith":
                        expected = await hadith_quote(pool, tools, quote, language)
                        if item["hadith_grade"] != expected["hadith_grade"]:
                            issues.append("wrong_hadith_grade")
                        if set(item["source_ids"]) != set(expected["source_ids"]):
                            issues.append("wrong_hadith_attribution")
                    pool.items.append(item if quote.kind_guess == "claim" else expected)
                except SourceError:
                    issues.append("source_unavailable")
    category = answer.get("classification", {}).get("question_class", answer.get("question_class", "general_knowledge"))
    if not answer.get("abstained", True):
        core = {"blocks": [b for b in rebound.get("blocks", []) if b["type"] != "referral"],
                "citations": rebound.get("citations", [])}
        # Learner terms are mechanically assigned; convert them to visible text for evaluation.
        def plain(node: Any) -> Any:
            if isinstance(node, dict):
                if node.get("type") == "term":
                    return {"type": "text", "text": node["text"]}
                return {k: plain(v) for k, v in node.items()}
            return [plain(v) for v in node] if isinstance(node, list) else node
        for finding in pipeline.guard(plain(core), pool, category):
            issues.append("wrong_scripture" if finding == "unverified_evidence" and any(
                b.get("evidence", {}).get("kind") == "quran" for b in core["blocks"])
                else "unverified_evidence" if finding == "unverified_evidence" else finding)
    return sorted(set(issues)), verified_sources


def inventory(answer: dict[str, Any]) -> list[dict[str, Any]]:
    """Every prose/attribution/verification/evidence sentence, with deterministic boundaries."""
    texts: list[dict[str, Any]] = []
    citations = {c["source"]["source_id"]: c["ref"] for c in answer.get("citations", [])}
    def collect(node: Any, refs: list[int]) -> None:
        if isinstance(node, dict):
            if "spans" in node:
                refs = [s["ref"] for s in node["spans"] if s.get("type") == "citation"]
            if "evidence_id" in node:
                refs = [citations[node["evidence_id"]]] if node["evidence_id"] in citations else []
            if "source_ids" in node:
                refs = [citations[s] for s in node["source_ids"] if s in citations]
            if node.get("type") in ("text", "strong", "term"):
                texts.append({"text": str(node.get("text", "")), "citation_refs": refs})
            for key, value in node.items():
                if key in ("text_uthmani", "text_ar", "translation", "holder", "quote_text") and isinstance(value, str):
                    texts.append({"text": value, "citation_refs": refs})
                elif key != "citations":
                    collect(value, refs)
        elif isinstance(node, list):
            for value in node:
                collect(value, refs)
    collect(answer.get("blocks", []), [])
    return [{"text": s.strip(), "citation_refs": value["citation_refs"]} for value in texts
            for s in re.split(r"(?<=[.!?؟])\s+|\n+", value["text"]) if s.strip()]


def sentences(answer: dict[str, Any]) -> list[str]:
    return [s["text"] for s in inventory(answer)]
