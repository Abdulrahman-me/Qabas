# 06 — Data models: DTO → mapper → entity

```
JSON (contract rev 10) ──► DTO (data/dtos, json_serializable) ──► mapper (data/mappers) ──► entity (domain/entities) ──► BLoC/UI
request entity/draft ──► mapper ──► request DTO.toJson() ──► JSON
```

DTOs never leave `data/`. BLoCs and widgets see only entities. When the backend contract changes or an assumption proves wrong, only the DTO and mapper change.

## 1. DTO rules

- One DTO per contract shape, named after the schema root plus `Dto` (`SessionDto`, `AnswerEvaluationDto`, `TermCardDto`). The 99 roots are listed in `docs/contract/03_API/contract_revision10/contract/qabas_contract.schema.json`; field-level truth is `qabas_contract.py`.
- `build.yaml`: `json_serializable` with `field_rename: snake`, `checked: true`, `explicit_to_json: true`, `create_to_json: false` by default (enable it only on request DTOs).
- **Unknown response fields are ignored** (json_serializable's default; never enable `disallow_unrecognized_keys`). This also skips fixture metadata such as `_mock_source_revision`.
- **Unknown enum values map to `unknown`**: every enum DTO uses `@JsonKey(unknownEnumValue: X.unknown)`, and the UI renders a safe fallback for `unknown`.
- **Nullable fields are explicit.** The server always sends them (as `null` when not applicable), so declare them nullable with no default. A missing non-nullable field throws → `UnexpectedFailure` → this is contract drift: fix the DTO or raise it with the backend.
- **Requests send explicit nulls** (`include_if_null: true`). The single exception is `PATCH /me` (`MePatchDto`): include only changed fields and never `null` (`include_if_null: false`).
- IDs are `String`, never parsed. Timestamps are ISO-8601 UTC strings in DTOs and become `DateTime` in entities. `_ms` integers become `Duration`. Percentages are `int` 0–100; mastery is `double` 0–1.
- **Unions are decoded by hand** with a `switch` on the discriminator: `type` for spans, blocks, exercises, answer blocks and socket events, `status` for Raqeeb messages, `kind` for visuals. Exercise payloads, answers and details are selected by the **exercise type** (the dispatch map). Don't guess from field presence.

```dart
sealed class BlockDto {
  static BlockDto fromJson(Map<String, dynamic> j) => switch (j['type']) {
        'paragraph' => ParagraphBlockDto.fromJson(j),
        'evidence' => EvidenceBlockDto.fromJson(j),
        'visual' => VisualBlockDto.fromJson(j),
        'callout' => CalloutBlockDto.fromJson(j),
        'hook' => HookBlockDto.fromJson(j),
        'story' => StoryBlockDto.fromJson(j),
        'teach' => TeachBlockDto.fromJson(j),
        'predict' => PredictBlockDto.fromJson(j),
        'exercise' => ExerciseBlockDto.fromJson(j),
        _ => UnknownBlockDto(j['block_id'] as String?, j['type'] as String?),
      };
}

ExercisePayloadDto decodePayload(String type, Map<String, dynamic> p) => switch (type) {
      'multiple_choice' => MultipleChoicePayloadDto.fromJson(p),
      'true_false_reason' => TrueFalseReasonPayloadDto.fromJson(p),
      'match_pairs' => MatchPairsPayloadDto.fromJson(p),
      'flashcard' => FlashcardPayloadDto.fromJson(p),
      'fill_blank' => FillBlankPayloadDto.fromJson(p),
      'categorize' => CategorizePayloadDto.fromJson(p),     // presentation: buckets | day_arc
      'spot_error' => SpotErrorPayloadDto.fromJson(p),
      'which_evidence' => WhichEvidencePayloadDto.fromJson(p),
      'order_steps' => OrderStepsPayloadDto.fromJson(p),    // presentation: plain | day_sequence
      'scenario' => ScenarioPayloadDto.fromJson(p),
      'timeline_order' => TimelineOrderPayloadDto.fromJson(p),
      'map_place' => MapPlacePayloadDto.fromJson(p),        // presentation: hotspots | map_pins
      'recite_verse' => ReciteVersePayloadDto.fromJson(p),
      'verse_meaning' => VerseMeaningPayloadDto.fromJson(p),
      'true_false' => TrueFalsePayloadDto.fromJson(p),      // challenges only
      _ => UnknownPayloadDto(type),
    };
```

## 2. Exercise catalog: payload, answer, details

From API §7 and `contract/dispatch_map.json`. The answer the client sends and the `details` it receives depend on the exercise type.

| Type | Payload (key fields) | Answer sent | `details` on evaluation |
|---|---|---|---|
| `multiple_choice` | `options[{option_id, spans}]` (2–4) | `{option_id}` | `null` |
| `true_false_reason` | `statement`, `reasons[]` | `{value: bool, reason_option_id}` | `{value_correct, reason_correct}` |
| `match_pairs` | `left[{item_id, spans}]`, `right[]` (3–5 each) | `{pairs:[{left_id, right_id}]}` | `{pair_results:[{left_id, correct}]}` |
| `flashcard` | `front`, `back` | `{rating: again\|hard\|good\|easy}` | `null`; `correct = rating != again`; no explanation panel |
| `fill_blank` | `segments[text\|blank]`, `word_bank[{word_id, text}]` | `{fills:[{blank_id, word_id}]}` | `{blank_results:[{blank_id, correct}]}` |
| `categorize` | `presentation`, `categories[{category_id, label, art_key, phase, capacity}]`, `items[{item_id, spans, secondary_label}]` | `{assignments:[{item_id, category_id}]}` | `{item_results:[{item_id, correct}]}` |
| `spot_error` | `segments[{segment_id, spans}]` | `{segment_id}` | `null` |
| `which_evidence` | `claim`, `options[{option_id, evidence}]` | `{option_id}` | `null` |
| `order_steps` | `presentation`, `steps[{step_id, spans, secondary_label}]` (3–7) | `{order:[step_id…]}` | `{first_wrong_index}` |
| `scenario` | `situation`, `options[]` | `{option_id}` | `{option_feedback:[{option_id, spans}]}` |
| `timeline_order` | `events[{event_id, spans}]` | `{order:[event_id…]}` | `{event_dates:[{event_id, label}]}` |
| `map_place` | `presentation`, `visual`, `question`, `pins[{pin_id, x_pct, y_pct, label, radius_pct, anchor_id}]`, `interaction` | `{pin_id}` or `{unavailable: true}` | `{pin_labels:[{pin_id, label}]}` |
| `recite_verse` | `surah`, `ayah`, `word_start`, `word_end`, `text_uthmani`, `audio{reciter, url, words[]}`, `transliteration`, `meaning`, `source_id`, `max_duration_ms`, `skippable` | `{check_id}` or `{skipped: true}` | `null` (the check result is shown inline) |
| `verse_meaning` | `verse` (Evidence), `options[]` | `{option_id}` | `null` |
| `true_false` (challenges) | `statement` | `{value: bool}` | — |
| any timed exercise | — | `answer: null` on timeout (quick review) | — |

`AnswerSubmitDto = {exercise_id, answer, elapsed_ms, is_retry}`. The domain models the answer as a sealed `AnswerPayload` (`OptionAnswer`, `ReasonAnswer`, `PairsAnswer`, `RatingAnswer`, `FillsAnswer`, `AssignmentsAnswer`, `SegmentAnswer`, `OrderAnswer`, `PinAnswer`, `CheckAnswer`, `SkippedAnswer`, `UnavailableAnswer`, `ValueAnswer`, `TimeoutAnswer`), and the mapper turns it into JSON.

## 3. Shared entities (`lib/shared/domain/entities/`)

Used by several features (session, reader, Raqeeb, glossary, guide):

| Entity | Fields (domain names) | From |
|---|---|---|
| `ContentSpan` (sealed) | `PlainSpan(text)`, `StrongSpan(text)`, `TermSpan(text, termId)`, `CitationSpan(ref)` | `Span` |
| `Sentence` | `id`, `spans`, `sourceIds` | `Sentence` |
| `Source` | `id`, `kind`, `provider`, `title`, `reference`, `excerpt`, `url`, `displayed`, `displayRole` (`content`/`activity`/null) | `Source` |
| `Evidence` (sealed) | `QuranEvidence(surah, surahName, ayahStart, ayahEnd, segment?, textUthmani, translation?, translationSource?, audio?)`, `HadithEvidence(textAr, translation?, narrator, collections, gradeLabel, gradeCategory, gradeSource, excerpt)` | `Evidence` |
| `RecitationAudio` | `reciter`, `url`, `words[{ayah, position, text, start, end}]?` | nested |
| `TermCard` | `id`, `text`, `transliteration`, `arabic?` (canonical Arabic display, authored diacritics; null → omit, never reconstruct), `state` (`newTerm`/`learning`/`mastered`/`unknown`), `level`, `definition`, `example`, `pronunciationUrl?`, `sourceId?`, `lessonId?`, `lessonTitle?` | `TermCard` |
| `Visual` (sealed) | `BuiltinVisual(key, version, params, fallbackImage?, alt, overlays)`, `ImageVisual(image, alt, overlays)`, `SceneVisual(scene: SceneRef, params, fallbackImage, fallbackParams, alt, overlays)`, `UnknownVisual(alt)` | `Visual` |
| `NetworkImageRef` | `url`, `mimeType`, `width`, `height` (aspect = width/height) | `Image` |
| `Overlay` | `assetUrl` (SVG medallion), `label`, `anchor` (`topStart`/`topEnd`/`center`/`bottomStart`/`bottomEnd`), `sizePct` | `Overlay` |
| `NextStep` | `type` (pretest/lesson/review/unitTest/journeyComplete), `reason`, `unitId?`, `lessonId?`, `title`, `dueReviewsCount` | `NextStep` |
| `UserProfile` | `id`, `displayName`, `role`, `language`, `track`, `dailyGoalMinutes`, `timezone`, `onboardingCompleted`, `avatarKey`, `familiarity?`, `privateProfile`, `goalAnchor?` (the onboarding curiosity choice; selects the onboarding bridge only, never ordering, recommendations or anything about religion), `createdAt` | `User` |
| `PageOf<T>` | `items`, `nextCursor?` | page roots |

**Term state store.** `shared/domain/term_state_store.dart` (an interface implemented in `shared/data`) merges term states from every payload's `terms` map and from `SessionResult.terms_mastered` (via the `TermsMastered` event). `SpanText` asks it whether to underline a term, so a term mastered during a session loses its underline immediately everywhere.

## 4. Feature entity catalog

| Feature | Entities | Contract roots |
|---|---|---|
| auth | `AuthSession(token, user)` (token never leaves data/storage), `UserProfile` | `GuestReq`, `AuthResp`, `User` |
| onboarding | `OnboardingAnswers(trackChoice, language, familiarity, dailyGoal, privateProfile, goalAnchor?)` + local `discreetReminders`; `CuriosityCopy` (from `assets/onboarding/curiosity.json`: question, anchors with label and bridge per track × language, all nullable); `OnboardingOutcome(user, startUnitId, nextStep)` | `OnboardingReq`, `OnboardingResp` |
| journey | `Journey(track, current{unitId, lessonId}, units)`, `JourneyUnit(id, index, title, subtitle, artKey, hasGuide, state, comingSoon, pretest{state}, unitTest{state, bestPercent, passPercent, canSkip}, lessons)`, `LessonEntry(id, index, title, lessonType, state, estimatedMinutes, xp, standaloneEligible, softLock?)`, `SoftLock(prerequisites: List<LessonRef>, startWith: LessonRef)` (non-null exactly when `state == locked`), `LessonRef(lessonId, unitId, title)`; Discover = the `standaloneEligible` lessons of the same `Journey`, `UnitGuide(title, sections[{title, sentences}], sources, terms)` | `Journey`, `Guide`, `NextStep` |
| session | see §5 | `SessionCreate`, `Session`, `AnswerSubmit`, `AnswerEvaluation`, `AnswerRecorded`, `FinishReq`, `SessionResult` |
| reader | `LessonReading(id, unitId, title, subtitle, lessonType, reviewedBy, version, sourceCount, objectives, blocks, completion, sources, terms)` | `LessonRead` |
| recitation | `RecitationCheck(id, status evaluated/unclear, passed, words[{index, expected?, result correct/missing/substituted/extra, heard?, audioSegment?}], summary, message)` | `RecitationCheck` |
| glossary | `TermCard`, `PageOf<TermCard>` | `GlossaryPage`, `TermCard` |
| raqeeb | `Conversation(id, title?, context?, createdAt, updatedAt)`, `ConversationSummary(id, title, lastMessagePreview, updatedAt)`, `UserMessage(id, text?, attachments, createdAt)`, `Attachment(id, kind, filename, mime, sizeBytes, url, duration?, pages?)`, `AssistantMessage` sealed: `Processing(id, stage)`, `Failed(id, stage, errorCode)`, `Completed(id, understoodInput, classification{questionClass, label}, abstained, blocks: AnswerBlock[], citations[{ref, source}], terms, suggestedLessons, feedback)`; `AnswerBlock` sealed: `ParagraphAnswer(spans)`, `EvidenceAnswer(evidence)`, `VerificationAnswer(items[VerificationItem])`, `DifferingViewsAnswer(intro, views[{holder, spans, sourceIds}])`, `ReferralAnswer(type, reason, targets[{name, description, url?, contact?}])` | `Conversation`, `ConversationPage`, `ConvDetail`, `PostMessageResp`, `AssistantMessage`, `RaqeebCompleted`, `FeedbackReq` |
| profile | `UserProfile`, `Stats(xpTotal, xpThisWeek, streak{current, longest, todayCompleted}, dailyGoal{minutes, minutesToday, met}, league?{id, rank, size}, concepts, terms, misconceptions, lessonsCompleted, unitsCompleted)`, `Achievement(key, title, description, unlocked, unlockedAt?, progress{current, target})`, `ProfilePatch` | `Stats`, `Achievements`, `MePatch` |
| streak | `Activity(timezone, from, to, streak, days[{date, qualifying, minutes, xp}])` | `Activity` |
| community | `League(id, weekStart, weekEnd, endsIn, myRank, tier{key, index, name, isTopTier}, promotionZoneSize, members[{rank, userId, displayName, xpWeek, isMe, avatarKey, inPromotionZone}])`, `DailyQuests(date, resetsIn, items[{id, kind, title, progress, goal, rewardXp, completed}])`, `Friend(userId, displayName, xpWeek?, streakCurrent?, online, avatarKey)`, `Invite(id, code, shareText, expiresAt)` | `League`, `Quests`, `FriendPage`, `Invite`, `InviteAccept` |
| challenges | `Challenge(id, status, mode, preset, opponentType, players, config{questionCount, timeLimit, scoring, reveal}, wsUrl, createdAt, expiresAt, result?)`, `ChallengeResult(winners, isDraw, scores, xpAwarded)`, `LiveEvent` sealed (one per server event type), `Invitation` | `Duel`, `DuelCreate`, `DuelResult`, `InvitationPage`, `WsEvent`, `WsClientMessage`, `AsyncNext`, `AsyncAnswer`, `AsyncAnswerResp` |

## 5. Session model (the core)

```dart
final class Session extends Equatable {
  final String id;
  final SessionKind kind;                // lesson | review | pretest | unitTest | unknown
  final SessionStatus status;            // active | finished | abandoned
  final FeedbackMode feedbackMode;       // immediate | none | end
  final ReviewMode? mode;                // cards | quick (review only)
  final String? unitId, lessonId;
  final int? lessonVersion;
  final String title; final String? subtitle;
  final LessonType? lessonType; final String? reviewedBy;
  final List<List<ContentSpan>> objectives;
  final SessionCounts counts;            // interactions (exercises + predict), exercises, scored. Never reuse one for another.
  final int sourceCount;
  final int totalExercises, answeredExercises;
  final List<RecordedAnswer> answers;    // history for resume (redacted per feedback mode)
  final DateTime startedAt;
  final List<SessionItem> items;         // top-level steps, in order
  final LessonCompletion? completion;    // challenge, reviewTopics, checkIn (lessons only)
  final List<Source> sources;
  final Map<String, TermCard> terms;
}

sealed class SessionItem { String get id; }   // block_id
final class HookItem extends SessionItem { situation, question, visual, cta? }
final class PredictItem extends SessionItem { prompt, options[{id, spans}], reveal, visual? }
final class StoryItem extends SessionItem { label, title?, provenance?{sourceId, provider, reference, gradeLabel?}, beats[StoryBeat], origin?{title, sourceIds, showCard} }
// origin == null → a fictional teaching scenario: provenance and every beat quote are null too (model-enforced). See 11 §3.
final class TeachItem extends SessionItem { eyebrow?, title, style (standard|summary), visual?, evidence?, points[{id, sentence, visualParams?}] }
final class ParagraphItem extends SessionItem { sentences }
final class EvidenceItem extends SessionItem { evidence, caption? }
final class VisualItem extends SessionItem { visual, caption? }
final class CalloutItem extends SessionItem { variant (tip|note), spans }
final class ExerciseItem extends SessionItem { Exercise exercise }
final class UnknownItem extends SessionItem { }        // newer server block: skip safely, log

final class Exercise extends Equatable {
  final String id; final ExerciseType type; final List<String> conceptIds;
  final List<ContentSpan> prompt; final Duration? timeLimit;
  final Scoring scoring;                 // accuracy, combo, layer (understand|apply|remember|null)
  final MythFraming? framing;            // statement spans
  final ExercisePayload payload;         // sealed, one subclass per type (+ UnknownPayload)
}

final class AnswerEvaluation extends Equatable {
  final String exerciseId; final bool recorded;
  final bool? correct;                   // null = neutral (skipped / unavailable)
  final Object? correctAnswer;           // typed per exercise type via the mapper
  final EvaluationDetails? details;      // sealed per type
  final List<ContentSpan> explanation; final List<String> sourceIds;
  final Misconception? misconception;    // id, title, card spans, sourceIds → remediation card
  final List<MasteryChange> masteryChanges; final List<TermChange> termChanges;
  final int xpAwarded;                   // non-zero only for a passed recitation
}
// For feedback modes none/end the server returns only {exercise_id, recorded}: map it to AnswerRecorded.

final class SessionResult extends Equatable {
  final String sessionId; final SessionKind kind;
  final Score score;                     // correct, total, percent
  final bool? passed;                    // unit tests only
  final XpSummary xp;                    // total (shown as embers) + breakdown[{reason, xp}]
  final Duration duration;
  final LayerScores layers;              // understanding?, applying?, remembering (always null: placeholder)
  final StreakUpdate streak;             // current, extendedToday
  final DailyGoalStatus dailyGoal;
  final List<MasteryChange> masterySummary;
  final List<TermRef> termsMastered;
  final MisconceptionChanges misconceptions;   // activated, resolved
  final List<Unlock> unlocked;
  final List<ReviewItem>? reviewItems;   // unit tests only
  final NextStep nextStep;
}
```

`RecordedAnswer = {exerciseId, isRetry, result (correct/incorrect/neutral/hidden), recordedAt, evaluation?}`. `hidden` never means skipped.

## 6. Mapping notes and traps

- `scoring.layer` values are `understand`/`apply`/`remember`; result keys are `understanding`/`applying`/`remembering`. `remembering` is always `null` in this revision, so the completion screen shows the prototype placeholder ("In review").
- `Category.phase` is set only for `day_arc` (dawn → night order); `capacity` only for `day_arc` slots. `art_key` (`prayer_rug`, `heart`, …) selects `UnitArtIcon` art from the contract's `exercise_art_registry.json`; unknown → no art.
- `Step.secondary_label` / `CatItem.secondary_label` are display only (English ordering shows the Arabic word under each step). Never grade with them.
- `TermCard.arabic`: render it in `Amiri` 34, height 1.3, explicit RTL. When `null`, omit it; never derive it from `text` or `transliteration`.
- Hadith `translation` is `null` when the content language is Arabic.
- `QuranEvidence.segment` `{word_start, word_end}` (1-based, inclusive) means `text_uthmani` holds exactly those words. The audio clip and the recitation checker use the same range.
- Arrays (options, banks, steps) arrive **already ordered** for display. Don't shuffle; resume must show the same order.
- `Session` returned with **200** from `POST /sessions` is an existing active session (resume it). **201** is new.
- An unknown block (`UnknownItem`) is skipped as a step; log it in debug. An unknown exercise type can't be answered, so show the "Update the app to continue" card (neutral) and log it. Finishing would then fail with `409 out_of_order`, which is acceptable for an outdated client. This is recorded in `docs/API_ASSUMPTIONS.md`.

## 7. Verifying models against the contract

`test/contract/fixtures_decode_test.dart` iterates `assets/mocks/contract/MANIFEST.json` in the app (382 files, each with its model name: `Session` 63, `Exercise` 120, `AnswerSubmit` 84, `AnswerEvaluation` 86, `AnswerRecorded` 16, `Journey` 6, `RecitationCheck` 3, `ErrorEnvelope` 2, `Duel` 1, `WsEvent` 1). It decodes each through the matching DTO, and then through the mapper. Request models (`AnswerSubmit`) are decoded and re-encoded, and the JSON is compared after stripping `_mock_*` keys. A second test decodes the 105 API examples already extracted into `assets/mocks/examples/` (listed with their model names in `INDEX.json`: User, Stats, Activity, Quests, Achievements, League, Friends, Raqeeb A–H, Guide, Glossary, Onboarding, NextStep…, see [07](07_MOCKS_AND_BACKEND_SYNC.md) §3). Both tests must pass before any feature is called done.

## 8. Changes in the amended revision 10 (2026-10-03)

Learner `Session`, `Exercise`, `AnswerEvaluation`, `AnswerRecorded`, `SessionResult` and every exercise payload are unchanged except one field. What the client must handle:

| Where | Change |
|---|---|
| `User`, `OnboardingReq`, `MePatch` | `goal_anchor` (required nullable in `User`; optional in requests; never `null` in `MePatch`). Keys: `does_god_exist`, `who_is_god`, `quran_special`, `who_was_muhammad`, `muslim_beliefs`, `why_pray` (`registries.template.json`). |
| `JLesson` (journey lesson) | `standalone_eligible: bool`, `soft_lock: SoftLock?` with `prerequisites: LessonRef[]` (≥ 1) and `start_with: LessonRef`; `soft_lock` ⇔ `state == "locked"`; standalone lessons are never locked; every ref resolves inside the same journey and `start_with` is openable. |
| `BStory.origin` | Nullable: `null` marks a teaching scenario (then `provenance` and every `quote` are `null`). 22 of the 24 Unit 0 sessions contain one; they fail the old contract and pass the amended one. |
| Errors | `409 prerequisite_unmet` with `details.prerequisite_lesson_ids` (list) and `details.start_with_lesson_id` (from `POST /sessions`). |
| Reviewer shapes (Tier C) | `LessonPlan` arc, depth and reasoning fields, `Claim.basis`, sentence roles, `QAKind` additions, `RunStage.localize`, `SemanticReview`. |
