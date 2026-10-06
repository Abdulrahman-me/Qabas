// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exercise_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ExerciseOptionDto _$ExerciseOptionDtoFromJson(Map<String, dynamic> json) => $checkedCreate('ExerciseOptionDto', json, ($checkedConvert) {
  final val = ExerciseOptionDto(
    optionId: $checkedConvert('option_id', (v) => v as String),
    spans: $checkedConvert('spans', (v) => (v as List<dynamic>).map((e) => SpanDto.fromJson(e as Map<String, dynamic>)).toList()),
  );
  return val;
}, fieldKeyMap: const {'optionId': 'option_id'});

ExerciseItemDto _$ExerciseItemDtoFromJson(Map<String, dynamic> json) => $checkedCreate('ExerciseItemDto', json, ($checkedConvert) {
  final val = ExerciseItemDto(
    itemId: $checkedConvert('item_id', (v) => v as String),
    spans: $checkedConvert('spans', (v) => (v as List<dynamic>).map((e) => SpanDto.fromJson(e as Map<String, dynamic>)).toList()),
  );
  return val;
}, fieldKeyMap: const {'itemId': 'item_id'});

ChoicePayloadDto _$ChoicePayloadDtoFromJson(Map<String, dynamic> json) => $checkedCreate('ChoicePayloadDto', json, ($checkedConvert) {
  final val = ChoicePayloadDto(
    options: $checkedConvert(
      'options',
      (v) => (v as List<dynamic>).map((e) => ExerciseOptionDto.fromJson(e as Map<String, dynamic>)).toList(),
    ),
  );
  return val;
});

ScenarioPayloadDto _$ScenarioPayloadDtoFromJson(Map<String, dynamic> json) => $checkedCreate('ScenarioPayloadDto', json, ($checkedConvert) {
  final val = ScenarioPayloadDto(
    situation: $checkedConvert('situation', (v) => (v as List<dynamic>).map((e) => SpanDto.fromJson(e as Map<String, dynamic>)).toList()),
    options: $checkedConvert(
      'options',
      (v) => (v as List<dynamic>).map((e) => ExerciseOptionDto.fromJson(e as Map<String, dynamic>)).toList(),
    ),
  );
  return val;
});

ReasonPayloadDto _$ReasonPayloadDtoFromJson(Map<String, dynamic> json) => $checkedCreate('ReasonPayloadDto', json, ($checkedConvert) {
  final val = ReasonPayloadDto(
    statement: $checkedConvert('statement', (v) => (v as List<dynamic>).map((e) => SpanDto.fromJson(e as Map<String, dynamic>)).toList()),
    reasons: $checkedConvert(
      'reasons',
      (v) => (v as List<dynamic>).map((e) => ExerciseOptionDto.fromJson(e as Map<String, dynamic>)).toList(),
    ),
  );
  return val;
});

PairsPayloadDto _$PairsPayloadDtoFromJson(Map<String, dynamic> json) => $checkedCreate('PairsPayloadDto', json, ($checkedConvert) {
  final val = PairsPayloadDto(
    left: $checkedConvert('left', (v) => (v as List<dynamic>).map((e) => ExerciseItemDto.fromJson(e as Map<String, dynamic>)).toList()),
    right: $checkedConvert('right', (v) => (v as List<dynamic>).map((e) => ExerciseItemDto.fromJson(e as Map<String, dynamic>)).toList()),
  );
  return val;
});

CategoryDto _$CategoryDtoFromJson(Map<String, dynamic> json) => $checkedCreate('CategoryDto', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['art_key', 'phase', 'capacity']);
  final val = CategoryDto(
    categoryId: $checkedConvert('category_id', (v) => v as String),
    label: $checkedConvert('label', (v) => v as String),
    artKey: $checkedConvert('art_key', (v) => v as String?),
    phase: $checkedConvert('phase', (v) => v as String?),
    capacity: $checkedConvert('capacity', (v) => (v as num?)?.toInt()),
  );
  return val;
}, fieldKeyMap: const {'categoryId': 'category_id', 'artKey': 'art_key'});

