# qabas_scene

Local, presentation-only Flutter renderer for `qabas.scene/1`. It has no Qabas
app imports. Its immutable manifest and deterministic engine are pure Dart;
the canvas program, lifecycle-aware widget and cache adapter use Flutter.

The normative contract is
[SCENE_RENDERER_SEMANTICS.md](../../docs/contract/07_ANIMATION/SCENE_RENDERER_SEMANTICS.md).
This build is `qabas_scene/1.0.0` and implements exactly:

```
scene/1
shape.rect/1
shape.ellipse/1
shape.path/1
paint.gradient/1
track/1
fx.sparkles/1
```

These are compiled renderer capabilities, not a publication approval for a
backend registry. Unsupported capabilities, assets, anchors or clipping reject
the whole scene. The caller supplies the localized image/alt fallback and a
public-media byte loader; the package makes no authenticated network requests.

`SceneCache` verifies SHA-256 over the original bytes and the reference's
identity, dimensions and capability list. It coalesces downloads, bounds them
to ten seconds and keeps a 24-entry LRU cache by scene ID/version/hash. Failed
loads are evicted. Validation enforces the contract's size, nesting, geometry,
state, rule, track and particle limits before any canvas program is created.
JSON Schema integers accept integral numbers such as `1.0`; integer state
values are canonicalized so native and JavaScript resolve the same manifest.

`SceneView` keeps its scene clock across parameter changes, reads physical
coordinates without RTL mirroring, and repaints without rebuilding the widget
tree on every frame. It pauses under TickerMode, application suspension or
scroll/viewport invisibility. Reduced motion paints at `still_time_ms` and
applies state changes immediately. Canvas paths, gradients and particle
geometry compile once per mounted program. At most two programs participate
in the app's scene/step crossfade.

State resolution follows base → last matching property rule → interruptible
transition → additive/multiplicative tracks. Returns to base use the previous
rule's transition. Tracks ease over a whole cycle, support all three loop
modes, and evaluate `active_when` against the current state. Sparkles use the
contract's mulberry32 sequence, with 16-bit multiplication limbs to preserve
32-bit behavior when compiled to JavaScript.

The frozen sRGB token table for this renderer version is independent of the
app's mutable theme. Unknown tokens reject the manifest.

| Token | sRGB |
|---|---|
| night_emerald | #073C37 |
| emerald | #0B5A52 |
| flame_gold | #E0A526 |
| soft_ember | #F6E3B4 |
| morning_mint | #EEF5F2 |
| deep_ink | #16233A |
| slate | #566476 |
| surface | #FFFFFF |
| surface_sunk | #F5F9F7 |
| line | #DCE7E3 |
| line_strong | #C5D6D0 |
| muted | #8A97A6 |

Run from this directory:

```sh
flutter analyze --no-pub
flutter test --no-pub
flutter test --no-pub --platform chrome test/engine_test.dart
```

App integration, all 20 manifests and all 86 authored stills are checked from
the repository root:

```sh
flutter test --no-pub test/scenes/
sh tool/test_web.sh
flutter drive --no-pub --keep-app-running --driver=test_driver/phase7_scenes.dart --target=integration_test/phase7_scenes_test.dart -d <device> --dart-define-from-file=config/mock.json
python3 tool/drive_phase7_scenes.py --device emulator-5554
```

The still comparison renders at 800 × 500 and requires mean absolute RGBA
channel error ≤ 0.5/255 and 99th-percentile error ≤ 8/255. Evidence is written
to `build/phase7/backend_still_comparison.json` and `build/phase7/frames/`.
The native tour measures all 20 cold first frames and steady build+raster
timings, then plays the ordinary 0.1 hook and first teaching card in both languages
with motion on/off. It saves captures in `build/tour/phase7/` and timing data in
`build/phase7/<platform>_frame_timings.json`. Report the actual device and build
mode; debug emulator measurements do not establish physical-device budgets.
Use the Python host helper on Android to capture through adb; Android 17's
integration screenshot conversion stalls with the external Rive textures.
Its `--tour flow` / `--tour benchmark` options support focused repeats. Timings
sample naturally scheduled frames, with build and raster costs reported
separately. Empty-app engine startup is excluded from cold media loading.
