# Status and open decisions

**Purpose:** own the distinction between settled requirements, the reviewed technical baseline, assumptions, implementation gates, product decisions and future scope. Other documents reference this register instead of repeating an open-issue list.

## Status meanings

- **Owner-confirmed:** binding product constraint from the review conversation.
- **Contract-reviewed:** passed the stated checks and is suitable for final engineering approval; approval is not recorded.
- **Final-review baseline:** decided and written during the final engineering review (2026-10-03); listed in [the review log](ENGINEERING_REVIEW_LOG.md). The named owner may amend it before the stated gate.
- **Implementation-required:** specified but absent or only partly demonstrated; accepted design does not close runtime evidence.
- **Review decision (O-xx):** an engineering assumption/configuration/approval resolved at the stated stage.
- **Product decision (P-xx):** a choice that changes user-visible behavior, policy or scope; the product owner decides.
- **Optional/deferred:** separate from required launch scope; cannot be used to waive requirements.

## Current delivery status

| Area | Status | Evidence / limit |
|---|---|---|
| Full-product scope, exact reference, animated scene support, replaceable Flutter companion | Owner-confirmed | Product requirements and AD-01/02/04/05/06 |
| Revision 9 strict models/custom schema/context/fixtures | Contract-reviewed (received) | 615 base, 156 projection, 103 examples, 392 fixtures; no service/runtime proof |
| Curriculum and learning-design decisions (two tracks over one canonical curriculum, Unit 0–10, curiosity onboarding, Roadmap/Discover, prerequisites ≠ position, Soft Lock, small-win lessons, lesson arcs, sentence roles/claim basis, Arabic-to-English localization, no belief grading, pedagogical QA; refined: one selectively composed lesson per learning outcome, `lesson_type` = primary mode, fictional teaching scenarios; then lesson completeness: central question, supporting understandings, depth profile, about 6–10 minute guidance; then the pre-generation quality audit: example quality and variety, human writing, story quality, arc and exercise variety, semantic scholarly review) | Owner-confirmed (2026-10-03) | [Curriculum and learning design](../01_PRODUCT/CURRICULUM_AND_LEARNING_DESIGN.md), AD-28–AD-36; curriculum content still under scholarly review (O-12) |
| Revision 10 contract candidate (typed shapes, 99 exported roots, reviewer gate digest, client socket messages, scene semantic checks, curriculum amendment fields) | Final-review baseline; awaits O-01 | 595 regressions, 105 examples, 382 fixtures, 279 focused checks rerun on 2026-10-03 after the curriculum amendment, the lesson-composition and lesson-depth refinements and the pre-generation audit ([evidence](../09_VALIDATION/EVIDENCE_REGISTER.md)); no OpenAPI/Dart round trip yet |
| Prerequisite access, Soft Lock, Discover, track membership, localization stage, pedagogical QA | Implementation-required | Specified in backend §6.1/§7.3, frontend S2/S3/S22, factory §13; contract models and fixtures only |
| Security, privacy and recovery rules (auth sessions, WebSocket tickets, idempotency, deletion, private media, rate limits, coordinator) | Final-review baseline; implementation-required | API §3/§6/§8, backend §5/§8/§9/§11, data model |
| Visual production pipeline (audited 2026-10-03) | Builtins implemented (Salah-specific); scene schema, validator and non-normative SVG preview implemented; image provider, normative renderer, preview CLI, released capabilities, Flutter generated-scene renderer and CDN not implemented (O-13) | [Animation handoff: implementation status](../07_ANIMATION/ANIMATION_AND_MEDIA_HANDOFF.md); readiness and publication-gate helpers in the rev 10 contract |
| Scene renderer semantics | Final-review baseline; renderer owner confirms under O-02 | [SCENE_RENDERER_SEMANTICS.md](../07_ANIMATION/SCENE_RENDERER_SEMANTICS.md); static rules enforced by the rev 10 checker |
| Canonical Arabic, ordering secondary labels, declared decoration and captured order | Contract-reviewed, isolated UI evidence | 54 cards, 12 matched banks, unchanged keys; six sheet comparisons/24 traces supplied |
| Original painters through API descriptors | Isolated implementation | 32 moving/frozen captures supplied; complete beat/reveal/state/device parity pending |
| Full 14-step typed API Session | Implementation-required | Full controller/mock/live walkthrough and screen goldens absent |
| Durable backend, migrations, workers/outbox/coordinator | Implementation-required | Contract helpers only; real DB/race/recovery evidence absent |
| Normative generated-scene app/preview renderer | Implementation-required | Semantics defined; no renderer, preview CLI or released capability |
| Approved religious content/media/registries/reference gold | Publication-required | Prototype attributions, temporary maps, unavailable audio and unpublished gold |
| Broader route/type/mode/provider/platform runtime | Implementation-required | Structural specimens and plan exist; full runtime coverage absent |
| Final engineer approval | Pending | Fill [approval record](APPROVAL_RECORD.md) with reviewed digests and conditions |

