# Qabas app — rules for coding agents

This project is the production Flutter app of Qabas (package `qabas`, id `com.rw.qabas`). Everything you need is in `docs/`; the prototype's source is the only reference outside it.

## Work in phases: always

1. **Start every session by reading `docs/PROGRESS.md`.** The current phase is the first one not marked ✅.
2. Read that phase in **`docs/PHASES.md`**, including its "Read first" list, and build **only that phase**.
3. When every "Done when" item is true and "Verify" passes, write the report in `docs/PROGRESS.md` (template there), set the phase to ⏸, and **stop**. Don't start the next phase until the owner says to continue.
4. If you're blocked, stop and report it; never skip ahead.

## Where things are

| What | Where |
|---|---|
| Phase plan, progress log | `docs/PHASES.md`, `docs/PROGRESS.md` |
| How to build (architecture, design system, screens, lesson engine, mocks, Rive…) | `docs/handoff/` (start with its `README.md`) |
| Wire contract (revision 10) and product reference, read-only | `docs/contract/` (`03_API/API_REQUIREMENTS.md` first) |
| Prototype screenshots | `docs/prototype/screens/` (index: `docs/prototype/README.md`) |
| Assumptions log, shared with the backend engineer | `docs/API_ASSUMPTIONS.md` |
| **Prototype source: visual/UX reference, read-only, outside this repo** | `/Users/aw/Documents/qpr/qabas/` (also named `qabas`; never edit it or import from it) |

Already in the project (don't copy again): fonts, sounds, the companion `.riv` and its Rive source (`tool/rive/guide_traveler/`), all mock data (`assets/mocks/`: amended contract fixtures, the 12 Unit 0 lessons with their scenes and stills, lesson 1.1, Salah, private keys, the demo curriculum), the curiosity copy (`assets/onboarding/curiosity.json`), design tokens and theme (`lib/core/design_system/`), verified scripture constants (`lib/shared/content/bundled_scripture.dart`), app icons, launch screens. Everything else from the prototype is **ported** (adapted to this architecture), not copied. The full list is in `docs/handoff/README.md`.

## Non-negotiables

- **Look and motion come from the prototype.** Before building or changing a screen, open its prototype file (map in `docs/handoff/02_PROTOTYPE_FIDELITY.md`) and its screenshot. Port widgets and painters; keep proportions, spacing, typography, colours, wording, transitions and micro-interactions. Never redesign.
- **Responsive web is required in every phase.** Preserve the phone design and adapt to available layout constraints, including narrow browsers and short/resized desktop windows. Use `QBreakpoints` (reading/sheets 560 px, composer 640 px, navigation rail from 840 px), wrap or scroll overflow, and preserve state during resize. Verify English/Arabic and reduced motion at narrow, tablet and desktop widths and text scale 1.35; build and test on web. Browser orientation remains unrestricted; portrait locking applies only to native phones. See `docs/handoff/03_DESIGN_SYSTEM.md` §4.
- **Data comes from the contract.** Never add endpoints, fields or enum values. Log every assumption in `docs/API_ASSUMPTIONS.md`; keep it inside `data/`. Never edit `docs/contract/`.
- **Layers:** `presentation → domain ← data`. Domain is pure Dart (no Flutter, Dio, JSON or Rive). Widgets never call repositories, Dio or `sl<>()` for data; they dispatch BLoC events and render state.
- **BLoC owns logic.** Use one BLoC per screen or flow, events in the past tense, immutable `Equatable` state with an explicit status. No `BuildContext` in BLoCs.
- **No hard-coded user-facing strings.** Use `context.l10n.<key>` (ARB, en + ar). This covers titles, buttons, errors, tooltips, semantics labels and character text.
- **No raw visual constants in features.** Use `QColors`, `QSpace`, `QRadius`, `QMotion`, `QShadows`, `QGradients`, `QBreakpoints`, theme text styles and design-system components.
- **Characters** (`lib/core/characters/`) are presentation-only. Map BLoC state to moods and cues in widgets with `BlocListener`. Never reference characters in domain, data or API.
- **Content policy:** Quran text only via `QText.quran` and only for `text_uthmani`; render server content verbatim (honorifics included); feedback is emerald/clay, never red; no depictions of prophets, companions, angels or God; faceless people only.
- **Security:** the access token lives only in `flutter_secure_storage`. Never log tokens, `ws_url` tickets or learner text. No mocks, fixtures or answer keys in production releases (`assets/mocks/` is dev/demo only).
- **Disk is nearly full** on this machine: boot one simulator at a time and check `df -h /System/Volumes/Data` before long builds.

## Where code goes

```
lib/app/            bootstrap, config, DI composition root, router
lib/core/           design_system (tokens ✓, theme ✓, components), l10n helpers, network, error, storage, audio, characters, events
lib/shared/         cross-feature content (Span, Visual, Evidence, TermCard…): domain, data, presentation; content/bundled_scripture.dart ✓
lib/features/<f>/   domain/ (entities, repositories, usecases) · data/ (dtos, mappers, datasources, repositories) ·
                    presentation/ (bloc, pages, widgets) · <f>_injection.dart · <f>_routes.dart
lib/mock_backend/   fake HTTP backend + fake socket (dev/demo builds), serving assets/mocks/
lib/l10n/fragments/ per-feature ARB fragments → merged into lib/l10n/arb/ by tool/merge_arb.dart
```

A feature never imports another feature's internals. Use `shared/`, `core/events/AppEventBus`, or route names. Imports are `package:qabas/...`.

## Commands

```sh
dart run tool/merge_arb.dart && flutter gen-l10n          # after editing any ARB fragment (tool written in Phase 1)
dart run build_runner build --delete-conflicting-outputs   # after editing DTOs
flutter analyze && flutter test                            # must be clean before you finish
flutter run --dart-define-from-file=config/mock.json       # all mock (dev: draft notices visible, dev toggles)
flutter run --dart-define-from-file=config/demo.json       # the competition demo build (notices hidden, curiosity page off)
flutter run --dart-define-from-file=config/hybrid.json     # live groups listed in LIVE_GROUPS
sh tool/check_rules.sh                                     # hard-coded strings / raw colours / forbidden imports (script in docs/handoff/15 §3)
python3 tool/extract_api_examples.py                       # refresh assets/mocks/examples/ from docs/contract/
python3 tool/build_demo_curriculum.py                       # rebuild assets/mocks/demo_curriculum/ (Soft Lock reference algorithm)
(cd tool/rive/guide_traveler && ./build.sh)                # rebuild the companion .riv (needs ~/.rive/bin on PATH)
```

## Before you report a phase as done

- `flutter analyze` and `flutter test` are clean, and `tool/check_rules.sh` passes.
- The screens work in mock mode in **English (LTR) and Arabic (RTL)**, with reduced motion on and off.
- Responsive layouts work on web at narrow, tablet and desktop widths, including short windows and resize; `flutter build web` and relevant Chrome tests pass.
- Loading, empty, error/retry states exist where screens fetch data.
- They match the prototype screenshots at the same viewport. Name any intentional difference.
- New assumptions are in `docs/API_ASSUMPTIONS.md`; new ARB keys exist in both `en` and `ar`.
- The report says plainly what you verified and what you could not verify.
