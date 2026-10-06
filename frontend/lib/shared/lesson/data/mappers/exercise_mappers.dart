import 'package:qabas/features/session/domain/entities/session_result.dart';
import 'package:qabas/shared/data/dtos/content_dto.dart';
import 'package:qabas/shared/data/mappers/content_mappers.dart';
import 'package:qabas/shared/data/mappers/core_mappers.dart';
import 'package:qabas/shared/domain/entities/content.dart';
import 'package:qabas/shared/domain/entities/stats.dart';
import 'package:qabas/shared/lesson/data/dtos/exercise_dto.dart';
import 'package:qabas/shared/lesson/data/dtos/session_dto.dart';
import 'package:qabas/shared/lesson/domain/entities/exercise.dart';

ExercisePayload decodeExercisePayload(String type, Map<String, dynamic> json) {
  switch (type) {
    case 'flashcard':
      final p = FlashcardPayloadDto.fromJson(json);
      return FlashcardPayload(contentSpans(p.front), contentSpans(p.back));
    case 'fill_blank':
      final p = FillPayloadDto.fromJson(json);
      return FillPayload(
        p.segments.map((s) => BlankSegment(text: s.text, blankId: s.blankId)).toList(),
        p.wordBank.map((w) => ExerciseOption(w.wordId, [TextContentSpan(text: w.text)])).toList(),
      );
    case 'which_evidence':
      final p = EvidenceChoicePayloadDto.fromJson(json);
      return EvidenceChoicePayload(contentSpans(p.claim), p.options.map((o) => EvidenceOption(o.optionId, o.evidence.toEntity())).toList());
    case 'verse_meaning':
      final p = VerseMeaningPayloadDto.fromJson(json);
      return ChoicePayload(p.options.map((o) => ExerciseOption(o.optionId, contentSpans(o.spans))).toList(), verse: p.verse.toEntity());
    case 'timeline_order':
      final p = TimelinePayloadDto.fromJson(json);
      return OrderPayload('timeline', p.events.map((e) => ExerciseToken(e.eventId, contentSpans(e.spans), null)).toList());
    case 'multiple_choice':
      final p = ChoicePayloadDto.fromJson(json);
      return ChoicePayload(p.options.map((o) => ExerciseOption(o.optionId, contentSpans(o.spans))).toList());
    case 'scenario':
      final p = ScenarioPayloadDto.fromJson(json);
      return ChoicePayload(
        p.options.map((o) => ExerciseOption(o.optionId, contentSpans(o.spans))).toList(),
        situation: contentSpans(p.situation),
      );
    case 'true_false_reason':
      final p = ReasonPayloadDto.fromJson(json);
      return ReasonPayload(contentSpans(p.statement), p.reasons.map((o) => ExerciseOption(o.optionId, contentSpans(o.spans))).toList());
    case 'match_pairs':
      final p = PairsPayloadDto.fromJson(json);
      return PairsPayload(
        p.left.map((o) => ExerciseOption(o.itemId, contentSpans(o.spans))).toList(),
        p.right.map((o) => ExerciseOption(o.itemId, contentSpans(o.spans))).toList(),
      );
    case 'categorize':
      final p = CategorizePayloadDto.fromJson(json);
      return CategorizePayload(
        presentation: p.presentation,
        categories: p.categories
            .map((c) => Category(id: c.categoryId, label: c.label, artKey: c.artKey, phase: c.phase, capacity: c.capacity))
            .toList(),
        items: p.items.map((i) => ExerciseToken(i.itemId, contentSpans(i.spans), i.secondaryLabel)).toList(),
      );
    case 'spot_error':
      final p = SegmentPayloadDto.fromJson(json);
      return SegmentPayload(p.segments.map((o) => ExerciseOption(o.segmentId, contentSpans(o.spans))).toList());
    case 'order_steps':
      final p = OrderPayloadDto.fromJson(json);
      return OrderPayload(p.presentation, p.steps.map((i) => ExerciseToken(i.stepId, contentSpans(i.spans), i.secondaryLabel)).toList());
    case 'map_place':
      final p = MapPayloadDto.fromJson(json);
      final i = p.interaction;
      return MapPayload(
        presentation: p.presentation,
        visual: p.visual.toEntity(),
        question: contentSpans(p.question),
        pins: p.pins
            .map((v) => MapPin(id: v.pinId, xPct: v.xPct, yPct: v.yPct, label: v.label, radiusPct: v.radiusPct, anchorId: v.anchorId))
            .toList(),
        interaction: i == null
            ? null
            : MapInteraction(
                bindings: {for (final b in i.bindings) b.pinId: visualParams(b.set)},
                resetOnDeselect: i.resetOnDeselect,
                correct: i.afterEvaluation?.correct == null ? null : visualParams(i.afterEvaluation!.correct!),
                incorrect: i.afterEvaluation?.incorrect == null ? null : visualParams(i.afterEvaluation!.incorrect!),
              ),
      );
    case 'recite_verse':
      final p = RecitePayloadDto.fromJson(json);
      return RecitePayload(
        surah: p.surah,
        ayah: p.ayah,
        wordStart: p.wordStart,
        wordEnd: p.wordEnd,
        textUthmani: p.textUthmani,
        audio: RecitationAudio(
          reciter: p.audio.reciter,
          url: p.audio.url,
          words: p.audio.words
              ?.map(
                (w) => WordTiming(
                  ayah: w.ayah,
                  position: w.position,
                  text: w.text,
                  start: Duration(milliseconds: w.startMs), // rules:allow — converts contract milliseconds
                  end: Duration(milliseconds: w.endMs), // rules:allow — converts contract milliseconds
                ),
              )
              .toList(),
        ),
        transliteration: p.transliteration,
        meaning: p.meaning == null ? null : contentSpans(p.meaning!),
        sourceId: p.sourceId,
        maxDuration: Duration(milliseconds: p.maxDurationMs), // rules:allow — converts contract milliseconds
        skippable: p.skippable,
      );
    default:
      return const UnknownExercisePayload();
  }
}

