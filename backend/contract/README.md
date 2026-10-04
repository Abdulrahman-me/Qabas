# Vendored contract — revision 10

`03_API/` is copied **unchanged** from `FINAL_ENGINEERING_HANDOFF/03_API/`: the complete `contract_revision10/` folder (models, custom-exported schema, contextual/review/display helpers, scene schema and capability registries, fixtures with their server-side grading context, tools and reports) plus `API_REQUIREMENTS.md`, which `tools/validate.py` reads for its JSON examples. The handoff requires this folder to be vendored into the repository and its suites run in CI (QUALITY §18.1, decision D-19).

Integrity: `VENDORED.json` pins the handoff digests of `API_REQUIREMENTS.md` and `contract_revision10/SHA256SUMS`, and `SHA256SUMS` covers every other file. `tests/contract/test_vendored_contract.py` verifies all of them.

| Path | Use |
|---|---|
| `03_API/contract_revision10/contract/qabas_contract.py` | Canonical Pydantic v2 models: the only source of public DTOs |
| `03_API/contract_revision10/contract/qabas_contract.schema.json` | Custom export (99 roots), the source of the served OpenAPI components |
| `03_API/contract_revision10/contract/contextual.py`, `review.py`, `display_fields.py` | Served-context validation and grading, reviewer gate digest, glossary projection |
| `03_API/contract_revision10/tools/` | `regression.py` (595), `rev10_checks.py` (279), `validate.py` (105 examples, 382 fixtures), `scene_check.py`, `recovery.py`, `export_schema.py` |
| `03_API/contract_revision10/fixtures/` | Contract examples and synthetic seeds; `EVALUATION_CONTEXT.json` is the **server-side** grading context (never sent to clients) |

Never edit these files. `validate.py` rewrites reports and checksums, so run the suites through `scripts/dev/run_contract_suites.py`, which works on a disposable copy. A contract amendment means re-vendoring, updating `VENDORED.json` and rerunning the suites.
