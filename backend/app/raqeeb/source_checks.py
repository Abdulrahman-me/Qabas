"""Re-resolve identities through Phase 9, never through a judge's religious memory."""
from __future__ import annotations

from typing import Any

from app.raqeeb.retrieval import Pool, Tools, hadith_evidence
from app.sources.errors import OperationUnsupported
from app.sources.records import SourceRecord, canonical_json, sha256_text


def identity(record: SourceRecord) -> str:
    # Text alone misses changed grades, narrator/book attribution, translation or dataset versions.
    return sha256_text(canonical_json({"provider": record.provider, "record": record.provider_record_id,
        "text": record.text_sha256, "adapter": record.adapter_version, "data": record.data,
        "title": record.title, "reference": record.reference, "url": record.url,
        "authority": [{"role": p.role, "provider": p.provider, "record": p.record_id, "version": p.version,
                       "dataset": p.sha256 if p.provider == "mushaf" else None}
                      for p in record.parts if p.role in
                      ("text_authority", "translation", "explanation", "grade")]}))


async def fresh(record: SourceRecord, tools: Tools, language: str, pool: Pool) -> SourceRecord:
    if record.kind == "quran" and record.provider == "quran_com":
        args = record.retrieval.arguments
        if args.get("word_range"):
            raise OperationUnsupported(record.provider, "segment refresh requires an exact verified binding")
        ayahs = args["ayah_range"]
        verified = await tools.quran(f"{args['surah']}:{ayahs[0]}-{ayahs[1]}", language)
        key = pool.add(verified.source)
        pool.evidence[key] = verified.evidence.model_dump(mode="json")
        pool.identified = True
        return verified.source
    resolver = getattr(tools, "resolve", None)
    if resolver is None:
        raise OperationUnsupported(record.provider, "identity refresh is unavailable")
    resolved: SourceRecord = await resolver(record, language)
    key = pool.add(resolved)
    if resolved.provider == "dorar" and resolved.kind == "hadith" and resolved.retrieval.operation != "sharh":
        evidence = hadith_evidence(resolved)
        if evidence is not None:
            pool.evidence[key] = evidence
            pool.identified = True
    return resolved


def rebind(node: Any, aliases: dict[str, str]) -> Any:
    if isinstance(node, dict):
        return {k: aliases.get(v, v) if k in ("source_id", "evidence_id") and isinstance(v, str)
                else [aliases.get(s, s) for s in v] if k == "source_ids" and isinstance(v, list)
                else rebind(v, aliases) for k, v in node.items()}
    if isinstance(node, list):
        return [rebind(v, aliases) for v in node]
    return node
