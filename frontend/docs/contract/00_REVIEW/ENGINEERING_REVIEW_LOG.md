# Final engineering review log (2026-10-03)

**Purpose:** record what the final engineering review changed in this package, why, and where. Normative rules live in the linked documents; open items live in [status and open decisions](STATUS_AND_OPEN_DECISIONS.md). Received artifacts under `10_REFERENCE/` and `11_HISTORY/` were not modified.

Product scope was preserved: exact Flutter reference behavior, full question/curriculum coverage, bespoke animated scenes and the Flutter-owned replaceable companion are unchanged. Where a finding touches user-visible behavior it is raised as a product decision (P-01–P-06) with a reversible default, not decided here.

## Contract (revision 10 candidate)

| # | Finding | Change | Where |
|---|---|---|---|
| C-1 | About 25 documented shapes (learner `SessionResult` XP/streak/review items, stats, achievements, recitation summary, conversation history, async duel answers, every reviewer/factory/metrics object) were exported as untyped objects. Generated Dart/OpenAPI would be untyped exactly where agreement matters. | Typed models matching the existing prose; learner JSON wire-identical | [contract_revision10](../03_API/contract_revision10/CHANGES.md) |
| C-2 | Several endpoint bodies had no exported root; `PATCH /me` had no model; client→server socket messages were prose only. | 21 new roots (78 → 99), `MePatch`, `WsClientMessage`, `AssistantMessage` union, page roots | same |
| C-3 | Gate approval required "exact reviewed artifact hash" but the API had no field for it; two reviewers or a finishing regeneration could approve something unseen. | `FactoryRun.review_digest` + `Gate1/Gate2.review_digest`, `409 review_stale`, reference `review.py` | API §6.11, factory §13.6 |
| C-4 | The approve response promised `published`, but the strict model forbade it. | `FactoryRun.published` | same |
| C-5 | Code-validator QA findings had no `QAKind`. | `validation` kind | API §4, factory §13.5 |
| C-6 | Missing invariants: XP total vs breakdown, recitation summary vs words, `passed`/`review_items` by kind, status-dependent run fields. | Model validators with positive/negative tests | `rev10_checks.py` |

## Security, privacy and abuse

| # | Finding | Change | Where |
|---|---|---|---|
| S-1 | "Long-lived JWT" cannot be revoked, so `DELETE /me` could not end access. | Opaque tokens backed by revocable server-side auth sessions; expiry rules | API §6.1, backend §5 |
| S-2 | Access token in the WebSocket query string leaks into proxy/access logs. | Single-use 60 s ticket embedded in server-provided `ws_url` | API §8, backend §11.2 |
| S-3 | Learner attachments were described on a public-read CDN. | Private bucket, signed URLs; recitation audio never stored | API §3.7/§3.8, architecture, data model |
| S-4 | Flutter guidance stored the bearer token in `shared_preferences`. | `flutter_secure_storage`; web limitation tied to O-04 | frontend §9/§11 |
| S-5 | `401` handling looped (S1 → 401 → S1). | Clear token, notice, new guest | API §3.4, frontend S1 |
| S-6 | `DELETE /me` had no defined effect. | Revoke now, purge within 30 days, anonymize shared records, re-purge after restore | API §6.2, backend §5, data model |
| S-7 | No rate limits, while LLM-backed and guest-creation endpoints are open to abuse. | Default limit table, invite brute-force limits, reviewer lockout | backend §5.1 |
| S-8 | Raqeeb treated attachments and retrieved text as plain input (prompt injection). | Untrusted-data handling, allow-listed tools | backend §9.1, catalog |
| S-9 | Semantic memory could reuse an answer derived from another user's question or attachments. | Guarded reuse (standalone, no attachments, digest/policy/version checks, de-personalised key, purge link) | backend §9.2, data model |
| S-10 | Reviewer passwords were seeded from environment variables. | Operator CLI, Argon2id; MFA left as O-11 | seeds, operations |
| S-11 | Gold import "published directly", bypassing specialist review. | Unpublished until a recorded approval | factory §13.7, seeds |

## Concurrency, recovery and idempotency

