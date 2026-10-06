# Data model and versioning

**Purpose:** define storage responsibilities, immutable identities and required database migration work. These table sketches are design inputs; no production SQL migrations are delivered.

The tables below are the inherited sketch plus the rev 10 additions marked **(rev 10)** and the curriculum/learning-design amendment marked **(curr)** ([curriculum](../01_PRODUCT/CURRICULUM_AND_LEARNING_DESIGN.md)). The constraints in the next section are mandatory parts of the first migration, not later hardening. Use real database transactions and the lock order in [backend handoff](../05_BACKEND/BACKEND_HANDOFF.md) (session → concepts by id → terms). Preserve served public order and private grading snapshots; content regeneration cannot alter active sessions.

## Mandatory constraints

| Invariant | Enforcement |
|---|---|
| One original and one retry per exercise and session | `UNIQUE (session_id, exercise_id, is_retry)` on `session_answers` |
| One active session per (user, kind, lesson/unit, mode) | Partial unique index `WHERE status = 'active'` on `sessions` (`COALESCE` nullable keys) |
| One completion per session; stored result replayed | `sessions.finished_at`/`result_snapshot` set once (`CHECK` + update guarded by `status = 'active'`) |
| Published content is immutable | `lesson_versions`, `exercise_versions`, `scene_versions`, `scene_assets` are insert-only once `published_at` is set (revoke `UPDATE`/`DELETE` for the app role; trigger rejects updates) |
| Recitation binding | `recitation_checks` stores `user_id`, surah/ayah/range and `checked_text_sha256`; answer grading compares with the served exercise version (API §6.6) |
| Six-decimal private mastery | `learner_concepts.mastery numeric(7,6) CHECK (mastery BETWEEN 0 AND 1)` |
| Effects happen once | `outbox_events.event_key UNIQUE`; `effect_ledger.effect_key UNIQUE`; `xp_events UNIQUE (user_id, reason, ref_type, ref_id)`; `daily_goal_met` unique per (`user_id`, `local_date`) |
| Challenge answers | `UNIQUE (duel_id, user_id, question_index)`; phase writes fenced by `duels.coordinator_epoch` |
| Request idempotency | `idempotency_keys UNIQUE (user_id, key)` |
| Gate decisions are auditable | `review_decisions` insert-only; `factory_runs.review_digest` must match at decision time |
| One lesson per curriculum slot (lesson-composition refinement) | `UNIQUE (unit_id, index)` on `lessons`; a new factory run or gold import for an occupied slot creates a new `lesson_versions` row, never a sibling lesson |
| One completion record per canonical lesson **(curr)** | `learner_lessons` primary key (`user_id`, `lesson_id`); never keyed by track, variant, language or entry surface |
| One introducing lesson per concept **(curr)** | `concepts.introduced_by_lesson_id` set once at publication; publish fails if another lesson already introduces the concept |

## Versioning and migration strategy

- **Schema migrations:** Alembic, forward-only, expand → migrate → contract. A deploy may only ship code that works with both the previous and the new schema, so rolling restarts are safe. Destructive steps (drop/rename) wait one release after the code stops using the column. Every migration has a tested downgrade path or a documented restore procedure.
- **Wire contract:** `Qabas-Contract` headers and `426 client_outdated` (API §3.2). Generated Dart DTOs **ignore unknown response fields** (json_serializable default; do not enable `disallowUnrecognizedKeys`) and tolerate unknown enum values by mapping them to an `unknown` case that renders a safe fallback. Server responses and contract tests stay strict. An additive response field or enum value is then backwards compatible within `/v1`. Removing, renaming or re-typing a field, changing a meaning or adding a required request field is breaking: it needs a new contract revision, a raised minimum client version, and the server keeps serving the old shape to clients and pinned sessions until they are retired.
- **Content versions:** each published `lesson_versions`/`exercise_versions`/`scene_versions` row records `contract_revision` and `scene_schema`. A session snapshot keeps the shape it was served with. `GET /sessions/{id}` returns the stored snapshot unchanged, and the client renders any revision it still declares as supported. If a future revision changes a learner shape, the server must either keep serving the old revision to pinned sessions or migrate snapshots with a tested, reversible transform recorded per row (`snapshot_revision`).
- **Revision 9 → 10:** no session snapshot changes (`Session`, `Exercise`, `AnswerEvaluation`, `SessionResult` stay wire-identical). Factory runs gain `review_digest`/`published`; the curriculum amendment adds `User.goal_anchor`, `JLesson.standalone_eligible`/`soft_lock`, the extended `LessonPlan`, `Claim.basis`/`reasoning`, sentence roles and `Draft.arc_map` (contract_revision10/CHANGES.md). No revision 9 data is known to exist; confirm under O-01.