extension ExerciseMapping on ExerciseHeaderDto {
  Exercise toEntity() => Exercise(
    id: exerciseId,
    type: wireEnum(type, ExerciseType.values, ExerciseType.unknown),
    conceptIds: conceptIds,
    prompt: contentSpans(prompt),
    timeLimit: timeLimitMs == null ? null : Duration(milliseconds: timeLimitMs!), // rules:allow — converts contract milliseconds
    scoring: Scoring(accuracy: scoring.accuracy, combo: scoring.combo, layer: scoring.layer),
    framing: framing == null ? null : contentSpans(framing!.statement),
    payload: decodeExercisePayload(type, payload),
  );
}

Map<String, dynamic>? answerJson(AnswerPayload a) => switch (a) {
  TimeoutAnswer() => null,
  RatingAnswer() => {'rating': a.rating},
  FillsAnswer() => {
    'fills': [
      for (final e in a.fills.entries) {'blank_id': e.key, 'word_id': e.value},
    ],
  },
  OptionAnswer() => {'option_id': a.optionId},
  ReasonAnswer() => {'value': a.value, 'reason_option_id': a.reasonOptionId},
  PairsAnswer() => {
    'pairs': [
      for (final e in a.pairs.entries) {'left_id': e.key, 'right_id': e.value},
    ],
  },
  AssignmentsAnswer() => {
    'assignments': [
      for (final e in a.assignments.entries) {'item_id': e.key, 'category_id': e.value},
    ],
  },
  SegmentAnswer() => {'segment_id': a.segmentId},
  OrderAnswer() => {'order': a.order},
  PinAnswer() => {'pin_id': a.pinId},
  RecitationAnswer(:final checkId) => {'check_id': checkId},
  SkippedAnswer() => {'skipped': true},
  UnavailableAnswer() => {'unavailable': true},
};
AnswerPayload? correctAnswer(ExerciseType type, Map<String, dynamic>? a) {
  if (a == null) return null;
  return switch (type) {
    ExerciseType.multipleChoice ||
    ExerciseType.scenario ||
    ExerciseType.verseMeaning ||
    ExerciseType.whichEvidence => OptionAnswer(a['option_id'] as String),
    ExerciseType.trueFalseReason => ReasonAnswer(a['value'] as bool, a['reason_option_id'] as String),
    ExerciseType.matchPairs => PairsAnswer({
      for (final p in (a['pairs'] as List).cast<Map>()) p['left_id'] as String: p['right_id'] as String,
    }),
    ExerciseType.categorize => AssignmentsAnswer({
      for (final p in (a['assignments'] as List).cast<Map>()) p['item_id'] as String: p['category_id'] as String,
    }),
    ExerciseType.fillBlank => FillsAnswer({
      for (final r in (a['fills'] as List).cast<Map>()) r['blank_id'] as String: r['word_id'] as String,
    }),
    ExerciseType.spotError => SegmentAnswer(a['segment_id'] as String),
    ExerciseType.orderSteps || ExerciseType.timelineOrder => OrderAnswer((a['order'] as List).cast<String>()),
    ExerciseType.mapPlace => PinAnswer(a['pin_id'] as String),
    _ => null,
  };
}

