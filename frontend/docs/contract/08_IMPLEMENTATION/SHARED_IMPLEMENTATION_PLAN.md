# Shared implementation and acceptance plan

**Purpose:** own sequencing, dependency gates and shared milestones. This is the retained latest engineer plan, with role-specific execution in [frontend implementation](FRONTEND_IMPLEMENTATION.md) and [backend implementation](BACKEND_IMPLEMENTATION.md).

Acceptance status is centralized in [the status register](../00_REVIEW/STATUS_AND_OPEN_DECISIONS.md). This plan is not evidence that its planned components exist. Final reviewer approves the baseline/conditions before the two teams begin implementation; later production/content approvals remain separate.

The reply8 focused display amendment is delivered. Typed API term sheets and isolated ordering/categorization panels now preserve canonical Arabic, secondary labels, declared decoration and captured bank order. Full Session integration remains pending. The previous review and candidate repairs are retained. The first integration milestone is **partly implemented**: a tested contract, actual-source export and isolated API-selected painters and display panels exist. A complete API-driven reference lesson, reviewed gold content and the normative generated-scene workflow are still required to finish that milestone.

Work in the order below. Items can be developed concurrently once their shared schema/version boundaries are agreed; acceptance gates remain dependent on the stated evidence. This plan does not assume Salah is the universal lesson template.

| Priority / milestone | Concrete work | Why it comes here | Acceptance evidence |
|---|---|---|---|
| **P0 — contract adoption** | Approve or amend the [revision 10 candidate](../03_API/contract_revision10/CHANGES.md) (O-01); vendor it into both repositories; generate OpenAPI components and Dart DTOs from its 99 roots (including the curriculum amendment fields); pin CI environments; implement the contract identity headers; preserve truthful matrix status | Prevents frontend/backend diverging on generic dictionaries and false rejection results; every later milestone depends on these types | Received-byte verification; 595 regressions, 105 examples, 382 fixtures, 279 rev 10 checks plus the focused source/display regressions; schema/OpenAPI/Dart round trips for every root; Python 3.12 production CI; no model negatives counted through truthy success |
| **P0 — reference integration** | Wire the four actual-source candidates through typed repositories/session controller into reused reference widgets; retain all 14 steps, scenes, terms and tracks; finalize private gold format and registry references | Gives a real shared visual/content fixture for later changes | Complete lesson recordings/screenshots in ar/en × both tracks, full interaction traces, reduced motion, source drawers, hotspot/placement/reveals, no private keys in learner output |
| **P0 — reference content/media** | Reverify scripture/hadith attributions and exact quotes; preserve the accepted 14 Arabic / 13 English linked-term counts; acquire licensed seven-word reciter clip/timings and bind check fixtures; fill concept/source/term/assessment/completion registries | Structural validation cannot establish source approval or audio playback | Approved content digest with explicit corrections; matched words 14–20, timing/text/clip agreement; source count 4 and counts 8/7/6; actual answer/check/finish fixtures |
| **P1 — durable learning slice** | Implement revocable auth sessions, rate limits, idempotency keys, journey/session endpoints, pinned versions, replay-first answers, deterministic grading, retries/feedback, transactional finish with stored result, outbox for unreported effects, account deletion on Postgres | Establishes the core runtime and its security/recovery controls before broad screens rely on it | Real database tests for concurrent originals/retries/finish, changed-body replay, finish replay, hidden histories, crash/redelivery, six-decimal mastery, unique XP/FSRS effects, token revocation and deletion purge |
| **P1 — generated-scene slice** | Confirm the [renderer semantics](../07_ANIMATION/SCENE_RENDERER_SEMANTICS.md) (O-02), then build shared `qabas_scene` and the normative preview worker against them; author a new non-Salah asset-bearing scene with hook/story/teach/hotspots; integrate audits/gates/publication and capability negotiation | Required from the start so the system does not become a set of built-in templates | PRNG test vectors; identical app/preview frames for state/time within the §8 thresholds, transition samples, reduced motion and fallbacks; anchor visibility, failed downloads/hashes, unknown capabilities, pinned resume; device timing and release evidence |
| **P1 — complete exercise/session matrix** | Reuse/extend generic components for every type/presentation; execute applicable outcome/feedback/mode combinations; real recitation checks, cards/quick reviews and challenge types | Structural specimens need actual grading and rendering coverage | Linked mock/live traces for 14 lesson types, challenge true/false, whole/segment recitation, invalid/timeout/retry/skip/unavailable/hidden cases; explicit N/A cases rejected |
| **P2 — multi-unit progression and review** | Persist the Unit 0–10 curriculum with track membership, unit pools, prerequisite-based access/Soft Lock, Discover, unit placement skipping, mastery/misconceptions, scheduler state and personal glossary | Tests scalability beyond Salah and the fixed three-unit fixture | Three-unit seed end to end plus a generated larger catalog; min(pool, cap) selection, no repeats, stable identity across language and track changes, correct track start, Roadmap/Discover session identity, no position-based locking, due reviews and term transitions |
| **P2 — Raqeeb** | Implement intake/polling, extraction, eight-class routing, source adapters, claim verification, writer/level adaptation, guarded memory and referral/failure states | Provider and provenance behavior needs its own vertical slice | Specialist-reviewed class benchmark; text/voice/image/DOCX/native and scanned PDF; missing sources, follow-ups, bad input, stale cache, false reuse, latency/cost measurements |
| **P2 — community/challenges** | Implement activity/quests/streaks/achievements/leagues/friends; durable duel/group coordinator (backend §11.2) with WebSocket tickets, bot/async and reconnect | Scripted score arithmetic does not exercise orchestration or recovery | Both presets, ties, timeout, disconnect, coordinator kill/takeover with fencing, score/reveal timing, bot/async fallback and forfeit, local-day/week boundaries and no duplicate awards |
| **P2 — factory/reviewer/admin** | Replace historical auto-gates with authenticated plan/content gates bound to `review_digest`; provenance-backed factory (Curriculum Architect plans with arcs and justified reasoning tools, Arabic-authored track variants, `localize` stage, religious/factual and pedagogical QA) with idempotent stages and budgets, media/scene regeneration, immutable publication, gold import behind approval, blind tests and metrics | Prevents saved experimental output becoming approved content | A new lesson across both gates, evidence/exercises/pools/terms/scenes/media previews, rejected/regenerated versions, stale-digest rejection, reviewer actor/hash audit and benchmark metrics |
| **P3 — release hardening** | Resolve retracted/native dependencies, build platform apps/containers, load-test queues/API/realtime, exercise backup/recovery and media retention | Needed to turn proven slices into a deployable product | Android/iOS/web builds as targeted, real-device RTL/accessibility, measured ASR/scene/API p95, durable recovery, provider outage behavior and repeatable deployment |

