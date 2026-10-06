# Animation and media handoff

**Purpose:** define animation ownership, reference mapping, bespoke-scene workflow and media delivery. Exact wire fields/manifest bounds live in [API §5.5/§7.12](../03_API/API_REQUIREMENTS.md) and the canonical [scene schema](../03_API/contract_revision10/contract/scene.schema.json)/[checker](../03_API/contract_revision10/tools/scene_check.py). How a manifest renders is normative in [scene renderer semantics](SCENE_RENDERER_SEMANTICS.md). Factory gates live in the factory handoff.

## Implementation status (audited 2026-10-03)

Audit of the working folders, the received delivery (`10_REFERENCE`) and the history archives (`11_HISTORY`, read without modification), plus the audit machine's tooling. A capability counts as implemented only when its code was found and, where possible, run; a description in a document is not enough.

| Capability | Status | Evidence |
|---|---|---|
| Builtin scenes `river_house`, `workplace`, `day_arc`, `pillars` | **Implemented** in the Flutter reference (compiled painters); Salah-specific | [scenes.dart](../10_REFERENCE/engineer_delivery/reply8/flutter_reference/lib/widgets/scenes.dart), `api_builtin_visual.dart`, 32 exported frames in `reference_export/flutter_frames`; Flutter is not installed on the audit machine, so they were not re-run |
| Scene manifest contract `qabas.scene/1`, capability registries | **Implemented** (schema and data) | [scene.schema.json](../03_API/contract_revision10/contract/scene.schema.json); simulation registry all `released`, production registry all `proposed` |
| Scene validator | **Implemented and tested** | `tools/scene_check.py`; revision 10 checks; the sample manifests pass |
| SVG preview `scene_check.render_svg` | **Partial, test only**: deviates from the semantics (reduced motion, sparkle PRNG; no transitions, clips, strokes or assets) | Reproduced the delivered sample fallback within a mean channel difference of about 0.7/255 through headless Chromium |
| Test-media generator `tools/make_mock_assets.py` | **Implemented, test media only**: scene fallbacks from the SVG preview, abstract placeholder lesson images, a synthetic tone | Needs Python Playwright (Chromium) and ffmpeg |
| Normative renderer `packages/qabas_scene`; preview CLI `tools/scene_preview` | **Specified, not implemented** | [renderer semantics](SCENE_RENDERER_SEMANTICS.md), factory §13.8, O-02 |
| Released scene capabilities | **None** | [production registry](../03_API/contract_revision10/contract/scene_capabilities.production.json) |
| Flutter renderer for generated scenes and network images | **Missing** | The Flutter reference renders builtins only and has no network-image path |
| Visual Selector, Image Prompt Writer, Animated Scene Author, Visual Auditor | **Specified, not implemented** | Factory §13.1, agent catalog |
| Image generation behind `IMAGE_PROVIDER` | **Specified interface only**: no provider chosen, no adapter; the style guide (`content/style_guide.md`) and character reference sheet it needs do not exist | System architecture stack, operations environment |
| Medallion registry (`content/medallions/registry.yaml`) and medallion SVGs | **Specified, not present** | Factory §13.4 |
| Static SVG artwork | **Specified** as a validated subset (`asset.svg/1`, proposed); no production artwork | Formats table below |
| Learner-facing video | **Not in the contract**: `Visual` has no video kind; WebM is reviewer evidence only | Contract `Visual`, `AnimationPreview` |
| Remotion | **Historical, source missing.** Used by the earlier concept prototype (`11_HISTORY/PREVIOUS_ENGINEER_CONTEXT.zip`, `ConcpetQabas`): its README describes `videos/remotion` and `videos/hyperframes` projects that were never supplied; one rendered MP4 (`motion-remotion`), its poster and a `river_house.svg` survive. No specification, code, dependency or test in the current handoff | Prototype `README.md`, `prototype/build.py`, `video_choice.json`, `dist/video.mp4`; the previous engineer's own context note says the `videos/` projects were absent |
| HyperFrames | **Historical, source missing**: named in the same prototype README and build script; no source and no surviving output | Same archive |
| FFmpeg | **Specified** for learner-audio normalisation (backend); not on the audit machine's PATH; Playwright's minimal build (MJPEG input, VP8/WebM output) is present | [Backend handoff](../05_BACKEND/BACKEND_HANDOFF.md) (learner recordings) |
| Asset storage and CDN | **Specified**, not implemented (immutable content-addressed `scenes/<scene_id>/v<version>/`, signed draft URLs); every documentation and fixture URL is `cdn.example.com` or `mock-asset://` | API §3.8, fixtures |
| Visual readiness and publication gate | **Implemented as contract helpers** (`contextual.visual_readiness`, `contextual.placeholder_media_errors`) and tested | Revision 10 checks, factory §13.4 |

