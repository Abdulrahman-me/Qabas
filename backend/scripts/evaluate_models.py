"""Bilingual model validation for O-03 (Phase 11 skeleton; live calls, so never run in CI).

    uv run python scripts/evaluate_models.py --systems opus=claude-opus-5-5,haiku=claude-haiku-4-5 \
        [--cases .private/eval/llm/cases.jsonl] [--out var/llm-eval/report.json] [--budget-tokens 200000]
    uv run python scripts/evaluate_models.py --capabilities claude-opus-5-5 claude-haiku-4-5

Each system label runs every case with that model on both tiers, through the production adapter (structured
outputs, validation, refusal handling). ``--capabilities`` compares ``content/llm/models.yaml`` with the live Models
API. The evaluation sets themselves are private (D-19, ``backend/.private/eval/``); ``tests/llm/sample_cases.jsonl``
is only a neutral sample. Approval (status: approved, evaluator, date, report) is recorded in models.yaml by hand.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.config import BACKEND_DIR, get_settings
from app.llm.client import AnthropicClient, LLMClient
from app.llm.evaluation import evaluate, load_cases, write_report
from app.llm.models import load_models

DEFAULT_CASES = BACKEND_DIR / ".private" / "eval" / "llm" / "cases.jsonl"


async def capabilities(model_ids: list[str]) -> int:
    import anthropic

    settings = get_settings()
    if settings.anthropic_api_key is None:
        print("ANTHROPIC_API_KEY is not configured", file=sys.stderr)
        return 1
    client = anthropic.AsyncAnthropic(api_key=settings.anthropic_api_key.get_secret_value())
    declared = load_models()
    status = 0
    for model_id in model_ids:
        info = await client.models.retrieve(model_id)
        live = getattr(info, "capabilities", None)
        effort = getattr(live, "effort", None) if live is not None else None
        levels = [lvl for lvl in ("low", "medium", "high", "xhigh", "max")
                  if effort is not None and getattr(getattr(effort, lvl, None), "supported", False)]
        mine = declared[model_id].capabilities.effort if model_id in declared else None
        same = mine is None or set(mine) <= set(levels)
        status |= 0 if same else 1
        print(json.dumps({"model": model_id, "live_effort": levels, "declared_effort": mine, "consistent": same}))
    return status


async def run(args: argparse.Namespace) -> int:
    settings = get_settings()
    cases = load_cases(Path(args.cases))
    systems: dict[str, LLMClient] = {}
    for item in args.systems.split(","):
        label, model = item.split("=", 1)
        configured = settings.model_copy(update={"llm_model_strong": model, "llm_model_fast": model})
        systems[label] = AnthropicClient(configured)
    report = await evaluate(cases, systems, budget_tokens=args.budget_tokens)
    write_report(report, Path(args.out))
    for label, system in report["systems"].items():
        print(f"{label}: pass rate {system['pass_rate']} by language {system['by_language']} "
              f"errors {system['errors']} p95 {system['latency_ms']['p95']} ms tokens {system['tokens']['total']}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--systems", help="label=model[,label=model...]")
    parser.add_argument("--cases", default=str(DEFAULT_CASES))
    parser.add_argument("--out", default=str(BACKEND_DIR / "var" / "llm-eval" / "report.json"))
    parser.add_argument("--budget-tokens", type=int, default=None)
    parser.add_argument("--capabilities", nargs="+", metavar="MODEL")
    args = parser.parse_args()
    if args.capabilities:
        return asyncio.run(capabilities(args.capabilities))
    if not args.systems:
        parser.error("--systems is required")
    return asyncio.run(run(args))


if __name__ == "__main__":
    sys.exit(main())
