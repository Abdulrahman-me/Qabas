# 09 — Character system and Rive

Qabas has animated characters that react to what happens: greeting, encouraging, celebrating, thinking. They are **presentation only**: never in API payloads, domain code or BLoC logic. They must be swappable or removable without touching screens (product requirement PR-13, decision AD-06).

The first character exists: the **guide traveller**, a faceless traveller in a hooded emerald cloak and gold scarf carrying the ember. Its Rive file is **already in the app** at `assets/characters/guide_traveler/guide_traveler.riv` (≈ 49 KB, declared in `pubspec.yaml`). Its source and generator are in the app at `tool/rive/guide_traveler/` (`generate.py`, `scene.rml`, `build.sh`, `README.md`, `contact_sheet.py`), and `build.sh` writes straight to that asset path. The prototype integration to port is `/Users/aw/Documents/qpr/qabas/lib/widgets/companion.dart`. This document generalises that integration into a multi-character system.

## 1. Principles

1. **Semantic vocabulary.** App code says *what is happening* (`CharacterCue.correct`, `CharacterMood.thinking`), never how the rig moves. No app code touches timelines, bones, nodes or transforms.
2. **Roles, not characters.** Screens ask for a *role* (`CharacterRole.guide`). A registry decides which character plays it. Swapping the character is a registry/setting change.
3. **One contract for every character.** Each character declares, in a typed spec, how the shared vocabulary maps to its rig and which parts it supports. Unsupported moods or cues degrade gracefully.
4. **Always a fallback.** Loading, failure, unsupported platform, character disabled: a calm placeholder holds the space (a quiet flame, never a spinner), and the layout never depends on the character being there.
5. **Reduced motion respected.** With reduced motion on, cues are not fired; the character rests in its calm idle.
6. **Content policy.** Characters are ordinary modern people or objects with **completely blank faces**; they never depict prophets, companions, angels or any historical person. No text is baked into the art. The ember stays a soft teardrop, never a blaze.

## 2. Vocabulary

```dart
enum CharacterRole { guide, assistant }          // guide = companion traveller; assistant = Raqeeb presence (optional)

enum CharacterMood { idle, thinking, listening, speaking }   // persistent; app → Rive

enum CharacterCue { greet, encourage, correct, retry, celebrate, complete, streak }   // one-shot; app → Rive
```

| Mood | Meaning | Used when |
|---|---|---|
| `idle` | Calm presence, breathing, scarf and ember flicker | Default everywhere |
| `thinking` | Hand to chin, ember orbiting | Lesson hook (the curiosity question), Raqeeb processing |
| `listening` | Attentive, turned toward the learner | Recording a voice question or a recitation |
| `speaking` | Gentle open-hand gesture, ember pulsing | Raqeeb answer appearing; companion speech bubbles in onboarding |

| Cue | Rig behaviour (guide traveller) | Fired when |
|---|---|---|
| `greet` | Wave hello | A screen with a companion first appears (onboarding, journey, lesson intro, profile) |
| `encourage` | Dip, fist up, nod: "you've got this" | Predict feedback (neutral), quit sheet, **Soft Lock sheet**, a non-winning challenge, familiarity choice |
| `correct` | Quick hop, flash of light, sparkles | Correct answer feedback; onboarding choices |
| `retry` | Ember dims, sheepish hand to hood, nod, rekindles | "Not quite" feedback (warm, never discouraging) |
| `celebrate` | Crouch, jump with arms up, ripple and burst | Onboarding "ready" page, review complete, challenge won |
| `complete` | Arms open, ember rises and blooms | Lesson complete |
| `streak` | Raises the ember, which grows into a fuller (still gentle) flame | Streak celebration |

These placements come straight from the prototype (search `CompanionReaction.` in `/Users/aw/Documents/qpr/qabas/lib/`) and must be kept.

## 3. Folder layout

```
assets/characters/
  guide_traveler/guide_traveler.riv          # ✓ in place (the prototype's companion.riv)
  raqeeb_lantern/raqeeb_lantern.riv          # optional, future (painter fallback until it exists)
lib/core/characters/
  character_vocabulary.dart                  # CharacterRole, CharacterMood, CharacterCue
  character_spec.dart                        # CharacterSpec, RiveRigSpec, CharacterLayout, CharacterFallbackKind
  specs/guide_traveler.dart                  # const spec for the existing companion
  specs/raqeeb_lantern.dart                  # painter-rig spec (Tier C: Rive later)
  character_registry.dart                    # all specs + default role → character id
  character_settings_cubit.dart              # enabled flag, role overrides (persisted locally)
  rig/character_rig.dart                     # abstract rig interface
  rig/rive_character_rig.dart                # Rive implementation (generalised prototype code)
  rig/painter_character_rig.dart             # Flutter-painter implementation (fallback / simple characters)
  character_asset_cache.dart                 # loads each .riv once, shares the File
  character_controller.dart                  # semantic handle for one on-screen character
  character_view.dart                        # the widget screens use
  character_cue_mapping.dart                 # pure helpers: evaluation → cue, etc.
tool/rive/guide_traveler/                    # ✓ in place: generator, scene.rml, build.sh → assets/characters/guide_traveler/, README
```