| # | Finding | Change | Where |
|---|---|---|---|
| R-1 | The backend sent XP/FSRS/quests through an async outbox, but `SessionResult` must return them. | Effects that responses report are committed in the same transaction and replayed; the outbox only carries unreported effects; lock order defined | backend controls, AD-24 |
| R-2 | Finish was not idempotent (a retried timeout could fail or double-apply). | Stored `SessionResult` replay; clamped duration; completeness check | API §6.5, backend §6.4 |
| R-3 | Raqeeb message and recitation uploads had no retry identity. | `Idempotency-Key` contract | API §3.2, backend §5.2 |
| R-4 | Answer processing order was described but not normative for edge cases (ownership, finished sessions, races). | Seven-step normative order | API §6.5 |
| R-5 | The live challenge engine lived in one in-memory process; a restart lost duels. | Durable coordinator (persisted deadlines, fenced leases, any-instance sockets); single process only as approved pilot | backend §11.2, AD-23 |
| R-6 | Async duel `next`/`answer` were not idempotent. | Idempotency, timeout and forfeit edge cases | API §6.10 |
| R-7 | CPU-bound ASR in the API process would stall requests and live challenges. | Dedicated `asr` worker, bounded wait, `503` back-pressure | backend §8, AD-22 |
| R-8 | Stalled Raqeeb messages could poll forever after a worker crash. | Late ack, sweeper at 90 s | backend §9.1 |
| R-9 | No migration or versioning strategy beyond "plan one". | Mandatory constraints, expand/contract migrations, client tolerance rules, contract headers and `426` | data model, API §3.2 |

## Animation and renderer

| # | Finding | Change | Where |
|---|---|---|---|
| A-1 | Renderer semantics were "to define before release". The only executable interpretation (SVG preview) uses Python's Mersenne Twister, skips tracks in reduced motion, and omits transitions/clip/assets/strokes, so app and preview could not be made equal. | Normative semantics with PRNG test vectors, precedence, transitions, compositing, equality thresholds and release evidence | [SCENE_RENDERER_SEMANTICS.md](../07_ANIMATION/SCENE_RENDERER_SEMANTICS.md) |
| A-2 | Statically checkable failure modes were unchecked (non-positive scale, animated clip sources, gradient sparkles, distorted assets, unknown tokens). | Rules added to the revision 10 `scene_check.py`; anchor visibility assigned to the preview | same §9 |

## Agent workflows

| # | Finding | Change | Where |
|---|---|---|---|
| G-1 | "Temperature 0 / ≤ 0.4" cannot be set on current Claude models; forced tool choice is rejected; example model IDs were outdated. | Structured outputs/strict tools, effort settings, refusal handling, current model starting points as configuration | agent catalog, system architecture, operations |
| G-2 | Factory stages had no idempotency or cost bound. | Idempotent stage tasks, per-run budget, cost record | factory §13.1 |
| G-3 | Gate 2 sentence edits bypassed validators. | Re-link terms and re-run all code validators before publishing; audit before/after | factory §13.6 |

## Documentation corrections

Malformed tables (mastery update table, group challenge row), a duplicated validator bullet, a stale `§1.1` reference, the doubled heading spacing in the plan, the `finished session` rule that contradicted replay, and outdated "78 roots"/revision 9 links in active documents were fixed. New cross-links point to the revision 10 contract and the scene semantics.

## Curriculum and learning-design amendment (2026-10-03)

The product owner supplied authoritative product/content decisions after the review. They were propagated as one coherent change; the canonical statement is [curriculum and learning design](../01_PRODUCT/CURRICULUM_AND_LEARNING_DESIGN.md). Unrelated settled decisions (security, recovery, scenes, grading arithmetic, scripture insertion by code, human gates) are unchanged.

