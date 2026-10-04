# Vendored contract — revision 10 (public subset)

Copied **unchanged** from `FINAL_ENGINEERING_HANDOFF/03_API/contract_revision10/`. `SHA256SUMS.public` lists the original handoff checksums for exactly these files, and `tests/contract/test_vendored_contract.py` verifies them.

| Path | Use |
|---|---|
| `contract/qabas_contract.py` | Canonical Pydantic v2 request/response/event models (the only source of public DTOs) |
| `contract/qabas_contract.schema.json` | Custom export, 99 roots; the source of the served OpenAPI components |
| `contract/contextual.py`, `review.py`, `display_fields.py` | Served-context validation and grading helpers, reviewer gate digest, glossary projection |
| `contract/dispatch_map.json`, `scene.schema.json`, `scene_capabilities*.json`, `exercise_art_registry.json`, `registries.template.json` | Discriminators, scene grammar, capability registries, art and registry templates |
| `tools/scene_check.py`, `tools/recovery.py`, `tools/export_schema.py` | Scene semantic checker, resume recovery reference, schema exporter |

Only code and schemas are here. Under the public-repo policy (D-14 in `IMPLEMENTATION_PHASES.md`), the handoff fixtures, the private evaluation context and grading keys, the API prose and the remaining generator tools are **not committed**. They live in git-ignored `backend/.private/` (see `scripts/dev/sync_private_contract.py`).

Never edit these files. A contract amendment means re-vendoring and updating `SHA256SUMS.public`, then rerunning the full suites (`scripts/dev/run_contract_suites.py`).
