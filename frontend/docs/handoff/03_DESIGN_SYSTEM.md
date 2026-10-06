# 03 — Design system

Everything here was **extracted from the prototype** (proto `lib/core/theme/tokens.dart`, `app_theme.dart`, `widgets/*`). The tokens and the theme are **already in the app**, verbatim. The components still need to be ported (§8, and [13](13_COMPONENTS.md)). Do not invent values. If a screen needs something not listed, take it from the nearest prototype widget and add it here as a named token or component, never as a literal in a feature.

## 1. Where it lives

```
lib/core/design_system/
  tokens/tokens.dart     ✓ IN PLACE (verbatim from the prototype): QColors, QSpace, QRadius, QMotion, QShadows, QGradients
                         TO ADD in the same file: the status palette aliases in QColors (§2),
                         QBreakpoints (§4), QSizes (§8), QMotion.pageReverse (320 ms)
  theme/app_theme.dart   ✓ IN PLACE (verbatim; only its import path changed): QFonts, QText ThemeExtension
                         (display, displaySmall, eyebrow, quran, hadith, stat), QTheme.light(arabic:),
                         extension QThemeX on BuildContext (context.text, context.qText)
  theme/theme_x.dart     TO ADD: context.isRtl, context.reduceMotion (PreferencesCubit + MediaQuery)
  components/            TO PORT: buttons, cards, tags, chips, progress, sheets, inputs, states, motion, brand (§8, 13)
  design_system.dart     TO ADD: barrel export
```

The font files the theme names (`Figtree`, `PlexArabic`, `Fraunces`, `Amiri`, `AmiriQuran`) are already in `assets/fonts/` and declared in `pubspec.yaml`.

**Rule:** feature code may not contain `Color(0x…)`, `Colors.<name>` (except `Colors.transparent` and `Colors.white` inside design-system components), raw `EdgeInsets` numbers, `BorderRadius.circular(<number>)`, `Duration(milliseconds: …)`, `Cubic(…)`, `BoxShadow(…)` or `TextStyle(fontSize: …)`. `tool/check_rules.sh` greps for these under `lib/features/` and `lib/shared/` ([15](15_CONVENTIONS_AND_DONE.md)). Painters ported from the prototype (scenes, unit art, badges, journey path) are the one exception: they live in `presentation/painters/` or `shared/presentation/visuals/` and keep their internal geometry and colours exactly as authored.

## 2. Colour

The palette is "a warm light in a deep, calm space": emeralds carry depth, golds carry light.

| Token | Hex | Use |
|---|---|---|
| **Brand core** | | |
| `nightEmerald` | `#073C37` | Night surfaces, barrier tint, shadows' base colour |
| `emerald` | `#0B5A52` | Primary (ColorScheme.primary) |
| `flameGold` | `#E0A526` | Light, progress, important moments, gold buttons |
| `softEmber` | `#F6E3B4` | Text and icons on night surfaces |
| `morningMint` | `#EEF5F2` | Scaffold background (light screens) |
| `deepInk` | `#16233A` | Primary text |
| `slate` | `#566476` | Secondary text (bodyMedium/bodySmall) |
| **Night ramp** | `night950 #032624` · `night900 #052F2C` · `night800 #0A4741` · `night700 #0E5650` · `nightLine #1C6159` | Journey, onboarding, splash, completion, streak backgrounds; bottom bar on the Journey tab |
| **Emerald ramp** | `emerald700 #084A43` · `emerald500 #13786B` · `emerald400 #1E9180` · `emerald200 #A9D6CB` · `emerald100 #D5EDE6` · `emerald50 #E7F4F0` | Buttons (face 500 / edge 700), selected tiles (50/400/700), links, eyebrows (500) |
| **Gold ramp** | `gold800 #9A6A0E` · `gold700 #B98318` · `gold400 #EDBB45` · `gold300 #F3CD6E` · `gold100 #FBEFD2` · `gold50 #FDF7E8` | Gold buttons (edge 700), neutral/predict feedback (50/800), tags |
| **Neutrals** | `surface #FFFFFF` · `surfaceSunk #F5F9F7` · `line #DCE7E3` · `lineStrong #C5D6D0` · `muted #8A97A6` | Cards, inputs, dividers, disabled |
| **Feedback** | `correct #128070` · `correctEdge #0B6457` · `correctSoft #DDF2EB` · `retry #C0743A` · `retryEdge #9C5A27` · `retrySoft #FBEBDD` · `retryInk #8A4B1F` | Correct = emerald; "not quite" = warm clay. **Never red.** |
| **Accents (sparingly)** | `dusk #4E6A9E` · `duskSoft #E3E9F5` · `rose #B4637A` · `sky #3D8EA8` | Categories, avatars, charts, specialist referral |

