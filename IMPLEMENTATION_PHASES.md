# Qabas Backend — Implementation Phases

**Scope:** backend only (FastAPI, Postgres, Redis, Celery workers, sources, recitation, Lesson Factory, reviewer gates and publishing, Raqeeb, community, challenges, operations). The Flutter app, Dart DTOs, `packages/qabas_scene` and the `tools/scene_preview` CLI are owned outside this plan and appear only as **external dependencies**.
**Baseline:** `FINAL_ENGINEERING_HANDOFF/` (contract **revision 10 candidate**, schema SHA-256 `9d67bda0…481c`). The handoff folder is read-only and excluded from git.
**Repository:** https://github.com/Abdulrahman-me/Qabas (branch `main` = latest completed checkpoint).
**Created:** 2026-10-04 · **Last updated:** 2026-10-04

**Priority order (D-02):** first the core learning experience (Phases 1–10), then the Lesson Factory, reviewer gates, publishing and the full visual/media pipeline (11–15). Raqeeb (16–17) starts only after that milestone. Community and challenges (18–20) and production hardening (21) follow.

---

## Status board

| Phase | Name | Status | Checkpoint tag | Notes |
|---|---|---|---|---|
| 0 | Workspace, toolchain and baseline verification | ✅ Done | `phase-0` | |
| 1 | Contract vendoring and service skeleton | 🔄 In progress | `phase-1` | All local checks green; waiting on first CI run |
| 2 | Core database schema and migrations | ⏳ Not started | `phase-2` | |
| 3 | Platform controls: auth, idempotency, rate limits, outbox, deletion | ⏳ Not started | `phase-3` | |
| 4 | Content storage, registries, projection and seeding | ⏳ Not started | `phase-4` | |
| 5 | Journey, lessons and session creation | ⏳ Not started | `phase-5` | |
| 6 | Answers: replay-first, evaluators, per-answer adaptation | ⏳ Not started | `phase-6` | |
| 7 | Finish transaction, FSRS, planner, reviews, glossary, stats | ⏳ Not started | `phase-7` | **Milestone A: durable learning slice** |
| 8 | Content import (Salah reference, Unit 0 drafts), approval-gated publish, staging | ⏳ Not started | `phase-8` | |
| 9 | Source adapters (tool layer) | ⏳ Not started | `phase-9` | |
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
| A-3 | All religious content (Salah reference, Unit 0 drafts, curriculum titles) is unapproved. It is imported **unpublished**, or published only to staging, until O-05/O-12 close. | Handoff status register |
| A-4 | Product decisions P-01–P-08 use the handoff's engineering defaults until decided. | STATUS_AND_OPEN_DECISIONS |
| A-5 | Generated scenes target the final production architecture. A missing Flutter preview tool limits **inspection only**, never scene quality or capability. | D-06 |
| A-6 | Commits carry no AI co-author or attribution metadata. | D-09 |

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
- [ ] CI workflow `.github/workflows/ci.yml` (ubuntu-24.04, Python 3.12, runner-native Postgres 16 and Redis, no Docker): guard, ruff, mypy, OpenAPI check, pytest. **Pending its first green run on GitHub.**

**Local status:** 84 tests pass (including the integration tests on the real `qabas_test`/Redis), ruff clean, mypy strict clean.
**Exit:** contract suites green locally (done), CI green on GitHub, tag `phase-1`.

---

## Phase 2 — Core database schema and migrations

**Goal:** the first Alembic migration with **every mandatory constraint**.
**Refs:** DATA_MODEL_AND_VERSIONING (mandatory constraints, §4.1–4.3, 4.5 platform tables).

- [ ] SQLAlchemy 2 async models: `users`, `auth_sessions`, `idempotency_keys`, `deletion_jobs`, `units`, `concepts`, `terms`, `misconceptions`, `sources`, `lessons`, `lesson_versions`, `claims`, `sentences`, `exercises`, `exercise_versions`, `scene_versions`, `scene_assets`, `learner_units`, `learner_lessons`, `learner_concepts`, `learner_terms`, `learner_misconceptions`, `sessions`, `session_answers`, `recitation_checks`, `xp_events`, `daily_activity`, `quests`, `outbox_events`, `effect_ledger`, `review_decisions`.
- [ ] Constraints: `UNIQUE(session_id, exercise_id, is_retry)`; partial unique active-session index (COALESCE keys); finish-once `CHECK`; `numeric(7,6)` mastery `CHECK 0..1`; `UNIQUE(unit_id, index)` on lessons; `learner_lessons` PK (`user_id`, `lesson_id`); `concepts.introduced_by_lesson_id` set-once; outbox/effect/xp/daily-goal uniques; `idempotency_keys UNIQUE(user_id, key)`.
- [ ] Immutability triggers on published `lesson_versions`, `exercise_versions`, `scene_versions`, `scene_assets`; insert-only `review_decisions`.
- [ ] DB roles: `app`, `worker`, `migration`, `readonly` (UPDATE/DELETE revoked where required).
- [ ] Test harness: per-test transactional fixtures on the native `qabas_test` database; factory helpers.

