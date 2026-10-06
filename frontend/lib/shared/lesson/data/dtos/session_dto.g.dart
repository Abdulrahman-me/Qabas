// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CountsDto _$CountsDtoFromJson(Map<String, dynamic> json) => $checkedCreate('CountsDto', json, ($checkedConvert) {
  final val = CountsDto(
    interactions: $checkedConvert('interactions', (v) => (v as num).toInt()),
    exercises: $checkedConvert('exercises', (v) => (v as num).toInt()),
    scored: $checkedConvert('scored', (v) => (v as num).toInt()),
  );
  return val;
});

RecordedAnswerDto _$RecordedAnswerDtoFromJson(Map<String, dynamic> json) => $checkedCreate('RecordedAnswerDto', json, ($checkedConvert) {
  final val = RecordedAnswerDto(
    exerciseId: $checkedConvert('exercise_id', (v) => v as String),
    isRetry: $checkedConvert('is_retry', (v) => v as bool),
    result: $checkedConvert('result', (v) => v as String),
    recordedAt: $checkedConvert('recorded_at', (v) => v as String),
    evaluation: $checkedConvert('evaluation', (v) => v as Map<String, dynamic>?),
  );
  return val;
}, fieldKeyMap: const {'exerciseId': 'exercise_id', 'isRetry': 'is_retry', 'recordedAt': 'recorded_at'});

ReviewTopicDto _$ReviewTopicDtoFromJson(Map<String, dynamic> json) => $checkedCreate('ReviewTopicDto', json, ($checkedConvert) {
  final val = ReviewTopicDto(
    topicId: $checkedConvert('topic_id', (v) => v as String),
    title: $checkedConvert('title', (v) => v as String),
    conceptIds: $checkedConvert('concept_ids', (v) => (v as List<dynamic>).map((e) => e as String).toList()),
  );
  return val;
}, fieldKeyMap: const {'topicId': 'topic_id', 'conceptIds': 'concept_ids'});

CompletionDto _$CompletionDtoFromJson(Map<String, dynamic> json) => $checkedCreate('CompletionDto', json, ($checkedConvert) {
  final val = CompletionDto(
    challenge: $checkedConvert('challenge', (v) => (v as List<dynamic>).map((e) => SpanDto.fromJson(e as Map<String, dynamic>)).toList()),
    reviewTopics: $checkedConvert(
      'review_topics',
      (v) => (v as List<dynamic>).map((e) => ReviewTopicDto.fromJson(e as Map<String, dynamic>)).toList(),
    ),
    checkIn: $checkedConvert('check_in', (v) => (v as List<dynamic>).map((e) => SpanDto.fromJson(e as Map<String, dynamic>)).toList()),
  );
  return val;
}, fieldKeyMap: const {'reviewTopics': 'review_topics', 'checkIn': 'check_in'});