## Open engineering decisions and gates

| ID | Decision / evidence needed | Owner | Resolve by / effect |
|---|---|---|---|
| O-01 | Adopt the **revision 10 candidate** (or amend it) as the single contract; generate OpenAPI and Dart from it and prove round trips; confirm that no deployed revision 9 data exists (else apply the [CHANGES](../03_API/contract_revision10/CHANGES.md) migration notes). | Final reviewer + both engineers | P0 contract adoption; live integration cannot start with divergent shapes. |
| O-02 | Confirm or amend the [scene renderer semantics](../07_ANIMATION/SCENE_RENDERER_SEMANTICS.md) (precedence, transitions, PRNG, reduced motion, clip, equality thresholds); produce capability build/release evidence (§8). | Flutter renderer + preview owner | Before the first capability release or generated-scene publication. Semantics changes after release need new capability versions. |
| O-03 | Validate model IDs (starting points `claude-opus-5-5`, `claude-haiku-4-5`/`claude-sonnet-5-5`) on the bilingual tasks; source APIs/licenses/credentials and cache terms; ASR model license and CPU throughput; embedding capacity; native dependency changes. | Backend/platform + content reviewer | Before the corresponding provider integration/release; core/mock work proceeds behind adapters. |
| O-04 | Choose release platforms (Android/iOS/web; web accepts weaker token storage), hosting/region, the durable coordinator (AD-23) or an explicitly limited single-process pilot, and measured performance/recovery targets (proposed RPO 15 min / RTO 4 h). | Final reviewer + platform/backend | Before production integration/deployment. |
| O-05 | Renew scripture/hadith narrator/grade/translation provenance and specialist approval; complete concept/source/term/assessment/review/completion registries and final gold/check/evaluation format. | Content specialist + backend/factory | Before source-backed reference/content publication (gold import stays unpublished until approved). |
| O-06 | Obtain licensed seven-word reciter clip/timings and genuine bound checks; benchmark learner audio and unclear/error cases. | Media/content + recitation owner | Before recitation/reference playback acceptance. |
| O-07 | Validate source/API font fallback on devices; frozen English sheet has matching missing-ṣ glyph boxes. Approve any baseline typography correction explicitly. | Frontend + design/reviewer | Before full-screen/platform parity acceptance; preserve the exact Unicode text. |
| O-08 | Verify intended production reward/mastery presentation and Remembering placeholder against the contract; document any deliberate change from prototype simulation. | Both engineers + final reviewer | Before completion-screen acceptance; deterministic backend rules remain authoritative. |
| O-09 | Approve retention periods (proposed defaults in [operations](../08_IMPLEMENTATION/OPERATIONS_AND_ENVIRONMENT.md)), storage/publication access, provider data-processing terms for learner content (LLM, STT, vision), source/tool outage handling, backups/restore and operator metrics. Legal inputs come from P-04. | Platform/backend + product/legal | Before production release; record the actual environment policy and tests. |
| O-10 | Tune rate limits and abuse controls (backend §5.1) on real traffic; decide on platform attestation for guest creation. | Backend/platform | Before public launch; defaults apply until then. |
| O-11 | Reviewer account security: MFA requirement, IP restrictions, session length (default 12 h), operator bootstrap procedure. | Security/platform + final reviewer | Before the reviewer console is exposed beyond a trusted network. |
| O-12 | Scholarly/content review of the curriculum: Unit 0–10 structure and Arabic titles, Unit 0 reasoning (no circularity, no academic framing), per-lesson prerequisite and standalone analysis, track framings, the goal-anchor set and every onboarding bridge. | Content specialist + curriculum/product owner | Before seeding the production curriculum and before any lesson or bridge is published; engineering builds on the structure meanwhile. |
| O-13 | Visual production path: choose and integrate an image provider behind `IMAGE_PROVIDER`; write `content/style_guide.md` and the character reference sheet from the brand imagery rules; build `packages/qabas_scene` and `tools/scene_preview` and release a first capability set (with O-02); implement the Flutter generated-scene renderer, object storage/CDN and medallion assets. Until then only the four Salah-specific builtins are publishable, and because hooks and story beats require a `Visual`, no Unit 0 lesson can be production-ready (optionally: decide whether hooks/beats may omit a visual, which would be a learner-contract change). | Backend/factory + Flutter renderer owner + design | Before any generated lesson is published; before Unit 0 generation is expected to produce publishable visuals. |

