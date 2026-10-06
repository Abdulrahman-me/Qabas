import 'package:json_annotation/json_annotation.dart';
import 'package:qabas/shared/data/dtos/content_dto.dart';
import 'package:qabas/shared/lesson/data/dtos/exercise_dto.dart';

part 'session_dto.g.dart';

sealed class BlockDto {
  const BlockDto();
  factory BlockDto.fromJson(Map<String, dynamic> json) => switch (json['type']) {
    'hook' => HookDto.fromJson(json),
    'predict' => PredictDto.fromJson(json),
    'story' => StoryDto.fromJson(json),
    'teach' => TeachDto.fromJson(json),
    'paragraph' => ParagraphDto.fromJson(json),
    'evidence' => EvidenceBlockDto.fromJson(json),
    'visual' => VisualBlockDto.fromJson(json),
    'callout' => CalloutDto.fromJson(json),
    'exercise' => ExerciseBlockDto.fromJson(json),
    _ => UnknownBlockDto(json['block_id'] as String),
  };
}

final class UnknownBlockDto extends BlockDto {
  const UnknownBlockDto(this.blockId);
  final String blockId;
}

@JsonSerializable()
final class CountsDto {
  const CountsDto({required this.interactions, required this.exercises, required this.scored});
  factory CountsDto.fromJson(Map<String, dynamic> json) => _$CountsDtoFromJson(json);
  final int interactions;
  final int exercises;
  final int scored;
}

@JsonSerializable()
final class RecordedAnswerDto {
  const RecordedAnswerDto({
    required this.exerciseId,
    required this.isRetry,
    required this.result,
    required this.recordedAt,
    this.evaluation,
  });
  factory RecordedAnswerDto.fromJson(Map<String, dynamic> json) => _$RecordedAnswerDtoFromJson(json);
  final String exerciseId;
  final bool isRetry;
  final String result;
  final String recordedAt;
  final Map<String, dynamic>? evaluation;
}

@JsonSerializable()
final class ReviewTopicDto {
  const ReviewTopicDto({required this.topicId, required this.title, required this.conceptIds});
  factory ReviewTopicDto.fromJson(Map<String, dynamic> json) => _$ReviewTopicDtoFromJson(json);
  final String topicId;
  final String title;
  final List<String> conceptIds;
}

@JsonSerializable()
final class CompletionDto {
  const CompletionDto({required this.challenge, required this.reviewTopics, required this.checkIn});
  factory CompletionDto.fromJson(Map<String, dynamic> json) => _$CompletionDtoFromJson(json);
  final List<SpanDto> challenge;
  final List<ReviewTopicDto> reviewTopics;
  final List<SpanDto> checkIn;
}

@JsonSerializable()
final class SessionDto {
  const SessionDto({
    required this.sessionId,
    required this.kind,
    required this.mode,
    required this.status,
    required this.feedbackMode,
    required this.unitId,
    required this.lessonId,
    required this.lessonVersion,
    required this.title,
    required this.subtitle,
    required this.lessonType,
    required this.reviewedBy,
    required this.objectives,
    required this.counts,
    required this.sourceCount,
    required this.totalExercises,
    required this.answeredExercises,
    required this.startedAt,
    required this.answers,
    required this.items,
    required this.completion,
    required this.sources,
    required this.terms,
  });
  factory SessionDto.fromJson(Map<String, dynamic> json) => _$SessionDtoFromJson(json);
  final String sessionId;
  final String kind;
  @JsonKey(required: true)
  final String? mode;
  final String status;
  final String feedbackMode;
  @JsonKey(required: true)
  final String? unitId;
  @JsonKey(required: true)
  final String? lessonId;
  @JsonKey(required: true)
  final int? lessonVersion;
  final String title;
  @JsonKey(required: true)
  final String? subtitle;
  @JsonKey(required: true)
  final String? lessonType;
  @JsonKey(required: true)
  final String? reviewedBy;
  final List<List<SpanDto>> objectives;
  final CountsDto counts;
  final int sourceCount;
  final int totalExercises;
  final int answeredExercises;
  final String startedAt;
  final List<RecordedAnswerDto> answers;
  final List<BlockDto> items;
  @JsonKey(required: true)
  final CompletionDto? completion;
  final List<SourceDto> sources;
  final Map<String, TermCardDto> terms;
}