**The real flow today.** A lesson visual can be (1) a builtin, which works only for the four Salah-specific scenes; (2) a generated image, which cannot be produced because no provider exists; or (3) a generated scene, which can be authored, validated with `scene_check.py`, previewed with the non-normative SVG preview (frames, reduced-motion still, fallback, a WebM via headless Chromium and Playwright's ffmpeg) and audited by looking at the frames. The flow stops there: the scene is `capability_blocked` against the production registry and `preview_only` with the simulation registry. Nothing can be published, and no app build can render a generated scene. Because hooks and story beats require a `Visual`, no Unit 0 lesson can currently reach production readiness.

**Representative test asset.** `TEST_LESSONS/assets/scenes/scn_u0l1_doorstep/v1` (outside this package): one scene for lesson 0.1's box-at-the-door card, built by `TEST_LESSONS/tools/build_scene.py` through the delivered workflow (manifest → `scene_check.py` against both registries → `render_svg` → headless Chromium → PNG frames, lossless WebP fallback, VP8 WebM). It was audited in two attempts against §13.4 and the visual QA criteria, and the test lesson player shows a different focus state for each teaching point. Readiness `preview_only` / `capability_blocked`: real pixels for testing, never publishable.

**What real visuals need** (open decision O-13): an image provider behind `IMAGE_PROVIDER`, with the style guide and character reference sheet written from the [brand imagery rules](../01_PRODUCT/CONTENT_AND_BRAND_POLICY.md); `packages/qabas_scene` and `tools/scene_preview`, with a first capability release and its evidence (O-02); the Flutter generated-scene renderer; object storage and CDN; the medallion assets. Whether learner-facing video is wanted at all is product decision P-08. If it is, it needs a contract kind and a pipeline; Remotion and HyperFrames would be candidates to evaluate, not existing assets.

## Existing reference drawings

| Reference | Compiled implementation | Local loop | API data |
|---|---|---|---|
| House, river, palms, glow, prayer lights | `RiverHouseScene` | 5 s | `builtin`, `river_house`, v1, beat 0–3 |
| Workplace clock and steam | `WorkplaceScene` | 60 s | `builtin`, `workplace`, v1; illustrative clock around 12:10 |
| Changing day sky | `DayArcScene` | 8 s | `builtin`, `day_arc`, v1, highlight −1–4 |
| Pillars | `PillarsScene` plus localized labels | 4 s | `builtin`, `pillars`, v1, highlight 0–4 |
| Prayer-slot phase art | `PhaseIcon` | Local widget | Category phase in day order |
| Sorting bucket decoration | `UnitArtIcon` | Local widget | Registered `Category.art_key`; reference prayer_rug/heart |
| Ordering dawn/night header | `PhaseIcon` | Local widget | `POrderSteps.presentation = day_sequence`; plain otherwise |

Reuse [scenes.dart](../10_REFERENCE/engineer_delivery/reply8/flutter_reference/lib/widgets/scenes.dart), theme/fonts and the original motion tokens. Continuous loops and story/reveal/selection/placement transitions run in Flutter. Backend supplies authored state/content and server evaluation, with no per-frame updates or companion coupling.

Per-use proportions: hook workplace 1.75, river story 1.5, river/pillars teach 1.9, day teach 2.1, river hotspots 1.15, placement arc 2.8. Builtins freeze at controller value 0.3 for reduced motion, while current content parameters still apply. Pillars use the source Arabic alignment/label mapping; scenes/maps/pins generally keep their own geometry instead of mirroring with surrounding RTL.

River hotspots use beat 1 and source coordinates: palm 16/36, door 55/52, window 80/34, river 42/86 percent. Source day teaching evolves −1 → 1 → 4 → 4; placement starts at dawn and changes with the selected destination. Preserve tap/drag/replacement/clear, labels and token states through the shared controller.

## Bespoke scenes authored by agents

The backend content pipeline can create new moving scenes. Agents author bounded **declarative scene data and artwork**, and the reusable Flutter renderer interprets that content. Reference builtins remain exact compiled scenes.

1. Select/author a scene brief supported by released renderer capabilities and the product imagery policy.
2. Create an immutable `.scene.json` manifest (`qabas.scene/1`), assets, view box, typed states, layer geometry/palette, tracks/rules, anchors and necessary interaction bindings.
3. Validate schema plus grammar/limits/capabilities/actual asset bytes/hash/MIME/dimensions; reject unknown/out-of-range states, unstable/misaligned hotspot anchors and inconsistent fallbacks.
4. Render state/time frames, transitions, reduced-motion still, animation preview and fallback with the **same `packages/qabas_scene` build** used by Flutter. Property precedence, transform composition, rule/track ordering, interpolation, loop phase, the sparkle PRNG and reduced motion follow [scene renderer semantics](SCENE_RENDERER_SEMANTICS.md); implement its PRNG test vectors and golden-equality thresholds first.
5. Audit rendered content/geometry/visibility, obtain actual reviewer approval, publish immutable manifest/assets/receipts and expose the production released-capability registry.
6. Flutter downloads/verifies/pins the manifest/assets, applies initial/local/evaluation state bindings, renders locally and shows the defined fallback for failures/unsupported capabilities. Resume preserves the old served version after later publication.

New scenes within the shipped capability set require no per-scene app release. A genuinely new primitive/behavior requires reviewed Dart code, tests, app build/release and capability registration first. Agents may propose that development work; learner payloads never download arbitrary Dart/scripts or execute generated code.

The delivered static checker and sample SVG preview do not prove a normative scene renderer (the SVG preview also deviates from the semantics in reduced motion and sparkles). The production registry currently has no released capabilities. Composed motion, anchor visibility, app/preview identity, device performance and unsupported/download/error paths are explicit acceptance gates (semantics §8–§9).

## Formats and delivery

| Artifact | Extension / MIME | Requirements |
|---|---|---|
| Scene manifest | `.scene.json` / `application/json` | Schema/version, digest, view box, capability and immutable asset references |
| Static illustration/fallback | `.webp`, `.png`, `.jpg` / `image/webp`, `image/png`, `image/jpeg` | Exact dimensions/proportion, hash where declared, localized alt; fallback state agrees with visual |
| Permitted static artwork/medallion | `.svg` / `image/svg+xml`, or accepted raster | Only supported validated subset; approved calligraphy/content; anchors/compositing preserved |
| Rendered frames/still | `.png` / `image/png` | Renderer/build/state/time identity for review and golden comparison |
| Animation preview | `.webm` / `video/webm` | Reviewer evidence, not a replacement for app scene behavior |
| Narration/pronunciation/reciter clip | `.mp3` / `audio/mpeg` | Approved source/license; exact text/range and applicable word timings; Quran never TTS |
| Learner recording | Contract-supported multipart audio | Exact field/size/MIME limits in API; backend normalizes to 16 kHz mono WAV |
| UI companion | Current bundled `.riv` or any replacement Flutter implementation | Local asset/behavior, no API identity |

**Delivery:** published media is served from the public content CDN at immutable, versioned, content-addressed paths with long-lived cache headers (API §3.8). Draft/preview media and gold candidates are private (signed URLs). Learner recordings are never stored.

`map_place` generated-scene pins bind declared static anchors. Manifest/fallback proportions alone do not prove target alignment; test visible object positions and hit regions. Fallback parameters must match authored state for hotspots; use defined error/alternate states rather than silently grading against mismatched geometry.

Reference recitation is seven words of An-Nisa 4:103, words 14–20 under the bundled tokenization that excludes standalone pause marks. Approved text, audio clip, timings and bound check must agree on that range. The supplied unavailable URL and synthetic tone fixtures do not provide playback or recognition evidence.

See [quality gates](../09_VALIDATION/QUALITY_AND_ACCEPTANCE.md) for the new non-Salah asset-bearing scene and full reference-motion acceptance.
