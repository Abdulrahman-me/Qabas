# Qabas · قبس — production Flutter app: build handoff

This folder is the complete brief for a coding agent that builds the **production Flutter app** of Qabas. It turns the prototype (how the app must look, feel and move) and the engineering handoff (what the backend serves and how the product behaves) into one buildable plan. **What to build next is in [`docs/PHASES.md`](../PHASES.md)**, one phase at a time, with progress in [`docs/PROGRESS.md`](../PROGRESS.md). These documents explain how to build it.

The backend is built **at the same time** by another engineer against the same contract. The window is about **two days** (competition). Everything here is written so that you can start immediately, work against mocks, and switch each feature to the live backend the moment its endpoints exist, without touching UI code.

## Where everything is

Paths like `lib/…`, `assets/…`, `tool/…` and `docs/…` are inside the app, `/Users/aw/StudioProjects/qabas/` (package `qabas`, application/bundle id `com.rw.qabas`).

| What | Where | Notes |
|---|---|---|
| Phase plan and progress log | `docs/PHASES.md`, `docs/PROGRESS.md` | Start every session with `PROGRESS.md` |
| These handoff documents | `docs/handoff/` | How to build: architecture, design system, screens… |
| Contract and product reference | `docs/contract/` | Read-only excerpt of the engineering handoff, in its original folder layout. **Paths in these documents that start with a numbered folder (`03_API/…`, `04_FRONTEND/…`, `07_ANIMATION/…`, `00_REVIEW/…`) are inside `docs/contract/`.** See its README. |
| Prototype screenshots | `docs/prototype/screens/` (57, English) | Index by screen and phase in `docs/prototype/README.md` |
| Assumptions log | `docs/API_ASSUMPTIONS.md` | Shared with the backend engineer |
| Agent rules | `CLAUDE.md` (repo root) | Loaded automatically by Claude Code |
| **Prototype source** (read-only, outside the app) | `/Users/aw/Documents/qpr/qabas/` | Also named `qabas`; never edit it, never import from it. "Proto `lib/…`" means a path inside it. |
| Original engineering handoff (read-only, outside the app) | `/Users/aw/Documents/qpr/FINAL_ENGINEERING_HANDOFF/` | The source of `docs/contract/`. It has strict integrity checks; never write into it. |

## Read in this order

| # | Document | Read it to learn |
|---|---|---|
| — | [PHASES.md](../PHASES.md) · [PROGRESS.md](../PROGRESS.md) | What to build now, the stop-and-report rule, and where the work stands |
| 0 | [CLAUDE.md](../../CLAUDE.md) | The condensed rules (repo root, loaded automatically) |
| 1 | [01_PRODUCT_AND_SCOPE.md](01_PRODUCT_AND_SCOPE.md) | What Qabas is, who it serves, the full scope and the demo tiers |
| 2 | [02_PROTOTYPE_FIDELITY.md](02_PROTOTYPE_FIDELITY.md) | How to treat the prototype; screen → file map; what is fake and how to replace it |
| 3 | [03_DESIGN_SYSTEM.md](03_DESIGN_SYSTEM.md) | Every token and component style, extracted from the prototype |
| 4 | [04_ARCHITECTURE.md](04_ARCHITECTURE.md) | Clean architecture, folders, BLoC, use cases, repositories, get_it, navigation |
| 5 | [05_NETWORKING_AND_API.md](05_NETWORKING_AND_API.md) | Dio client, headers, errors, polling, uploads, WebSocket, endpoint map |
| 6 | [06_DATA_MODELS.md](06_DATA_MODELS.md) | DTO → mapper → entity, unions, rich text, entity catalog |
| 7 | [07_MOCKS_AND_BACKEND_SYNC.md](07_MOCKS_AND_BACKEND_SYNC.md) | Mock backend, hybrid live/mock switching, fixtures, contract tests, working with the backend engineer |
| 8 | [08_LOCALIZATION.md](08_LOCALIZATION.md) | ARB setup, key naming, plurals, digits, RTL, server vs bundled strings |
| 9 | [09_CHARACTERS_AND_RIVE.md](09_CHARACTERS_AND_RIVE.md) | Multi-character Rive system, states, cues, fallbacks, adding characters |
| 10 | [10_SCREENS_AND_FLOWS.md](10_SCREENS_AND_FLOWS.md) | Every screen: prototype source, BLoC, use cases, endpoints, states |
| 11 | [11_SESSION_PLAYER.md](11_SESSION_PLAYER.md) | The lesson engine: steps, exercises, visuals, feedback, retries, resume, finish |
| 12 | [12_STATES_AND_ERRORS.md](12_STATES_AND_ERRORS.md) | Loading, empty, error, retry, offline and blocking states |
| 13 | [13_COMPONENTS.md](13_COMPONENTS.md) | Reusable component catalog and where each one comes from |
| 14 | [14_DELIVERY_PLAN.md](14_DELIVERY_PLAN.md) | Priorities, the phases at a glance, two-day timeline, demo script, cut order |
| 15 | [15_CONVENTIONS_AND_DONE.md](15_CONVENTIONS_AND_DONE.md) | Coding conventions, tests, checks and the definition of done |
| — | [docs/API_ASSUMPTIONS.md](../API_ASSUMPTIONS.md) | The assumptions log (pre-filled with 21 entries); update it whenever you rely on something the contract doesn't state |