**Tables added later by their phases (additive migrations):** `factory_runs` (12), `blind_pairs`/`blind_responses`/`benchmark_runs` (15/17), Raqeeb tables (16–17), league/friend/achievement tables (18), duel tables (19–20).

**Exit:** constraint tests (duplicate attempt, second active session, update of a published version, mastery out of range) fail at the DB as expected; up/down migration green; tag `phase-2`.

---

## Phase 3 — Platform controls

**Goal:** the security and recovery primitives every later feature relies on.
**Refs:** BACKEND_HANDOFF §5, §5.1, §5.2; API §6.1–6.2; AD-20, AD-21, AD-25.

- [ ] **3.1 Auth:** `POST /auth/guest` (CSPRNG 32-byte token, only HMAC-SHA-256 with the pepper stored, generated display names); request auth with a ≤30 s cache; 180-day guest inactivity expiry; pepper rotation (two values accepted); `last_seen_at` throttled to 30 s.
- [ ] **3.2 Reviewer auth:** `POST /auth/reviewer` (Argon2id, lockout of 5 attempts per 15 min per account/address, no enumeration, 12 h sessions); `scripts/create_reviewer.py` (interactive password).
- [ ] **3.3 Rate limits:** Redis token buckets with the default table in §5.1; `429 rate_limited` + `retry_after_ms`; profile from `RATE_LIMITS_PROFILE`.
- [ ] **3.4 Idempotency-Key:** stored in the create transaction; same body → stored response; different body → `409`; concurrent duplicate waits; 24 h cleanup beat job.
- [ ] **3.5 Outbox:** write in the producing transaction; relay with `FOR UPDATE SKIP LOCKED`; `effect_ledger` consumer idempotency; redelivery test.
- [ ] **3.6 Storage:** two buckets (public `content`, private `private`); S3 implementation (boto3) alongside the local filesystem one; signed URLs (`SIGNED_URL_TTL_SECONDS`); content-addressed immutable writes.
- [ ] **3.7 Profile:** `POST /onboarding` (goal_anchor validated against the registry, `track_choice` mapping, no religion field), `GET /me`, `PATCH /me` (track change keeps state, avatar validation).
- [ ] **3.8 Deletion:** `DELETE /me` (revoke + anonymise in the request transaction, `user:{id}:purge` outbox event, idempotent purge job, `deletion_jobs` log).

**Tests:** `test_auth_sessions`, `test_idempotency_keys`, `test_rate_limits`, `test_account_deletion` (DB part), `test_onboarding_privacy`.
**Exit:** all of the above green; tag `phase-3`.

---

## Phase 4 — Content storage, registries, projection and seeding

**Goal:** content can be stored, validated, projected and seeded reproducibly. No learner endpoints yet.
**Refs:** SEED_AND_IMPORT_REQUIREMENTS §15; BACKEND_HANDOFF §6.5; DATA_MODEL §4.2.

- [ ] `content/curriculum.yaml`: Units 0–10, `tracks`, lesson slots, concept graph. Titles marked *pending O-12*.
- [ ] `content/visual_registry.yaml` + `test_registry_parity.py`.
- [ ] `contract/registries.json` from the template (tiers, achievements, avatars, unit art keys, goal anchors).
- [ ] Placeholder `referrals.yaml`, `safety_rules.yaml`, `medallions/registry.yaml` (content to be supplied and reviewed).
- [ ] Stored → public → reviewer projections (`project_term`, explicit nulls, captured bank order, secondary labels, category art).
- [ ] Publication validators of §6.5 (visual, teach, story, hook, predict, map pins, scoring, scene references, placeholder-media and visual-readiness gate) wrapping `contract/contextual.py` and `scene_check.py`.
- [ ] Version-aware import core: content digests, a no-op when identical, a new version when changed, never overwriting published or pinned versions.
- [ ] `scripts/seed.py` (production structure: units, `coming_soon`, bot user, synthetic users only when `SYNTHETIC_LEAGUE_MEMBERS=true`) and `--test-curriculum` (loads `fixtures/curriculum_test/` + `fixtures/scenes/`).

