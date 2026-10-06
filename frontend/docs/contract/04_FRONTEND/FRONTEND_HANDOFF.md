# Frontend handoff

**Purpose:** specify Flutter screens, visual/interaction behavior, source reuse and the exact reference conversion. Schema details belong to [API requirements](../03_API/API_REQUIREMENTS.md); implementation sequence belongs to [frontend implementation](../08_IMPLEMENTATION/FRONTEND_IMPLEMENTATION.md).

Read the product requirements, API contract, architecture decisions and animation/media handoff before wiring repositories. Generate DTOs from the [revision 10 schema](../03_API/contract_revision10/README.md) (99 roots; ignore unknown response fields and map unknown enum values to a safe `unknown` case, per the [data model](../02_ARCHITECTURE/DATA_MODEL_AND_VERSIONING.md) versioning rules). The source is [flutter_reference](../10_REFERENCE/engineer_delivery/reply8/flutter_reference/README.md); original `lib/` is unchanged, with separately added export/API adapters. It uses local simulated services. Do not ship its demo `AppState` or locally graded `LessonSession` as the live data source.

The six typed display DTOs, API term sheet and isolated order/categorize panels demonstrate the four projection fixes. They are scaffolding for the full Session controller and reference component adaptation. They do not establish complete screen layouts, feedback/retry/resume/finish, every animation/interaction state or all production exercise renderers. Complete those through reusable components, not per-lesson branches.

Freeze viewport/fonts/DPR/preferences/time for source/API goldens, then test real interactions. Preserve 14 Arabic/13 English linked terms, canonical Arabic glossary display including diacritics, English ordering secondary labels across token states, explicit prayer_rug/heart bucket art, declared day_sequence ordering header and all 12 captured banks. The exact native fixture values are in [reference_export](../10_REFERENCE/engineer_delivery/reply8/reference_export/README.md).

The known frozen Latin-font fallback issue and approved production reward/Remembering differences are tracked in [open decisions](../00_REVIEW/STATUS_AND_OPEN_DECISIONS.md). Keep exact strings; close device-font/visual acceptance deliberately. The optional companion is purely local and may be replaced/removed.

Original section numbers below support cross-references through [the section map](../03_API/SECTION_REFERENCE_MAP.md). For complete per-type/mode tests use [quality criteria](../09_VALIDATION/QUALITY_AND_ACCEPTANCE.md).

## 2. Screens and navigation

