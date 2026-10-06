# 02 — Prototype fidelity: from prototype to production

The prototype (`/Users/aw/Documents/qpr/qabas/`) is the **visual and UX specification**. The production app must look, move, sound and read like it. It is not the engineering specification: its data and state plumbing is demo-only and gets rebuilt.

## 1. Study the prototype first

The prototype's 57 screenshots are already in the app at **`docs/prototype/screens/`** (English, iPhone 17 Pro simulator, 1206 × 2622 px), with a screen → source → phase table in `docs/prototype/README.md`. Play the prototype itself too:

```sh
cd /Users/aw/Documents/qpr/qabas      # the prototype (read-only), not this app
flutter run                            # play it: onboarding, the Prayer lesson, every tab, Arabic
```

**Settings → Prototype → Reset demo progress** restores the demo state (3-day streak, Prayer lesson waiting). Arabic screenshots don't exist yet; `docs/prototype/README.md` explains how to capture them with the prototype's tour (`TOUR=arabic`). The disk on this machine is nearly full, so boot only one simulator at a time.

Screenshot names (use the same names in the production tour so you can compare side by side): `01_onboarding_language`, `02_onboarding_welcome`, `03_onboarding_who`, `04_onboarding_who_selected`, `05_onboarding_familiar`, `06_onboarding_goal`, `07_onboarding_privacy`, `08_onboarding_ready`, `09_journey`, `10_journey_popover`, `11_lesson_intro`, `12_lesson_hook`, `13_lesson_predict_selected`, `14_lesson_predict_feedback`, `15–17_lesson_story_*`, `18_lesson_discover_feedback`, `19_lesson_teach_river`, `20_lesson_misconception_retry`, `21_lesson_teach_pillars`, `22–25_lesson_sort_*`, `26_lesson_teach_dayarc`, `27–28_lesson_timeline_*`, `29_lesson_scenario`, `30–32_lesson_recite_*`, `33_lesson_summary`, `34–35_lesson_order_*`, `36_lesson_complete`, `37_streak_celebration`, `38_journey_after`, `39–42_review_*`, `43–46_raqeeb_*`, `47–48_community*`, `49–52_live_*`, `53_profile`, `54_achievements`, `55_settings`, `56_about`, `57_unit_guide`.

Before implementing **any** screen: open its prototype file(s) below, open its screenshots, and play it in the running prototype. Note the layout order, paddings, which tokens are used, entrance animations (`Reveal` delays), sounds/haptics (`Sensory.*`) and companion reactions.

## 2. Three kinds of prototype code, three treatments

| Kind | Examples | Treatment |
|---|---|---|
| **Pure presentation**: painters, decorative widgets, tokens, components | `core/theme/*`, `widgets/*` (buttons, common, brand, scenes, motion, ember_burst, unit_art, lantern, sheets), `exercise_kit.dart`, `journey_widgets.dart` painters, `achievement_badge.dart` | `tokens.dart` and `app_theme.dart` are **already in the app** (`lib/core/design_system/tokens/`, `theme/`). **Port the rest** into `core/design_system/` or the feature's `presentation/widgets/`: keep the widget and painter code and every number, and change only imports, strings (→ ARB), the sound/haptics singleton (→ injected `SensoryService`) and the reduced-motion source (→ `context.reduceMotion`). These files can't be dropped in unchanged because they import prototype state (`state/app_scope.dart`, `core/services/sensory.dart`, `l10n/s.dart`). |
| **Screens that mix layout and data access** | `journey_screen.dart` (reads `context.app`, `Curriculum`), `lesson_complete_screen.dart`, `profile_screen.dart`, `raqeeb_screen.dart` | Split each into a **page** (BlocProvider, BlocBuilder/Listener, routing) and **view widgets** that take domain entities or state slices. Keep the widget tree, spacing and animation code identical; only replace where the data comes from. |
| **Demo plumbing** | `state/app_state.dart`, `state/app_scope.dart`, `features/lesson/lesson_session.dart`, everything in `data/` (curriculum, lesson_salah, glossary, raqeeb_script, community, achievements, scripture.g.dart), `l10n/*` | **Do not port.** Replace with BLoCs, use cases, repositories and API data. Use it only to understand behaviour and as the source of the ARB strings. |