SessionDto _$SessionDtoFromJson(Map<String, dynamic> json) => $checkedCreate(
  'SessionDto',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const ['mode', 'unit_id', 'lesson_id', 'lesson_version', 'subtitle', 'lesson_type', 'reviewed_by', 'completion'],
    );
    final val = SessionDto(
      sessionId: $checkedConvert('session_id', (v) => v as String),
      kind: $checkedConvert('kind', (v) => v as String),
      mode: $checkedConvert('mode', (v) => v as String?),
      status: $checkedConvert('status', (v) => v as String),
      feedbackMode: $checkedConvert('feedback_mode', (v) => v as String),
      unitId: $checkedConvert('unit_id', (v) => v as String?),
      lessonId: $checkedConvert('lesson_id', (v) => v as String?),
      lessonVersion: $checkedConvert('lesson_version', (v) => (v as num?)?.toInt()),
      title: $checkedConvert('title', (v) => v as String),
      subtitle: $checkedConvert('subtitle', (v) => v as String?),
      lessonType: $checkedConvert('lesson_type', (v) => v as String?),
      reviewedBy: $checkedConvert('reviewed_by', (v) => v as String?),
      objectives: $checkedConvert(
        'objectives',
        (v) =>
            (v as List<dynamic>).map((e) => (e as List<dynamic>).map((e) => SpanDto.fromJson(e as Map<String, dynamic>)).toList()).toList(),
      ),
      counts: $checkedConvert('counts', (v) => CountsDto.fromJson(v as Map<String, dynamic>)),
      sourceCount: $checkedConvert('source_count', (v) => (v as num).toInt()),
      totalExercises: $checkedConvert('total_exercises', (v) => (v as num).toInt()),
      answeredExercises: $checkedConvert('answered_exercises', (v) => (v as num).toInt()),
      startedAt: $checkedConvert('started_at', (v) => v as String),
      answers: $checkedConvert(
        'answers',
        (v) => (v as List<dynamic>).map((e) => RecordedAnswerDto.fromJson(e as Map<String, dynamic>)).toList(),
      ),
      items: $checkedConvert('items', (v) => (v as List<dynamic>).map((e) => BlockDto.fromJson(e as Map<String, dynamic>)).toList()),
      completion: $checkedConvert('completion', (v) => v == null ? null : CompletionDto.fromJson(v as Map<String, dynamic>)),
      sources: $checkedConvert('sources', (v) => (v as List<dynamic>).map((e) => SourceDto.fromJson(e as Map<String, dynamic>)).toList()),
      terms: $checkedConvert(
        'terms',
        (v) => (v as Map<String, dynamic>).map((k, e) => MapEntry(k, TermCardDto.fromJson(e as Map<String, dynamic>))),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'sessionId': 'session_id',
    'feedbackMode': 'feedback_mode',
    'unitId': 'unit_id',
    'lessonId': 'lesson_id',
    'lessonVersion': 'lesson_version',
    'lessonType': 'lesson_type',
    'reviewedBy': 'reviewed_by',
    'sourceCount': 'source_count',
    'totalExercises': 'total_exercises',
    'answeredExercises': 'answered_exercises',
    'startedAt': 'started_at',
  },
);

HookDto _$HookDtoFromJson(Map<String, dynamic> json) => $checkedCreate('HookDto', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['cta']);
  final val = HookDto(
    blockId: $checkedConvert('block_id', (v) => v as String),
    situation: $checkedConvert('situation', (v) => (v as List<dynamic>).map((e) => SpanDto.fromJson(e as Map<String, dynamic>)).toList()),
    question: $checkedConvert('question', (v) => (v as List<dynamic>).map((e) => SpanDto.fromJson(e as Map<String, dynamic>)).toList()),
    visual: $checkedConvert('visual', (v) => VisualDto.fromJson(v as Map<String, dynamic>)),
    cta: $checkedConvert('cta', (v) => v as String?),
  );
  return val;
}, fieldKeyMap: const {'blockId': 'block_id'});

PredictOptionDto _$PredictOptionDtoFromJson(Map<String, dynamic> json) => $checkedCreate('PredictOptionDto', json, ($checkedConvert) {
  final val = PredictOptionDto(
    optionId: $checkedConvert('option_id', (v) => v as String),
    spans: $checkedConvert('spans', (v) => (v as List<dynamic>).map((e) => SpanDto.fromJson(e as Map<String, dynamic>)).toList()),
  );
  return val;
}, fieldKeyMap: const {'optionId': 'option_id'});

PredictDto _$PredictDtoFromJson(Map<String, dynamic> json) => $checkedCreate('PredictDto', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['visual']);
  final val = PredictDto(
    blockId: $checkedConvert('block_id', (v) => v as String),
    prompt: $checkedConvert('prompt', (v) => (v as List<dynamic>).map((e) => SpanDto.fromJson(e as Map<String, dynamic>)).toList()),
    options: $checkedConvert(
      'options',
      (v) => (v as List<dynamic>).map((e) => PredictOptionDto.fromJson(e as Map<String, dynamic>)).toList(),
    ),
    reveal: $checkedConvert('reveal', (v) => (v as List<dynamic>).map((e) => SpanDto.fromJson(e as Map<String, dynamic>)).toList()),
    visual: $checkedConvert('visual', (v) => v == null ? null : VisualDto.fromJson(v as Map<String, dynamic>)),
  );
  return val;
}, fieldKeyMap: const {'blockId': 'block_id'});

