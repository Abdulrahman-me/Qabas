# Frontend implementation instructions

**Purpose:** give the Flutter engineer an executable work sequence. Screens/appearance belong to the frontend handoff; API formats and shared acceptance are referenced.

## Inputs and initial setup

Use the approved package manifest/contract identity; read [frontend handoff](../04_FRONTEND/FRONTEND_HANDOFF.md), [API requirements](../03_API/API_REQUIREMENTS.md), [animation/media](../07_ANIMATION/ANIMATION_AND_MEDIA_HANDOFF.md), [mock guide](../09_VALIDATION/MOCKS_AND_FIXTURES.md) and [setup](SETUP_AND_REPRODUCTION.md). Begin from the delivered Flutter source/assets/lockfile in a writable checkout. Resolve native/retracted dependency and target-platform decisions before release; preserve source identity for comparison.

## Work sequence

1. **Models and repositories.** Generate complete typed public DTOs from the [revision 10](../03_API/contract_revision10/README.md) 99-root custom schema/dispatch map (unknown response fields ignored, unknown enum values mapped to `unknown`). Test nulls/enums/nested block/exercise/event/client-message payloads and JSON round trips against fixtures and the API examples. Build equivalent mock/live repositories and the shared HTTP layer: secure token storage, contract identity headers, `401`/`426` handling, idempotency keys, error mapping, polling, uploads and a socket adapter that always connects through a freshly fetched `ws_url`. The six delivered display DTOs cover only focused panels.
2. **Session controller.** Replace demo grading/state with a typed controller that consumes pinned Session content/history, server evaluations/finish and mode rules. Keep local story/reveal/predict/UI preferences separate. Implement incomplete submission gating, retry eligibility, mode-dependent disclosure, authoritative evaluation application, duration/progress and same/fresh-device recovery. Recorded attempts replay; do not create duplicate effects or rewind reading progress.
3. **Reference integration.** Adapt original hook/story/teach/hotspot/choice/categorize/order/recite/feedback/completion widgets to shared IDs/payloads. Reuse painters/motion/theme; preserve all source text/track differences, 54 card values, source drawers and 12 banks. Maintain Arabic order secondary labels, metadata-selected decoration and placement sky/slot semantics. Do not locally reshuffle arrays or import private gold/native snapshots into widgets.
4. **Broader exercise coverage.** Build all 14 renderers, both presentations, challenge true_false, neutral prediction/myth, whole/segment recitation and applicable outcomes. Wire correctly typed per-item details, partial feedback, flashcard behavior and timeout/skip/unavailable/hidden states. Add non-Salah fixtures to prove generality.
5. **Other routes.** Wire onboarding (including the curiosity page and its bundled reviewed bridges), journey/Roadmap with the Soft Lock sheet, Discover, guide/reader/glossary/review, Raqeeb inputs/classes/failures, profile/settings/activity/quests/achievements, league/friends/challenges and reviewer Gate 1/2/blind/metrics screens through the same repositories. Respect privacy and local/server preference boundaries.
6. **Generated-scene package.** Implement the shared renderer against [scene renderer semantics](../07_ANIMATION/SCENE_RENDERER_SEMANTICS.md) (confirm or amend it first, O-02): PRNG test vectors, precedence/transition/track fixtures, reduced-motion still, compositing. Build the headless preview CLI from the same package with the backend preview owner. Validate a new asset-bearing scene and actual download/checksum/unsupported/reduced-motion/resume paths, and golden equality within §8 thresholds.
7. **Integration and release.** Run full source/API goldens and interaction traces for four reference variants and both motion settings, then mock/live coverage and targeted platform/device tests. Resolve known font fallback, dependency and production-display decisions with approved baseline updates. Add the release-bundle scan for private/mock data to CI.

## Required artifacts

Complete DTO generation/checks, repository/controller code, reusable renderers, platform builds, source/API full-screen captures/recordings, per-type/mock/live coverage and supported scene capability/build evidence. Keep implementation status honest in [quality criteria](../09_VALIDATION/QUALITY_AND_ACCEPTANCE.md).

Shared acceptance gates and build order are in [the plan](SHARED_IMPLEMENTATION_PLAN.md). The optional companion must compile/run when replaced or removed without changing backend requests or lesson data.