**Exit:** the test curriculum seeds twice with no diff; validators reject the negative fixtures; tag `phase-4`.

---

## Phase 5 — Journey, lessons and session creation

**Goal:** a learner can see the journey and start every session kind.
**Refs:** BACKEND_HANDOFF §6.1–6.2; API §6.3–6.5; AD-28, AD-29.

- [ ] `GET /journey`: track membership, prerequisite access, lesson/unit states, `soft_lock` (prerequisites + transitive `start_with`), `standalone_eligible` (Discover), `unit_test.can_skip`, `current`.
- [ ] `GET /units/{id}/guide`, `GET /lessons/{id}` (reader projection).
- [ ] `POST /sessions` for `lesson` / `review` (cards, quick) / `pretest` / `unit_test`: access checks (`404`, `409 prerequisite_unmet` with details), existing active session returned, variant choice (New Muslim → Explorer fallback only), composition sizes and pool minimums, serve-time shuffle stored in the snapshot, `served_exercises`/`served_scenes` pinning, `counts`, `sources`/`source_count`, `terms`.
- [ ] `GET /sessions/{id}` with feedback-mode redaction; `POST /sessions/{id}/abandon`.

**Tests:** `test_curriculum` (journey part), `test_discover_identity`, `test_version_pinning` (serve side), `test_assessment_supply`.
**Exit:** tag `phase-5`.

---

## Phase 6 — Answers: replay-first, evaluators, per-answer adaptation

**Goal:** correct, idempotent answer handling under concurrency.
**Refs:** API §6.5 (processing order), BACKEND_HANDOFF §6.3, §7.1–7.2; AD-08–AD-12, AD-24.

- [ ] **6.1 Processing order:** authenticate → parse identity only → replay lookup → (fresh) full validation → eligibility/order → grade → transact. No eager full-body validation.
- [ ] **6.2 Evaluators:** all 14 learner types plus duel `true_false`, against the pinned `exercise_versions` row; `categorize` validation (including `day_arc`); `map_place` unavailable; flashcard ratings; timeouts; `correct=null` handling.
- [ ] **6.3 Rules:** attempt identity, retry eligibility (`409 retry_not_allowed`), authored order (`409 out_of_order`), finished/abandoned sessions, immediate vs end/none responses.
- [ ] **6.4 Per-answer effects in the same transaction:** Decimal mastery (6 dp, half-up public 2 dp), retries, pretest half weight, misconception evidence/activation/resolution, term exposure; stored `evaluation` snapshot replayed as-is.
- [ ] Lock order: session → concepts ascending → terms.
- [ ] `recite_verse` answer binding is stubbed until Phase 10 (`check_id` validation interface only).

**Tests:** `test_types`, `test_attempt_identity`, `test_mastery`, `test_null_correct`, `test_history_redaction` (submit/replay part), concurrency tests (two devices racing the original and the retry; malformed changed body replays).
**Exit:** sub-tag `phase-6.1` after the evaluators, `phase-6` at the end.

---

## Phase 7 — Finish transaction, FSRS, planner, reviews, glossary, stats

**Goal:** complete the durable learning slice (**Milestone A**).
**Refs:** BACKEND_HANDOFF §6.4, §7.3–7.6, §10.1–10.2, §10.5–10.6; API §6.2, §6.5, §6.7.

- [ ] `POST /sessions/{id}/finish`: one transaction that stores and replays `SessionResult` (score, layers, `lesson_perfect`, `passed`, `review_items`, `duration_ms` clamp, XP grants, daily activity/streak/daily goal, quest progress and rewards, FSRS updates, term promotions, `unlocked`, `next_step`); pretest/first-post percentages; unit skip.
- [ ] Outbox events for unreported effects (`session:{id}:finished` → achievements/leagues/metrics consumers, added in their phases).
- [ ] FSRS service (py-fsrs), card review and quick review selection, `409 nothing_to_review`.
- [ ] Planner (`GET /journey/next`), level, `/me/concepts`, `/me/stats`, `/me/activity`, `/me/quests` (lazy deterministic quests).
- [ ] Glossary: `GET /glossary`, `GET /glossary/{id}`, `POST /glossary/{id}/opened`.

**Tests:** `test_finish_workflow` (exact §6.5 example), `test_finish_replay`, `test_recovery` (against `tools/recovery.py`), `test_scoring`, `test_curriculum` (complete), `test_history_redaction` (complete), crash/redelivery tests, concurrent finish.
**Exit:** Integration gate 3 (real Postgres race/replay/finish/outbox/crash); tag `phase-7`.

