"""Bounded, resumable private Unit 0 plan translation; never approves content or edits originals."""
from __future__ import annotations

import argparse
import asyncio
import json
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.config import get_settings
from app.content.importers.unit0 import digest
from app.llm.budget import Ledger
from app.llm.errors import LLMError
from app.llm.factory_client import factory_client


def fields(record: dict[str, Any]) -> list[tuple[dict[str, Any], str, str]]:
    plan = record["plan"]
    arc = plan["lesson_arc"]
    candidates = [(arc, "rationale", "arc/rationale")]
    candidates += [(s, "experience", f"arc/{s['step_id']}") for s in arc["steps"]]
    candidates += [(s, "justification", f"tool/{n}") for n, s in enumerate(plan["reasoning_tools"])]
    return [(parent, key, ident) for parent, key, ident in candidates if isinstance(parent[key], str)]


def apply_translations(record: dict[str, Any], result: dict[str, Any]) -> None:
    targets = fields(record)
    translations = result["translations"]
    ids = [t["id"] for t in translations]
    if len(ids) != len(set(ids)) or set(ids) != {ident for _, _, ident in targets}:
        raise ValueError("translation ids must match all supplied fields exactly")
    by_id = {t["id"]: t["ar"].strip() for t in translations}
    if not all(by_id.values()):
        raise ValueError("empty Arabic translation")
    for parent, key, ident in targets:
        parent[key] = {"ar": by_id[ident], "en": parent[key]}


async def execute(source: Path, out: Path) -> int:
    if ".private" not in out.resolve().parts:
        raise ValueError("translated authoring and model outputs must remain private")
    out.mkdir(parents=True, exist_ok=True)
    lessons = out / "lessons"
    receipts = out / "provenance"
    lessons.mkdir(exist_ok=True)
    receipts.mkdir(exist_ok=True)
    client = factory_client(get_settings())
    failed = 0
    try:
        for path in sorted(source.glob("u0_l*.json")):
            original = json.loads(path.read_text(encoding="utf-8"))
            target = lessons / path.name
            provenance = receipts / (path.stem + ".json")
            if target.exists() and provenance.exists():
                previous = json.loads(provenance.read_text(encoding="utf-8"))
                prepared = json.loads(target.read_text(encoding="utf-8"))
                if previous["source_digest"] == digest(original) and previous["prepared_digest"] == digest(prepared):
                    print(f"{path.stem}: retained private translation; human review still required", flush=True)
                    continue
                failed += 1
                print(f"{path.stem}: source or prepared digest changed; use a new private output directory",
                      flush=True)
                continue
            ledger = Ledger(budget_tokens=30_000)
            try:
                targets = fields(original)
                result = await client.structured("unit0_plan_text", {"texts": [
                    {"id": ident, "en": parent[key]} for parent, key, ident in targets]}, ledger=ledger)
                source_digest = digest(original)
                apply_translations(original, result.data)
                target.write_text(json.dumps(original, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
                provenance.write_text(json.dumps({"source_digest": source_digest,
                    "prepared_digest": digest(original), "prompt": result.prompt, "model": result.model,
                    "usage": ledger.summary(), "translated_fields": len(targets),
                    "review_status": "pending", "scientific_approval": False}, indent=2) + "\n", encoding="utf-8")
                print(f"{path.stem}: {len(targets)} plan fields translated; not approved", flush=True)
            except (LLMError, ValueError) as exc:
                failed += 1
                print(f"{path.stem}: blocked ({type(exc).__name__}); independent lessons continue", flush=True)
    finally:
        await client.aclose()
    return 2 if failed else 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    return asyncio.run(execute(args.source, args.out))


if __name__ == "__main__":
    sys.exit(main())