CatItemDto _$CatItemDtoFromJson(Map<String, dynamic> json) => $checkedCreate('CatItemDto', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['secondary_label']);
  final val = CatItemDto(
    itemId: $checkedConvert('item_id', (v) => v as String),
    spans: $checkedConvert('spans', (v) => (v as List<dynamic>).map((e) => SpanDto.fromJson(e as Map<String, dynamic>)).toList()),
    secondaryLabel: $checkedConvert('secondary_label', (v) => v as String?),
  );
  return val;
}, fieldKeyMap: const {'itemId': 'item_id', 'secondaryLabel': 'secondary_label'});

CategorizePayloadDto _$CategorizePayloadDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('CategorizePayloadDto', json, ($checkedConvert) {
      final val = CategorizePayloadDto(
        presentation: $checkedConvert('presentation', (v) => v as String),
        categories: $checkedConvert(
          'categories',
          (v) => (v as List<dynamic>).map((e) => CategoryDto.fromJson(e as Map<String, dynamic>)).toList(),
        ),
        items: $checkedConvert('items', (v) => (v as List<dynamic>).map((e) => CatItemDto.fromJson(e as Map<String, dynamic>)).toList()),
      );
      return val;
    });

SegmentDto _$SegmentDtoFromJson(Map<String, dynamic> json) => $checkedCreate('SegmentDto', json, ($checkedConvert) {
  final val = SegmentDto(
    segmentId: $checkedConvert('segment_id', (v) => v as String),
    spans: $checkedConvert('spans', (v) => (v as List<dynamic>).map((e) => SpanDto.fromJson(e as Map<String, dynamic>)).toList()),
  );
  return val;
}, fieldKeyMap: const {'segmentId': 'segment_id'});

SegmentPayloadDto _$SegmentPayloadDtoFromJson(Map<String, dynamic> json) => $checkedCreate('SegmentPayloadDto', json, ($checkedConvert) {
  final val = SegmentPayloadDto(
    segments: $checkedConvert('segments', (v) => (v as List<dynamic>).map((e) => SegmentDto.fromJson(e as Map<String, dynamic>)).toList()),
  );
  return val;
});

OrderStepDto _$OrderStepDtoFromJson(Map<String, dynamic> json) => $checkedCreate('OrderStepDto', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['secondary_label']);
  final val = OrderStepDto(
    stepId: $checkedConvert('step_id', (v) => v as String),
    spans: $checkedConvert('spans', (v) => (v as List<dynamic>).map((e) => SpanDto.fromJson(e as Map<String, dynamic>)).toList()),
    secondaryLabel: $checkedConvert('secondary_label', (v) => v as String?),
  );
  return val;
}, fieldKeyMap: const {'stepId': 'step_id', 'secondaryLabel': 'secondary_label'});

OrderPayloadDto _$OrderPayloadDtoFromJson(Map<String, dynamic> json) => $checkedCreate('OrderPayloadDto', json, ($checkedConvert) {
  final val = OrderPayloadDto(
    presentation: $checkedConvert('presentation', (v) => v as String),
    steps: $checkedConvert('steps', (v) => (v as List<dynamic>).map((e) => OrderStepDto.fromJson(e as Map<String, dynamic>)).toList()),
  );
  return val;
});

PinDto _$PinDtoFromJson(Map<String, dynamic> json) => $checkedCreate('PinDto', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['label', 'radius_pct', 'anchor_id']);
  final val = PinDto(
    pinId: $checkedConvert('pin_id', (v) => v as String),
    xPct: $checkedConvert('x_pct', (v) => (v as num).toDouble()),
    yPct: $checkedConvert('y_pct', (v) => (v as num).toDouble()),
    label: $checkedConvert('label', (v) => v as String?),
    radiusPct: $checkedConvert('radius_pct', (v) => (v as num?)?.toDouble()),
    anchorId: $checkedConvert('anchor_id', (v) => v as String?),
  );
  return val;
}, fieldKeyMap: const {'pinId': 'pin_id', 'xPct': 'x_pct', 'yPct': 'y_pct', 'radiusPct': 'radius_pct', 'anchorId': 'anchor_id'});