---

## Phase 8 — Content import, approval-gated publish, staging

**Goal:** real authored content on live endpoints, plus a staging environment for frontend integration.
**Refs:** FACTORY §13.6–13.7; SEED_AND_IMPORT; QUALITY §18.1 `test_salah_reference`.

- [ ] `scripts/import_gold.py`: imports into **unpublished** versions; runs all validators.
- [ ] Minimal publish path: a Gate 2-equivalent `review_decisions` row bound to the content digest → immutable publish (extended in Phase 13).
- [ ] Salah reference: import the four actual-source sessions (fixture `les_u1_l3` → production slot 3.2) with the backend-authored plan, claims, sentence roles, `arc_map`, keys, flashcards, assessment and duel items; `test_salah_reference.py` for 4 language × track combinations (14 steps, 14/13 terms, 12 banks, 8/7/6 counts, `source_count` 4).
- [ ] Unit 0 drafts: an importer projecting `UNIT_0_CONTENT/lessons/u0_l01…u0_l12.json` (authoring records) and its 20 scene manifests into rev 10 stored content, kept **unpublished**. Scripture placeholders stay flagged until verified insertion (Phase 9) and specialist approval.
- [ ] Staging environment (native services on the target host) with the test curriculum + reference content, so the frontend can integrate on live data.

**Gates:** publication of Salah and Unit 0 stays blocked on O-05/O-06/O-12/P-07; staging-only publication is allowed.
**External input:** frontend's `tools/export_reference_lesson` output (interim: reply8 `reference_export/` and `FRONTEND_DEMO_HANDOFF/reference_salah/`).
**Exit:** tag `phase-8`.

---

## Phase 9 — Source adapters (tool layer)

**Goal:** verified, cached, failure-tolerant evidence tools. The factory and verified scripture insertion depend on them.
**Refs:** SOURCE_ADAPTERS §12, §12.1; OPERATIONS timeouts/retries.

