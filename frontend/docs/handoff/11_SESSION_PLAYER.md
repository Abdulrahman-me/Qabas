# 11 — Session player (the lesson engine)

One player plays every session kind (`lesson`, `review`, `pretest`, `unit_test`) from typed API items. It must reproduce the prototype lesson **1:1 in appearance and motion** (`/Users/aw/Documents/qpr/qabas/lib/features/lesson/`), while grading, XP, mastery and streaks come only from the server. Never branch on Salah IDs, unit numbers, wording or positions. The binding behaviour is API §5.6–§5.8, §6.5 and §7, and `docs/contract/04_FRONTEND/FRONTEND_HANDOFF.md` Appendix A (the Salah reference).

## 1. Structure

```
features/session/
  domain/  entities (Session, SessionItem…, see 06 §5), repositories/session_repository.dart,
           usecases/ start_lesson_session, start_review_session, start_unit_assessment, resume_session,
                     submit_answer, finish_session, abandon_session
           logic/ progress.dart  retry_queue.dart  teach_params.dart  answer_drafts/*.dart   # pure Dart, unit-tested
  data/    session_remote_data_source.dart, session_local_store.dart (resume), dtos, mappers
  presentation/
    bloc/session_player_bloc.dart         # flow, network, progress, combo, retry round, finish
    steps/  <type>_step_bloc.dart + <type>_step_view.dart   (hook, predict, story, teach, paragraph, evidence, visual, callout, exercise)
    exercises/ <type>_view.dart + kit/ (Tile3D, OptionTile, Token ported from proto exercise_kit.dart)
    widgets/ feedback_panel.dart, player_top_bar.dart, action_bar.dart, quit_sheet.dart, misconception_card.dart
    pages/  lesson_intro_page.dart, session_player_page.dart, session_result_page.dart
```

## 2. SessionPlayerBloc

**State:** `session`, `phase` (`loading`, `playing`, `feedback`, `retryRound`, `finishing`, `finished`, `failure`), `cursor` (index into `items`, or into the retry queue), `completedStepIds`, `evaluation?` (shown in the feedback panel), `combo`, `retryQueue`, `submitting`, `startedAt`, `failure?`.

**Events:** `SessionLoaded(sessionId)`, `StepCompleted(itemId)` (content steps), `AnswerChecked(exerciseId, AnswerPayload, elapsed)`, `FeedbackContinued`, `QuitConfirmed`, `RetrySubmitFailed…`, `FinishRequested`.

**Rules (normative):**

- **Steps** are the top-level `items` in order. A `story` (all its beats) and a `teach` card (all its reveals) are one step each.
- **Starting** goes through `StartLessonSession`; `409 prerequisite_unmet` opens the Soft Lock sheet instead of the player ([10](10_SCREENS_AND_FLOWS.md) S3). An already active session is returned before that check (200).
- **One lesson, every surface:** a lesson renders identically whether it was opened from the Journey, Discover, a Raqeeb suggestion or the developer menu; never branch on the entry surface.
- **Progress** = completed top-level steps ÷ total steps (`progress.dart`). Content steps complete on Continue. Exercise and `predict` steps complete **when the feedback panel is shown**. Retries don't move the bar. `recite_verse` completes on **Continue** (its result shows inline, not in the feedback panel). Review, pretest and unit-test sessions use answered ÷ total exercises.
- **Predict** is local only: no network call, nothing recorded, never counted in accuracy, combo or retries. After Check, the selected option takes the gold "guess" state, the others dim, and the neutral gold panel ("Nice thinking") shows `reveal`.
- **Answers** go through `SubmitAnswer` with `sequential()` concurrency; `is_retry` is false on the first pass. Network retry is safe (the server replays recorded identities). Feedback mode `immediate` → show the evaluation; `none`/`end` → `{recorded}` only, then advance without a panel.
- **Feedback panel** uses the evaluation: `correct: true` → emerald + praise; `false` → clay + "The answer:" + explanation; `null` → neutral "Skipped"; when `misconception != null` show the remediation card (distinct gentle style) before Continue. Combo +1 only for `scoring.combo` exercises answered correctly; reset on incorrect; at ≥ 3 show the combo flame and `Sensory.sparkle`. `predict` and `correct: null` never touch the combo.
- **Retry round** (lessons only): after the last item, re-present each first-attempt-incorrect exercise **once**, excluding `recite_verse`, `flashcard` and neutral results (`retry_queue.dart`). Submit with `is_retry: true`.
- **Finish**: every exercise needs a first attempt; then `FinishSession(duration)` → cache the result → `/session/:id/result`. A timed-out finish is retried, never re-played locally.
- **Quit** (× → quit sheet with the companion `encourage`, "Keep learning" / "Leave"): Leave → `AbandonSession` (Tier B) → journey.
- **Resume** (Tier B): persist the local state on every step change (`session_local_store.dart`, keyed by `session_id` + `lesson_version`): cursor, completed steps, predict selections, an open feedback panel with its evaluation, the retry queue. On restart restore it exactly; without local state, use the server history and the algorithm in API §6.5.5 (`contract_revision10/tools/recovery.py`). Stories restart at beat 0, teach cards at their first point.

