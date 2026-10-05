# Qabas Backend — Implementation Phases

**Scope:** backend only (FastAPI, Postgres, Redis, Celery workers, sources, recitation, Lesson Factory, reviewer gates and publishing, Raqeeb, community, challenges, operations). The Flutter app, Dart DTOs, `packages/qabas_scene` and the `tools/scene_preview` CLI are owned outside this plan and appear only as **external dependencies**.
**Baseline:** `FINAL_ENGINEERING_HANDOFF/` (contract **revision 10 candidate**, schema SHA-256 `9d67bda0…481c`). The handoff folder is read-only and excluded from git.
**Repository:** https://github.com/Abdulrahman-me/Qabas (branch `main` = latest completed checkpoint).
**Created:** 2026-10-04 · **Last updated:** 2026-10-05

**Priority order (D-02):** first the core learning experience (Phases 1–10), then the Lesson Factory, reviewer gates, publishing and the full visual/media pipeline (11–15). Raqeeb (16–17) starts only after that milestone. Community and challenges (18–20) and production hardening (21) follow.

---

## Status board

| Phase | Name | Status | Checkpoint tag | Notes |
|---|---|---|---|---|
| 0 | Workspace, toolchain and baseline verification | ✅ Done | `phase-0` | |
| 1 | Contract vendoring and service skeleton | ✅ Done | `phase-1`, `phase-1.1` | CI green; repository boundary corrected by D-19 (`phase-1.1`) |
| 2 | Core database schema and migrations | ✅ Done | `phase-2` | CI green (151 passed incl. role grants) |
| 3 | Platform controls: auth, idempotency, rate limits, outbox, deletion | ✅ Done | `phase-3` | CI green (218 passed) |
| 4 | Content storage, registries, projection and seeding | ✅ Done | `phase-4` | CI green (313 passed); conflict D-38 resolved |
| 5 | Journey, lessons and session creation | ✅ Done | `phase-5` | CI green (393 passed); planner complete (D-44, D-45) |
| 6 | Answers: replay-first, evaluators, per-answer adaptation | ✅ Done | `phase-6` | CI green (525 passed); 86/86 contract evaluations |
| 7 | Finish transaction, FSRS, planner, reviews, glossary, stats | ✅ Done | `phase-7` | **Milestone A: durable learning slice** |
| 7.1 | Phase 7 audit corrections (corrective checkpoint) | ✅ Done | `phase-7.1` | Independent audit; 5 findings fixed (F-48–F-52) |
| 8 | Content import (Salah reference, Unit 0 drafts), approval-gated publish, staging | ✅ Done | `phase-8` | CI green (582 passed); pipeline complete; real content correctly blocked on human/source/media inputs |
| 9 | Source adapters (tool layer) | ✅ Done | `phase-9` | CI green; canonical insertion/import checks complete; provider live/cache approvals remain O-03 |
| 9.1 | Phase 9 audit corrections (corrective checkpoint) | 🔄 In progress | `phase-9.1` | Independent audit; findings F-79–F-85 |
| 10 | Recitation service (`asr` worker) | ⏳ Not started | `phase-10` | **Milestone B: complete learning experience** |
| 11 | LLM adapter and agent infrastructure | ⏳ Not started | `phase-11` | |
| 12 | Lesson Factory pipeline: plan → QA | ⏳ Not started | `phase-12` | |
| 13 | Reviewer gates, publication, reviewer console API | ⏳ Not started | `phase-13` | |
| 14 | Visual and media pipeline (images, audio, production scenes) | ⏳ Not started | `phase-14` | Full scene quality (D-06) |
| 15 | Metrics, blind tests, factory acceptance | ⏳ Not started | `phase-15` | **Milestone C: lesson generation and publishing** |
| 16 | Raqeeb text pipeline | ⏳ Not started | `phase-16` | Starts after Milestone C |
| 17 | Raqeeb inputs, guarded memory and benchmark | ⏳ Not started | `phase-17` | Needs pgvector (D-05) |
| 18 | Community: leagues, friends, achievements | ⏳ Not started | `phase-18` | |
| 19 | Challenges: REST, selection, bot, async | ⏳ Not started | `phase-19` | |
| 20 | Challenges: live WebSocket and durable coordinator | ⏳ Not started | `phase-20` | |
| 21 | Production hardening and deployment | ⏳ Not started | `phase-21` | |

Legend: ⏳ Not started · 🔄 In progress · ✅ Done · ⛔ Blocked (state the reason in Notes)

---

## Working assumptions

| # | Assumption | Basis |
|---|---|---|
| A-1 | The rev 10 candidate is the working contract until the approval record says otherwise. Any amendment means re-vendoring and rerunning the suites. | D-01 |
| A-2 | Development runs natively on Windows: Postgres 16 service, native Redis 7.4, Python 3.12, uv, ffmpeg. No Docker. CI uses runner-native Postgres/Redis, also without Docker. | D-03 |
| A-3 | Religious content still pending approval (Salah reference, Unit 0 drafts, curriculum titles) stays in git-ignored `backend/.private/content/` and is imported unpublished until O-05/O-12 close. Once approved, it enters `backend/content/` through the normal import pipeline and is committed like any production content. | Handoff status register, D-19 |
| A-4 | Product decisions P-01–P-08 use the handoff's engineering defaults until decided. | STATUS_AND_OPEN_DECISIONS |
| A-5 | Generated scenes target the final production architecture. A missing Flutter preview tool limits **inspection only**, never scene quality or capability. | D-06 |
| A-6 | Commits carry no AI co-author or attribution metadata. | D-09 |
| A-7 | **One real product.** The public repository is the complete production system: cloneable, installable, testable and runnable as-is. There is no demo mode, demo dataset, sample product or judge-only path. Production/runtime data, answer keys and tests may be public; internal evaluation material, unpublished handoff material and secrets stay private. Correct answers never reach a client before submission (server-side grading and redaction). | D-19 |

---

## Checkpoint and recovery protocol

A phase is **done** only when every item below is true. The checkpoint is the last state to which work can safely return.

1. All tasks of the phase are ticked, or explicitly moved to a later phase with a note.
2. The phase's tests pass locally against **real Postgres/Redis**, plus the vendored contract suites.
3. From Phase 2 on: `alembic upgrade head` from an empty database and `alembic downgrade -1` both succeed.
4. The phase is committed and tagged `phase-N` (annotated), and both are pushed to GitHub.
5. This file is updated: status board, ticked tasks, the progress log entry, and any new decisions or deviations.

**When something breaks mid-phase:** branch or stash the broken work, `git checkout phase-N` (the last good tag), rebuild the database (`alembic upgrade head` + `scripts/seed.py --test-curriculum`), and resume from the first unticked task. Large phases have **sub-checkpoints** (tags `phase-N.x`) for the same purpose.

**Branching:** one branch per phase (`phase/N-short-name`), merged into `main` when done. `main` always equals the latest completed checkpoint.

---

## Phase 0 — Workspace, toolchain and baseline verification

**Goal:** a reproducible native environment and a verified starting point.

- [x] Environment re-checked beyond PATH (Program Files, services, py launcher, choco/winget). Findings are in D-03/D-04/D-05/D-12.
- [x] Python **3.12.10** (per-user, `py -3.12`) and **uv 0.12.23** for locking. The broken choco `python312` record was left untouched.
- [x] PostgreSQL **16.14**: native Windows service `postgresql-x64-16`, running, scram-sha-256 auth.
- [x] Dev database role `qabas` and databases `qabas_dev`, `qabas_test` created with `backend\scripts\dev\create-dev-db.ps1` (run by you); credentials in git-ignored `backend/.env`.
- [x] Redis **7.4.11** native Windows build, localhost only, at `%LOCALAPPDATA%\Programs\Redis`. Start it with `backend\scripts\dev\start-redis.ps1` (D-04).
- [x] ffmpeg **9.0.2** (winget `Gyan.FFmpeg`); Node **22.23** present (for the native Dorar sidecar in Phase 9).
- [x] pgvector: not installed. Deferred to Phase 17, where it is first used (D-05).
- [x] Handoff integrity: all 2,010 manifest entries hash-verified. The bundled `verify_package.py` misreports on Windows (D-07).
- [x] Rev 10 suites rerun on a disposable copy with Python 3.12 and the locked dependencies: **595/595 regressions, 279/279 focused checks, 105/105 examples, 382/382 fixtures, 99 exported roots, PASS**. Rerun outputs are identical to the handoff after LF normalization (D-08).
- [x] O-01 working assumption recorded: rev 10 adopted, schema `9d67bda00d2edd04d47645b6b93a7747ab9d5646cddeb12a7b34a6910c97481c` (D-01).
- [x] Git connected to `Abdulrahman-me/Qabas`; handoff excluded and set read-only; `.gitattributes` enforces LF (D-09).
- [x] Repository visibility decided: stays **public** (hackathon requirement), with the public-repo data policy in D-14.
- [x] `check-env.ps1` passes every check (Python, uv, ffmpeg, Node, Redis, Postgres service, `qabas_dev`, `qabas_test`).

**Exit:** environment documented in `backend/README.md`; dev databases reachable with the credentials in `backend/.env`; Redis ping OK; tag `phase-0` pushed.

---

## Phase 1 — Contract vendoring and service skeleton

**Goal:** a running FastAPI service whose public shapes come only from the vendored rev 10 contract.
**Refs:** API §3 (conventions, headers, errors, multipart), SYSTEM_ARCHITECTURE §3.2, BACKEND_IMPLEMENTATION step 1.
**Public-repo rule (D-14):** only code, schemas and sanitized synthetic test data are committed. Fixtures, answer keys, private handoff material and unapproved religious content stay local and git-ignored.

- [x] `backend/` layout per SYSTEM_ARCHITECTURE §3.2; `pyproject.toml` + `uv.lock` (Python 3.12; pydantic 2.12.5 / jsonschema 4.25.1 / Pillow 12.0.0 pinned to the contract-verified versions).
- [x] Public part of rev 10 vendored **unchanged** into `backend/contract/` (D-18): the `contract/` directory plus the runtime tools `scene_check.py`, `recovery.py` and `export_schema.py`. A checksum test runs against `SHA256SUMS.public` (the 14 original handoff checksums), and the schema digest test expects `9d67bda0...481c`.
- [x] Local private mirror: `scripts/dev/sync_private_contract.py` (fixtures, tools, grading context, API prose into git-ignored `backend/.private/`, plus private-file digests). `scripts/dev/run_contract_suites.py` result: **595/595, 279/279, 105/105, 382/382, schema identical, PASS**.
- [x] Public-safety guard `scripts/check_public_safety.py`: runs in CI and in the local pre-commit hook (`scripts/dev/install_git_hooks.py`). It blocks handoff/private paths, private-material names, `.env`, Arabic text outside `.public-safety-allow`, and verbatim copies of private handoff files.
- [x] Sanitized test data policy: tests build synthetic neutral data in code; marker `private` is reserved for tests needing the mirror.
- [x] `app/config.py` (pydantic-settings, all OPERATIONS §19 variables, secrets as `SecretStr`, staging/production secret checks, P-01 guard), `.env.example`.
- [x] Error envelope through the contract `ErrorEnvelope` model, with every §3.4 code and status; validation errors are 400 without echoing input; unknown route or method gives 404 (D-16); unhandled errors give 500 with no internals.
- [x] Contract identity middleware: `Qabas-Contract` on every response, `426 client_outdated` with `min_contract`/`min_app_version`, header rules per D-15; CORS per API §3.2; request IDs.
- [x] OpenAPI 3.1 whose components are the 99-root custom export flattened (281 definitions plus roots, conflict-checked). Routes referencing a non-contract schema fail the build; 422 responses are replaced by the `ErrorEnvelope` default. Exported to `backend/docs/openapi.json` with a staleness check.
- [x] `/health/live`, `/health/ready` (real Postgres + Redis checks, no secrets in output), outside `/v1` and the contract document; JSON logging with key and query redaction.
- [x] Adapter interfaces: LLM, STT, image, TTS, source tools (`app/adapters.py`).
- [x] Celery app: five queues, prefix routing, acks-late, reject-on-lost, prefetch 1; `maintenance.ping`; Windows dev uses `--pool=solo`.
- [x] Storage: two-bucket interface with local filesystem implementation (immutable content, HMAC-signed private URLs, key validation). S3 follows in Phase 3.
- [x] CI workflow `.github/workflows/ci.yml` (ubuntu-24.04, Python 3.12, runner-native Postgres 16 and Redis, no Docker): guard, ruff, mypy, OpenAPI check, pytest. First run green: 84 passed, integration tests included.

**Local status:** 84 tests pass (including the integration tests on the real `qabas_test`/Redis), ruff clean, mypy strict clean.

**Correction `phase-1.1` (D-19, supersedes the D-14 boundary).** The items above that keep fixtures and the API prose local and block Arabic text describe the original `phase-1` state and are kept here as history. Corrected:
- [x] The **whole** `contract_revision10/` folder (fixtures, server-side grading context `EVALUATION_CONTEXT.json`, tools, reports) and `API_REQUIREMENTS.md` are vendored under `backend/contract/03_API/` (handoff layout). `VENDORED.json` pins the handoff digests; tests verify all 455 checksummed files and that nothing unlisted exists.
- [x] The full contract suites (595/279/105/382, schema identity) run **in CI** via `scripts/dev/run_contract_suites.py`, as QUALITY §18.1 requires ("both repos, from the vendored revision 10 folder"). The local private mirror and `sync_private_contract.py` are removed.
- [x] The Arabic-text rule and `.public-safety-allow` are removed. The guard now blocks: handoff and `backend/.private/` paths; secrets/credential files; secret-looking tokens (private keys; Anthropic, OpenAI-style, AWS, GitHub, Slack and Google keys); hidden-evaluation dataset names (held-out, adversarial, golden/reference answers, `backend/bench/data/`); and verbatim copies of private handoff artifacts. That last check uses committed digests-only fingerprints (`backend/security/private_fingerprints.json`, 881 digests from `scripts/dev/update_private_fingerprints.py`), so CI enforces it too.
- [x] Fix found on the way: digests now cover raw bytes as well as LF-normalized text, because normalizing binaries (WebP) corrupted their checksums.
- [x] 96 tests, ruff, mypy, OpenAPI check and contract suites green locally.
**Exit:** ✅ contract suites green locally, CI green on GitHub, tagged `phase-1`.

---

## Phase 2 — Core database schema and migrations

**Goal:** the first Alembic migration with **every mandatory constraint**.
**Refs:** DATA_MODEL_AND_VERSIONING (mandatory constraints, §4.1–4.3, 4.5 platform tables).

- [x] SQLAlchemy 2.1 async models (31 tables): `users`, `auth_sessions`, `idempotency_keys`, `deletion_jobs`, `units`, `concepts`, `terms`, `misconceptions`, `sources`, `lessons`, `lesson_versions`, `claims`, `sentences`, `exercises`, `exercise_versions`, `scene_versions`, `scene_assets`, `learner_units`, `learner_lessons`, `learner_concepts`, `learner_terms`, `learner_misconceptions`, `sessions`, `session_answers`, `recitation_checks`, `xp_events`, `daily_activity`, `quests`, `outbox_events`, `effect_ledger`, `review_decisions`.
- [x] Enum columns are text with named CHECKs whose values are **derived from the contract** (`app/db/enums.py`, via `typing.get_args` on the contract models). A test compares every migrated CHECK with the contract values.
- [x] Mandatory constraints: `UNIQUE(session_id, exercise_id, is_retry)`; partial unique active-session index (COALESCE keys); finish-once CHECKs (`finished` ⇔ `finished_at` + `result_snapshot`); `numeric(7,6)` mastery `CHECK 0..1`; `UNIQUE(unit_id, index)`; `learner_lessons` PK (`user_id`, `lesson_id`); set-once `concepts.introduced_by_lesson_id`; unique outbox `event_key`, effect `effect_key`, XP grant (`user_id`, `reason`, `ref_type`, `ref_id`) and daily goal per local date; `idempotency_keys` PK (`user_id`, `key`); recitation binding columns with range/hash checks.
- [x] Further domain CHECKs: feedback mode matches session kind; review mode only for reviews; lesson/unit refs per kind; exercise purpose/type pools (no flashcard/recitation in assessments or duels; duel types; `true_false` duel-only); standalone lessons have no prerequisites; reviewer credentials only for reviewers; case-insensitive unique reviewer email; ID prefixes (API §3.3); SHA-256 formats.
- [x] Triggers (custom SQLSTATEs QB001–QB005, enforced for every role): published lesson/exercise/scene versions immutable, including child claims, sentences and scene assets; concept introduced once; `current_version` must be published; served session identity and snapshot frozen (changes only through a snapshot migration raising `snapshot_revision`); finished/abandoned sessions terminal; `session_answers` and `review_decisions` insert-only.
- [x] Circular FKs (concepts→lessons, lessons→lesson_versions, exercises→exercise_versions) created after all tables; the downgrade drops them first.
- [x] Least-privilege roles `qabas_app`, `qabas_worker`, `qabas_readonly` via `qabas_apply_grants()`: no DELETE on content, versions or the audit; no UPDATE on answers or the audit; `alembic_version` read-only. Roles are created by an operator (`create-dev-db.ps1` locally, CI with the superuser); later migrations re-run the grant function.
- [x] Test harness on real Postgres: fresh schema each run, migrations base→head→base→head, per-test rollback, savepoint-based SQLSTATE assertions, synthetic factories.
- [x] Fix found by the tests: `recitation_checks.word_range_valid` let a half range pass, because a NULL CHECK result passes. It's rewritten with explicit `IS NOT NULL`, and every other CHECK was re-audited for the same pitfall.