## The rules that override everything else

1. **The prototype is the visual and UX specification.** Port its widgets, painters, tokens, spacing, motion and wording. Do not redesign, "modernise" or reinterpret. The production app should read as a refined implementation of the prototype.
2. **The prototype is not the engineering specification.** Its `AppState`, local curriculum, local grading, scripted Raqeeb and simulated community are demo plumbing. Rebuild that plumbing with production patterns and keep the experience identical.
3. **The wire contract is `FINAL_ENGINEERING_HANDOFF` revision 10.** Never invent endpoints, fields or enum values. Write every assumption down in `docs/API_ASSUMPTIONS.md` and keep it inside the data layer.
4. **Clean architecture, organised by feature.** `presentation → domain ← data`. BLoCs hold the UI and business logic; widgets stay declarative; use cases represent actions; repositories hide data sources; get_it wires it all.
5. **No hard-coded user-facing strings.** Every visible string comes from ARB files. Content strings come from the API already localised.
6. **No raw visual constants in features.** Colours, sizes, radii, shadows, durations and curves come from the design system.
7. **Mock first, live ready, same code path.** Mock mode runs the real Dio stack against an in-app fake backend. Each feature group switches to live with configuration alone.
8. **Characters are presentation-only.** The companion (Rive) never appears in API payloads, BLoC logic or domain code, and can be swapped or removed.
9. **Content policy is binding.** Quran text uses the Quran font only and is never altered; no depictions of God, prophets, companions, angels, paradise or hell; ordinary people have blank faces; the flame is gentle; mistakes are met warmly (clay, never red).
10. **Demo first, but no dead ends.** Build the core learning flow to full fidelity first. Defer secondary features behind finished interfaces rather than shortcuts that block integration.

## Sources of truth and precedence

| Question | Authority (highest first) |
|---|---|
| How a screen looks, moves, sounds and reads | 1. Prototype source `/Users/aw/Documents/qpr/qabas/lib/` · 2. Prototype screenshots (`docs/prototype/screens/`, regenerate with the tour) · 3. `docs/contract/04_FRONTEND/FRONTEND_HANDOFF.md` §9 UI rules |
| What the server sends and accepts | 1. `docs/contract/03_API/API_REQUIREMENTS.md` · 2. `docs/contract/03_API/contract_revision10/contract/qabas_contract.py` + `qabas_contract.schema.json` · 3. Fixtures in `assets/mocks/contract/` |
| Product behaviour, scope and policy | `docs/contract/01_PRODUCT/*`, `docs/contract/02_ARCHITECTURE/ARCHITECTURE_DECISIONS.md`, `docs/contract/00_REVIEW/STATUS_AND_OPEN_DECISIONS.md` |
| What to build next, and when to stop | `docs/PHASES.md` |
| How the Flutter code is engineered | This folder |
| Anything still ambiguous | Ask the owner; meanwhile choose the documented default and log it |

