# Product requirements

**Purpose:** define what must be delivered, the owner constraints and explicit scope boundaries. Public field names and algorithms are owned by the API and backend handoffs.

## Required product areas

| ID | Required capability | Detailed owner |
|---|---|---|
| PR-01 | Preserve the Flutter design, motion, interactions, RTL and accessibility for the same screens; reuse its components and painters. | [Frontend](../04_FRONTEND/FRONTEND_HANDOFF.md) |
| PR-02 | Guests/reviewers, eight-page onboarding (language, learner type/track, curiosity Goal Anchor with its reviewed bridge, familiarity, daily goal, privacy), profiles and local UI preferences. Onboarding never asks or infers religion. | [API](../03_API/API_REQUIREMENTS.md), [backend](../05_BACKEND/BACKEND_HANDOFF.md) |
| PR-03 | Data-driven units/lessons with track membership (Unit 0 Explorer-only, Units 1–10 shared), guidebooks, Roadmap and Discover over the same canonical lessons, prerequisite-based access with Soft Lock (position is not a prerequisite), pretests/unit tests and the unit placement skip, next steps; any curriculum size. | Backend, [curriculum](CURRICULUM_AND_LEARNING_DESIGN.md) |
| PR-04 | One lesson per learning outcome, taught completely (a central question, its supporting understandings and a planned depth; about 6–10 minutes, foundational Units 0–1 about 8–10, never padded); `concept`/`story`/`practice` is its primary mode, and any lesson may compose scenarios, stories, practice and exercises its arc needs (selectively, never as sibling versions); planned with a primary outcome, prerequisites, a lesson-specific arc, explicit reasoning tools and whole-lesson budgets; fictional teaching scenarios allowed when non-assertive; evidence for every assertion (non-assertive framing needs none); flexible hook/predict/story/teach/visual/exercise/completion blocks realising the arc. | API and [factory](../06_CONTENT/FACTORY_AND_REVIEWER_HANDOFF.md) |
| PR-05 | All exercise types and presentation variants in the matrix below. | API, backend, frontend |
| PR-06 | Lesson/review/pretest/unit-test sessions; immediate/end/none feedback; cards/quick reviews; replay, eligible retries, resume and finish. | Backend |
| PR-07 | Deterministic mastery, misconceptions, term states, level adaptation, FSRS scheduling and glossary. | Backend |
| PR-08 | Whole-ayah/segment listen-and-recite, bound checks, word coaching, skip/unavailable paths. | Backend and [media](../07_ANIMATION/ANIMATION_AND_MEDIA_HANDOFF.md) |
| PR-09 | Raqeeb's eight routing classes, conversations, source citations, multimodal intake, abstention/referral and guarded memory. | Backend, source tools, benchmark |
| PR-10 | XP/activity/streaks/goals/quests/achievements/leagues/friends; duel/group, bot/async/reconnect behavior. | API and backend |
| PR-11 | Factory agents, two human gates, editable previews/regeneration, religious/factual **and** pedagogical QA, immutable publication, blind tests and metrics. | Factory/reviewer handoff |
| PR-12 | New bespoke scenes authored by agents as declarative content and assets, with shared Flutter preview/runtime, capability gates and fallbacks. | Animation/media handoff |
| PR-13 | Replace or remove the Flutter companion without changing backend requests, schema, scoring or content. | Architecture decisions |
| PR-14 | Both languages × both tracks throughout content and acceptance: Arabic Explorer and Arabic New Muslim are authored variants of one canonical lesson, English is constrained localization of each, and identity is preserved across variants and translations. | API, factory, quality |
| PR-15 | Learner privacy and safety baseline: discreet guest identity, account deletion that removes learner data, private handling of uploads/recordings, abuse limits and source-grounded, guarded assistant answers. | API §3/§6.2, backend §5/§9, [status](../00_REVIEW/STATUS_AND_OPEN_DECISIONS.md) P-04/O-09 |
| PR-16 | Curriculum and learning design: the Unit 0–10 curriculum, the Explorer foundation without circular reasoning, lesson-size targets and exercises that never grade personal belief. | [Curriculum and learning design](CURRICULUM_AND_LEARNING_DESIGN.md), factory |

## Complete question/activity scope