## 3. Screen → prototype source → production location

| Production screen | Prototype source (under `/Users/aw/Documents/qpr/qabas/lib/`) | Production feature / page |
|---|---|---|
| Splash | `features/splash/splash_screen.dart` | `features/auth/presentation/pages/splash_page.dart` |
| Onboarding (7 pages: language, welcome, who, familiarity, goal, privacy, ready) | `features/onboarding/onboarding_flow.dart` (`_LanguagePage`, `_WelcomePage`, `_ChoicePage`, `_PrivacyPage`, `_ReadyPage`, `_NightOption`, `_NightToggle`, `_Bars`) | `features/onboarding/` |
| Home shell (bottom bar; side rail ≥ 840 px; night-toned on Journey) | `features/shell/home_shell.dart`, `widgets/lantern.dart` | `app/presentation/home_shell.dart` |
| Journey (app bar with path switcher and stat chips, Today card, unit banners, winding path, nodes, popover, horizon) | `features/journey/journey_screen.dart`, `journey_widgets.dart` (`UnitBanner`, `JourneyPathPainter`, `JourneyNodeButton`, `_Popover`, `_StartBubble`, `SideDecoration`) | `features/journey/` |
| Unit guide sheet | journey screen guide sheet | `features/journey/presentation/widgets/unit_guide_sheet.dart` |
| Lesson intro | `features/lesson/lesson_intro_screen.dart` (`_TrustRow`) | `features/session/presentation/pages/lesson_intro_page.dart` |
| Lesson player chrome (top bar, progress, step scroll, action bar, quit sheet, combo) | `features/lesson/lesson_screen.dart` (`_TopBar`, `_ActionBar`, `StepScroll`, `KindChip`) | `features/session/presentation/pages/session_player_page.dart` |
| Hook | `features/lesson/steps/hook_view.dart` | `features/session/presentation/steps/hook_step_view.dart` |
| Story | `features/lesson/steps/story_view.dart` | `…/steps/story_step_view.dart` |
| Teach (+ summary style) | `features/lesson/steps/teach_view.dart` | `…/steps/teach_step_view.dart` |
| Evidence card | `features/lesson/steps/evidence_card.dart` | `shared/presentation/content/evidence_card.dart` |
| Recite | `features/lesson/steps/recite_view.dart` | `…/exercises/recite_verse_view.dart` + `features/recitation/` |
| Choice / predict / scenario / myth | `features/lesson/exercises/choice_view.dart` | `…/exercises/choice_exercise_view.dart`, `…/steps/predict_step_view.dart` |
| Find in the scene | `exercises/discover_view.dart` | `…/exercises/map_place_view.dart` (hotspots) |
| Sort | `exercises/sort_view.dart` | `…/exercises/categorize_buckets_view.dart` |
| Place prayers on the day | `exercises/timeline_view.dart` | `…/exercises/categorize_day_arc_view.dart` |
| Ordering | `exercises/order_view.dart` | `…/exercises/order_steps_view.dart` |
| Matching | `exercises/match_view.dart` | `…/exercises/match_pairs_view.dart` |
| Answer tiles, tokens, stable shuffle | `exercises/exercise_kit.dart` (`Tile3D`, `OptionTile`, `Token`, `TileState`, `TokenState`) | `features/session/presentation/exercises/kit/` |
| Feedback panel | `features/lesson/feedback_panel.dart` | `…/widgets/feedback_panel.dart` |
| Lesson complete | `features/lesson/lesson_complete_screen.dart` (`_StatTile`, `_MasteryCard`) | `features/session/presentation/pages/session_result_page.dart` |
| Streak celebration and calendar | `features/streak/streak_screen.dart` (`_RollingNumber`, `_WeekRow`, `_DayDot`, `_MonthCalendar`) | `features/streak/` |
| Review hub (deck card, words list) | `features/review/review_screen.dart` | No tab any more: the deck card becomes the Journey's **Review card** (`features/journey/presentation/widgets/review_card.dart`), the words list becomes the **"Your words" row** in Profile (+ glossary list in `features/glossary/`) |
| Card review session | `features/review/review_session_screen.dart` | `features/session/` (`kind: review`, `mode: cards`) with the flip-card view |
| Raqeeb | `features/raqeeb/raqeeb_screen.dart` (`_Header`, `_Welcome`, `_SuggestionChip`, `_UserBubble`, `_AnswerBubble`, `_CitedText`, `_SourceCard`, `_VerificationCard`, `_SpecialistCard`, `_TypingDots`, `_InputBar`) | `features/raqeeb/` |
| Community (league header, rows, quests, live card) | `features/community/community_screen.dart` | `features/community/` |
| Live challenge (lobby, countdown, question, reveal, results) | `features/community/live_challenge_screen.dart` | `features/challenges/` |
| Profile | `features/profile/profile_screen.dart` | `features/profile/` |
| Achievements (badges) | `features/profile/achievements_screen.dart`, `achievement_badge.dart` | `features/profile/` (badge painter → `shared/presentation/brand/`) |
| Settings, About | `features/settings/settings_screen.dart`, `about_screen.dart` | `features/profile/presentation/pages/` |
| Term sheet, term underline | `widgets/term_text.dart` (`TermText`, `TermSheet`) | `shared/presentation/content/span_text.dart`, `term_sheet.dart` |
| Built-in scenes | `widgets/scenes.dart` (`RiverHouseScene`, `WorkplaceScene`, `DayArcScene`, `PillarsScene`, `PhaseIcon`) | `shared/presentation/visuals/builtin/` (port; painter code unchanged) |
| Companion | `widgets/companion.dart` | `core/characters/` (generalised, see [09](09_CHARACTERS_AND_RIVE.md)) |
| Page transitions | `router.dart` (`fadeThrough`) | `app/router/transitions.dart` (port; only the token import changes) |