@JsonSerializable()
final class HookDto extends BlockDto {
  const HookDto({required this.blockId, required this.situation, required this.question, required this.visual, required this.cta});
  factory HookDto.fromJson(Map<String, dynamic> json) => _$HookDtoFromJson(json);
  final String blockId;
  final List<SpanDto> situation;
  final List<SpanDto> question;
  final VisualDto visual;
  @JsonKey(required: true)
  final String? cta;
}

@JsonSerializable()
final class PredictOptionDto {
  const PredictOptionDto({required this.optionId, required this.spans});
  factory PredictOptionDto.fromJson(Map<String, dynamic> json) => _$PredictOptionDtoFromJson(json);
  final String optionId;
  final List<SpanDto> spans;
}

@JsonSerializable()
final class PredictDto extends BlockDto {
  const PredictDto({required this.blockId, required this.prompt, required this.options, required this.reveal, required this.visual});
  factory PredictDto.fromJson(Map<String, dynamic> json) => _$PredictDtoFromJson(json);
  final String blockId;
  final List<SpanDto> prompt;
  final List<PredictOptionDto> options;
  final List<SpanDto> reveal;
  @JsonKey(required: true)
  final VisualDto? visual;
}

@JsonSerializable()
final class ProvenanceDto {
  const ProvenanceDto({required this.sourceId, required this.provider, required this.reference, required this.gradeLabel});
  factory ProvenanceDto.fromJson(Map<String, dynamic> json) => _$ProvenanceDtoFromJson(json);
  final String sourceId;
  final String provider;
  final String reference;
  @JsonKey(required: true)
  final String? gradeLabel;
}

@JsonSerializable()
final class OriginDto {
  const OriginDto({required this.title, required this.sourceIds, required this.showCard});
  factory OriginDto.fromJson(Map<String, dynamic> json) => _$OriginDtoFromJson(json);
  final String title;
  final List<String> sourceIds;
  final bool showCard;
}

@JsonSerializable()
final class BeatDto {
  const BeatDto({
    required this.beatId,
    required this.beatIndex,
    required this.narration,
    required this.narrationAudioUrl,
    required this.quote,
    required this.quoteMeaning,
    required this.visual,
  });
  factory BeatDto.fromJson(Map<String, dynamic> json) => _$BeatDtoFromJson(json);
  final String beatId;
  final int beatIndex;
  final List<SentenceDto> narration;
  @JsonKey(required: true)
  final String? narrationAudioUrl;
  @JsonKey(required: true)
  final EvidenceDto? quote;
  @JsonKey(required: true)
  final List<SpanDto>? quoteMeaning;
  final VisualDto visual;
}

@JsonSerializable()
final class StoryDto extends BlockDto {
  const StoryDto({
    required this.blockId,
    required this.label,
    required this.title,
    required this.provenance,
    required this.beats,
    required this.origin,
  });
  factory StoryDto.fromJson(Map<String, dynamic> json) => _$StoryDtoFromJson(json);
  final String blockId;
  final String label;
  @JsonKey(required: true)
  final String? title;
  @JsonKey(required: true)
  final ProvenanceDto? provenance;
  final List<BeatDto> beats;
  @JsonKey(required: true)
  final OriginDto? origin;
}

@JsonSerializable()
final class PointDto {
  const PointDto({required this.pointId, required this.sentence, required this.visualParams});
  factory PointDto.fromJson(Map<String, dynamic> json) => _$PointDtoFromJson(json);
  final String pointId;
  final SentenceDto sentence;
  @JsonKey(required: true)
  final Map<String, dynamic>? visualParams;
}

@JsonSerializable()
final class TeachDto extends BlockDto {
  const TeachDto({
    required this.blockId,
    required this.eyebrow,
    required this.title,
    required this.style,
    required this.visual,
    required this.evidence,
    required this.points,
  });
  factory TeachDto.fromJson(Map<String, dynamic> json) => _$TeachDtoFromJson(json);
  final String blockId;
  @JsonKey(required: true)
  final String? eyebrow;
  final List<SpanDto> title;
  final String style;
  @JsonKey(required: true)
  final VisualDto? visual;
  @JsonKey(required: true)
  final EvidenceDto? evidence;
  final List<PointDto> points;
}