**Tables added later by their phases (additive migrations):** `factory_runs` (12; plus the FK from `review_decisions.run_id` and `lesson_versions.run_id`), `blind_pairs`/`blind_responses` (15), `benchmark_runs` and Raqeeb tables (16–17), league/friend/achievement tables (18), duel tables (19–20).

**Local status:** 150 tests pass (24 DB constraint/schema tests on the real `qabas_test`; the role-privilege test runs in CI and locally after `create-dev-db.ps1` is re-run). `alembic check` shows no drift; the dev DB is at head after a downgrade/upgrade round trip; ruff and mypy are clean.
**Exit:** ✅ CI green on GitHub (run 37193125528: 151 passed, role-privilege test included; contract suites green); tagged `phase-2`.

---

## Phase 3 — Platform controls

**Goal:** the security and recovery primitives every later feature relies on.
**Refs:** BACKEND_HANDOFF §5, §5.1, §5.2; API §6.1–6.2; AD-20, AD-21, AD-25.

- [x] **3.1 Auth:** `POST /v1/auth/guest` (`GuestReq` → `201 AuthResp`): 32-byte CSPRNG token, only HMAC-SHA-256(pepper, token) stored; generated Arabic display names (registry word + Arabic-Indic number); random selectable avatar; IANA time-zone validation. Each request does one indexed session+user lookup with no cache, so revocation is immediate (D-24). Inactive guests expire after 180 days (on use and by a daily job); deleted/deactivated users are rejected; pepper rotation accepts the previous pepper and re-hashes the row; `last_used_at`/`last_seen_at` are throttled to 30 s.
- [x] **3.2 Reviewer auth:** `POST /v1/auth/reviewer` (Argon2id; constant-time verification against a dummy hash for unknown emails; case-insensitive email; one generic 401 for every failure; lockout after 5 failures per account or per address in 15 min → `429`; 12 h sessions; transparent re-hash). `scripts/create_reviewer.py` prompts for the password (minimum 12 characters); re-keying revokes existing sessions.
- [x] **3.3 Rate limits:** atomic multi-bucket Redis token buckets (one Lua script; a request consumes from every bucket only if all allow it). The full default profile from §5.1 is defined; `auth_guest` (10/h per address) is applied now, the rest by their phases. Fixed-window failure counters handle lockouts and code guessing. `429 rate_limited` carries `details.retry_after_ms` and `Retry-After`. Client address honours only `TRUSTED_PROXY_HOPS`.
- [x] **3.4 Idempotency-Key:** `run_idempotent()`: a transaction-scoped advisory lock serializes duplicates; same key + same fingerprint replays the stored status/body; a different body gives `409 idempotency_conflict`; a failed create stores nothing; 24 h TTL with reuse after expiry and an hourly purge job. UUID key validation and canonical request fingerprints. Used by the create endpoints of later phases.
- [x] **3.5 Outbox:** `enqueue()` in the producing transaction (re-enqueue is a no-op); the relay claims one due event at a time with `FOR UPDATE SKIP LOCKED`, runs its consumer in a savepoint, and on failure records attempts/backoff/last error without losing the event; `apply_effect()` effect ledger for consumer idempotency; beat runs the relay every 5 s.
- [x] **3.6 Storage:** `S3Storage` (immutable content writes with SHA-256 metadata and immutable cache headers, presigned private URLs, prefix purge) alongside `LocalStorage`; per-user private prefix `users/<id>/`; local dev routes `/media/…` and signed `/private/…` (outside the contract); `build_storage()` from settings.
- [x] **3.7 Profile:** `POST /v1/onboarding` (track mapping `undisclosed` → `explorer`; start unit = first unit of the track path; `goal_anchor` validated against the registry and never read by the planner; no religion field anywhere), `GET /v1/me`, `PATCH /v1/me` (`MePatch`: whitespace-normalized display name, selectable avatars only, IANA zones, registry anchors; a track change keeps all progress). `content/registries.json` holds avatars, guest names, anchors and placeholders (D-23).
- [x] **3.8 Deletion:** `DELETE /v1/me` → 204: in one transaction it revokes every session, marks the user deleted, runs request-time steps (extensible for friends/leagues in Phase 18), records `deletion_jobs` and enqueues `user:{id}:purge`. Reviewers get 403. The purge consumer deletes all learner rows and private objects, anonymizes the profile row (rendered as the localized "Deleted learner"), records its steps and is idempotent. `scripts/repurge_deleted_users.py` re-purges after a backup restore.
- [x] Planner foundation (`services/adaptive/planner.py`): track path, current unit, new-unit pretest, due reviews, journey complete. Rules 3–4 (lesson and unit-test steps) need lesson access state and are completed in Phase 7 (D-25).
- [x] Runtime resources per process (engine, Redis, storage) created in the app lifespan; maintenance tasks build their own in their event loop. Verified with a real native Celery worker: ping, relay, guest expiry and key purge executed.

**Tests (real Postgres + Redis):** 59 new integration tests: guest/reviewer auth, HMAC-only storage, pepper rotation, immediate revocation, expiry and throttling, lockouts, onboarding and profile validation, deletion and purge (including private objects and re-purge after restore), idempotency (replay, conflict, five concurrent duplicates → one create, failures, expiry), outbox (once-only, effect ledger, backoff, unknown kinds, four concurrent relays over 30 events), multi-bucket limits, local media links. S3 is exercised with botocore's Stubber.
**Local status:** 214 passed, 1 skipped (role privileges, which run in CI); ruff and mypy clean; contract suites 595/279/105/382 PASS; `alembic check` clean; OpenAPI regenerated.
**Exit:** ✅ CI green on GitHub (run 37199034433: 218 passed, contract suites green); tagged `phase-3`.

---

## Phase 4 — Content storage, registries, projection and seeding

**Goal:** the production foundation for curriculum and content: what exists, where every lesson sits, how content is stored, validated, versioned and published, and which units learners may enter. No learner endpoints yet.
**Refs:** SEED_AND_IMPORT_REQUIREMENTS §15; BACKEND_HANDOFF §6.2, §6.5; DATA_MODEL §4.2; FACTORY §13.1–13.7; CURRICULUM_AND_LEARNING_DESIGN; API §5.5c–5.5d, §6.3–6.4.