ProvenanceDto _$ProvenanceDtoFromJson(Map<String, dynamic> json) => $checkedCreate('ProvenanceDto', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['grade_label']);
  final val = ProvenanceDto(
    sourceId: $checkedConvert('source_id', (v) => v as String),
    provider: $checkedConvert('provider', (v) => v as String),
    reference: $checkedConvert('reference', (v) => v as String),
    gradeLabel: $checkedConvert('grade_label', (v) => v as String?),
  );
  return val;
}, fieldKeyMap: const {'sourceId': 'source_id', 'gradeLabel': 'grade_label'});

OriginDto _$OriginDtoFromJson(Map<String, dynamic> json) => $checkedCreate('OriginDto', json, ($checkedConvert) {
  final val = OriginDto(
    title: $checkedConvert('title', (v) => v as String),
    sourceIds: $checkedConvert('source_ids', (v) => (v as List<dynamic>).map((e) => e as String).toList()),
    showCard: $checkedConvert('show_card', (v) => v as bool),
  );
  return val;
}, fieldKeyMap: const {'sourceIds': 'source_ids', 'showCard': 'show_card'});

BeatDto _$BeatDtoFromJson(Map<String, dynamic> json) => $checkedCreate(
  'BeatDto',
  json,
  ($checkedConvert) {
    $checkKeys(json, requiredKeys: const ['narration_audio_url', 'quote', 'quote_meaning']);
    final val = BeatDto(
      beatId: $checkedConvert('beat_id', (v) => v as String),
      beatIndex: $checkedConvert('beat_index', (v) => (v as num).toInt()),
      narration: $checkedConvert(
        'narration',
        (v) => (v as List<dynamic>).map((e) => SentenceDto.fromJson(e as Map<String, dynamic>)).toList(),
      ),
      narrationAudioUrl: $checkedConvert('narration_audio_url', (v) => v as String?),
      quote: $checkedConvert('quote', (v) => v == null ? null : EvidenceDto.fromJson(v as Map<String, dynamic>)),
      quoteMeaning: $checkedConvert(
        'quote_meaning',
        (v) => (v as List<dynamic>?)?.map((e) => SpanDto.fromJson(e as Map<String, dynamic>)).toList(),
      ),
      visual: $checkedConvert('visual', (v) => VisualDto.fromJson(v as Map<String, dynamic>)),
    );
    return val;
  },
  fieldKeyMap: const {
    'beatId': 'beat_id',
    'beatIndex': 'beat_index',
    'narrationAudioUrl': 'narration_audio_url',
    'quoteMeaning': 'quote_meaning',
  },
);

StoryDto _$StoryDtoFromJson(Map<String, dynamic> json) => $checkedCreate('StoryDto', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['title', 'provenance', 'origin']);
  final val = StoryDto(
    blockId: $checkedConvert('block_id', (v) => v as String),
    label: $checkedConvert('label', (v) => v as String),
    title: $checkedConvert('title', (v) => v as String?),
    provenance: $checkedConvert('provenance', (v) => v == null ? null : ProvenanceDto.fromJson(v as Map<String, dynamic>)),
    beats: $checkedConvert('beats', (v) => (v as List<dynamic>).map((e) => BeatDto.fromJson(e as Map<String, dynamic>)).toList()),
    origin: $checkedConvert('origin', (v) => v == null ? null : OriginDto.fromJson(v as Map<String, dynamic>)),
  );
  return val;
}, fieldKeyMap: const {'blockId': 'block_id'});

PointDto _$PointDtoFromJson(Map<String, dynamic> json) => $checkedCreate('PointDto', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['visual_params']);
  final val = PointDto(
    pointId: $checkedConvert('point_id', (v) => v as String),
    sentence: $checkedConvert('sentence', (v) => SentenceDto.fromJson(v as Map<String, dynamic>)),
    visualParams: $checkedConvert('visual_params', (v) => v as Map<String, dynamic>?),
  );
  return val;
}, fieldKeyMap: const {'pointId': 'point_id', 'visualParams': 'visual_params'});