**Status palette** (add to `QColors` as named aliases; new for production, built only from existing colours). These are used by Raqeeb verification cards, grade tags and source chips:

| Status | Ink / soft | Contract meaning |
|---|---|---|
| `statusVerified` | `correct` / `correctSoft` | `quran_exact`; hadith `authentic` or `acceptable` |
| `statusCaution` | `gold800` / `gold50` | `quran_inexact`; hadith `weak` |
| `statusFabricated` | `retryEdge` / `retrySoft`, with an explicit "Fabricated" label | hadith `fabricated`. The contract says "red"; the brand forbids alarming red, so use the deepest clay plus the label. Logged as a design decision. |
| `statusUnknown` | `slate` / `surfaceSunk` | `not_found`, grade `other`. **Must never look like fabricated.** |
| `statusSpecialist` | `dusk` / `duskSoft` | `needs_specialist`, referral cards |

Gradients (`QGradients`): `night` (top→bottom `night950 → nightEmerald → night800`, stops 0 / 0.55 / 1), `gold` (`gold400 → flameGold → #D58F1A`, top-left → bottom-right), `emeraldButton` (`emerald400 → emerald500`). The journey sky brightens from night toward dawn with progress (see `journey_screen.dart` `_Horizon` and the sky stops in `JourneyScreen`), so keep its gradient code inside the journey presentation.

## 3. Typography

| Family (`QFonts`) | Font files (`/Users/aw/Documents/qpr/qabas/assets/fonts/`) | Use |
|---|---|---|
| `Figtree` (latin) | 400, 500, 600, 700, 800 | Latin interface |
| `PlexArabic` (arabic) | IBM Plex Sans Arabic 400–700 | Arabic interface |
| `Fraunces` (latinDisplay) | 500, 600, 700 | Special moments (titles on splash, completion, streak) in Latin |
| `Amiri` (arabicDisplay) | 400, 700 | Special moments in Arabic; hadith text; canonical Arabic term display (size 34, height 1.3) |
| `AmiriQuran` (quran) | 400 | **Quran `text_uthmani` only.** Never stylised. |

The UI family follows the locale; the other script is the fallback (`fontFamilyFallback`). Arabic needs more vertical room: heading line height **1.55** (Latin 1.3), body **1.75** (Latin 1.5). Arabic letter spacing is always 0.

Material text theme (sizes / weights / Latin letter spacing; colour `deepInk` unless noted):

| Style | Size | Weight | Spacing | Notes |
|---|---|---|---|---|
| displayLarge | 44 | 800 | −1.2 | |
| displayMedium | 36 | 800 | −0.8 | |
| displaySmall | 30 | 800 | −0.5 | |
| headlineLarge | 28 | 800 | −0.5 | |
| headlineMedium | 24 | 800 | −0.3 | |
| headlineSmall | 21 | 800 | −0.2 | Feedback titles, sheet titles |
| titleLarge | 19 | 700 | −0.1 | Section headers, app bar |
| titleMedium | 17 | 700 | 0 | |
| titleSmall | 15 | 700 | 0 | Option text (w600), tokens (w700) |
| bodyLarge | 17.5 | 500 | 0 | body line height |
| bodyMedium | 15.5 | 500 | 0 | colour `slate` |
| bodySmall | 13.5 | 500 | 0 | colour `slate` |
| labelLarge | 16 | 800 | 0.3 | Buttons (Latin label uppercased, spacing 0.9) |
| labelMedium | 13.5 | 700 | 0.2 | Tags, links |
| labelSmall | 11.5 | 800 | 0.8 | |

`QText` extension (brand styles Material has no slot for):

| Style | Latin | Arabic |
|---|---|---|
| `display` | Fraunces 36 / w600 / h1.12 / −0.6 | Amiri 38 / w700 / h1.45 |
| `displaySmall` | Fraunces 25 / w600 / h1.2 / −0.3 | Amiri 27 / w700 / h1.5 |
| `eyebrow` | UI 12 / w800 / spacing 1.4 / `emerald500` (uppercase) | UI 13 / w800 |
| `quran` | AmiriQuran 27 / h2.15 / `deepInk` | same |
| `hadith` | Amiri 22 / h1.95 / `deepInk` | same |
| `stat` | Figtree 22 / w800 / h1.1, tabular figures | same (Plex fallback) |

