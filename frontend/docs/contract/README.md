# Contract and product reference (excerpt)

A read-only excerpt of the **amended** engineering handoff, `/Users/aw/Documents/qpr/FINAL_ENGINEERING_HANDOFF 2/FINAL_ENGINEERING_HANDOFF/` (contract **revision 10** with the owner's curriculum and learning-design amendment; schema digest `9d67bda00d2edd04d47645b6b93a7747ab9d5646cddeb12a7b34a6910c97481c`; refreshed 2026-10-04). The backend engineer confirmed this digest as the shared baseline for the demo, header still `Qabas-Contract: 10`; it is not a recorded final sign-off (O-01). The earlier, unamended package at `/Users/aw/Documents/qpr/FINAL_ENGINEERING_HANDOFF/` is superseded. It contains only the parts the Flutter app needs, in the original folder layout, so section references such as "API §6.5" or "frontend handoff §9" resolve here.

**Don't edit these files.** The contract is shared with the backend engineer. A change is agreed with them first, then made in the original package (which has its own integrity checks), and then this excerpt is refreshed from it. Record client-side interpretations in `docs/API_ASSUMPTIONS.md` instead.

| File | Use it for |
|---|---|
| `03_API/API_REQUIREMENTS.md` | **The wire contract:** endpoints, fields, enums, errors, exercise shapes, WebSocket protocol |
| `03_API/contract_revision10/contract/` | Machine contract: `qabas_contract.py` (field-level truth), `qabas_contract.schema.json` (99 roots), `dispatch_map.json` (answer/details per exercise type), `scene.schema.json`, capability and art registries |
| `03_API/contract_revision10/tools/` | The contract's own checkers (`validate.py`, `regression.py`, `rev10_checks.py`, `recovery.py`…). They need Python with Pydantic 2.12 and jsonschema 4.25 (for example `/Users/aw/Documents/qpr/reply8/.venv/bin/python`). Run them only on a temporary copy: `validate.py` rewrites files. `tool/extract_api_examples.py` reads `validate.py` for its heading → model map. |
| `03_API/contract_revision10/README.md`, `CHANGES.md`, `VALIDATION_REPORT.md` | What revision 10 changed and how it was verified |
| `03_API/SECTION_REFERENCE_MAP.md` | Resolves old section numbers used across the documents |
| `04_FRONTEND/FRONTEND_HANDOFF.md` | Screen list S1–S21/R1–R6, UI rules §9, Salah reference spec (Appendix A), frontend definition of done |
| `07_ANIMATION/` | Built-in scenes, generated-scene workflow, `SCENE_RENDERER_SEMANTICS.md` |
| `01_PRODUCT/` | Product requirements, overview, content and brand policy (now with illustration-style rules), and **`CURRICULUM_AND_LEARNING_DESIGN.md`**: the two tracks over one canonical curriculum, Units 0–10, curiosity onboarding, Roadmap and Discover, prerequisites versus position (Soft Lock), lesson composition and depth |
| `00_REVIEW/STATUS_AND_OPEN_DECISIONS.md` | Open decisions O-01–O-13 and product decisions P-01–P-08 with their defaults |
| `00_REVIEW/ENGINEERING_REVIEW_LOG.md` | Why revision 10 exists (security, idempotency, tickets…) |
| `02_ARCHITECTURE/` | Architecture decisions AD-01–AD-35; versioning rules (unknown fields and enums) |
| `05_BACKEND/BACKEND_HANDOFF.md` | What the backend computes (XP table §10.1, streaks, leagues, rate limits §5.1). Read-only context for the client. |
| `08_IMPLEMENTATION/FRONTEND_IMPLEMENTATION.md`, `SHARED_IMPLEMENTATION_PLAN.md` | The engineering package's own frontend sequence and shared milestones |
| `09_VALIDATION/MOCKS_AND_FIXTURES.md`, `QUALITY_AND_ACCEPTANCE.md` | Mock behaviour and acceptance criteria |

**Not included**, because the app doesn't need them or they live elsewhere. Links to these from the documents above won't open here:

- `03_API/contract_revision10/fixtures/` (382 fixtures) is in the app at **`assets/mocks/contract/`**.
- `UNIT_0_CONTENT/` (the authoring packages of the 12 Unit 0 lessons). The app uses the backend's projected learner Sessions instead, in `assets/mocks/unit0/`.
- `10_REFERENCE/` (the received engineer delivery). The Salah sessions, glossary and private keys the app needs are already in `assets/mocks/`. Everything else is at the original path.
- `06_CONTENT/` (factory, source adapters, agent catalog), `05_BACKEND/SEED_AND_IMPORT_REQUIREMENTS.md`, `08_IMPLEMENTATION/BACKEND_IMPLEMENTATION.md` and `OPERATIONS_AND_ENVIRONMENT.md`, `09_VALIDATION/EVIDENCE_REGISTER.md` and `RAQEEB_BENCHMARK.md`, `11_HISTORY/`: all backend, content-pipeline or history material, at the original path if ever needed.
