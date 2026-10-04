"""Reviewer gate digest — revision 10 reference implementation (server side).

`FactoryRun.review_digest` identifies the exact artifact a reviewer is approving. The server
computes it from the *stored* gate artifact (object keys and content hashes, never short-lived
signed URLs), returns it on every `GET /admin/factory/runs/{id}` while the run awaits a gate,
and requires `Gate1.review_digest` / `Gate2.review_digest` to match before it applies a decision
(`409 review_stale` otherwise). Clients never compute it; they echo the value they rendered.
"""
import hashlib
import json


def canonical_json(obj) -> bytes:
    """Deterministic UTF-8 JSON: sorted keys, no insignificant whitespace, NaN/Infinity rejected."""
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=False, allow_nan=False).encode("utf-8")


def review_digest(run: dict) -> str:
    """Digest of the artifact awaiting a gate. `run` is the stored FactoryRun projection (dict)."""
    if run["status"] == "awaiting_gate1":
        body = {"gate": "gate1", "run_id": run["run_id"], "plan": run["plan"]}
    elif run["status"] == "awaiting_gate2":
        body = {"gate": "gate2", "run_id": run["run_id"], "draft": run["draft"], "qa_report": run["qa_report"]}
    else:
        raise ValueError("run is not awaiting a gate")
    return hashlib.sha256(canonical_json(body)).hexdigest()