@JsonSerializable()
final class ParagraphDto extends BlockDto {
  const ParagraphDto({required this.blockId, required this.sentences});
  factory ParagraphDto.fromJson(Map<String, dynamic> json) => _$ParagraphDtoFromJson(json);
  final String blockId;
  final List<SentenceDto> sentences;
}

@JsonSerializable()
final class EvidenceBlockDto extends BlockDto {
  const EvidenceBlockDto({required this.blockId, required this.evidence, required this.caption});
  factory EvidenceBlockDto.fromJson(Map<String, dynamic> json) => _$EvidenceBlockDtoFromJson(json);
  final String blockId;
  final EvidenceDto evidence;
  @JsonKey(required: true)
  final List<SpanDto>? caption;
}

@JsonSerializable()
final class VisualBlockDto extends BlockDto {
  const VisualBlockDto({required this.blockId, required this.visual, required this.caption});
  factory VisualBlockDto.fromJson(Map<String, dynamic> json) => _$VisualBlockDtoFromJson(json);
  final String blockId;
  final VisualDto visual;
  @JsonKey(required: true)
  final List<SpanDto>? caption;
}

@JsonSerializable()
final class CalloutDto extends BlockDto {
  const CalloutDto({required this.blockId, required this.variant, required this.spans});
  factory CalloutDto.fromJson(Map<String, dynamic> json) => _$CalloutDtoFromJson(json);
  final String blockId;
  final String variant;
  final List<SpanDto> spans;
}

@JsonSerializable()
final class ExerciseHeaderDto {
  const ExerciseHeaderDto({
    required this.exerciseId,
    required this.type,
    required this.prompt,
    required this.conceptIds,
    required this.timeLimitMs,
    required this.scoring,
    required this.framing,
    required this.payload,
  });
  factory ExerciseHeaderDto.fromJson(Map<String, dynamic> json) => _$ExerciseHeaderDtoFromJson(json);
  final String exerciseId;
  final String type;
  final List<SpanDto> prompt;
  final List<String> conceptIds;
  @JsonKey(required: true)
  final int? timeLimitMs;
  final ScoringDto scoring;
  @JsonKey(required: true)
  final FramingDto? framing;
  final Map<String, dynamic> payload;
}

@JsonSerializable()
final class ExerciseBlockDto extends BlockDto {
  const ExerciseBlockDto({required this.blockId, required this.exercise});
  factory ExerciseBlockDto.fromJson(Map<String, dynamic> json) => _$ExerciseBlockDtoFromJson(json);
  final String blockId;
  final ExerciseHeaderDto exercise;
}

@JsonSerializable(createToJson: true)
final class SessionCreateDto {
  const SessionCreateDto({required this.lessonId, this.kind = 'lesson', this.unitId, this.mode});
  factory SessionCreateDto.fromJson(Map<String, dynamic> json) => _$SessionCreateDtoFromJson(json);
  final String kind;
  final String? lessonId, unitId, mode;
  Map<String, dynamic> toJson() => _$SessionCreateDtoToJson(this);
}

@JsonSerializable()
final class LessonReaderDto {
  const LessonReaderDto({
    required this.lessonId,
    required this.unitId,
    required this.title,
    required this.subtitle,
    required this.lessonType,
    required this.reviewedBy,
    required this.version,
    required this.sourceCount,
    required this.objectives,
    required this.blocks,
    required this.completion,
    required this.sources,
    required this.terms,
  });
  factory LessonReaderDto.fromJson(Map<String, dynamic> json) => _$LessonReaderDtoFromJson(json);
  final String lessonId, unitId, title, lessonType;
  @JsonKey(required: true)
  final String? subtitle;
  @JsonKey(required: true)
  final String? reviewedBy;
  final int version, sourceCount;
  final List<List<SpanDto>> objectives;
  final List<BlockDto> blocks;
  @JsonKey(required: true)
  final CompletionDto? completion;
  final List<SourceDto> sources;
  final Map<String, TermCardDto> terms;
}
