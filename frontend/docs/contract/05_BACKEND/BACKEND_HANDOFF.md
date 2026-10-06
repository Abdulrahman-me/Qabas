# Backend handoff

**Purpose:** define learner-service behavior: auth/onboarding, journey/sessions, deterministic grading/adaptation, recitation, Raqeeb, community and challenges. Public schemas are owned by [API requirements](../03_API/API_REQUIREMENTS.md). Tables/processes/source/factory/environment are in their dedicated documents.

The original backend service sections below are retained with the revision 9 display amendments and the final-review corrections (contract revision 10 candidate, auth/privacy/idempotency/coordinator rules). Effective revision 8 code/production corrections and the final-review decisions are recorded in [architecture decisions](../02_ARCHITECTURE/ARCHITECTURE_DECISIONS.md). The received code is contract/validation tooling; FastAPI services, SQL migrations, durable workers and deployment are not implemented.

## Required implementation controls

Use the canonical [revision 10 models/custom export](../03_API/contract_revision10/README.md) and contextual checks; expose matching OpenAPI with nested tagged payloads/events. Authenticate and extract parseable identity before full-body validation so recorded answers replay (processing order: [API §6.5](../03_API/API_REQUIREMENTS.md)). Fresh grading uses pinned served payload/private keys and recitation ownership/range/text; the private stored six-decimal mastery snapshot is authoritative.

**Transactions and effects (normative):** an answer transaction inserts the attempt (unique identity), stores the issued evaluation and applies the per-answer effects it reports (mastery, misconceptions, term exposure, recitation XP). A finish transaction inserts exactly one completion, computes and **stores the complete `SessionResult`** and commits everything that result reports: score/layers, XP grants, daily activity/streak, quest progress and rewards, FSRS updates, term promotions, unlocks, next step. A replayed answer or finish returns the stored snapshot. Only effects that the response does not report go through the durable outbox: achievements, league standings, metrics aggregates, semantic-memory cleanup and purge jobs. Each outbox event has a unique `event_key` (for example `session:{id}:finished`), and each consumer effect has a unique `effect_key`, so redelivery is harmless. Lock order: session row, then learner concept rows in ascending `concept_id`, then learner term rows; this prevents deadlocks between concurrent answers and finish. Test concurrent first/retry/finish, malformed changed-body replay and crash/redelivery against real Postgres. The pure helpers do not prove these behaviors.

Persist the served public bank and immutable exercise/source/scene/media versions. Preserve chronological original attempts, eligible one-time retry rules and immediate/end/none redaction on submit/replay/resume/reconnect/after finish. Never give a widget its private key. Validate all exercise and session compositions, not only Salah.

Challenges use the durable coordinator in §11.2; the single-process variant is a pilot-only option (O-04). Semantic memory is guarded as in §9.2: a high cosine score is only a candidate signal and cannot authorize a factual answer. Recitation runs in an isolated ASR worker (§8). Model/provider choices require measured learner-audio performance and license/source review.

Canonical glossary Arabic and display metadata must flow through storage, Session/glossary/Raqeeb/reviewer output; use [project_term](../03_API/contract_revision10/contract/display_fields.py). Reference gold stays unpublished until source/media/registry/evaluation gates close.

Proceed using [backend implementation](../08_IMPLEMENTATION/BACKEND_IMPLEMENTATION.md), [data model](../02_ARCHITECTURE/DATA_MODEL_AND_VERSIONING.md), [seed/import](SEED_AND_IMPORT_REQUIREMENTS.md) and [factory/reviewer](../06_CONTENT/FACTORY_AND_REVIEWER_HANDOFF.md). Original backend section references resolve through [the section map](../03_API/SECTION_REFERENCE_MAP.md).

## 5. Auth, users, onboarding (contract §6.1–§6.2)

- `POST /auth/guest`: create a learner with an auto-generated `display_name` (pattern: a word from a curated ar/en list + a number, e.g., "مسافر ٤٧" / "Traveler 47"), language defaults to `ar`, `track=explorer`, `onboarding_completed=false`. Return an access token (below).
- **Auth sessions (rev 10, replaces "long-lived JWT"):** the access token is 32 random bytes (base64url) from a CSPRNG. Only HMAC-SHA-256(`AUTH_TOKEN_PEPPER`, token) is stored, in `auth_sessions` (`user_id`, `role`, `created_at`, `last_used_at`, `expires_at`, `revoked_at`). Every request looks the hash up (cache ≤ 30 s, so a revocation takes effect within 30 s). Guest sessions: no fixed expiry, revoked by `DELETE /me` or operator action, expired after 180 days unused. Reviewer sessions: 12 h absolute. A self-contained JWT is not acceptable, because guest tokens must be revocable on account deletion. Never log tokens, `Authorization` headers or WebSocket tickets.
- `POST /auth/reviewer`: email/password for reviewer accounts created by an operator command (§15). Passwords are hashed with Argon2id. After 5 failed attempts per account or per address within 15 min, further attempts get `429` with a generic message (no account enumeration). Reviewer MFA is recommended and is a pending security decision ([O-11](../00_REVIEW/STATUS_AND_OPEN_DECISIONS.md)).
- `POST /onboarding`: store `familiarity` (nullable; not used by adaptation yet), `daily_goal_minutes` (5/10/15/20), `private_profile` and `goal_anchor` (nullable; validated against the `goal_anchors` registry). Map `track_choice` (`undisclosed` → `explorer`). No religion or worldview is requested, stored or inferred, and `goal_anchor` is used only by the client's onboarding bridge: never by the planner, access rules, adaptation, Raqeeb, metrics segmentation or any inference about the learner. Learner unit/lesson state is derived from track membership and prerequisites (§6.1), so nothing is pre-locked. Return `start_unit_id` (Explorer `unit_0`, New Muslim `unit_1`: the first unit of the track path) and `next_step` (planner, §7.3).
- `PATCH /me` with a new `track`: keep all learner state; lesson completion is keyed by canonical `lesson_id` and stays valid. Recompute the journey for the new track (Unit 0 appears only for Explorers; its records are retained) and `current`. The track changes only on this explicit request, never from behavior.
- Every authenticated request updates `users.last_seen_at` (throttled to once per 30 s).
- `GET /me/stats`: aggregate from `xp_events`, `daily_activity`, learner tables, league membership (see §10).
- `PATCH /me` also accepts `avatar_key` (validated against the avatar key list mirrored from the Flutter avatar set) and `private_profile`.
- `GET /me/activity`, `GET /me/quests`, `GET /me/achievements`, `GET /units/{id}/guide`: §10.5–§10.7 and §6.1.
- `DELETE /me`: as specified in [API §6.2](../03_API/API_REQUIREMENTS.md). Revoke sessions and anonymize community references in the request transaction; enqueue `user:{id}:purge` (outbox) for the 30-day purge of learner data, private objects and derived memory rows. The purge job is idempotent and reports completion in the operator audit log.

### 5.1 Rate limits and abuse controls (rev 10)
Enforced with Redis token buckets keyed by user, plus client address for unauthenticated calls. Defaults are configuration (operations) and must be tuned with real traffic. Exceeding a limit → `429 rate_limited` with `details.retry_after_ms`.