## 4. The runtime contract every Rive character follows

The existing companion already follows this shape (names in brackets are its actual values):

| Item | Name | Type | Values / purpose |
|---|---|---|---|
| Artboard | per spec [`Companion`] | Artboard | Transparent, square (400 × 400), headroom above the figure for jumps |
| State machine | per spec [`Companion`] | State machine | Layers `Mood` and `Ambient` |
| View model | per spec [`Companion`], instance [`Default`] | View model | Exported default instance |
| Property | `mood` | Enum | Subset of `idle`, `thinking`, `listening`, `speaking` (companion: `idle`, `thinking`); initial `idle`; app → Rive |
| Properties | `greet`, `encourage`, `correct`, `retry`, `celebrate`, `complete`, `streak` | Trigger | One-shots; app → Rive; each returns to the current mood by itself |
| Optional | `reducedMotion` | Boolean | If present, the app sets it so the rig can use calmer ambient motion |

Nothing flows from Rive back to the app. The app never reads Rive events or internal state.

**State machine structure** (required for new characters):

- **`Mood` layer:** Entry → `Idle`. `Idle` ↔ each mood state on the `mood` enum condition, with 300–400 ms eased blends (the companion uses 380 ms). **Any State → each reaction state** on its trigger (≈ 160 ms), with *reset on retrigger* so repeated cues restart. Each reaction exits at 100 % exit time back to `Idle` (≈ 260 ms), then the mood conditions route on to `Thinking`/`Listening`/`Speaking` if that mood is still set.
- **`Ambient` layer:** a single looping state (breathing, cloth, flame flicker, glow) that keys **only** objects the `Mood` layer never keys, so the layers never fight.
- Every mood timeline keys the same full set of rig properties, so a state never inherits stray values from the previous one.
- Size and fit: square artboard with headroom; the app aligns it bottom-centre with `Fit.contain` (or `Fit.fitHeight` for narrow slots) and may enlarge it with `zoom`, letting the headroom overflow.
- No text, fonts, images or scripts embedded. Target ≤ 100 KB.

## 5. Specs and registry

```dart
final class CharacterSpec {
  const CharacterSpec({
    required this.id,
    required this.rig,                      // RiveRigSpec or PainterRigSpec
    required this.supportedMoods,
    required this.supportedCues,
    this.moodFallbacks = const {},          // e.g. {listening: idle, speaking: idle}
    this.cueFallbacks = const {},           // e.g. {streak: celebrate}
    this.layout = const CharacterLayout(),  // fit, alignment, default zoom, aspect
    this.fallback = CharacterFallbackKind.flame,
    required this.semanticsLabel,           // String Function(AppLocalizations l10n)
  });
  final String id;
  // …
}

final class RiveRigSpec {
  const RiveRigSpec({
    required this.assetPath,
    this.artboard,                          // null → default artboard
    this.stateMachine,                      // null → default state machine
    this.viewModelInstance,                 // null → DataBind.auto()
    this.moodProperty = 'mood',
    this.moodValues = const {},             // CharacterMood → enum value name in the rig (default: same name)
    this.cueTriggers = const {},            // CharacterCue → trigger name (default: same name)
    this.reducedMotionProperty,             // optional Boolean
  });
}

const guideTraveler = CharacterSpec(
  id: 'guide_traveler',
  rig: RiveRigSpec(
    assetPath: 'assets/characters/guide_traveler/guide_traveler.riv',
    artboard: 'Companion',
    stateMachine: 'Companion',
    viewModelInstance: 'Default',
  ),
  supportedMoods: {CharacterMood.idle, CharacterMood.thinking},
  supportedCues: CharacterCue.values,         // all seven
  moodFallbacks: {CharacterMood.listening: CharacterMood.idle, CharacterMood.speaking: CharacterMood.idle},
  fallback: CharacterFallbackKind.flame,
  semanticsLabel: _guideLabel,               // l10n.characterGuideSemantics
);
```

`CharacterRegistry.bundled` lists every spec and the default casting: `guide → guide_traveler`, `assistant → raqeeb_lantern` (painter rig until a Rive lantern exists). `CharacterSettingsCubit` can disable characters entirely or override the casting per role (persisted locally, never sent to the server).

