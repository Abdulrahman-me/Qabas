#!/usr/bin/env python3
"""Extracts every JSON example from the API contract into assets/mocks/examples/.

Each fenced ```json block in API_REQUIREMENTS.md becomes one file, named after
the contract model it is an example of. The heading → model mapping is read from
the contract's own validator (contract_revision10/tools/validate.py, `EXPLICIT`),
so the files match what the contract suite validates. Blocks under other headings
are classified by their keys, the same way validate.py does.

    python3 tool/extract_api_examples.py [--handoff docs/contract]

Re-run it whenever the contract changes. Output: one JSON file per example plus
INDEX.json ([{file, model, heading}]).
"""
import argparse
import json
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
# Local excerpt of FINAL_ENGINEERING_HANDOFF (same folder layout). Pass --handoff to read the original instead.
DEFAULT_HANDOFF = ROOT / "docs/contract"


class _Model:
    def __init__(self, name):
        self.model_validate = name


class _Contract:
    """Stands in for `qabas_contract as C`: C.User.model_validate → 'User'."""

    def __getattr__(self, name):
        return _Model(name)


def explicit_map(validate_py: Path) -> dict[str, list[str]]:
    src = validate_py.read_text(encoding="utf-8")
    block = re.search(r"^EXPLICIT = (\{.*?^\})", src, re.S | re.M).group(1)
    names = {
        "C": _Contract(),
        "page": lambda m: f"Page[{m.model_validate}]",
        "BLOCK": type("B", (), {"validate_python": "Block"})(),
        "SPANS": type("S", (), {"validate_python": "Spans"})(),
    }
    raw = eval(block, names)  # trusted input: the contract's own validator source
    return {h: [v if isinstance(v, str) else "WsClientMessage[]" for v in vs] for h, vs in raw.items()}


def classify(o) -> str | None:
    """Key-based fallback, mirroring validate.py `classify` for the shapes the app decodes."""
    if isinstance(o, list):
        return "WsEvent[]" if o and all(isinstance(x, dict) and set(x) == {"type", "data"} for x in o) else None
    k = set(o)
    if k == {"exercise_id", "recorded"}:
        return "AnswerRecorded"
    if o.get("role") == "assistant" and o.get("status") == "completed":
        return "RaqeebCompleted"
    for need, model in [({"session_id", "items"}, "Session"), ({"lesson_id", "blocks", "version"}, "LessonRead"),
                        ({"duel_id", "players"}, "Duel"), ({"exercise_id", "correct_answer"}, "AnswerEvaluation"),
                        ({"exercise_id", "payload"}, "Exercise"), ({"evidence_id"}, "Evidence"),
                        ({"term_id", "definition"}, "TermCard"), ({"source_id", "displayed"}, "Source"),
                        ({"track", "units"}, "Journey")]:
        if need <= k:
            return model
    if o.get("kind") in ("builtin", "image", "scene") and "alt" in k:
        return "Visual"
    if "block_id" in k:
        return "Block"
    if k == {"url", "mime_type", "width", "height"}:
        return "Image"
    if o.get("type") == "medallion":
        return "Overlay"
    if k == {"error"}:
        return "ErrorEnvelope"
    return None


def slug(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", text.lower()).strip("_")[:48] or "section"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--handoff", type=Path, default=DEFAULT_HANDOFF)
    args = ap.parse_args()
    api = args.handoff / "03_API/API_REQUIREMENTS.md"
    mapping = explicit_map(args.handoff / "03_API/contract_revision10/tools/validate.py")

    out = ROOT / "assets/mocks/examples"
    shutil.rmtree(out, ignore_errors=True)
    out.mkdir(parents=True)

    heading, counters, index, skipped = "", {}, [], []
    for m in re.finditer(r"^(#{2,4} [^\n]*)$|```json\n(.*?)```", api.read_text(encoding="utf-8"), re.S | re.M):
        if m.group(1):
            heading = m.group(1).strip("# ").strip()
            continue
        obj = json.loads(m.group(2))
        i = counters.get(heading, 0)
        counters[heading] = i + 1
        models = mapping.get(heading)
        model = models[i] if models and i < len(models) else classify(obj)
        payload_heading = re.match(r"7\.\d+ `(\w+)`", heading)
        if model is None and payload_heading:  # §7 exercise catalog: bare payload examples
            model = f"Payload[{payload_heading.group(1)}]"
        if model is None:
            skipped.append(heading)
            continue
        safe = model.replace("[", "_").replace("]", "")
        name = f"{safe}__{slug(heading)}__{i}.json"
        (out / name).write_text(json.dumps(obj, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        index.append({"file": name, "model": model, "heading": heading})

    (out / "INDEX.json").write_text(json.dumps(index, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"{len(index)} examples → {out.relative_to(ROOT)}; unclassified blocks: {len(skipped)} {sorted(set(skipped))}")


if __name__ == "__main__":
    main()