| Scope | Default |
|---|---|
| `POST /auth/guest` | 10 per hour per client address (platform attestation such as Play Integrity/App Attest is a later hardening option) |
| `POST /auth/reviewer` | lockout rule above |
| Raqeeb messages | 5 per minute and 50 per day per user; one `processing` answer per conversation |
| Recitation checks | 20 per minute per user |
| Session answers/finish | 120 per minute per user |
| Friend invites / duel creation | 20 per day / 30 per hour per user; invite acceptance 10 failures per hour per user (§10.4) |
| Challenge socket | 5 messages per second per socket |
| Reviewer factory runs | 20 per day per reviewer, plus the factory budget in the [factory handoff](../06_CONTENT/FACTORY_AND_REVIEWER_HANDOFF.md) |

Uploads are capped as in API §3.7. Image/document/voice extraction runs in workers with per-file time and memory limits; a file that exceeds them fails the message with `input_unreadable`.

### 5.2 Request idempotency (rev 10)
`Idempotency-Key` handling (API §3.2) uses `idempotency_keys` (`user_id`, `key`, `request_hash`, `response_status`, `response_body`, `created_at`, unique (`user_id`, `key`)) inside the same transaction as the create. A concurrent duplicate waits for the first to commit and returns its stored response. Rows expire after 24 h.

---

## 6. Journey and sessions (contract §6.3–§6.5)

### 6.1 Access, prerequisites and states
Curriculum position (unit index, lesson `index`) orders the Roadmap and the planner; it never gates access. Access depends only on the approved mandatory prerequisites ([curriculum](../01_PRODUCT/CURRICULUM_AND_LEARNING_DESIGN.md)).
- **Track membership:** a learner's journey contains the published lessons of the units whose `tracks` include the learner's track (Unit 0 Explorer-only; Units 1–10 both). No session is started for a lesson outside the track (`404`); records of lessons completed in another track are kept.
- **Prerequisites:** each published lesson has `prerequisite_concept_ids` from its approved plan; each concept is introduced by exactly one lesson (`concepts.introduced_by_lesson_id`). A prerequisite concept is satisfied when its introducing lesson is `completed` or that lesson's unit is `completed`/`skipped`. Publication validators guarantee that prerequisites are introduced by already published lessons at earlier curriculum positions within every track the lesson serves, so the recommended path is always feasible.
- **Lesson state:** `completed` when a `lesson` session for that canonical lesson is finished (no pass threshold; any track, entry surface or variant); otherwise `in_progress` if a session is active; otherwise `locked` if any prerequisite is unmet, with `soft_lock` = the unmet prerequisites' introducing lessons in curriculum order plus `start_with`, the first lesson reached by following unmet prerequisites transitively (earliest curriculum position first) whose own prerequisites are met; otherwise `available`. There is no sequential unlocking and no lesson-skip action.
- **Standalone eligibility:** `standalone_eligible` comes from the approved plan; it requires empty prerequisites (validator). Discover lists these lessons from the journey response.
- **Unit state:** `in_progress` once any of its sessions started; `completed` when all lessons are completed **and** the unit test passed; `skipped` when the unit test is passed while not all lessons are completed (`skipped` behaves as completed, including for the prerequisites its lessons introduce); otherwise `available` if any lesson can be opened, else `locked`. Units never wait for the previous unit. `coming_soon` units stay `locked`, list no lessons and are never recommended.
- `SessionResult.unlocked` lists lessons whose last unmet prerequisite this finish satisfied (and units that became available).
- `unit_test.can_skip = true` iff unit not completed/skipped and not `coming_soon`.
- `current` = the planner's target (unit and lesson if any).
- Journey units return `art_key` and `has_guide`; `GET /units/{unit_id}/guide` serves the stored `guide` in the learner's language and track framing (sentences with term spans and sources, contract §6.3). The number of units is data-driven; nothing assumes three units or specific ids.

