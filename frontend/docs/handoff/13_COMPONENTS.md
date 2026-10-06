# 13 — Reusable components

Most of these already exist in the prototype. **Port them, don't rewrite them**: start from the prototype file, fix imports, replace `Sensory.instance` with the injected `SensoryService`, replace inline strings with parameters or ARB keys, and keep every size, colour, curve and duration. New components appear only where the prototype has a repeated pattern without a widget, or where production adds a state the prototype lacks.

Paths are relative to the app's `lib/` (`/Users/aw/StudioProjects/qabas/lib/`). "Proto" paths are relative to `/Users/aw/Documents/qpr/qabas/lib/`. The tokens and theme (`QColors`, `QSpace`, `QRadius`, `QMotion`, `QShadows`, `QGradients`, `QFonts`, `QText`, `QTheme`) are already in the app; everything in the tables below is still to be ported.

## 1. Rules for components

- **Location:** generic UI goes in `core/design_system/components/`; content rendering shared by several features goes in `shared/presentation/`; anything used by one feature stays in that feature's `presentation/widgets/`. Promote a widget to shared only when a second feature needs it.
- **Naming:** keep prototype names (`QButton`, `QCard`, `Tag`, `Tile3D`…). New design-system components use the `Q` prefix.
- **Pure presentation:** components take data and callbacks; they never read BLoCs, repositories or `sl`. The exceptions are the content widgets that need the term-state store or `SensoryService`; those get them from an `InheritedWidget`/`RepositoryProvider` set up in `app.dart`, never from `sl` directly.
- **Strings:** callers pass already-localised strings. A component may read `context.l10n` only for its own fixed labels (for example "Sources" in `SourcesSheet`, close-button tooltips).
- **Disabled = `onPressed: null`**, as in the prototype. `const` constructors wherever possible.
- **Accessibility:** every tappable component has a semantics label (from ARB), a 44 px minimum target, and visible pressed/selected states. Selected states set `Semantics(selected:)`.
- **Reduced motion:** components with entrance or idle motion read `context.reduceMotion` and render their final state.
- **RTL:** directional padding and alignment; fills and progress follow reading direction; illustrations don't mirror.
- **Responsive web:** respect parent constraints and the limits in [03 §4](03_DESIGN_SYSTEM.md); wrap or scroll narrow/short layouts, keep sheets and inputs reachable, and preserve input/selection state during resize. Test both locales at phone, tablet and desktop widths.
- **Tests:** a widget test per component for its states, in English and Arabic.

Shared enums: `QTone { light, night }` (surface the component sits on), `QButtonTone` (8 tones, see [03](03_DESIGN_SYSTEM.md) §8), `TileState`, `TokenState`.

## 2. Catalog

### Foundations (`core/design_system/components/`)

