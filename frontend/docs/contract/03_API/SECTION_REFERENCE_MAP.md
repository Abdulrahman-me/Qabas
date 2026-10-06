# Section reference map

**Purpose:** resolve inherited section numbers after separating topics. Original API/frontend/backend section identifiers are retained in extracted chapters; numbers belong to their original namespace, not a global sequence.

“Contract §…” means frontend/API namespace. Explicit “backend §…” means backend namespace. Planned code paths are implementation deliverables, not missing files in this handoff. For ambiguous source references use the corresponding raw handoff in the immutable reference delivery and the mappings below.

| Original namespace / section | Active document |
|---|---|
| frontend §1 | [PRODUCT_REQUIREMENTS.md](../01_PRODUCT/PRODUCT_REQUIREMENTS.md) |
| frontend §2 | [FRONTEND_HANDOFF.md](../04_FRONTEND/FRONTEND_HANDOFF.md) |
| frontend §3 | [API_REQUIREMENTS.md](API_REQUIREMENTS.md) |
| frontend §4 | [API_REQUIREMENTS.md](API_REQUIREMENTS.md) |
| frontend §5 | [API_REQUIREMENTS.md](API_REQUIREMENTS.md) |
| frontend §6 | [API_REQUIREMENTS.md](API_REQUIREMENTS.md) |
| frontend §7 | [API_REQUIREMENTS.md](API_REQUIREMENTS.md) |
| frontend §8 | [API_REQUIREMENTS.md](API_REQUIREMENTS.md) |
| frontend §9 | [FRONTEND_HANDOFF.md](../04_FRONTEND/FRONTEND_HANDOFF.md) |
| frontend §10 | [MOCKS_AND_FIXTURES.md](../09_VALIDATION/MOCKS_AND_FIXTURES.md) |
| frontend §11 | [FRONTEND_HANDOFF.md](../04_FRONTEND/FRONTEND_HANDOFF.md) |
| frontend §12 | [FRONTEND_HANDOFF.md](../04_FRONTEND/FRONTEND_HANDOFF.md) |
| frontend §Appendix A | [FRONTEND_HANDOFF.md](../04_FRONTEND/FRONTEND_HANDOFF.md) |
| frontend §Appendix B | [QUALITY_AND_ACCEPTANCE.md](../09_VALIDATION/QUALITY_AND_ACCEPTANCE.md) |
| backend §0 | [ARCHITECTURE_DECISIONS.md](../02_ARCHITECTURE/ARCHITECTURE_DECISIONS.md) |
| backend §1 | [PRODUCT_REQUIREMENTS.md](../01_PRODUCT/PRODUCT_REQUIREMENTS.md) |
| backend §2 | [SYSTEM_ARCHITECTURE.md](../02_ARCHITECTURE/SYSTEM_ARCHITECTURE.md) |
| backend §3 | [SYSTEM_ARCHITECTURE.md](../02_ARCHITECTURE/SYSTEM_ARCHITECTURE.md) |
| backend §4 | [DATA_MODEL_AND_VERSIONING.md](../02_ARCHITECTURE/DATA_MODEL_AND_VERSIONING.md) |
| backend §5 | [BACKEND_HANDOFF.md](../05_BACKEND/BACKEND_HANDOFF.md) |
| backend §6 | [BACKEND_HANDOFF.md](../05_BACKEND/BACKEND_HANDOFF.md) |
| backend §7 | [BACKEND_HANDOFF.md](../05_BACKEND/BACKEND_HANDOFF.md) |
| backend §8 | [BACKEND_HANDOFF.md](../05_BACKEND/BACKEND_HANDOFF.md) |
| backend §9 | [BACKEND_HANDOFF.md](../05_BACKEND/BACKEND_HANDOFF.md) |
| backend §10 | [BACKEND_HANDOFF.md](../05_BACKEND/BACKEND_HANDOFF.md) |
| backend §11 | [BACKEND_HANDOFF.md](../05_BACKEND/BACKEND_HANDOFF.md) |
| backend §12 | [SOURCE_ADAPTERS.md](../06_CONTENT/SOURCE_ADAPTERS.md) |
| backend §13 | [FACTORY_AND_REVIEWER_HANDOFF.md](../06_CONTENT/FACTORY_AND_REVIEWER_HANDOFF.md) |
| backend §14 | [FACTORY_AND_REVIEWER_HANDOFF.md](../06_CONTENT/FACTORY_AND_REVIEWER_HANDOFF.md) |
| backend §15 | [SEED_AND_IMPORT_REQUIREMENTS.md](../05_BACKEND/SEED_AND_IMPORT_REQUIREMENTS.md) |
| backend §16 | [RAQEEB_BENCHMARK.md](../09_VALIDATION/RAQEEB_BENCHMARK.md) |
| backend §17 | [AGENT_AND_PROVIDER_CATALOG.md](../06_CONTENT/AGENT_AND_PROVIDER_CATALOG.md) |
| backend §18 | [QUALITY_AND_ACCEPTANCE.md](../09_VALIDATION/QUALITY_AND_ACCEPTANCE.md) |
| backend §19 | [OPERATIONS_AND_ENVIRONMENT.md](../08_IMPLEMENTATION/OPERATIONS_AND_ENVIRONMENT.md) |

Documents added by the final engineering review have no inherited section numbers: [revision 10 contract](contract_revision10/README.md) (machine contract and `CHANGES.md`), [scene renderer semantics](../07_ANIMATION/SCENE_RENDERER_SEMANTICS.md) and the [review log](../00_REVIEW/ENGINEERING_REVIEW_LOG.md). New subsections inside retained chapters (for example backend §5.1/§5.2) extend the backend namespace.

[Machine-readable source coverage](SOURCE_SECTION_COVERAGE.json) records every original top-level chapter and its destination. Revision logs, historical packaging mechanics and old status wording remain in provenance. Current counts/status and four display amendments are explicit in the active documents.