## Data protection

Learner uploads (Raqeeb attachments) live in a private bucket with signed URLs; recitation audio is never stored. Reviewer previews/drafts are private. Only published content goes to the public CDN. `DELETE /me` and retention follow API §6.2 and [O-09](../00_REVIEW/STATUS_AND_OPEN_DECISIONS.md). Backups inherit the purge: deleted users are re-purged after any restore, using the `deletion_jobs` log. Production database and object-store encryption at rest is required; access is via least-privilege roles (app, worker, migration, read-only analytics).

Model stored glossary with `StoredGlossaryTerm`: bilingual headings/definitions/examples, canonical nullable Arabic and the declared source/concept/lesson/audio references. Required public nulls and explicit ordering/bucket display metadata must survive stored/reviewer/public projection. Legacy null/plain backfill is demonstrated in [display_fields.py](../03_API/contract_revision10/contract/display_fields.py); it is not a migration strategy for pinned production records.

Include a content/schema-version negotiation and migration plan for any already published/pinned data. Since this candidate has not been deployed, confirm whether legacy production records exist rather than assuming they do. The immutable public contract is in [API requirements](../03_API/API_REQUIREMENTS.md).

## 4. Data model

Types abbreviated; all tables have `created_at`/`updated_at` where useful. JSON columns are `jsonb`.

