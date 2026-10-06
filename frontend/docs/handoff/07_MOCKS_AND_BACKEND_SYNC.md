# 07 — Mocks, hybrid mode and working in parallel with the backend

The backend is being built at the same time. The frontend must never wait for it, and switching a feature to live must never need UI or BLoC changes.

**Backend status (reply of 2026-10-04):** no backend service, hosted origin or go-live date exists yet. The contract is frozen for the demo at the amended revision 10 (`docs/contract/`, schema digest `9d67bda0…481c`, header still `Qabas-Contract: 10`). Plan for a demo that may run entirely on the mock backend; every group can still switch to live by configuration when it exists.

## 1. Strategy: a fake backend behind Dio

Mock mode runs the **real** client stack (ApiClient, interceptors, DTO decoding, mappers, repositories) against an in-app fake server, `MockBackend`, plugged in as Dio's `HttpClientAdapter`. Because every request still goes through the same headers, error envelope and JSON, a feature that works in mock mode is very likely to work live, and the fixtures double as contract tests.

```
RoutingAdapter.fetch(request)
  ├─ group = LiveGroup.of(request.path)      // auth, profile, journey, sessions, recitation, glossary, raqeeb, community, challenges, reviewer
  ├─ config.isLive(group) ? liveAdapter.fetch(request)   // real HTTP
  └─                      : mockBackend.handle(request)  // fake server: fixtures + small state machine
```

| `API_MODE` | Behaviour |
|---|---|
| `mock` | Everything served by `MockBackend` (no network). Default for UI work and the screenshot tour. |
| `hybrid` | Groups listed in `LIVE_GROUPS` go to `API_BASE_URL`; the rest stay mocked. **If any group is live, `auth` must be live too** (mock tokens are meaningless to the real server). `profile` should follow `auth`. |
| `live` | Everything goes to the backend; `MockBackend` isn't constructed. |

Configuration files (`--dart-define-from-file`):

```json
// config/mock.json
{ "API_MODE": "mock", "APP_FLAVOR": "dev" }
// config/hybrid.json (edit LIVE_GROUPS as backend endpoints land)
{ "API_MODE": "hybrid", "API_BASE_URL": "http://localhost:8000/v1", "LIVE_GROUPS": "auth,profile,journey", "APP_FLAVOR": "dev" }
// config/demo.json (what the competition demo runs; flip LIVE_GROUPS only for backend groups verified in Phase 14)
{ "API_MODE": "mock", "APP_FLAVOR": "demo", "HIDE_DRAFT_NOTICES": true, "CURIOSITY_ONBOARDING": false }
// config/live.json
{ "API_MODE": "live", "API_BASE_URL": "https://<API_HOST>/v1", "APP_FLAVOR": "demo", "HIDE_DRAFT_NOTICES": true, "CURIOSITY_ONBOARDING": false }
```

Owner decisions for the demo build (2026-10-04), carried by `config/demo.json`:

| Flag / rule | Effect |
|---|---|
| `HIDE_DRAFT_NOTICES=true` | The mock sessions handler drops the "Review draft only…" callout blocks listed in `assets/mocks/unit0/DRAFT_NOTICES.json` before serving a Unit 0 session. The list was built once from the backend's exact notice text; the app never matches wording at runtime. Other callouts are kept. (A-22) |
| `CURIOSITY_ONBOARDING=false` | Onboarding stays at the prototype's 7 pages and sends `goal_anchor: null`. (A-26) |
| No mock labels | Raqeeb, challenges and the rest show no "demo/mock" badge. |
| Salah reference | Never on the journey or in Discover; it opens only from the developer menu (§5). (A-23) |
| Recitation | No checker or licensed audio exists: the recite step shows "Audio isn't available yet" and offers skip. A pass is never simulated in the demo flavor. (A-27) |

Simulators: iOS can reach `localhost`; the Android emulator uses `10.0.2.2`; a physical device needs the laptop's LAN IP.

Path → group mapping (`LiveGroup.of`): `/auth`, `/onboarding` → auth · `/me` (except `/me/quests`) → profile · `/journey`, `/units` → journey · `/sessions`, `/lessons` → sessions · `/recitation` → recitation · `/glossary` → glossary · `/raqeeb` → raqeeb · `/leagues`, `/friends`, `/me/quests` → community · `/duels` + the socket → challenges · `/admin` → reviewer.