BindingDto _$BindingDtoFromJson(Map<String, dynamic> json) => $checkedCreate('BindingDto', json, ($checkedConvert) {
  final val = BindingDto(
    pinId: $checkedConvert('pin_id', (v) => v as String),
    set: $checkedConvert('set', (v) => v as Map<String, dynamic>),
  );
  return val;
}, fieldKeyMap: const {'pinId': 'pin_id'});

AfterEvaluationDto _$AfterEvaluationDtoFromJson(Map<String, dynamic> json) => $checkedCreate('AfterEvaluationDto', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['correct', 'incorrect']);
  final val = AfterEvaluationDto(
    correct: $checkedConvert('correct', (v) => v as Map<String, dynamic>?),
    incorrect: $checkedConvert('incorrect', (v) => v as Map<String, dynamic>?),
  );
  return val;
});

InteractionDto _$InteractionDtoFromJson(Map<String, dynamic> json) => $checkedCreate('InteractionDto', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['after_evaluation']);
  final val = InteractionDto(
    bindings: $checkedConvert('bindings', (v) => (v as List<dynamic>).map((e) => BindingDto.fromJson(e as Map<String, dynamic>)).toList()),
    resetOnDeselect: $checkedConvert('reset_on_deselect', (v) => v as bool),
    afterEvaluation: $checkedConvert('after_evaluation', (v) => v == null ? null : AfterEvaluationDto.fromJson(v as Map<String, dynamic>)),
  );
  return val;
}, fieldKeyMap: const {'resetOnDeselect': 'reset_on_deselect', 'afterEvaluation': 'after_evaluation'});

MapPayloadDto _$MapPayloadDtoFromJson(Map<String, dynamic> json) => $checkedCreate('MapPayloadDto', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['interaction']);
  final val = MapPayloadDto(
    presentation: $checkedConvert('presentation', (v) => v as String),
    visual: $checkedConvert('visual', (v) => VisualDto.fromJson(v as Map<String, dynamic>)),
    question: $checkedConvert('question', (v) => (v as List<dynamic>).map((e) => SpanDto.fromJson(e as Map<String, dynamic>)).toList()),
    pins: $checkedConvert('pins', (v) => (v as List<dynamic>).map((e) => PinDto.fromJson(e as Map<String, dynamic>)).toList()),
    interaction: $checkedConvert('interaction', (v) => v == null ? null : InteractionDto.fromJson(v as Map<String, dynamic>)),
  );
  return val;
});

RecitePayloadDto _$RecitePayloadDtoFromJson(Map<String, dynamic> json) => $checkedCreate(
  'RecitePayloadDto',
  json,
  ($checkedConvert) {
    $checkKeys(json, requiredKeys: const ['word_start', 'word_end', 'transliteration', 'meaning']);
    final val = RecitePayloadDto(
      surah: $checkedConvert('surah', (v) => (v as num).toInt()),
      ayah: $checkedConvert('ayah', (v) => (v as num).toInt()),
      wordStart: $checkedConvert('word_start', (v) => (v as num?)?.toInt()),
      wordEnd: $checkedConvert('word_end', (v) => (v as num?)?.toInt()),
      textUthmani: $checkedConvert('text_uthmani', (v) => v as String),
      audio: $checkedConvert('audio', (v) => AudioDto.fromJson(v as Map<String, dynamic>)),
      transliteration: $checkedConvert('transliteration', (v) => v as String?),
      meaning: $checkedConvert('meaning', (v) => (v as List<dynamic>?)?.map((e) => SpanDto.fromJson(e as Map<String, dynamic>)).toList()),
      sourceId: $checkedConvert('source_id', (v) => v as String),
      maxDurationMs: $checkedConvert('max_duration_ms', (v) => (v as num).toInt()),
      skippable: $checkedConvert('skippable', (v) => v as bool),
    );
    return val;
  },
  fieldKeyMap: const {
    'wordStart': 'word_start',
    'wordEnd': 'word_end',
    'textUthmani': 'text_uthmani',
    'sourceId': 'source_id',
    'maxDurationMs': 'max_duration_ms',
  },
);