TeachDto _$TeachDtoFromJson(Map<String, dynamic> json) => $checkedCreate('TeachDto', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['eyebrow', 'visual', 'evidence']);
  final val = TeachDto(
    blockId: $checkedConvert('block_id', (v) => v as String),
    eyebrow: $checkedConvert('eyebrow', (v) => v as String?),
    title: $checkedConvert('title', (v) => (v as List<dynamic>).map((e) => SpanDto.fromJson(e as Map<String, dynamic>)).toList()),
    style: $checkedConvert('style', (v) => v as String),
    visual: $checkedConvert('visual', (v) => v == null ? null : VisualDto.fromJson(v as Map<String, dynamic>)),
    evidence: $checkedConvert('evidence', (v) => v == null ? null : EvidenceDto.fromJson(v as Map<String, dynamic>)),
    points: $checkedConvert('points', (v) => (v as List<dynamic>).map((e) => PointDto.fromJson(e as Map<String, dynamic>)).toList()),
  );
  return val;
}, fieldKeyMap: const {'blockId': 'block_id'});

ParagraphDto _$ParagraphDtoFromJson(Map<String, dynamic> json) => $checkedCreate('ParagraphDto', json, ($checkedConvert) {
  final val = ParagraphDto(
    blockId: $checkedConvert('block_id', (v) => v as String),
    sentences: $checkedConvert(
      'sentences',
      (v) => (v as List<dynamic>).map((e) => SentenceDto.fromJson(e as Map<String, dynamic>)).toList(),
    ),
  );
  return val;
}, fieldKeyMap: const {'blockId': 'block_id'});

EvidenceBlockDto _$EvidenceBlockDtoFromJson(Map<String, dynamic> json) => $checkedCreate('EvidenceBlockDto', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['caption']);
  final val = EvidenceBlockDto(
    blockId: $checkedConvert('block_id', (v) => v as String),
    evidence: $checkedConvert('evidence', (v) => EvidenceDto.fromJson(v as Map<String, dynamic>)),
    caption: $checkedConvert('caption', (v) => (v as List<dynamic>?)?.map((e) => SpanDto.fromJson(e as Map<String, dynamic>)).toList()),
  );
  return val;
}, fieldKeyMap: const {'blockId': 'block_id'});

VisualBlockDto _$VisualBlockDtoFromJson(Map<String, dynamic> json) => $checkedCreate('VisualBlockDto', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['caption']);
  final val = VisualBlockDto(
    blockId: $checkedConvert('block_id', (v) => v as String),
    visual: $checkedConvert('visual', (v) => VisualDto.fromJson(v as Map<String, dynamic>)),
    caption: $checkedConvert('caption', (v) => (v as List<dynamic>?)?.map((e) => SpanDto.fromJson(e as Map<String, dynamic>)).toList()),
  );
  return val;
}, fieldKeyMap: const {'blockId': 'block_id'});

CalloutDto _$CalloutDtoFromJson(Map<String, dynamic> json) => $checkedCreate('CalloutDto', json, ($checkedConvert) {
  final val = CalloutDto(
    blockId: $checkedConvert('block_id', (v) => v as String),
    variant: $checkedConvert('variant', (v) => v as String),
    spans: $checkedConvert('spans', (v) => (v as List<dynamic>).map((e) => SpanDto.fromJson(e as Map<String, dynamic>)).toList()),
  );
  return val;
}, fieldKeyMap: const {'blockId': 'block_id'});