## 2. Mock backend design (`lib/mock_backend/`)

```
mock_backend/
  mock_backend.dart          # HttpClientAdapter: routes, latency, idempotency store, error injection
  mock_router.dart           # MockRoute(method, pattern, handler); path params; query; JSON/multipart body
  mock_db.dart               # in-memory state: user, journey progress, sessions, answers, checks, conversations, friends
  fixtures.dart              # loads assets/mocks/** lazily (rootBundle), caches decoded JSON
  grading/mock_grader.dart   # deterministic grading against private keys (§4)
  grading/mock_finisher.dart # builds SessionResult per contract rules (§4)
  handlers/<group>_handlers.dart   # one file per group (one owner per file)
  socket/fake_duel_socket.dart     # replays WebSocket scripts with timing
  controls/mock_controls.dart      # debug toggles (§5)
```

Behaviour shared by all handlers:

- **Latency** 300–800 ms (random, seeded), with a `fast` toggle for tests.
- **Envelope and status codes exactly as live**: `201` for creates, `202` for Raqeeb posts, `204` for no-content, and the `{"error": {code, message, details}}` envelope for failures.
- **Headers**: reject requests missing `Qabas-Contract` with `400` in debug, so a forgotten interceptor shows up early; return `Qabas-Contract: 10`.
- **Idempotency**: store `(key → status + body)`; same key + same body → same response; same key + different body → `409 idempotency_conflict`.
- **Auth**: `POST /auth/guest` issues `mock_<uuid>`; other routes require a bearer token unless the "revoke" toggle is on (then they return `401`).
- **Language and track**: choose the fixture variant from `Accept-Language` and the mock user's track (`*_ar_explorer`, `*_en_new_muslim`, …). Unit 0 exists only for Explorers (no New Muslim variants).
- **Never** put private answer keys in responses. The grader reads them on the "server" side only.

## 3. Fixtures: already in the app

Every fixture the mock backend needs is **already in `/Users/aw/StudioProjects/qabas/assets/mocks/`** and declared in `pubspec.yaml` (in the block marked "Mock data: dev/demo builds only", §8). Don't copy anything else in. Strip nothing: `_mock_*` keys are fixture metadata that the DTOs ignore.