## 4. What is fake in the prototype, and its production replacement

| Prototype behaviour | Production behaviour |
|---|---|
| Seeded demo progress in `AppState` (3-day streak, 245 embers, Prayer lesson current) | `GET /me/stats`, `GET /journey`, `GET /journey/next` |
| Local curriculum (`data/curriculum.dart`), two fixed journeys | `GET /journey` for any number of units; `art_key` selects bundled unit art |
| One hard-coded lesson (`data/lesson_salah.dart`) with local grading in `LessonSession` | `POST /sessions` returns any lesson as typed blocks. Every answer is graded by `POST /sessions/{id}/answers`; finish by `POST /sessions/{id}/finish` |
| `LessonReward` computed locally (embers, streak +1) | `SessionResult` (xp.total shown as embers, layers, streak, mastery, terms mastered, unlocks, next step) |
| Term underline based on a local "mastered" set | Span `term` + the payload's `terms` map state (`new`/`learning` underlined); `SessionResult.terms_mastered` removes the underline immediately; `POST /glossary/{id}/opened` when the sheet opens |
| Raqeeb answers four scripted questions | `POST /raqeeb/conversations/{id}/messages` then poll `GET /raqeeb/messages/{id}`, with stage labels; eight question classes plus `failed` |
| Recitation simulated (advances after a fake listen) | `record` audio → `POST /recitation/checks` (multipart, `Idempotency-Key`) → word-level result; answer submitted with `check_id` or `skipped` |
| League members, friends, quests, achievements are static lists | `GET /leagues/current`, `GET /friends`, `GET /me/quests`, `GET /me/achievements` |
| Live quiz with scripted opponents | `POST /duels`, then the WebSocket at `Duel.ws_url` (fake socket in mock mode) |
| Path switch and settings persisted locally | Server profile via `PATCH /me` (language, track, daily goal, avatar, private profile); local-only: sound, haptics, reduced motion, discreet reminders |
| Review deck from local terms | `POST /sessions {kind: review, mode: cards}` (flashcards, self-rated) |
| Unit guide text is local | `GET /units/{unit_id}/guide` |
| "Reset demo progress" in Settings | Not in production. Put developer controls in a debug-only developer menu ([07](07_MOCKS_AND_BACKEND_SYNC.md)) |
| `scripture.g.dart` constants | Evidence and recitation payloads from the API (exact text from verified sources) |
| Inline bilingual strings `s.t('…','…')` and `Bi(en, ar)` | ARB keys for interface text; API content arrives already localised |