EvaluationDetails? evaluationDetails(ExerciseType type, Map<String, dynamic>? d) {
  if (d == null) return null;
  return switch (type) {
    ExerciseType.trueFalseReason => ReasonDetails(d['value_correct'] as bool, d['reason_correct'] as bool),
    ExerciseType.matchPairs => ItemDetails({
      for (final r in (d['pair_results'] as List).cast<Map>()) r['left_id'] as String: r['correct'] as bool,
    }),
    ExerciseType.categorize => ItemDetails({
      for (final r in (d['item_results'] as List).cast<Map>()) r['item_id'] as String: r['correct'] as bool,
    }),
    ExerciseType.fillBlank => ItemDetails({
      for (final r in (d['blank_results'] as List).cast<Map>()) r['blank_id'] as String: r['correct'] as bool,
    }),
    ExerciseType.timelineOrder => TimelineDetails({
      for (final r in (d['event_dates'] as List).cast<Map>()) r['event_id'] as String: r['label'] as String,
    }),
    ExerciseType.orderSteps => OrderDetails(d['first_wrong_index'] as int?),
    ExerciseType.scenario => ScenarioDetails({
      for (final r in (d['option_feedback'] as List).cast<Map>())
        r['option_id'] as String: contentSpans(
          (r['spans'] as List).map((s) => SpanDto.fromJson(Map<String, dynamic>.from(s as Map))).toList(),
        ),
    }),
    ExerciseType.mapPlace => PinDetails({
      for (final r in (d['pin_labels'] as List).cast<Map>()) r['pin_id'] as String: r['label'] as String,
    }),
    _ => null,
  };
}

AnswerResponse decodeAnswerResponse(Map<String, dynamic> json, ExerciseType type, {required bool immediate}) {
  if (!immediate) {
    final d = AnswerRecordedDto.fromJson(json);
    return AnswerRecorded(d.exerciseId);
  }
  final d = AnswerEvaluationDto.fromJson(json);
  final m = d.misconception;
  return AnswerEvaluation(
    exerciseId: d.exerciseId,
    correct: d.correct,
    correctAnswer: correctAnswer(type, d.correctAnswer),
    details: evaluationDetails(type, d.details),
    explanation: contentSpans(d.explanation),
    sourceIds: d.sourceIds,
    misconception: m == null
        ? null
        : Misconception(id: m.misconceptionId, title: m.title, card: contentSpans(m.card), sourceIds: m.sourceIds),
    masteryChanges: d.masteryChanges.map((c) => MasteryChange(c.conceptId, c.title, c.before, c.after)).toList(),
    termChanges: d.termChanges
        .map((c) => TermChange(c.termId, c.state == 'new' ? TermState.newTerm : wireEnum(c.state, TermState.values, TermState.unknown)))
        .toList(),
    xpAwarded: d.xpAwarded,
  );
}

