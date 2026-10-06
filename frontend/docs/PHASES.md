# Build phases

The app is built in **16 phases, one at a time**. Each phase ends with a complete, verified result, a report, and a **stop**: the agent waits for the owner's go-ahead before starting the next phase. The handoff documents in `docs/handoff/` explain *how* to build; this file says *what to build next* and *when to stop*.

Progress lives in [PROGRESS.md](PROGRESS.md). A new session always starts by reading it.

## Rules for every phase

1. **Start:** read `docs/PROGRESS.md` and find the current phase. Read this phase's "Read first" list before writing code. If the previous phase isn't marked ✅ done and approved, don't start; report that instead.
2. **Stay inside the phase.** Don't build ahead. If something from a later phase is needed, add the smallest interface or placeholder and note it. Small, obvious decisions inside the phase don't need the owner: use the documented default and log it.
3. **Finish completely.** A phase is done only when every item under "Done when" is true and the "Verify" commands pass. Partial phases are reported as partial, never as done.
4. **Backend:** no backend service is running yet (backend reply, 2026-10-04), so every phase is finished in mock mode. If a backend group becomes available, also verify the feature in hybrid mode ([07 §7](handoff/07_MOCKS_AND_BACKEND_SYNC.md)).
5. **Report**, as a new entry in `docs/PROGRESS.md` and in the reply to the owner:
   - what was built (features, main files);
   - **verified**: the commands run, with their results, device/simulator, languages, mock or live;
   - **not verified**, and why;
   - prototype comparison: the screenshots compared, and any intentional differences;
   - new assumptions (`A-xx` in `docs/API_ASSUMPTIONS.md`) and open questions;
   - what the owner should check (the "Owner check" list below).