## 6. Runtime implementation (rive 0.14.x)

The following API names are taken from the installed `rive` 0.14.11 / `rive_native` 0.1.11 sources (`lib/src/painters/widget_controller.dart`, `models/artboard_selector.dart`, `models/state_machine_selector.dart`, `models/data_bind.dart`). Re-check them if you upgrade the package.

```dart
// Once, during bootstrap (the prototype does it in CompanionAssets.load):
await rive.RiveNative.init();

// CharacterAssetCache: one File per character, shared by every on-screen instance.
Future<rive.File?> load(RiveRigSpec spec) => _files[spec.assetPath] ??= () async {
  try {
    return await rive.File.asset(spec.assetPath, riveFactory: rive.Factory.rive);
  } catch (e, st) {
    log.warning('Character asset failed: ${spec.assetPath}', e, st);
    return null;                                 // → fallback, never a crash
  }
}();

// RiveCharacterRig: one per CharacterView (own artboard, state machine and view-model instance).
final controller = rive.RiveWidgetController(
  file,
  artboardSelector: spec.artboard == null ? rive.ArtboardSelector.byDefault() : rive.ArtboardSelector.byName(spec.artboard!),
  stateMachineSelector: spec.stateMachine == null ? rive.StateMachineSelector.byDefault() : rive.StateMachineSelector.byName(spec.stateMachine!),
);                                               // throws RiveArtboardException / state-machine exception if a name is missing
final vmi = controller.dataBind(spec.viewModelInstance == null ? rive.DataBind.auto() : rive.DataBind.byName(spec.viewModelInstance!));
final mood = vmi.enumerator(spec.moodProperty);  // ViewModelInstanceEnum?  → mood.value = 'thinking'
final triggers = {for (final c in supportedCues) c: vmi.trigger(spec.cueTriggers[c] ?? c.name)};   // ViewModelInstanceTrigger? → t.trigger()

// Render
rive.RiveWidget(controller: controller, fit: aspect >= 1 ? rive.Fit.contain : rive.Fit.fitHeight, alignment: Alignment.bottomCenter);

// Dispose in reverse: mood?.dispose(); each trigger?.dispose(); vmi.dispose(); controller.dispose();
```

Setup rules (port them from `companion.dart`):

- Create controllers and bindings in `initState`/async init, **never in `build`**. Dispose everything in `dispose`.
- If any name is missing (artboard, state machine, view model, `mood`, a trigger), log the expected vs observed contract once (`Character guide_traveler: contract mismatch (mood=false, triggers=[greet, …])`) and fall back for the missing part. Never throw into the UI.
- Queue the last cue requested before the rig is ready; play it about 260 ms after setup so the state machine settles into idle first (prototype behaviour).
- Apply `mood` immediately after setup and on every change.
- Swap fallback → Rive with an `AnimatedSwitcher` (`QMotion.medium`) so the character fades in.
- Off-screen pages: wrap inactive shell branches in `TickerMode(enabled: false)` and check that the Rive widget pauses. Keep at most about three characters on screen at once.

**Painter rigs** (`PainterCharacterRig`) implement the same `CharacterRig` interface with Flutter painters and implicit animations. The Raqeeb lantern uses one: `LanternGlyph` with a soft glow that pulses while `thinking` and brightens briefly on `speaking`. Characters therefore don't have to be Rive files, and a Rive lantern can replace the painter later through its spec alone.

```dart
abstract interface class CharacterRig {
  Future<bool> attach();                       // false → render fallback
  void setMood(CharacterMood mood);
  void fire(CharacterCue cue);
  Widget build(BuildContext context, CharacterLayout layout);
  void dispose();
}
```

## 7. The widget screens use

```dart
CharacterView(
  role: CharacterRole.guide,
  size: 104, aspect: 0.88, zoom: 1.45,         // the prototype's per-placement values; keep them
  mood: CharacterMood.idle,
  appearCue: CharacterCue.correct,             // played once when the view first appears
  controller: _character,                      // optional, for later cues from listeners
  whenDisabled: CharacterAbsence.collapse,     // or keepSpace when the layout needs the slot
)
```

`CharacterController` is a small presentation object owned by the page's `State` (like the prototype's `CompanionController`):

```dart
final class CharacterController {
  set mood(CharacterMood value);               // remembered and applied when attached
  void cue(CharacterCue cue);                  // dropped under reduced motion; unsupported → cueFallbacks or ignored
}
```