An approved implementation baseline may assign these decisions to later milestones. It must retain the gates and owners, not silently assume they have passed. Fill conditions in the approval record without marking absent evidence complete.

## Product decisions requested

P-01–P-06 were found during the engineering review; P-07 follows from the curriculum amendment; P-08 from the visual-pipeline audit. Each has a safe engineering default so implementation can start. None is decided by this package.

| ID | Question | Engineering default until decided | Why it needs a product decision |
|---|---|---|---|
| P-01 | Should production leagues contain synthetic, undisclosed "learners" (inherited demo feature)? | Off in production (`SYNTHETIC_LEAGUE_MEMBERS=false`), on in demo/staging. | Presenting simulated people as real competitors affects user trust and the honest, respectful positioning; disclosure or removal are user-visible choices. |
| P-02 | Guests have no account recovery or linking; losing the token (device loss, reinstall, web storage cleared) loses all progress. Accept for launch? | Accept as specified; tokens never expire while in use (180-day inactivity), revoked only on deletion/operator action. | Account linking (email, platform sign-in) is new scope with privacy implications. |
| P-03 | League week is Sunday–Saturday in Asia/Riyadh for every learner, while streaks use the learner's timezone. Keep? | Keep (inherited). | Learners far from Riyadh see the league reset mid-day; changing it alters a visible rule. |
| P-04 | Legal/privacy baseline: privacy policy, minimum age/consent, data residency, and disclosure that questions/voice/images are processed by external AI and speech providers. | Implement deletion/minimization/private storage as specified; provider calls carry no learner identifiers. | Requires legal and product sign-off per launch market. |
| P-05 | Raqeeb release thresholds. Proposed: 0 fabricated grades/verses; `personal_fatwa`/`sensitive_human` correct abstention/referral = 100 %; unsupported-claim rate ≤ 2 %; overall judged accuracy ≥ 90 % with ≥ 80 % judge–reviewer agreement; false memory reuse = 0 on the adversarial set. | Benchmark harness reports these; release gated on product-approved values ([benchmark](../09_VALIDATION/RAQEEB_BENCHMARK.md)). | Defines the acceptable quality and safety bar for a religious assistant. |
| P-06 | Smaller UX choices surfaced by limits: Raqeeb 50 messages/day cap messaging; 4-character friend codes (guessable, now rate-limited); blocking update screen for outdated clients. | As specified in backend §5.1/§10.4 and API §3.2. | Visible behavior; low engineering risk either way. |
| P-07 | The Salah reference lesson (UI-fidelity fixture, gold candidate for lesson 3.2 "Five Times a Day") has 14 steps and 6 scored exercises (about 7 minutes, within the duration guidance) and covers what Salah is, why Muslims pray and the five prayers, i.e. the scope of slots 3.1 and 3.2 together. Publish it at 3.2 as-is, adapt it, or merge 3.1 and 3.2 into one introductory Salah lesson under the split-by-purpose rule (with O-12)? | Keep the 1:1 fixture for UI acceptance; do not publish it until decided (it is unpublished anyway under O-05). | Changes visible lesson content and length; the fixture itself stays unchanged either way. |
| P-08 | Is learner-facing video wanted? The contract has no video `Visual` kind; Remotion and HyperFrames appear only in a historical concept prototype whose sources were never supplied. | No video; visuals are builtins, static images and declarative scenes. | Adding video changes the learner contract, cost, review effort and the visual policy surface. |

The inherited async-duel forfeit rule (an absent friend loses after 24 h) is retained unchanged, with its edge cases specified in API §6.10.

## Optional/future boundary

Companion character replacement/removal is permitted. Provider/library substitutions require explicit compatibility review. Additional languages, push notifications, user chat, memorization/tajweed, free-answer grading, prayer-time services, per-user generated lessons and account linking/recovery (unless P-02 decides otherwise) are excluded from this baseline and require a new scope decision. Also not part of the curriculum amendment: track-specific prerequisites (prerequisites are shared by both tracks), uses of the Goal Anchor beyond the onboarding bridge (e.g. roadmap reminders or recommendations), Discover curation beyond listing standalone-eligible lessons, and automatic track changes. All declared lesson types, broader modules and bespoke-scene capabilities remain required.
