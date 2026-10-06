# 14 — Delivery plan (two days)

Priorities, in order: **1** core user flows → **2** prototype fidelity → **3** working backend integration → **4** character/Rive experience → **5** robust architecture for critical features → **6** error/loading states → **7** secondary polish. Never trade (1)–(3) for later items. Don't over-build Tier B/C, but don't take shortcuts that make live integration harder (always go through repository → data source → ApiClient).

## Phases

The work is split into **16 phases in [`docs/PHASES.md`](../PHASES.md)**, built one at a time. Each ends with a verified result, a report in [`docs/PROGRESS.md`](../PROGRESS.md), and a stop until the owner approves. In summary:

| Phase | Scope | Tier |
|---|---|---|
| 1 | Foundation and design system: packages, lints, ported components, ARB setup with all prototype strings, rule checks, component gallery | — |
| 2 | App core: config and demo flags, errors, network stack, mock backend, DI, router + five-tab shell (Journey · Discover · Raqeeb · Community · Profile), app-wide state, characters, developer menu | — |
| 3 | Splash, bootstrap (`401`/`426`) and onboarding (+ curiosity page behind a flag, off in the demo) | A |
| 4 | Journey with Soft Locks and the Review card; Discover tab; demo curriculum mock | A |
| 5 | Lesson I: shared content, visuals, intro, player, content steps (teaching scenarios, teach cards without visuals); Unit 0, 1.1, Salah via developer menu | A |
| 6 | Lesson II: every exercise type in the demo data (incl. `true_false_reason`, `spot_error`, `match_pairs`), grading, feedback, retries, finish | A |
| 7 | Scene renderer (`packages/qabas_scene`): live animated scenes for Unit 0 | A |
| 8 | Completion and streak celebration; the journey and Discover update | A |
| 9 | Raqeeb (text questions, polling, every answer type) | A |
| 10 | Profile ("Your words" row), settings (language switch), about | A |
| 11 | Demo spine fidelity pass: tour port, side-by-side comparison, Arabic and reduced-motion passes | A |
| 12 | Card review (from the Review card), glossary, unit guide, remaining exercise types and session kinds, reader, resume | B |
| 13 | Community, challenges (fake socket), achievements, streak calendar, recitation recording, Raqeeb attachments and history, delete account | B |
| 14 | Reviewer console: sign-in, runs, Gate 1 plan review, Gate 2 draft review (approve / request changes / reject), blind test, metrics dashboard; same design language, no gamification | B |
| 15 | Live integration of every backend group that becomes ready, demo build, rehearsals | — |
| 16 | Raqeeb's lantern as a Rive animation; more guide characters cast per lesson | C (after the demo if needed) |

**Parallel agents (optional).** Phases 3–10 only depend on Phases 1–2, except that Phase 7 needs Phase 5's `VisualView`. If the owner runs several agents at once, give each agent one of those phases. Each agent owns its feature folder, ARB fragments, mock handlers and tests. Shared files (`core/`, `app/router/routes.dart`, `app/di/injector.dart`, `common_*.arb`) change only through small, separate commits, announced to the other agents. Every agent still stops and reports at the end of its phase.

## Timeline

- **Day 1 morning:** Phases 1–2. (Backend status, 2026-10-04: no service or go-live date yet, so the timeline doesn't wait for it.)
- **Day 1 afternoon–evening:** Phases 3–5 on mocks.
- **Day 2 morning:** Phases 6–8.
- **Day 2 midday:** Phases 9–11. The Tier A demo spine is complete and verified against the prototype.
- **Day 2 afternoon:** Phases 12–14 as time allows; feature freeze 3 hours before the deadline, then Phase 15's rehearsals. Phase 16 comes after the demo unless time remains.

## Demo script (rehearse it with `config/demo.json`)

1. Fresh install → splash → onboarding in English as an Explorer ("I'm exploring Islam"), goal 10 min. Seven pages; the curiosity page is off.
2. Journey: Unit 0 "Start With a Question"; the companion greets beside lesson 0.1; tap 0.3 to show the Soft Lock sheet ("one idea first"), then start 0.1 from the popover → lesson intro.
3. Lesson 0.1 "Do You Have to See It to Know It?": the grandmother's apricot-tree hook, a prediction, the "box at the door" and "open book and warm tea" cards whose scenes change state as points appear, classifying routes of knowledge into three buckets, the four-beat "last bus" scenario, a deliberate wrong answer (warm clay feedback), the closing scenario exercise and the summary.
4. Completion count-ups → streak celebration → journey updated (0.1 done, 0.2 available).
5. Discover tab: lesson 1.1 "What Does Islam Mean?", opened in the same player (show a step or two).
6. Raqeeb: "Why do Muslims pray five times a day?" → stage labels → answer with citations; then an authenticity check example.
7. Settings → العربية: the whole app flips to RTL instantly; show the journey and a lesson step in Arabic.

Optional, by the presenter only: the Salah reference lesson from the developer menu (long-press the profile avatar), to show the prototype's hand-built scenes.

## Cut order if time runs short

Drop from the bottom: Phase 16 (Rive lantern, extra characters) → reviewer console → async duels → live socket against the backend → attachments in Raqeeb → recitation recording (keep the unavailable state and skip) → glossary screen → league/friends/quests → card review → the curiosity page (already off in the demo) → scene renderer polish (if Phase 7 can't finish, scenes fall back to the backend's stills, which still show the first state of every scene). Never cut: onboarding, journey with Soft Locks, Discover, the Unit 0 lessons with all their exercise types, completion/streak, Raqeeb text Q&A, the language switch, loading/error states on those screens.
