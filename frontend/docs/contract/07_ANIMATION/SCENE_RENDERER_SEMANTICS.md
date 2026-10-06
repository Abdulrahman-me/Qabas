# Scene renderer semantics (`qabas.scene/1`)

**Purpose:** define how a validated `.scene.json` manifest becomes pixels, so the app renderer (`packages/qabas_scene`) and the preview CLI (`tools/scene_preview`) agree, and so validators, auditors and authors can reason about every state and time. Grammar and limits live in [scene.schema.json](../03_API/contract_revision10/contract/scene.schema.json) and the [capability registry](../03_API/contract_revision10/contract/scene_capabilities.production.json). Wire use of scenes is in [API §5.5e](../03_API/API_REQUIREMENTS.md).

**Status:** engineering baseline written during the final review to close the semantic gap behind open decision **O-02**. Wherever the received non-normative SVG preview (`tools/scene_check.py`) already makes a choice, these rules keep it: rule override, additive/multiplicative tracks, whole-cycle easing and the transform order. They add what that preview leaves undefined or non-portable. The Flutter renderer owner confirms or amends these rules **before the first capability is released**. Until then changes are free. Afterwards, any change of meaning needs a new capability ID (for example `track/2`) or a new schema version, never a silent reinterpretation of published content.

## 1. Inputs and determinism

A frame is a pure function of: the manifest and its verified assets; the current state values `S` (manifest defaults, overridden by `Visual.params`, then by beat/teach-point/binding changes); the state-change history needed for an in-progress transition (previous displayed values, time since the change); the scene clock `t` (ms); the reduced-motion flag; and the renderer build. No network, device clock, locale, text direction, random source or frame count may influence the output.

- **Scene clock:** milliseconds since the renderer for this `scene_id` + `version` was mounted. It keeps running across state changes (consecutive beats or points that reuse one mounted renderer, §5.6 of the API). It pauses while the widget is not visible (`TickerMode` off) and resumes from the paused value.
- **Preview frames** are rendered for an explicit `(state, t)`. When a preview asks for a transition sample it supplies `(from_state, to_state, t_since_change, t)`.

## 2. Coordinates and painting order

- View-box units; origin top-left; +x right, +y down; rotation in degrees, positive clockwise on screen. The scene is scaled uniformly to its occurrence box. `Visual` validation guarantees the box proportion equals the view-box proportion, so no cropping or letterboxing happens. Scenes, anchors and pins are never mirrored in RTL.
- Layers paint depth-first in array order (later is on top). A group has no geometry of its own.
- Geometry is in the layer's local space: `rect` (`x`, `y`, `w`, `h`, `corner` radius clamped to `min(w,h)/2`), `ellipse` (`x`, `y` = centre, `rx`, `ry`), `path` (`d`, SVG subset M L H V C Q Z, absolute and relative, non-zero fill rule), `asset` (box `x`, `y`, `w`, `h`), `sparkles` (box `x`, `y`, `w`, `h`).
- Anti-aliasing on. Colors are sRGB.

## 3. Property resolution per layer

For each layer and frame:

1. **Base values:** `opacity` (default 1), `transform.x`/`y` (0), `rotation` (0), `scale` (1), `origin_x`/`origin_y` (0), `fill`.
2. **State rules → target values:** evaluate `state_rules` in array order. Every rule whose `when` holds for the current `S` applies its `set`, and a later matching rule overrides an earlier one property by property ("last match wins"). `set.x`/`set.y`/`set.rotation`/`set.scale` replace the transform values; `set.opacity` replaces opacity; `set.fill` replaces the fill with a palette color. A condition holds when every listed state satisfies every listed operator (`eq`, `gte`, `lte`, `in`).
3. **Transitions:** when `S` changes, each property whose target changes animates from its currently displayed value (including a transition still in progress) to the new target. Duration and easing come from the rule that supplies the **new** target. If the new target is the base value (no rule matches), they come from the rule that supplied the **previous** target. With no `transition_ms`, or in reduced motion, the change is instant. Numbers interpolate linearly after easing. Solid fills interpolate per RGBA channel in sRGB. A change between a gradient and a solid fill is instant.
4. **Tracks:** every track whose `active_when` is absent or holds for the current `S` contributes a value `v(t)` (§4). `translate_x`/`translate_y` add to `x`/`y`, `rotation` adds degrees, `scale` multiplies, and `opacity` multiplies. Several tracks on one property compose the same way. An inactive track contributes the identity (0, or 1 for scale/opacity); switching activity is instant, so authors keep identity-valued keyframes at loop boundaries when a jump would be visible.
5. **Final values:** opacity is clamped to [0, 1]. Scale is always > 0, enforced by the validator (§9).

## 4. Track timing

With `u = t − delay_ms` and `d = duration_ms`:

- `u < 0` → value of the first keyframe.
- `loop: none` → `p = clamp(u/d, 0, 1)`; `repeat` → `p = (u mod d)/d`; `ping_pong` → `q = (u mod 2d)/d`, `p = q ≤ 1 ? q : 2 − q`.
- Easing applies to the **whole cycle position**: `e = ease(p)` with `linear: p`, `ease_in: p²`, `ease_out: 1 − (1 − p)²`, `ease_in_out: 0.5 − 0.5·cos(π·p)`.
- The value is piecewise-linear over the keyframes at `e` (keyframe `t` strictly ascending from 0 to 1, enforced by the checker).

## 5. Transforms, opacity and compositing

- Local matrix = `T(x, y) · T(origin_x, origin_y) · R(rotation) · S(scale) · T(−origin_x, −origin_y)`; world = parent world × local.
- Group opacity below 1 composites the group's children into an offscreen layer and then applies the opacity (SVG group semantics). Leaf opacity applies to that leaf's paint only. A group with a single child may apply opacity directly; the result is identical.