| # | Decision | Conflict found in the handoff | Change | Where |
|---|---|---|---|---|
| L-1 | Two tracks, one canonical curriculum; Unit 0 Explorer-only; Units 1–10 shared with per-track variants; completion keyed by lesson ID | Unit 0 was "optional/available" for New Muslims; `units.start_for_tracks`; variant fallback in both directions; old Unit 0/1 outline (Allah, Islam, Ibrahim in Unit 0; Salah in Unit 1) | `units.tracks`, track framing, one-way New Muslim → Explorer fallback, track-change rules, Unit 0–10 curriculum | curriculum doc, AD-28, data model, backend §5/§6, API §6.2/§6.3, seeds |
| L-2 | Curriculum position ≠ prerequisite; Soft Lock; Discover = same published lesson | Sequential lesson unlocking and "next unit after previous" (backend §6.1); journey fixtures and example used position-based locks | Prerequisite-based access, `JLesson.standalone_eligible`/`soft_lock`, `409 prerequisite_unmet`, Discover screen S22, planner rules | AD-29, API §6.3/§6.5, backend §6.1/§7.3, frontend S3/S22, fixtures |
| L-3 | Onboarding asks curiosity (Goal Anchor + reviewed bridge), never religion | Seven-page onboarding without a curiosity step | `goal_anchor` on onboarding/User/`PATCH /me`, `goal_anchors` registry, 8-page onboarding | API §6.1, frontend S2, registries template |
| L-4 | One small learning win; size targets per lesson type | Hard rule of 4–8 graded exercises (factory, Gate 2 minimum 4, `contextual.py`) | Structural 2–6 graded exercises, per-type targets as QA warnings, split signal above 7–8 min | factory §13.3, `contextual.py`, curriculum doc |
| L-5 | Lesson Arc and Curriculum Architect responsibilities; explicit reasoning tools | `LessonPlan` held only title/objectives/prerequisites/terms/misconceptions/minutes; prompt guidance implied one presentation sequence | `LessonPlan` outcome/introduced concepts/arc/reasoning tools/standalone/budgets; `Draft.arc_map`; writer constraints | AD-30, factory §13, API §6.11 |
| L-6 | Evidence for assertions only; framing roles; scriptural vs reasoning support; no circular reasoning | "Every sentence has ≥ 1 claim" with a `connective` flag; claims could only be source-supported | `SentenceClaims.role`, `Claim.basis`/`reasoning`, QA `circular_reasoning` | AD-31, factory §13.2/§13.5, data model |
| L-7 | Arabic-authored variants; English constrained localization | Writer produced `ar`/`en` × tracks directly | `localize` stage, parity validator, QA `localization`, paired Gate 2 edits | AD-32, factory §13.1, API §6.11 |
| L-8 | Never grade belief; pedagogical QA | QA covered only religious/factual/safety | QA kinds `pedagogy`, `belief_grading`; exercise rules; `predict` for polls | AD-33, factory §13.3/§13.5, API §5.6/§5.7 |
| L-9 | Examples tell the same story | API examples placed "Who is Allah?" (Quran-evidenced) and the Ibrahim story in Unit 0 | Examples re-homed (2.1, 7.4, 4.1, 1.1); journey example rewritten; gate digests recomputed with `review.py` | API §5–§6.11, `workflows/ses_91ab.json` |

Contract consequences (revision 10 candidate, class F in [CHANGES](../03_API/contract_revision10/CHANGES.md)): learner `Session`/`Exercise`/`AnswerEvaluation`/`SessionResult` unchanged; `Journey`, `User`, onboarding, `PATCH /me` and reviewer plan/draft shapes extended; still 99 roots; schema digest `4e9e971307642e704c493a9c7ccf2ae933f1148aeeee1333778767a27aae681f`. Suites: 595/595 regressions, 232/232 focused checks, 105/105 examples, 382/382 fixtures, PASS ([evidence](../09_VALIDATION/EVIDENCE_REGISTER.md)).

Housekeeping: 18 Gradle/NetBeans cache files (`android/.gradle/…`) had appeared inside the two received Flutter reference folders after the pre-amendment manifest was frozen (they are in no received archive or checksum list) and made `verify_package.py` fail. They were moved out of the package unchanged rather than frozen into the manifest.

## Lesson-composition refinement (2026-10-03)

A generation test that produced separate concept, story and practice lessons for lesson 0.1 showed each output too thin, while concatenating them would repeat hooks, explanations and exercises. The owner's refinement was propagated as follows; the canonical statements are [curriculum: lesson types and composition](../01_PRODUCT/CURRICULUM_AND_LEARNING_DESIGN.md) and factory §13.