## 5. Shape differences you must bridge

The prototype's local models (`data/models.dart`) are **not** API models. Map contract data onto the prototype's visuals like this:

| Prototype concept | Contract equivalent | Note |
|---|---|---|
| `NodeKind` lesson / story / practice / checkpoint | `LessonEntry.lesson_type` `concept` / `story` / `practice`; unit `unit_test` → checkpoint (lantern) node; `pretest` → entry before a unit | Node glyph by type, never by id |
| `UnitArt` enum | `Unit.art_key` string → bundled `UnitArtIcon` art; unknown or `null` → default art | Keep a key → art map in the journey presentation |
| `UnitStatus` done / current / locked | `UnitState` `locked` / `available` / `in_progress` / `completed` / `skipped`; `Journey.current` marks the current node | `skipped` renders as done |
| `ChoiceStyle.standard` | `multiple_choice` | |
| `ChoiceStyle.predictive` | `predict` **block** (ungraded, no network) | Neutral gold "Nice thinking" feedback |
| `ChoiceStyle.scenario` | `scenario` (per-option feedback in `details.option_feedback`) | |
| `ChoiceStyle.fixMisconception` | any exercise with `framing: {kind: myth, statement}` | Prompt first, then the mistaken-idea card, then options |
| `DiscoverExercise` (hotspots) | `map_place` with `presentation: hotspots` on a built-in visual | Pins are percentages of the 1.15 box; labels visible before answering |
| `SortExercise` | `categorize` with `presentation: buckets` | `art_key` `prayer_rug`/`heart` select bucket art |
| `TimelineExercise` (place on the day) | `categorize` with `presentation: day_arc` | Slots in day order; sky follows the selected slot |
| `OrderExercise` | `order_steps` (`presentation: day_sequence` shows the dawn→night header; plain otherwise) | English shows Arabic secondary labels |
| `MatchExercise` | `match_pairs` | |
| `TrueFalseExercise` | `true_false_reason` in lessons; `true_false` only in challenges | |
| `ReciteStep` | `recite_verse` exercise (`scoring.accuracy=false`, `combo=false`) | Completes on Continue, not through the feedback panel |
| `TeachVisual` river / pillars / dayArc | `Visual{kind: builtin, key: river_house \| pillars \| day_arc \| workplace, params}` | Per-use proportions in [11](11_SESSION_PLAYER.md) |
| `ExerciseLayer` understand / practice / remember | `scoring.layer` `understand` / `apply` / `remember` → result `understanding` / `applying` / `remembering` (always `null` → placeholder) | |
| Embers | `xp` | The UI keeps the word "embers" (قبسات) |

## 6. Screens the prototype doesn't have

Design these **in the prototype's language**. Compose existing components, follow the layout of the nearest prototype screen, and introduce no new colours, type styles or radii.