ScoringDto _$ScoringDtoFromJson(Map<String, dynamic> json) => $checkedCreate('ScoringDto', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['layer']);
  final val = ScoringDto(
    accuracy: $checkedConvert('accuracy', (v) => v as bool),
    combo: $checkedConvert('combo', (v) => v as bool),
    layer: $checkedConvert('layer', (v) => v as String?),
  );
  return val;
});

FramingDto _$FramingDtoFromJson(Map<String, dynamic> json) => $checkedCreate('FramingDto', json, ($checkedConvert) {
  final val = FramingDto(
    kind: $checkedConvert('kind', (v) => v as String),
    statement: $checkedConvert('statement', (v) => (v as List<dynamic>).map((e) => SpanDto.fromJson(e as Map<String, dynamic>)).toList()),
  );
  return val;
});

MisconceptionDto _$MisconceptionDtoFromJson(Map<String, dynamic> json) => $checkedCreate('MisconceptionDto', json, ($checkedConvert) {
  final val = MisconceptionDto(
    misconceptionId: $checkedConvert('misconception_id', (v) => v as String),
    title: $checkedConvert('title', (v) => v as String),
    card: $checkedConvert('card', (v) => (v as List<dynamic>).map((e) => SpanDto.fromJson(e as Map<String, dynamic>)).toList()),
    sourceIds: $checkedConvert('source_ids', (v) => (v as List<dynamic>).map((e) => e as String).toList()),
  );
  return val;
}, fieldKeyMap: const {'misconceptionId': 'misconception_id', 'sourceIds': 'source_ids'});

MasteryChangeDto _$MasteryChangeDtoFromJson(Map<String, dynamic> json) => $checkedCreate('MasteryChangeDto', json, ($checkedConvert) {
  final val = MasteryChangeDto(
    conceptId: $checkedConvert('concept_id', (v) => v as String),
    title: $checkedConvert('title', (v) => v as String),
    before: $checkedConvert('before', (v) => (v as num).toDouble()),
    after: $checkedConvert('after', (v) => (v as num).toDouble()),
  );
  return val;
}, fieldKeyMap: const {'conceptId': 'concept_id'});

TermChangeDto _$TermChangeDtoFromJson(Map<String, dynamic> json) => $checkedCreate('TermChangeDto', json, ($checkedConvert) {
  final val = TermChangeDto(termId: $checkedConvert('term_id', (v) => v as String), state: $checkedConvert('state', (v) => v as String));
  return val;
}, fieldKeyMap: const {'termId': 'term_id'});