| # | Screen | Key behavior |
|---|---|---|
| S1 | Splash | If a token is stored → `GET /me`; if `onboarding_completed=false` → S2; else → S3. If no token → `POST /auth/guest`, then S2. On `401` follow API §3.4 (clear token, notice, new guest; never loop). On `426 client_outdated` show the blocking update screen. |
| S2 | Onboarding (8 pages; the prototype's 7 pages from `qabas/lib/features/onboarding/onboarding_flow.dart` plus a new curiosity page built from the same onboarding components) | (1) Language; (2) Welcome; (3) Learner type: exploring Islam / new Muslim / prefer not to say (track only; never a religion question); (4) **Curiosity:** "What would you most like to understand?" with the `goal_anchors` choices (skippable); after a choice, show its reviewed onboarding bridge for the chosen track and language (bundled copy keyed by `goal_anchor` × track, e.g. why the foundation comes before Muhammad ﷺ). The choice never changes the start unit or order; (5) Familiarity: none / some / good; (6) Daily goal: 5 / 10 / 15 / 20 min; (7) Privacy: private profile, discreet reminders; (8) Ready. Submit `POST /onboarding` on page 8. No placement test. Discreet reminders are a local preference. Bridges are onboarding content, not lessons. |
| S3 | Home / Journey map (Roadmap) | `GET /journey` + `GET /journey/next`. Prototype journey presentation (`journey_widgets.dart`): unit artwork chosen by `unit.art_key` from bundled art, lesson nodes with popovers, checkpoint nodes for unit tests, guidebook sheet per unit (`GET /units/{id}/guide`). A prominent "Continue" uses `next_step`. Lesson node state comes from the server: a lesson later in the path can be `available` (position is not a prerequisite). Tapping a `locked` node opens the **Soft Lock** sheet: a warm explanation that one earlier idea makes this lesson easier (conceptually "You're almost there. One idea first will make this much easier to understand."), naming `soft_lock.prerequisites` and a button that opens `soft_lock.start_with`. Never an unexplained lock and never a "skip lesson" action; the unit "Skip unit" placement test stays on the checkpoint. A `409 prerequisite_unmet` from `POST /sessions` shows the same sheet. Badge for pending challenge invitations (`GET /duels/invitations`, poll every 15 s while visible). |
| S4 | Session player | Plays any session (`lesson`, `review`, `pretest`, `unit_test`). Lesson progress follows §6.5.1 (top-level steps); other kinds use answered/total exercises. |
| S5 | Session result / lesson complete | Lesson sessions use the prototype completion screen (`lesson_complete_screen.dart`): accuracy, time, and embers count-ups; understanding and applying bars from `layers`; remembering placeholder; review topics; real-life challenge; "Tomorrow we'll ask" check-in; next step. Other kinds show score, XP, streak, unlocks, and next step (`unit_test` adds the answer review). |
| S6 | Lesson reader | `GET /lessons/{id}` to re-read a completed lesson (blocks only, no exercises, `predict` shown with its explanation). |
| S7 | Sources drawer | Bottom sheet listing `sources` of the current lesson/session ("مصادر هذا الدرس"). |
| S8 | Term card | Bottom sheet for a tapped dotted term. |
| S9 | My glossary | `GET /glossary` with filter tabs (new / learning / mastered). |
| S10 | Raqeeb conversations list | `GET /raqeeb/conversations`. |
| S11 | Raqeeb chat | Compose (text + mic + image picker + document picker), stage indicator while processing, rich answer rendering. One answer in progress per conversation (`409 answer_in_progress` → keep the composer disabled until the current answer completes or fails). Each send uses a new `Idempotency-Key`, reused for automatic network retries of that send. Attachment URLs are short-lived; re-fetch the conversation when one expires. |
| S12 | Profile and settings | `GET /me`, `GET /me/stats`, `GET /me/achievements` (badges row), `GET /me/concepts`; settings: language, track (explicit learner choice, e.g. an Explorer who became Muslim; progress is kept and the journey is re-fetched), curiosity question/Goal Anchor, daily goal, avatar, private profile (`PATCH /me`); sound, haptics, reduced motion, discreet reminders (local, persisted on device); delete account. |
| S13 | League | `GET /leagues/current`: tier name and art, promotion zone, no demotion. `404` with `no_league_this_week` → localized empty state ("Earn embers to join this week's league"). |
| S14 | Friends | `GET /friends`, create/share invite code, accept code, remove friend. |
| S15 | Challenge lobby | Start a duel (one friend or the practice bot) or a group challenge (up to 3 friends) as in `community_screen.dart`; pending invitations; accept/decline. |
| S16 | Challenge play | WebSocket live play (§8) using `Duel.ws_url` exactly as returned (it carries a single-use ticket); fetch a fresh `Duel` before every reconnect. Group layout per `live_challenge_screen.dart`. |
| S17 | Challenge result | Winner/ranking, scores, per-question explanations. |
| S18 | Streak | `GET /me/activity` calendar/week view and current/longest streak (`streak_screen.dart`). |
| S19 | Daily quests | `GET /me/quests`: three quest rows with progress, goal, and reward. |
| S20 | Achievements | `GET /me/achievements`: locked/unlocked badges with progress (`achievements_screen.dart`). Badge art is bundled by `achievement_key`. |
| S21 | Review | `POST /sessions {kind: review, mode: cards}`: untimed self-rated flip-card deck (`review_session_screen.dart`). Quick timed review (`mode: quick`) is an additional entry. |
| S22 | Discover | "What can I explore now?" Lists the `standalone_eligible` lessons of the learner's journey (same `GET /journey` response; completed ones marked), grouped by unit. One general page notice explains that some lessons normally come later and earlier units can make them easier. Opening a lesson uses exactly `POST /sessions {kind: lesson, lesson_id}`: same session player, version, wording and exercises as from the Roadmap; nothing records or varies by the entry surface. Completion shows on the Roadmap too. |
| R1 | Reviewer login | `POST /auth/reviewer`. |
| R2 | Factory runs list | `GET /admin/factory/runs`; "New run" form. |
| R3 | Run detail — Gate 1 | Review/edit the lesson plan: primary outcome, objectives, prerequisite and introduced concepts, standalone decision, reasoning tools with justifications, lesson arc steps, minutes and budgets against the lesson-type targets; approve or reject. Send the `review_digest` of the run as displayed; on `409 review_stale` reload and ask the reviewer to look again. |
| R4 | Run detail — Gate 2 | Draft preview (per language × track variant, Arabic and English of a variant side by side) using the learner renderers, per-sentence evidence panel with the sentence role and claim basis/reasoning, arc map (which blocks realise each arc step), QA report with religious and pedagogical findings, visuals list; an Arabic sentence edit requires the matching English edit; approve / request changes / reject; regenerate generated images. Same digest echo and stale handling as R3; Approve stays disabled while any `blocker` (including `kind: validation`) remains, and validation errors returned on approve are shown inline. |
| R5 | Blind test | Two anonymized lessons side by side; three questions. |
| R6 | Metrics dashboard | `GET /admin/metrics`. |

Routing: learner routes under `/`, reviewer routes under `/review/*` (shown only when `role=reviewer`).

---

## 9. UI rules specific to this product

1. **Direction:** `ar` → RTL, `en` → LTR, switchable at runtime from settings without restarting. Quran text is always RTL, even inside the English UI.
2. **Design baseline:** use the prototype's theme tokens (`qabas/lib/core/theme/tokens.dart`: colors, spacing, radii, curves, motion durations), its bundled fonts, and its components as-is; don't reinterpret them. The Uthmani Hafs font is used **only** for `text_uthmani` fields. Add all font licenses to the repo's licenses log.
3. **Quran display:** always show `text_uthmani` verbatim (never re-wrap words across a different order, never truncate mid-ayah). Show `surah_name` + ayah numbers under the verse. Quran audio is always the reciter file from the payload; the app never uses text-to-speech for Quran.
4. **Honorifics:** content may contain "ﷺ" and "عليه السلام"; render as-is.
5. **Dotted terms:** dotted underline for `term` spans whose state is `new` or `learning`; tap → Term card; call `POST /glossary/{id}/opened`. When a `SessionResult` lists a term under `terms_mastered`, update the local term state so the underline disappears immediately.
6. **Evidence budget:** the backend guarantees §6.5.3 — at most 3 **content** sources plus eligible **activity** sources (the reference shows 4); render exactly what is sent and don't add extra evidence UI. Everything else is in the "Sources" drawer.
7. **Sentence sources:** long-press on any `Sentence` (paragraphs, story beat narration, teaching points, summary cards) shows its sources in a small sheet.
7a. **One lesson, every surface:** a lesson renders identically whether it was opened from the Roadmap, Discover, a Raqeeb suggestion or the reader; never branch on the entry surface. Track variants are chosen by the server.
8. **Overlays:** draw a `Visual`'s `overlays` on top of the rendered visual (built-in scene or downloaded image) in the same box, exactly as specified. Never render generated text over visuals except overlays and UI captions.
9. **Misconception card:** a distinct, gentle style (not red); title + card spans + sources link.
10. **Raqeeb stages:** show the current `stage` label with a subtle progress animation; never show a spinner without a label for more than 1 s.
11. **Verification card colors:** see §6.8. `not_found` must never be styled like `fabricated`.
12. **Referral card:** clear, calm styling with the target name, description, and an "Open" button when `url` exists.
13. **Recording:** request microphone permission just-in-time. Show elapsed time and max time; auto-stop at the max. Encode AAC/m4a on mobile, Opus/webm on web.
14. **Timers:** quick reviews (20 s), duel challenges (15 s), and group challenges (10 s) use a draining bar; the last 5 s (3 s for group) change color. Card reviews are untimed.
15. **Display names and avatars:** render the prototype's bundled faceless traveler avatars by `avatar_key` (unknown → default). No photos or avatar uploads.
16. **Localization:** all static UI strings in `ar` and `en` ARB files. Content strings come from the API already localized.
17. **Visual dispatch:** `kind: builtin` → bundled painters via `VisualRegistry` (key + version); `kind: scene` → `packages/qabas_scene` with the manifest; `kind: image` → network image. Never by lesson id. Unknown key/version/capability → fallback (§3.8).
18. **Motion:** continuous motion (water, palms, sparkles, clock second hand, steam, sky) runs locally. State changes from local actions (story beat advance, teaching-point reveal, day-arc slot placement) animate immediately with no network round trip.
19. **Reduced motion:** when the platform's reduce-motion setting is on, scenes show a readable static frame for their current state, transitions are instant, and every interaction stays usable.
20. **No mirroring of illustrations:** scenes, maps, and pins keep their physical layout in RTL, **except** the `pillars` rule in §5.5b.
21. **Loop timings:** reuse the prototype painters and their loops — `river_house` 5 s, `workplace` 60 s, `day_arc` 8 s, `pillars` 4 s — and the prototype motion tokens for transitions.
22. **Feedback and celebration:** correct/incorrect feedback, combo flame, sounds, haptics, count-ups, celebration, and the streak transition follow the prototype (`lesson_session.dart`, `lesson_complete_screen.dart`) and respect the local sound/haptics/reduced-motion settings. `predict` and `correct: null` steps never trigger correct/incorrect feedback or combos.
23. **Localized bundled strings** (not API content): pillar labels, CTA defaults ("Show more", "Continue", "Let's find out"), `day_arc` instructions, completion-screen headings, onboarding copy — taken from the prototype's l10n.
24. **Companion:** optional and fully Flutter-owned ([PR-13](../01_PRODUCT/PRODUCT_REQUIREMENTS.md), AD-06). It reacts to app events (correct, incorrect, misconception card, lesson complete, streak, duel result) and is never referenced in API payloads.
25. **Narration audio:** never autoplays; a play control appears only when a URL is present.
26. **Network identity and retries (rev 10):** every request sends `Qabas-Contract`/`Qabas-Client` (API §3.2). Create calls that need it carry an `Idempotency-Key` generated once per user action. Answer and finish calls are retried freely with the same body (the server replays). A timed-out finish is retried, never re-played locally.
27. **Credentials:** access tokens live only in `flutter_secure_storage` (Keychain/Keystore). They never appear in logs, crash reports, analytics or URLs. Web stores the guest token in browser storage only if web is an approved platform (O-04, accepted weaker storage).
28. **Release hygiene:** release builds exclude `assets/mocks/`, fixture files and any `_mock_*` or answer-bearing data. CI fails a release build whose bundled assets contain `_mock_` keys, answer keys, `PRIVATE_GRADING_KEYS`, evaluation context or gold/native exports. Reviewer-console DTO code may name `answer_key`; the scan targets bundled data, not compiled field names.

---

## 11. Suggested Flutter setup

| Concern | Package |
|---|---|
| State management | `flutter_riverpod` |
| Routing | `go_router` |
| Models | `freezed`, `json_serializable` |
| HTTP | `dio` (multipart uploads, interceptors for auth and error mapping) |
| WebSocket | `web_socket_channel` |
| Audio record | `record` (supports Android, iOS, web) |
| Audio play (with seek/clip) | `just_audio` |
| Image/file pick | `image_picker`, `file_picker` |
| SVG overlays | `flutter_svg` |
| Image cache | `cached_network_image` |
| Localization | `flutter_localizations`, `intl` (ARB) |
| Token storage | `flutter_secure_storage` (rev 10: `shared_preferences` is not encrypted; keep it for non-secret local preferences only) |
| Idempotency keys | `uuid` (v4) |
| Share sheet | `share_plus` |

Folder structure:
```
lib/
  core/        (config, api client, error mapping, theme, l10n, rich_text renderer)
  models/      (freezed models mirroring §5–§8)
  data/
    mock/      (Mock*Repository + fixture loader)
    api/       (Api*Repository + duel socket client)
  features/
    onboarding/ journey/ session/ exercises/ recitation/ glossary/
    raqeeb/ community/ duel/ profile/ reviewer/
  widgets/     (evidence card, verse player, term card, sources drawer, overlays image)
```

---

## 12. Frontend definition of done (before merge)

- Every screen in §2 works end-to-end in mock mode, in both `ar` (RTL) and `en` (LTR), on every release platform approved under O-04 (the inherited target was Android and web; iOS builds are included in the reference source).
- All 14 exercise types render, validate completeness, submit the exact answer shape in §7, and display evaluation `details`.
- Session flow handles all four kinds and feedback modes, including lesson retries and review timeouts.
- Raqeeb handles all input combinations and renders all eight completed classes (examples A–H) plus `failed`.
- Recitation handles errors, pass, unclear, skip, and word-segment playback.
- Duels work against `FakeDuelSocket` including reconnect and opponent-disconnect paths, plus the async REST flow.
- Reviewer console renders Gate 1, Gate 2 (with evidence panel and QA issues), blind test, and metrics from fixtures.
- Contract check (§10.4) passes against the live backend.
- The Salah reference lesson (Appendix A; fixture ID `les_u1_l3`, curriculum lesson 3.2) plays end to end in mock and live modes with all 14 steps, matching the prototype 1:1 in appearance **and motion** in `ar` and `en`, both tracks: office hook, neutral prediction, river beats with constant story label, provenance tags, quotes, and glosses (no origin card), labeled river hotspots, five-light teaching card, myth correction (prompt above the card), pillars (Arabic labels aligned) with `pillarsEvidence`, sorting, day-arc card (−1, 1, 4, 4) with `timesEvidence`, five-slot placement (layout, states, sky), recitation of the 4:103 segment (`nisaEvidence`, Meaning expander, word highlighting), summary card, ordering, completion screen (accuracy over 6; Understanding 3, Applying 2, Remembering placeholder).
- **Visual verification:** screenshots compared with the prototype at the same viewport and a fixed animation frame (animations paused at a known time), in `ar`, `en`, and reduced motion; **motion/interaction** verified separately by a recorded walkthrough or integration tests on state changes. Record the prototype source identity (git commit if available; otherwise the verified source-content digest) used as the baseline.
- Every exercise type and presentation in §7 (including those absent from the prototype), the `predict` block, `framing`, the duel-only `true_false`, and both challenge presets pass their §10.6 fixtures in mock and live modes.
- The multi-unit test curriculum (§10.5) plays without lesson-specific branches or fixed curriculum size.
- Onboarding (the prototype's 7 pages plus the curiosity page with its bridge), journey art and guidebook, streak calendar, quests, achievements, league tiers, card review, and avatars match the prototype screens with live data; the curiosity page and bridge reuse the onboarding components and pass product review.
- Roadmap and Discover (S3, S22) show the same lessons from one journey response; Soft Lock sheet for locked nodes and `409 prerequisite_unmet`; a lesson finished from Discover shows completed on the Roadmap; Explorer-only Unit 0 disappears after a track change to New Muslim while shared progress stays.
- Appendix B coverage matrix is kept current with honest status (specified / implemented / verified).
- Story blocks render both kinds through the same story view: sourced stories with provenance tags and the optional origin card, teaching scenarios (`origin: null`) with their label and no provenance, origin card or drawer entry.
- Generated scenes: `packages/qabas_scene` renders `fixtures/scenes/session_test_scene_lesson.json` without lesson-specific code or a new app build — hook, story beats 0→2, teaching focus 0→2, hotspots on the scene with server grading — in `ar`/`en` and reduced motion; unknown capability and download/checksum failure show the fallback; a resumed session keeps its scene version. Golden frames from the app renderer match the backend preview tool's frames for the same scene/state/time.
- Visual fallbacks work for unknown keys/versions and failed image loads without blocking the lesson.
- Swapping or removing the companion character compiles and runs with no API or fixture change.
- Rev 10 controls: secure token storage and the non-looping `401` path; `426` update screen; idempotency keys on required creates with retry-safe behavior; WebSocket connect/reconnect only through freshly fetched `ws_url`; reviewer digest echo and `review_stale` handling; release-bundle scan for private/mock data passes.

---

## Appendix A — Salah reference lesson: 1:1 conversion specification

The rev 2 file `session_salah.json` (an adapted lesson) is **withdrawn**. The reference fixtures are generated from the prototype's authored lesson so that copy, terms, and states can't drift.

### A.1 Generation
- **Input:** `qabas/lib/data/lesson_salah.dart` with `qabas/lib/data/models.dart` and the prototype's l10n for both languages. Record the prototype git commit in each generated file (`"_mock_source_revision"`).
- **Tool:** `tools/export_reference_lesson` (Dart, run inside the prototype repo against its own models). It emits (1) the backend gold file `content/gold/salah-01.json` in the stored-content format, and (2) the four learner fixtures `session_salah_{ar,en}_{explorer,new_muslim}.json` plus the evaluation and completion fixtures (§A.4).
- **Copy:** every string (step text, options, feedback, quote glosses, labels, CTA, eyebrow, objectives, summary, challenge, review topics, check-in) is copied **verbatim** from the source. Nothing is rewritten or translated by hand.
- **Terms:** preserve every linked source key and its original span location: **14 in Arabic, 13 in English**, in each track. English does not link `daran`; that is the accepted source baseline. All TermCards carry the separate `Term.arabic` display exactly. No source correction is implied by the count difference.
- **Ids:** opaque and deterministic (hash of the source keys); they never encode answers or slot order.
- **Tracks:** export both the default points and the track-specific `explorerPoints` (and any other track-specific text) into their own variants; the four fixtures must preserve every difference. Content identical across tracks is stored once as `shared`.
- **Evidence:** export all four reference evidence objects with their localized explanations and references — `riverEvidence`, `pillarsEvidence`, `timesEvidence`, `nisaEvidence` (`qabas/lib/data/lesson_salah.dart`, `qabas/lib/data/scripture.g.dart`).

### A.2 Step mapping (binding)
| # | Prototype step | Contract representation | Visual (proportion) | Required states and details |
|---:|---|---|---|---|
| 1 | Office hook | `hook` | `workplace` `{}` (1.75) | Question and CTA verbatim (`cta`). |
| 2 | Predictive question | `predict` | as in source (`null` if none) | Options and neutral reveal verbatim; select → Check → neutral gold feedback; ungraded. |
| 3 | Four-beat river story | `story` (4 beats), `label` verbatim, `provenance` = `riverEvidence` (grade/reference/provider tags on all beats, incl. beat 0), `origin.show_card: false` | `river_house` beats `0, 1, 2, 3` (1.5) | Quotes = verbatim hadith excerpts (`excerpt: true`); `quote_meaning` = the source's gloss with its tappable terms; story label and dots constant; `narration_audio_url: null` (the reference story is silent); goes straight to step 4. |
| 4 | Find the river | `map_place`, `presentation: hotspots` | `river_house` **beat 1** (1.15) | Pins: palm **(16, 36)**, front door **(55, 52)**, window **(80, 34)**, river **(42, 86)**; all four labels visible before evaluation; answer = river. |
| 5 | River-parable teaching card | `teach` (`standard`) | `river_house` beat **3** (five lights) (1.9) | Eyebrow, title, points verbatim. The river hadith is already displayed (story) — same source, no extra budget. |
| 6 | Myth: "past mistakes make prayer pointless" | exercise of the source's type with `framing: { kind: "myth", statement }` | as in source | Prompt first, then the mistaken-idea card (`choice_view.dart`); misconception mapping and remediation card verbatim. |
| 7 | Pillars teaching card | `teach` (`standard`) | `pillars` `{ highlight: 1 }` throughout, no point `visual_params` (1.9) | Five localized labels, prayer label emphasized, Arabic RTL rule (§5.5b); evidence = `pillarsEvidence` on entry; points verbatim per track. |
| 8 | Sort prayer vs free supplication | `categorize`, `presentation: buckets` | Category drawings | Categories/items verbatim; explicit `prayer_rug` and `heart` art keys; initial bank captured by Dart `stableShuffle` with the English prompt. |
| 9 | Day-arc teaching card | `teach` (`standard`), 4 points | `day_arc` base `{ highlight: -1 }`; point `visual_params` `null`, `{1}`, `{4}`, `null` (2.1) | Visible highlights **−1, 1, 4, 4**; evidence = **`timesEvidence`** (the prayer-times hadith, "وقت صلاتكم بين ما رأيتم") with its explanation, shown on entry; the narration explaining it stays verbatim. |
| 10 | Place the five prayers | `categorize`, `presentation: day_arc` | arc (2.8), starts at dawn | Slot labels and secondary labels verbatim; initial bank captured by Dart `stableShuffle` with the English prompt. |
| 11 | Why five times a day (scenario) | `scenario` | as in source | Situation, options, and per-option feedback verbatim. |
| 12 | Recite the An-Nisa 4:103 segment | `recite_verse` with its own `source_id` = **`nisaEvidence`** (`display_role: activity`), `word_start`/`word_end` = that seven-word segment matched against the mushaf | — | `meaning` = the source's localized meaning (Meaning expander); reciter clip of exactly the segment with `audio.words`; checker receives the same range. |
| 13 | Three-idea summary | `teach` (`style: summary`) | as in source | All three points visible immediately. |
| 14 | Order the five prayers, morning → night | `order_steps`, `presentation: day_sequence` (five steps) | dawn → night header | Steps verbatim, Arabic secondary labels in English/null in Arabic; initial bank captured by Dart `stableShuffle` with the Arabic prompt. |
| — | Intro / completion | `objectives`; `completion` (`challenge`, `review_topics`, `check_in`) | — | Verbatim from the source's objectives, challenge, review topics, and check-in. |

Displayed sources: `riverEvidence`, `pillarsEvidence`, `timesEvidence` (content, 3) + `nisaEvidence` (activity, 1) → `source_count` **4**, matching the prototype's `sourceCount: 4`.

**Scoring map (binding for the reference):**
| Step | Activity | `scoring.accuracy` | `scoring.combo` | `scoring.layer` | Completion bar |
|---:|---|:---:|:---:|---|---|
| 2 | Prediction | — (content block) | — | — | none |
| 4 | Find the river | ✓ | ✓ | `understand` | Understanding |
| 6 | Myth correction | ✓ | ✓ | `understand` | Understanding |
| 8 | Sorting | ✓ | ✓ | `understand` | Understanding |
| 10 | Day-arc placement | ✓ | ✓ | `apply` | Applying |
| 11 | Scenario | ✓ | ✓ | `apply` | Applying |
| 12 | Recitation | ✗ | ✗ | `null` | none (its checker result is still shown) |
| 14 | Ordering | ✓ | ✓ | `remember` | none — "Remembering" stays the placeholder |

→ 6 accuracy-scored exercises; Understanding over 3, Applying over 2. Intro: 8 interactions, 7 exercises, 6 scored, 4 sources.

**Documented product differences from the prototype** (behavior that intentionally extends the proof of concept; mock completion fixtures follow these rules, and visual comparisons account for them):
| Area | Prototype | Production |
|---|---|---|
| Rewards | simulated embers | XP per backend §10.1 (incl. `recitation_passed` 3 XP and quests); the completion screen shows `xp.total` as embers |
| Recitation | advances on Continue without checking | genuine check with inline word feedback; still advances on Continue (not through the feedback panel) and stays excluded from accuracy/combo |
| Data | sample values | live learner data (streaks, leagues, quests, achievements) |
| Narration | silent | optional play control when content provides audio (reference provides none) |

### A.3 Generator checks (the export fails if any check fails)
14 top-level steps in the order above · beat states 0–3 · hotspot coordinates and labels as in A.2 · teach highlight sequences (pillars constant 1; day arc −1, 1, 4, 4) · step 9 evidence = `timesEvidence`, step 12 source = `nisaEvidence` · scoring map as above (6 scored; 3 understand, 2 apply, 1 remember) · counts 8/7/6 and `source_count` 4 · track-specific points differ between explorer and new_muslim exactly as in the source · 14 linked term keys in Arabic / 13 in English, separate canonical Arabic displays, all 12 captured banks, ordering labels and declared decorations preserved · quote and verse text identical to Dorar/mushaf (gloss kept separately); **recitation text, segment range, audio, timings, and checker agree with the recitation's own verified Quran source** · ≤ 3 content sources · no answer data in learner fields · both languages complete · every model in `contract/qabas_contract.py` validates. If a specialist correction to prototype scripture or attribution is required, the export records it in `"_mock_corrections"` and the fixture is labelled corrected (not silently 1:1).

### A.4 Companion fixtures (generated)
`answer_salah_<step>_{correct,incorrect}.json` for every graded step (incl. misconception card on step 6 incorrect), `answer_salah_12_{pass,errors,unclear,skipped}.json`, and `session_finish_salah.json` (accuracy over 6, `duration_ms`, `layers` understanding/3 and applying/2, `remembering: null`, XP per the production rules incl. `recitation_passed`, streak). Step 2 has no fixture (no network). `_mock_answer_key` uses `{ "grade_by": "recitation_check" }` for step 12 (§10.3).

---