- [x] **4.1 Curriculum file** `content/curriculum.yaml` (`qabas.curriculum/1`, `review_status: working`, pending O-12): Units 0–10 with tracks (Unit 0 Explorer-only, AD-28), track-framed titles/subtitles in both languages, `art_key`, `pass_percent`, 93 lesson slots (`les_u{U}_l{n}`, working titles, Unit 0 focus notes) and the concept graph. A strict loader (`app/content/curriculum.py`) rejects unknown fields, duplicate units/indices/lesson IDs, non-canonical IDs, gaps in slot numbering, missing track framing, unknown art keys and invalid concept graphs (unknown units or prerequisites, cycles, prerequisites placed later, a prerequisite unavailable in one of the concept's tracks). `scripts/seed.py --check` validates it without a database.
- [x] **4.2 Curriculum slots** (migration 0002, D-30): `curriculum_slots` table; a lesson can exist only in its slot (composite FK on `(id, unit_id, index)`); positions are 0-based like the contract; one lesson per slot.
- [x] **4.3 Registries:** `content/visual_registry.yaml` (keys, versions and parameter ranges equal to the contract's `BUILTIN_PARAMS`; per-use proportions equal to API §5.5d, parsed from the vendored spec in `test_registry_parity.py`). `content/registries.json` gains `unit_art` (the compiled art set), `league_tiers` (lantern → beacon → star → dawn, zone 5) and the 8 prototype `achievements` with counters/targets.
- [x] **4.4 Lesson package** (`app/content/package.py`): one lesson version as contract models: approved `LessonPlan`, Arabic + English variants per track sharing one block skeleton, claims, sentence roles, `arc_map`, exercises with private keys and per-language feedback, glossary, misconception cards and sources. Arabic/English exercises must agree on everything except wording.
- [x] **4.5 Deterministic validators** (`app/content/validation.py`), all issues reported at once, nothing repaired (D-36): variant/track rules, skeleton and localization parity, sentence roles and supported-claim links, reasoning tools from the plan, `arc_map` order/coverage/techniques (one hook, one summary, story/predict/summary placement), 2–6 graded exercises, a flashcard per introduced concept, 2 pretest + 3 unit-test + 3 duel items, assessment-type exclusions, answer keys via `contextual.validate_answer`, feedback coverage of served IDs, myth framing needs a target, source existence and the 3-content-source budget, glossary/term spans, misconception cards, completion, and the placeholder-media gate (`contextual.placeholder_media_errors`).
- [x] **4.6 Storage and versioning** (`app/content/store.py`, D-34): `import_package` stores a new **unpublished** version only after placement, concept-registration and validation checks pass. Identical content (same digest) is a no-op; changed content becomes a new version; published versions are immutable (DB triggers). `load_package` rebuilds the exact package (digest-verified). Exercise type/purpose can never change once created (trigger QB006).
- [x] **4.7 Publication** `publish()`: latest version only; Gate 2 approval bound to the exact content digest by an active reviewer (or `FixtureApproval` for test fixtures in dev/test only, D-29); digest re-verified and content re-validated; prerequisite concepts must already be introduced by a published lesson; scene references must match a published scene version's manifest digest; sources/misconceptions/terms upserted (a conflicting source record is an error); children first, `published_at` last (D-22); lesson metadata, `xp` (D-31) and concept introductions recorded.
- [x] **4.8 Unit availability** (D-38): a unit stays `coming_soon` until it has a published lesson **and** its published pools can serve both assessments (≥ 6 pretest, ≥ 9 unit-test items).
- [x] **4.9 Projections** (`app/content/projection.py`): variant choice (New Muslim → Explorer fallback only), learner exercise projection (keys, misconception maps and duel flags never leave the server), session items, reader blocks, session sources with `displayed`/`display_role` and `source_count` (D-35), `counts`, term cards through the contract's `display_fields.project_term`. Verified byte-for-byte against all 34 contract session fixtures (every lesson × language × variant).
- [x] **4.10 Seeding** `scripts/seed.py`: the production structure (units, slots, concepts; no lesson content); idempotent; refuses to move occupied slots, drop units or concepts in use, or change tracks/index of units with published lessons. `--test-curriculum` (dev/test only) loads the contract's synthetic test curriculum (10 lessons, 3 units + a coming-soon unit) and its scene through the real import → publish pipeline.
- [~] Placeholder `referrals.yaml`, `safety_rules.yaml`, `medallions/registry.yaml`, bot user and synthetic league users: moved to the phases that consume them (D-37), so no empty production data files are created.

**Tests:** `tests/content/` (94): curriculum file structure and every curriculum error; registry parity; every content rule rejecting the violation it targets; storage round trip; versioning and immutability; approval bound to the digest; fixture origin refused outside dev/test; prerequisites; slot placement; exercise identity; unit availability; projection against the contract sessions; idempotent seeding. DB/API tests updated for slots and `origin`.
**Local status:** 312 passed, 1 skipped (role privileges, CI only); ruff and mypy clean; contract suites 595/279/105/382 PASS; OpenAPI unchanged; `alembic check` clean; migration round trip verified; production seed applied twice on the dev DB (second run unchanged).
**Exit:** ✅ CI green on GitHub (run 37209992662: 313 passed incl. role grants, contract suites green); tagged `phase-4`.

### Handoff review findings (Phase 4)

Re-review of 01_PRODUCT, 06_CONTENT, API §5.5c/5.5d/6.3/6.4, the contract models and helpers, `CHANGES.md`, the review log, the test-curriculum fixtures and generator, the Unit 0 brief and drafts, and the prototype registries and art.

| # | Finding | Handling |
|---|---|---|
| F-1 | `JLesson.index` is 0-based in the contract and fixtures; migration 0001 assumed 1-based. | Fixed by migration 0002 (D-30). |
| F-2 | `JLesson.xp` has no defined derivation; examples show values not derivable from the XP table. | Derived from the fixed XP table (D-31). |
| F-3 | API examples use unit art keys that are not in the compiled `UnitArt` set. | Only compiled keys are accepted (D-32). |
| F-4 | Contract fixtures use sentence/claim IDs like `s1`; migration 0001 enforced `sen_`/`clm_`. | Prefix checks dropped (D-33). |
| F-5 | Fixture sessions list no `sources` while exercises embed evidence. | Embedded evidence is shown by its exercise and not listed; existence still validated (D-35). |
| F-6 | Seed spec opens a unit at its first published lesson; backend/factory specs require pools ≥ 6/≥ 9 before a unit is publishable. A unit opened earlier would trap learners (pretest/unit test unservable). | Safest interpretation: both conditions (D-38). |
| F-7 | Test-curriculum prerequisites are lesson-level; the production rule is concept-level. | Each fixture lesson introduces one synthetic concept; lesson prerequisites map to those (D-29). |
| F-8 | `predict.reveal` is plain `Spans`, so its factual sentences cannot carry sentence IDs or claim links. | Not role-checked; factual reveals must also appear as claim sentences elsewhere. Raised for the factory QA rules (Phase 12). |
| F-9 | Fixture `estimated_minutes` 5 vs the 6–10 minute guidance. | Guidance, not a constant (factory §13.1); not a validation error. |
| F-10 | Prototype achievement copy «افز في تحدٍّ مباشر…» is a typo. | Corrected to «فُز» (D-39); the content specialist should confirm. |
| F-11 | No reviewed unit guides or final Arabic titles (O-12). | Curriculum marked `working` (status documented in the file header); guides absent (D-39). |
| F-12 | Unit 0 drafts: two-digit IDs, 1-based positions, a non-contract `learner_acts` field and 9 reasoning tools outside the contract enum. | Phase 8 importer; reasoning tools need a human mapping, never a guess (D-40). |
| F-13 | Contract fixtures use `mock-asset://` media. | Allowed only for `test_fixture` content in dev/test; blocked for real content (D-29). |

---

## Phase 5 — Journey, lessons and session creation

**Goal:** a learner can see the journey and start, resume and abandon every session kind.
**Refs:** BACKEND_HANDOFF §6.1–6.2, §7.3–7.6; API §3.2, §5.9, §6.3–6.5; DATA_MODEL invariants; FRONTEND S3–S7, S21, S22; CURRICULUM_AND_LEARNING_DESIGN (Roadmap/Discover, position vs prerequisites); FACTORY §13.3 (banks); QUALITY §18.1; AD-28, AD-29.

- [x] **5.1 Journey service** (`app/services/learning/journey.py`): track membership (coming-soon units list no lessons), concept prerequisites satisfied by the introducing lesson's completion or its unit's passed test, lesson states (completed > in_progress > locked > available), Soft Lock (`prerequisites` in curriculum order, transitive `start_with`), unit states (locked/completed/skipped/in_progress/available, derived from `unit_test_passed_at`, D-21), `pretest`/`unit_test` blocks, `can_skip`, `has_guide`, `art_key`, track-framed titles; published variant titles for lessons. Data that breaks a publication invariant raises instead of being hidden.
- [x] **5.2 Planner** (`app/services/adaptive/planner.py`): rules 1–5 complete on the journey view; coming-soon units are passed over (D-44); a review is recommended only when a card deck exists (D-51); `current` pointer (D-45).
- [x] **5.3 Endpoints:** `GET /journey`, `GET /journey/next`, `GET /units/{id}/guide`, `GET /lessons/{id}` (reader projection, D-47), `POST /sessions` (`201` new / `200` existing), `GET /sessions/{id}`, `POST /sessions/{id}/abandon`. Learner-only (reviewers `403`). `Accept-Language` negotiation with profile fallback (D-43).
- [x] **5.4 Session creation** (`app/services/learning/sessions.py`): lesson access (`404` outside the journey, `409 prerequisite_unmet` with Soft Lock details); variant by track (New Muslim → Explorer fallback only); one active session per key, race-safe through the partial unique index; language and variant pinned; full snapshot (`objectives`, `items`, `completion`, `sources`, `terms`, header fields) stored and replayed unchanged; `served_exercises` from the lesson version's pins and `served_scenes`; `learner_units.started_at` (race-safe upsert); every composition checked with `contextual.session_composition_errors` and the contract `Session` model before it is stored.
- [x] **5.5 Assessments:** pretest `min(8, pool)`, unit test `min(12, pool)`, from the unit's current published pools (`app/content/catalog.py`), shuffled with a CSPRNG at serve time, no repeats; exercise-only shape (`objectives: []`, `completion: null`).
- [x] **5.6 Reviews** (`app/services/learning/review.py`): card deck (one flashcard per concept, due first, up to 12) and quick review (up to 10, 20 s timer, excluded types, active-misconception and 24 h priorities) over the learner's practiced concepts, inside the learner's journey (D-46); empty → `409 nothing_to_review`.
- [x] **5.7 Resume and redaction:** answer history per feedback mode (`immediate` results + stored evaluation; `end` hidden until finish, then results; `none` always hidden); ownership `404`; abandon idempotent, `409 session_finished` after finish.
- [x] **5.8 Term cards** (`app/services/learning/terms.py`): contract `project_term` with the learner's term state and level (§7.5), lesson titles in the learner's language/variant.
- [x] **5.9 Phase 4 hardening found while building 5:** unit availability also requires reachable prerequisites (D-41); assessment pools are the exercises pinned by current lesson versions (D-41); a served bank may not spell out its answer (D-42).

**Tests:** `tests/learning/` (77): the four contract journeys (structure, Soft Locks, track membership, titles), position never gates, unit passing satisfies prerequisites, track switch keeps completions, coming-soon units, `in_progress` from any session, the planner through a whole path and with due reviews, all 34 contract lesson sessions reproduced through `POST /sessions`, Discover identity (no surface field, byte-identical content), one active session per key (also after a track change, and four concurrent starts → one session), language pinning, request validation, all six assessment compositions against the contract banks, serve-time shuffle kept on resume, card and quick review selection, track-scoped reviews, history redaction for all three modes, ownership, abandon, version pinning across a republish (title, key and feedback changes), pools after a revision, unit guides with sources and term cards, reader projection. Plus validation tests for answer-revealing banks and the open-unit decision.
**Local status:** 392 passed, 1 skipped (role privileges, CI only); ruff and mypy clean; contract suites 595/279/105/382 PASS; OpenAPI regenerated (7 new operations, contract schemas only); `alembic check` clean (no migration needed); production seed unchanged on re-run; end-to-end on the dev database with the production curriculum (all units coming soon, sessions `404`, journey complete).
**Exit:** ✅ CI green on GitHub (run 37218397023: 393 passed incl. role grants, contract suites green); tagged `phase-5`.

### Handoff review findings (Phase 5)

Re-review of BACKEND §6–7, API §3.2/§3.4/§5.9/§6.3–6.5, DATA_MODEL invariants and versioning, FRONTEND screens S3–S7/S21/S22 and UI rules, CURRICULUM (Roadmap, Discover, Soft Lock), FACTORY §13.3 (banks), QUALITY §18.1, the contract models and `contextual.py`, and the fixture generator (`tools/make_fixtures.py`).

| # | Finding | Handling |
|---|---|---|
| F-14 | The journey fixtures mark the start unit `in_progress` for a learner with no session; backend §6.1 makes a unit `in_progress` only once a session started. The generator hard-codes it. | Spec wins; the fixtures are matched after the learner starts the unit's pretest (D-49). |
| F-15 | Fixture journey lesson titles (`درس اختباري 1.1`) differ from the fixture session titles of the same lessons. | One source of truth: the published variant title (D-49). |
| F-16 | Planner rule 1 skips `coming_soon` units; rule 5 ends the journey at the next coming-soon unit; the Phase 3 planner stopped at the first one. | Rule 1 wins; units never wait (D-44). |
| F-17 | `Journey.current` is only "the planner's target"; the fixtures point at a lesson while the next step is a pretest. | Defined as the rule-3 lesson of the current unit (D-45). |
| F-18 | Under D-38 a lesson could depend on a lesson in a still-closed unit, making its Soft Lock name a lesson outside the journey (the contract model rejects that). | Such units stay closed (D-41). |
| F-19 | "Shuffle at serve time" (backend §6.2) vs "authored or server-shuffled banks" and the captured Salah bank order (factory §13.3, AD-14). An authored bank in key order would reveal the answer. | Items of assessments are shuffled at serve time; banks are served as authored/captured, and a revealing bank is rejected at validation (D-42, D-50). |
| F-20 | `GET /lessons/{id}` access (S6 "re-read a completed lesson") and which sources the reader lists are unspecified. | D-47. |
| F-21 | Review scope across tracks, and an empty quick review, are unspecified (only cards mention `nothing_to_review`). | D-46. |
| F-22 | A pretest can be requested again after it was taken; `pretest_complete` XP and `pretest_percent` would be repeatable. | Allowed (no rule forbids it); Phase 7 stores the first result only and grants pretest XP once per unit (D-52). |
| F-23 | Exercise-only sessions need a `title`; no copy is specified (fixtures use a synthetic "جلسة اختبارية"). | D-51. |
| F-24 | Planner rule 2 counts due concepts "learning or mastered" and must never recommend a review that would be `nothing_to_review`. | D-51. |
| F-25 | The contract's graded test exercises all practise `con_test`; flashcards practise one concept each. | Tests account for it; no product effect. |

---

## Phase 6 — Answers: replay-first, evaluators, per-answer adaptation

**Goal:** correct, idempotent answer handling under concurrency.
**Refs:** API §5.7–5.8, §6.5 (answers, processing order, retry rule), §6.6 (recitation binding), §7 (exercise catalog); BACKEND_HANDOFF "Transactions and effects", §6.3, §7.1–7.2, §8 step 10, §10.1; DATA_MODEL invariants; AD-08–AD-12, AD-24, AD-25; FRONTEND S4 and exercise rules; QUALITY §18.1; contract `contextual.py`, `EVALUATION_CONTEXT.json`, `fixtures/exercises/*`, `fixtures/negative/*`.

- [x] **6.1 Processing order** (`app/services/learning/answers.py`): authenticate → rate limit (`session_answer`, 120/min) → load + ownership (`404`) → parse only `exercise_id`/`is_retry` → recorded identity replays the stored mode-permitted response (even after finish/abandon, whatever the body) → lock the session row and re-check (a concurrent duplicate replays the winner) → `409 session_finished`/`session_not_active` → served check (`400`, `field: exercise_id`) → retry eligibility (`409 retry_not_allowed`) / authored order (`409 out_of_order`) → full body validation (`400`) → grade, apply, record in one transaction. The route reads the raw body so FastAPI never validates eagerly; OpenAPI still documents the contract `AnswerSubmit`.
- [x] **6.2 Evaluators** (`app/services/learning/grading.py`, pure): all 14 lesson types and both presentations of `categorize`/`map_place`, plus challenge `true_false`; against the served exercise and the pinned `exercise_versions` key; per-type `details` (reason flags, per-item results in key order, `first_wrong_index`, chronological `event_dates`, `pin_labels`, the chosen scenario option's feedback); timeouts; neutral `skipped`/`unavailable`; flashcard ratings; `categorize` validation with `details.reason` (D-58). Reproduces **all 86** contract evaluation fixtures and rejects every negative fixture.
- [x] **6.3 Rules:** attempt identity (one original + one retry), retry only after an incorrect first attempt in a lesson for retryable types, authored order for first attempts, finished/abandoned sessions, `immediate` → full evaluation vs `none`/`end` → `{exercise_id, recorded}`; the full evaluation is always stored.
- [x] **6.4 Per-answer effects** (`app/services/learning/adaptation.py`): Decimal mastery through the contract's `update_mastery` (six decimals stored, half-up two decimals reported), pretest half weight, retry +0.10 / no change, flashcard `hard`, recitation passed +0.15, neutral → nothing; misconception evidence, activation (card returned), re-show, streak and resolution (D-57); recitation XP 3 once per exercise per session via a unique `xp_events` grant (D-60); `term_changes` always empty (D-53). The issued evaluation is re-checked with `contextual.validate_evaluation` before it is stored.
- [x] Lock order: session → concepts ascending → misconceptions ascending (D-56); missing learner rows created with `ON CONFLICT DO NOTHING` first.
- [x] Grading uses the version in `sessions.served_exercises`; the misconception card comes from the exercise's own lesson version (D-55).
- [x] `recite_verse` binding: the referenced check must be the caller's and match surah, ayah, word range and text digest, else `409 recitation_check_mismatch` (D-62). The ASR producer of checks is Phase 10.
- [x] Phase 4 fixes found here: misconception cards were stored as Python objects (publish failed for any lesson with a misconception); test-curriculum exercises now carry the sources their feedback cites; lesson/pretest/unit-test items must be untimed in real content (D-61).

**Tests:** `tests/learning/test_grading.py` (112: all contract evaluation contexts, negatives, categorize reasons, timeouts, identity parsing), `test_answers.py` (15: every lesson type through real sessions equal to the contract evaluations, exact six-decimal mastery across 40 answers, neutral outcomes, retry rules, wrong retry never lowers mastery, authored order, replay with same/changed/malformed bodies, finished/abandoned, ownership/unserved/invalid bodies, assessments recorded without revealing (half-weight pretest), flashcard ratings, quick-review timeouts, four concurrent duplicates → one row, two devices racing the retry, half-up display), `test_misconceptions_and_recitation.py` (4: activation/re-show/resolution/reactivation, retries untouched, recitation binding mismatches, XP once, failed and skipped recitations), plus the untimed-items validation test.
**Local status:** 524 passed, 1 skipped (role privileges, CI only); ruff and mypy clean; contract suites 595/279/105/382 PASS; OpenAPI regenerated (`POST /v1/sessions/{id}/answers`, contract schemas only); `alembic check` clean (no migration needed).
**Exit:** the evaluators and the effects landed together, so there is no separate `phase-6.1` checkpoint. ✅ CI green on GitHub (run 37221363500: 525 passed incl. role grants, contract suites green); tagged `phase-6`.

### Handoff review findings (Phase 6)

Re-review of API §5.7–5.8, §6.5–6.6, §7 (every exercise type and mode), §8 (challenge answer shapes); BACKEND §6.3, §7.1–7.2, §8, §10.1–10.3 and the transaction rules; DATA_MODEL invariants; ARCHITECTURE AD-07–AD-13, AD-23–AD-25; FRONTEND screens and exercise rules; PRODUCT and SHARED_IMPLEMENTATION_PLAN exercise coverage; QUALITY §18.1; `contextual.py`, `EVALUATION_CONTEXT.json`, the exercise and negative fixtures and the generator `make_fixtures.py`.

| # | Finding | Handling |
|---|---|---|
| F-26 | Backend's transaction paragraph lists "term exposure" as a per-answer effect, but §7.6 defines exposure as finished sessions containing the term with promotions at finish; every contract evaluation has `term_changes: []`. | §7.6 wins (D-53). |
| F-27 | API §5.7: lessons, tests and card reviews are untimed; the contract's test-curriculum lesson fixtures and specimens carry `time_limit_ms: 20000` (assessment fixtures are untimed). | Real content must be untimed; fixture-only exemption (D-61). |
| F-28 | The scenario timeout fixture shows the wrong option's feedback although no option was chosen (generator copies the incorrect case). | No option chosen → empty `option_feedback` (D-59). |
| F-29 | `categorize` `details.reason` values are unspecified; the fixtures use `duplicate_or_missing_item`, also for an over-full `day_arc` slot. | D-58. |
| F-30 | `contextual.validate_recitation_binding` compares a check's `exercise_id`/`exercise_version`, which the data model's `recitation_checks` doesn't have; API §6.6 binds by user, surah, ayah, range and text digest. | Data model + API §6.6 (D-62); Phase 10 revisits. |
| F-31 | "Authoritative deadlines": sessions record no per-exercise issue time, so lesson/review timers can't be enforced server-side. | D-63; challenges get persisted deadlines (Phase 19). |
| F-32 | Misconception evidence when an answer both picks a mapped option and misses a targeting exercise, and what happens to a resolved misconception chosen again, are unspecified. | D-57. |
| F-33 | Misconception cards live in a mutable registry row, so a republished card could change what a pinned session shows. | D-55. |
| F-34 | `week_key` is "ISO year + week starting Sunday 00:00 Asia/Riyadh" with no format. | D-60. |
| F-35 | Phase 4 bugs: misconception cards stored as objects (publication failed); test-curriculum exercises had no `source_ids` although their feedback cites `src_q_112_1`. | Fixed. |
| F-36 | Nothing limits rewards across repeated sessions: recitation XP is "once per exercise per session", so abandoning and restarting a lesson can earn it again (with a genuinely passing recitation each time). | Phase 6 followed the per-session rule (D-64). Resolved in Phase 7 by D-67: canonical cross-session claims, preserving legitimate repeated learning and D-52. |
| F-37 | The order of per-item results, `event_dates` and `pin_labels` is unspecified. | D-65. |

---

## Phase 7 — Finish transaction, FSRS, planner, reviews, glossary, stats

**Goal:** complete the durable learning slice (**Milestone A**).
**Refs:** BACKEND_HANDOFF §6.4, §7.3–7.6, §10.1–10.2, §10.5–10.6; API §6.2, §6.5, §6.7.

- [x] XP grants follow the fixed table, which also drives the displayed `JLesson.xp` (D-31); keep the two in one place.
- [x] Pretest: store the first result only (`pretest_taken_at`/`pretest_percent` set once) and grant `pretest_complete` once per unit (D-52).
- [x] Finish takes locks in the answer order (session → concepts ascending → misconceptions ascending → terms, D-56).
- [x] Create FSRS cards and set `learner_concepts.first_practiced_at` at finish for concepts practised by non-retry, non-pretest answers (D-54); term exposures and promotions at finish (D-53).
- [x] Decide the repeated-reward policy for `lesson_complete`, `lesson_perfect`, `review_complete` and recitation XP across repeated sessions of the same lesson (F-36, D-64), alongside D-52.
- [x] Finish writes the facts the journey derives from (D-21): `learner_lessons.completed_at`, `learner_units.unit_test_passed_at`/`unit_test_best_percent`, `completed_at`/`skipped_at`; FSRS cards set `first_practiced_at`/`due_at`, which feed review selection (Phase 5).
- [x] `POST /sessions/{id}/finish`: one transaction that stores and replays `SessionResult` (score, layers, `lesson_perfect`, `passed`, `review_items`, `duration_ms` clamp, XP grants, daily activity/streak/daily goal, quest progress and rewards, FSRS updates, term promotions, `unlocked`, `next_step`); pretest/first-post percentages; unit skip.
- [x] Outbox events for unreported effects (`session:{id}:finished` → achievements/leagues/metrics consumers, added in their phases).
- [x] FSRS service (py-fsrs), card review and quick review selection, `409 nothing_to_review`.
- [x] Planner (`GET /journey/next`): complete rules 3–4 (lesson and unit-test steps) on the journey service; rules 1, 2 and 5 exist since Phase 3. Level, `/me/concepts`, `/me/stats`, `/me/activity`, `/me/quests` (lazy deterministic quests).
- [x] Glossary: `GET /glossary`, `GET /glossary/{id}`, `POST /glossary/{id}/opened`.

**Implementation:** atomic stored-result finish; private start mastery, term-concept and assessment-threshold pins; FSRS cards; canonical completion facts; reward uniqueness across sessions; exact daily duration; deterministic quests and reward cascades; learner profile and glossary endpoints; finish outbox. Planner rules 3–4 already existed in Phase 5 and are exercised through real completions here.

**Validation:** 556 passed, 1 skipped locally (the existing role-grants check runs with CI-created roles); strict mypy (77 files), ruff, current OpenAPI and repository safety guard pass. Revision 10 suites: 595/595, 279/279, 105/105, 382/382; regenerated schema unchanged. Development migration upgrade → downgrade → upgrade and `alembic check` pass; full tests also verify migration round-trip/parity. Acceptance tests cover the contract §6.5 arithmetic, scoring/FSRS rules, curriculum completion in both tracks, end/none history, original/retry/finish races, concurrent finishes and overlapping reviews, rollback before commit, outbox redelivery, repeated rewards, terms, quests, daily activity, legacy-state rejection and long-lived sessions. GitHub CI passes all 557 tests including role grants, all static checks and all contract suites. The existing Starlette/httpx deprecation warning remains; no tests were weakened or removed.

### Handoff review findings (Phase 7)

Re-reviewed the completed tracker records and D-01–D-66/F-01–F-37; searched the entire handoff (including history) for repeated rewards and finish/progression requirements; reviewed PRODUCT/CURRICULUM, CONTENT/FACTORY/SEED, API §6.2/6.5/6.7, backend transaction rules/§6.4/§7.3–7.6/§10.1–10.6, data model, architecture decisions and quality gates. Checked revision 10 session/result/evaluation/history/review/workflow models and fixtures, recovery, existing implementation and tests, OpenAPI, Git history and phase tags. Existing dependencies remain open.

| # | Finding | Handling |
|---|---|---|
| F-38 | No authoritative cross-session reward policy exists. Per-session recitation permits abandon/restart farming (F-36); arbitrary repeat reviews can farm completion/quest XP. | D-67: canonical one-time rewards, scheduled-review eligibility and shared daily cap; learning repeats remain possible. |
| F-39 | Phase 6 did not capture start mastery or exact misconception transitions. First evaluation values cannot reconstruct the historical start after concurrent activity. | D-68: private immutable start snapshot and per-answer transition audit. Legacy active records lacking authoritative start data reject finish; no rounded reconstruction/reset. |
| F-40 | Integer minute storage loses repeated sub-minute durations; §6.5's illustrative result has 7 minutes of prior activity yet says extended_today=true. | D-69: accumulate capped milliseconds and derive qualification. Example score/layers/XP/duration/goal/mastery arithmetic is reproduced; extension uses actual prior qualification. |
| F-41 | Percentage rounding and multiple flashcards for one concept are unspecified. | D-70/D-75: half-up percentages; worst explicit card rating overrides other answers. |
| F-42 | API permits state=new but backend §7.6 excludes unseen terms from the personal glossary. | D-71: explicit new is an empty personal filter; known published term detail/open still works. |
| F-43 | Quest progress follows XP events, but API §5.8 grants all other XP at finish; reward XP contributing to earn_xp is unspecified. | D-72: recitation progress at answer, rewards at finish; all actual same-day XP counts through a bounded cascade. Repeated activity counters require newly eligible work. |
| F-44 | Unit-test pass_percent and contained term→concept links were mutable during active sessions. | D-73: capture them privately at serve time. |
| F-45 | int32 session duration could overflow for a long-lived active session, despite contract-valid wall-time clamping. | Migration 0003 widens duration to bigint; qualifying time remains capped at 20 minutes per finish. |
| F-46 | Phase 5 returned end-mode outcomes without stored evaluations; fixtures permit null, while the API allows feedback at the result/review stage. | D-74: reveal stored unit-test evaluations after finish only; pretests remain hidden; answer replay shape unchanged. |
| F-47 | FSRS settings/version were unspecified; contract Page factory classes collide in FastAPI component naming. | D-75 pins FSRS. OpenAPI aliases only structurally identical pages to unchanged exported roots; unknown schemas still fail. |

**Exit:** Integration gate 3 passed: contract §6.5 arithmetic through published content, answer/retry/finish → quest rewards → next step, concurrent finish/answer/review, transaction rollback, history recovery and outbox redelivery. GitHub CI [37226971161](https://github.com/Abdulrahman-me/Qabas/actions/runs/37226971161) green (557 passed including role grants; all contract suites/static checks green). Checkpoint `phase-7` follows the established fast-forward merge to `main`.

### Phase 7.1 — independent audit and corrections (corrective checkpoint `phase-7.1`)

Phase 7 was delivered by another agent. It was re-audited end to end before Phase 8: the tracker (Phase 7 checklist, D-01–D-75, F-01–F-47), the whole handoff for completion/progress/mastery/XP/rewards/streaks/quests/reviews/terms/history/visibility (API §3.5, §5.8, §6.2, §6.5, §6.7; backend §5.1, §6.4, §7.3–7.6, §10.1–10.7; data model; AD-11/AD-24), the revision 10 models and finish/history/workflow fixtures, the code (`finish.py`, `progress.py`, `spaced.py`, `profile.py`, `terms.py`, `locking.py`, answer/session changes), migration 0003, the OpenAPI output, the tests and the Git history `phase-6..phase-7`. The baseline was reproduced (556 passed, 1 CI-only skip).

**Verified as correct:** single-transaction finish with stored-result replay before body validation (also malformed bodies), `409 out_of_order` with `missing_exercise_ids`, `409 session_not_active` for abandoned sessions, duration clamp to wall time; score/layers/perfect over accuracy-counted graded first attempts with half-up percentages; mastery summary from the private start snapshot; FSRS per §7.4 (pretest excluded, flashcard override, neutral/retry excluded); term exposure/promotion per §7.6; completion facts, unit skip/complete, first-post percentage, pinned pass threshold, first pretest result; XP via unique grants; daily activity with exact milliseconds and the 20-minute cap; streak with today/yesterday grace; quests per §10.6 (pool, goals, rewards, progress tied to XP-writing events); unlocks and next step; outbox event on finish; session → advisory → concepts → misconceptions → terms lock order; concurrency, rollback and redelivery tests. **The repeat-reward policy (D-67) was checked against the whole handoff:** nothing authoritative requires repeat rewards, every reward stays unique under concurrency and replay (database unique keys), and repeated learning keeps all learning effects (mastery, FSRS, exposures, time, streak, best scores). The daily cap on `review_complete` is necessary, not only conservative: an `again` rating makes a card due again within minutes, so "due and unconsumed" alone would let reviews be repeated for XP.

| # | Finding | Handling |
|---|---|---|
| F-48 | `/v1/glossary` and `/v1/me/concepts` defaulted to 30 items and accepted up to 100; API §3.5 fixes default 20, max 50. Either cursor prefix was accepted on both lists. | D-78; fixed and tested; OpenAPI regenerated. |
| F-49 | `POST /sessions/{id}/finish` was not rate-limited; backend §5.1 gives answers *and* finish one 120/min budget. | Finish now draws from `session_answer`; tested. |
| F-50 | No outbox consumer existed for `session.finished`: in production every finish event would fail and retry forever (warning per attempt), until Phases 15/18. | D-77: a dispatcher consumer with named subscribers; tested (completes with none, fans out once with one). |
| F-51 | Legacy active sessions (started before migration 0003, no learning snapshot) could not be finished (`500`) and, being the learner's active session for that key, would block the activity indefinitely; the database permitted the state. None exist anywhere (dev DB holds no sessions, the test DB is rebuilt per run, no staging/production yet), but nothing prevented it. | D-76 (supersedes D-68's legacy clause): migration 0004 refuses to upgrade while such sessions exist and adds `CHECK (status <> 'active' OR learning_snapshot IS NOT NULL)`; `scripts/abandon_legacy_sessions.py` abandons them explicitly. Tested with a real downgrade/upgrade round trip. |
| F-52 | Quest titles were ungrammatical ("Complete 1 lessons", «أكمل 2 من الدروس» where API §6.2 shows «أكمل درسين»). | D-78; number-agreeing titles; tested. |

**Validation:** 561 passed, 1 skipped locally; ruff, strict mypy (79 files), OpenAPI current, `alembic check` clean, migration round trip incl. the 0004 guard, repository safety guard OK; contract suites unchanged.
**Exit:** ✅ CI green on GitHub (run 37229813941: 562 passed incl. role grants, contract suites green); corrective checkpoint `phase-7.1` (the original `phase-7` tag and history are kept unchanged).

---

## Phase 8 — Content import, approval-gated publish, staging

**Goal:** the one production path by which real authored content reaches learners (convert → import unpublished → specialist approval of the exact digest, which publishes), applied to the real Unit 0 drafts and the Salah reference, failing clearly wherever a human decision, verified source or published media is still missing; staging support for frontend integration.
**Refs:** FACTORY §13 (writing, exercise, QA rules), §13.6–13.8; SEED_AND_IMPORT; CURRICULUM_AND_LEARNING_DESIGN; CONTENT_AND_BRAND_POLICY; STATUS O-05/O-06/O-12/O-13/P-07; API §5.6–5.7, §7; QUALITY §18.1 `test_salah_reference`; UNIT_0_CONTENT (README, authoring brief, records); reply8 `reference_export` (README, EXPORT_REPORT, gold candidate, native snapshots); FRONTEND_DEMO_HANDOFF (README, SESSION_INDEX, SOURCE_INSERTION_PENDING).

- [x] **8.1 Gold files and import** (`app/content/gold.py`, `scripts/import_gold.py import`): `qabas.gold/1` = a `LessonPackage` plus provenance; imported through Phase 4's `import_package(origin="gold_import")` (every validator, slot placement, concept registration), always **unpublished**, lessons marked `is_gold`; identical re-import is a no-op (D-79).
- [x] **8.2 Approval-gated publication** (`scripts/review_gold.py`): the reviewer authenticates with their own password; approval names the exact content digest; the Gate 2-equivalent `review_decisions` row (with `published_digest`) and the publication commit together (§13.6); stale digests, inactive reviewers, non-gold versions and already-published versions are refused; rejection is recorded with a reason (D-79).
- [x] **8.3 Unit 0 converter** (`app/content/importers/unit0.py`): projects the authoring records (the authoritative source, D-80) mechanically (D-82) and blocks on what they cannot supply (D-81). Run on the real drafts: **all 12 lessons blocked** — see the findings below.
- [x] **8.4 Salah converter** (`app/content/importers/salah.py`): lossless projection of the four exported variants (verified item-for-item against the export: 14 steps each); the §13.7.2 additions arrive in a content-team **completion record** (`qabas.salah_completion/1`, D-83); **blocked** today.
- [x] **8.5 Reasoning-tool mapping** `content/mappings/reasoning_tools.yaml`: the nine draft tools listed, every entry `null`, `status: pending` until a specialist records the approved mapping (D-40). No mapping guessed.
- [x] **8.6 Content locations** (D-19): converters write pending gold to git-ignored `backend/.private/content/gold/`; approved gold will be committed under `content/gold/`; one importer in every environment.
- [x] **8.7 Staging support** (D-84, D-86): `APP_ENV=staging` may hold the synthetic test curriculum (never production) and imports/publishes approved content through the same gold path; README section. The staging *host* itself is an operations dependency.
- [~] `test_salah_reference.py` (published Salah sessions equal to the fixtures): **blocked** with the Salah lesson (O-05, O-06, P-07, completion record). Its projection half is proven now (`test_private_handoff_content.py`).
- [~] Unit 0 import into a review database: **blocked** until the mapping, Arabic plan text, concept registration, verified sources and published scene media exist (O-12, O-05, O-13, Phase 9/14).

**Tests:** `tests/content/test_unit0_converter.py` (12: a resolved neutral record converts to a lesson passing every Phase 4 validator; each blocker kind with its owner; flattened claims; published scene media), `test_salah_converter.py` (4: lossless projection, no authoring without a completion record, completion merge equals the stored lesson, export/media blockers), `test_gold.py` (4: gold round trip; import unpublished/no-op; authentication; inactive reviewer; stale digest; atomic approve+publish with `published_digest`; already published; rejection with reason; fixture content never takes the gold path; the `convert` command's report), `test_private_handoff_content.py` (3, local only: all 12 Unit 0 lessons blocked exactly by the recorded inputs; with stand-ins for those inputs lessons 0.5/0.6/0.8 pass every validator; Salah export blocked and lossless). Updated: production refuses fixture content (staging allowed).
**Exit:** ✅ CI green on GitHub (run 37232368721: 582 passed incl. role grants, 3 private-content tests skipped as designed, contract suites green); tagged `phase-8`.

### Handoff review findings (Phase 8)

Re-review of 01_PRODUCT (curriculum incl. the 0.1 reference design, content/brand policy), 06_CONTENT (factory §13.1–13.8 incl. writing/exercise/image rules and the QA table), SEED_AND_IMPORT, STATUS (O-05/O-06/O-12/O-13/P-07), API §5.6–5.7/§7, QUALITY §18.1, the Unit 0 package (README, brief, 12 records, scenes, reviews), the reply8 reference export and the frontend demo handoff.

| # | Finding | Handling |
|---|---|---|
| F-53 | Every Unit 0 plan writes its arc rationale, arc-step experiences and reasoning-tool justifications in English only; the contract requires both languages (187 places). | Blocked (`plan_text_missing`); the Arabic must be authored, not machine-made (D-81). |
| F-54 | The drafts use 9 reasoning tools outside the contract's six, in every lesson (168 references across plans and claims). | Pending mapping file (D-40); blocked. |
| F-55 | Lessons 0.1–0.4 assert 18 claims only inside fields the contract types as plain spans (hook, prediction reveal, callout, feedback), where the claim link would be lost. | Blocked (`claim_in_span_field`); a claim also linked by a sentence elsewhere is accepted. |
| F-56 | 22 source-based claims, 16 scripture placeholders (`insert_by_code`) and a sourced story (lessons 0.7, 0.9–0.12) await verified insertion. | Phase 9 provides canonical Arabic Quran insertion; English translation selection, hadith record bindings, the 22 claims and story remain `source_pending` under O-03/O-05 and D-92/D-93. This finding is only partially resolved. |
| F-57 | Unit 0 visuals are generated scenes; O-13 states no Unit 0 lesson can be production-ready without the normative renderer, a released capability and published scene media. | Blocked (`scene_media_unpublished`); the converter accepts published scene media from Phase 14. |
| F-58 | The drafts write the same data in alternative forms (pool keys as `correct_answer` / `answer_key` / nested; explanations as spans or sentences; option feedback as list or map). | Normalised losslessly (D-82); never reinterpreted. |
| F-59 | Factory §13.7.2 says "the backend adds" the plan, claims, roles, arc map, keys mapping, flashcards and assessment/duel items to the Salah reference; these are new religious teaching content. The prototype also lacks per-option scenario feedback. §13.7.3 requires checking hadith/Quran against Dorar and the mushaf before import, which needs Phase 9. | D-101/D-104 provide mechanical gold-import scripture/binding checks in Phase 9. D-83/D-85 still require the content-team completion record and verified bindings; engineering authors none of the missing content. O-05 remains open. |
| F-60 | The Salah export's own blockers: licensed recitation clip and timings absent (`unavailable://…`), scripture copied from the prototype, API playback parity not run, registries not finalised. | Reported as `media_unavailable`, `source_pending`, `reference_acceptance`, `completion_record_missing`. |
| F-61 | The production slot of the Salah reference (3.2 as-is, adapted or merged with 3.1) is open (P-07); the export keeps fixture id `les_u1_l3`. | Part of the completion record (`target_lesson_id`, `decided_by`); blocked until decided. |
| F-62 | The frontend demo sessions are a mock projection (inside a ZIP, localhost media, scripture replaced by draft notices), not an import source. | The authoring records are the source (D-80). |
| F-63 | Unit 0's 13 concepts (34 references across the plans) are not in the curriculum graph; registering them is part of the O-12 review. | Blocked (`concept_unregistered`); no draft concept added to the public curriculum (D-87). |
| F-64 | The plan asks for staging with the test curriculum, which D-29 confined to dev/test; a staging host does not exist yet. | D-84 (staging allowed, production never) and D-86 (host is an operations dependency). |
| F-65 | CI found a Phase 7 test that depended on the time of day: it finished sessions on a clock 40 minutes ahead but read `/me/stats` with the real clock, so within 40 minutes of the learner's local midnight the two disagreed. Product behaviour was correct. | The test now uses one clock for finishing and reading; verified across local midnight. |

---

## Phase 9 — Source adapters (tool layer)

**Goal:** verified, cached, failure-tolerant evidence tools. The factory and verified scripture insertion depend on them.
**Refs:** SOURCE_ADAPTERS §12, §12.1; OPERATIONS timeouts/retries.

- [x] `normalize_ar` + mushaf loader (`get`, `find_exact`, `find_fuzzy`).
- [x] Adapters: Quran Foundation (search, audio + word timings; translation via QuranEnc, D-93), Tafsir Center MCP (stdio, fake-server validation pending O-03 delivery), Dorar (native pinned Node sidecar), HadeethEnc, QuranEnc, IslamHouse. Unsupported REST search remains the explicit D-96 follow-up.
- [x] Common: timeouts 5 s/15 s, 2 retries with jitter, circuit breaker, adapter version, Redis cache (7 days only under confirmed terms), `sources.raw` with provider ID, retrieval time and SHA-256; concurrent-safe immutable persistence and `SourceChanged`.
- [x] Verified scripture insertion by code, Unit 0 resolver and pre-write gold-import checks. Arabic Quran placeholders have the canonical insertion path; English selection and human source bindings remain gated.
- [x] Recorded-response fixtures for tests (no live calls in CI), synthetic mushaf and fake stdio MCP server.

**Gates:** O-03 (credentials/licenses/cache terms). Mock adapters proceed without them.
**Exit:** tag `phase-9`.

**Completed continuation record (branch `phase/9-source-adapters`; checkpoint `phase-9`).**
Inherited commits `463a616` and `0332e69`: source matrix/manifests, pinned King Fahd mushaf, normalization, resilience/cache core, QuranEnc/HadeethEnc/Dorar, sidecar manager, conservative grades, recordings and 47 source tests. `main` was verified at `a79a783`; no previous history was rewritten. The entire 15-page organizers' PDF and handoff were independently reviewed before continuation.

Continuation adds Quran Foundation scoped OAuth/current search/audio metadata, IslamHouse with response/log redaction, a bounded stdio MCP client with a synthetic server, source persistence with concurrent-insert arbitration and `SourceChanged`, canonical scripture insertion, Unit 0 resolver integration and gold-import checks/private provenance snapshots. The original adapter/resilience checkpoint is pushed as `5564488`. Real provider approvals remain pending: these integrations are not declared production-live.

Final integration checkpoint `f3e91ee`: focused tests **134 passed**; full local suite **702 passed, 1 skipped** (local database-role check; role grants pass in CI), including the installed canonical dataset and private handoff checks. GitHub CI [37252965749](https://github.com/Abdulrahman-me/Qabas/actions/runs/37252965749) is green: **689 passed, 14 skipped** (11 canonical-dataset and 3 private-handoff checks absent from the public checkout). Ruff, strict mypy (112 files), OpenAPI freshness, repository safety and revision 10 suites **595/279/105/382** all pass. The existing Starlette/httpx deprecation warning remains; no test was weakened or skipped to fix a failure.

The real private Unit 0 CLI conversion was exercised with the installed dataset and pending translation manifest: **0/12 ready**, as required by the remaining human/media gates. No Arabic Quran insertion failure remains; the report retains 31 source blockers (6 English translation cards, 2 hadith bindings, 22 claims and 1 story), plus the existing reasoning/plan/concept/scene/content-structure blockers. No unfinished lesson was imported or published. The same ignored `PRODUCT_PROGRESS_NOTES.md` has its Phase 9 section; neither it nor the mushaf JSON is committed.

**Explicit follow-ups permitted by the Phase 9 gate:** HadeethEnc/IslamHouse text search moves to the association MCP after its schemas/terms are delivered (D-96); MP3Quran ayah timing is a later optional capability (D-95); terminology sources belong to the Localizer (D-97). Quran Foundation translation is supplied through the selected QuranEnc authority route (D-93). No unsupported operation is silently substituted.

| # | Finding | Resolution / gate |
|---|---|---|
| F-66 | The handoff's normalization ranges omit King Fahd's Extended-A/open-tanween marks. | Add U+08D3–U+08FF for matching; preserve canonical stored text. |
| F-67 | IslamHouse returns HTTP 200 with an error body for missing items. | Recognize the recorded missing-item error only; other malformed/error bodies are outages. |
| F-68 | Public Quran.com v4 search returns HTTP 204 (retired endpoint). | Keep its recording as failure evidence; use current authenticated Search API, never empty fabricated evidence. |
| F-69 | HadeethEnc English cards omit reference/attribution/grade fields. | Join the Arabic card by ID, keep provider attribution explicit. |
| F-70 | Dorar sharh places takhrij in `grade`; some hadith text contains an editorial bracketed gloss. | Never grade from sharh; retain verbatim text and flag editorial brackets for review. |
| F-71 | Inherited fuzzy trimming could use query coordinates when the query exceeded the candidate length, and alignment can be null. | Use canonical destination coordinates and handle no alignment; discovery still cannot insert. |
| F-72 | A documented-shape failure after HTTP 200 could reset the breaker and enter the cache before adapter validation. | Validate before success/cache; malformed responses count as failures and are not retried. Cancellation releases half-open slots. |
| F-73 | The pinned sidecar cached for five seconds despite pending terms; NodeCache TTL zero means infinite storage. It also raised the provider's default access limit. | Disable NodeCache using a tested preload; retain the original rate limit; verify actual checkout and minimize child environment (D-100). |
| F-74 | Current Quran Foundation search uses a separate endpoint and `search` OAuth scope, not the Content API token. | Separate memory-only scoped tokens; mock-test current search and bounded 401 refresh. Credentials still O-03. |
| F-75 | Bilingual exercise payload IDs must match even though translations require separate provenance. | One identity for the same complete verified bundle across languages; new bindings get a new fingerprint (D-98). |
| F-76 | Phase 8 gold imports deferred canonical scripture checks and private adapter snapshots. | Check Quran bodies, embedded exercise evidence and recitation ranges before writes; persist snapshots atomically with the unpublished lesson (D-101). |
| F-77 | The first continuation CI run exposed production-gate tests relying on local `.env` platform secrets. | Supply explicit neutral test platform configuration, omit provider credentials; keep production validation and all assertions intact. |
| F-78 | A provider can change a grade/grader/reference or translation version while its quoted text remains identical; text-only replay must not authorize new attribution against an old snapshot. | Reject changed citation/critical attribution metadata with `SourceChanged` (D-104). Gold hadith bodies also require Dorar bindings, exact excerpts and recorded grades/collections before import. |


---

### Phase 9.1 — independent audit and corrections (corrective checkpoint `phase-9.1`)

Independent re-review of the completed Phase 9 (`phase-8..phase-9`, 77 files): the tracker (D-88–D-104, F-66–F-78, O-03/O-05/O-06), SOURCE_ADAPTERS §12/§12.1, operations timeouts, factory §13.7.3, the contract (`Source`, `Evidence`, `QuranBody`, `Audio`, `PReciteVerse`, `HadithBody`), the organizers' package, `SOURCE_POLICY.md`, the three source manifests, all of `app/sources/`, the gold/Unit 0 integration, the recordings and every Phase 9 test. Baseline reproduced: **702 passed, 1 skipped** locally.

**Verified as correct:** the digest-pinned King Fahd dataset (archive + member SHA-256, structural validation, not committed); `normalize_ar` ranges (§12.1 + U+08D3–U+08FF); exact `get`/word ranges and name/number contradiction refusal; fuzzy matching is discovery only (no path from `find_fuzzy` to `insert`); insertion takes Arabic only from `Mushaf.get`, translations only under the approved key **and** version with per-ayah canonical Arabic agreement; invalid timings become `words: null`; timeouts 5 s connect / 15 s read, two jittered retries for transport/timeout/429/5xx only, 404 = definite not-found (never an outage, never fabricated), malformed bodies validated before success/cache and counted as failures; breaker 5 failures / 60 s / one half-open trial; Dorar grades only from search/get/alternate (never sharh); the conservative grade table; HadeethEnc translations joined to the Arabic record; collection-number hadith citations stay blocked (D-92); O-03 production refusal and zero cache under pending terms are enforced in code; immutable persistence with concurrent-insert arbitration and `SourceChanged` on text/citation/critical-attribution change; gold checks run before any write inside the caller's transaction; the real Unit 0 conversion remains 0/12 ready. The 14 CI skips are exactly the 11 canonical-dataset and 3 private-handoff checks; every production invariant they touch is also exercised publicly on the synthetic mushaf or real recordings.

| # | Finding | Resolution |
|---|---|---|
| F-79 | `scripture.insert` with a word segment and Quran Foundation audio returned the **whole-ayah clip URL** with the segment's timings. `PReciteVerse.audio` is required to be a clip of exactly the recited words, cut at publish time (backend §8 step 8); the gold check would have accepted such a payload. A test asserted the defect. | Segment insertion refuses capability audio (`CapabilityMismatch`); segment clips arrive with the licensed media pipeline (O-06/Phase 14). Test corrected. |
| F-80 | `store.persist` accepted any record, so capability data (Quran Foundation verse text/search/audio records, `kind=quran`) could become a citable `sources` row; gold import persisted every snapshot including audio capability records. | Only authority records (and canonical insertion records carrying the mushaf text-authority part) are citable; capability snapshots stay inside the authority row's `raw` (D-106). |
| F-81 | Any exception outside the handled classes during a half-open trial (e.g. `OperationUnsupported` from a validator) left the slot occupied, so the breaker refused that provider for the life of the process. Valid IslamHouse items of a non-citable type or another language were classified as malformed responses and counted as outages. | The trial slot is released on every exit; those IslamHouse answers are definite `RecordNotFound` and leave the breaker untouched. |
| F-82 | A cache hit was served before the O-03 live gate. | The production live gate now precedes the cache: cached provider data is still that provider's data. |
| F-83 | The learner-facing canonical Qur'an `Source` was titled with the dataset name ("…KFGQPC developer data (JSON)") and linked to a 10 MB zip archive. | Title names the surah and edition, reference `surah: ayahs`, link to the verse reading page (D-105). |
| F-84 | `SOURCE_POLICY.md` presented Tafsir Center as the organizers' tafsir authority. The organizers' tafsir rule (p. 3) names first-three-centuries sources or dorar.net/tafseer; Tafsir Center appears among recommended external platforms; the handoff's Mukhtasar-first order names later works. | Recorded as a specialist decision (D-107); the adapter was already mock-only (D-103), so no learner-facing tafsir is affected. |
| F-85 | Gold hadith/translation/audio snapshots are checked for consistency with the lesson and with each other, but their provenance is operator-supplied (private gold envelope); they are not re-fetched at import, and the reviewer's digest approval covers the public lesson, not `raw`. | Accepted trust boundary for unpublished import; live re-verification of every cited snapshot before production approval is a recorded gate (D-108, O-03). |

**Exit:** corrective checkpoint `phase-9.1` once CI is green (the original `phase-9` tag and history stay unchanged).

---

## Phase 10 — Recitation service (`asr` worker)

**Goal:** complete the learner-facing lesson experience (**Milestone B**).
**Refs:** BACKEND_HANDOFF §8; API §6.6; AD-22.

- [ ] `POST /recitation/checks` (multipart, signature and decoded-duration validation).
- [ ] `asr` Celery worker: restricted ffmpeg, faster-whisper (CTranslate2 int8) loaded once, prefetch 1; API waits ≤15 s; `503` back-pressure with `retry_after_ms`; audio deleted on every path.
- [ ] Expected words + range validation, DP alignment with rapidfuzz ≥80, outcome classes, unclear rule, localized messages, `audio_segment` from timings.
- [ ] `recitation_checks` persistence + `recite_verse` binding in grading (`409 recitation_check_mismatch`), recitation XP and mastery.

**Tests:** `test_recitation_range`, `test_asr_backpressure`, a recorded clip set (≥10 clips).
**Gates:** O-03 (model license, CPU throughput), O-06 (held-out learner audio for acceptance).
**Exit:** tag `phase-10`.

---

## Phase 11 — LLM adapter and agent infrastructure

**Goal:** the shared, auditable model-calling layer used by the factory (and later Raqeeb).
**Refs:** AGENT_AND_PROVIDER_CATALOG §17; AD-27.

- [ ] Adapter on the official Anthropic SDK: structured outputs/strict tools, effort setting, records model ID, prompt version and token usage per call; `LLM_MODEL_STRONG`/`LLM_MODEL_FAST`.
- [ ] Prompt registry (`llm/prompts/*.md`, versioned) and JSON schemas (`llm/json_schemas/`).
- [ ] Untrusted-data framing helper (delimited data fields, ignore-embedded-directives instruction), reused by every agent.
- [ ] Spend/budget accounting primitives; a deterministic fake client for tests.
- [ ] Bilingual evaluation harness skeleton for O-03 model validation.

**Exit:** tag `phase-11`.

---

## Phase 12 — Lesson Factory pipeline: plan → QA

**Refs:** FACTORY §13–13.5; CURRICULUM (lesson types, completeness and depth); AD-30–AD-36.

- [ ] Additive migration: `factory_runs` (+ `review_digest`, `cost`).
- [ ] Orchestrator: idempotent Celery stages keyed by (`run_id`, `stage`, `attempt`), transactional stage writes, 2 retries, budgets (`budget_exceeded`), cost recording.
- [ ] Agents: Curriculum Architect (with unit context), Objective Decomposer/Event Extractor, Evidence Retriever, Evidence Verifier (code checks + semantic scholarly review), Lesson Writer/Story Narrator, Exercise Designer + selection, Glossary Editor, Localizer + code parity check, QA Reviewer + Pedagogy Reviewer.
- [ ] Code validators: writing rules, sentence roles/claim basis, evidence budget, arc coverage, exercise rules (2–6 graded), duplication/composition checks, localization parity, pool minimums.

**Tests:** `test_factory_pedagogy` (fake LLM), stage crash/resume.
**Gates:** O-03 (model validation on bilingual tasks), O-12 (curriculum review before production seeding).
**Exit:** sub-tag `phase-12.1` after the orchestrator and plan stage; tag `phase-12`.

---

## Phase 13 — Reviewer gates, publication, reviewer console API

**Refs:** API §6.11; FACTORY §13.6, §14.

- [ ] `POST/GET /admin/factory/runs`, `GET /admin/factory/runs/{id}` (typed `FactoryRun`, `Draft`, `QAReport`, `DraftVisual`).
- [ ] Gate 1 / Gate 2 with `review_digest` (`409 review_stale`), `review_decisions` audit, edits (paired Arabic/English), exercise removals, re-validation, `request_changes` re-run from `write`.
- [ ] Publication transaction: single lesson per slot, versions, concepts introduced once, claims/sentences/exercises/terms/misconceptions/sources upserts, immutable object writes before commit, `published_digest`.
- [ ] Gold and Unit 0 imports now publish only through this same approval path.

**Tests:** `test_review_digest`, publication immutability, a rejected/regenerated version.
**Exit:** tag `phase-13`.

---

## Phase 14 — Visual and media pipeline (images, audio, production scenes)

**Goal:** the complete visual pipeline at **final production quality** (D-06). Scenes, assets, states and transitions are authored against the full architecture. Nothing is downgraded to builtins or static images because the Flutter preview tool is missing.
**Refs:** ANIMATION_AND_MEDIA_HANDOFF; SCENE_RENDERER_SEMANTICS; FACTORY §13.4, §13.8; O-13.

- [ ] Visual Selector stage. It chooses by pedagogy (builtin, image or scene per the brief), never by preview availability.
- [ ] Image provider adapter (`IMAGE_PROVIDER`), Image Prompt Writer, Visual Auditor (vision), max 3 attempts, WebP storage, `content/style_guide.md` + character reference sheet inputs.
- [ ] TTS narration (`TTS_PROVIDER`, never Quran), Quran audio + word timings, segment cutting.
- [ ] Animated Scene Author stage targeting the full `qabas.scene/1` grammar (states, beats, focus, tracks, transitions, reduced motion, anchors, asset-bearing layers), with a validator retry loop (`scene.schema.json` + `scene_check.py`).
- [ ] Scene asset generation (artwork briefs → image provider → audit), checksums, sizes, content-addressed storage.
- [ ] Preview/inspection: a pluggable `ScenePreviewer` interface. Interim: the existing non-normative preview/review renderer (handoff SVG preview, Unit 0 review canvas) renders frames, the animation preview, the reduced-motion still and fallbacks **for inspection**. When `tools/scene_preview` arrives, it plugs into the same interface. Scene definitions do not change.
- [ ] `content/medallions/registry.yaml` with real medallion art (D-37).
- [ ] Scene publishing (`scenes/<id>/v<n>/`, `scene_versions`), capability negotiation, state-aligned fallbacks, `POST …/images/{scene_id}/regenerate`.

**Release gate, not a quality limit:** the handoff requires that a learner-facing scene only uses capabilities a real app build supports (`released` in the production registry, O-02). That gate protects learners on older apps from scenes they can't render. It does not lower authoring quality. Scenes are fully authored, audited and staged now, and they go live as soon as the renderer releases the capabilities.
**Tests:** `test_scenes`, `test_scene_hotspots`; joint acceptance of a non-Salah asset-bearing scene (Integration gate 4).
**External dependency:** `packages/qabas_scene` + `tools/scene_preview` + capability release (renderer owner). It affects normative preview equality and go-live, not generation.
**Exit:** tag `phase-14`.

---

## Phase 15 — Metrics, blind tests, factory acceptance

**Goal:** prove the generation and publishing pipeline end to end (**Milestone C**).

- [ ] Additive migration: `blind_pairs`, `blind_responses`.
- [ ] `GET /admin/blind-test/next`, `POST /admin/blind-test/{pair_id}`, `scripts/create_blind_pair.py`.
- [ ] `GET /admin/metrics` with real computed values (outbox-fed aggregates; synthetic users excluded).
- [ ] Factory definition of done: three lessons in three slots (concept/story/practice, one composing a scenario or practice step inside another type) through both gates, localized, published (staging), playable in sessions, with at least one Visual Selector builtin and one generated scene.

**Exit:** tag `phase-15`.

---

## Phase 16 — Raqeeb text pipeline

**Precondition:** Milestone C complete.
**Refs:** BACKEND_HANDOFF §7.7, §9.1–9.5.

- [ ] Additive migration: `raqeeb_conversations`, `raqeeb_messages`.
- [ ] Endpoints: conversations create/list/get, messages (202 + polling), feedback; one `processing` answer per conversation; 75 s timeout; 90 s stalled-message sweeper.
- [ ] `content/referrals.yaml` and `content/safety_rules.yaml`, authored and reviewed with this phase (D-37).
- [ ] Pipeline: safety rules → classifier → 8 class strategies → verifier → writer → level service (rewrite / term linking / check) → guard (regenerate once, then abstain) → output mapping; referrals; titles; history window; `suggested_lessons`.

**Tests:** contract-valid messages for all 8 classes (fake LLM), guard rules, `test_untrusted_input`.
**Exit:** tag `phase-16`.

---

## Phase 17 — Raqeeb inputs, guarded memory and benchmark

- [ ] Inputs: voice (ffmpeg → STT provider), images (vision extraction), DOCX, PDF (text and scanned via pypdfium2), limits, `input_unreadable`; private attachment storage + retention.
- [ ] pgvector installed and the extension enabled (D-05); embeddings worker (bge-m3, CPU); `raqeeb_memory` with guarded reuse (standalone, no attachments, source digests, equivalence check, version keys, expiry, purge by `origin_user_id`).
- [ ] `bench/run.py` (committed) with the judge and P-05 thresholds, reading the benchmark/adversarial question sets from git-ignored `backend/.private/eval/` (D-19); public harness tests use their own small synthetic cases; `benchmark_runs` table.

**Tests:** `test_raqeeb_memory_guard`, input-type tests.
**Gates:** O-03 (models/STT), P-05 (release thresholds), P-04 (provider disclosure).
**Exit:** tag `phase-17`.

---

## Phase 18 — Community: leagues, friends, achievements

**Refs:** BACKEND_HANDOFF §10.3–10.7; API §6.9.

- [ ] Additive migration: `leagues`, `league_tiers`, `learner_tiers`, `league_members`, `achievements`, `learner_achievements`, `friendships`, `friend_invites`.
- [ ] Leagues: Riyadh-week `week_key`, assignment under an advisory lock, ranking, idempotent week-end promotion beat job, privacy masking, synthetic members behind `SYNTHETIC_LEAGUE_MEMBERS` (P-01), seeded by `scripts/seed.py` (D-37).
- [ ] Friends: invite codes, accept with brute-force limits, online status, privacy.
- [ ] Achievements as outbox consumers from authoritative tables (definitions already in `registries.json`, Phase 4); `GET /me/achievements`.

**Exit:** tag `phase-18`.

---

## Phase 19 — Challenges: REST, selection, bot, async

**Refs:** BACKEND_HANDOFF §11, §11.1, §11.3, §11.4; API §6.10.

- [ ] Additive migration: `duels`, `duel_players`, `duel_questions`, `duel_answers`.
- [ ] `POST /duels`, invitations, accept/decline, get, history; presets `duel`/`group` with `config`; question selection (7/3, no repeats); shared `challenge_points()`.
- [ ] Bot user seeded by `scripts/seed.py` (D-37). Deterministic seeded bot; async flow (`async`, `async/next`, `async/answer`), idempotency, 24 h forfeit beat job, expiry jobs.
- [ ] Results transaction: ranking, ties, XP/quests; achievements/leagues through the outbox.

**Tests:** `test_challenge_scoring`, `test_async_duel_idempotency`.
**Exit:** tag `phase-19`.

---

## Phase 20 — Challenges: live WebSocket and durable coordinator

**Refs:** BACKEND_HANDOFF §11.2; API §8; AD-23.

- [ ] Single-use 60 s WebSocket tickets in `Duel.ws_url`; validation at upgrade.
- [ ] Coordinator: fenced Redis lease + epoch, persisted deadlines, takeover/reload, beat scan for unowned duels, Redis snapshot + pub/sub, sockets on any instance.
- [ ] Protocol: lobby, ready/countdown, question/answer/close/reveal, disconnect grace, reconnect `state` with `live`, `player_left`, finish; 5 messages/s per socket.

**Tests:** full bot duel event order (§8.4), four-player group script (`fixtures/challenges/group_ws_script.json`), `test_ws_tickets`, `test_coordinator_takeover`.
**Gates:** O-04 (durable coordinator vs approved single-process pilot).
**Exit:** tag `phase-20`.

---

## Phase 21 — Production hardening and deployment

**Refs:** OPERATIONS_AND_ENVIRONMENT; QUALITY integration gates 7–8; O-04, O-09, O-10, O-11.

- [ ] Deployment packaging for `api`, `worker`, `asr`, `beat`, `scene-preview`, `dorar`, `tafsir-mcp` (form decided with hosting under O-04; Docker stays out of the dev environment per D-03).
- [ ] Hosting/region, secret manager, encrypted DB/object store, least-privilege roles.
- [ ] Metrics/alerts and tracing per OPERATIONS; log retention.
- [ ] Load tests (API p95, queues, ASR, realtime); provider outage drills.
- [ ] Backup/PITR, restore rehearsal with re-purge from `deletion_jobs`; retention jobs.
- [ ] Security review (tokens absent from URLs/logs, private objects unreachable without a signed URL, rate limits); release bundle contains no private/mock data.

**Exit:** deployment runbook; tag `phase-21`.

---

## External dependencies (not backend work)

| Dependency | Owner | Needed by phase |
|---|---|---|
| Dart DTOs generated from our `docs/openapi.json` + round trips (O-01) | Frontend | Integration after 1 |
| `tools/export_reference_lesson` gold output | Frontend | 8 |
| `packages/qabas_scene`, `tools/scene_preview`, capability release (O-02) | Flutter renderer owner | 14 (normative preview and go-live only; generation proceeds) |
| Reviewed curriculum titles, guides, bridges (O-12); unit art for units 4 and 10 (D-32); confirmation of the corrected achievement copy (D-39) | Content specialist / design | 4 (production seed), 12 |
| Unit 0: approved reasoning-tool mapping (D-40), Arabic plan text, concept registration (O-12), restructured span-field claims; Salah completion record and slot decision (D-83, P-07) | Content team + specialist + product | 8 (import), 13 |
| Staging host provisioning (D-86) | Operations | 8 onward (frontend integration) |
| Source re-verification, registries, reciter licensing (O-05, O-06) | Content/media | 8, 9, 10 |
| Product decisions P-01–P-08 | Product owner | Defaults are used until decided |

## Decision log

| Date | ID | Decision / deviation | Effect |
|---|---|---|---|
| 2026-10-04 | D-01 | O-01 working assumption: adopt the rev 10 candidate as the single contract. Schema SHA-256 `9d67bda00d2edd04d47645b6b93a7747ab9d5646cddeb12a7b34a6910c97481c`, 99 roots. The formal approval record (`00_REVIEW/APPROVAL_RECORD.md`) is still unfilled. | Phase 1 vendors rev 10. An amendment means re-vendoring and rerunning the suites. |
| 2026-10-04 | D-02 | Phase order: core learning experience, then Lesson Factory/reviewer gates/publishing/visual pipeline, then Raqeeb (owner request). The LLM adapter moved into its own phase (11) before the factory. | Raqeeb moved from 11–12 to 16–17. |
| 2026-10-04 | D-03 | Native development environment, no Docker (owner request). CI uses runner-native services. | Removed Docker Compose and MinIO; filesystem storage backend for dev. |
| 2026-10-04 | D-04 | Redis: native Windows build of Redis 7.4.11 (`redis-windows/redis-windows`, msys2 build, zip SHA-256 `ec629971…a2a9` verified against the GitHub release digest) at `%LOCALAPPDATA%\Programs\Redis`, bound to localhost. Started per session with `backend/scripts/dev/start-redis.ps1`. Start-at-logon was **not** configured (it needs your approval); there's no admin rights for a Windows service. | Run the start script after a reboot. |
| 2026-10-04 | D-05 | pgvector is not installed. A native build needs MSVC + the Windows SDK, but the existing VS 2019 Build Tools install is partial (no `cl.exe`, no SDK) and installing them needs admin/UAC. Deferred to Phase 17 (first use: Raqeeb memory). | No effect before Phase 17. |
| 2026-10-04 | D-06 | Scene quality is never reduced because the Flutter preview tool is missing (owner request). The missing tool limits inspection only. Phase 14 builds the full scene pipeline; the capability-release gate stays as a go-live safety rule. | Phase 14 rewritten. |
| 2026-10-04 | D-07 | `tools/verify_package.py` misreports on Windows: it compares `\` disk paths against `/` manifest paths. Independent check: all 2,010 manifest entries match. Unmanifested files are the later `FRONTEND_DEMO_HANDOFF/` and `UNIT_0_CONTENT/` deliveries, `.vscode/`, plus harmless caches (3 `__pycache__` cpython-313 files, `.gradle` caches). | Handoff accepted as intact; frozen tool not modified. |
| 2026-10-04 | D-08 | Test-count discrepancy resolved: rev 10 = 595 regressions / 279 focused / 105 examples / 382 fixtures (rerun on Python 3.12.10, PASS, outputs identical after LF normalization). The `SETUP_AND_REPRODUCTION.md` figures 615/170/392 are stale (615/392 are revision 9). | CI targets 595/279/105/382. |
| 2026-10-04 | D-09 | Git: local `Qabas/` connected to `github.com/Abdulrahman-me/Qabas`. `FINAL_ENGINEERING_HANDOFF/` is git-ignored and its files are read-only (undo: `attrib -R /S /D`). `.gitattributes` forces LF. No AI co-author or attribution metadata in commits (owner request). | — |
| 2026-10-04 | D-10 | The GitHub repo stays **public** (hackathon requirement; owner decision). | Resolved by D-14. |
| 2026-10-04 | D-11 | `UNIT_0_CONTENT/` (12 authored Unit 0 lessons, 20 scene manifests) and `FRONTEND_DEMO_HANDOFF/` are unapproved review drafts outside the frozen manifest. Treated as read-only import inputs. | Unit 0 import added to Phase 8. |
| 2026-10-04 | D-12 | Python: 3.12.10 installed per-user (`py -3.12`). The chocolatey `python312` 3.12.4 record points at a missing `C:\python312` and was left untouched. uv 0.12.23 installed for locking. | — |
| 2026-10-04 | D-14 | **Superseded by D-19.** **Public-repo data policy.** Committed: application code, migrations, the rev 10 `contract/` directory (verified to contain no Arabic text, scripture or answer keys), docs, and synthetic neutral test data. Never committed: `FINAL_ENGINEERING_HANDOFF/`, contract fixtures and tools, `API_REQUIREMENTS.md`, private grading keys and evaluation context, gold/reference lessons, Unit 0 drafts, and any unapproved religious content. Those live in git-ignored `backend/.private/`. A safety guard enforces this in CI and pre-commit. | Full contract suites run locally only. Content imports (Phase 8) read from local private paths; staging data never enters git. |
| 2026-10-04 | D-19 | **Repository boundary corrected (owner clarification; supersedes D-14).** The public repository is the complete production product, not a demo or reduced version, and must be cloneable, installable, testable and runnable as the real system. Rule: *production/runtime data and tests may be public; internal evaluation material stays private.* Public: code, migrations, the full vendored contract with fixtures and server-side grading context, approved production content and its answer keys, Arabic text, and tests that verify real behavior. Private (git-ignored `backend/.private/`): hidden/golden evaluation datasets, reviewer reference answers, adversarial cases, unpublished handoff material, content pending approval, secrets and credentials. Correct answers are protected at runtime (server-side grading, redaction before submission), not by hiding files. The handoff itself requires the contract suites in CI in both repositories (QUALITY §18.1), so they now run in CI. Earlier commits and the `phase-1` tag are kept unchanged; this correction is `phase-1.1`. | Phase 1 corrected; Phases 8 and 17 content/eval locations updated; A-3 revised, A-7 added. |
| 2026-10-04 | D-15 | Contract-header cases the spec leaves open: a missing or non-integer `Qabas-Contract`, or a missing `Qabas-Client`, is treated as a pre-revision-10 client (`426 client_outdated`). A malformed `Qabas-Client` (not `android`, `ios` or `web` followed by `/` and a semantic version) is `400 validation_error` with `details.field`. Health and OpenAPI paths are exempt. | `app/middleware.py`; tests in `test_contract_headers.py`. |
| 2026-10-04 | D-16 | A request to a known path with an unsupported method returns `404 not_found`, like an unknown path, because §3.4 has no 405 row (adding a code is a contract change). | `app/errors.py`. |
| 2026-10-04 | D-17 | uv also needs the Windows certificate store: user-level `%APPDATA%\uv\uv.toml` sets `system-certs = true`. | Documented in `backend/README.md`. |
| 2026-10-04 | D-18 | Vendored layout keeps the handoff structure (`backend/contract/contract/*`, `backend/contract/tools/*`) because the tools locate the schema relative to themselves; `app/contract.py` puts the directory on `sys.path` so the modules stay byte-identical. OpenAPI components are the export's `$defs` and roots flattened with refs rewritten. Same-named definitions must be identical, except the four tagged-union roots, which differ only by `title`. | `app/contract.py`, `app/openapi.py`. |
| 2026-10-04 | D-20 | Keys: public resources use contract-prefixed opaque IDs (`<prefix>_` + 26-char ULID-style suffix, time-ordered and unguessable, `app/db/ids.py`). Internal rows (auth sessions, lesson versions, review decisions, deletion jobs) use UUIDs, and high-volume logs (answers, XP, outbox, quests) use identity integers. Claims and sentences are keyed per lesson version (`(lesson_version_id, id)`; sentences add `lang`, `variant`) because localization keeps IDs identical across variants and versions reuse them. | `app/db`, migration 0001. |
| 2026-10-04 | D-21 | Stored facts, derived states: lesson/unit *states* (locked/available/in_progress/completed/skipped) are computed at read time from prerequisites, active sessions and stored facts. `learner_units` stores `started_at`, pretest/unit-test results, `unit_test_passed_at`, `completed_at` and `skipped_at`; `learner_lessons` stores `completed_at`. `learner_misconceptions.status` adds `inactive` for evidence below the activation threshold (backend §7.2 accumulates evidence before activation). `review_decisions` can bind to a lesson version (gold/approved-content import approvals) as well as a factory run. | Data-model sketch refined; no contract change. |
| 2026-10-04 | D-22 | Database integrity that a CHECK can't express is enforced by triggers for every role, with custom SQLSTATEs (QB001 immutable published content, QB002 set-once, QB003 session snapshot/terminal, QB004 insert-only, QB005 unpublished current version). Publication must write `published_at` last (children first). Runtime roles are `NOLOGIN` locally and receive grants from the migration's `qabas_apply_grants()`. | Phases 8 and 13 publish in that order; later migrations call `qabas_apply_grants()`. |
| 2026-10-04 | D-23 | Shared registry `backend/content/registries.json`. Avatar keys `traveler_01`…`traveler_12` map to the prototype's traveller hues (the 11 sample travellers plus the learner's own hue); `traveler_bot` is reserved for the coach and isn't selectable; default `traveler_01`. It also holds guest-name words (ar/en), the goal anchors from the contract template, and the "Deleted learner"/private-member placeholders. The handoff left `avatars.keys` empty; the Flutter app must map the same keys to hues. | Frontend alignment needed on the avatar keys (external dependency). Phase 4 extends the file (tiers, achievements, unit art). |
| 2026-10-04 | D-24 | Token lookups are not cached: each authenticated request does one indexed `auth_sessions` + `users` lookup, so revocation (logout, `DELETE /me`, operator action) is immediate. That is stricter than the spec's "cache ≤ 30 s" and needs no invalidation. | Auth latency is one PK/unique-index query per request. |
| 2026-10-04 | D-25 | Planner rules 3–4 need lesson availability (prerequisites, Soft Lock) and are completed with the journey service (Phases 5/7). Until a lesson can be started, the planner's reachable outputs are rules 1, 2 and 5, which are implemented. | Phase 7 checklist updated. |
| 2026-10-04 | D-26 | Guest display names are generated in the default language (Arabic, e.g. "مسافر ٤٧") since `POST /auth/guest` carries no language; learners can rename themselves (`PATCH /me`, 2–24 printable characters, whitespace collapsed). Unknown time zones, avatars and anchors are `400 validation_error` with `details.field`. | API behavior. |
| 2026-10-04 | D-27 | Account purge is queued immediately through the outbox (well within the 30-day bound). The users row is kept, anonymized, as the placeholder other users' records point to; private objects live under `users/<id>/` so purge can remove them by prefix; `deletion_jobs` keeps the audit trail and drives `repurge_deleted_users.py`. | Later phases add purge steps (Raqeeb rows and memory, friendships, leagues) to the same consumer. |
| 2026-10-04 | D-28 | Time-zone validation uses the IANA list shipped with the pinned `tzdata` package (598 zones, minus the `Factory` placeholder) on every platform. CI found that Linux's OS list also accepts `localtime`, which Windows rejected. | Identical validation everywhere. |
| 2026-10-04 | D-29 | **Content origin and test fixtures** (environment limit superseded by D-84)**.** `lesson_versions.origin` ∈ `factory`, `gold_import`, `test_fixture`. The contract's synthetic test curriculum goes through the real import → validate → publish pipeline, but only with `FixtureApproval`, which is refused unless `ENV` is dev/test. Placeholder media (`mock-asset://`) is accepted only for that content. The fixture's lesson-level prerequisites are expressed as one synthetic concept per lesson (`con_t{u}_{l}`), matching the production concept-level rule. | No demo path: fixtures exercise production code; real content always needs a digest-bound Gate 2 approval. |
| 2026-10-04 | D-30 | **Lesson positions are 0-based** (`JLesson.index`, fixtures) and live in `curriculum_slots`. Lesson ID `les_u{U}_l{n}` with n = index + 1. Lessons reference their slot by a composite FK on `(id, unit_id, index)`, so a lesson can't exist outside the curriculum or drift from its position. Migration 0002 converts any existing 1-based rows deterministically and backfills slots. | Corrects migration 0001's `index >= 1` (F-1). |
| 2026-10-04 | D-31 | **Displayed lesson XP** (`JLesson.xp`, undefined in the spec) = what the fixed XP table lets a learner earn: completion 10, +3 perfect lesson when any exercise counts toward accuracy, +3 per `recite_verse`. Stored on `lessons.xp` at publication. | Phase 7 grants must use the same table (F-2). |
| 2026-10-04 | D-32 | **Unit art keys** must be in the compiled art set (`EXERCISE_ART`, 9 keys). Mapping: unit_0 questions, 1 footprints, 2 starry_sky, 3 prayer_rug, 5 heart, 6 book, 7 compass, 8 lantern, 9 water_drop; units 4 and 10 have none (null) until art is designed. | API example keys are rejected (F-3); frontend/content to confirm. |
| 2026-10-04 | D-33 | **Claim and sentence IDs** are authored per lesson version with no required prefix (fixtures use `s1`, `c1`); they are scoped by `(lesson_version_id, …)` keys. Migration 0002 drops the 0001 prefix checks. | F-4. |
| 2026-10-04 | D-34 | **Content storage shape.** `lesson_versions.content` holds the variants, glossary, misconception cards, sources and the ordered exercise version pins (a list, since JSONB loses key order); `plan` and `arc_map` have their own columns; claims and sentence roles are rows. Each exercise version stores the learner fields and feedback per language, and the key only in `answer_key`. Content identity is the SHA-256 of the canonical JSON of the whole package; `load_package` must reproduce it exactly. | Identical re-import is a no-op; any change is a new version. |
| 2026-10-04 | D-35 | **Session sources** list sources referenced by blocks (evidence, teach evidence, story quotes = `content`) and by `recite_verse` (`activity`). Evidence embedded inside an exercise payload is shown by that exercise and isn't listed, matching every contract session fixture. Validation still requires every referenced source, embedded ones included, to exist, and at most 3 displayed content sources. | F-5. |
| 2026-10-04 | D-36 | **Invalid content is rejected, never repaired.** Validation reports every issue at once; nothing is synthesized or backfilled (`display_fields.backfill_legacy` is never applied, keys are never derived). | Factory retries and reviewers see complete issue lists. |
| 2026-10-04 | D-37 | **No empty production data files.** `referrals.yaml`/`safety_rules.yaml` move to Phase 16, `medallions/registry.yaml` to Phase 14, the bot user to Phase 19 and synthetic league members to Phase 18, each created with real content alongside its consumer. | Phase 4 checklist adjusted; later phases updated. |
| 2026-10-04 | D-38 | **Unit availability (conflict resolved).** SEED_AND_IMPORT §15 opens a unit at its first published lesson; BACKEND §6.2 and FACTORY §13.3 make a unit publishable only when its pools reach ≥ 6 pretest and ≥ 9 unit-test items. Safest interpretation, satisfying both: lessons publish individually, but a unit stays `coming_soon` until it has a published lesson **and** its published pools meet both minimums. Otherwise a learner could enter a unit whose pretest and unit test can't be served and could never complete it. | Recomputed at every publish and seed (`refresh_unit_availability`); the planner never meets an unservable pretest (F-6). |
| 2026-10-04 | D-39 | **Curriculum file status.** `curriculum.yaml` is `review_status: working` pending O-12: English titles from the curriculum; Arabic titles from the handoff where given, otherwise working translations to be reviewed; no unit guides yet. `concepts` is empty: concepts are registered when an approved plan or a gold import introduces them, and imports refuse unregistered concepts. Registry UI copy typo «افز» corrected to «فُز». | Content specialist to review titles, guides and the corrected copy (F-10, F-11). |
| 2026-10-04 | D-40 | **Unit 0 draft conflicts** (`learner_acts` clause superseded by D-82) (two-digit IDs, 1-based positions, non-contract `learner_acts`, 9 reasoning tools outside the contract enum) are resolved in the Phase 8 importer. The reasoning tools need a human-approved mapping; the importer will not guess. | Phase 8 checklist updated (F-12). |
| 2026-10-04 | D-41 | **Units open only when their prerequisites are reachable** (extends D-38). A unit also stays `coming_soon` while a prerequisite of one of its published lessons is introduced in a closed unit, so a Soft Lock never names a lesson the learner cannot see. Availability is decided in curriculum order (`decide_open_units`). Assessment pools are the exercises pinned by the *current* published lesson versions, the same definition for availability and for serving. | F-18. |
| 2026-10-04 | D-42 | **A served bank must not reveal its answer.** Validation rejects an `order_steps`/`timeline_order` bank in key order, a `match_pairs` right column aligned with its key, and a `fill_blank` word bank starting with the answers in blank order (2+ items). | Protects answers under authored/captured banks (F-19). |
| 2026-10-04 | D-43 | **Request language:** `Accept-Language` is negotiated (q-weights, region subtags); a header naming no supported language falls back to the profile language rather than failing. A session keeps the language it was created in. | API §3.2. |
| 2026-10-04 | D-44 | **Planner current unit** = the first unit of the track path that is neither completed/skipped nor `coming_soon` (rule 1 as written); coming-soon units are passed over and the journey is complete only when no unit remains. Corrects the Phase 3 planner, which stopped at the first coming-soon unit. | F-16; units never wait for the previous unit. |
| 2026-10-04 | D-45 | **`Journey.current`** = the planner's rule-3 lesson of the current unit (first available/in-progress lesson, else the Soft Lock `start_with` of the first locked one, possibly in another unit), whatever the next step is; the unit alone when all its lessons are done; both null when the journey is complete. Matches the contract fixtures. | F-17. |
| 2026-10-04 | D-46 | **Review scope:** reviews draw only on lessons in the learner's journey (open units of the current track) with purpose `lesson`. Practiced concepts outside it are not reviewed (records are kept). An empty quick review is also `409 nothing_to_review`. Cards: one flashcard per concept. Quick: candidates sorted by active-misconception target, then not answered in 24 h, then concept priority. | F-21. |
| 2026-10-04 | D-47 | **Lesson reader:** `GET /lessons/{id}` serves the current published version for lessons in the learner's journey (`404` otherwise) and refuses a locked lesson with the same `409 prerequisite_unmet` as a session, so the Soft Lock can't be bypassed by reading. Its `sources`/`source_count`/`terms` are those of the reader blocks (no exercises, so no recitation activity source). | F-20. |
| 2026-10-04 | D-48 | **Guide sources** are sentence citations: listed with `displayed: false`, `display_role: null`; the evidence budget applies to lessons, not guides. A guide citing an unregistered source is a data error. | API §6.3 guide. |
| 2026-10-04 | D-49 | **Journey fixtures** are compared structurally after the learner has started the start unit's pretest. Lesson titles come from the published variant (they differ in the generated fixtures) and `xp` follows D-31. | F-14, F-15. |
| 2026-10-04 | D-50 | **Shuffling:** pretest/unit-test items are drawn and ordered with a CSPRNG at serve time and frozen in the snapshot. Lesson items keep authored order; exercise banks are served exactly as authored or captured (factory §13.3, the Salah reference's captured order), protected by D-42. | F-19. |
| 2026-10-04 | D-51 | **Exercise-only sessions:** title = localized label (pretest "A quick check before you start", unit test "Unit test", "Card review", "Quick review"; UI copy pending product review), `subtitle` null, block ids `blk_q{n}`. Planner rule 2 counts due concepts with mastery > 0 and recommends a review only when a card deck can be served. | F-23, F-24. |
| 2026-10-04 | D-52 | **Repeated pretests** are allowed by `POST /sessions` (no rule forbids them), but Phase 7 records only the first pretest result and grants `pretest_complete` XP once per unit, so repetition can't skew metrics or farm XP. | F-22; Phase 7 checklist updated. |
| 2026-10-04 | D-53 | **No per-answer term changes.** `term_changes` is always `[]`; term exposure (finished sessions containing the term) and promotions happen at finish (backend §7.6), as every contract evaluation shows. | F-26; Phase 7. |
| 2026-10-04 | D-54 | **"Practiced" starts at finish.** Answers update mastery only; the FSRS card and `first_practiced_at` (which make a concept reviewable, Phase 5) are created at finish for non-retry, non-pretest answers (§7.4). An abandoned session's answers keep their mastery effect but don't schedule reviews. | Phase 7 checklist. |
| 2026-10-04 | D-55 | **Pinned misconception cards.** The card returned in an evaluation comes from the lesson version that published the served exercise version; the registry row is used only when that version doesn't define it. | F-33. |
| 2026-10-04 | D-56 | **Lock order and duplicate handling.** An answer locks the session row (serializing a session's answers), then learner concept rows ascending, then misconception rows ascending; missing rows are inserted with `ON CONFLICT DO NOTHING` before locking. A duplicate that waited on the lock finds the recorded identity and replays it. Finish must take the same order. | Backend lock order; verified with concurrent tests. |
| 2026-10-04 | D-57 | **Misconception arithmetic.** Per answer and misconception, evidence adds the larger of +1.0 (mapped option chosen) and +0.5 (targeting exercise answered incorrectly), not both. A resolved misconception that gathers new evidence becomes active again (card shown, streak 0). Streaks count only active misconceptions; retries and neutral outcomes never touch them. When several cards qualify, the chosen option's misconception is shown. | F-32. |
| 2026-10-04 | D-58 | **Answer validation errors:** `400 validation_error` with `details.field` (`exercise_id`, `answer`, `elapsed_ms`, `is_retry`, `body`); `categorize` adds `details.reason`: `duplicate_or_missing_item` (items not each assigned once, or an over-full `day_arc` slot, as in the fixtures), `unknown_category`, `over_capacity` (buckets). Submitted content is never echoed. | F-29. |
| 2026-10-04 | D-59 | **Scenario timeout:** no option was chosen, so `details.option_feedback` is empty. | F-28. |
| 2026-10-04 | D-60 | **`week_key`** = ISO year-week (`YYYY-Www`) of the Asia/Riyadh date shifted by one day, so Sunday–Saturday share a key; `local_date` = the learner's date in their time zone at the grant. XP grants are unique per (user, reason, ref); recitation uses ref `session_exercise` / `{session_id}:{exercise_id}`. | F-34; leagues (Phase 18) reuse it. |
| 2026-10-04 | D-61 | **Untimed lesson and assessment items.** Real lesson, pretest and unit-test items must have `time_limit_ms: null` (API §5.7); timers belong to the serving mode (quick review 20 s, challenges). Only `test_fixture` content (the contract specimens carry 20 s) is exempt, through the same fixture-only allowance as placeholder media (D-29), which `import_package` now refuses for any other origin. | F-27. |
| 2026-10-04 | D-62 | **Recitation binding** follows the data model and API §6.6: the check must belong to the caller and match the served surah, ayah, word range and `sha256(text_uthmani)`. An unknown, foreign or mismatched check is the same `409 recitation_check_mismatch` (no existence leak). A check may answer any number of exercises with the same text. | F-30; Phase 10 produces checks. |
| 2026-10-04 | D-63 | **Timing:** per-exercise time in lessons and reviews is client-measured; the server rejects a timeout reported before the served limit and a negative `elapsed_ms`, and grades a submitted answer as given. Server-authoritative deadlines apply to challenges (persisted, Phase 19). | F-31. |
| 2026-10-04 | D-64 | **Replays and rewards.** A replay returns the response shape of the session's feedback mode, applies nothing, works after finish/abandon, and a changed body is logged with ids only. Recitation XP is granted once per exercise per session (spec); repeat-session reward policy is decided in Phase 7. | F-36. |
| 2026-10-04 | D-65 | **Result ordering:** per-item results follow the answer key's order (slot order for `day_arc`, as the fixtures), `event_dates` the key's chronological order, `pin_labels` the authored order. | F-37. |
| 2026-10-04 | D-66 | **Unserved exercise** in an answer is `400 validation_error` (`field: exercise_id`): the session exists, the request names something it never served. | API §6.5 step 5 gives no code. |
| 2026-10-04 | D-67 | **Repeated rewards (conservative default; closes F-36/F-38).** `lesson_complete` once per canonical lesson; `lesson_perfect` once on its first perfect finish (may be a later attempt); `pretest_complete` once per unit (D-52); `unit_test_passed` once per unit on first pass. `recitation_passed` remains an immediate 3-XP grant, but once per canonical exercise across sessions, including abandon/restart. `review_complete` requires actually graded work on a concept due at serve time whose opportunity has not since been consumed, and is capped once per learner local day across cards/quick. Database `UNIQUE(user, reason, reward_key)` supplements existing reference/daily-goal constraints. Language, track and publication changes never reset claims. | Repeats retain feedback, mastery, FSRS, term exposure, time/streak and best results. Completion/perfect/review/recitation counters cannot farm quest rewards. D-64 replay and D-60 XP references/week keys stay intact; only the provisional repeated-recitation allowance is superseded. |
| 2026-10-04 | D-68 | **Private learning audit** (legacy clause superseded by D-76)**:** immutable six-decimal start mastery snapshot; private per-answer misconception activation/resolution transitions and pinned titles. Finish reports captured start and locked end, without repeating mastery. Legacy active records lacking reliable start data reject finish until an explicitly audited snapshot migration; finished legacy results still replay and served public content stays intact. | F-39. Earlier checkpoints had no production deployment/data. No silent reconstruction, reset or abandonment. |
| 2026-10-04 | D-69 | **Local-day duration/facts:** accumulate exact milliseconds after each finish's 20-minute qualifying-time cap; floor only cumulative display minutes. Result duration is independently clamped to nonnegative elapsed wall time and stored as bigint. Any finish (including repeats) qualifies a day; `extended_today` means its first qualifying finish. Current streak has today/yesterday grace; longest uses historical dates. Timezone changes never rewrite stored dates. | F-40/F-45; daily-goal reward still once per stored date. |
| 2026-10-04 | D-70 | **Percentages:** half-up `correct/graded-total × 100`; empty denominator = 0/0/0. Only accuracy-eligible graded original attempts count. Retries/neutral outcomes cannot make a lesson perfect; remembering stays null. | F-41; no contract/schema amendment. |
| 2026-10-04 | D-71 | **Glossary:** personal lists exclude new, so `state=new` is empty; detail/open accepts known published terms and unknown IDs are 404. Opening increments opened_count and promotes new→learning, without exposure/mastered promotion. Finish increments exposure once per contained term and promotes at exposures≥2 plus linked mastery≥0.8. Mastered terms are not downgraded. | F-42; canonical project_term and learner-level rules are preserved. |
| 2026-10-04 | D-72 | **Quests:** three deterministic unique kinds/slots per stored local day; goals freeze at materialization. Newly eligible lesson/perfect/review work advances activity quests; newly rewarded recitation records progress at answer. All non-recitation reward XP settles at finish, including pending quests. Quest reward XP counts for earn_xp through a bounded cascade, with unique grants. | F-43. Abandoned answer XP remains, but abandoned sessions never qualify days/apply finish effects. Normative win_challenge pool entries remain for Phases 19–20. |
| 2026-10-04 | D-73 | **Finish pins:** capture unit-test pass_percent and contained term→concept bindings privately at start. Contained term references use pinned language/text; current profile track governs the next journey step. Missing canonical state is rejected, never repaired. | F-44; no public fields added. |
| 2026-10-04 | D-74 | **History/concurrency:** end history reveals original evaluations only after finish; none stays hidden. Answer replays retain their mode-permitted shape after finish. Finish replays the full result before validating changed/malformed retry bodies. A transaction advisory lock after the session row serializes each learner's cross-session reward/activity writes; row order stays session→concepts ascending→misconceptions ascending→terms ascending. Term-open takes term locks only. | F-46; real Postgres races, rollback and redelivery tests. |
| 2026-10-04 | D-75 | **FSRS:** fsrs 6.3.1 locked, default weights/0.9 retention, UTC Card JSON, fuzzing disabled. One update per concept at finish, excluding neutral/retry/pretest. Explicit flashcard rating overrides (worst if multiple); otherwise any wrong→Again, all correct with known average elapsed<6000→Easy, otherwise Good. Missing elapsed uses Good. | F-41/F-47. Repeated learning updates schedules even without rewards. |
| 2026-10-05 | D-76 | **Legacy active sessions (supersedes D-68's legacy clause).** An active session must carry its private learning snapshot, enforced by a CHECK (migration 0004). The upgrade refuses to run while snapshot-less active sessions exist; an operator abandons them explicitly with `scripts/abandon_legacy_sessions.py --confirm` (listing is the default). Abandoning is the defined outcome of API §6.5: answer effects stay, finish effects never happen, the learner restarts. Nothing is reconstructed. Finished/abandoned history without a snapshot remains valid and replays. | F-51; no such session exists in any environment today. |
| 2026-10-05 | D-77 | **`session.finished` consumer.** A dispatcher fans the event out to named subscribers (achievements, leagues, metrics in Phases 15/18), each claiming its own effect key. With no subscriber the event completes; later subscribers backfill from authoritative tables (backend §10.3, §10.7), never from old events. | F-50. |
| 2026-10-05 | D-78 | **List and copy conventions.** Lists use API §3.5 (default 20, max 50); a cursor is the last item's id and must belong to that list (`con_` / `term_`). Quest titles agree with their number in both languages («أكمل درساً», «أكمل درسين»; "Complete a lesson"). | F-48, F-52. |
| 2026-10-05 | D-79 | **Gold path.** Gold file `qabas.gold/1` = `LessonPackage` + provenance. Import always creates an unpublished `gold_import` version (Phase 4 validators, placement, concept checks) and marks the lesson `is_gold`. Publication is only `approve_and_publish`: an authenticated, active reviewer (own password) approves the exact stored digest; the `review_decisions` row with `published_digest` and the publication commit in one transaction (§13.6). Rejections are recorded with a reason. | Phase 13 adds the reviewer API on the same service. |
| 2026-10-05 | D-80 | **Unit 0 source of truth:** the authoring records in `UNIT_0_CONTENT/lessons/` (plans, claims, roles, keys, pools). The frontend demo sessions are a mock projection and are not imported. | F-62. |
| 2026-10-05 | D-81 | **Converters never guess.** Each missing input is a typed blocker with its owner (`reasoning_tool_unmapped`, `plan_text_missing`, `concept_unregistered`, `source_pending`, `scene_media_unpublished`, `media_unavailable`, `claim_in_span_field`, `completion_record_missing`, `curriculum_placement`, `reference_acceptance`, `record_invalid`); a lesson with any blocker produces no gold file; the JSON report is for reviewers. | F-53–F-61. |
| 2026-10-05 | D-82 | **Mechanical projections only:** two-digit ids → slot ids, 1-based numbers → 0-based indices, `learner_acts` → `interactive` (same meaning), inline sentence roles → the sentence map, claims keep the Arabic (authored) text, misconception statement/correction → title/card, glossary heading/definition/example → `StoredGlossaryTerm`, review-topic labels → titles with stable ids, and the drafts' alternative key/feedback/explanation forms normalised losslessly. Specialist flags travel in the gold provenance; QA self-checks and visual briefs are authoring material. | F-58; supersedes D-40's "drop `learner_acts`". |
| 2026-10-05 | D-83 | **Salah completion record** (`qabas.salah_completion/1`): target slot + decision owner (P-07), plan, claims, sentence map, arc map, misconception records/mappings/targets, per-exercise feedback extras and sources, flashcards and pretest/unit-test/duel items, re-verified sources, licensed recitation audio. Written and reviewed by the content team; the converter merges it with the lossless 1:1 projection. | F-59–F-61. |
| 2026-10-05 | D-84 | **Fixture content outside production (supersedes D-29's dev/test limit):** the synthetic test curriculum may be loaded and published in dev, test and **staging** (frontend integration), never production; placeholder-media/timer allowances stay fixture-only; `import_package` refuses those allowances for any non-fixture origin. | F-64. |
| 2026-10-05 | D-85 | **Engineering authors no religious or curricular content.** Where the handoff assigns content creation to "the backend" (§13.7.2), engineering supplies the format, validation and merge; the content team writes and the specialist approves. | F-59. |
| 2026-10-05 | D-86 | **Staging** runs the same code, migrations and native services as production with real secrets, the test curriculum and approved content via the gold path. Provisioning its host is an operations dependency outside this repository. | F-64. |
| 2026-10-05 | D-87 | **Concept registration stays with O-12.** Imports refuse unregistered concepts; no draft concept is added to the public `content/curriculum.yaml` before the curriculum review approves it. | F-63. |
| 2026-10-05 | D-88 | **Canonical Quran text is the King Fahd Complex Hafs v3.0 dataset**, pinned by archive/member SHA-256. Do not commit the dataset while redistribution terms are pending; fuzzy matches locate only and never insert. | Organizers pp. 3–4, 14; source handoff; O-03. |
| 2026-10-05 | D-89 | **Keep rev 10's `quran_com` provider value for canonical Quran rows**, because its enum has no King Fahd value. The real publisher, edition/digest and authority role are explicit in title/link and `raw.parts`; capability providers retain separate parts. A provider-enum extension needs a future contract amendment. | Contract `Provider`; authority/capability split. |
| 2026-10-05 | D-90 | **Circuit breakers are per provider and per process**, shared by adapter instances: five failed calls, sixty-second open period, one half-open trial. | Operations; no unapproved distributed-breaker architecture. |
| 2026-10-05 | D-91 | **Cache only after terms are confirmed** and a reviewer is named. Pending terms mean neither reading nor writing provider caches; default seven-day TTL applies only after confirmation. | Source handoff; O-03. |
| 2026-10-05 | D-92 | **Collection-number hadith citations require a content-team binding to a provider record ID.** Engineering does not infer a Dorar record from “Bukhari 4770” or fabricate its grade/narrator. | Unit 0/Salah provenance; O-05. |
| 2026-10-05 | D-93 | **Qabas selects QuranEnc for Quran translations**, with a specialist-approved key and version for each language. Quran Foundation remains a capability provider and supplies no translation fallback. This is a project route; the organizers also permit other approved translations (D-102). | Organizers pp. 3–4, 8–11; `translations.yaml`. |
| 2026-10-05 | D-94 | **Hadith categories use a conservative exact-ruling table.** Unknown/qualified rulings are `other` and require specialist interpretation; the original ruling and grader remain verbatim. Sharh never supplies grades. | Dorar recordings; F-70; no LLM grading. |
| 2026-10-05 | D-95 | **MP3Quran is an optional later audio capability**, with ayah-level timing only. It does not replace the required Quran Foundation word-timing adapter or the canonical text authority. | Organizers p. 12. |
| 2026-10-05 | D-96 | **HadeethEnc and IslamHouse REST text search is explicitly unsupported.** The association MCP is the planned search route after its tool schemas and terms are available; results must be re-fetched from the authority record. | Organizers p. 9; O-03; follow-up, no invented endpoint. |
| 2026-10-05 | D-97 | **Terminology sources are a Localizer follow-up (Phase 11).** Prefer the organizers' Jamhara/Encyclopedia of Islamic Terms to automatic translation; existing authored glossary content is not rewritten by Phase 9. | Organizers pp. 3–4, 10. |
| 2026-10-05 | D-98 | **One bilingual source identity represents the same complete verified translation/audio bundle.** Canonical text authority and every contributing provider retain separate parts. A changed bundle gets a new identity; replay keeps original source snapshots. | F-75; stored exercise localization parity and immutable citations. |
| 2026-10-05 | D-99 | **Quran Foundation uses separate content/search OAuth scopes**, tokens in process memory only. A single 401 can renew a token and repeat the request once; a second 401 or any 403 fails. This bounded provider-specific authorization flow is the sole exception to the general no-4xx-retry rule. | Official OAuth/Search API docs; F-74. |
| 2026-10-05 | D-100 | **Disable the Dorar sidecar's own cache until terms permit it**, using a Qabas preload without modifying the pinned checkout. Do not raise its access-rate limit. Check marker, actual HEAD and tracked files; pass only a minimal native child environment. | D-91; F-73; O-03. |
| 2026-10-05 | D-101 | **Gold import requires canonical scripture checks before writes**, including nested exercise evidence and recitation word ranges. Typed `source_records` snapshots in the private gold envelope are persisted with the unpublished lesson in one caller transaction. No automatic repair; English Quran evidence needs an approved translation. | Factory 13.7.3; F-76; production/test separation. |
| 2026-10-05 | D-102 | **The organizers' source recommendations do not establish technical capabilities or licences.** Their broader translation choices are acknowledged; D-93 remains Qabas's conservative selected route. Canonical authority and auxiliary capabilities never share a misleading attribution. | Entire 15-page organizers' PDF independently reviewed. |
| 2026-10-05 | D-103 | **Tafsir MCP stays mock-only until the actual package, tool/argument/response mapping and native process-egress isolation are confirmed.** Use bounded stdio JSON-RPC, JSON argv without a shell, schema-checked allow-listed calls and no ambient secrets. No fake tool name is claimed as live-verified. | O-03; source/operations handoff; native architecture D-03. |
| 2026-10-05 | D-104 | **Source replay cannot silently change religious attribution.** Changed citation metadata, grade/grader/reference or translation key/version requires re-verification even when the quoted text is unchanged. Gold hadith content must match its Dorar record, including grade source/category, collection reference and verbatim excerpt; translated text needs an explicitly linked matching HadeethEnc record. Multi-record collection/grade composites require a separately reviewed binding rather than an inferred aggregation. | F-78; factory 13.7.3; D-92/D-94. |
| 2026-10-05 | D-105 | **Canonical Qur'an sources are cited as "سورة <name> — <edition>"** with reference `<name>: <ayahs>` and a verse reading link, never a dataset title or download. Refines D-89: the contract provider value stays `quran_com`; the edition and digest stay in the title and `raw.parts`. | F-83; contract fixtures' learner-facing Source shape. |
| 2026-10-05 | D-106 | **Only authority records become citable `sources` rows**, enforced in `store.persist`: capability-only providers (Quran Foundation verse text, search, audio, timings) are refused, and so is any record claiming the mushaf text-authority part outside canonical insertion. Capability snapshots live in the authority row's `raw`. | F-80; authority/capability principle. |
| 2026-10-05 | D-107 | **The acceptable tafsir books and their order need specialist confirmation** against the organizers' tafsir rule (first-three-centuries sources or dorar.net/tafseer) before any tafsir is served; Tafsir Center stays a candidate route, mock-only (D-103). | F-84; organizers pp. 3, 11–12; O-05. |
| 2026-10-05 | D-108 | **Gold snapshots are re-verified against the live providers before production approval** of any lesson citing hadith, translations or audio (once O-03 approves those providers); the import-time checks are consistency checks over operator-supplied provenance. | F-85; O-03. |
| 2026-10-04 | D-13 | Git HTTPS failed certificate verification with Git's bundled OpenSSL. The repo-local config now sets `http.sslBackend=schannel` (Windows certificate store); global config is untouched. The first push made `phase/0-workspace` GitHub's default branch, so switch the default to `main` when `phase-0` is tagged. | — |

## Progress log

| Date | Phase | Entry |
|---|---|---|
| 2026-10-04 | — | Phase plan created from FINAL_ENGINEERING_HANDOFF |
| 2026-10-04 | — | Plan revised: Raqeeb after the learning experience + factory (D-02); native dev env (D-03); full-quality scenes (D-06) |
| 2026-10-04 | 0 | Environment verified and completed (Python 3.12.10, uv, Postgres 16.14, Redis 7.4.11, ffmpeg 9.0.2, Node 22). Handoff integrity verified. Rev 10 suites rerun: 595/279/105/382 PASS. Git connected; WIP branch `phase/0-workspace` pushed. `check-env.ps1`: all checks pass except the database (role not yet created). Waiting on the dev DB role and D-10. |
| 2026-10-04 | 0 | ✅ Phase 0 complete: `check-env.ps1` all green (dev DBs created); repo stays public with data policy D-14; tagged `phase-0`, merged to `main`. |
| 2026-10-04 | 1 | Skeleton built: vendored contract (14 files, checksums verified), private mirror + full suites 595/279/105/382 PASS, guard + pre-commit hook, config, errors, contract headers, contract-only OpenAPI, health, logging, adapters, Celery, storage. 84 tests green locally; CI pending. |
| 2026-10-04 | 1 | ✅ Phase 1 complete: CI green on GitHub (84 passed, native Postgres/Redis on the runner); tagged `phase-1`, merged to `main`. |
| 2026-10-04 | 1.1 | Corrective commit (D-19): full contract vendored and its suites in CI; guard now targets secrets, private handoff artifacts (fingerprints) and hidden evaluation data instead of Arabic text; binary-digest bug fixed. 96 tests + 595/279/105/382 green locally. |
| 2026-10-04 | 2 | Core schema built: 31 tables, contract-derived enum CHECKs, all mandatory constraints, 12 integrity triggers, least-privilege grants; migration round trip and `alembic check` parity in tests; NULL-CHECK bug in the recitation range found and fixed. 150 tests green locally; CI pending. |
| 2026-10-04 | 2 | ✅ Phase 2 complete: CI green (151 passed; role grants verified with CI-created roles); tagged `phase-2`, merged to `main`. |
| 2026-10-04 | 3 | Platform controls built: guest/reviewer auth with immediate revocation, rate limits, idempotency keys, outbox relay, S3/local storage, onboarding/profile, account deletion and purge; real worker verified. 214 tests green locally; CI pending. Product progress notes created (git-ignored). |
| 2026-10-04 | 3 | First CI run failed: Linux accepted `localtime` as a time zone (OS list). Fixed by validating against the `tzdata` package list (D-28); tests extended (`Factory`, `posixrules`, path-like names). |
| 2026-10-04 | 3 | ✅ Phase 3 complete: CI green (218 passed incl. role grants; contract suites green); tagged `phase-3`, merged to `main`. |
| 2026-10-04 | 4 | Handoff re-reviewed for curriculum and content rules; 13 findings recorded (F-1–F-13), one genuine conflict resolved (D-38). Built the curriculum file and slots (migration 0002), registries, the lesson package model, deterministic validators, versioned storage, digest-bound publication, unit availability, projections and the seed script. Bugs found and fixed during the build: 1-based lesson index, sentence/claim ID prefixes, JSONB losing exercise order (digest mismatch). 312 tests green locally; CI pending. |
| 2026-10-04 | 4 | ✅ Phase 4 complete: CI green (313 passed incl. role grants; contract suites green); tagged `phase-4`, merged to `main`. |
| 2026-10-04 | 5 | Handoff re-reviewed for learner delivery (12 findings F-14–F-25). Built the journey service, the complete planner, guide/reader/session endpoints, assessment and review composition, resume with redaction, abandon and term cards; hardened Phase 4 (D-41, D-42) and corrected the Phase 3 planner (D-44). 392 tests green locally; CI pending. |
| 2026-10-04 | 5 | ✅ Phase 5 complete: CI green (393 passed incl. role grants; contract suites green); tagged `phase-5`, merged to `main`. |
| 2026-10-04 | 6 | Handoff re-reviewed for answers, grading, retries, feedback and adaptation (12 findings F-26–F-37). Built replay-first answer handling, all evaluators (86/86 contract evaluations reproduced), per-answer mastery/misconception/recitation-XP effects with a fixed lock order, and recitation binding; fixed two Phase 4 bugs and added the untimed-items rule (D-61). 524 tests green locally; CI pending. |
| 2026-10-04 | 6 | ✅ Phase 6 complete: CI green (525 passed incl. role grants; contract suites green); tagged `phase-6`, merged to `main`. |
| 2026-10-04 | 7 | Recovered the complete handoff/contract/history context; recorded F-38–F-47 and D-67–D-75. Built atomic replayable finish, FSRS, progression facts, terms, protected repeat rewards, daily activity/quests and profile/glossary endpoints, with migration 0003. 556 passed + one CI-only role check skipped locally; lint/type/OpenAPI/migration/safety checks and full 595/279/105/382 contract suites green. Private product progress notes updated; CI pending. |
| 2026-10-04 | 7 | ✅ Phase 7 complete / Milestone A: GitHub CI 37226971161 green (557 passed including role grants; contract suites 595/279/105/382 green). Integration gate 3 passed. Tagged `phase-7`, merged to `main`; private product notes remain git-ignored. |
| 2026-10-05 | 7.1 | Independent Phase 7 audit (baseline 556 passed reproduced). Policy and core finish behaviour verified; five defects fixed: pagination limits, finish rate limit, missing `session.finished` consumer, legacy active sessions (migration 0004 guard + CHECK + operator script), quest-title grammar. 561 passed locally; CI pending. |
| 2026-10-05 | 7.1 | ✅ Phase 7.1 complete: CI green (562 passed incl. role grants; contract suites green); tagged `phase-7.1`, merged to `main`. |
| 2026-10-05 | 8 | Handoff re-reviewed for real content (12 findings F-53–F-64). Built the gold path (import unpublished → authenticated digest-bound approve+publish), the Unit 0 and Salah converters with typed blocker reports, the pending reasoning-tool mapping, staging support. Real content: 12/12 Unit 0 lessons and the Salah reference correctly blocked; projections proven lossless/valid with stand-ins. CI pending. |
| 2026-10-05 | 8 | First CI run failed on F-65 (a time-of-day-dependent Phase 7 test, 23:26 Riyadh); fixed with one test clock. |
| 2026-10-05 | 8 | ✅ Phase 8 complete: CI green (582 passed incl. role grants; contract suites green); tagged `phase-8`, merged to `main`. |
| 2026-10-05 | 9 | Continued `phase/9-source-adapters` from `0332e69` without rewriting history. Read the full organizers' PDF independently; completed capability adapters, resilience/sidecar tests, immutable persistence, canonical scripture insertion and Unit 0/gold verification. Added D-88–D-104 and F-66–F-78. Focused checks: 134 passed; strict mypy, ruff, OpenAPI, safety and 595/279/105/382 contracts pass. First full run: 692 passed, one local role check skipped; final full run and branch CI pending. Fixed four CI tests to use explicit configuration rather than local `.env` secrets (F-77). Private product notes updated and remain ignored. |
| 2026-10-05 | 9 | ✅ Phase 9 complete: final local suite 702 passed / 1 local role skip; GitHub CI 37252965749 green with 689 passed / 14 private-data skips and contracts 595/279/105/382. Ruff, strict mypy, OpenAPI and safety green. Real Unit 0 converter resolves canonical Arabic insertion while correctly retaining translation/content/media blockers. Release checkpoint `phase-9`; O-03/O-05/O-06/O-12/O-13 and the documented D-95–D-97 follow-ups remain open. |
| 2026-10-05 | 9.1 | Independent Phase 9 audit (baseline 702 passed / 1 skipped reproduced). Core source guarantees verified; seven findings F-79–F-85: segment audio, citable-only persistence, breaker trial release and IslamHouse definite answers, live gate before cache, learner-facing Qur'an citation, tafsir authority wording, gold snapshot trust boundary. D-105–D-108. |