- [ ] `normalize_ar` + mushaf loader (`get`, `find_exact`, `find_fuzzy`).
- [ ] Adapters: Quran Foundation (search, translation, audio + word timings), Tafsir Center MCP (stdio), Dorar (run natively with Node as a local sidecar process), HadeethEnc, QuranEnc, IslamHouse.
- [ ] Common: timeouts 5 s/15 s, 2 retries with jitter, circuit breaker, adapter version, Redis cache (7 days unless the provider's terms say otherwise), `sources.raw` with provider ID, retrieval time and SHA-256.
- [ ] Verified scripture insertion by code (the Unit 0 placeholders from Phase 8 resolve through this).
- [ ] Recorded-response fixtures for tests (no live calls in CI).

**Gates:** O-03 (credentials/licenses/cache terms). Mock adapters proceed without them.
**Exit:** tag `phase-9`.

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
- [ ] Pipeline: safety rules → classifier → 8 class strategies → verifier → writer → level service (rewrite / term linking / check) → guard (regenerate once, then abstain) → output mapping; referrals; titles; history window; `suggested_lessons`.

**Tests:** contract-valid messages for all 8 classes (fake LLM), guard rules, `test_untrusted_input`.
**Exit:** tag `phase-16`.

---

## Phase 17 — Raqeeb inputs, guarded memory and benchmark

- [ ] Inputs: voice (ffmpeg → STT provider), images (vision extraction), DOCX, PDF (text and scanned via pypdfium2), limits, `input_unreadable`; private attachment storage + retention.
- [ ] pgvector installed and the extension enabled (D-05); embeddings worker (bge-m3, CPU); `raqeeb_memory` with guarded reuse (standalone, no attachments, source digests, equivalence check, version keys, expiry, purge by `origin_user_id`).
- [ ] `bench/questions.jsonl` + `bench/run.py` with the judge and P-05 thresholds; `benchmark_runs` table.

**Tests:** `test_raqeeb_memory_guard`, input-type tests.
**Gates:** O-03 (models/STT), P-05 (release thresholds), P-04 (provider disclosure).
**Exit:** tag `phase-17`.

---

## Phase 18 — Community: leagues, friends, achievements

**Refs:** BACKEND_HANDOFF §10.3–10.7; API §6.9.

- [ ] Additive migration: `leagues`, `league_tiers`, `learner_tiers`, `league_members`, `achievements`, `learner_achievements`, `friendships`, `friend_invites`.
- [ ] Leagues: Riyadh-week `week_key`, assignment under an advisory lock, ranking, idempotent week-end promotion beat job, privacy masking, synthetic members behind `SYNTHETIC_LEAGUE_MEMBERS` (P-01).
- [ ] Friends: invite codes, accept with brute-force limits, online status, privacy.
- [ ] Achievements as outbox consumers from authoritative tables; `GET /me/achievements`.

**Exit:** tag `phase-18`.

---

## Phase 19 — Challenges: REST, selection, bot, async

**Refs:** BACKEND_HANDOFF §11, §11.1, §11.3, §11.4; API §6.10.

- [ ] Additive migration: `duels`, `duel_players`, `duel_questions`, `duel_answers`.
- [ ] `POST /duels`, invitations, accept/decline, get, history; presets `duel`/`group` with `config`; question selection (7/3, no repeats); shared `challenge_points()`.
- [ ] Deterministic seeded bot; async flow (`async`, `async/next`, `async/answer`), idempotency, 24 h forfeit beat job, expiry jobs.
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
| Reviewed curriculum titles, guides, bridges (O-12) | Content specialist | 4 (production seed), 12 |
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
| 2026-10-04 | D-14 | **Public-repo data policy.** Committed: application code, migrations, the rev 10 `contract/` directory (verified to contain no Arabic text, scripture or answer keys), docs, and synthetic neutral test data. Never committed: `FINAL_ENGINEERING_HANDOFF/`, contract fixtures and tools, `API_REQUIREMENTS.md`, private grading keys and evaluation context, gold/reference lessons, Unit 0 drafts, and any unapproved religious content. Those live in git-ignored `backend/.private/`. A safety guard enforces this in CI and pre-commit. | Full contract suites run locally only. Content imports (Phase 8) read from local private paths; staging data never enters git. |
| 2026-10-04 | D-15 | Contract-header cases the spec leaves open: a missing or non-integer `Qabas-Contract`, or a missing `Qabas-Client`, is treated as a pre-revision-10 client (`426 client_outdated`). A malformed `Qabas-Client` (not `android`, `ios` or `web` followed by `/` and a semantic version) is `400 validation_error` with `details.field`. Health and OpenAPI paths are exempt. | `app/middleware.py`; tests in `test_contract_headers.py`. |
| 2026-10-04 | D-16 | A request to a known path with an unsupported method returns `404 not_found`, like an unknown path, because §3.4 has no 405 row (adding a code is a contract change). | `app/errors.py`. |
| 2026-10-04 | D-17 | uv also needs the Windows certificate store: user-level `%APPDATA%\uv\uv.toml` sets `system-certs = true`. | Documented in `backend/README.md`. |
| 2026-10-04 | D-18 | Vendored layout keeps the handoff structure (`backend/contract/contract/*`, `backend/contract/tools/*`) because the tools locate the schema relative to themselves; `app/contract.py` puts the directory on `sys.path` so the modules stay byte-identical. OpenAPI components are the export's `$defs` and roots flattened with refs rewritten. Same-named definitions must be identical, except the four tagged-union roots, which differ only by `title`. | `app/contract.py`, `app/openapi.py`. |
| 2026-10-04 | D-13 | Git HTTPS failed certificate verification with Git's bundled OpenSSL. The repo-local config now sets `http.sslBackend=schannel` (Windows certificate store); global config is untouched. The first push made `phase/0-workspace` GitHub's default branch, so switch the default to `main` when `phase-0` is tagged. | — |

## Progress log

| Date | Phase | Entry |
|---|---|---|
| 2026-10-04 | — | Phase plan created from FINAL_ENGINEERING_HANDOFF |
| 2026-10-04 | — | Plan revised: Raqeeb after the learning experience + factory (D-02); native dev env (D-03); full-quality scenes (D-06) |
| 2026-10-04 | 0 | Environment verified and completed (Python 3.12.10, uv, Postgres 16.14, Redis 7.4.11, ffmpeg 9.0.2, Node 22). Handoff integrity verified. Rev 10 suites rerun: 595/279/105/382 PASS. Git connected; WIP branch `phase/0-workspace` pushed. `check-env.ps1`: all checks pass except the database (role not yet created). Waiting on the dev DB role and D-10. |
| 2026-10-04 | 0 | ✅ Phase 0 complete: `check-env.ps1` all green (dev DBs created); repo stays public with data policy D-14; tagged `phase-0`, merged to `main`. |
| 2026-10-04 | 1 | Skeleton built: vendored contract (14 files, checksums verified), private mirror + full suites 595/279/105/382 PASS, guard + pre-commit hook, config, errors, contract headers, contract-only OpenAPI, health, logging, adapters, Celery, storage. 84 tests green locally; CI pending. |