AnswerEvaluationDto _$AnswerEvaluationDtoFromJson(Map<String, dynamic> json) => $checkedCreate(
  'AnswerEvaluationDto',
  json,
  ($checkedConvert) {
    $checkKeys(json, requiredKeys: const ['correct', 'correct_answer', 'details', 'misconception']);
    final val = AnswerEvaluationDto(
      exerciseId: $checkedConvert('exercise_id', (v) => v as String),
      recorded: $checkedConvert('recorded', (v) => v as bool),
      correct: $checkedConvert('correct', (v) => v as bool?),
      correctAnswer: $checkedConvert('correct_answer', (v) => v as Map<String, dynamic>?),
      details: $checkedConvert('details', (v) => v as Map<String, dynamic>?),
      explanation: $checkedConvert(
        'explanation',
        (v) => (v as List<dynamic>).map((e) => SpanDto.fromJson(e as Map<String, dynamic>)).toList(),
      ),
      sourceIds: $checkedConvert('source_ids', (v) => (v as List<dynamic>).map((e) => e as String).toList()),
      misconception: $checkedConvert('misconception', (v) => v == null ? null : MisconceptionDto.fromJson(v as Map<String, dynamic>)),
      masteryChanges: $checkedConvert(
        'mastery_changes',
        (v) => (v as List<dynamic>).map((e) => MasteryChangeDto.fromJson(e as Map<String, dynamic>)).toList(),
      ),
      termChanges: $checkedConvert(
        'term_changes',
        (v) => (v as List<dynamic>).map((e) => TermChangeDto.fromJson(e as Map<String, dynamic>)).toList(),
      ),
      xpAwarded: $checkedConvert('xp_awarded', (v) => (v as num).toInt()),
    );
    return val;
  },
  fieldKeyMap: const {
    'exerciseId': 'exercise_id',
    'correctAnswer': 'correct_answer',
    'sourceIds': 'source_ids',
    'masteryChanges': 'mastery_changes',
    'termChanges': 'term_changes',
    'xpAwarded': 'xp_awarded',
  },
);

AnswerRecordedDto _$AnswerRecordedDtoFromJson(Map<String, dynamic> json) => $checkedCreate('AnswerRecordedDto', json, ($checkedConvert) {
  final val = AnswerRecordedDto(
    exerciseId: $checkedConvert('exercise_id', (v) => v as String),
    recorded: $checkedConvert('recorded', (v) => v as bool),
  );
  return val;
}, fieldKeyMap: const {'exerciseId': 'exercise_id'});

AnswerSubmitDto _$AnswerSubmitDtoFromJson(Map<String, dynamic> json) => $checkedCreate('AnswerSubmitDto', json, ($checkedConvert) {
  final val = AnswerSubmitDto(
    exerciseId: $checkedConvert('exercise_id', (v) => v as String),
    answer: $checkedConvert('answer', (v) => v as Map<String, dynamic>?),
    elapsedMs: $checkedConvert('elapsed_ms', (v) => (v as num).toInt()),
    isRetry: $checkedConvert('is_retry', (v) => v as bool),
  );
  return val;
}, fieldKeyMap: const {'exerciseId': 'exercise_id', 'elapsedMs': 'elapsed_ms', 'isRetry': 'is_retry'});

Map<String, dynamic> _$AnswerSubmitDtoToJson(AnswerSubmitDto instance) => <String, dynamic>{
  'exercise_id': instance.exerciseId,
  'answer': instance.answer,
  'elapsed_ms': instance.elapsedMs,
  'is_retry': instance.isRetry,
};

FinishRequestDto _$FinishRequestDtoFromJson(Map<String, dynamic> json) => $checkedCreate('FinishRequestDto', json, ($checkedConvert) {
  final val = FinishRequestDto(durationMs: $checkedConvert('duration_ms', (v) => (v as num).toInt()));
  return val;
}, fieldKeyMap: const {'durationMs': 'duration_ms'});

Map<String, dynamic> _$FinishRequestDtoToJson(FinishRequestDto instance) => <String, dynamic>{'duration_ms': instance.durationMs};

ResultScoreDto _$ResultScoreDtoFromJson(Map<String, dynamic> json) => $checkedCreate('ResultScoreDto', json, ($checkedConvert) {
  final val = ResultScoreDto(
    correct: $checkedConvert('correct', (v) => (v as num).toInt()),
    total: $checkedConvert('total', (v) => (v as num).toInt()),
    percent: $checkedConvert('percent', (v) => (v as num).toInt()),
  );
  return val;
});

