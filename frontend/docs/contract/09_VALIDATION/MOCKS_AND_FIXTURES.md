# Mock repositories and fixture guide

**Purpose:** define mock/live equivalence, fixture coverage and mock-service behavior. Fixtures are test content, not approved production data.

The current artifacts are [382 positive model fixtures](../03_API/contract_revision10/fixtures/MANIFEST.json), [roles](../03_API/contract_revision10/fixtures/FIXTURE_ROLES.json), [coverage matrix](../03_API/contract_revision10/fixtures/COVERAGE_MATRIX.json), private grading/evaluation context and four [source-backed Session candidates](../10_REFERENCE/engineer_delivery/reply8/reference_export/README.md). The fixtures are byte-identical to the received revision 9 set except the curriculum amendment changes: the test-curriculum journeys (Explorer-only first unit, prerequisite Soft Locks, standalone lessons), the removal of the ten New Muslim variants of that Explorer-only unit, and the re-homed IDs in `workflows/ses_91ab.json`. All 382 validate against revision 10. Validate every mock file with the revision 10 models (`tools/validate.py` maps the API examples; add a manifest row for each new mock file).

Use a private mock service/repository boundary for grading; public widgets receive redacted contract responses. Never bundle answer-bearing native/gold/context files into learner assets or a public CDN. Mock assets (`assets/mocks/`, including `_mock_answer_key`) belong to a development flavor only; release builds exclude them and CI scans release bundles for them ([frontend rule 28](../04_FRONTEND/FRONTEND_HANDOFF.md)). Strip documented `_mock_*` markers before strict production model validation. Synthetic tones, unavailable audio and unpublished/reference metadata are test limitations, not playable or approved media.

Use current manifest/schema/report counts. Historical chapter labels and specimen filenames below describe behavior; old delivery ZIP/bundle instructions are excluded from this working guide. Complete missing runtime/mock/live coverage according to [quality criteria](QUALITY_AND_ACCEPTANCE.md).

## 10. Mock-first development

### 10.1 Architecture
- One repository interface per module: `AuthRepository`, `ProfileRepository`, `JourneyRepository`, `SessionRepository`, `RecitationRepository`, `GlossaryRepository`, `RaqeebRepository`, `CommunityRepository`, `DuelRepository`, `AdminRepository`.
- Two implementations each: `Mock*Repository` (fixtures) and `Api*Repository` (HTTP/WebSocket). Selected by `API_MODE`.
- Models are generated from the JSON shapes in this document (`freezed` + `json_serializable`). The same models are used by both implementations — switching to live must not touch the UI.

### 10.2 Fixtures
Create these files in `assets/mocks/` from the examples in this document (verbatim JSON):