Resolution inside `CharacterView`: role → spec (registry + settings) → mood through `moodFallbacks` → rig. If characters are disabled: collapse to `SizedBox.shrink()` or keep an empty slot of the same size. While loading or after a failure: `CharacterFallbackKind.flame` (the prototype's quiet `FlameMark`: glow 1.2 while loading; dimmed glow 0.6 and opacity 0.5 after failure), `lantern` (`LanternGlyph`) or `none`. Semantics: an `image` node labelled from ARB (`characterGuideSemantics`).

## 8. How BLoCs drive characters (without knowing about them)

BLoCs expose facts in their state. Pages translate those facts into moods and cues with listeners, and the mapping helpers are pure functions that are easy to test:

```dart
// character_cue_mapping.dart
CharacterCue cueForEvaluation(EvaluationOutcome o) => switch (o) {
  EvaluationOutcome.correct => CharacterCue.correct,
  EvaluationOutcome.incorrect => CharacterCue.retry,
  EvaluationOutcome.neutral => CharacterCue.encourage,   // predict, skipped, unavailable
};

// Raqeeb page
BlocListener<RaqeebChatBloc, RaqeebChatState>(
  listenWhen: (a, b) => a.assistantActivity != b.assistantActivity,
  listener: (context, s) => _assistant.mood = switch (s.assistantActivity) {
    AssistantActivity.recording => CharacterMood.listening,
    AssistantActivity.processing => CharacterMood.thinking,
    AssistantActivity.answering => CharacterMood.speaking,   // the page returns it to idle after ~2 s
    AssistantActivity.idle => CharacterMood.idle,
  },
);
```

The feedback panel's character takes `appearCue: cueForEvaluation(outcome)`. The completion page uses `complete`, the streak page `streak`, the journey `greet` beside the current node, and the hook step `mood: thinking`.

## 9. Adding or replacing a character

1. **Author** the rig to the §4 contract: in the Rive Editor, or with the generator approach in the app's `tool/rive/guide_traveler/` (RML generated by `generate.py`, compiled by the Rive CLI at `~/.rive/bin/rive`, then `./build.sh`; see its README). For a new character, start from a copy of that folder under `tool/rive/<id>/` and change the output path in its `build.sh`. Keep it faceless and text-free.
2. **Export** the `.riv` to `assets/characters/<id>/<id>.riv` and list it in `pubspec.yaml`.
3. **Spec**: add `lib/core/characters/specs/<id>.dart` and register it in `CharacterRegistry.bundled`. Declare supported moods/cues and fallbacks honestly.
4. **Strings**: add `character<Id>Name` and `character<Id>Semantics` to the `common` ARB fragments (en + ar).
5. **Cast it**: change the default for a role, or expose a choice in Settings through `CharacterSettingsCubit`.
6. **Test**: the integration test `integration_test/character_contract_test.dart` loads each spec on a device or simulator, binds it and asserts that the artboard, state machine, view model, `mood` values and triggers exist, then fires every cue once. Widget tests use a fake `CharacterAssetCache` that returns `null` (fallback path).

No screen changes are needed for any of these steps.

## 10. Planned extensions (Phase 16)

- Add `listening` and `speaking` mood states to the guide traveller (extend `generate.py`): *listening* turns the blank face toward the learner with a slight hood tilt and a stilled ember; *speaking* uses a slow open-hand gesture with a gently pulsing ember. Update the spec's `supportedMoods`.
- A Rive Raqeeb lantern (`raqeeb_lantern.riv`) with `idle`, `thinking` (flame breathing), `listening` (flame leaning toward the learner), `speaking` (warm pulse). Raqeeb's identity is a lantern, separate from the companion. It is never a person.

- **More guide characters cast per lesson:** the `guide` role holds a pool. `CharacterCasting` picks a lesson's companion deterministically from its lesson ID (stable across resume and languages); `assets/characters/casting.json` can pin a lesson to a character; outside lessons the default traveller appears. Purely client-side: no API field, no BLoC knowledge. Every new character keeps the §4 contract and the faceless policy. Details in `docs/PHASES.md` Phase 16.

## 11. QA checklist

- Every placement in §2 shows the right cue or mood, in English and Arabic (the character is not mirrored for RTL).
- Rapid repeated cues restart cleanly; a cue during a mood blend returns to that mood.
- Reduced motion (OS and in-app) leaves the character in calm idle with no hops or jumps.
- Characters disabled → every screen still lays out correctly.
- Asset missing or corrupt → the fallback flame, plus one log line naming the expected contract.
- Background/foreground and navigation back-stack: no duplicate loads, no leaked controllers (check with DevTools memory).
- Frame timing stays smooth with three characters visible on a mid-range Android device.

**Evidence (this document):** *Verified*: the guide traveller `.riv` loads and reacts in the Flutter runtime on the iOS simulator (prototype tour). *Inspected*: the rive 0.14.11 API names above, read from the package source. *Unverified*: Android and web rendering, the listening/speaking states, the lantern rig and the multi-character registry. These need the checks in §11.