ResultXpDto _$ResultXpDtoFromJson(Map<String, dynamic> json) => $checkedCreate('ResultXpDto', json, ($checkedConvert) {
  final val = ResultXpDto(
    total: $checkedConvert('total', (v) => (v as num).toInt()),
    breakdown: $checkedConvert(
      'breakdown',
      (v) => (v as List<dynamic>).map((e) => ResultXpGrantDto.fromJson(e as Map<String, dynamic>)).toList(),
    ),
  );
  return val;
});

SessionResultDto _$SessionResultDtoFromJson(Map<String, dynamic> json) => $checkedCreate(
  'SessionResultDto',
  json,
  ($checkedConvert) {
    $checkKeys(json, requiredKeys: const ['passed', 'review_items']);
    final val = SessionResultDto(
      sessionId: $checkedConvert('session_id', (v) => v as String),
      kind: $checkedConvert('kind', (v) => v as String),
      score: $checkedConvert('score', (v) => ResultScoreDto.fromJson(v as Map<String, dynamic>)),
      passed: $checkedConvert('passed', (v) => v as bool?),
      xp: $checkedConvert('xp', (v) => ResultXpDto.fromJson(v as Map<String, dynamic>)),
      durationMs: $checkedConvert('duration_ms', (v) => (v as num).toInt()),
      layers: $checkedConvert('layers', (v) => ResultLayersDto.fromJson(v as Map<String, dynamic>)),
      streak: $checkedConvert('streak', (v) => ResultStreakDto.fromJson(v as Map<String, dynamic>)),
      dailyGoal: $checkedConvert('daily_goal', (v) => DailyGoalDto.fromJson(v as Map<String, dynamic>)),
      masterySummary: $checkedConvert(
        'mastery_summary',
        (v) => (v as List<dynamic>).map((e) => MasteryChangeDto.fromJson(e as Map<String, dynamic>)).toList(),
      ),
      termsMastered: $checkedConvert(
        'terms_mastered',
        (v) => (v as List<dynamic>).map((e) => ResultTermDto.fromJson(e as Map<String, dynamic>)).toList(),
      ),
      misconceptions: $checkedConvert('misconceptions', (v) => ResultMisconceptionsDto.fromJson(v as Map<String, dynamic>)),
      unlocked: $checkedConvert(
        'unlocked',
        (v) => (v as List<dynamic>).map((e) => ResultUnlockDto.fromJson(e as Map<String, dynamic>)).toList(),
      ),
      nextStep: $checkedConvert('next_step', (v) => NextStepDto.fromJson(v as Map<String, dynamic>)),
      reviewItems: $checkedConvert(
        'review_items',
        (v) => (v as List<dynamic>?)?.map((e) => AnswerReviewDto.fromJson(e as Map<String, dynamic>)).toList(),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'sessionId': 'session_id',
    'durationMs': 'duration_ms',
    'dailyGoal': 'daily_goal',
    'masterySummary': 'mastery_summary',
    'termsMastered': 'terms_mastered',
    'nextStep': 'next_step',
    'reviewItems': 'review_items',
  },
);

ResultXpGrantDto _$ResultXpGrantDtoFromJson(Map<String, dynamic> json) => $checkedCreate('ResultXpGrantDto', json, ($checkedConvert) {
  final val = ResultXpGrantDto(reason: $checkedConvert('reason', (v) => v as String), xp: $checkedConvert('xp', (v) => (v as num).toInt()));
  return val;
});

ResultLayersDto _$ResultLayersDtoFromJson(Map<String, dynamic> json) => $checkedCreate('ResultLayersDto', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['understanding', 'applying', 'remembering']);
  final val = ResultLayersDto(
    understanding: $checkedConvert('understanding', (v) => v == null ? null : ResultScoreDto.fromJson(v as Map<String, dynamic>)),
    applying: $checkedConvert('applying', (v) => v == null ? null : ResultScoreDto.fromJson(v as Map<String, dynamic>)),
    remembering: $checkedConvert('remembering', (v) => v == null ? null : ResultScoreDto.fromJson(v as Map<String, dynamic>)),
  );
  return val;
});