| Component | Proto source | Use |
|---|---|---|
| `QButton` | `widgets/buttons.dart` | Primary raised button, 8 tones, optional icon/trailing icon, `expand`, `silent`, `onDark` |
| `QIconButton` | `widgets/buttons.dart` | 44 px circular icon button with tooltip |
| `Pressable` | `widgets/buttons.dart` | Press-scale + haptic wrapper for any custom tappable surface |
| `QCard` | `widgets/common.dart` | Standard white card (radius 20, 1.5 px line border, soft shadow), optional `onTap` |
| `SectionHeader` | `widgets/common.dart` | Section title + optional action link |
| `Tag` | `widgets/common.dart` | Small coloured pill label (track, level, grade, kind) |
| `StatChip` | `widgets/common.dart` | Streak and embers counters (light/night) |
| `ProgressTrack` | `widgets/common.dart` | Gold progress bar with an ember tip; RTL-aware; `streakGlow` |
| `RingProgress` | `widgets/common.dart` | Circular progress (word mastery, quests) |
| `SpeechBubble` | `widgets/common.dart` | Companion speech bubble with a tail |
| `DottedLine` | `widgets/common.dart` | Dotted separators and connectors |
| `StreakFlame` | `widgets/common.dart` | Small streak/combo flame |
| `showQSheet` | `widgets/sheets.dart` | The only bottom-sheet entry point (radius 32, handle, max width 560, tinted barrier) |
| `QConfirmSheet` (new) | pattern of the lesson quit sheet (`lesson_screen.dart` `_confirmQuit`) | Companion + title + body + primary/ghost buttons; destructive actions use the `retry` tone |
| `showQSnack` (new) | theme `SnackBarThemeData` | Transient notices |
| `QTextField` (new wrapper) | inputs in `raqeeb_screen.dart` `_InputBar`, `profile_screen.dart` | Filled `surfaceSunk` pill field with the emerald focus border |
| `QComposerBar` (new wrapper) | `raqeeb_screen.dart` `_InputBar` | Attach + field + send/mic switcher; attachment chips; recording timer |
| `QSegmentedChips` (new) | journey path chip / tag styles | Filter tabs (glossary states), small option sets |
| `QSettingsSection`, `QSettingsRow`, `QSettingsToggle` | `features/settings/settings_screen.dart` `_Section`, `_Row`, `_Toggle` (`SwitchListTile`) | Settings groups and rows: icon, title, value or switch, chevron |
| `QLoadingView`, `QInlineLoading`, `QEmptyView`, `QErrorView`, `QInlineError`, `QOfflineBanner`, `QBlockingScreen`, `StatusSwitcher`, `DelayedLoading` (new) | — | [12](12_STATES_AND_ERRORS.md) §2 |

### Motion (`core/design_system/components/motion/`)

| Component | Proto source | Use |
|---|---|---|
| `Reveal` | `widgets/motion.dart` | Staggered fade-and-lift entrances |
| `Breathe`, `Nudge` | `widgets/motion.dart` | Gentle idle emphasis on calls to action |
| `EmberBurst`, `Glow` | `widgets/ember_burst.dart` | Celebration particles and soft glows |
| `CountUp` (extract) | the `TweenAnimationBuilder` count-ups in `lesson_complete_screen.dart` | Embers / accuracy / time tiles |
| `RollingNumber` (extract) | `_RollingNumber` in `streak_screen.dart` | Streak number roll |
| `fadeThrough` | `router.dart` | Page transition for every route (`app/router/transitions.dart`) |

### Brand and illustration (`shared/presentation/brand/`, `shared/presentation/visuals/`)

| Component | Proto source | Use |
|---|---|---|
| `FlameMark` | `widgets/brand.dart` | Animated soft flame: logo, loaders, character fallback |
| `QabasLogo` | `widgets/brand.dart` | Wordmark + flame (splash, about) |
| `NightSky`, `GeometricPatternPainter`, `HillsPainter` | `widgets/brand.dart` | Night backgrounds, faint pattern, horizon hills |
| `TravelerAvatar` | `widgets/brand.dart` | Faceless avatars by `avatar_key` (unknown → default) |
| `EmberIcon` | `widgets/brand.dart` | Embers (XP) icon |
| `LanternGlyph` | `widgets/lantern.dart` | Raqeeb identity; nav tab icon; assistant painter rig |
| `UnitArtIcon` | `widgets/unit_art.dart` | Unit art by `art_key`; bucket art (`prayer_rug`, `heart`…) |
| `PhaseIcon` | `widgets/scenes.dart` | Day phases (dawn → night) for placement and ordering headers |
| `AchievementBadge` | `features/profile/achievement_badge.dart` | Badges by `achievement_key` (unknown → generic) |
| `RiverHouseScene`, `WorkplaceScene`, `DayArcScene`, `PillarsScene` | `widgets/scenes.dart` | Built-in visuals (registry v1); port with painter code unchanged, including loops and the reduced-motion freeze |
| `VisualView` (new) | dispatch described in [11](11_SESSION_PLAYER.md) §5 | Renders any `Visual` at its per-use proportion, with overlays and fallbacks |
| `OverlayLayer` (new) | API §5.5 | SVG medallion overlays (`flutter_svg`) by anchor and `size_pct` |

### Content (`shared/presentation/content/`)