| Screen / state | Base it on |
|---|---|
| Blocking update (`426`) | Splash: night sky, flame mark, title, body, one gold button (opens the store link from config) |
| "Session ended" notice (`401`) | Bottom sheet like the lesson quit sheet: companion `encourage`, title, body, Continue |
| Raqeeb conversations list | Raqeeb header + `QCard` rows (title, preview, relative time); empty state = Raqeeb welcome |
| Glossary filters (new / learning / mastered) | Review screen's words section with a segmented chip row |
| Discover tab | Review hub and community layouts: `SectionHeader` per unit, `QCard` rows with the journey node glyph, one notice card at the top |
| Soft Lock sheet | The lesson quit sheet: companion `encourage`, warm title and body, the prerequisite lesson titles, one primary button to `start_with` |
| Curiosity onboarding page (behind a flag) | `_ChoicePage` with six `_NightOption`s and a skip action, then a bridge page in the welcome page's style |
| Teaching-scenario story | `story_view.dart` with the label only: no provenance tags, quote card or origin card |
| Teach card without a visual | `teach_view.dart` minus the scene box |
| Generated scenes | No prototype equivalent: `packages/qabas_scene` draws them; the builtin scenes' framing (rounded box, per-use proportion) applies |
| Friends: invite code and accept | `showQSheet` with the code in `stat` style, share button (`share_plus`), text field for entering a code |
| Challenge result and answer review | Live challenge results phase; a list of `QCard`s with prompt, correct answer and explanation |
| Unit test answer review, pretest "thank you" | Lesson complete layout without mastery bars |
| Quick review timer (20 s) | `ProgressTrack` draining; colour shifts to clay in the last 5 s |
| Raqeeb stage indicator, failed state, verification statuses (5), differing views, referral | Prototype `_TypingDots`, `_VerificationCard`, `_SpecialistCard`, `_SourceCard`; status colours in [03](03_DESIGN_SYSTEM.md) |
| Loading, empty, error, offline | [12_STATES_AND_ERRORS.md](12_STATES_AND_ERRORS.md) |
| "Prefer not to say" onboarding option | Third `_NightOption` on the "who" page, with a neutral icon |
| Delete account confirmation | Quit-sheet pattern; destructive action uses the `retry` (clay) tone, never red |

## 7. How to verify fidelity

1. **Port the tour** (Phase 11). Add `integration_test/tour_test.dart` to the app with the same screen names (`test_driver/integration_test.dart` is already in place). Base it on the prototype's `/Users/aw/Documents/qpr/qabas/integration_test/tour_test.dart`. Run it in mock mode on the same simulator as the prototype (`iPhone 17 Pro`; optionally `iPad Pro 13-inch (M5)` for wide layouts).
2. **Compare side by side.** Build a contact sheet (prototype left, production right) per screen, and inspect proportions, spacing, type, colours and wording. The two must be indistinguishable except where data legitimately differs (server-provided text, live numbers).
3. **Motion.** Check entrance staggers, page transitions (`fadeThrough`, 460 ms), button press depth, feedback slide-up, count-ups, the combo flame after 3 correct in a row, the story beat transitions, teach reveals and companion reactions, with reduced motion both on and off.
4. **Arabic.** Every screen in Arabic: RTL layout, Arabic-Indic digits, Arabic typography heights, pillars aligned under their Arabic labels, scenes **not** mirrored.
5. Record intentional differences in the PR description (for example "production shows server XP instead of simulated embers").

## 8. Prototype habits not to carry over

- `context.app` / `AppScope` global mutable state → BLoCs and repositories.
- `Sensory.instance` and `CompanionAssets` static singletons → injected services (`SensoryService`, `CharacterAssetCache`) registered in get_it.
- Inline `s.t('en', 'ar')` strings and `Bi` data → ARB keys and API content.
- Local grading, randomised praise picked in a widget (`math.Random` in `FeedbackPanel`) → praise variants in ARB and selection in the BLoC (seeded by exercise id for stability).
- `shared_preferences` JSON blob of all state → secure storage for the token, `PreferencesStore` for local settings, `SessionLocalStore` for resume data.