ResultStreakDto _$ResultStreakDtoFromJson(Map<String, dynamic> json) => $checkedCreate('ResultStreakDto', json, ($checkedConvert) {
  final val = ResultStreakDto(
    current: $checkedConvert('current', (v) => (v as num).toInt()),
    extendedToday: $checkedConvert('extended_today', (v) => v as bool),
  );
  return val;
}, fieldKeyMap: const {'extendedToday': 'extended_today'});

ResultTermDto _$ResultTermDtoFromJson(Map<String, dynamic> json) => $checkedCreate('ResultTermDto', json, ($checkedConvert) {
  final val = ResultTermDto(termId: $checkedConvert('term_id', (v) => v as String), text: $checkedConvert('text', (v) => v as String));
  return val;
}, fieldKeyMap: const {'termId': 'term_id'});

ResultMisconceptionDto _$ResultMisconceptionDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ResultMisconceptionDto', json, ($checkedConvert) {
      final val = ResultMisconceptionDto(
        misconceptionId: $checkedConvert('misconception_id', (v) => v as String),
        title: $checkedConvert('title', (v) => v as String),
      );
      return val;
    }, fieldKeyMap: const {'misconceptionId': 'misconception_id'});

ResultMisconceptionsDto _$ResultMisconceptionsDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ResultMisconceptionsDto', json, ($checkedConvert) {
      final val = ResultMisconceptionsDto(
        activated: $checkedConvert(
          'activated',
          (v) => (v as List<dynamic>).map((e) => ResultMisconceptionDto.fromJson(e as Map<String, dynamic>)).toList(),
        ),
        resolved: $checkedConvert(
          'resolved',
          (v) => (v as List<dynamic>).map((e) => ResultMisconceptionDto.fromJson(e as Map<String, dynamic>)).toList(),
        ),
      );
      return val;
    });

ResultUnlockDto _$ResultUnlockDtoFromJson(Map<String, dynamic> json) => $checkedCreate('ResultUnlockDto', json, ($checkedConvert) {
  final val = ResultUnlockDto(
    type: $checkedConvert('type', (v) => v as String),
    id: $checkedConvert('id', (v) => v as String),
    title: $checkedConvert('title', (v) => v as String),
  );
  return val;
});

FlashcardPayloadDto _$FlashcardPayloadDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('FlashcardPayloadDto', json, ($checkedConvert) {
      final val = FlashcardPayloadDto(
        front: $checkedConvert('front', (v) => (v as List<dynamic>).map((e) => SpanDto.fromJson(e as Map<String, dynamic>)).toList()),
        back: $checkedConvert('back', (v) => (v as List<dynamic>).map((e) => SpanDto.fromJson(e as Map<String, dynamic>)).toList()),
      );
      return val;
    });

BlankSegmentDto _$BlankSegmentDtoFromJson(Map<String, dynamic> json) => $checkedCreate('BlankSegmentDto', json, ($checkedConvert) {
  final val = BlankSegmentDto(
    type: $checkedConvert('type', (v) => v as String),
    text: $checkedConvert('text', (v) => v as String?),
    blankId: $checkedConvert('blank_id', (v) => v as String?),
  );
  return val;
}, fieldKeyMap: const {'blankId': 'blank_id'});

BankWordDto _$BankWordDtoFromJson(Map<String, dynamic> json) => $checkedCreate('BankWordDto', json, ($checkedConvert) {
  final val = BankWordDto(wordId: $checkedConvert('word_id', (v) => v as String), text: $checkedConvert('text', (v) => v as String));
  return val;
}, fieldKeyMap: const {'wordId': 'word_id'});

