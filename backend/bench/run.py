"""Private evaluator: python -m bench.run run|finalize --dataset .private/eval/raqeeb --run-id UUID.

Live runs require a separate qabas_bench_* database, explicit private specialist gold and provider credentials.
Public CI constructs deterministic drivers/batches directly; this CLI never selects a fake production provider.
"""
from __future__ import annotations

import argparse
import asyncio
import hashlib
import json
import uuid
from pathlib import Path
from typing import Any

import yaml
from sqlalchemy import text
from sqlalchemy.pool import NullPool

from app.config import BACKEND_DIR, get_settings
from app.llm.batches import Batches
from app.llm.budget import Ledger
from app.llm.client import AnthropicClient
from app.llm.models import model_policy
from app.llm.prompts import all_prompts
from app.raqeeb.memory import versions
from app.runtime import Resources
from bench import engine
from bench.dataset import load
from bench.native import Native


def identities(resources: Resources) -> dict[str, Any]:
    policy, _ = versions(resources)
    effort = model_policy(resources.settings.llm_model_strong, resources.settings).capabilities.effort or []
    digest = hashlib.sha256()
    for path in sorted((BACKEND_DIR / "app" / "sources").rglob("*.py")):
        digest.update(path.relative_to(BACKEND_DIR).as_posix().encode())
        digest.update(path.read_bytes())
    return {"policy": policy, "prompts": {p.id: f"{p.version}:{p.sha256}" for p in all_prompts()},
        "adapters": {"phase9_source_code": digest.hexdigest(), "memory": "guarded/1", "inputs": "isolated/1"},
        "models": {"raqeeb_strong": resources.settings.llm_model_strong,
                   "baseline_llm": resources.settings.llm_model_strong, "judge": resources.settings.llm_model_strong,
                   "judge_effort": "medium" if "medium" in effort else "not_sent",
                   "writer_effort": "high" if "high" in effort else "not_sent",
                   "fast": resources.settings.llm_model_fast,
                   "speech": resources.settings.stt_model, "embeddings": "BAAI/bge-m3"}}


async def execute(args: argparse.Namespace) -> dict[str, Any]:
    resources = Resources.create(get_settings(), poolclass=NullPool)
    try:
        native = Native(resources, args.dataset)
        load(args.dataset)  # fail before any paid calls if private sets/approval are unavailable
        state = engine.State(args.dataset, args.run_id, synthetic=False)
        async with resources.engine.connect() as connection:
            lock = "benchmark:" + str(args.run_id)
            acquired = await connection.scalar(text("SELECT pg_try_advisory_lock(hashtextextended(:k, 0))"),
                                               {"k": lock})
            await connection.commit()
            if not acquired:
                raise ValueError("this evaluation already has an active runner")
            try:
                if args.command == "run":
                    identity = identities(resources)
                    client = AnthropicClient(resources.settings)
                    try:
                        report = await engine.run(args.dataset, state, native, Batches(client),
                                                  Ledger(args.budget_tokens), identity)
                    finally:
                        await client.aclose()
                    return {"run_id": report["run_id"], "stage": "awaiting_manual_review",
                            "release_approved": False, "private_report": str(state.root / "judged.json")}
                report = json.loads((state.root / "judged.json").read_text(encoding="utf-8"))
                labels = json.loads(args.labels.read_text(encoding="utf-8"))
                policy = yaml.safe_load(args.policy.read_text(encoding="utf-8"))
                signoff = json.loads(args.signoff.read_text(encoding="utf-8")) if args.signoff else None
                return await engine.finalize(resources, state, report, labels, policy, signoff)
            finally:
                await connection.execute(text("SELECT pg_advisory_unlock(hashtextextended(:k, 0))"), {"k": lock})
                await connection.commit()
    finally:
        await resources.close()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("run", "finalize"))
    parser.add_argument("--dataset", type=Path, default=BACKEND_DIR / ".private" / "eval" / "raqeeb")
    parser.add_argument("--run-id", type=uuid.UUID, required=True)
    parser.add_argument("--budget-tokens", type=int, default=6_000_000)
    parser.add_argument("--labels", type=Path)
    parser.add_argument("--policy", type=Path, default=BACKEND_DIR / "content" / "raqeeb_release_policy.yaml")
    parser.add_argument("--signoff", type=Path)
    args = parser.parse_args()
    if args.budget_tokens <= 0 or (args.command == "finalize" and args.labels is None):
        parser.error("a positive budget and manual labels for finalization are required")
    result = asyncio.run(execute(args))
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