### 6.2 Session composition
| Kind | Items | Feedback | Exercise pool |
|---|---|---|---|
| `lesson` | Published lesson version blocks for (language, learner's track variant), exercise blocks resolved to learner-facing `Exercise` objects; identical whether opened from the Roadmap or Discover | `immediate` | The lesson's own exercises (purpose `lesson`) in authored order |
| `review`, `mode: cards` | up to 12 `flashcard` exercises (fewer allowed; see §7.4) | `immediate`, `time_limit_ms=null` | Flashcards of due concepts, then lowest-mastery practiced concepts (§7.4); none → `409 nothing_to_review` |
| `review`, `mode: quick` | 10 exercises (fewer if not enough) | `immediate`, `time_limit_ms=20000` | See §7.4 selection |
| `pretest` | `min(8, pool)` exercises; requires pool ≥ 6 | `none` | Unit exercises with purpose `pretest`, shuffled, no repeats |
| `unit_test` | `min(12, pool)` exercises; requires pool ≥ 9 | `end` | Unit exercises with purpose `unit_test`, shuffled, no repeats |

- The served payload (`objectives`, `items`, `completion`, `sources`, `terms`) is stored in `sessions.items_snapshot` and returned unchanged by `GET /sessions/{id}`, so a resumed session renders the same visuals, beats, and presentations.
- **Assessment supply:** each lesson contributes 2 `pretest` and 3 `unit_test` items (§13.1), so a unit with ≥ 3 lessons has ≥ 6 / ≥ 9 items. A unit is publishable only when its pools meet those minimums (validator); items are never repeated within a session to reach a size.
- **Session fields:** `subtitle`, `lesson_version`, `counts` (`interactions` = exercise + `predict` blocks, `exercises`, `scored` = exercises with `scoring.accuracy`), `source_count` (displayed sources), and `answers` (ordered history `{exercise_id, is_retry, result, recorded_at, evaluation}`).
- **History redaction by feedback mode** (applies to `GET /sessions/{id}`, resume, reconnect, and post-finish access): `immediate` → `result` ∈ `correct`/`incorrect`/`neutral` with the stored `evaluation`; `end` → `result: hidden`, `evaluation: null` while active, real results after finish; `none` → always `hidden`/`null`. `hidden` is a presentation state only: private grading, scoring, and adaptation use the stored `correct` unchanged.
- **Version pinning:** each session records `lesson_version_id` and the `{exercise_id, version}` pairs it served. Answers are graded against the **immutable `exercise_versions` row** that was served (answer key, feedback, misconception mapping, scoring); publishing a new lesson or scene version never changes an active session's content, assets, or correctness. New sessions use the current version.
- Lesson sessions include the lesson version's `objectives` and `completion` for the language/variant; `review`, `pretest`, and `unit_test` sessions return `objectives: []`, `completion: null`, `mode` (review only), and exercise blocks only.
- `GET /lessons/{id}` returns the same `objectives`, blocks (minus exercises), and `completion`.
- `sources` = all sources referenced by blocks and exercises in the session (including story `origin.source_ids`); `displayed=true` exactly for counted sources, with `display_role` `content` (≤ 3 distinct) or `activity` (recitation sources); `source_count` = content + activity (4 for the Salah reference). There is no cap on the total of displayed sources beyond these two rules.
- Shuffling (items, steps, word banks, right columns) happens at serve time and is stored in the snapshot; ids are opaque.
- `terms` = TermCards for every `term_id` appearing in any span of the session, with the learner's current `state` and `level` (§7.6). Project `arabic` unchanged from the canonical stored glossary record into Session, glossary list/detail and Raqeeb TermCards. Keep `text`, `transliteration` and `arabic` independent. `project_term` in `contract/display_fields.py` demonstrates the shared projection; intermediate definitions fall back to basic when the stored intermediate value is null.
- Variant choice: `explorer` or `new_muslim` from the learner's track. A missing New Muslim variant falls back to the Explorer variant (its attributed framing is safe for everyone); an Explorer is never served a New Muslim variant, so a shared lesson without an Explorer variant cannot publish. Exercises have one wording per language for both tracks. The entry surface (Roadmap/Discover) is not an input.
- **Access check on `POST /sessions` (lesson):** lesson published and in the learner's track, else `404 not_found`; no unmet prerequisite, else `409 prerequisite_unmet` with `details.prerequisite_lesson_ids` and `details.start_with_lesson_id`. An existing active session is returned first (it may have started before a track change).
- Exercises of type `recite_verse` and `flashcard` are excluded from `pretest`, `unit_test`, and duels.
- One active session per (user, kind, lesson/unit, review mode), enforced by a partial unique index on active sessions: starting another returns the existing active one with `200`. The session stores `language` and `variant` at creation; later profile or header changes never re-render it.

### 6.3 Answer evaluation (deterministic, no LLM)
Implement one evaluator per type using `answer_key`:

| Type | Correct when |
|---|---|
| `multiple_choice`, `spot_error`, `which_evidence`, `scenario`, `verse_meaning` | selected id equals key |
| `map_place` (`hotspots` or `map_pins`) | `pin_id` equals key; `{ "unavailable": true }` → `correct=null` |
| `true_false_reason` | `value` and `reason_option_id` both equal key (`details.value_correct`, `details.reason_correct`) |
| `true_false` (duel) | `value` equals key |
| `match_pairs` | all pairs equal key set (`details.pair_results`) |
| `fill_blank` | every blank equals key (`details.blank_results`) |
| `categorize` | every assignment equals key (`details.item_results`, one entry per item) — validation below |
| `order_steps`, `timeline_order` | order equals key (`details.first_wrong_index` / `details.event_dates`) |
| `flashcard` | `rating != again`; `correct_answer = null` |
| `recite_verse` | referenced `recitation_checks.passed` (must belong to the same user and match the served exercise's surah, ayah, `word_start`, `word_end`, and `checked_text_sha256` — a check of a different range of the same ayah is rejected with `409 recitation_check_mismatch`); `{skipped:true}` → `correct=null` |
| any, `answer = null` (timeout) | incorrect |

- **`categorize` answer validation** (before grading; failures → `400 validation_error` with `details.reason`): every `item_id` and `category_id` must belong to the exercise; each item assigned exactly once (no duplicates, no missing items); per-category count ≤ `capacity` when `capacity` is non-null. For `presentation = day_arc` this means exactly one item per slot. `answer: null` (review timeout) skips validation and is incorrect.
- For `feedback_mode=immediate` return the full `AnswerEvaluation`; for `none`/`end` return `{exercise_id, recorded:true}`. `correct_answer` and `details` are never returned in `none`/`end` modes (the unit test returns them later in `review_items`).
- `details` for `scenario` includes `option_feedback` for the chosen option; for `map_place` includes `pin_labels`.
- **Attempt identity** (unique index on `session_id`, `exercise_id`, `is_retry`). **Attempt identity = (`session_id`, `exercise_id`, `is_retry`).** Exactly two identities can exist per exercise: the original and the retry. Any request whose identity is already recorded is a **replay**: the server returns the stored response the feedback mode allows, applies no mastery/FSRS/misconception/quest/XP change, records nothing, and **ignores the request body** (a different `answer` for a recorded identity is not re-graded; it is logged for diagnostics only). Because a retry request for an exercise whose retry is already recorded has a recorded identity, it is always a replay — there is no "second retry" outcome. `409 retry_not_allowed` applies only to a retry request whose identity is **not yet recorded** and which is ineligible: no first attempt yet, a first attempt that wasn't `incorrect` (correct, neutral, or hidden-mode), an excluded type (`recite_verse`, `flashcard`), or a non-lesson session. Check order: (1) recorded identity → replay; (2) otherwise eligibility/order checks; (3) otherwise grade and record.
- **Retry eligibility** (lesson sessions only): for a retry identity not yet recorded: the exercise has an `incorrect` first attempt and is not `recite_verse`/`flashcard`; otherwise `409 retry_not_allowed`. The once-each rule counts a retry as used whatever its outcome — later retry requests replay it.
- **Authored order:** a first attempt is accepted only when every earlier exercise block in the served items already has a first attempt; otherwise `409 out_of_order`. (Recovery stays defensive against gaps; see §18.1.)
- Fresh attempts on a finished session → `409 session_finished`; on an abandoned one → `409 session_not_active`. Recorded identities still replay after finish (API §6.5 processing order).
- Every answer calls the adaptive engine (§7) unless `is_retry=true` (retry: correct → small mastery gain, wrong → no change; no misconception activation; no XP).
- **`correct = null`** (skipped recitation, unavailable map) is stored but excluded from score denominators, accuracy, layers, `lesson_perfect`, mastery, FSRS, misconceptions, retries, and quest counters; the step still counts as completed.
- `predict` blocks are never sent to the server and have no evaluation. `framing` doesn't affect grading.
- `scoring` is read from the served exercise version: checker correctness is always computed and returned; `scoring.accuracy` decides whether the answer enters accuracy/score/layers/`lesson_perfect`; `scoring.combo` is informational for the client combo. `recite_verse` is always `accuracy: false, combo: false, layer: null`.

### 6.4 Finish
`POST /sessions/{id}/finish` computes `SessionResult` exactly as in contract §6.5, in the single finish transaction described under "Transactions and effects" above. It stores the result on the session (`result_snapshot`) and replays it unchanged for every later finish call. It requires a first attempt for every served exercise (`409 out_of_order` otherwise) and clamps `duration_ms` as in API §6.5.
- `score` over graded first-attempt answers (`correct` true/false) of exercises with `scoring.accuracy = true`. `tools/validate.py` recomputes the contract's finish example from its session and answer history; the backend's finish logic must produce the same numbers.
- `duration_ms`: echo of the request value (stored on the session).
- `layers` (response keys `understanding`, `applying`, `remembering`): over graded first attempts of exercises with `scoring.accuracy = true`, input layer `understand` → `understanding`, `apply` → `applying`; each `{correct, total, percent}` or `null` if none. `remembering` is always `null` in this revision; `remember`-layer exercises count in accuracy only.
- `lesson_perfect` requires at least one **accuracy-counted (`scoring.accuracy = true`), graded (`correct` true/false) first attempt**, with all such attempts correct. The `score` denominator counts graded first attempts, so a skipped/unavailable eligible exercise lowers it below `counts.scored`.
- Quest progress and achievement counters are updated (§10.6–§10.7); completed quest rewards appear in `xp.breakdown` as `quest_complete`.
- `passed` for `unit_test` (≥ `pass_percent`).
- `review_items` for `unit_test` only.
- FSRS updates per concept (§7.4), term state promotions (§7.6), XP (§10.1), streak and daily goal (§10.2), unlocks, `next_step`.
- For `pretest`: store `learner_units.pretest_percent`. For the first `unit_test` taken after all lessons are completed: store `first_post_percent` (used by metrics; skip attempts don't count as post-tests).

---

### 6.5 Visual registry and presentation validation
`content/visual_registry.yaml` mirrors contract §5.5c (keys, versions, params) and §5.5d (proportion per use). Rendering, loops, mirroring, and labels are Flutter's; the backend needs the uses only to author and validate pins.
```yaml
keys:
  river_house:
    versions: [1]
    params: { beat: { type: int, min: 0, max: 3, required: true } }
    description: "House with palms and a flowing river. beat 0 establishing view; 1 the river as the parable's focus (places and light only, no people); 2 clean-light sparkles; 3 five prayer lights."
  workplace:
    versions: [1]
    params: {}
    description: "Office with an illustrative wall clock near 12:10 and steam from a cup."
  day_arc:
    versions: [1]
    params: { highlight: { type: int, min: -1, max: 4, required: true } }
    description: "Sun's path through the day; highlight -1 none, 0..4 dawn, midday, afternoon, sunset, night."
  pillars:
    versions: [1]
    params: { highlight: { type: int, min: 0, max: 4, required: true } }
    description: "Five pillars with localized labels drawn by Flutter; highlight in canonical order 0 shahada, 1 prayer, 2 zakat, 3 fasting, 4 Hajj."
uses:            # width / height per use (contract §5.5d)
  hook: 1.75
  story_beat: 1.5
  teach: { river_house: 1.9, pillars: 1.9, workplace: 1.9, day_arc: 2.1 }
  map_place_hotspots: 1.15
  categorize_day_arc: 2.8
  visual_block: 1.75
  predict: 1.75
```
Validators (run on factory output, gold import, and publish; failures block publishing):
- **Visual:** `kind=builtin` → registered key, supported version, params exactly per schema (no extra keys), `image=null`, and the key has a proportion for the block/exercise use it appears in; `kind=image` → `image` with `url`, `mime_type` ∈ {`image/webp`, `image/png`, `image/jpeg`}, positive `width`/`height`, and `key/version/params=null`; `alt` non-empty in both languages; overlays reference medallion assets that exist.
- **Teach:** `style` ∈ {`standard`, `summary`}; `eyebrow` null or non-empty; 1–5 points. State validation **dispatches by `visual.kind`**: `builtin` → registry params; `scene` → the manifest's declared states (initial `params` and every merged state after each point); `image`/`null` → `visual_params` must be `null`. `visual_params` is always `null` for `style: summary`.
- **Story:** non-empty `label`; ≥ 1 beat, `beat_index` contiguous from 0, each beat has a `visual`; `quote_meaning` only when `quote` is non-null. A sourced story has `origin` (`source_ids` non-empty, `show_card` boolean), `provenance` (if set) referencing a story source, and quotes following factory §13.2. A teaching scenario has `origin`, `provenance` and every `quote` null and only non-assertive narration sentences (factory §13.2). The block sits in a `story` or `scenario` arc step. Narration audio is optional and never autoplays.
- **Hook:** a real-life, contemporary situation and a curiosity question that the lesson answers; no religious claims in the hook (if any, they need claims and sources like any sentence). Optional `cta`.
- **Predict:** an ungraded curiosity question before the explanation; 2–4 options that are plausible guesses, none marked correct; a non-empty neutral `reveal` whose factual sentences are linked to claims; no answer key exists for it.
- **Map pins:** 3–6 pins; 0 ≤ `x_pct`,`y_pct` ≤ 100; `radius_pct` null or in (0, 25]; `presentation: hotspots` requires every pin `label` non-null and a `builtin`, `image`, or **`scene`** visual. Scene hotspots additionally require `anchor_id` on every pin, the pin inside that anchor's radius (view-box coordinates), anchors that pass the stability check (§13.8), and `visual.fallback_params == visual.params`. `interaction` (contract §7.12): bindings reference distinct existing pins; every `set` and `after_evaluation` state is valid for the visual (registry or manifest); `null` for image maps. Pins on built-in scenes are authored in that use's proportion (`map_place_hotspots` = 1.15).
- **Publication gate and readiness (pre-generation audit):** publishing a lesson version requires `contextual.placeholder_media_errors` to be empty (no reserved example host, `mock-asset://` or non-https URL anywhere) and every draft visual's `contextual.visual_readiness` to be `compiled` or `audited` (factory §13.4).
- **Generated images** are stored as WebP (PNG/JPEG accepted on import); the object store sets `Content-Type` to the stored `mime_type`; scene illustrations 1600×1000, maps 1600×1200.
- **Scene visuals (`kind: scene`):** manifest passes `contract/scene.schema.json` and `tools/scene_check.py` (capabilities declared = used, all `released`; limits; state references and ranges; palette; anchor stability; anchors inside the view box; asset checksums/sizes); `Visual.params`, `fallback_params`, and every beat/`visual_params`/binding state are valid for the manifest's declared states; `fallback_image` is present with the view box's proportion and was rendered at `fallback_params`; the referenced `scene_versions` row is `published` (or, in a draft, `draft` from the same run).
- **Scoring:** `scoring.accuracy`/`combo` booleans and `layer` ∈ {`understand`, `apply`, `remember`, null}; `recite_verse` must be `false/false/null`.
- `tests/contract/test_registry_parity.py` fails if the YAML and contract §5.5c (keys, versions, params) or §5.5d (**per-use** proportions) disagree.

## 7. Adaptive engine

### 7.1 Concept mastery
Per (user, concept), `mastery ∈ [0,1]`, initial `0.0`, computed in **decimal arithmetic** (Python `Decimal`, PostgreSQL `numeric(7,6)`) and stored at 6 decimal places — binary floats would turn 0.545 into 0.5449… and round the wrong way. For every evaluated answer (first attempts, plus the retry and recitation rows below), for each concept in `exercise.concept_ids`, apply in submission order:

| Event | Update |
|---|---|
| correct | `m ← m + 0.35 × (1 − m)` |
| incorrect / timeout | `m ← m − 0.25 × m` |
| flashcard `hard` | `m ← m + 0.15 × (1 − m)` |
| recitation passed | `m ← m + 0.15 × (1 − m)` |
| recitation skipped, or checked but not passed | no change (practice, not assessment) |
| pretest answers | half weight (0.175 / 0.125) |
| retry correct | `m ← m + 0.10 × (1 − m)` |
| retry incorrect | no change |

Mastered: `m ≥ 0.8`. Learning: `0 < m < 0.8`. Responses report values **rounded half-up to 2 decimals** (e.g., 0.545 → 0.55); computations always use the stored 6-decimal value.
- `AnswerEvaluation.mastery_changes`: before/after of **that** answer, stored with the evaluation snapshot and replayed unchanged.
- `SessionResult.mastery_summary`: per practiced concept, the value at **session start** and at **session end** after all of the session's updates (first attempts, retries, recitation). Example (contract §6.5): 0.20 → 0.48 → 0.558 ≈ **0.56**; 0.40 → 0.30 → 0.37.
- `tools/validate.py` recomputes every evaluation's mastery change and the §6.5 summary from these formulas.

### 7.2 Misconceptions
- Exercise options may map to a misconception (`option_misconceptions`); exercises may target one (`targets_misconception_id`).
- Evidence: choosing a mapped option → `+1.0`; answering incorrectly an exercise that targets a misconception → `+0.5`.
- Activation at `evidence_score ≥ 1.0` → `status=active`, `correct_streak=0`, return `misconception` in the evaluation (title + card + sources).
- If already active and the learner again chooses a mapped option → return the card again; reset `correct_streak`.
- Resolution: each correct answer on an exercise that targets the misconception or maps it in its options → `correct_streak += 1`; wrong → `0`; at `3` → `status=resolved`.
- Surface in `SessionResult.misconceptions.activated/resolved`, `/me/stats`, and metrics.

### 7.3 Next-step planner (`GET /journey/next`, onboarding, session finish)
Evaluate in order; return the first match:
1. **Current unit** = the first unit (by index) of the learner's track path that is not `completed`/`skipped` and not `coming_soon` (Explorer `0,1,2…`; New Muslim `1,2,…`; Unit 0 is not in the New Muslim path). If its pretest isn't taken and none of its lessons is completed yet (lessons may already be done through Discover) → `pretest` (`new_unit_pretest`).
2. Due concepts (FSRS `due_at ≤ now`, mastered or learning) count ≥ 5 → `review` (`due_reviews`).
3. First `available`/`in_progress` lesson in curriculum order in the current unit → `lesson` (`next_lesson`). Completed lessons, including those finished through Discover, are passed over; if every remaining lesson of the unit is locked, recommend the `soft_lock.start_with` lesson of the first one.
4. All lessons completed and unit test not passed → `unit_test` (`unit_ready_for_test`).
5. Next unit is `coming_soon` or none → `journey_complete` (`all_done`); otherwise loop to step 1 with the next unit.
`due_reviews_count` is always populated. `title` = lesson title, or a localized label for pretest/review/unit test.

### 7.4 Spaced repetition (FSRS) and reviews
- One FSRS card per (user, concept), created when the concept is first practiced.
- At session finish, per concept practiced (non-retry answers): any wrong → `Again`; all correct with average `elapsed_ms` < 6000 → `Easy`; all correct otherwise → `Good`; a flashcard rating maps directly (`again/hard/good/easy`) and overrides for that concept. Pretest answers don't update FSRS.
- **Card review (`mode: cards`, default):** up to 12 `flashcard` exercises: due concepts first (by `due_at`, then lowest mastery; active misconceptions first), then lowest-mastery practiced concepts; fewer than 8 is a valid smaller deck; if the learner has no practiced concept with a flashcard → `409 nothing_to_review` and the planner never recommends a review. Untimed; ratings map directly to FSRS. Every concept taught in a lesson has ≥ 1 flashcard (§13.3).
- **Quick review (`mode: quick`) selection:** concepts with `due_at ≤ now` ordered by `due_at`, then lowest mastery; pick up to 10 exercises from those concepts (purpose `lesson`, excluding `recite_verse`, `map_place` on built-in scenes, and `categorize` with `presentation: day_arc`, which are not suited to the 20 s timer), prioritizing exercises that target the learner's **active misconceptions**, then exercises not answered in the last 24 h. If fewer than 3 due concepts exist, fill with lowest-mastery practiced concepts.

### 7.5 Level
`level = basic` if the learner has 0 completed/skipped units and fewer than 8 mastered concepts; otherwise `intermediate`. Used to choose TermCard definitions and by the level service.

### 7.6 Personal glossary (term states)
- `new`: never shown to the learner.
- `learning`: appeared in a finished session or its card was opened (`POST /glossary/{id}/opened` increments `opened_count`).
- `mastered`: linked concept mastery ≥ 0.8 **and** `exposures ≥ 2` (exposures = finished sessions containing the term).
- Promotions happen at session finish; report newly mastered terms in `terms_mastered`.
- `GET /glossary` returns terms with state ≠ `new`, filterable by state.

### 7.7 Level service ("explain at your level") — shared by Raqeeb
`level_service.adapt(core_blocks, citations, learner_profile, language) -> blocks, terms`
- `learner_profile` = `{ level, track, language, known_terms: [texts of learning+mastered terms], active_misconceptions: [titles] }`, read from the adaptive engine tables.
- Step 1 — rewrite (fast model): rewrite `paragraph` spans for the level; keep every `citation` span attached to the same claim; do not add facts; unknown technical words that are not in `known_terms` get a short inline definition; if an active misconception is relevant, address it gently using only the provided core content.
- Step 2 — term linking (code): find glossary terms (by exact/normalized text) in the rewritten text and convert them into `term` spans; attach TermCards (learner's state/level) to `terms`.
- Step 3 — check (fast model, separate prompt): compare core vs adapted claims; if any new claim or changed meaning → discard the rewrite and return the core blocks (still with term linking).
- `evidence`, `verification`, `differing_views` (holders and sources), and `referral` blocks are never rewritten except `note`/`reason` spans for readability.

---

## 8. Recitation service (contract §6.6)

Synchronous for the client; target p95 < 6 s for a 10 s clip (to be measured, O-03).

**Isolation (rev 10):** CPU-bound decoding and ASR never run in the API process. Running them there would stall every request and every live challenge task on that event loop. The API validates the upload, then sends the audio bytes to a dedicated `asr` worker pool (Celery queue `asr`, one model instance per worker process, `prefetch=1`, concurrency = physical cores) and awaits the result for at most 15 s. If the queue is longer than a configured bound or the wait times out, it responds `503 upstream_unavailable` with `details.retry_after_ms`, and the client offers retry or skip. Audio stays in memory or temporary storage on the worker and is deleted when the job ends, even on failure. Only the check result is persisted. Size the pool from measured throughput (O-03).

1. Validate type/size/duration (signature and decoded duration, API §3.7); convert with ffmpeg to 16 kHz mono WAV, with ffmpeg restricted to the needed demuxers/decoders and no network protocols.
2. ASR: faster-whisper with `tarteel-ai/whisper-base-ar-quran` (CTranslate2 int8), `language="ar"`, `beam_size=5`, `vad_filter=True`. Load the model once per worker process. Model and license are unverified proposals (O-03).
3. Unclear: no speech segments, or empty text, or mean `avg_logprob < -1.0` → `status=unclear`, `passed=false`, empty `words`.
4. Expected words: from the local mushaf text (§12.1) for (surah, ayah), split on spaces, excluding waqf/ayah-number marks; when `word_start`/`word_end` are sent, only that 1-based inclusive range (validated: 1 ≤ start ≤ end ≤ word count, else `400 validation_error`). Response word `index` values are 0-based within the checked range.
5. Normalize both sides (same function as §12.1 `normalize_ar`).
6. Align words with dynamic programming (edit distance over tokens) where two tokens match if `rapidfuzz.fuzz.ratio(norm_a, norm_b) ≥ 80`. Backtrace → `correct`, `substituted` (`heard` = ASR token), `missing`, `extra` (`expected=null`).
7. `passed = missing == 0 and substituted == 0` (extra words allowed but shown).
8. `audio_segment`: from reciter word timings for that ayah (or segment clip) if available, else `null`. For segments, the reciter clip and `audio.words` served in the exercise cover exactly the segment (cut from the ayah audio using word timings at publish time).
9. `message`: localized templates (no LLM) chosen by outcome: all correct / some errors / unclear.
10. Persist to `recitation_checks` with `word_start`, `word_end`, and `checked_text_sha256`; referenced later by the session answer `{check_id}` and verified against the served exercise (§6.3).

---

## 9. Raqeeb (contract §6.8)

### 9.1 Request handling
- `POST …/messages`: validate limits (contract §3.7), store attachments in object storage, create the user message (`status=received`) and the assistant message (`status=processing`, `stage=received`), enqueue `raqeeb.process_message`, return `202`.
- `GET /raqeeb/messages/{id}`: return the current state. While processing, return only the processing fields shown in the contract.
- Update `stage` in the DB at each pipeline step. Overall timeout 75 s → `failed` with `upstream_unavailable`, `internal_error` or `input_unreadable` (corrupt, encrypted or unparseable attachment). The task is idempotent per `message_id` and acknowledged late. If a worker dies, redelivery resumes or restarts the message; a periodic sweeper marks any message still `processing` after 90 s as `failed` (`internal_error`), so polling clients always terminate.
- **Untrusted input (prompt injection):** user text, transcripts, image/document text and retrieved source text are data, never instructions. Pass them to models inside clearly delimited data fields with a system instruction to ignore embedded directives. Tool calls are chosen only by the class strategy (§9.3) from an allow-list, never by content. No model output can change grading, publication, routing class guards or referral targets. The guard (§9.4) runs on every answer, whatever an attachment claims.
- Conversation `title`: after the first completed answer, generate ≤ 6 words (fast model) in the conversation language.
- Conversation history: pass the last 6 messages (text + understood inputs + final answer text) to the classifier and writer for follow-up questions.

### 9.2 Pipeline
| Stage (`stage`) | Step |
|---|---|
| `reading_inputs` | **Audio** → ffmpeg → STT provider → `understood_input.transcript`. **Images** → vision extraction (fast model) → `{extracted_text, description}` per image. **Document** → DOCX: `python-docx` paragraphs; PDF: `pdfplumber` text of the first 20 pages; if extracted text < 200 chars, render the first 5 pages with `pypdfium2` and use vision extraction; truncate to 30,000 chars (`truncated=true`); 3-sentence `summary` (fast model). The **question** = text + transcript; the **material** = extracted image/document text. |
| `classifying` | (1) **Safety rules first** (`content/safety_rules.yaml`, ar/en regex/keyword lists: self-harm, suicide, abuse, threats, coercion). Match → `sensitive_human`, skip the LLM classifier. (2) Fast-model classifier → JSON `{question_class, confidence, language, quotes: [{text, kind_guess: quran/hadith/claim}], retrieval_queries: [..], concept_hint, standalone, canonical_question}` (`standalone` = answerable without earlier turns; `canonical_question` = de-personalised restatement used only for memory). Low confidence (< 0.6) on a sensitive or fatwa-like boundary routes to the more protective class. If material contains quotes and the user asks about correctness/meaning of them → `verification`. |
| *(memory)* | **Guarded reuse (rev 10; replaces the plain ≥ 0.92 rule).** Eligible only for `general_knowledge`/`text_explanation` questions with **no attachments and no dependence on earlier conversation turns** (the classifier reports `standalone: true`). Lookup key: `language`, `question_class`, current `policy_version` and prompt/source-adapter versions. A cosine similarity ≥ 0.92 (bge-m3) only nominates a candidate. Reuse requires: every cited source still resolves to the same stored text digest; a fast-model equivalence check confirms that the new question asks for the same thing (low effort, structured verdict); and the guard passes on the adapted result. Otherwise run the full pipeline. Memory stores the classifier's canonical, de-personalised question and the core answer, never raw user text or attachments, and keeps `origin_user_id` only so account deletion can purge it. Rows expire when a cited source, policy or prompt version changes. Record false-reuse checks in the benchmark (§16). |
| `retrieving` | Class strategy (§9.3) using the tool layer (§12). Collect candidate evidence with verbatim text and references. |
| `verifying` | Strong-model verifier (separate prompt from the writer): for each candidate claim the writer may make, decide `supported` against retrieved texts; hadith grades and Quran matches come from code (§12), not the model. Unsupported claims are dropped. |
| `writing` | Strong-model writer produces **core** `blocks` + `citations` as JSON (schema = contract `AnswerBlock` + `citations`) using only supported claims. Every factual sentence carries ≥ 1 `citation` span. |
| `adapting` | Level service (§7.7) with the learner profile. |
| `done` | Guard (§9.4) → persist → `status=completed`. Save `core` to memory for eligible questions (see memory row) when not abstained. `suggested_lessons`: up to 2 published lessons of the learner's track whose outcomes/titles embed with similarity ≥ 0.6 to the question (opening one follows the normal access rules). |

### 9.3 Strategies per class
| `question_class` | Retrieval | Output | Abstain / refer |
|---|---|---|---|
| `general_knowledge` | Tafsir (Mukhtasar first), HadeethEnc, IslamHouse articles; Quran search | `paragraph` (+ at most 1 `evidence`) | If < 1 supporting source → `abstained=true` + `referral(specialist)` |
| `text_explanation` | Identify the text: Quran (mushaf match / Quran search) or hadith (Dorar). Explanation **only** from tafsir (Mukhtasar, Sa'di) or hadith sharh (HadeethEnc/Dorar) | `evidence` of the text + `paragraph` explanation | If the text can't be identified → abstain + `specialist` |
| `verification` | For each quote: Quran → mushaf exact match, else fuzzy (§12.1); hadith → Dorar search, verbatim grade + grader + book, alternative authentic hadith via Dorar alternate tool when weak/fabricated; claim → IslamHouse fatwas/articles search | `verification` block (one item per quote) + optional short `paragraph` | Claims without direct sources → item `needs_specialist`. Hadith with no Dorar match → `not_found` (never "fabricated") |
| `differing_opinions` | IslamHouse fatwas/articles in the user's language | `differing_views` (attributed; the model never picks a winner) + final `referral(specialist)` | If fewer than 2 attributable views → abstain + `specialist` |
| `personal_fatwa` | None | `referral(fatwa_authority)` only | Always `abstained=true` |
| `doubt_or_deep_creed` | Published responses on IslamHouse; tafsir for cited verses | `paragraph` from published responses | If no adequate published response → abstain + `specialist` |
| `sensitive_human` | None | short supportive `paragraph` (template, localized) + `referral(human_support)` | Always `abstained=true` |
| `out_of_scope` | None | short localized `paragraph` explaining what Raqeeb helps with | `abstained=true` |

Referral targets come from `content/referrals.yaml` (per type and language). The fatwa authority entry is the General Presidency of Scholarly Research and Ifta (`https://www.alifta.gov.sa`).
Class `label` values are localized strings from a static map.

### 9.4 Guard (code + fast model)
Reject and regenerate once (then fall back to abstain + `specialist`) if:
- a `paragraph` in an answering class lacks any `citation` span;
- a `citation.ref` doesn't exist in `citations`;
- a verification item has a grade not taken from Dorar output, or `not_found` is labeled as fabricated;
- the text gives a personal ruling ("you must/you are allowed" addressed to the user's situation) outside quoting a source;
- Quran text in `evidence` differs from the mushaf text.

### 9.5 Output mapping
Persist and return exactly the contract's completed `Message`: `understood_input`, `classification {question_class, label}`, `abstained`, `blocks`, `citations [{ref, source}]`, `terms`, `suggested_lessons`, `feedback`. `sources` created during answering are upserted into `sources` for reuse.

---

## 10. Community (contract §6.9)

### 10.1 XP (fixed table)
| Reason | XP |
|---|---|
| `lesson_complete` | 10 |
| `lesson_perfect` (≥ 1 accuracy-counted graded first attempt, all of them correct) | 3 |
| `recitation_passed` (once per exercise per session; returned in the evaluation) | 3 |
| `review_complete` | 8 |
| `pretest_complete` | 5 |
| `unit_test_passed` | 20 |
| `duel_win` / `duel_draw` / `duel_loss` | 15 / 8 / 4 |
| `group_rank_1` / `group_rank_2` / `group_rank_other` | 15 / 8 / 4 |
| `daily_goal_met` (once per local day) | 2 |
| `quest_complete` | the quest's `reward_xp` |

Write each grant to `xp_events` with `week_key` and `local_date`.

### 10.2 Streak and daily goal
- Local day = user's `timezone` at the time of the event; `daily_activity.local_date` and `xp_events.local_date` are stored and never recomputed after a timezone change. A day **qualifies** when at least one session or duel is finished. `daily_goal_met` is granted at most once per stored local date (unique key).
- `current` streak = consecutive qualifying days ending today (or yesterday if today not yet qualifying); computed from `daily_activity`. `longest` = max historical run.
- `minutes_today` = sum of finished sessions' `duration_ms` (each capped at 20 min) + finished duel durations, in minutes.

### 10.3 Leagues
- `week_key` = ISO year + week starting **Sunday 00:00 Asia/Riyadh**.
- On a learner's first XP of the week, assign to a league of that week and tier with < 20 members (create if none), under a per-(`week_key`, `tier_key`) advisory lock so concurrent first-XP events cannot overfill a league. Rank by `xp_week` desc, ties by earlier last XP time. The week-end promotion job is idempotent per `week_key` (unique job record).
- **Tiers:** every learner has a tier (`learner_tiers`, starts at index 0). Leagues are formed per (`week_key`, `tier_key`). At week end (beat job at Sunday 00:00 Asia/Riyadh), the top `promotion_zone_size` ranks move up one tier; **no demotion**; the top tier keeps its members. `GET /leagues/current` returns `tier`, `promotion_zone_size`, `demotion: false`, and `in_promotion_zone` per member. Tier names (ar/en) and zone sizes are seeded from the prototype's `community_screen.dart`.
- **Privacy:** members with `private_profile=true` are returned to other users with a generic localized name ("مسافر" / "Traveler") and the default `avatar_key`; their own view is unchanged.
- **Synthetic members** (`is_synthetic=true`, seeded; §15) fill leagues to 20 and gain XP through a beat job every 30 min following seeded activity profiles, so leagues look populated during demos. They are indistinguishable in the API. **Production use is a pending product decision ([P-01](../00_REVIEW/STATUS_AND_OPEN_DECISIONS.md)):** presenting undisclosed simulated people as competitors conflicts with the product's honest, respectful positioning. Default: `SYNTHETIC_LEAGUE_MEMBERS=false` in production and enabled only in demo/staging. Synthetic users never receive friend requests or challenges and are excluded from all metrics.

### 10.4 Friends
- Invite code `QBS-` + 4 chars (Crockford base32), single use, valid 7 days, `share_text` localized. Codes are unique among unexpired invites (regenerate on collision). The 4-character space (~10⁶) is guessable, so `POST /friends/invites/accept` allows at most 10 failed codes per user per hour and 100 per address per day (`429`). Lengthening the code is a UX decision that stays open.
- Accept creates a mutual friendship; errors `invite_invalid`, `already_friends`.
- `online` = `last_seen_at` within 60 s (WebSocket pings also update it).
- Friends with `private_profile=true` are returned with `xp_week: null` and `streak_current: null`.

### 10.5 Activity calendar (`GET /me/activity`)
From `daily_activity` in the learner's `timezone`: range `from`/`to` (≤ 62 days, default last 35 days), qualifying days only, with `minutes` and `xp`, plus the streak summary (§10.2).

### 10.6 Daily quests (`GET /me/quests`)
- Three quests per learner per local day, created lazily on first request or activity of the day (unique (`user_id`, `local_date`, `slot`); a concurrent creator re-reads); chosen deterministically (hash of user id + date) from the pool `earn_xp`, `complete_lessons`, `perfect_lesson`, `complete_review`, `win_challenge`, `recite_verse`, with at most one of each kind.
- Goals: `earn_xp` = 3 × `daily_goal_minutes`; `complete_lessons` = 1 (5–10 min goals) or 2 (15–20); others = 1. Rewards: 10 XP, `perfect_lesson` and `win_challenge` 15 XP. Titles are localized templates.
- Progress is updated on the same events that write `xp_events`, session finishes, and challenge results (`correct: null` answers and `predict` never count). When `progress ≥ goal`, set `completed_at` and grant `quest_complete` once.

### 10.7 Achievements (`GET /me/achievements`)
- Seeded definitions (`achievements`) mirror the prototype's achievement set (keys, titles, targets). Each has a `counter` from: `raqeeb_questions` (user messages whose assistant reply reached `completed`; one per user message; `failed` replies, feedback, and polling never count — the "Ask Raqeeb 5 questions" badge), `lessons_completed`, `units_completed`, `longest_streak`, `terms_mastered`, `misconceptions_resolved`, `challenges_won`, `recitations_passed`, `reviews_completed`, `perfect_lessons`.
- Counters are derived from authoritative tables (`raqeeb_messages`, `learner_lessons`, `daily_activity`, `learner_terms`, `learner_misconceptions`, `duels`, `recitation_checks`, `sessions`); `learner_achievements.progress` is recomputed on the relevant events, and `unlocked_at` is set once when `progress ≥ target` (never revoked).

---

## 11. Challenges (contract §6.10, §8)

Presets (contract §6.10), each with its own `config`:
| Preset | Players | Questions | Limit | Points if correct | Result reveal |
|---|---|---|---|---|---|
| `duel` | 2 | 7 | 15 s | `100 + floor(100 × remaining ÷ limit)` | 3.0 s |
| `group` | 2–4 | 3 | 10 s | `100 + half_up(50 × remaining ÷ limit)`, `half_up(x) = floor(x + 0.5)` — Dart `.round()` for positive values, **not** banker's rounding (Python's `round(2.5)` = 2 is wrong here); 500 ms remaining → **103** | 2.2 s (prototype) |

Endpoints keep the `/duels` path; the engine is shared and parameterized by `config` (`question_count`, `time_limit_ms`, `scoring.base`, `scoring.speed_bonus`, `scoring.rounding` ∈ `half_up`/`floor`, `reveal_ms`). Use the shared `challenge_points()` from `contract/qabas_contract.py`.

### 11.1 Question selection (7 or 3, no repeats)
Pool: exercises with `duel_eligible=true` and type in `multiple_choice`, `true_false`, `verse_meaning` (the factory creates these as purpose `duel`).
1. Concepts with mastery ≥ 0.5 for **all** human players.
2. If fewer than needed: add concepts from lessons all human players completed.
3. If still fewer: the Unit 1 duel pool (the first unit shared by both tracks, so mixed-track challenges stay possible).
For the bot, use the human player's concepts only.

### 11.2 Live engine
**Durable coordinator (rev 10 baseline; O-04 approves the deployment):**
- **System of record in Postgres:** `duels` (status, phase, `coordinator_epoch`, `lobby_deadline_at`), `duel_players`, `duel_questions` (`duel_id`, `question_index`, `exercise_id`, `exercise_version`, `issued_at`, `deadline_at`, `closed_at`, `reveal_until`) and `duel_answers` (unique (`duel_id`, `user_id`, `question_index`), server `received_at`, points). Redis holds a read-through snapshot for fast `state` events plus a pub/sub channel `duel:{id}:events`.
- **One owner per live duel:** an API instance acquires `duel:{id}:owner` (`SET NX PX 5000`, renewed every second) and takes a fencing token from `INCR duel:{id}:epoch`. Every phase write is conditional (`UPDATE … WHERE coordinator_epoch <= :epoch`), so a paused or partitioned old owner cannot overwrite a successor.
- **Deadlines are data, not timers:** `issued_at`, `deadline_at`, `reveal_until` and `lobby_deadline_at` are persisted before the corresponding event is published. Local timers only wake the owner. On takeover, or when an owner restarts, the new owner reloads the duel: a past deadline closes the question at once (missing answers score 0); otherwise it re-arms for the remaining time. A beat job also scans for duels whose deadlines passed without an owner and claims them.
- **Sockets on any instance:** the instance holding a player's socket validates the ticket and writes that player's answer directly (`INSERT … ON CONFLICT DO NOTHING`, accepted only when `received_at ≤ deadline_at`). It publishes `answered` on the channel; the owner closes the question early when all connected players have answered. The owner publishes all outbound events, and every instance forwards them to its local sockets. Host clocks are NTP-synchronised; the elapsed time is `received_at − issued_at`.
- **Bot:** answers are generated deterministically from (`duel_id`, `question_index`) (seeded PRNG), so a takeover reproduces the same bot behavior.
- **Finish:** the owner ranks players and writes the result, answers summary and XP/quest grants in one transaction keyed by `duel_id` (unique result row), then emits `finished`. Achievements and league updates go through the outbox.
- **Pilot-only alternative:** a single API process owning all duels in memory is acceptable only for an explicitly approved pilot deployment (O-04). Even then, answers, deadlines and results must be persisted as above, so a restart resolves every open duel (resume or expire) instead of losing it.
- Duel snapshot also mirrored in Redis (`duel:{id}`) for reconnect `state` events.
- **Lobby:** clients may connect while `pending`; send `player_status {user_id, status}` on every join/decline and a `state` (status `ready`) when the start rule fires. REST polling of `GET /duels/{id}` remains a fallback.
- **Reconnect snapshot:** every `state` includes `live` (`phase`, `question_index`, current `question`, `deadline_at`, `answered_user_ids`, the player's own locked `my_answer`, running `totals`, `results_so_far`), built from Redis duel state so points and locks survive reconnects.
- On connect: send `state` with `server_ts`. When all joined players sent `ready` (bots auto-ready after 1 s) → `countdown` (3 s) → questions.
- Each `question`: `issued_at`, `deadline_at = issued_at + time_limit_ms`. Accept the first answer per player; timestamps are server-side. Emit `answer_received` to the answerer and `opponent_answered {question_index, user_id}` to the others; disconnect/reconnect events carry `user_id`. A second answer for the same question is ignored.
- Close the question when all connected players answered or at the deadline → `question_result` (points from `config.scoring`) → wait `config.reveal_ms` → next question.
- After the last question → rank players (points; tie → lower total elapsed of correct answers; else shared rank) → persist answers and `result` (`winner_user_ids` = all rank-1 players; `is_draw` when all players share rank 1; `rank` per player), grant XP (§10.1; every rank-1 player gets the rank-1 award), update quests and achievements, emit `finished` with `summary`, set `status=finished`.
- **Group start:** `pending` until every invitee joined/declined or 60 s passed; then start if ≥ 1 friend joined (empty seats filled by bots when `bot_fill=true`), else `expired`. A player who leaves mid-game (`player_left`) scores 0 on the remaining questions.
- Disconnect: emit `opponent_disconnected {grace_ms: 10000}`; on reconnect emit `opponent_reconnected` and send `state` + current `question`. After the grace period, the absent player scores 0 on remaining questions; the duel continues to completion.

### 11.3 Bot
`display_name` localized "المدرّب" / "Coach", `is_bot=true`. Per question: correct with probability 0.7; response time log-normal with median 6 s, clamped to [1.5 s, 14 s].

### 11.4 Friend invitations and async (duel preset)
- Friend duel: `pending`, expires after 120 s → `expired` (live). Group challenges have no async mode.
- `POST /duels/{id}/async` (inviter, allowed after the duel is pending ≥ 60 s): `mode=async`, `status=in_progress`; the invitation remains visible to the friend for 24 h.
- Async play: `async/next` issues the next question with server `issued_at`; `async/answer` scores with server-side elapsed time (≥ 15 s → 0). After both players finish 7 questions → `finished`. If the friend doesn't play within 24 h → `finished` with the inviter as winner (friend forfeits). Idempotency of `next`/`answer`, timeouts and the inviter-abandon case follow API §6.10 "Async idempotency and timing"; the 24 h close is a beat job, idempotent per duel.
- `accept` on an async duel returns it with `mode=async` so the client uses the async flow.

---