The older `/Users/aw/Documents/qpr/FRONTEND_HANDOFF.md`, `/Users/aw/Documents/qpr/BACKEND_HANDOFF.md` and `/Users/aw/Documents/qpr/new/` drafts are **superseded** by the engineering handoff (`docs/contract/`). Do not build from them.

## Decisions already made

Don't reopen these; they are settled for this build.

| Topic | Decision | Why |
|---|---|---|
| Repository | The app is `/Users/aw/StudioProjects/qabas/` (package `qabas`, id `com.rw.qabas`; not yet a git repository). The prototype `/Users/aw/Documents/qpr/qabas/` stays read-only. | Keeps the visual baseline intact for comparison |
| Stack | Flutter 3.44 / Dart 3.12 · `flutter_bloc` · `get_it` · `dio` · `go_router` (as in the prototype) · `rive` 0.14.x · ARB + `flutter gen-l10n` · `json_serializable` | Owner's required stack; go_router and rive are proven in the prototype. The handoff's *suggested* Riverpod/freezed setup is replaced by owner instruction. |
| AI | All AI is **backend-mediated** through the Raqeeb endpoints. The app contains no LLM SDK, no Gemini/Claude key and no direct model calls. | The handoff puts every model call (Raqeeb, factory) in backend workers with source verification and guards |
| Mocking | A fake backend behind Dio's `HttpClientAdapter` plus a fake challenge socket; `API_MODE=mock\|live\|hybrid` with per-feature live groups | Mock mode exercises the same headers, errors, DTOs and mappers as live, so switching is configuration, not code |
| Languages | English **and** Arabic ARB files from day one (English is the template). Both are already written in the prototype. | Arabic/RTL is core to the product; adding further languages later only needs new ARB files |
| Platforms | iOS and Android, plus responsive web in every UI phase. Verify narrow/short, tablet and desktop web layouts in en/ar with reduced motion; see 03 §4. | Owner's web requirement, 2026-10-04; prototype phone fidelity is retained |
| DTOs | Written by hand with `json_serializable`, verified by decoding every contract fixture and API example in tests | A schema → Dart generator is out of reach in two days. The fixture tests give the same guarantee for the shapes we use. |
| Contract | The **amended revision 10** (`docs/contract/`, schema digest `9d67bda0…481c`, header `Qabas-Contract: 10`), frozen for the demo by the backend engineer (2026-10-04). Not yet a final sign-off (O-01). | Adds Soft Lock journeys, Discover, `goal_anchor`, fictional teaching-scenario stories; learner lesson shapes otherwise unchanged |
| Backend | No service, hosted URL or go-live date exists yet. The demo may run entirely on the mock backend; every group switches to live by configuration when it exists. | Backend reply, 2026-10-04 |
| Navigation | Bottom bar: **Journey · Discover · Raqeeb · Community · Profile**. Discover replaces the Review tab; a Review card on the Journey (when cards are due) opens card review; "Your words" lives in Profile. | Owner decision, 2026-10-04 |
| Scenes | **Build the generated-scene renderer** (`packages/qabas_scene`, Phase 7) for the seven capabilities Unit 0 uses; fall back to the backend's stills only when a scene can't render. | Every Unit 0 visual is an animated scene; owner decision |
| Demo build (`config/demo.json`) | Hide the "Review draft only" notices; show no "mock" labels; Salah opens only from the developer menu; curiosity onboarding page built but off; recitation shows "unavailable" + skip, never a simulated pass. | Owner decisions and backend reply, 2026-10-04 |
| Reviewer console | Phase 14 (before live integration): same design language, no gamification | Owner decision, 2026-10-06 |
| Raqeeb Rive lantern, more characters per lesson | Phase 16, after the demo if needed | Owner decision, 2026-10-06 |
| Real-time challenge socket against the live backend | Tier C: interfaces, routes and fallbacks only, unless Tier A/B are finished | See [14_DELIVERY_PLAN.md](14_DELIVERY_PLAN.md) |