6. **Stop.** End the turn after the report. Start the next phase only when the owner says to continue.
7. **If blocked** (a failing build you can't fix, a contract contradiction, a missing asset), stop early and report the blocker with what you tried. Never skip to another phase to keep busy.

**Timeline targets** (two-day window): Day 1, Phases 1–5. Day 2 morning, Phases 6–8. Day 2 midday, Phases 9–11, which complete the demo spine (Tier A). Then Phases 12–16 as time allows (Phase 15, live integration, before the demo; Phase 16 after it if needed). If behind schedule, apply the cut order in [14_DELIVERY_PLAN.md](handoff/14_DELIVERY_PLAN.md); never cut Phases 1–11.

**Owner decisions in force (2026-10-04):** Discover replaces the Review tab (bottom bar index 1); a "Review" card appears on the Journey when cards are due, and "Your words" lives under Profile. The scene renderer is built (Phase 7). The demo build hides the "Review draft only" notices and shows no "mock" labels. The Salah lesson opens only from the developer menu. The curiosity onboarding page is built but switched off for the demo.

**Responsive web (owner, 2026-10-04):** required in every phase with UI, alongside native phone fidelity. Follow [03 §4](handoff/03_DESIGN_SYSTEM.md) for constrained widths, navigation breakpoints, resizing and narrow/short-window verification. Build and test on web in both languages with reduced motion on/off; add each product screen's checks in its own phase. Web is not deferred, and browser orientation must remain unrestricted.

---

## Phase 1 — Foundation and design system

**Goal:** the project is set up, and every reusable visual building block from the prototype exists, viewable in a component gallery in English and Arabic.

**Read first:** handoff [README](handoff/README.md) and [CLAUDE.md](../CLAUDE.md); [01](handoff/01_PRODUCT_AND_SCOPE.md), [02](handoff/02_PROTOTYPE_FIDELITY.md), [03](handoff/03_DESIGN_SYSTEM.md), [08](handoff/08_LOCALIZATION.md), [13](handoff/13_COMPONENTS.md), [15](handoff/15_CONVENTIONS_AND_DONE.md). Prototype: `lib/widgets/*`, `lib/core/services/sensory.dart`, `lib/l10n/*`, `lib/router.dart` (`fadeThrough`). Run the prototype once.

**Build:**
- Dependencies and dev dependencies from [15 §1](handoff/15_CONVENTIONS_AND_DONE.md); `analysis_options.yaml` from [15 §2](handoff/15_CONVENTIONS_AND_DONE.md); `build.yaml` for `json_serializable`.
- Design system: extend `lib/core/design_system/tokens/tokens.dart` (status palette aliases, `QBreakpoints`, `QSizes`, `QMotion.pageReverse`); add `theme/theme_x.dart`. Port every component in [13 §2](handoff/13_COMPONENTS.md) "Foundations", "Motion" and "Brand and illustration" (except `VisualView`/`OverlayLayer`, which are Phase 5), keeping code and numbers unchanged. Add the new state components from [12 §2](handoff/12_STATES_AND_ERRORS.md).
- `SensoryService` (injected, respects settings; settings can be a stub until Phase 2).
- Localization: `l10n.yaml`, `tool/merge_arb.dart`, the `common_{en,ar}.arb` fragments, `QNumbers` (Arabic-Indic digits), `context.l10n`. Write `tool/extract_prototype_strings.dart` and generate the fragments for **all** prototype interface strings now, split by feature, so later phases only consume keys.
- `tool/check_rules.sh` (script in [15 §3](handoff/15_CONVENTIONS_AND_DONE.md)).
- A debug-only **component gallery** route showing every ported component and state view in both languages, with a reduced-motion toggle (it becomes part of the developer menu later).

**Not in this phase:** networking, BLoCs for features, real screens.

**Done when:**
- [x] Every ported component matches its prototype rendering (compare against the prototype screens where it appears).
- [x] The gallery renders in English and Arabic (RTL, Arabic-Indic digits, Arabic fonts) and with reduced motion.
- [x] The gallery resizes across narrow, tablet and desktop web viewports without overflow; centred content/sheet limits and input retention are verified.
- [x] Prototype strings exist as ARB fragments in both languages; `merge_arb` passes key and placeholder parity.
- [x] `flutter analyze`, `flutter test` and `sh tool/check_rules.sh` are clean.

**Verify:** `dart run tool/merge_arb.dart && flutter gen-l10n && flutter analyze && flutter test && sh tool/check_rules.sh`, then run the gallery on the iPhone simulator. Also run `flutter build web --debug` and `flutter test --platform chrome test/widget_test.dart test/design_system/responsive_test.dart` for the responsive gallery.

**Owner check:** open the gallery: buttons (all 8 tones, press depth), cards, tags, chips, progress track (fills right-to-left in Arabic), sheets, flame and night sky, in both languages.

---

## Phase 2 — App core

**Goal:** the app's skeleton runs: configuration and demo flags, error model, networking with the mock backend, DI, router with the five-tab shell, app-wide state, characters and the developer menu.

**Read first:** [04](handoff/04_ARCHITECTURE.md), [05](handoff/05_NETWORKING_AND_API.md) §1–§5, §9 and §11, [06](handoff/06_DATA_MODELS.md) §1 and §3, [07](handoff/07_MOCKS_AND_BACKEND_SYNC.md) §1–§5 and §8, [09](handoff/09_CHARACTERS_AND_RIVE.md). Prototype: `lib/main.dart`, `lib/app.dart`, `lib/features/shell/home_shell.dart`, `lib/widgets/companion.dart`.

**Build:**
- `AppConfig` + `config/{mock,demo,hybrid,live}.json` with the demo flags from [07 §1](handoff/07_MOCKS_AND_BACKEND_SYNC.md) (`HIDE_DRAFT_NOTICES`, `CURIOSITY_ONBOARDING`); `bootstrap.dart` (portrait lock on native phones < 600 px, skipped on web, error handlers); `app.dart` (theme by locale, ARB delegates, text-scale clamp 0.9–1.35).
- `core/error` (`Result`, `Failure`s, `guard`), `core/storage` (`TokenStore` on `flutter_secure_storage`, `PreferencesStore`), `core/events/AppEventBus`.
- `core/network`: `ApiClient`, the interceptors in order, `RoutingAdapter`, `ApiException` → `Failure` mapping (including `prerequisite_unmet`), idempotency keys, the polling helper, the media URL resolver for mock assets ([05 §9](handoff/05_NETWORKING_AND_API.md)), and the `DuelSocket` interfaces (implementations later).
- `lib/mock_backend/`: router, latency, idempotency store, error injection, the fixture loader over `assets/mocks/`, `MockDb`, and the auth/profile handlers.
- Shared DTOs, entities and mappers for `User` (with `goal_anchor`), `NextStep`, `ErrorEnvelope`; the `test/contract/` harness (decode tests over `assets/mocks/contract/MANIFEST.json` and `assets/mocks/examples/INDEX.json`, reporting coverage).
- get_it composition root; go_router with `fadeThrough`, the guard skeleton and `HomeShell` with the five tabs **Journey · Discover · Raqeeb · Community · Profile** (bottom bar; side rail ≥ 840 px; night-toned on Journey), as placeholder screens.
- App-wide state: `AppSessionBloc` (statuses only for now), `LocaleCubit`, `PreferencesCubit`.
- Characters: vocabulary, `CharacterSpec` + `guide_traveler` spec, `CharacterRegistry`, `CharacterAssetCache`, `RiveCharacterRig`, `PainterCharacterRig` (lantern), `CharacterController`, `CharacterView`, `CharacterSettingsCubit`, `integration_test/character_contract_test.dart`.
- The developer menu (debug and demo-developer builds only), with the mock toggles from [07 §5](handoff/07_MOCKS_AND_BACKEND_SYNC.md). The lesson launchers in it (Salah preview, Unit 0 picker) are wired in Phase 5.

**Not in this phase:** real screens and feature BLoCs.

**Done when:**
- [x] The app boots in mock mode to the shell with the five tabs; the companion is visible (placeholder journey tab and gallery) and plays every cue from the developer menu.
- [x] Switching language in the developer menu flips the whole app to Arabic RTL instantly.
- [x] A test request through `ApiClient` reaches the mock backend with all required headers; the error envelope maps to the right `Failure`s (unit tests for each status code, including `409 prerequisite_unmet`).
- [x] The contract decode harness runs and prints its coverage; `User`/`NextStep`/`ErrorEnvelope` decode.
- [x] The character contract test passes on the simulator; a missing `.riv` shows the flame fallback.
- [x] The shell retains its selected tab when resized across the web viewport matrix, with no overflow in either language or motion setting; the real companion renders in Chrome.
- [x] analyze, test and rules are clean.

**Verify:** `flutter analyze && flutter test && sh tool/check_rules.sh`; `flutter run --dart-define-from-file=config/mock.json`; `sh tool/test_web.sh`; `flutter build web --debug --dart-define-from-file=config/mock.json`; `flutter test --no-pub integration_test/character_contract_test.dart -d <simulator> --dart-define-from-file=config/mock.json` (prepare the iOS configuration first as described in [README](../README.md)).

**Owner check:** the app opens to the five-tab shell (night bar on Journey, light elsewhere); the companion moves; the language switch works.

---

## Phase 3 — Splash, bootstrap and onboarding · Tier A · backend group `auth` (+ `profile`)

**Goal:** a fresh install goes from the splash animation through onboarding to the journey tab, exactly like the prototype.

**Read first:** [10](handoff/10_SCREENS_AND_FLOWS.md) S1, S2; [05 §5](handoff/05_NETWORKING_AND_API.md); [08 §6](handoff/08_LOCALIZATION.md) (curiosity copy); [12](handoff/12_STATES_AND_ERRORS.md) (splash, onboarding rows); `docs/contract/01_PRODUCT/CURRICULUM_AND_LEARNING_DESIGN.md` "Onboarding by curiosity". Prototype: `lib/features/splash/splash_screen.dart`, `lib/features/onboarding/onboarding_flow.dart`. Screenshots `docs/prototype/screens/01`–`08`.

**Build:** auth feature (`AuthRemoteDataSource`, repository, `CreateGuestSession`, `LoadCurrentUser`, `AppSessionBloc` bootstrap with the non-looping `401` path and the session-ended sheet), the `426` blocking screen, the splash page, the onboarding feature (`OnboardingBloc`; the prototype's 7 pages plus "Prefer not to say"; `POST /onboarding` with `goal_anchor`; the local discreet-reminders preference), **the curiosity page** (page 4 of 8: the six goal anchors, skippable, then the bridge) **behind `CURIOSITY_ONBOARDING`**, the router guards, companion cues per page, and the auth/onboarding mock handlers (Explorer and "Prefer not to say" → Unit 0; New Muslim → Unit 1).

**Done when:**
- [x] Fresh install → splash → 7 pages → journey tab (flag off; demo default). Reopening the app goes straight to the journey. `goal_anchor` is sent as `null`.
- [x] With the flag on and copy present in `assets/onboarding/curiosity.json`, the curiosity page appears as page 4, built from the onboarding components; skipping sends `null`; a choice shows its bridge and never changes the start unit. With the flag on but copy missing for the current language, the page is skipped.
- [x] The language chosen on page 1 applies immediately; Arabic onboarding is fully RTL.
- [x] Developer menu: "revoke token" → session-ended sheet → new guest → onboarding (no loop); "426" → blocking screen.
- [x] Submit failure keeps the answers and shows the inline error with retry.
- [x] It matches screenshots `01`–`08` side by side (spacing, companion size and position, bubbles, option tiles, goal bars, toggles).
- [x] BLoC tests for bootstrap and onboarding (success, failure, retry, flag on and off); analyze, test and rules are clean.

**Owner check:** delete the app, install, go through onboarding in English, then again in Arabic.

---

## Phase 4 — Journey and Discover · Tier A · backend groups `journey`, `profile`

**Goal:** the Journey tab shows the learner's path with prerequisite-based access (Soft Lock), and the Discover tab lists the lessons that can be explored now, both from `GET /journey`.

**Read first:** [10](handoff/10_SCREENS_AND_FLOWS.md) S3, S22, Review card; [02 §5](handoff/02_PROTOTYPE_FIDELITY.md); [06 §4](handoff/06_DATA_MODELS.md) journey; [07 §4](handoff/07_MOCKS_AND_BACKEND_SYNC.md) journey handler; `docs/contract/01_PRODUCT/CURRICULUM_AND_LEARNING_DESIGN.md` "Roadmap and Discover", "Curriculum position versus prerequisites". Prototype: `lib/features/journey/journey_screen.dart`, `journey_widgets.dart`, `lib/widgets/unit_art.dart`. Screenshots `09`, `10`, `38`.

**Build:** journey feature (DTOs with `standalone_eligible` and `soft_lock`, mappers, `GetJourney`, `GetNextStep`, `GetStats`, `JourneyBloc`), the app bar with path chip and switch sheet (`PATCH /me` track; switching to New Muslim removes Unit 0) and stat chips, the night sky brightening with progress, the Today card, the **Review card** (shown only when `next_step.due_reviews_count > 0`; opens card review in Phase 12), unit banners, the winding path, nodes by type and state, the current node with START bubble and companion, the anchored popover (Start → lesson intro route, a placeholder until Phase 5), **the Soft Lock sheet** for locked nodes (and for `409 prerequisite_unmet`), coming-soon units, the horizon; the **Discover** feature (`DiscoverBloc` over the same journey data: standalone lessons grouped by unit, completed ones marked, one general notice); loading, empty and error states; the journey mock handler porting `compute_journey()` from `tool/build_demo_curriculum.py` over `assets/mocks/demo_curriculum/curriculum.json`.

**Not in this phase:** the unit guide sheet (Phase 12), invitations badge (Phase 13).

**Done when:**
- [x] Explorer: Unit 0 shows 0.1 available and 0.2–0.12 locked; tapping a locked lesson opens the Soft Lock sheet naming its prerequisite with a button to `start_with` (0.1). Unit 1's 1.1 is available (position isn't a prerequisite); Units 2–10 are coming soon.
- [x] New Muslim: no Unit 0; Unit 1 starts at 1.1. Switching track keeps progress and refetches the journey.
- [x] Discover lists lesson 1.1 (the only standalone lesson in the demo data) and opens it through the same lesson route.
- [x] Mock progression: marking a lesson completed in the developer menu unlocks the next lessons exactly as `compute_journey()` does (unit test comparing both on the curriculum).
- [x] It matches screenshots `09` and `10` (sky, path, node glyphs, START bubble, popover anchoring, chips); Soft Lock sheet and Discover follow the prototype's sheet and card styles.
- [x] Arabic layout correct; scenes and art not mirrored; coming-soon units without an Arabic title show the English title (A-30).
- [x] Mapper tests with the demo journeys; BLoC tests including failure, refresh and track switch; analyze, test and rules are clean.

**Owner check:** both tracks in both languages; tap a locked lesson; open Discover.

---

## Phase 5 — Lesson I: content, intro and player · Tier A · backend group `sessions`

**Goal:** lessons open from the journey and every **content** step plays like the prototype, for the Unit 0 lessons, lesson 1.1 and the Salah reference; exercise steps show a placeholder that can be continued past.

**Read first:** [11](handoff/11_SESSION_PLAYER.md) §1–§3 and §5; [06 §2, §5](handoff/06_DATA_MODELS.md); [10](handoff/10_SCREENS_AND_FLOWS.md) S4a, S7, S8; `docs/contract/04_FRONTEND/FRONTEND_HANDOFF.md` Appendix A. Prototype: `lib/features/lesson/lesson_intro_screen.dart`, `lesson_screen.dart`, `lesson_session.dart`, `steps/*`, `feedback_panel.dart`, `lib/widgets/scenes.dart`, `term_text.dart`, `steps/evidence_card.dart`. Screenshots `11`–`17`, `19`, `21`, `26`, `33`.

**Build:** shared content entities, DTOs and mappers (Span, Sentence, Source, Evidence, TermCard, Visual, Overlay); `SpanText`, `TermSheet`, `SourcesSheet` + long-press sentence sources, `EvidenceCard`, `QuranText`/`HadithText`; `VisualView` with the four built-in scenes (painter code unchanged), per-use proportions, image visuals, **scene visuals as their fallback still for now** (the renderer is Phase 7), and overlays; the term-state store; session DTOs and mappers (story `origin` nullable); `StartLessonSession` (a `409 prerequisite_unmet` opens the Soft Lock sheet); the lesson intro page (hides the sources figure and drawer when `source_count` is 0, and the reviewed badge when `reviewed_by` is null); the session player page (top bar, progress, action bar, quit sheet); step BLoCs and views for hook, predict, story (**sourced story and teaching scenario**), teach (standard and summary, **with or without a visual**), paragraph, evidence, visual, callout; the feedback panel (neutral predict variant now); the session mock handlers (Unit 0 sessions, lesson 1.1, Salah; in the demo flavor, the draft-notice callouts are removed); the developer-menu launchers (**Salah preview**, 4 variants; Unit 0 lesson picker).

**Done when:**
- [x] Journey → popover → intro → player for lesson 0.1 (English and Arabic) and 1.1 (both tracks); Salah opens from the developer menu.
- [x] Salah's content steps match screenshots `11`–`17`, `19`, `21`, `26`, `33` (hook, prediction, four story beats with provenance, river, pillars with Arabic labels aligned, day arc −1/1/4/4, summary).
- [x] Unit 0 teaching scenarios show their label ("Scenario") without provenance tags or an origin card; teach cards without a visual lay out cleanly; intros with no sources show no "0 sources".
- [x] With `config/demo.json`, no "Review draft only" notice appears in any Unit 0 lesson; with `config/mock.json` they appear.
- [x] Underlined terms open the term sheet; sentences show their sources on long-press where sources exist.
- [x] Progress bar rules from [11 §2](handoff/11_SESSION_PLAYER.md); scene loops run; reduced motion freezes them.
- [x] Mapper tests over the Salah, Unit 0 and 1.1 fixtures; analyze, test and rules are clean.

**Owner check:** play the content steps of 0.1, 1.1 and Salah in English and Arabic.

---

## Phase 6 — Lesson II: exercises, grading and retries · Tier A · backend groups `sessions`, `recitation`

**Goal:** every lesson in the demo data plays end to end: all its exercises, server-style grading, warm feedback, the combo flame, the misconception card and the retry round.

**Read first:** [11](handoff/11_SESSION_PLAYER.md) §2–§4 and §6; [06 §2](handoff/06_DATA_MODELS.md); [07 §4](handoff/07_MOCKS_AND_BACKEND_SYNC.md) (MockGrader, key files). Prototype: `lib/features/lesson/exercises/*`, `steps/recite_view.dart`, `feedback_panel.dart`. Screenshots `18`, `20`, `22`–`25`, `27`–`32`, `34`, `35`.

**Build:** the exercise kit (`Tile3D`, `OptionTile`, `Token`), answer drafts (pure Dart, unit-tested), the renderer registry, and renderers for every type in the demo data: `multiple_choice` (with myth framing), `categorize` buckets (**2–3 buckets**) and day arc, `scenario`, **`true_false_reason`**, **`spot_error`**, **`match_pairs`**, `order_steps` (plain and day sequence), `map_place` hotspots, `recite_verse` (listen with word highlighting when audio exists; "audio isn't available yet" state; skip; recording waits until Phase 13; **never simulate a passed recitation**); `SubmitAnswer` with the mock grader over the private keys (Salah, Unit 0, 1.1); feedback panel for correct / not quite / neutral with companion cues and sounds; the misconception card; combo flame at 3; the retry round; `FinishSession` (result stored, navigation to a placeholder result page until Phase 8).

**Done when:**
- [x] Salah's 14 steps play in all four variants with one deliberate wrong answer (clay feedback, misconception card, retried in the retry round).
- [x] All 12 Unit 0 lessons (ar/en) and 1.1 (four variants) play end to end through the mock grader; lessons without explanations (1.1) show the feedback title without an empty gap.
- [x] Each Salah exercise matches its screenshots; the new types use the kit's tile states, sounds and spacing; three buckets fit a phone width at text scale 1.35.
- [x] Recitation is excluded from accuracy and combo, completes on Continue, and in the demo shows the unavailable state with skip.
- [x] Submit failure keeps the answer and offers retry; repeated submits are safe.
- [x] Draft and grader unit tests for every type; BLoC tests for the player flow including retries; analyze, test and rules are clean.

**Owner check:** play Salah perfectly and with mistakes; play 0.1 and one later Unit 0 lesson; play 1.1.

---

## Phase 7 — Scene renderer · Tier A

**Goal:** generated animated scenes (`Visual.kind = scene`) render live in the app, change state as story beats and teaching points advance, and match the backend's stills.

**Read first:** `docs/contract/07_ANIMATION/SCENE_RENDERER_SEMANTICS.md` (normative, all sections), `docs/contract/03_API/contract_revision10/contract/scene.schema.json`, API §5.5e (`docs/contract/03_API/API_REQUIREMENTS.md`), [11 §5](handoff/11_SESSION_PLAYER.md), [09 §1](handoff/09_CHARACTERS_AND_RIVE.md) (renderer vs Rive). Data: the 20 manifests in `assets/mocks/unit0/media/scenes/`, the 86 stills in `media/fallbacks/` and their states in `assets/mocks/unit0/MEDIA_INDEX.json`.

**Build:** a local Dart package **`packages/qabas_scene/`** (path dependency, no app imports) with:
- manifest DTOs and validation of the parts the renderer relies on; SHA-256 check against `SceneRef.sha256` (mismatch → fallback);
- the **released capability list of this app build**: exactly `scene/1`, `shape.rect/1`, `shape.ellipse/1`, `shape.path/1`, `paint.gradient/1`, `track/1`, `fx.sparkles/1` (a scene requiring anything else renders its `fallback_image`, never a partial scene);
- painting per the semantics: view-box scaling, depth-first layer order, `rect`/`ellipse`/`path` (SVG subset M L H V C Q Z, absolute and relative, non-zero fill), palette colours and linear/radial gradients, transforms and opacity;
- property resolution: base values → state rules ("last match wins") → transitions from the displayed value with the new rule's duration and easing → tracks (`translate_x/y`, `rotation`, `scale`, `opacity`; easing; `none`/`repeat`/`ping_pong`; `active_when`);
- sparkles with the specified PRNG and its test vectors;
- the scene clock (runs across state changes in one mounted renderer, pauses when not visible); reduced motion = the still at `reduced_motion.still_time_ms`, state changes without transitions;
- a `SceneView` widget for `VisualView`: loads and caches by `scene_id`/`version`/`sha256`, applies `Visual.params` and the step's state changes, falls back to `fallback_image` then to the `alt` placeholder.

**Done when:**
- [x] Every Unit 0 lesson's scenes render live; teach points and story beats change state with the authored transitions; nothing is mirrored in RTL.
- [x] For every still in `MEDIA_INDEX.json`, the renderer's frame at the same state and time matches the still closely (golden comparison test with a stated pixel tolerance; differences listed in the report, since the stills come from the backend's non-normative renderer).
- [x] PRNG test vectors pass; reduced motion shows the specified still; an unknown capability, a bad checksum and a missing manifest each show the fallback.
- [ ] Smooth on the iPhone simulator and a mid-range Android device with a scene on screen (frame timings in the report).
- [x] Package unit tests cover state rules, transitions, track timing and easing; analyze, test and rules are clean.