ExerciseHeaderDto _$ExerciseHeaderDtoFromJson(Map<String, dynamic> json) => $checkedCreate('ExerciseHeaderDto', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['time_limit_ms', 'framing']);
  final val = ExerciseHeaderDto(
    exerciseId: $checkedConvert('exercise_id', (v) => v as String),
    type: $checkedConvert('type', (v) => v as String),
    prompt: $checkedConvert('prompt', (v) => (v as List<dynamic>).map((e) => SpanDto.fromJson(e as Map<String, dynamic>)).toList()),
    conceptIds: $checkedConvert('concept_ids', (v) => (v as List<dynamic>).map((e) => e as String).toList()),
    timeLimitMs: $checkedConvert('time_limit_ms', (v) => (v as num?)?.toInt()),
    scoring: $checkedConvert('scoring', (v) => ScoringDto.fromJson(v as Map<String, dynamic>)),
    framing: $checkedConvert('framing', (v) => v == null ? null : FramingDto.fromJson(v as Map<String, dynamic>)),
    payload: $checkedConvert('payload', (v) => v as Map<String, dynamic>),
  );
  return val;
}, fieldKeyMap: const {'exerciseId': 'exercise_id', 'conceptIds': 'concept_ids', 'timeLimitMs': 'time_limit_ms'});

ExerciseBlockDto _$ExerciseBlockDtoFromJson(Map<String, dynamic> json) => $checkedCreate('ExerciseBlockDto', json, ($checkedConvert) {
  final val = ExerciseBlockDto(
    blockId: $checkedConvert('block_id', (v) => v as String),
    exercise: $checkedConvert('exercise', (v) => ExerciseHeaderDto.fromJson(v as Map<String, dynamic>)),
  );
  return val;
}, fieldKeyMap: const {'blockId': 'block_id'});

SessionCreateDto _$SessionCreateDtoFromJson(Map<String, dynamic> json) => $checkedCreate('SessionCreateDto', json, ($checkedConvert) {
  final val = SessionCreateDto(
    lessonId: $checkedConvert('lesson_id', (v) => v as String?),
    kind: $checkedConvert('kind', (v) => v as String? ?? 'lesson'),
    unitId: $checkedConvert('unit_id', (v) => v as String?),
    mode: $checkedConvert('mode', (v) => v as String?),
  );
  return val;
}, fieldKeyMap: const {'lessonId': 'lesson_id', 'unitId': 'unit_id'});

Map<String, dynamic> _$SessionCreateDtoToJson(SessionCreateDto instance) => <String, dynamic>{
  'kind': instance.kind,
  'lesson_id': instance.lessonId,
  'unit_id': instance.unitId,
  'mode': instance.mode,
};

LessonReaderDto _$LessonReaderDtoFromJson(Map<String, dynamic> json) => $checkedCreate(
  'LessonReaderDto',
  json,
  ($checkedConvert) {
    $checkKeys(json, requiredKeys: const ['subtitle', 'reviewed_by', 'completion']);
    final val = LessonReaderDto(
      lessonId: $checkedConvert('lesson_id', (v) => v as String),
      unitId: $checkedConvert('unit_id', (v) => v as String),
      title: $checkedConvert('title', (v) => v as String),
      subtitle: $checkedConvert('subtitle', (v) => v as String?),
      lessonType: $checkedConvert('lesson_type', (v) => v as String),
      reviewedBy: $checkedConvert('reviewed_by', (v) => v as String?),
      version: $checkedConvert('version', (v) => (v as num).toInt()),
      sourceCount: $checkedConvert('source_count', (v) => (v as num).toInt()),
      objectives: $checkedConvert(
        'objectives',
        (v) =>
            (v as List<dynamic>).map((e) => (e as List<dynamic>).map((e) => SpanDto.fromJson(e as Map<String, dynamic>)).toList()).toList(),
      ),
      blocks: $checkedConvert('blocks', (v) => (v as List<dynamic>).map((e) => BlockDto.fromJson(e as Map<String, dynamic>)).toList()),
      completion: $checkedConvert('completion', (v) => v == null ? null : CompletionDto.fromJson(v as Map<String, dynamic>)),
      sources: $checkedConvert('sources', (v) => (v as List<dynamic>).map((e) => SourceDto.fromJson(e as Map<String, dynamic>)).toList()),
      terms: $checkedConvert(
        'terms',
        (v) => (v as Map<String, dynamic>).map((k, e) => MapEntry(k, TermCardDto.fromJson(e as Map<String, dynamic>))),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'lessonId': 'lesson_id',
    'unitId': 'unit_id',
    'lessonType': 'lesson_type',
    'reviewedBy': 'reviewed_by',
    'sourceCount': 'source_count',
  },
);