| Component | Proto source | Use |
|---|---|---|
| `SpanText` (replaces `TermText`) | `widgets/term_text.dart` | Renders `ContentSpan[]`: plain, **strong**, dotted-underlined `term` (when new/learning; tap → term sheet), superscript `citation` (tap → source). Long-press on a sentence → its sources. Same text styles and underline as `TermText`. |
| `TermSheet` | `widgets/term_text.dart` | Term card (S8), including canonical Arabic (Amiri 34/1.3, RTL) |
| `SourcesSheet`, `SentenceSourcesSheet` (new) | sources UI in the lesson and Raqeeb | Sources drawer (S7) and the per-sentence mini sheet |
| `EvidenceCard` | `features/lesson/steps/evidence_card.dart` | Quran or hadith evidence with reference, grade tag, translation, source link |
| `QuranText` (new wrapper) | `QText.quran` usage in evidence/recite | `text_uthmani` only: forced RTL, Quran font, never truncated, surah name + ayah numbers below |
| `HadithText` (new wrapper) | `QText.hadith` usage | Arabic hadith text, RTL |
| `MisconceptionCard` (new) | myth card in `choice_view.dart` + feedback panel | Remediation card: gentle, distinct (gold50/retrySoft family, never red), title + spans + sources link |
| `VerificationCard` | `raqeeb_screen.dart` `_VerificationCard` | Five statuses with the status palette ([03](03_DESIGN_SYSTEM.md) §2) |
| `ReferralCard` | `raqeeb_screen.dart` `_SpecialistCard` | Calm referral with targets and "Open" links |
| `CitationList`, `SourceCard` | `raqeeb_screen.dart` `_SourceCard` | Numbered sources under an answer |

### Lesson kit (`features/session/presentation/`)

| Component | Proto source | Use |
|---|---|---|
| `Tile3D`, `OptionTile`, `Token`, `TileState`, `TokenState` | `features/lesson/exercises/exercise_kit.dart` | All answer surfaces, word chips, drag feedback, ghosts |
| `FeedbackPanel` | `features/lesson/feedback_panel.dart` | Correct / not quite / neutral panel with the companion; now driven by `AnswerEvaluation` |
| `PlayerTopBar`, `ActionBar`, `StepScroll`, `KindChip` | `features/lesson/lesson_screen.dart` | Lesson chrome |
| Step views and exercise views | `features/lesson/steps/*`, `exercises/*` | See [11](11_SESSION_PLAYER.md) |

### New for the amended contract (2026-10-04)

| Component | Based on | Use |
|---|---|---|
| `SoftLockSheet` | quit sheet (`lesson_screen.dart` `_confirmQuit`) | Locked lesson or `409 prerequisite_unmet`: companion `encourage`, explanation, prerequisite titles, button to `start_with` |
| `ReviewCard` | `review_screen.dart` `_DeckCard` | Journey card when reviews are due |
| `DiscoverLessonTile` | `QCard` + journey node glyph | Discover list rows (title, minutes, `+xp`, completed tick) |
| `YourWordsRow` | review screen words section + `RingProgress` | Profile entry to the glossary |
| `SceneView` (`packages/qabas_scene`) | none | Live rendering of `Visual.kind = scene` with fallback still and `alt` placeholder |
| Teaching-scenario mode of the story view | `story_view.dart` | `origin == null`: label, title, visuals, narration only |

### Navigation and characters

| Component | Proto source | Use |
|---|---|---|
| `HomeShell` (bottom bar + rail) | `features/shell/home_shell.dart` | The 5-tab shell, night-toned on Journey |
| `CharacterView`, `CharacterController` | `widgets/companion.dart` (generalised) | Every character placement ([09](09_CHARACTERS_AND_RIVE.md)) |

## 3. When the prototype has a one-off widget

Many prototype screens use private widgets (`_TodayCard`, `_StatTile`, `_MasteryCard`, `_LeagueRow`, `_QuestRow`, `_DeckCard`, `_WeekRow`…). Port them as **public widgets inside their feature** (`TodayCard`, `StatTile`, `MasteryCard`…), unchanged visually, taking entities instead of prototype models. Promote one to `shared/` or the design system only when another feature needs the same pattern (for example, if the profile statistics grid ends up reusing the result page's `StatTile`).