Implementation and software verification completed on 2026-10-05. The iPhone
simulator passes the timing targets. The supplied Android emulator was verified
in debug/profile builds, but cannot establish physical mid-range Android
performance; its worst profile p95 build+raster is 20.91 ms against the 8 ms
reference-device target. Phase 7 remains blocked on that device check; see
[the report](PROGRESS.md#phase-7--scene-renderer--2026-10-05--physical-android-verification-pending).

**Owner check:** play lesson 0.1 and watch the scenes respond as each point is revealed; turn on reduced motion.

---

## Phase 8 — Completion and streak · Tier A · backend groups `sessions`, `profile`

**Goal:** finishing a lesson shows the prototype's completion and streak celebration with server results, and the journey reflects the progress (the next lessons unlock).

**Read first:** [10](handoff/10_SCREENS_AND_FLOWS.md) S5, S5b; [06 §5](handoff/06_DATA_MODELS.md) `SessionResult`; [07 §4](handoff/07_MOCKS_AND_BACKEND_SYNC.md) (MockFinisher). Prototype: `lib/features/lesson/lesson_complete_screen.dart`, `lib/features/streak/streak_screen.dart`. Screenshots `36`–`38`.

**Build:** `SessionResultBloc` (cached result or idempotent re-finish), the result page (count-ups, mastery card with Understanding/Applying bars and the Remembering placeholder, review topics, challenge, check-in, next step), the streak celebration (rolling number, week row, companion streak cue), the MockFinisher (Salah: accuracy over 6, Understanding over 3, Applying over 2; Unit 0 and 1.1 from their scoring), and the `SessionCompleted`/`TermsMastered`/`XpChanged` events refreshing the journey (Soft Locks recomputed), Discover and the stat chips.

**Done when:**
- [x] Finishing 0.1 shows completion → streak (first lesson of the day) → journey with 0.1 completed and 0.2 available.
- [x] A lesson finished from Discover (1.1) shows completed on the Journey too.
- [x] It matches screenshots `36`–`38`; Arabic correct; count-ups jump to final values with reduced motion.
- [x] MockFinisher unit tests match the contract finish example (`assets/mocks/contract/workflows/ses_91ab.json`) and the Salah expectations; analyze, test and rules are clean.

**Owner check:** finish 0.1 and watch the full celebration, then the updated journey.

---

## Phase 9 — Raqeeb · Tier A · backend group `raqeeb`

**Goal:** the learner asks Raqeeb a text question and gets a sourced answer, with stage labels while it works, exactly in the prototype's style.

**Read first:** [10](handoff/10_SCREENS_AND_FLOWS.md) S10/S11; [05 §6](handoff/05_NETWORKING_AND_API.md) polling; [12](handoff/12_STATES_AND_ERRORS.md) Raqeeb rows; [03 §2](handoff/03_DESIGN_SYSTEM.md) status palette. Prototype: `lib/features/raqeeb/raqeeb_screen.dart`. Screenshots `43`–`46`.

**Build:** raqeeb feature (DTOs including the `AssistantMessage` status union and the five answer blocks, `StartConversation`, `SendRaqeebMessage` with idempotency, `WatchAssistantMessage` polling, `RateAnswer`), `RaqeebChatBloc`, the welcome state with trust points and suggestion chips, the composer (text; attachments wait for Phase 13), user and answer bubbles, the understood-input row, classification chip, paragraph with citations and terms, evidence, verification cards (5 statuses), differing views, referral card, citations list, suggested lessons, failed and timeout states, the lantern character (thinking/speaking), and the Raqeeb mock handlers with the outcome picker. No "mock" label in the UI.

**Done when:**
- [x] A question shows the user bubble immediately, localised stage labels while processing, then the answer; all nine outcomes from the developer picker render correctly (A–H and failed).
- [x] `not_found` is never styled like fabricated; the composer is disabled while an answer is processing.
- [x] It matches screenshots `43`–`46` (with the intentional difference A-06 noted).
- [x] Decode tests for all eight completed examples; BLoC tests for send, poll, fail, timeout and retry; analyze, test and rules are clean.

**Owner check:** ask the suggested questions in both languages; pick each outcome in the developer menu.

---

## Phase 10 — Profile, settings and about · Tier A · backend group `profile`

**Goal:** the Profile tab, settings and about page work like the prototype, including the instant language switch and the new "Your words" entry.

**Read first:** [10](handoff/10_SCREENS_AND_FLOWS.md) S12; [08 §5](handoff/08_LOCALIZATION.md). Prototype: `lib/features/profile/profile_screen.dart`, `lib/features/settings/settings_screen.dart`, `about_screen.dart`, `lib/features/review/review_screen.dart` ("Your words" section). Screenshots `53`, `55`, `56`, `39`.

**Build:** `ProfileBloc` (me, stats, achievements row), display-name edit, the **"Your words" row** (count and a preview of terms; opens the glossary, a placeholder until Phase 12), `SettingsBloc` (language, track, goal, private profile, and the curiosity question when `CURIOSITY_ONBOARDING` is on, via `PATCH /me` with optimistic update and revert), local preferences (sound, haptics, reduced motion, discreet reminders, characters on/off), the about page using `Scripture.taha10` from `lib/shared/content/bundled_scripture.dart`.

**Done when:**
- [x] Changing the language in Settings switches the whole app between English and Arabic instantly, and persists; a failed save reverts with a snackbar.
- [x] Sound, haptics, reduced motion and characters-off take effect everywhere built so far.
- [x] It matches screenshots `53`, `55`, `56`; "Your words" follows the prototype's words section style; analyze, test and rules are clean.

**Owner check:** switch to Arabic in Settings and walk through every screen built so far.

---

## Phase 11 — Demo spine: fidelity pass · Tier A complete

**Goal:** the whole Tier A spine is proven against the prototype, screen by screen, and is ready to demo with `config/demo.json`.

**Read first:** [02 §7](handoff/02_PROTOTYPE_FIDELITY.md); [15 §5](handoff/15_CONVENTIONS_AND_DONE.md) "demo-ready"; [14](handoff/14_DELIVERY_PLAN.md) demo script.

**Build:** port the prototype's screenshot tour to `integration_test/tour_test.dart` (same screen names; Salah through the developer launcher; plus the new screens: Discover, Soft Lock sheet, a Unit 0 lesson with scenes); capture the app's screens; produce side-by-side comparisons with `docs/prototype/screens/` (for example with a small Pillow script into `build/compare/`); fix every unintended difference; run the Arabic and reduced-motion passes; run every developer-menu failure toggle on the spine screens.

**Done when:**
- [x] Every Tier A screenshot pair is indistinguishable except for listed intentional differences.
- [x] The demo script ([14](handoff/14_DELIVERY_PLAN.md)) runs start to finish with `config/demo.json` in both languages without a crash, with no draft notices and no mock labels visible.
- [x] Failure toggles (`426`, `401`, `503`, offline) recover gracefully on these screens.

**Owner check:** review the side-by-side sheets, and run the demo script yourself.

---

## Phase 12 — Review, glossary and the rest of learning · Tier B · groups `sessions`, `glossary`, `journey`

**Build:** card review (flip cards, ratings without intervals, A-05) opened from the Journey's Review card, quick review with its 20 s timer, the glossary ("Your words", from Profile) with filters and paging, the unit guide sheet, the remaining exercise renderers (`fill_blank`, `which_evidence`, `timeline_order`, `map_place` map pins, `verse_meaning`, `flashcard`), pretest and unit-test sessions (feedback modes `none`/`end`, answer review), the lesson reader, and resume (local session state + recovery rules).

**Done when:** every exercise type in `assets/mocks/contract/sessions/session_practice_all_types.json` renders and grades through the mock; all four session kinds play; the contract test curriculum (`assets/mocks/contract/curriculum_test/`) plays without lesson-specific code; screenshots `40`–`42` and `57` match; resume works after killing the app mid-lesson; analyze, test and rules are clean.

**Owner check:** do a card review from the Journey; open "Your words"; play the practice session with every exercise type.

---

## Phase 13 — Community, challenges and media · Tier B · groups `community`, `challenges`, `recitation`, `raqeeb`, `profile`

**Build:** the community tab (league with promotion zone and the `no_league_this_week` empty state, daily quests, friends with invite share and accept), challenges on the fake socket (lobby, countdown, questions with draining timers, reveal, results, reconnect), the invitations badge, the achievements screen, the streak calendar, recitation recording and checks (permissions, errors, unclear, busy; never a simulated pass in the demo), Raqeeb attachments (image, document, voice) and conversation history, and delete account.

**Done when:** screenshots `47`–`52` and `54` match; a full bot duel and the 4-player group script play on the fake socket including a disconnect/reconnect; the recitation flow handles every outcome; analyze, test and rules are clean.

**Owner check:** play a challenge against the bot; record a recitation; send Raqeeb a photo.

---

## Phase 14 — Reviewer console · groups `auth` (reviewer), `reviewer`

**Goal:** a reviewer signs in and reviews AI-generated lessons: the lesson plan at Gate 1 and the full draft at Gate 2, then approves, requests changes or rejects; plus the runs list, blind test and a metrics dashboard. Same design language as the learner app, but **a calm professional tool: no gamification**.

**Read first:** [10](handoff/10_SCREENS_AND_FLOWS.md) R1–R6; API §6.11 and the reviewer shapes (`FactoryRun`, `LessonPlan`, `Draft`, `ReviewerExercise`, `QAReport`, `Gate1`, `Gate2`, `BlindPair`, `Metrics`) in `docs/contract/03_API/API_REQUIREMENTS.md` and `contract_revision10/contract/qabas_contract.py`; `review.py` (the `review_digest`); `docs/contract/04_FRONTEND/FRONTEND_HANDOFF.md` R1–R6; `docs/contract/01_PRODUCT/CURRICULUM_AND_LEARNING_DESIGN.md` "Lesson completeness and depth" (what Gate 1 checks). Data: `assets/mocks/reviewer/u0l1.factory_run.json`, `u1l1.factory_run.json` (real runs at `awaiting_gate2`, validated) and the reviewer examples in `assets/mocks/examples/` (`AuthResp`, `RunCreate`, `Page[RunRow]`, `FactoryRun`, `Gate1`, `DraftFragment`, `Gate2`, `BlindPair`, `BlindAnswer`, `Metrics`).

**Design rules (reviewer surfaces):**
- Same tokens, typography, `QCard`, `QButton`, `Tag`, sheets, motion curves and RTL rules as the learner app; light `morningMint` surfaces, with the night palette only for the sign-in header.
- **No gamification:** no embers, streaks, XP, combo flames, celebrations, companion character, confetti or reward sounds. Sounds and haptics only for errors and confirmations.
- Work-tool density: tablet and web first (side rail ≥ 840 px, two-pane layouts: list + detail, Arabic and English side by side); still usable on a phone.
- Status colours from the status palette (`QColors` status aliases): blockers in `statusFabricated` (clay, labelled), warnings in `statusCaution`, info in `statusUnknown`. Never alarming red.

**Build:** a `reviewer` feature (domain/data/presentation like every feature; routes under `/reviewer/*`, shown only when `role = reviewer`):
- **R1 Sign in** (`POST /auth/reviewer`, email + password, 12 h token, lockout message); entry from the developer menu in dev/demo builds and from a hidden route `/reviewer/login`.
- **Shell:** its own rail/bar (Runs · Blind test · Metrics · Sign out); a learner token can never open it (`403` → back to the learner app).
- **R2 Runs:** paged list with status filter (`running`, `awaiting_gate1`, `awaiting_gate2`, `published`, `rejected`, `failed`), stage progress per run, and the "New run" form (`POST /admin/factory/runs` with `Idempotency-Key`).
- **R3 Gate 1, plan review:** primary outcome, central question, supporting understandings, depth profile, objectives (≤ 3), prerequisite and introduced concepts, standalone decision, reasoning tools with justifications, the lesson arc (steps with technique), minutes and budgets against the targets; edit fields; Approve / Reject with note.
- **R4 Gate 2, draft review:** variant picker (language × track) with Arabic and English side by side; the draft rendered with the **learner renderers** (session player views in a read-only preview mode, scenes included); per-sentence panel with role, claim, basis and evidence plus semantic-review flags; arc map (which blocks realise each step); reviewer exercises with answer keys; QA report grouped by severity and kind; visuals list with "Regenerate image"; sentence edits (an Arabic edit requires the matching English edit); Approve (disabled while any blocker remains) / Request changes / Reject.
- **Digest safety:** every gate request echoes the run's `review_digest`; `409 review_stale` → reload the run and ask the reviewer to look again; validation errors from Approve show inline.
- **R5 Blind test:** two anonymised lessons side by side and the three questions.
- **R6 Metrics dashboard:** `GET /admin/metrics` as clear stat tiles and simple charts (follow the `dataviz` skill for chart colours and marks); `null` values show "Not measured yet".
- Mock handlers: runs list from the two real runs plus the examples; gate decisions move the run to the next status; the stale-digest toggle in the developer menu; "Regenerate image" returns `202` and keeps the placeholder.

**Done when:**
- [x] Sign in → runs list → open the u0l1 run → Gate 2 shows both languages, the evidence panel, arc map, QA report and the learner-rendered preview; an Arabic edit without its English pair is refused; Approve is disabled while blockers remain; Request changes and Reject work.
- [x] A Gate 1 example run can be edited and approved; a stale digest (developer toggle) reloads and asks again.
- [x] Blind test and metrics render from the examples, with empty and error states.
- [x] No gamification element appears anywhere in `/reviewer/*` (checked by a widget test that scans for the embers/streak/companion widgets).
- [x] Works in English and Arabic, on phone and tablet/web widths; a learner token can't reach it.
- [x] Decode tests for every reviewer root used; BLoC tests for gate actions including `review_stale`; analyze, test and rules are clean.

**Owner check:** sign in as reviewer, review the u0l1 draft end to end in both languages, and look at the dashboard.

---

## Phase 15 — Live integration and demo hardening


**Build:** for every backend group that becomes ready: run `tool/contract_smoke.dart`, switch it live in `config/hybrid.json`, play the feature in both languages, fix mismatches with the protocol in [07 §7](handoff/07_MOCKS_AND_BACKEND_SYNC.md), and update the status table in `docs/API_ASSUMPTIONS.md`. Then the demo build: `config/demo.json` final (hybrid with verified groups live, otherwise mock), the developer menu reachable only by the hidden gesture, a release-bundle check that private keys aren't shipped to anything beyond the demo, and two full rehearsals of the demo script on the demo device.

**Done when:** every live-verified group is marked with a date (or the report states that no backend was available); the demo script runs twice in a row on the demo device without a crash; known issues are listed in `docs/PROGRESS.md`.

**Owner check:** the final rehearsal.

---

## Phase 16 — Raqeeb's Rive lantern and more characters (after the demo, if needed)

**Goal:** Raqeeb's lantern becomes a Rive animation, and the guide role gets more characters, cast per lesson, all without touching screens, BLoCs or the API.

**Read first:** [09](handoff/09_CHARACTERS_AND_RIVE.md) (all; §4 contract, §5 specs, §9 adding a character, §10 planned extensions), the `rive` skill, `tool/rive/guide_traveler/README.md` (the generator and `build.sh` workflow with the Rive CLI at `~/.rive/bin/rive`), `docs/contract/01_PRODUCT/CONTENT_AND_BRAND_POLICY.md` (imagery rules).

**Build:**
- **Raqeeb lantern** (`raqeeb_lantern`): authored with the same generator approach in `tool/rive/raqeeb_lantern/` → `assets/characters/raqeeb_lantern/raqeeb_lantern.riv`, following the [09 §4](handoff/09_CHARACTERS_AND_RIVE.md) contract: moods `idle` (soft flame), `thinking` (flame breathing), `listening` (flame leaning toward the learner), `speaking` (warm pulse); cues it supports (for example `greet`, `correct`). Its spec replaces the painter rig for the `assistant` role; `LanternGlyph` stays the loading and failure fallback. Nav-bar icon stays the static glyph.
- **More guide characters:** 2 new characters (for example a young woman in a modest headscarf and travelling cloak, and an older man with a walking staff), both ordinary modern people with **completely blank faces**, modest clothing, no text, the same palette, the same state machine and view-model contract (moods `idle`/`thinking`, ideally `listening`/`speaking`; all seven cues). Add `listening` and `speaking` to the guide traveller too ([09 §10](handoff/09_CHARACTERS_AND_RIVE.md)).
- **Per-lesson casting** (client-only, never in the API, AD-06): `CharacterRegistry` holds a **pool** for the `guide` role. A `CharacterCasting` service picks the lesson's companion deterministically from the lesson ID (stable hash → pool index), so a lesson always has the same companion, also on resume and in both languages; outside lessons (onboarding, journey, profile) the default traveller appears. Optional fixed assignments in `assets/characters/casting.json` (`lesson_id → character_id`) override the hash. Settings → characters off still hides all of them; the developer menu can force a character for checking.
- `integration_test/character_contract_test.dart` covers every new `.riv`; contact sheets of each state in `tool/rive/<id>/shots/`.

**Done when:**
- [ ] Raqeeb's lantern animates through idle → listening (recording) → thinking (processing) → speaking (answer) in the chat, in both languages, with reduced motion leaving it calm.
- [ ] Two new guide characters pass the contract test, and every cue placement in [09 §2](handoff/09_CHARACTERS_AND_RIVE.md) looks right with each of them.
- [ ] Different lessons show different companions; the same lesson always shows the same one (unit test over the demo curriculum); a fixed assignment in `casting.json` wins.
- [ ] Faceless at every frame; no text; no depiction of prophets, companions or historical figures (owner review of the contact sheets).
- [ ] analyze, test and rules are clean.

**Owner check:** open three lessons and see their companions; chat with Raqeeb and watch the lantern.