FillPayloadDto _$FillPayloadDtoFromJson(Map<String, dynamic> json) => $checkedCreate('FillPayloadDto', json, ($checkedConvert) {
  final val = FillPayloadDto(
    segments: $checkedConvert(
      'segments',
      (v) => (v as List<dynamic>).map((e) => BlankSegmentDto.fromJson(e as Map<String, dynamic>)).toList(),
    ),
    wordBank: $checkedConvert(
      'word_bank',
      (v) => (v as List<dynamic>).map((e) => BankWordDto.fromJson(e as Map<String, dynamic>)).toList(),
    ),
  );
  return val;
}, fieldKeyMap: const {'wordBank': 'word_bank'});

EvidenceOptionDto _$EvidenceOptionDtoFromJson(Map<String, dynamic> json) => $checkedCreate('EvidenceOptionDto', json, ($checkedConvert) {
  final val = EvidenceOptionDto(
    optionId: $checkedConvert('option_id', (v) => v as String),
    evidence: $checkedConvert('evidence', (v) => EvidenceDto.fromJson(v as Map<String, dynamic>)),
  );
  return val;
}, fieldKeyMap: const {'optionId': 'option_id'});

EvidenceChoicePayloadDto _$EvidenceChoicePayloadDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('EvidenceChoicePayloadDto', json, ($checkedConvert) {
      final val = EvidenceChoicePayloadDto(
        claim: $checkedConvert('claim', (v) => (v as List<dynamic>).map((e) => SpanDto.fromJson(e as Map<String, dynamic>)).toList()),
        options: $checkedConvert(
          'options',
          (v) => (v as List<dynamic>).map((e) => EvidenceOptionDto.fromJson(e as Map<String, dynamic>)).toList(),
        ),
      );
      return val;
    });

VerseMeaningPayloadDto _$VerseMeaningPayloadDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('VerseMeaningPayloadDto', json, ($checkedConvert) {
      final val = VerseMeaningPayloadDto(
        verse: $checkedConvert('verse', (v) => EvidenceDto.fromJson(v as Map<String, dynamic>)),
        options: $checkedConvert(
          'options',
          (v) => (v as List<dynamic>).map((e) => ExerciseOptionDto.fromJson(e as Map<String, dynamic>)).toList(),
        ),
      );
      return val;
    });

TimelineEventDto _$TimelineEventDtoFromJson(Map<String, dynamic> json) => $checkedCreate('TimelineEventDto', json, ($checkedConvert) {
  final val = TimelineEventDto(
    eventId: $checkedConvert('event_id', (v) => v as String),
    spans: $checkedConvert('spans', (v) => (v as List<dynamic>).map((e) => SpanDto.fromJson(e as Map<String, dynamic>)).toList()),
  );
  return val;
}, fieldKeyMap: const {'eventId': 'event_id'});

TimelinePayloadDto _$TimelinePayloadDtoFromJson(Map<String, dynamic> json) => $checkedCreate('TimelinePayloadDto', json, ($checkedConvert) {
  final val = TimelinePayloadDto(
    events: $checkedConvert(
      'events',
      (v) => (v as List<dynamic>).map((e) => TimelineEventDto.fromJson(e as Map<String, dynamic>)).toList(),
    ),
  );
  return val;
});

AnswerReviewDto _$AnswerReviewDtoFromJson(Map<String, dynamic> json) => $checkedCreate('AnswerReviewDto', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['correct', 'correct_answer']);
  final val = AnswerReviewDto(
    exerciseId: $checkedConvert('exercise_id', (v) => v as String),
    correct: $checkedConvert('correct', (v) => v as bool?),
    correctAnswer: $checkedConvert('correct_answer', (v) => v as Map<String, dynamic>?),
    explanation: $checkedConvert(
      'explanation',
      (v) => (v as List<dynamic>).map((e) => SpanDto.fromJson(e as Map<String, dynamic>)).toList(),
    ),
    sourceIds: $checkedConvert('source_ids', (v) => (v as List<dynamic>).map((e) => e as String).toList()),
  );
  return val;
}, fieldKeyMap: const {'exerciseId': 'exercise_id', 'correctAnswer': 'correct_answer', 'sourceIds': 'source_ids'});