| File | Source section | Used by |
|---|---|---|
| `auth_guest.json` | §6.1 | `POST /auth/guest` |
| `auth_reviewer.json` | §6.1 | `POST /auth/reviewer` |
| `onboarding.json` | §6.1 | `POST /onboarding` |
| `me.json` | §5.1 | `GET /me`, `PATCH /me` |
| `me_stats.json` | §6.2 | `GET /me/stats` |
| `me_concepts.json` | §6.2 | `GET /me/concepts` |
| `journey.json` | §6.3 | `GET /journey` (Roadmap; Discover is its `standalone_eligible` lessons) |
| `journey_next.json` | §5.9 | `GET /journey/next` |
| `lesson_les_u2_l1.json` | §6.4 | `GET /lessons/{id}` |
| `session_lesson.json` | §6.5 | `POST /sessions` (lesson) |
| `session_story.json` | The §6.5 `story` block wrapped in a `Session` with `lesson_type: "story"`, plus a `timeline_order` and a `map_place` (image map) exercise (§7.11, §7.12) | `POST /sessions` (story) |
| `session_salah_{ar,en}_{explorer,new_muslim}.json` (4 files) | **Generated** from `lesson_salah.dart` per Appendix A (never retyped) | Reference lesson, 1:1 parity |
| `answer_salah_*.json`, `session_finish_salah.json` | Generated alongside, per Appendix A §A.4 | Correct, incorrect, neutral, skipped/unavailable evaluations and completion for the reference journey |
| `curriculum_test/*.json` | §10.5 | Multi-unit test curriculum |
| `me_activity.json`, `me_quests.json`, `me_achievements.json`, `unit_guide_u1.json` | §6.2, §6.3 | Streak calendar, quests, achievements, guidebook |
| `group_challenge.json`, `group_ws_script.json` | §6.10, §8 | Group challenge (4 players, 3 × 10 s) |
| `session_review_cards.json` | `Session` with `kind: "review"`, `mode: "cards"`, 8 `flashcard` exercises, `time_limit_ms: null` | Card review (S21) |
| `answer_day_arc_correct.json`, `answer_day_arc_incorrect.json` | §7.6 | Day-arc evaluation |
| `session_practice_all_types.json` | A `Session` whose items contain one exercise of **each** type from §7.1–§7.14 (both `categorize` presentations, both `map_place` presentations, whole-ayah and segment recitation), plus a `predict` block and an exercise with `framing` | Exercise widget development |
| `answers_by_type/*.json` | Per §10.6 | Evaluation states per type |
| `session_review.json` | `Session` with `kind: "review"`, `mode: "quick"`, `feedback_mode: "immediate"`, 5 exercises with `time_limit_ms: 20000` | Quick review |
| `session_pretest.json` | `Session` with `kind: "pretest"`, `feedback_mode: "none"`, 6 exercises | Pretest |
| `session_unit_test.json` | `Session` with `kind: "unit_test"`, `feedback_mode: "end"`, 10 exercises | Unit test / skip |
| `answer_correct.json` | §5.8 with `correct: true`, `misconception: null`, `xp_awarded: 0` | Answers |
| `answer_wrong_misconception.json` | §5.8 | Answers |
| `answer_recorded.json` | §5.8 short form | Pretest / unit test answers |
| `session_finish.json` | §6.5 | Finish |
| `session_finish_unit_test.json` | §6.5 with `passed: true` and `review_items` | Finish (unit test) |
| `recitation_errors.json`, `recitation_pass.json`, `recitation_unclear.json` | §6.6 | Recitation |
| `glossary_list.json`, `glossary_term.json` | §6.7, §5.4 | Glossary |
| `raqeeb_conversations.json`, `raqeeb_conversation.json`, `raqeeb_post_message.json` | §6.8 | Raqeeb |
| `raqeeb_msg_general.json`, `raqeeb_msg_verification.json`, `raqeeb_msg_fatwa.json`, `raqeeb_msg_sensitive.json`, `raqeeb_msg_failed.json` | §6.8 | Raqeeb answers |
| `league_current.json`, `friends.json`, `friend_invite.json` | §6.9 | Community |
| `duel_bot.json`, `duel_invitations.json`, `duel_ws_script.json`, `duel_async_next.json`, `duel_async_answer.json` | §6.10, §8.4 | Duels |
| `admin_runs.json`, `admin_run_gate1.json`, `admin_run_gate2.json`, `admin_blind_pair.json`, `admin_metrics.json` | §6.11 | Reviewer console |