extension SessionResultMapping on SessionResultDto {
  SessionResult toEntity() => SessionResult(
    sessionId: sessionId,
    kind: kind,
    correct: score.correct,
    total: score.total,
    percent: score.percent,
    passed: passed,
    xp: xp.total,
    duration: Duration(milliseconds: durationMs), // rules:allow — converts contract milliseconds
    understanding: layers.understanding == null
        ? null
        : LayerScore(layers.understanding!.correct, layers.understanding!.total, layers.understanding!.percent),
    applying: layers.applying == null ? null : LayerScore(layers.applying!.correct, layers.applying!.total, layers.applying!.percent),
    streakCurrent: streak.current,
    streakExtended: streak.extendedToday,
    dailyGoal: DailyGoal(minutes: dailyGoal.minutes, minutesToday: dailyGoal.minutesToday, met: dailyGoal.met),
    nextStep: nextStep.toEntity(),
    xpBreakdown: xp.breakdown.map((g) => XpGrant(g.reason, g.xp)).toList(),
    masterySummary: masterySummary.map((c) => MasteryChange(c.conceptId, c.title, c.before, c.after)).toList(),
    termsMastered: termsMastered.map((t) => ResultReference(t.termId, t.text)).toList(),
    misconceptionsActivated: misconceptions.activated.map((m) => ResultReference(m.misconceptionId, m.title)).toList(),
    misconceptionsResolved: misconceptions.resolved.map((m) => ResultReference(m.misconceptionId, m.title)).toList(),
    reviewItems: (reviewItems ?? [])
        .map(
          (r) => AnswerReview(
            exerciseId: r.exerciseId,
            correct: r.correct,
            correctAnswer: decodeStoredAnswer(r.correctAnswer),
            explanation: contentSpans(r.explanation),
            sourceIds: r.sourceIds,
          ),
        )
        .toList(),
    unlocked: unlocked.map((u) => ResultUnlock(u.type, u.id, u.title)).toList(),
  );
}

AnswerPayload? decodeStoredAnswer(Map<String, dynamic>? a) {
  if (a == null) return null;
  if (a['option_id'] is String) return OptionAnswer(a['option_id'] as String);
  if (a['value'] is bool) return ReasonAnswer(a['value'] as bool, a['reason_option_id'] as String);
  if (a['segment_id'] is String) return SegmentAnswer(a['segment_id'] as String);
  if (a['pin_id'] is String) return PinAnswer(a['pin_id'] as String);
  if (a['rating'] is String) return RatingAnswer(a['rating'] as String);
  if (a['order'] is List) return OrderAnswer((a['order'] as List).cast<String>());
  if (a['fills'] is List) {
    return FillsAnswer({for (final r in (a['fills'] as List).cast<Map>()) r['blank_id'] as String: r['word_id'] as String});
  }
  if (a['pairs'] is List) {
    return PairsAnswer({for (final r in (a['pairs'] as List).cast<Map>()) r['left_id'] as String: r['right_id'] as String});
  }
  if (a['assignments'] is List) {
    return AssignmentsAnswer({for (final r in (a['assignments'] as List).cast<Map>()) r['item_id'] as String: r['category_id'] as String});
  }
  if (a['check_id'] is String) return RecitationAnswer(a['check_id'] as String);
  if (a['skipped'] == true) return const SkippedAnswer();
  if (a['unavailable'] == true) return const UnavailableAnswer();
  return null;
}