### 4.1 Users and community
| Table | Key columns |
|---|---|
| `users` | `id`, `display_name`, `avatar_key`, `role` (learner/reviewer), `language`, `track`, `familiarity` (nullable), `daily_goal_minutes` (5/10/15/20), `private_profile` (default true), `timezone`, `onboarding_completed`, `goal_anchor` (nullable registry key; onboarding bridge only, never used for ordering, recommendations, adaptation or inference) **(curr)**, `email` (reviewers), `password_hash` (reviewers, Argon2id), `is_synthetic`, `is_bot`, `last_seen_at`, `deleted_at` **(rev 10)** |
| `auth_sessions` **(rev 10)** | `id`, `user_id`, `token_hmac` (unique; HMAC-SHA-256 with the server pepper), `role`, `created_at`, `last_used_at`, `expires_at` (reviewers), `revoked_at` |
| `idempotency_keys` **(rev 10)** | `user_id`, `key`, `request_hash`, `response_status`, `response_body`, `created_at` — unique (`user_id`, `key`), 24 h retention |
| `deletion_jobs` **(rev 10)** | `user_id`, `requested_at`, `completed_at`, `steps` (json) — survives the purge as the audit/restore re-purge log |
| `xp_events` | `id`, `user_id`, `reason`, `xp`, `ref_type`, `ref_id`, `week_key`, `local_date` |
| `daily_activity` | `user_id`, `local_date`, `minutes`, `xp`, `qualifying` (bool) — PK (`user_id`, `local_date`) |
| `leagues` | `id`, `week_key`, `tier_key` |
| `league_tiers` | seeded config: `tier_key`, `index`, `name` {ar,en}, `promotion_zone_size`, `is_top_tier` (names mirror the prototype's `community_screen.dart`) |
| `learner_tiers` | `user_id`, `tier_key`, `promoted_at` |
| `quests` | `id`, `user_id`, `local_date`, `slot` (1–3), `kind`, `goal`, `progress`, `reward_xp`, `completed_at` |
| `achievements` | seeded config: `achievement_key`, `title` {ar,en}, `description` {ar,en}, `counter`, `target` (set mirrors the prototype's `achievements_screen.dart`) |
| `learner_achievements` | `user_id`, `achievement_key`, `progress`, `unlocked_at` |
| `league_members` | `league_id`, `user_id` |
| `friendships` | `user_a`, `user_b` (ordered pair) |
| `friend_invites` | `id`, `code`, `inviter_id`, `expires_at`, `used_by`, `used_at` |
| `duels` | `id`, `preset` (duel/group), `mode`, `status`, `phase`, `opponent_type`, `bot_fill`, `config`, `expires_at`, `lobby_deadline_at`, `coordinator_epoch` **(rev 10)**, `result` |
| `duel_players` **(rev 10)** | `duel_id`, `user_id`, `is_bot`, `status` (invited/joined/declined/left), `joined_at` — 2–4 rows |
| `duel_questions` **(rev 10)** | `duel_id`, `question_index`, `exercise_id`, `exercise_version`, `issued_at`, `deadline_at`, `closed_at`, `reveal_until` (per player for async duels: add `user_id`) |
| `duel_answers` | `duel_id`, `user_id`, `question_index`, `answer`, `correct`, `received_at`, `elapsed_ms`, `points` — unique (`duel_id`, `user_id`, `question_index`) |

### 4.2 Content
| Table | Key columns |
|---|---|
| `units` | `id`, `index` (curriculum position), `title`/`subtitle` {ar,en} × {explorer, new_muslim} (track framing; an Explorer-only unit has only `explorer`), `art_key` (nullable), `guide` per language × track (nullable: `{title, sections: [{title, sentences}]}`), `tracks` (`["explorer"]` for unit_0, both for units 1–10; replaces `start_for_tracks`: a track starts at the first unit of its path) **(curr)**, `coming_soon`, `pass_percent` (80) |
| `concepts` | `id`, `unit_id`, `title` {ar,en}, `prerequisite_ids` (curriculum concept graph consulted by the Curriculum Architect; not read for access), `introduced_by_lesson_id` (set at publication) **(curr)** |
| `terms` | `id` (wire `term_id`), `text` {ar,en}, `arabic` (nullable canonical Arabic display, independent of localized heading), `transliteration`, `concept_id`, `lesson_id`, `source_id`, `pronunciation_audio_url`, `definition` {basic:{ar,en}, intermediate:{ar,en} or null} (Span[]), `example` {ar,en} (Span[]); typed wire storage/reviewer model `StoredGlossaryTerm` |
| `misconceptions` | `id`, `unit_id`, `concept_id`, `title` {ar,en}, `card` {ar,en} (Span[]), `source_ids` |
| `sources` | `id`, `kind`, `provider`, `title`, `reference`, `excerpt`, `url`, `raw` (provider payload) |
| `lessons` | `id` (canonical lesson identity, shared by both tracks), `unit_id`, `index` (curriculum position; never a prerequisite), `lesson_type`, `estimated_minutes`, `xp`, `current_version`, `is_gold`; denormalized from the current version **(curr)**: `prerequisite_concept_ids`, `introduced_concept_ids`, `standalone_eligible`, `variants` (published track variants) |
| `lesson_versions` | `id`, `lesson_id`, `version`, `reviewed_by`, `published_at`, `run_id`, `plan` (approved `LessonPlan`: outcome, prerequisites, introduced concepts, arc, reasoning tools, standalone flag, budgets) and `arc_map` **(curr)**, `content` (Arabic variants authored; English variants localized from them) — `{ "<lang>": { "<variant>": { "title", "subtitle", "objectives": Span[][], "blocks": Block[], "completion": { "challenge": Span[] \| null, "review_topics": [{topic_id, title, concept_ids}], "check_in": Span[] \| null }, "source_ids", "displayed_source_ids" } } }`. `blocks` use the contract block shapes (§5.6) **including every `Visual` descriptor, story (`label`, `provenance`, `origin.show_card`; beats with `quote`, `quote_meaning`), teach card (`eyebrow`, `style`, points, `visual_params`), `predict` block, and hook `cta`**; exercise blocks store only `exercise_id`. |
| `claims` | `id`, `lesson_version_id`, `text`, `status`, `basis` (`source`/`reasoning`) **(curr)**, `evidence` (list of `{source_id, supports, verifier_note}`), `reasoning` (`{tool, premises, inference}` for `basis = reasoning`) **(curr)** |
| `sentences` | `id`, `lesson_version_id`, `lang`, `variant`, `role` (`claim`/`framing`/`hypothetical`/`instruction`/`question`) **(curr)**, `claim_ids` (non-empty exactly for `claim`), `edited_by_reviewer` |
| `exercises` | `id`, `lesson_id` (nullable for unit-level), `unit_id`, `purpose` (lesson, pretest, unit_test, duel), `type`, `concept_ids`, `current_version` (one wording per language serving both tracks) |
| `exercise_versions` | **immutable** per (`exercise_id`, `version`): `content` {ar,en} (`prompt`, `payload` incl. presentations/visuals/segments, `explanation`, `option_feedback`, `pin_labels`, `event_dates`), `scoring` (`accuracy`, `combo`, `layer`), `framing`, `answer_key`, `option_misconceptions`, `targets_misconception_id`, `source_ids`, `duel_eligible`, `lesson_version_id`. Never updated after publish; grading reads only from here. |
| `scene_versions` | **immutable** per (`scene_id`, `version`): `manifest_url`, `sha256`, `bytes`, `view_box`, `states` (declared schema), `required_capabilities`, `anchors`, `fallback_image` (`Image`), `preview` (frame URLs, animation preview URL, reduced-motion still), `audit`, `status` (draft/published), `created_by_run_id` |
| `scene_assets` | `scene_id`, `version`, `asset_id`, `url`, `mime_type`, `width`, `height`, `bytes`, `sha256` |
| `visual_registry` | Not a table: `content/visual_registry.yaml` (§6.5), loaded at startup. |

### 4.3 Learner state
| Table | Key columns |
|---|---|
| `learner_units` | `user_id`, `unit_id`, `state`, `pretest_taken_at`, `pretest_percent`, `unit_test_best_percent`, `first_post_percent`, `skipped` |
| `learner_lessons` | `user_id`, `lesson_id` (canonical), `state`, `completed_at`, `best_percent` — completion is independent of track, variant, language and entry surface **(curr)** |
| `learner_concepts` | `user_id`, `concept_id`, `mastery`, `fsrs_card` (json), `due_at`, `last_reviewed_at` |
| `learner_terms` | `user_id`, `term_id`, `state`, `exposures`, `opened_count` |
| `learner_misconceptions` | `user_id`, `misconception_id`, `status` (active/resolved), `evidence_score`, `correct_streak`, `activated_at`, `resolved_at` |
| `sessions` | `id`, `user_id`, `kind`, `mode` (review only), `lesson_id`, `lesson_version_id`, `unit_id`, `status`, `feedback_mode`, `language`, `variant`, `items_snapshot` (exactly what was served), `served_exercises` (`[{exercise_id, version}]`, referencing `exercise_versions`), `served_scenes` (`[{scene_id, version}]`), `started_at`, `finished_at`, `duration_ms`, `result_snapshot` (stored `SessionResult`, replayed) **(rev 10)**, `contract_revision` **(rev 10)** |
| `session_answers` | `id`, `session_id`, `exercise_id`, `exercise_version`, `answer`, `correct` (private, nullable for skipped/unavailable), `elapsed_ms`, `is_retry`, `misconception_id`, `evaluation` (the exact `AnswerEvaluation` issued or computed at submission, incl. mastery before/after — replayed as-is, never recomputed), `recorded_at` |
| `recitation_checks` | `id`, `user_id`, `surah`, `ayah`, `word_start`, `word_end` (nullable), `checked_text_sha256` (normalized expected words), `status`, `passed`, `words`, `summary` |

### 4.4 Raqeeb
| Table | Key columns |
|---|---|
| `raqeeb_conversations` | `id`, `user_id`, `title`, `context` |
| `raqeeb_messages` | `id`, `conversation_id`, `role`, `status`, `stage`, `text`, `attachments`, `understood_input`, `classification`, `abstained`, `blocks`, `citations`, `terms`, `suggested_lessons`, `error`, `feedback`, `feedback_reason`, `completed_at`, `trace` (internal: retrieved items, verifier verdicts, timings) |
| `raqeeb_memory` | `id`, `language`, `question_class`, `canonical_question` (de-personalised), `embedding` vector(1024), `core` (pre-adaptation blocks + citations), `source_digests`, `policy_version`, `prompt_version`, `origin_user_id` (purge only), `hits`, `created_at`, `expires_at` **(rev 10 guards; backend §9.2)** |

### 4.5 Factory and evaluation
| Table | Key columns |
|---|---|
| `factory_runs` | `id`, `unit_id`, `lesson_type`, `brief`, `position_index` (curriculum position of the lesson slot, not a dependency), `status`, `stage`, `stages`, `plan`, `artifacts` (claims, evidence, Arabic drafts, English localizations, arc map, exercises, glossary, misconceptions, images, narration), `qa_report`, `gate1_decision`, `gate2_decision`, `stage_timings`, `review_started_at`, `review_finished_at`, `published_lesson_id`, `published_version`, `review_digest` **(rev 10)**, `cost` (tokens/media spend) **(rev 10)** |
| `review_decisions` **(rev 10)** | `id`, `run_id`, `gate` (1/2), `decision`, `reviewer_id`, `reviewed_digest`, `published_digest` (Gate 2 approve), `edits`, `reason`, `decided_at` — insert-only audit |
| `outbox_events` **(rev 10)** | `id`, `event_key` (unique), `kind`, `payload`, `created_at`, `available_at`, `attempts`, `processed_at` — written in the producing transaction; relayed with `FOR UPDATE SKIP LOCKED` |
| `effect_ledger` **(rev 10)** | `effect_key` (unique), `event_key`, `applied_at` — consumer idempotency |
| `blind_pairs` | `id`, `lesson_version_a`, `lesson_version_b`, `gold_side` |
| `blind_responses` | `pair_id`, `reviewer_id`, `clearer`, `more_accurate`, `guessed_handwritten` |
| `benchmark_runs` | `id`, `run_at`, `question_count`, `results` |

---