| # | Decision | Conflict found | Change | Where |
|---|---|---|---|---|
| L-10 | `lesson_type` is the primary pedagogical mode; one learning win → one composed lesson; no concept/story/practice siblings | Nothing prevented two lessons per slot or parallel runs for one outcome; agents were selected by lesson type (Event Extractor/Story Narrator for story lessons only); "Factory done" asked for "one concept, one story and one practice lesson" without saying they are different slots | One lesson per slot (`UNIQUE (unit_id, index)`, re-runs version the slot's lesson), primary-mode semantics, Story Narrator/Event Extractor used for story steps in any lesson, DoD clarified | curriculum doc, factory §13/§13.1/§13.6, data model, AD-34, PR-04, quality |
| L-11 | The Lesson Arc controls composition; selective merge, never concatenation; rhythm; one hook/one takeaway | Arc steps had no technique, so "story block with no need" or "second summary" could not be checked | `ArcStep.technique`, at most one `takeaway`, primary mode must appear in the arc; code checks map story/summary/predict blocks to compatible steps | contract class G, factory §13.1/§13.5, API §6.11 |
| L-12 | Exercises follow the arc: candidate pool, selected non-duplicated subset; budgets apply to the whole lesson | Exercise stage produced a fixed count after writing | Selection along the arc; whole-lesson budget and duration | factory §13.1/§13.3, curriculum doc |
| L-13 | Fictional/everyday stories allowed; religious stories only when needed; early Explorer lessons prefer everyday scenarios | "Stories: from the Quran and authentic Sunnah only" and a contract that required sources on every `story` block | Sourced story vs teaching scenario (`BStory.origin` nullable; no provenance/quotes; non-assertive narration); story quality rules | contract class G, API §5.6, factory §13.2, backend §6.5, frontend DoD, content policy |
| L-14 | Examples must be epistemically clean; direct observation is any sense; testimony varies in reliability | 0.1 test examples used weak inferences (neighbour's car, wet ground) and named the category "seeing" | Example-quality rules, reasoning-integrity QA (blocker in reasoning lessons), 0.1 reference design | curriculum doc, factory §13.2/§13.5 |
| L-15 | Pedagogical QA detects duplication and composition failures | QA had no sibling/duplication/story-necessity checks | New `pedagogy` and `validation` checks with stated severities | factory §13.5 |

Contract consequences (class G in [CHANGES](../03_API/contract_revision10/CHANGES.md)): reviewer plans gain `technique` per arc step; learner story blocks may carry `origin: null`; still 99 roots; schema digest `578391dd245eb4cb96c9f376a4f982c4863d8a8c1e3dfc9827a9fed8f2a3450e`. Suites: 595/595 regressions, 243/243 focused checks, 105/105 examples, 382/382 fixtures, PASS.

## Lesson-depth refinement (2026-10-03)

The composed lessons were coherent but some foundational lessons were too shallow: "one small learning win" was being read as "one narrow fact, then stop". The owner's refinement redefines lesson completeness; canonical statement: [curriculum: lesson completeness and depth](../01_PRODUCT/CURRICULUM_AND_LEARNING_DESIGN.md).

| # | Decision | Conflict found | Change | Where |
|---|---|---|---|---|
| L-16 | One primary outcome is not one fact: a lesson answers one central learner question completely, with the supporting understandings it needs | Principle 9 and AD-30 said "one small learning win"; `LessonPlan` had no place for the central question or supporting ideas, so the plan could not express a complete outcome | `LessonPlan.central_question`, `supporting_understandings`; principle 9 refined; completeness test and dimensions | contract class H, curriculum doc, factory §13.1, AD-35 |
| L-17 | Depth profile; Units 0 and 1 foundational; first lessons must show the platform's value | No notion of depth; Unit 0/1 lessons planned at the minimum | `LessonPlan.depth_profile` (`foundational`/`standard`/`focused`); Unit 0/1 standard; principles 17–18 | contract class H, curriculum doc, Gate 1 checklist |
| L-18 | Duration guidance about 6–10 minutes (foundational about 8–10), never a cap or padding target; review beyond about 10–12 minutes | 4–6/5–7/4–7 minute targets, "above 7–8 minutes is a split signal" and a code warning "above 8 minutes: split candidate"; the Gate 2 QA example flagged an 8-minute story | New guidance table; code warning only beyond about 12 minutes (review, no automatic split) and an info when a foundational lesson looks thin; example fixed | curriculum doc, factory §13.3/§13.5, API §6.11 |
| L-19 | Split by change in learning purpose, not by heading or duration; establish the map now, explore regions later | "Learn prayer is too broad … separate lessons" read as a mandate to split every subtopic | Keep-together / consider-splitting test; no micro-lessons from headings; prayer grouping as illustration only | curriculum doc, factory §13.1 |
| L-20 | Depth, not padding; longer lessons gain depth and ungraded interaction, not more questions | Budgets described "primary content blocks" (read as a minimum) and graded targets of 2–4 | `content_budget`/`exercise_budget`/`estimated_minutes` semantics restated; graded usually about 3–5 (structural 2–6); quiz-heavy warning | contract comments, factory §13.1/§13.3 |
| L-21 | QA checks underdevelopment as well as overdevelopment; Gate 1/2 completeness questions | QA only detected excess (length, duplication) | `pedagogy` model rows for underdevelopment and overdevelopment; Gate 1 checklist and Gate 2 guidance rewritten | factory §13.1/§13.5 |

Knock-on: the Salah reference (about 7 minutes) is now within guidance; P-07 is reframed around its scope, which spans slots 3.1 and 3.2. Contract consequences (class H in [CHANGES](../03_API/contract_revision10/CHANGES.md)): reviewer plans gain three fields; learner payloads unchanged; still 99 roots; schema digest `2d94da6a8c60a77af31ff23f70f1a4407ed61ac46aee6818198cc88ece15d253`. Suites: 595/595 regressions, 249/249 focused checks, 105/105 examples, 382/382 fixtures, PASS.

## Pre-generation quality and visual-pipeline audit (2026-10-03)

Before generating Unit 0, the owner asked for a quality audit (examples, writing, stories, arc and exercise variety, semantic scholarly review) and an audit of the visual pipeline as it actually exists. Canonical statements: factory §13.1–§13.5 and §13.8, [curriculum](../01_PRODUCT/CURRICULUM_AND_LEARNING_DESIGN.md), [brand imagery](../01_PRODUCT/CONTENT_AND_BRAND_POLICY.md), [animation handoff: implementation status](../07_ANIMATION/ANIMATION_AND_MEDIA_HANDOFF.md).

| # | Decision | Conflict or gap found | Change | Where |
|---|---|---|---|---|
| L-22 | Examples separate observation, inference and strength, avoid hidden assumptions and vary their contexts | The 0.1 test lesson leaned on weather, school, messages and footprints and had three reasoning slips: "half-eaten sandwich" put the conclusion inside the observation; a station employee "looking at the timetable" was treated as knowing whether the bus had left; a friend relaying his brother was called "a source who would know". Inference strength was not taught | Example-quality and example-variety rules; 0.1 reference design re-chosen (parcel at the door, library table, bus-station narrative, health claim) and now teaches inference strength; code flags lessons leaning on an overused context family | factory §13.2/§13.5, curriculum Unit 0 and 0.1 |
| L-23 | Human writing quality and natural flow | No rule against AI-card tone, scripted enthusiasm, stock openers, rhetorical questions or hard resets between blocks | Writing and flow rules (register, what to avoid, blocks respond to each other); code heuristics for stock phrasing, exclamation marks and question density; model rows for tone and flow | factory §13.2/§13.5 |
| L-24 | Stories are miniature narratives with light roles; fictional or sourced | "Story" allowed an example with a character attached; characters were generic | Story-quality, fictional-or-sourced and character rules; code flags one-beat stories and generic-only characters | factory §13.2/§13.5, curriculum Explorer guidance |
| L-25 | Arc families are a vocabulary, not templates; planning uses a unit context; exercise format follows the cognitive task | The reference lessons risked becoming hidden templates; nothing told the architect what recent lessons did; exercise-type choice had no task mapping | Architect input gains the unit context; arc-family and unit-variety paragraphs; exercise-task mapping; unit-monotony checks (`TEST_LESSONS/tools/unit_review.py` as reference) | factory §13.1/§13.3/§13.5/§13.7, curriculum composition |
| L-26 | Semantic scholarly review of scriptural support; the AI flags and the specialist decides | Entailment was a free-text note; nothing recorded tafsir dependence, addressee, generalisation, disagreement or oversimplification. In 1.1, 2:256 bridged to "submission is willing", 6:162 (addressed to the Prophet ﷺ) was generalised, 2:130–132 stood for "all prophets", "so Islam is not just a word" went beyond 2:112, and the framing set rituals against "living Islam" | `ClaimEvidence.semantic_review` (`fit`, `concerns`, note; stretched/unrelated cannot support); QA kind `scholarly_review`; 1.1 framing corrected (museum hook, no ritual opposition), every religious claim left unchanged and flagged for the specialist | contract class I, factory §13.1/§13.5, curriculum 1.1 |
| L-27 | Visual pipeline audited from code, not documents | Documents describe a generated-image and generated-scene pipeline. Found: builtins (Salah-specific) implemented in the Flutter reference; scene schema, validator and a non-normative SVG preview implemented; no image provider, no `qabas_scene`, no `scene_preview`, no released capability, no Flutter generated-scene renderer, no CDN; Remotion and HyperFrames only in a historical prototype whose sources were never supplied. Hooks and story beats require a `Visual`, so no Unit 0 lesson can reach production readiness today | Implementation-status section; one representative scene rendered through the delivered workflow (`preview_only`, not publishable) and shown in the test player; decisions O-13 and P-08 | animation handoff, factory §13.8, status register |
| L-28 | Visual choice follows pedagogy and cost escalation; visual storytelling, visual QA, explicit style; readiness states and a publication gate | Visuals were chosen per block without a stated purpose; the Visual Auditor checked policy only; the style guide and character sheet are referenced but absent; placeholder URLs could pass structural validation | Escalation ladder, storytelling and visual QA criteria; brand illustration style, composition and consistency rules; `contextual.visual_readiness` and `contextual.placeholder_media_errors` (Gate 2 needs `compiled`/`audited`; publication rejects placeholder or non-https media) | factory §13.4/§13.5, brand policy, contract class I |

Contract consequences (class I in [CHANGES](../03_API/contract_revision10/CHANGES.md)): reviewer evidence gains `semantic_review`, `QAKind` gains `scholarly_review`, `contextual.py` gains three helpers; learner payloads unchanged; still 99 roots; schema digest `9d67bda00d2edd04d47645b6b93a7747ab9d5646cddeb12a7b34a6910c97481c`. Suites: 595/595 regressions, 279/279 focused checks, 105/105 examples, 382/382 fixtures, PASS.

## Package identities

| Identity | Value |
|---|---|
| Pre-review package (2026-10-02) outer `MANIFEST.sha256` digest | `478b403b6c2053951e97be18bb642b0fdbf760d248ec37f03d005bdda479e9cb` |
| Pre-review ZIP SHA-256 (kept beside the package as `FINAL_ENGINEERING_HANDOFF.pre-final-review.zip`) | `4ca95668420fe31c4e78a6f54a4357109388d1c89b14c8a3bc5b64fdcfdb2735` |
| Received revision 9 schema (unchanged) | `e38f032c38ff5d02de549205680e50a3f7691e1dd5cc87138b0fe4af2c24d4f3` |
| Revision 10 candidate schema (final review, before the curriculum amendment) | `5adaff5c8980e9b91483a1c865d047164065adf6ef851cce10d8f052bc44d911` |
| Package before the curriculum amendment: outer `MANIFEST.sha256` digest | `02acfe5cccab86b53df9fd55bb9b989bf53f5cb71fed2aa222e1117d9b784064` |
| Revision 10 candidate schema after the curriculum amendment | `4e9e971307642e704c493a9c7ccf2ae933f1148aeeee1333778767a27aae681f` |
| Revision 10 candidate schema after the lesson-composition refinement | `578391dd245eb4cb96c9f376a4f982c4863d8a8c1e3dfc9827a9fed8f2a3450e` |
| Revision 10 candidate schema after the lesson-depth refinement | `2d94da6a8c60a77af31ff23f70f1a4407ed61ac46aee6818198cc88ece15d253` |
| Revision 10 candidate schema after the pre-generation audit (current) | `9d67bda00d2edd04d47645b6b93a7747ab9d5646cddeb12a7b34a6910c97481c` |
| Post-review manifest and ZIP | Printed by `tools/package_handoff.py` and stored in `MANIFEST.sha256` / `FINAL_ENGINEERING_HANDOFF.zip.sha256`; record them in the approval record. A file cannot contain its own digest. |

## What this review did not do

It did not build or run any service, the Flutter app, the scene renderer or provider calls. It did not approve religious content, media licenses or legal/retention policy. It did not record the engineer approval itself. Verification performed is listed in the [evidence register](../09_VALIDATION/EVIDENCE_REGISTER.md).