The app clamps the OS text scale to **0.9–1.35** (`MaterialApp.builder` in `/Users/aw/Documents/qpr/qabas/lib/app.dart`). Keep it. Layouts must survive 1.35 (use `Wrap`/`Flexible`/`FittedBox(scaleDown)` as the prototype does).

## 4. Spacing, radius, breakpoints

`QSpace`: `xxs 4 · xs 8 · sm 12 · md 16 · lg 20 · xl 24 · xxl 32 · xxxl 40 · huge 56 · page 20` (horizontal page gutter) · `readingWidth 560` (max width of lesson content and sheets on tablets/web).

`QRadius`: `xs 8 · sm 12 · md 16 · lg 20 · xl 26 · xxl 32`; `card` = 20, `button` = 16, `chip` = 999 (pill), `sheet` = top 32.

`QBreakpoints` (new names for the prototype's literals):

| Name | Value | Behaviour |
|---|---|---|
| `phoneMax` | shortest side < 600 logical px | Lock native phones to portrait (`main.dart`); tablets and web keep every orientation |
| `rail` | width ≥ 840 | Side navigation rail instead of the bottom bar (`home_shell.dart`) |
| `readingWidth` | 560 | Lesson content, feedback panel, sheets: centred and constrained |
| `composerMax` | 640 | Raqeeb composer max width |

**Responsive web requirement (owner, 2026-10-04):** retain the prototype's phone sizes, spacing and artwork. Adapt layout to the available constraints with `LayoutBuilder`, `Flexible`/`Expanded`, `Wrap` and scrolling; do not stretch the entire phone design to fill a desktop. Centre reading content and sheets at `readingWidth`, and composers/lesson chrome at `composerMax`. Use width, rather than platform or user-agent checks, for the 840 px navigation rail. A browser may be narrow and short simultaneously; scrolling must keep every control reachable, including sheet actions and fields above the software keyboard. Resizing must retain input, selections and flow state. Do not lock browser orientation. Preserve RTL reading order, unmirrored artwork and reduced motion at every size.

For every phase with UI, verify representative logical viewports **320 × 568, 320 × 400, 600 × 400, 839 × 600, 840 × 600, 1440 × 900 and 1920 × 1080**, including text scale 1.35, en/ar and reduced motion on/off. Resize an already-mounted view, test overflow and content-width limits, then run relevant widget tests on Chrome and compile `flutter build web`. Product-screen checks are added in the phase that builds that screen; this requirement does not authorize building ahead.

## 5. Motion

`QMotion` durations: `fast 140 ms` (tile/colour changes) · `normal 240 ms` · `medium 360 ms` (bottom bar, companion swap) · `slow 520 ms` (progress fill, `Reveal`) · `page 460 ms` (route transitions; reverse 320 ms). Button press 70 ms; tile press 90 ms.

Curves: `emphasized` `Cubic(0.2, 0, 0, 1)` (default) · `emphasizedDecel` `Cubic(0.05, 0.7, 0.1, 1)` (entrances) · `gentle` `Cubic(0.4, 0, 0.2, 1)` · `settle` `Cubic(0.34, 1.32, 0.64, 1)` (small overshoot when something "arrives").

Patterns to reuse (all in `/Users/aw/Documents/qpr/qabas/lib/widgets/motion.dart` and `router.dart`):

- `Reveal(delay:)`: fade and lift 18 px into place over `slow` with `emphasizedDecel`; screens assemble with staggered delays. Use each screen's exact delays (the prototype mostly uses 80/100/120/200/300 ms, list items `50 ms × index`, celebration beats 640–900 ms).
- `Breathe`, `Nudge`: subtle idle motion for calls to action.
- `fadeThrough` page transition: outgoing fades in the first half; incoming fades in (interval 0.15–1), slides up 3 % (8 % and no scale for bottom-up pages such as lessons) and scales from 0.985.
- Count-ups on completion and the rolling number on the streak screen.
- Built-in scene loops: `river_house` 5 s, `workplace` 60 s, `day_arc` 8 s, `pillars` 4 s.

**Reduced motion** = `MediaQuery.disableAnimations` **or** the in-app setting. Expose it as `context.reduceMotion` from `PreferencesCubit` + MediaQuery. When on: no entrance animations (render final state), instant transitions, scenes freeze at controller value 0.3, companion cues are not fired (the calm idle remains), count-ups jump to the final value.

## 6. Shadows and elevation

No Material elevation. Depth comes from these shadows and from raised "edge" surfaces (buttons, tiles):

- `QShadows.soft`: `#073C37` at 8 % alpha, blur 18, y 6 + `#073C37` at 4 % alpha, blur 4, y 1. Cards.
- `QShadows.lifted`: 13 % alpha, blur 30, y 14 + 6 % alpha, blur 6, y 2. Popovers, floating elements.
- `QShadows.glow(color, strength)`: two soft glows (38 % alpha, blur 26 and 18 % alpha, blur 60, spread 6). Flames, current node, celebrations.

## 7. Theme (already in place: `lib/core/design_system/theme/app_theme.dart`)

Material 3, `ColorScheme.fromSeed(emerald)` with `primary emerald`, `secondary flameGold`, `surface white`, `error retry` (clay). Scaffold `morningMint`. `InkSparkle` splash, transparent highlight. AppBar: `morningMint`, no elevation or tint, centred `titleLarge`. Bottom sheet: white, top radius 32. Switch: selected track `emerald500`, white thumb. Slider: `emerald500` / `line`, gold thumb. SnackBar: floating, `deepInk`, radius 16, `titleSmall` white. Page transitions: Android `FadeForwardsPageTransitionsBuilder`, iOS `CupertinoPageTransitionsBuilder` (routes use `fadeThrough` anyway).

## 8. Component styles (exact)

| Component | Spec (prototype source) |
|---|---|
| **QButton** (`widgets/buttons.dart`) | Raised face over a darker edge that presses down. Height 54, depth 4, radius 16, horizontal padding 20, icon 21. Label `labelLarge`, **uppercased in Latin** with spacing 0.9, never in Arabic; `FittedBox(scaleDown)` for long labels. Tones (face / edge / ink): `emerald` 500/700/white · `gold` flameGold/gold700/deepInk · `correct` correct/correctEdge/white · `retry` retry/retryEdge/white · `light` white/lineStrong/deepInk (2 px `line` border) · `outline` white/line/emerald500 (border) · `ghost` transparent, flat · `night` night800/night950/softEmber (`nightLine` border). Disabled: face `line` (or white 8 % on dark), ink `muted`, no depth. Tap plays `Sensory.tap` unless `silent`. |
| **QIconButton** | 44 circle, icon 56 % of size, `Pressable` scale 0.9, tooltip (from ARB). |
| **Pressable** | Scale 0.96 on press plus a selection haptic. Used for any tappable custom surface. |
| **QCard** (`widgets/common.dart`) | White Material surface, radius 20, 1.5 px `line` border, `QShadows.soft`, padding 16, optional `onTap` (Pressable 0.98). |
| **Tag** | Pill, padding 10×4, background = colour at 12 % (or given), `labelMedium`, optional 14 px icon. |
| **StatChip** | Pill, padding (8, 5, 12, 5), 1.5 px border; on dark: white 8 % fill / 10 % border, value in `stat` 16 `softEmber`. |
| **SectionHeader** | `titleLarge` + optional action link (`labelMedium` emerald500). |
| **ProgressTrack** | Height 14, `line` track, gold gradient fill (`#EFB43A → flameGold`), gloss highlight, glowing ember at the leading edge; animates `slow`/`emphasized`; **fills from the reading start (flipped in RTL)**. |
| **RingProgress** | Circular progress with a rounded cap (word mastery, quests). |
| **SpeechBubble** | Companion speech bubble with a tail (onboarding). |
| **Tile3D / OptionTile / Token** (`exercise_kit.dart`) | Answer surfaces: depth 4 (tokens 3), radius 16 (tokens 12), 2 px border, padding 16×14 (tokens 14×9, compact 10×7), press sinks by depth−1 over 90 ms. States: idle (white/lineStrong/line/deepInk) · selected (emerald50/emerald400/emerald400/emerald700) · correct (correctSoft/correct/correct/correctEdge) · wrong (retrySoft/retry/retry/retryInk) · dimmed (white/line/line/muted) · guess (gold50/flameGold/flameGold/gold800). OptionTile: 30×30 number badge (radius 9) that turns into ✓/✕. Token ghost: 45 % opacity placeholder keeping the bank steady; drag feedback rotated −0.04 rad, scale 1.08. |
| **FeedbackPanel** | Slides up from the bottom. Background correctSoft / retrySoft / gold50 (neutral), ink correct / retryInk / gold800, 30 px icon circle, title `headlineSmall`, companion 92×104 (zoom 1.45) reacting, explanation `bodyMedium` (h1.7 Arabic / 1.45 Latin), "The answer:" + answer when missed, a full-width button in the matching tone. Constrained to 560. |
| **Sheets** (`widgets/sheets.dart`, `showQSheet`) | Root navigator, scroll-controlled, safe area, transparent background with a white Material and top radius 32, barrier `nightEmerald` at 42 %, max width 560, drag handle 44×5 `lineStrong`, padding (24, 12, 24, 24 + bottom inset). All sheets (term, sources, quit, guide, invite) use it. |
| **Inputs** (Raqeeb composer, profile name) | Filled `surfaceSunk`, pill radius 24, no border; focused 1.5 px `emerald400`; content padding 16×12; text `bodyLarge` 16; hint `bodyMedium` `muted`. Composer bar: white, 1.5 px top `line` border, padding 12, max width 640, attach (emerald500 icon), send (white on emerald500 circle) ⇄ mic (emerald500 on emerald50), animated scale switch (`normal`). Wrap this in `QTextField` and `QComposerBar`. |
| **Navigation** (`home_shell.dart`) | Bottom bar: background `night950` on Journey, `surface` elsewhere (animated `medium`/`gentle`), 1.5 px top border (`nightLine` 60 % on night, `line` otherwise), 5 tabs: Journey (explore), **Discover** (a filled/outlined Material Rounded pair distinct from the compass, e.g. `travel_explore`; it replaces the prototype's Review tab, owner decision 2026-10-04), Raqeeb (lantern glyph), Community (emoji_events), Profile (person), with filled/outlined icon variants. Side rail at ≥ 840 px. Selecting a tab plays `Sensory.select`. |
| **Lesson chrome** (`lesson_screen.dart`) | Top bar (max width 640, padding 8/8/20/4): close × (`QIconButton`, `muted`) → quit sheet; `ProgressTrack` height 16 with `streakGlow` when combo ≥ 3; combo counter (`StreakFlame` 18 + number in `stat` 16 `gold700`) that pops in with `settle` once 3 correct answers in a row are reached, plus `Sensory.sparkle`. Bottom action bar: one `QButton` whose label and enabled state come from the current step. Content in `StepScroll`, constrained to 560. |
| **Brand marks** (`widgets/brand.dart`) | `FlameMark` (animated soft flame), `QabasLogo`, `GeometricPatternPainter` (faint pattern), `NightSky` (starfield), `HillsPainter`, `TravelerAvatar` (faceless avatars by key), `EmberIcon`, `StreakFlame`, `LanternGlyph`, `EmberBurst`/`Glow` (celebration particles). Port with the painter code unchanged. |

Add the recurring sizes as `QSizes` (button height 54, depth 4, icon button 44, option badge 30, sheet handle 44×5, feedback companion 92×104…) so features never repeat the numbers.

## 9. Sound and haptics

`SensoryService` (port of `core/services/sensory.dart`, injected rather than a singleton). Sounds in `assets/sounds/`: `tap` (0.5 volume), `select` (0.6), `correct` (0.75), `retry` (0.6), `complete` (0.8), `streak` (0.8), `sparkle` (0.6). Haptics: tap/select → selection click; correct → medium; retry/sparkle → light; complete/streak → heavy. Both respect the local sound/haptics settings and never throw. Feedback is soft: a gentle bell for correct, a low wooden phrase for "not quite", never a buzzer.

## 10. Imagery and iconography

- Material Rounded icons (`Icons.*_rounded`), as in the prototype.
- Avatars are `TravelerAvatar` painters selected by `avatar_key` (unknown → default). No photos.
- Unit art: `UnitArtIcon` painters by `art_key`; phase art `PhaseIcon` (dawn, midday, afternoon, sunset, night).
- Badges: `AchievementBadge` painter by `achievement_key` (unknown → generic badge).
- Downloaded images (`Visual.kind=image`): `cached_network_image`, aspect ratio from `width/height`, placeholder panel with `alt` and a retry on failure. Never crop in a way that moves pins or overlays.