## 3. Step BLoCs and the shared action bar

Each step view owns a small step BLoC created per item id. It exposes `StepCta {labelKey, enabled, tone}` in its state, and the player's bottom `QButton` renders it (this replaces the prototype's `StepAction` notifier). Pressing it sends `CtaPressed` to the step BLoC, which either advances internally (next story beat, reveal the next teach point) or emits an intent (`completed`, or `submit(AnswerPayload)`) that the page forwards to `SessionPlayerBloc`.

| Step | Local state | CTA |
|---|---|---|
| hook | — | `cta` or "Let's find out" |
| predict | selected option, checked | Check → Continue |
| story | beat index | Next … → Continue on the last beat (origin card first if `origin.show_card`). Two kinds share the view: a **sourced story** (`origin` set: provenance tags on every beat, quotes with their meaning, optional origin card) and a **teaching scenario** (`origin`, `provenance` and every `quote` are `null`: show the `label`, e.g. "Scenario"/"موقف", the title, visuals and narration only; no provenance tags, origin card or sources-drawer entry). |
| teach `standard` (with or without `visual`; most Unit 0 cards have none, so the card starts at the eyebrow/title with no empty visual box) | visible point count | "Show more" until all are visible, then Continue. Visual params = base `params` merged with `points[0..n-1].visual_params` in order (`teach_params.dart`; Salah day arc: −1, 1, 4, 4). Earlier points are de-emphasised. A screen-reader "Show all" action. |
| teach `summary` | — | Continue (all points visible) |
| exercise | an `AnswerDraft` per type (pure classes in `domain/logic/answer_drafts/`: option, reason, pairs, fills, assignments, order, pin, rating, recitation) with `isComplete` and `toPayload()` | Check (enabled when complete) |

## 4. Exercise renderers

`ExerciseRendererRegistry` maps `ExerciseType` (+ presentation) to a view. Unknown → the neutral "Update the app to continue" card. Each renderer follows its own interaction (API §7), not one generic flow:

| Type | View (prototype source) | Notes |
|---|---|---|
| multiple_choice, scenario, verse_meaning, which_evidence | `choice_view.dart` (`OptionTile`) | Myth `framing`: prompt first, then the mistaken-idea card, then options. Scenario shows `details.option_feedback` for the chosen option. |
| true_false_reason | choice kit | Two steps on one screen: true/false, then the reason; myth `framing` as for multiple choice. **Phase 6** (Unit 0 and 1.1 use it) |
| map_place `hotspots` | `discover_view.dart` | Pins are % of the 1.15 box, labels visible before answering, min target 44 px; `interaction` bindings set visual states locally |
| map_place `map_pins` | image + pins | Aspect from `image.width/height`; `{unavailable: true}` when neither the visual nor a geometry-safe fallback renders |
| categorize `buckets` | `sort_view.dart` (`Token`, drag or tap) | 2–3 buckets (Unit 0 uses three; the prototype's row of `Expanded` buckets must still fit at text scale 1.35); bucket art from `art_key` (`footprints`, `compass`, `prayer_rug`, `heart`…; `null` = no art) |
| categorize `day_arc` | `timeline_view.dart` | Arc proportion 2.8, starts at dawn, the sky follows the selected slot; tap, drag, replace, clear |
| order_steps | `order_view.dart` | `day_sequence` → dawn/night header; English shows Arabic `secondary_label`s |
| match_pairs | `match_view.dart` | Tap left then right; pairs lock with a colour. **Phase 6** |
| spot_error | new, built from the kit (segments as tappable `Tile3D` spans) | **Phase 6** (Unit 0 uses it 9 times) |
| fill_blank, timeline_order | new, built from the kit (Token, Tile3D) | Same tile states and sounds. Phase 12 |
| flashcard | `review_session_screen.dart` flip card | Rating buttons; no explanation panel |
| recite_verse | `recite_view.dart` + `features/recitation` | **Demo:** no checker or licensed audio exists, so show "Audio isn't available yet", keep the verse and meaning, and offer skip (`{skipped: true}`); never simulate a pass. When available: verse in `QText.quran` word by word with `audio.words` highlighting, Meaning expander, listen → record → `CheckRecitation` → colour missing/substituted words, tap a word to play its segment; skip when `skippable`; "audio unavailable" state; excluded from accuracy and combo |

## 5. Visuals (`shared/presentation/visuals/visual_view.dart`)

`VisualView(visual, use: VisualUse.hook)` dispatches by `kind`, never by lesson id:

- **builtin** → the prototype painters, ported with their painter code unchanged (`RiverHouseScene(beat)` 5 s loop, `WorkplaceScene` 60 s, `DayArcScene(highlight)` 8 s, `PillarsScene(highlight)` 4 s with localised pillar labels, flipped in Arabic). Unknown key/version → `fallback_image` or a neutral panel with `alt`.
- **image** → cached network image at `width/height`, with a placeholder and retry on failure.
- **scene** → `SceneView` from `packages/qabas_scene` (Phase 7): downloads (or, in mock mode, resolves) the manifest, verifies `sha256`, checks the scene's `required_capabilities` against this build's released list, and renders it live with state changes from story beats and `TeachPoint.visual_params`. Until Phase 7, and whenever a scene can't render (unknown capability, checksum or download failure), show `fallback_image` (always present, same proportion), then the `alt` placeholder.
- **Proportions per use** (frozen): hook 1.75 · story beat 1.5 · teach river/pillars/workplace 1.9 · teach day arc 2.1 · map hotspots 1.15 · categorize day arc 2.8 · visual block/predict 1.75 · image/scene from their own size.
- Consecutive story beats with the same key keep one mounted renderer and transition state; otherwise crossfade. Overlays (SVG medallions) are drawn in the same box by `anchor` and `size_pct`. Scenes are not mirrored in RTL (except pillars). Reduced motion → scenes frozen at controller value 0.3.

## 6. Acceptance: the lessons in the demo data

### Salah reference (opened from the developer menu)

All 14 steps play in ar/en × explorer/new_muslim exactly as the prototype: office hook → neutral prediction → four river beats with a constant story label and provenance tags → find the river (hotspots at beat 1: palm 16/36, door 55/52, window 80/34, river 42/86) → five-light teaching card → myth correction → pillars (highlight 1) → sorting (prayer_rug/heart) → day-arc card (−1, 1, 4, 4) → five-slot placement → scenario → An-Nisa 4:103 segment recitation → three-idea summary → ordering (day_sequence) → completion (accuracy over 6; Understanding 3, Applying 2, Remembering placeholder). Intro: 8 interactions, 7 exercises, 6 scored, 4 sources; 14 linked terms in Arabic and 13 in English.

### Unit 0 (12 lessons, Explorer, ar/en) and lesson 1.1 (both tracks)

- Every lesson plays end to end through the mock grader: hook, predictions (also used as ungraded polls), teaching scenarios, teach cards with and without scenes, callouts, the seven exercise types (`multiple_choice`, `categorize` buckets, `scenario`, `true_false_reason`, `spot_error`, `match_pairs`, `order_steps` plain), summary, completion.
- Scenes animate and change state as story beats and teaching points advance (after Phase 7), and look like the stills in `assets/mocks/unit0/media/fallbacks/`.
- Intros show no sources figure (all have `source_count` 0) and no reviewed badge.
- With `config/demo.json` no "Review draft only" notice appears; the two content callouts in 0.10 and 0.11 still do.
- 1.1's images point to unavailable placeholder URLs, so its hook and story show the `alt` placeholder panel, and its feedback panels have no explanation text.