## Already in the app project

Everything that can be used as-is has already been copied or generated into the app. Don't copy any of it again.

| In the app | Contents | Came from |
|---|---|---|
| `CLAUDE.md` | Agent rules (auto-loaded by Claude Code) | written for this project |
| `docs/PHASES.md`, `docs/PROGRESS.md` | The 16-phase plan with stop-and-report rules; the progress log | written for this project |
| `docs/handoff/` | These documents | moved here from `/Users/aw/Documents/qpr/PRODUCTION_FLUTTER_HANDOFF/` (only a pointer is left there) |
| `docs/contract/` | The **amended** contract revision 10 (`03_API/`: `API_REQUIREMENTS.md`, machine contract, checker tools), frontend handoff, animation and scene semantics, product requirements, **curriculum and learning design**, policy, open decisions, architecture decisions, backend handoff, mocks and acceptance docs | excerpt of `/Users/aw/Documents/qpr/FINAL_ENGINEERING_HANDOFF 2/FINAL_ENGINEERING_HANDOFF/` (refreshed 2026-10-04) |
| `docs/prototype/screens/` | 57 prototype screenshots (iPhone 17 Pro simulator, English) | prototype tour output |
| `docs/API_ASSUMPTIONS.md` | Assumptions log: integration status table, 21 assumptions, 6 questions for the backend engineer | written for this project |
| `assets/fonts/` | 15 font files: Figtree 400–800, IBM Plex Sans Arabic 400–700, Fraunces 500–700, Amiri 400/700, Amiri Quran 400 | proto `assets/fonts/` |
| `assets/sounds/` | 7 UI sounds: `tap`, `select`, `correct`, `retry`, `complete`, `streak`, `sparkle` (`.wav`) | proto `assets/sounds/` |
| `assets/characters/guide_traveler/guide_traveler.riv` | The companion character (artboard, state machine and view model all named `Companion`) | proto `assets/rive/companion.riv` |
| `assets/mocks/contract/` | All amended revision 10 fixtures: `MANIFEST.json` (382 files with model names), `exercises/<type>/` (per-type exercise, answer and evaluation cases), `sessions/`, `workflows/`, `curriculum_test/` (3 units × 4 variants + `PRIVATE_GRADING_KEYS.json`), `challenges/` (socket scripts), `recitation/`, `scenes/`, `presentation/`, `negative/`, `EVALUATION_CONTEXT.json`, `mock_assets/` (test audio tone, map, scene, images) | amended `…/03_API/contract_revision10/fixtures/` |
| `assets/mocks/salah/session_salah_{ar,en}_{explorer,new_muslim}.json` | The real 14-step Salah lesson (`les_u1_l3`) as served | `…/reply8/reference_export/` |
| `assets/mocks/private/salah_keys_{variant}.json` | Answer key, explanation and misconception card for each of the 7 Salah exercises per variant (checked: every exercise id matches its session file). **Private: dev/demo builds only.** | extracted from `reference_export/salah-01.gold-candidate.json` |
| `assets/mocks/glossary/` | `glossary_{variant}.json` (glossary pages) and `raqeeb_terms_{variant}.json` (term cards) for the reference terms | `reference_export/` |
| `assets/mocks/examples/` | All 105 JSON examples from the amended `API_REQUIREMENTS.md`, one file each, named `<Model>__<section>__<n>.json`, plus `INDEX.json` (`file`, `model`, `heading`) | `tool/extract_api_examples.py` |
| `assets/mocks/unit0/` | The 12 Unit 0 lessons as learner Sessions (24 files, Explorer, ar/en), the 20 scene manifests, 86 stills, `SESSION_INDEX.json`, `MEDIA_INDEX.json`, and `DRAFT_NOTICES.json` (the notice blocks the demo build hides) | backend frontend-demo handoff (`/Users/aw/Documents/qpr/back_reply/FRONTEND_DEMO_HANDOFF/`) |
| `assets/mocks/test_lessons/` | Lesson 1.1 "What Does Islam Mean?" (4 variants, both tracks) | `FINAL_ENGINEERING_HANDOFF 2/TEST_LESSONS/sessions/` |
| `assets/mocks/private/unit0/`, `private/test_lessons/u1l1_keys.json` | Answer keys and feedback for Unit 0 and 1.1 (**private: dev/demo builds only**) | backend demo handoff; extracted from the 1.1 factory run |
| `assets/mocks/demo_curriculum/` | The mock demo curriculum (Units 0–10, prerequisites, standalone flags, session files) and four validated initial journeys | `tool/build_demo_curriculum.py` |
| `assets/mocks/reviewer/u0l1.factory_run.json`, `u1l1.factory_run.json` | Two real factory runs at Gate 2 (plan, bilingual draft, evidence, arc map, QA, visuals, digest), validated | `FINAL_ENGINEERING_HANDOFF 2/TEST_LESSONS/runs/` |
| `assets/onboarding/curiosity.json` | Curiosity page copy (question, six goal anchors, bridges); mostly `null` until approved | contract registry + curriculum doc |
| `lib/core/design_system/tokens/tokens.dart` | `QColors`, `QSpace`, `QRadius`, `QMotion`, `QShadows`, `QGradients`, verbatim | proto `lib/core/theme/tokens.dart` |
| `lib/core/design_system/theme/app_theme.dart` | `QFonts`, `QText`, `QTheme.light(arabic:)`, `context.text` / `context.qText`, verbatim (import path adjusted) | proto `lib/core/theme/app_theme.dart` |
| `lib/shared/content/bundled_scripture.dart` | Verified Quran/hadith string constants, used only for the About page verse (Taha 20:10) | proto `lib/data/scripture.g.dart` |
| `tool/rive/guide_traveler/` | Companion Rive source: `generate.py`, `scene.rml`, `build.sh` (now writes to `assets/characters/guide_traveler/`), `README.md`, `contact_sheet.py` | proto `rive/companion/` |
| `tool/make_icons.py` | App icon generator. It has already been run: iOS, Android and web icons, plus `docs/brand/app_icon_1024.png` | proto `tool/` |
| `tool/extract_api_examples.py` | Re-extracts `assets/mocks/examples/` from `docs/contract/` when the contract changes | new |
| `tool/build_demo_curriculum.py` | Rebuilds `assets/mocks/demo_curriculum/`; its `compute_journey()` is the reference Soft Lock algorithm the Dart mock ports | new |
| `test_driver/integration_test.dart` | Driver for `flutter drive` (used by the screenshot tour) | proto |
| Platform files | Launch screens set to night emerald `#032624` (iOS `LaunchScreen.storyboard`, Android `launch_background.xml` ×2); Android label `Qabas` | proto |
| `pubspec.yaml` | Asset entries (sounds, character, onboarding copy, the 46 mock directories), the 5 font families, and the SDK dev dependencies `flutter_driver` + `integration_test` (for the tour). `flutter analyze` is clean. | — |

**Still the Flutter template** (set up in Phase 1): `lib/main.dart` (counter app), `test/widget_test.dart`, `analysis_options.yaml`, and the runtime dependencies (only `flutter` and `cupertino_icons` so far; add the list in [15](15_CONVENTIONS_AND_DONE.md) §1).

Everything else from the prototype (widgets, painters, screens, strings) must be **ported**: brought over while adapting imports, state, strings and sound to the production architecture. It can't be copied as-is, because it depends on the prototype's `AppState`, `Sensory` singleton and inline strings. [02](02_PROTOTYPE_FIDELITY.md) and [13](13_COMPONENTS.md) say exactly which prototype file each piece comes from.

## First steps for the agent

1. Open `docs/PROGRESS.md` to see the current phase, then read that phase in `docs/PHASES.md`.
2. If you're starting Phase 1: read this README and 01 → 15 in order, run the prototype once (`cd /Users/aw/Documents/qpr/qabas && flutter run`), and look through `docs/prototype/screens/`.
3. Build only the current phase. Verify it, write the report in `docs/PROGRESS.md`, and **stop** until the owner says to continue.