| Path in the app | What it holds | Serves |
|---|---|---|
| `assets/mocks/contract/MANIFEST.json` | The 382 contract fixtures of the amended revision 10, each with its model name (`Session` 63, `Exercise` 120, `AnswerSubmit` 84, `AnswerEvaluation` 86, `AnswerRecorded` 16, `Journey` 6, `RecitationCheck` 3, `ErrorEnvelope` 2, `Duel` 1, `WsEvent` 1) | Contract decode test (§6) |
| `assets/mocks/contract/exercises/<type>/` | One folder per exercise type and presentation (`categorize__buckets`, `categorize__day_arc`, `map_place__hotspots`, `map_place__map_pins`, …): `exercise.json`, `answer_*.json`, `eval_*.json` (correct, incorrect, misconception, retry, timeout, recorded-only) | Exercise renderer development; MockGrader cases |
| `assets/mocks/contract/sessions/` | `review_cards.json`, `review_quick.json`, `session_practice_all_types.json` (one exercise of every type + predict + myth framing), feedback-mode histories, recovery cases | Review sessions, practice playground, resume |
| `assets/mocks/contract/curriculum_test/` | The contract's test curriculum: `journey_{lang}_{track}.json` (prerequisite Soft Locks, standalone lessons, an Explorer-only first unit), `lessons/<lesson_id>__<lang>_<track>.json` (3 units), `assessments/` (pretests and unit tests), `bank/`, `ASSESSMENT_BANKS.json`, `PRIVATE_GRADING_KEYS.json` (**private**) | Multi-unit journey, non-Salah lessons, pretest/unit test, their grading |
| `assets/mocks/contract/EVALUATION_CONTEXT.json` | Private grading context for the per-type fixtures (**private**) | MockGrader for `exercises/<type>/` |
| `assets/mocks/contract/recitation/` | `check_errors.json`, `check_passed.json`, `check_unclear.json`, `exercise_segment.json` | Recitation mock |
| `assets/mocks/contract/challenges/` | `group_challenge.json`, `group_ws_script.json` (4 players, 3 × 10 s, timeout, disconnect/reconnect, tie) | Fake socket |
| `assets/mocks/contract/workflows/ses_91ab.json` | The §6.5 session's answer history that produces the §6.5 finish example | MockFinisher test |
| `assets/mocks/contract/scenes/`, `presentation/`, `negative/` | Scene manifests and hotspot answers; generic categorize/order payloads; invalid answers (expect `400`) | Scene fallback tests, validation tests |
| `assets/mocks/contract/mock_assets/` | `audio/test_tone_112001.mp3` (a test tone only), `maps/hijaz_test.webp`, `scenes/scn_test_desert_well/`, `test/*.webp`, `mock_assets.json` | Media for `mock-asset://<path>` URLs, which resolve to `assets/mocks/contract/mock_assets/<path>`. There is no licensed reciter audio yet (O-06), so the recite step must handle "audio unavailable". |
| `assets/mocks/salah/session_salah_{ar,en}_{explorer,new_muslim}.json` | The real 14-step Salah lesson (`les_u1_l3`), as served | `POST /sessions` for the reference lesson |
| `assets/mocks/private/salah_keys_{ar,en}_{explorer,new_muslim}.json` | `exercises.<exercise_id>` → `answer_key`, `explanation`, `misconception_card` for the 7 Salah exercises (**private**) | MockGrader for the Salah lesson |
| `assets/mocks/glossary/glossary_{variant}.json`, `raqeeb_terms_{variant}.json` | Glossary pages and term cards for the reference terms | Glossary and term sheets |
| `assets/mocks/examples/` + `INDEX.json` | All 105 JSON examples from `API_REQUIREMENTS.md` as `<Model>__<section>__<n>.json` (`User`, `Stats`, `Activity`, `Quests`, `Achievements`, `Guide`, `NextStep`, `OnboardingResp`, `Page[TermCard]`, Raqeeb conversations and the 8 completed answers A–H + processing/failed, `League`, `Page[Friend]`, `Invite`, `Duel`, `SessionResult`, reviewer runs/gates/metrics, `Payload[<type>]` for every exercise type, request bodies…) | Every endpoint without a richer fixture. Regenerate with `python3 tool/extract_api_examples.py` when the contract changes. |
| `assets/mocks/demo_curriculum/curriculum.json` | **The demo curriculum the journey handler serves:** Units 0–10, track membership (Unit 0 Explorer-only), each lesson's prerequisite lesson IDs, standalone flag, minutes, type, and session file per variant. Unit 0 = the 12 backend lessons; Unit 1 = lesson 1.1; Units 2–10 coming soon. Salah is deliberately absent. | Journey and Discover handlers |
| `assets/mocks/demo_curriculum/journey_initial_{ar,en}_{explorer,new_muslim}.json` | `GET /journey` for a fresh learner, validated against the amended contract | Tests; reference output for the handler |
| `assets/mocks/unit0/sessions/session_u0_lNN_{ar,en}_explorer.json` | The 12 Unit 0 lessons as learner Sessions (24 files; Explorer only), from the backend's demo handoff. Unpublished review drafts: no displayed sources, pending scripture shown as draft notices. Lesson IDs `les_u0_l1`…`les_u0_l12`. | `POST /sessions` for Unit 0 |
| `assets/mocks/unit0/SESSION_INDEX.json`, `MEDIA_INDEX.json`, `DRAFT_NOTICES.json` | File index and exercise types per lesson; every scene and still with its state, size and hash, and the capability union; the draft-notice callout block IDs (19 in 12 lessons) | Sessions handler, media resolver, scene-renderer golden tests, demo-flavor notice removal |
| `assets/mocks/unit0/media/scenes/*.json`, `media/fallbacks/*.webp` | The 20 scene manifests (byte-for-byte, SHA-256 in the filename) and 86 clean 800 × 500 stills, one per authored state | Scene renderer (Phase 7); fallback stills before it |
| `assets/mocks/private/unit0/session_u0_lNN_{ar,en}_explorer.json` | `answers.<exercise_id>` (the correct answer) and `feedback.<exercise_id>` (`correct_answer`, `explanation`, `option_misconceptions`) per Unit 0 session (**private**) | MockGrader for Unit 0 |
| `assets/mocks/test_lessons/u1l1_{ar,en}_{explorer,new_muslim}.json` | Lesson 1.1 "What Does Islam Mean?" (both tracks) from `FINAL_ENGINEERING_HANDOFF 2/TEST_LESSONS`. Its images point to `cdn.example.com` placeholders that don't exist, so they show the placeholder panel. | `POST /sessions` for `les_u1_l1` |
| `assets/mocks/private/test_lessons/u1l1_keys.json` | `exercises.<exercise_id>` → `answer_key`, `option_misconceptions` (from the factory run; no explanations exist for 1.1) (**private**) | MockGrader for 1.1 |
| `assets/onboarding/curiosity.json` | Curiosity page copy: the question, the six goal-anchor labels and their bridges per track and language. Only English labels and one English example bridge exist; everything else is `null` until approved (O-12). Not mock data: it ships with the app. | Onboarding page 4 (behind `CURIOSITY_ONBOARDING`) |