## Dependencies and parallel start

The critical path is **O-01 contract approval → generated DTOs/OpenAPI → durable learning slice → reference integration on live data**. Everything else can start in parallel once DTOs exist:

| Can start immediately after approval | Needs first |
|---|---|
| Flutter: repositories/controllers on mocks, reference widget adaptation, `qabas_scene` against the semantics (PRNG, precedence, goldens) | Generated Dart DTOs (P0) |
| Backend: auth sessions, idempotency, rate limits, migrations with the mandatory constraints, outbox relay | Vendored rev 10 models (P0) |
| Content: source re-verification, registries, reciter licensing (O-05/O-06) | Nothing technical; owners assigned |
| Platform: hosting decision, buckets, secrets, CI with Python 3.12 (O-04) | Nothing technical |
| Raqeeb, community/challenges, factory | Durable learning slice (shared auth, outbox, sessions) |

Product decisions P-01–P-07 do not block the critical path; their defaults are implementable and reversible.

## Reference integration checklist

Implement a typed Session controller around the existing lesson widgets, rather than feeding the production API directly into the prototype's locally graded `LessonSession`. Keep mock and live repositories interchangeable. The mock repository uses private grading data only behind its service boundary, and returns the same redacted response shapes as live.

Record all 14 steps and their content states: workplace hook, neutral prediction, river beats 0–3, labeled hotspots at beat 1, river teaching, myth exercise, pillars highlight 1, buckets, day reveals −1/1/4/4, five placement rows, scenario, ungraded recitation, summary and prayer ordering. Verify CTA/quotes/meaning/provenance/track copy, aspect ratios and localized labels against the actual source. Check both languages and both tracks, not only the explorer captures currently supplied.

Build a new full-screen baseline from the source at fixed viewport, fonts, preferences and animation times. The 57 received screenshots are historical guides. The 32 reply 7 painter captures are isolated witnesses. The reply8 term/panel captures add focused display evidence. These sets do not constitute a full Session golden test. Compare app state and pixels at controlled points, then record real interactions to catch transitions, hit targets and continuation behavior that still frames miss.

Keep the companion local and optional throughout this work. Swapping/removing its Flutter implementation must leave backend requests, grading and lesson data unchanged.

## Runtime tests that close the contract's limits

Use real Postgres transactions for duplicate original and retry submissions; two devices racing; a valid recorded identity replayed with malformed/changed answers; interruption before/after commit; concurrent finish; and worker retries after a completion commit. Assert stored response identity, chronological history and one effect per attempt/completion. Test none/end feedback both while active and after finish. Check retries never alter first-attempt accuracy or rewind reading progress.

Recitation tests must cover owner/version/range/text binding, reused/foreign checks, unclear audio, skip and unavailable playback, with recognition returning coaching rather than graded accuracy/combo. Evaluate actual audio on held-out learner recordings and noise; a synthetic tone or a model-card score cannot close this gate.

Exercise tests must link public payload, submitted body, pinned private key, returned evaluation/details and exact private mastery. Include wrong IDs, missing/duplicate assignments, partial correctness, timeout with no correct unanswered items, ineligible retries and separate challenge policy. Published content needs reference integrity and source/claim review beyond the pure contextual checks.

## Renderer release checklist

Define property precedence, transform origin/composition, state-rule ordering, interpolation, active tracks, loop phase, reduced motion and deterministic random seeds before coding preview/app divergence. Use the same implementation and build identity in both renderers. Verify raster and permitted SVG decoding, gradient/clip bounds, visible target containment and fallback geometry in rendered output.

A capability is released only after a real client build supports it and measured evidence exists. The candidate production registry intentionally has none. Until then, preview/test scenes can use the simulation registry, while production publication fails. New content should exercise the released subset; new code requires the separate capability review/build/release path.

The non-Salah acceptance scene must include actual asset bytes and multiple exercise states, not only vector shapes with `assets: []`. Test asset corruption, wrong MIME/dimensions/hash, missing download, unknown capability, reduced motion and state-specific fallback. Resume a pinned session after a newer scene version is published and prove it still uses the old version.

## What is not yet verified

No production API/database/worker, normative scene renderer or device build was run in reply7 or reply8. No paid/credentialed provider call or licensed reference reciter media was obtained. Religious source approval, complete published registries, full API lesson parity, full broader-route mocks/live tests, provider/model benchmarks and deployment performance remain open gates. The review and reproducible repair package should be accepted on their stated scope; production acceptance requires the evidence above.