## 6. Paint, clip, assets, sparkles

- **Palette:** names resolve to `#RRGGBB[AA]`. `token:<name>` resolves through the renderer build's frozen token table, which is published with the capability release evidence. An unknown token is a validation error.
- **Gradients:** coordinates in the layer's local space (user space). Linear runs `from` → `to`; radial uses `center` and `radius`. Stops are ordered by `at`, with pad spread.
- **Stroke:** palette color, `stroke_width` local units, centered on the geometry, butt caps, miter joins (limit 4), painted after the fill.
- **Clip (`clip/1`):** `clip` names a `rect`/`ellipse`/`path` layer whose geometry is used, in the clipped layer's **local** space, as an anti-aliased clip for that layer and its descendants. Clip-source layers are definitions only: they are not painted where they appear, and they have no rules, tracks or anchors.
- **Assets:** the decoded image is stretched to its box. The validator requires the box proportion to be within 1 % of the asset's `width/height`. Raster assets use linear filtering. SVG assets are drawn by the package's own parser for the validated subset (no general SVG library), so app, preview and validator accept exactly the same features.
- **Sparkles (`fx.sparkles/1`):** solid palette fill only. Particle `i` (0-based) draws from the PRNG below, seeded with `seed` (as uint32), in this order: `px = x + r()·w`, `py = y + r()·h`, `phase = r()`. It is a circle of radius `2 + 2·phase` local units with alpha `0.4 + 0.6·|sin(π·(t/2000 + phase))|`, multiplied by the layer opacity. PRNG `r()` is mulberry32:

  ```python
  def mulberry32(seed):              # all arithmetic on unsigned 32-bit integers
      state = seed & 0xFFFFFFFF
      def r():
          nonlocal state
          state = (state + 0x6D2B79F5) & 0xFFFFFFFF
          z = ((state ^ (state >> 15)) * (state | 1)) & 0xFFFFFFFF
          z = (z ^ ((z + (((z ^ (z >> 7)) * (z | 61)) & 0xFFFFFFFF)) & 0xFFFFFFFF)) & 0xFFFFFFFF
          return ((z ^ (z >> 14)) & 0xFFFFFFFF) / 4294967296   # [0, 1)
      return r
  ```
  Test vectors (checked against the canonical JavaScript mulberry32): seed 1 → 0.6270739405881613, 0.002735721180215478, 0.5274470399599522; seed 42 → 0.6011037519201636, 0.44829055899754167, 0.8524657934904099. The Dart implementation must reproduce them exactly. The received SVG preview uses Python's Mersenne Twister and is therefore not comparable for sparkles.

## 7. Reduced motion and fallbacks

- With reduced motion, `t` is fixed at `reduced_motion.still_time_ms` for every track and sparkle field, and state changes apply instantly. Tracks still respect `active_when`. (The received SVG preview skips tracks entirely in reduced motion; that deviates and is non-normative.)
- A fallback image is the reduced-motion still rendered at its `fallback_params`, exported as WebP at the view-box size: lossless if ≤ 1 MB, otherwise quality 90.
- At runtime the client re-checks the schema version, its compiled capability list, limits and every `sha256`, and decodes assets before the first frame. Any failure shows the fallback image, never a partial scene. Manifest plus assets must load within 10 s; otherwise the fallback is shown and the download is retried the next time the scene is displayed.

## 8. App/preview equality and release evidence

- App and preview must run the same `qabas_scene` version on the same Flutter engine version and rendering backend. The preview records all three in `ScenePreview.renderer_version`.
- **Golden equality:** for each compared `(state, t)` frame at the same size, mean absolute channel error ≤ 0.5/255 and 99th-percentile channel error ≤ 8/255. Larger differences fail the comparison, even if they are only at anti-aliased edges.
- A capability may become `released` only with: the app build that includes it (`min_app_version`); goldens for every primitive and option it covers; transition, reduced-motion and fallback samples; device timings against the registry's performance target; and the frozen token table. Release evidence is attached to the registry entry (`release_evidence`).

## 9. Validator rules added by these semantics

The schema is unchanged. `tools/scene_check.py` in the [revision 10 contract](../03_API/contract_revision10/tools/scene_check.py) enforces the first five rules. The others need the renderer or preview and are publish gates for `tools/scene_preview`.

| Rule | Where |
|---|---|
| Rule and track `scale` values are > 0 | `scene_check.py` (rev 10) |
| Clip sources have no state rules, tracks or anchors and are not anchored layers | `scene_check.py` (rev 10) |
| Sparkles use a solid palette fill | `scene_check.py` (rev 10) |
| Asset box proportion within 1 % of the asset's pixel proportion | `scene_check.py` (rev 10) |
| `token:` palette entries exist in the release token table (when a token table is supplied) | `scene_check.py` (rev 10) |
| **Anchor visibility:** in every state an exercise can show (authored state, binding states, after-evaluation states) and at every `preview.frames_ms` plus the still time, the anchored layer has world opacity ≥ 0.5 and is the topmost painted layer (or an ancestor/descendant of it) at the anchor point. Checked from an ID buffer rendered by the preview | `tools/scene_preview` (P1) |
| Fallback pixels equal the reduced-motion still at `fallback_params` (golden equality above) | `tools/scene_preview` (P1) |
| Measured p95 frame build+raster ≤ 8 ms and first frame ≤ 150 ms on the reference devices | release evidence |

## 10. Performance practice

Parse paths once per manifest version, cache decoded assets per `(scene_id, version)`, avoid offscreen layers except where §5/§6 require them, and keep at most two scene renderers mounted at a time (current and outgoing during a crossfade). Stop the ticker when the scene is off-screen.
