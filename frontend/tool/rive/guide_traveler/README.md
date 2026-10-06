# Qabas companion — Rive source & handoff

An original, faceless traveller in a hooded emerald cloak and a flame-gold scarf,
carrying the small ember (the *qabas*) the product is named after. Following the
brief's imagery rules (§8.4) the face is a blank, featureless shape: no eyes, no
nose, no mouth. Every emotion is carried by pose, gesture, head orientation
(where the face sits inside the hood), cloth motion and the ember's light.

The scene is written as RML and compiled by the official Rive CLI, so it is
version-controlled text that a designer can open in the Rive Editor
(`rive . --rev`, requires `rive login`).

```
generate.py        # source of truth: rig, poses (with 2-bone IK), animations, state machine
scene.rml          # generated — do not edit by hand
build.sh           # generate → verify → inspect → build → copy to ../../../assets/characters/guide_traveler/guide_traveler.riv
contact_sheet.py   # headless frame strips of every state (--bg=dark|light)
```

```sh
export PATH="$HOME/.rive/bin:$PATH"     # Rive CLI ≥ 1.2
./build.sh
python3 contact_sheet.py all --bg=dark  # review motion as PNG strips in shots/
```

## Runtime contract

| Item | Name | Type | Values / purpose |
|---|---|---|---|
| Artboard | `Companion` | Artboard | 400 × 400, transparent, default artboard |
| State Machine | `Companion` | State Machine | default; layers `Mood` and `Ambient` |
| View Model | `Companion` | View Model | default instance `Default` (exported) |
| Property | `mood` | Enum `CompanionMood` | `idle` (initial), `thinking` — persistent, app → Rive |
| Property | `greet` | Trigger | wave hello |
| Property | `encourage` | Trigger | dip, fist up, nod: "you've got this" |
| Property | `correct` | Trigger | quick hop, a flash of light, three sparkles |
| Property | `retry` | Trigger | ember dims, sheepish hand to hood, nod, ember rekindles |
| Property | `celebrate` | Trigger | crouch, jump with arms up, ripple + sparkle burst, soft landing |
| Property | `complete` | Trigger | arms open, the ember rises and blooms, soft rays |
| Property | `streak` | Trigger | raises the ember, which grows into a fuller (still gentle) flame |

All properties flow **app → Rive**; nothing is written back. Reactions are
one-shots that return to the current `mood` on their own. The app never touches
internal nodes, timelines or bones — see `lib/widgets/companion.dart`
(`CompanionController.mood`, `CompanionController.react(...)`).

## Structure

**Hierarchy** (first child draws on top): `Companion` root at the feet →
`FxFront` (sparkles, rising embers, ripple) · `Ember` (flicker group, core,
flame, glow) · `Body` (hop / squash pivot at the feet) → `Hips` → `Breath` →
`Torso` (arms, scarf, head, bag, cape, strap, belt, tunic, scarf tail) and legs ·
`FxBack` (aura, rays) · `Shadow`.

Arms are three-node chains (shoulder → elbow → hand) posed by an IK helper in
`generate.py`, so poses are authored as hand positions. The head turns by moving
the blank face inside the hood opening (a clipping mask) — the one cue that
reads as "looking" without any facial features.

**Timelines**: `Idle` (4 s loop), `Thinking` (3.2 s loop: hand to chin, ember
orbiting above), `Greet`, `Encourage`, `Correct`, `Celebrate`, `Retry`,
`Complete`, `Streak` (one-shots, 1.25–2.8 s) and `Ambient` (3.2 s loop).
Every mood timeline keys the same full set of rig properties, so a state never
inherits stray values from the one it blended out of.

**State machine**

- `Mood` layer: Entry → `Idle`. `Idle` ↔ `Thinking` on `mood` (380 ms eased
  blend). Any State → each reaction on its trigger (160 ms). Each reaction →
  `Idle` at 100 % exit time (260 ms), then `Idle` → `Thinking` again if the mood
  is still `thinking`. Reaction states use `reset` so retriggering restarts them.
- `Ambient` layer: one looping state — breathing, scarf ribbon wave, hem sway,
  flame flicker and glow. It keys only objects the mood layer never touches, so
  the layers never fight.

## Runtime notes

- Flutter: `rive` 0.14.11 / `rive_native`, `Factory.rive`, `Fit.contain`
  (or `Fit.fitHeight` for narrow slots), aligned bottom-centre. The file is
  loaded once and shared; each widget owns its controller and view-model
  instance and disposes them.
- The artboard keeps headroom above the character for jumps and blooms. In
  compact slots the app enlarges the character (`Companion(zoom: …)`) and lets
  that headroom overflow rather than shrinking the figure.
- Reduced motion (OS setting or in-app toggle): reactions are not fired; the
  calm idle remains.
- Loading or failure: a quiet flame holds the space; nothing throws.
- No text, fonts, images or scripts are embedded; the file is ~49 KB.

## QA checklist

- [x] `rive . --verify` and `rive inspect . --summary` — no problems.
- [x] Headless captures of every state on dark and light backdrops (`contact_sheet.py`).
- [x] Loaded in the Flutter runtime on the iOS simulator; triggers and mood
      drive the expected states (integration tour screenshots).
- [x] Faceless at every frame; no figure depicts a prophet, companion, angel or
      any historical person; the flame stays a soft teardrop, never a blaze.
- [ ] Android and web runtimes (expected to work; not yet run).
- [ ] Low-end device frame timing with several companions on screen.
- [ ] Open the exported `.rev` in the Rive Editor for designer hand-over.

**Evidence: Verified** for the iOS Flutter runtime (rendered and driven on the
iPhone 17 Pro simulator) and the Rive CLI headless renderer. **Unverified** for
Android, web, and editor round-trip; run the three unchecked items above.