The 14 lesson exercise types are `multiple_choice`, `true_false_reason`, `match_pairs`, `flashcard`, `fill_blank`, `categorize`, `spot_error`, `which_evidence`, `order_steps`, `scenario`, `timeline_order`, `map_place`, `recite_verse`, and `verse_meaning`.

Add challenge-only `true_false`, the neutral `predict` block (predictions and ungraded polls), myth framing, `categorize` buckets/day_arc, `map_place` map_pins/hotspots, and whole/segment recitation. Historical timelines are distinct from prayer placement. Support applicable correct/incorrect/partial/misconception/invalid/timeout/retry/skip/unavailable/hidden/recorded-only cases, and explicitly reject ineligible combinations. The [coverage matrix](../03_API/contract_revision10/fixtures/COVERAGE_MATRIX.json) records current specimens; [quality criteria](../09_VALIDATION/QUALITY_AND_ACCEPTANCE.md) require runtime evidence.

The Salah lesson's exact 14 steps, geometry and copy belong only to its reference fixture. Other lessons choose structures and exercises suited to their objectives through the same reusable components.

## Owner constraints

- Exact reference motion includes the river/house/palms/lights, workplace clock/steam, pillars and day sky. Prayer slots use compiled Flutter drawings; a separate image per prayer slot is unnecessary.
- Agents must support animated content beyond static illustrations. A new scene using released capabilities needs no per-scene app release. New renderer capabilities require code review, testing and app release.
- Retain Arabic 14 / English 13 linked terms in the actual reference. Canonical Arabic glossary display, English ordering secondary labels, declared bucket/header decoration and captured bank order must survive API projection.
- Render published content from data; do not branch on Salah IDs, unit numbers, translations, category positions or the surface (Roadmap/Discover) a lesson was opened from.
- Learning design follows the owner-confirmed principles in [curriculum and learning design](CURRICULUM_AND_LEARNING_DESIGN.md): lessons complete enough that the first ones show the platform's value, two tracks over one canonical curriculum, curiosity-based onboarding without religious classification, Roadmap and Discover over the same published lessons, prerequisites separate from curriculum position, one coherent learning outcome per lesson, taught completely, lesson-specific arcs, Arabic-authored variants with English localization, and no grading of personal belief.
- Every published factual, historical, theological or religious assertion requires attributable support (verified sources, or reviewed reasoning for foundation reasoning claims) and specialist review. Non-assertive framing (hypotheticals, instructions, questions, transitions) needs no scriptural evidence but may not hide an assertion. Structural validation does not grant publication approval.

## Current scope exclusions

Do not build per-user/gap lesson generation, free-answer exercise evaluation, personal-fatwa generation, standalone Quran memorization/tajweed/makharij modes, learner-to-learner chat, push notifications, or languages beyond ar/en in this baseline. Raqeeb inputs exclude URLs and device-audio listening. Recitation recognition/scoring belongs only to `recite_verse`; Raqeeb voice uses ordinary speech intake. Prayer-time calculations/location/clock services are excluded; the reference clock is illustrative. Backend storage of companion behavior or local sound/haptics/reduced-motion/reveal/predict choices is excluded.

PR-16 records the owner's curriculum and learning-design decisions of 2026-10-03; it replaces the earlier Unit 0/Unit 1 content outline and adds no feature outside the learning experience. PR-15 makes explicit what the brief already implies ("preserve learner privacy", `DELETE /me`, specialist-gated religious content). It adds no feature. Its legal parameters are product decision P-04.

## Decisions surfaced by engineering review

The review found choices that change visible behavior. They are listed with safe defaults as **P-01–P-07** in [status and open decisions](../00_REVIEW/STATUS_AND_OPEN_DECISIONS.md): synthetic league members in production, guest progress without recovery, the Riyadh league week, legal/privacy baseline, Raqeeb release thresholds, smaller UX limits and the production treatment of the use of the Salah reference lesson, whose scope spans slots 3.1 and 3.2. Until decided, implement the stated defaults; none removes required scope.

## Optional and future items

The companion's character/implementation can change or be removed. Library/provider replacements and deployment variants are review decisions, not automatic product additions. Any later excluded feature requires an explicit scope/contract change; none is approved by this package. Required scenes, full question coverage and broader modules must not be relabeled optional to reduce scope.