### 10.3 Mock behaviors
- **Latency:** random 300–800 ms per call.
- **Journey access:** `MockJourneyRepository` returns `409 prerequisite_unmet` (with the lesson's `soft_lock` data) when a locked lesson is started, and marks a lesson completed for every surface after its session finishes. A debug toggle switches the track to exercise the Explorer → New Muslim change.
- **Sessions:** `MockSessionRepository` evaluates answers locally against a `correct_answer` map embedded in the fixture under a mock-only key `"_mock_answer_key": { "<exercise_id>": <correct_answer> }`, returning `answer_correct.json` / `answer_wrong_misconception.json`-shaped results. Strip this key in API models (it never appears in live responses).
- **Raqeeb:** `POST` returns `raqeeb_post_message.json`; polls advance `stage` every 1.2 s through `reading_inputs → classifying → retrieving → verifying → writing → adapting`, then return the completed fixture selected by a **debug picker with all nine outcomes** (A general, B verification, C personal fatwa, D sensitive, E differing, F text explanation, G deep creed, H out of scope, and `failed`). Without a manual pick, the attachment type chooses a default (image → B, DOCX → E, PDF → G, audio → F) and otherwise A.
- **Recitation:** `MockRecitationRepository` stores each mock check by `check_id` (first attempt → errors fixture, second → pass, debug toggle → unclear). For `recite_verse`, `_mock_answer_key` is `{ "grade_by": "recitation_check" }`: the mock evaluator looks up the submitted `check_id` in `MockRecitationRepository` and returns the normal evaluation shape (`correct` = check `passed`; `{ "skipped": true }` → `correct: null`). Generic answer comparison is never used for recitation.
- **Media in mock mode:** fixture audio URLs use the scheme `mock-asset://audio/<file>.mp3`, resolved by the mock layer to bundled files in `assets/mocks/audio/` (reciter clips for the reference verses with word timings, story narration, term pronunciation). The team supplies these files with licenses recorded; `cdn.example.com` URLs are not playable and are not used in reference fixtures.
- **Challenges:** `FakeDuelSocket` also replays `group_ws_script.json` (4 players, 3 questions, 10 s; bots answer after 1–7 s).
- **Duel socket:** `FakeDuelSocket` replays `duel_ws_script.json` with realistic delays: `countdown` 1 s after `ready`, each `question` `config.reveal_ms` after the previous `question_result` (3000 ms duel, 2200 ms group), bot `opponent_answered` after 2–9 s, `question_result` when all answered or at the deadline, points via the preset's `config.scoring` (half-up for group). Generate the preset's question count by cycling the fixture's question.
- **Built-in visuals:** no fixture assets needed; the scenes are bundled. To test fallbacks, a debug toggle rewrites one visual's `key` to an unknown value.
- **Factory runs:** `admin_run_gate1.json` then, after approval, `running` for 6 s → `admin_run_gate2.json`. Fixtures carry `review_digest`/`published` (rev 10). The mock requires the gate request to echo the run's current `review_digest` and returns `409 review_stale` otherwise (debug toggle to simulate a concurrent change).
- **Rev 10 behaviors:** the mock HTTP layer honors `Idempotency-Key` (same key → same stored response), returns `426 client_outdated` from a debug toggle, simulates `401` after a debug "revoke" to exercise the non-looping path, and `FakeDuelSocket` is opened only from a `ws_url` returned by a mock `Duel` (ticketed, single use).

### 10.4 Switching to live
1. Set `API_MODE=live` and `API_BASE_URL`.
2. Run the contract check: for each fixture, call the live endpoint and deserialize with the same **generated models** (not just JSON parsing); any failure is a contract bug → fix the side that diverges from this document.

### 10.5 Multi-unit test curriculum
`assets/mocks/curriculum_test/` (and the matching backend seed `seed_test_curriculum`) contains **3 successive units** with 3–4 lessons each (the first Explorer-only, the others shared), both languages, prerequisite chains with Soft Locks, standalone lessons (one in a later unit) and a lesson with no prerequisites that is not standalone, mixed `concept`/`story`/`practice` lessons, at least one **non-Salah generated lesson**, and at least one lesson using **only downloaded images** (no built-in scenes). It drives verification of: journey states across unit boundaries (locked with Soft Lock, available ahead of position, in-progress, completed, skipped, coming soon), Discover listing, track membership, next-step recommendations, pretest/lesson/review/unit-test composition, unit skipping, repeated attempts, track/language switching, and review selection across units. Nothing in the app may assume a fixed number of units, the reference ids, or one playable lesson.

### 10.6 Per-type evaluation fixtures
For each exercise type (and presentation) provide evaluation fixtures for every case that applies to it: correct, incorrect, incorrect with misconception, incomplete/invalid (`400 validation_error`), timeout (`answer: null`), retry (`is_retry: true`), skipped/unavailable (`correct: null`), and no-feedback modes (`recorded` only). `flashcard` has rating outcomes instead of correct/incorrect panels; `recite_verse` covers pass, errors, unclear, and skip; `predict` has no fixture (no network). Each renderer follows its own type's interaction — no generic Check/explanation flow where §7 defines another.