Media URLs in these files: the Unit 0 sessions use absolute `http://localhost:8765/media/…` URLs (the backend's local file server), and the contract fixtures use `mock-asset://<path>`. In mock mode the media resolver maps both to bundled files: `http://localhost:8765/<path>` → `assets/mocks/unit0/<path>`, `mock-asset://<path>` → `assets/mocks/contract/mock_assets/<path>`. The session JSON stays byte-identical, so scene checksums still match. (A-24)

The Salah fixtures and the API examples are written in Arabic or English. If a variant is missing for a language, serve the other language rather than inventing text.

## 4. Stateful mock behaviour

| Group | Behaviour |
|---|---|
| auth / onboarding | Guest → `onboarding_completed=false`, `goal_anchor=null`. `POST /onboarding` stores the answers (including `goal_anchor`): `explorer`/`undisclosed` → track explorer, start `unit_0` (lesson 0.1); `new_muslim` → start `unit_1` (lesson 1.1). It returns the matching `NextStep`. |
| profile | `PATCH /me` merges fields into the mock user and returns it; `DELETE /me` clears `MockDb` and returns 204. Stats, achievements and activity start from the API examples and are updated by the finisher (streak, XP, lessons completed). |
| journey | Computes `GET /journey` from `assets/mocks/demo_curriculum/curriculum.json` and the mock learner's completed and in-progress lessons, by porting `compute_journey()` from `tool/build_demo_curriculum.py`: only the units of the learner's track; a lesson is `available` when all its prerequisite lessons are completed, otherwise `locked` with a `soft_lock` (`prerequisites` = the unmet prerequisite lessons, `start_with` = the earliest openable lesson on that dependency path); position never locks. `GET /journey/next` = the first available lesson in curriculum order (or `review` when cards are due). Changing the track to `new_muslim` removes Unit 0 and keeps completions. A lesson completed from any surface counts everywhere. |
| sessions | `POST /sessions {lesson, <id>}`: Unit 0 and 1.1 → the session file named in the curriculum for the learner's variant, with a fresh `session_id`; a lesson whose prerequisites are unmet → `409 prerequisite_unmet` with `details.prerequisite_lesson_ids` and `details.start_with_lesson_id`; a lesson outside the learner's track → `404 not_found`. In the demo flavor, the draft-notice blocks in `DRAFT_NOTICES.json` are removed first. `les_u1_l3` → the Salah variant fixture (reachable only from the developer menu, which calls this same endpoint). Other lesson IDs → `assets/mocks/contract/curriculum_test/lessons/<id>__<variant>.json`. If an active session already exists, return it with **200**. Review (`cards`/`quick`), pretest and unit test sessions → `assets/mocks/contract/sessions/review_cards.json`, `review_quick.json`, `assets/mocks/contract/curriculum_test/assessments/*`. Answers: enforce authored order (`409 out_of_order`), replay recorded identities `(session, exercise, is_retry)` unchanged, apply the retry rule (`409 retry_not_allowed`), grade with `MockGrader`, and redact for feedback modes `none`/`end` (`{exercise_id, recorded}` only). Finish: `MockFinisher` builds the `SessionResult` and stores it; later calls return the same body. |
| recitation | **Demo flavor:** `POST /recitation/checks` → `503 upstream_unavailable`, so the recite step shows its unavailable state and the learner skips; a pass is never simulated (backend reply item 10). **Dev flavor only** (to build and test the UI states): first check → errors result (`assets/mocks/contract/recitation/check_errors.json`), second → passed; the "unclear" toggle → unclear. Store checks by `check_id` for grading (`grade_by: recitation_check`: `correct = check.passed`; `{skipped: true}` → `correct: null`). |
| glossary | Lists from `glossary_{variant}.json`; `POST /glossary/{id}/opened` → 204 and moves `new → learning`. |
| raqeeb | `POST …/messages` → `202` with a processing assistant message. Polls advance `stage` every 1.2 s through `reading_inputs → classifying → retrieving → verifying → writing → adapting`, then return the completed example chosen by the developer-menu picker (A general, B verification, C personal fatwa, D sensitive, E differing views, F text explanation, G deep creed, H out of scope, or failed). Without a pick, the attachment type decides (image → B, DOCX → E, PDF → G, audio → F), otherwise A. A second message while one is processing → `409 answer_in_progress`. |
| community | League, friends and quests from the examples. `POST /friends/invites` returns a code; accepting `QBS-TEST` succeeds, anything else → `409 invite_invalid`. With the developer toggle "no league yet", `/leagues/current` → `404` with `details.reason = no_league_this_week`. |
| challenges | `POST /duels` (bot) → `ready` with `ws_url = mock-ws://duels/<id>?ticket=<uuid>`. `FakeDuelSocket` only accepts that URL once (single-use ticket). It replays `assets/mocks/contract/challenges/group_ws_script.json` for groups, or a generated duel script for the 7-question duel preset: `countdown` 1 s after `ready`; next `question` `reveal_ms` after each `question_result` (3,000 ms duel / 2,200 ms group); bot answers after 2–9 s; scoring `100 + floor(100 × remaining/limit)` (duel) or `100 + half_up(50 × remaining/limit)` (group). |

**MockGrader** rules (deterministic, per type, against the private key): option/segment/pin match; `true_false_reason` needs both value and reason; `match_pairs`, `fill_blank` and `categorize` need every pair/fill/assignment right and return per-item details; `order_steps`/`timeline_order` need the exact sequence (details: `first_wrong_index` / `event_dates`); `flashcard` → `rating != again`; `map_place {unavailable}` and recitation `{skipped}` → `correct: null`; `answer: null` (timeout) → incorrect. Key files by lesson: Salah → `private/salah_keys_<variant>.json` (`exercises.<id>.answer_key`, `explanation`, `misconception_card`); Unit 0 → `private/unit0/<session file name>` (`answers.<id>` and `feedback.<id>.explanation` / `option_misconceptions`); 1.1 → `private/test_lessons/u1l1_keys.json` (`answer_key`, `option_misconceptions`; no explanation, so the evaluation's `explanation` is `[]`); the contract test curriculum → `contract/curriculum_test/PRIVATE_GRADING_KEYS.json`. The explanation comes from the key file; a misconception card is attached when the key marks one for the chosen option (Unit 0 and 1.1 name a misconception ID only, so the card shows the lesson's misconception title from the session when available, and is omitted otherwise). `mastery_changes` can be empty in mock mode.

**MockFinisher** follows API §6.5 finish rules: accuracy and `score` over graded **first attempts** of exercises with `scoring.accuracy = true` (excluding `correct: null`); `layers` grouped by `scoring.layer` (`remembering` always null); XP `lesson_complete 10` + `lesson_perfect 3` (all accuracy-counted first attempts correct) + `recitation_passed 3` per passed recitation + `daily_goal_met 2` once per day; `streak.extended_today` true on the first finished session of the mock day; `terms_mastered` = terms opened during the session that were `learning` (good enough for the demo); `next_step` from the mock journey. **Salah reference expectations:** 6 accuracy-scored exercises, Understanding over 3, Applying over 2, Remembering placeholder.

## 5. Developer menu (debug and demo builds only)

Reachable by long-pressing the profile avatar in dev and demo builds (hidden in release; the gesture is the only entry, so judges never see it). It contains:

- Current `API_MODE`, base URL and live groups (read-only), plus the contract revision the server reported.
- **Lesson launchers:** "Preview: Salah reference lesson" (the 4 language × track variants; the only way to open Salah, A-23) and a Unit 0 lesson picker that opens any of the 12 lessons regardless of Soft Locks (for review only).
- Journey: mark a lesson completed or reset progress; switch track.
- Raqeeb outcome picker (9 outcomes). Recitation (dev flavor): next check unclear. Duel: bot speed.
- Flags (dev only): toggle `HIDE_DRAFT_NOTICES` and `CURIOSITY_ONBOARDING` at runtime to check both behaviours.
- Simulate: `426` on the next request · revoke token (→ `401` path) · `503`/`429` on the next request · offline · rewrite one visual's `key` to an unknown value (fallback test).
- Reset mock database · clear local preferences and resume data · fast latency.

These are developer tools: strings may be English-only literals **inside `features/dev_tools/` only**, which is the one folder excluded from the hard-coded-string check.

## 6. Contract tests (run on every change)

1. `test/contract/fixtures_decode_test.dart`: every file in `assets/mocks/contract/MANIFEST.json` decodes with the DTO for its model name, and mappers succeed. Print coverage (models without a DTO yet) instead of failing for Tier C models.
2. `test/contract/api_examples_decode_test.dart`: every file listed in `assets/mocks/examples/INDEX.json` decodes with the DTO for its `model`. Skip `Payload[<type>]` entries through the exercise payload decoder, and skip reviewer models until Tier C.
3. `test/contract/request_shapes_test.dart`: request DTOs (`OnboardingReq`, `MePatch`, `SessionCreate`, `AnswerSubmit` for every type, `FinishReq`, `ConvCreate`, `FeedbackReq`, `InviteAccept`, `DuelCreate`, `WsClientMessage`) serialise to exactly the documented JSON (explicit nulls; `MePatch` partial).
4. `tool/contract_smoke.dart` (manual, against a live backend): guest → onboarding → `GET /me` → `GET /journey` → `GET /journey/next` → `POST /sessions` (lesson) → one answer → finish → `GET /me/stats` → Raqeeb post + poll. It decodes each response with the same DTOs and prints the first mismatch with its JSON path.

## 7. Working with the backend engineer

**Kick-off (30 minutes, first morning):**

1. Both sides confirm `FINAL_ENGINEERING_HANDOFF` revision 10 (`03_API/API_REQUIREMENTS.md` + `contract_revision10/`) as the only contract, and the base URL (`http://<host>:8000/v1`).
2. Agree the order endpoints go live (it matches the demo spine): **auth + onboarding + `GET/PATCH /me` → journey + next → sessions (Salah lesson: create, answers, finish) → Raqeeb (post + poll) → stats/activity/quests/achievements → glossary → league/friends → recitation → challenges.**
3. Agree that both sides validate against the same fixtures (the backend's contract tests use the same `contract_revision10/fixtures`), and agree one shared place for mismatches (a chat thread or a shared `API_ASSUMPTIONS.md`).
4. Share this repo's `docs/API_ASSUMPTIONS.md` and ask the backend engineer to confirm or correct each open item.

**Flipping a group to live:**

1. Backend says the group is deployed (local or hosted).
2. Run `dart run tool/contract_smoke.dart --groups=<group>` → all responses decode.
3. Add the group to `LIVE_GROUPS` in `config/hybrid.json`, then play the feature in both languages.
4. Fix mismatches with the protocol below, then mark the group **live-verified** in the status table of `docs/API_ASSUMPTIONS.md` with the date.

**Mismatch protocol.** Compare the live JSON with `API_REQUIREMENTS.md`. Whichever side deviates from the document fixes it. If the document is ambiguous, agree on an interpretation, write it in `docs/API_ASSUMPTIONS.md` (both sides), and change the DTO or mapper. Never silently loosen a DTO to accept a shape that contradicts the contract. A temporary tolerant mapping is allowed only with `// TODO(contract): <assumption id>` and an entry in the log.

**Sync points:** a 10-minute check-in twice a day: groups live, blockers, new assumptions, and what the demo will run live versus mocked.

**For the demo:** the default is `hybrid`, with every group the backend has verified set to live and the rest mocked. A feature never disappears because its endpoint is late.

## 8. Keeping mocks out of production

- Mock assets live only under `assets/mocks/`. They are declared in `pubspec.yaml` as 38 directory entries, inside a block marked "Mock data: dev/demo builds only". Once iOS/Android flavors exist, move that block under asset flavors (`- path: assets/mocks/<dir>/` with `flavors: [dev, demo]`). Until then, a production build must delete that block from `pubspec.yaml` and use `config/live.json`.
- With `APP_FLAVOR=prod` the code refuses `API_MODE != live`, never constructs `MockBackend`, and hides the developer menu.
- `tool/check_release_bundle.sh` (Tier C) unzips the release build and fails if it finds `_mock_`, `answer_key`, `PRIVATE_GRADING_KEYS`, `EVALUATION_CONTEXT` or `gold-candidate`.
