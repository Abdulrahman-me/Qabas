import 'package:json_annotation/json_annotation.dart';
import 'package:qabas/shared/data/dtos/content_dto.dart';
import 'package:qabas/shared/data/dtos/next_step_dto.dart';
import 'package:qabas/shared/data/dtos/stats_dto.dart';
part 'exercise_dto.g.dart';

@JsonSerializable()
final class ExerciseOptionDto {
  const ExerciseOptionDto({required this.optionId, required this.spans});
  factory ExerciseOptionDto.fromJson(Map<String, dynamic> json) => _$ExerciseOptionDtoFromJson(json);
  final String optionId;
  final List<SpanDto> spans;
}

@JsonSerializable()
final class ExerciseItemDto {
  const ExerciseItemDto({required this.itemId, required this.spans});
  factory ExerciseItemDto.fromJson(Map<String, dynamic> json) => _$ExerciseItemDtoFromJson(json);
  final String itemId;
  final List<SpanDto> spans;
}

@JsonSerializable()
final class ChoicePayloadDto {
  const ChoicePayloadDto({required this.options});
  factory ChoicePayloadDto.fromJson(Map<String, dynamic> json) => _$ChoicePayloadDtoFromJson(json);
  final List<ExerciseOptionDto> options;
}

@JsonSerializable()
final class ScenarioPayloadDto {
  const ScenarioPayloadDto({required this.situation, required this.options});
  factory ScenarioPayloadDto.fromJson(Map<String, dynamic> json) => _$ScenarioPayloadDtoFromJson(json);
  final List<SpanDto> situation;
  final List<ExerciseOptionDto> options;
}

@JsonSerializable()
final class ReasonPayloadDto {
  const ReasonPayloadDto({required this.statement, required this.reasons});
  factory ReasonPayloadDto.fromJson(Map<String, dynamic> json) => _$ReasonPayloadDtoFromJson(json);
  final List<SpanDto> statement;
  final List<ExerciseOptionDto> reasons;
}

@JsonSerializable()
final class PairsPayloadDto {
  const PairsPayloadDto({required this.left, required this.right});
  factory PairsPayloadDto.fromJson(Map<String, dynamic> json) => _$PairsPayloadDtoFromJson(json);
  final List<ExerciseItemDto> left;
  final List<ExerciseItemDto> right;
}

@JsonSerializable()
final class CategoryDto {
  const CategoryDto({required this.categoryId, required this.label, required this.artKey, required this.phase, required this.capacity});
  factory CategoryDto.fromJson(Map<String, dynamic> json) => _$CategoryDtoFromJson(json);
  final String categoryId;
  final String label;
  @JsonKey(required: true)
  final String? artKey;
  @JsonKey(required: true)
  final String? phase;
  @JsonKey(required: true)
  final int? capacity;
}

@JsonSerializable()
final class CatItemDto {
  const CatItemDto({required this.itemId, required this.spans, required this.secondaryLabel});
  factory CatItemDto.fromJson(Map<String, dynamic> json) => _$CatItemDtoFromJson(json);
  final String itemId;
  final List<SpanDto> spans;
  @JsonKey(required: true)
  final String? secondaryLabel;
}

@JsonSerializable()
final class CategorizePayloadDto {
  const CategorizePayloadDto({required this.presentation, required this.categories, required this.items});
  factory CategorizePayloadDto.fromJson(Map<String, dynamic> json) => _$CategorizePayloadDtoFromJson(json);
  final String presentation;
  final List<CategoryDto> categories;
  final List<CatItemDto> items;
}

@JsonSerializable()
final class SegmentDto {
  const SegmentDto({required this.segmentId, required this.spans});
  factory SegmentDto.fromJson(Map<String, dynamic> json) => _$SegmentDtoFromJson(json);
  final String segmentId;
  final List<SpanDto> spans;
}

@JsonSerializable()
final class SegmentPayloadDto {
  const SegmentPayloadDto({required this.segments});
  factory SegmentPayloadDto.fromJson(Map<String, dynamic> json) => _$SegmentPayloadDtoFromJson(json);
  final List<SegmentDto> segments;
}

@JsonSerializable()
final class OrderStepDto {
  const OrderStepDto({required this.stepId, required this.spans, required this.secondaryLabel});
  factory OrderStepDto.fromJson(Map<String, dynamic> json) => _$OrderStepDtoFromJson(json);
  final String stepId;
  final List<SpanDto> spans;
  @JsonKey(required: true)
  final String? secondaryLabel;
}

@JsonSerializable()
final class OrderPayloadDto {
  const OrderPayloadDto({required this.presentation, required this.steps});
  factory OrderPayloadDto.fromJson(Map<String, dynamic> json) => _$OrderPayloadDtoFromJson(json);
  final String presentation;
  final List<OrderStepDto> steps;
}

@JsonSerializable()
final class PinDto {
  const PinDto({
    required this.pinId,
    required this.xPct,
    required this.yPct,
    required this.label,
    required this.radiusPct,
    required this.anchorId,
  });
  factory PinDto.fromJson(Map<String, dynamic> json) => _$PinDtoFromJson(json);
  final String pinId;
  final double xPct;
  final double yPct;
  @JsonKey(required: true)
  final String? label;
  @JsonKey(required: true)
  final double? radiusPct;
  @JsonKey(required: true)
  final String? anchorId;
}

@JsonSerializable()
final class BindingDto {
  const BindingDto({required this.pinId, required this.set});
  factory BindingDto.fromJson(Map<String, dynamic> json) => _$BindingDtoFromJson(json);
  final String pinId;
  final Map<String, dynamic> set;
}

@JsonSerializable()
final class AfterEvaluationDto {
  const AfterEvaluationDto({required this.correct, required this.incorrect});
  factory AfterEvaluationDto.fromJson(Map<String, dynamic> json) => _$AfterEvaluationDtoFromJson(json);
  @JsonKey(required: true)
  final Map<String, dynamic>? correct;
  @JsonKey(required: true)
  final Map<String, dynamic>? incorrect;
}

@JsonSerializable()
final class InteractionDto {
  const InteractionDto({required this.bindings, required this.resetOnDeselect, required this.afterEvaluation});
  factory InteractionDto.fromJson(Map<String, dynamic> json) => _$InteractionDtoFromJson(json);
  final List<BindingDto> bindings;
  final bool resetOnDeselect;
  @JsonKey(required: true)
  final AfterEvaluationDto? afterEvaluation;
}

@JsonSerializable()
final class MapPayloadDto {
  const MapPayloadDto({
    required this.presentation,
    required this.visual,
    required this.question,
    required this.pins,
    required this.interaction,
  });
  factory MapPayloadDto.fromJson(Map<String, dynamic> json) => _$MapPayloadDtoFromJson(json);
  final String presentation;
  final VisualDto visual;
  final List<SpanDto> question;
  final List<PinDto> pins;
  @JsonKey(required: true)
  final InteractionDto? interaction;
}

@JsonSerializable()
final class RecitePayloadDto {
  const RecitePayloadDto({
    required this.surah,
    required this.ayah,
    required this.wordStart,
    required this.wordEnd,
    required this.textUthmani,
    required this.audio,
    required this.transliteration,
    required this.meaning,
    required this.sourceId,
    required this.maxDurationMs,
    required this.skippable,
  });
  factory RecitePayloadDto.fromJson(Map<String, dynamic> json) => _$RecitePayloadDtoFromJson(json);
  final int surah;
  final int ayah;
  @JsonKey(required: true)
  final int? wordStart;
  @JsonKey(required: true)
  final int? wordEnd;
  final String textUthmani;
  final AudioDto audio;
  @JsonKey(required: true)
  final String? transliteration;
  @JsonKey(required: true)
  final List<SpanDto>? meaning;
  final String sourceId;
  final int maxDurationMs;
  final bool skippable;
}

@JsonSerializable()
final class ScoringDto {
  const ScoringDto({required this.accuracy, required this.combo, required this.layer});
  factory ScoringDto.fromJson(Map<String, dynamic> json) => _$ScoringDtoFromJson(json);
  final bool accuracy;
  final bool combo;
  @JsonKey(required: true)
  final String? layer;
}

@JsonSerializable()
final class FramingDto {
  const FramingDto({required this.kind, required this.statement});
  factory FramingDto.fromJson(Map<String, dynamic> json) => _$FramingDtoFromJson(json);
  final String kind;
  final List<SpanDto> statement;
}

@JsonSerializable()
final class MisconceptionDto {
  const MisconceptionDto({required this.misconceptionId, required this.title, required this.card, required this.sourceIds});
  factory MisconceptionDto.fromJson(Map<String, dynamic> json) => _$MisconceptionDtoFromJson(json);
  final String misconceptionId;
  final String title;
  final List<SpanDto> card;
  final List<String> sourceIds;
}

@JsonSerializable()
final class MasteryChangeDto {
  const MasteryChangeDto({required this.conceptId, required this.title, required this.before, required this.after});
  factory MasteryChangeDto.fromJson(Map<String, dynamic> json) => _$MasteryChangeDtoFromJson(json);
  final String conceptId;
  final String title;
  final double before;
  final double after;
}

@JsonSerializable()
final class TermChangeDto {
  const TermChangeDto({required this.termId, required this.state});
  factory TermChangeDto.fromJson(Map<String, dynamic> json) => _$TermChangeDtoFromJson(json);
  final String termId;
  final String state;
}

@JsonSerializable()
final class AnswerEvaluationDto {
  const AnswerEvaluationDto({
    required this.exerciseId,
    required this.recorded,
    required this.correct,
    required this.correctAnswer,
    required this.details,
    required this.explanation,
    required this.sourceIds,
    required this.misconception,
    required this.masteryChanges,
    required this.termChanges,
    required this.xpAwarded,
  });
  factory AnswerEvaluationDto.fromJson(Map<String, dynamic> json) => _$AnswerEvaluationDtoFromJson(json);
  final String exerciseId;
  final bool recorded;
  @JsonKey(required: true)
  final bool? correct;
  @JsonKey(required: true)
  final Map<String, dynamic>? correctAnswer;
  @JsonKey(required: true)
  final Map<String, dynamic>? details;
  final List<SpanDto> explanation;
  final List<String> sourceIds;
  @JsonKey(required: true)
  final MisconceptionDto? misconception;
  final List<MasteryChangeDto> masteryChanges;
  final List<TermChangeDto> termChanges;
  final int xpAwarded;
}

@JsonSerializable()
final class AnswerRecordedDto {
  const AnswerRecordedDto({required this.exerciseId, required this.recorded});
  factory AnswerRecordedDto.fromJson(Map<String, dynamic> json) => _$AnswerRecordedDtoFromJson(json);
  final String exerciseId;
  final bool recorded;
}

@JsonSerializable(createToJson: true)
final class AnswerSubmitDto {
  const AnswerSubmitDto({required this.exerciseId, required this.answer, required this.elapsedMs, required this.isRetry});
  factory AnswerSubmitDto.fromJson(Map<String, dynamic> json) => _$AnswerSubmitDtoFromJson(json);
  final String exerciseId;
  final Map<String, dynamic>? answer;
  final int elapsedMs;
  final bool isRetry;
  Map<String, dynamic> toJson() => _$AnswerSubmitDtoToJson(this);
}

@JsonSerializable(createToJson: true)
final class FinishRequestDto {
  const FinishRequestDto({required this.durationMs});
  factory FinishRequestDto.fromJson(Map<String, dynamic> json) => _$FinishRequestDtoFromJson(json);
  final int durationMs;
  Map<String, dynamic> toJson() => _$FinishRequestDtoToJson(this);
}

@JsonSerializable()
final class ResultScoreDto {
  const ResultScoreDto({required this.correct, required this.total, required this.percent});
  factory ResultScoreDto.fromJson(Map<String, dynamic> json) => _$ResultScoreDtoFromJson(json);
  final int correct;
  final int total;
  final int percent;
}

@JsonSerializable()
final class ResultXpDto {
  const ResultXpDto({required this.total, required this.breakdown});
  factory ResultXpDto.fromJson(Map<String, dynamic> json) => _$ResultXpDtoFromJson(json);
  final int total;
  final List<ResultXpGrantDto> breakdown;
}

@JsonSerializable()
final class SessionResultDto {
  const SessionResultDto({
    required this.sessionId,
    required this.kind,
    required this.score,
    required this.passed,
    required this.xp,
    required this.durationMs,
    required this.layers,
    required this.streak,
    required this.dailyGoal,
    required this.masterySummary,
    required this.termsMastered,
    required this.misconceptions,
    required this.unlocked,
    required this.nextStep,
    this.reviewItems,
  });
  factory SessionResultDto.fromJson(Map<String, dynamic> json) => _$SessionResultDtoFromJson(json);
  final String sessionId;
  final String kind;
  final ResultScoreDto score;
  @JsonKey(required: true)
  final bool? passed;
  final ResultXpDto xp;
  final int durationMs;
  final ResultLayersDto layers;
  final ResultStreakDto streak;
  final DailyGoalDto dailyGoal;
  final List<MasteryChangeDto> masterySummary;
  final List<ResultTermDto> termsMastered;
  final ResultMisconceptionsDto misconceptions;
  final List<ResultUnlockDto> unlocked;
  final NextStepDto nextStep;
  @JsonKey(required: true)
  final List<AnswerReviewDto>? reviewItems;
}

@JsonSerializable()
final class ResultXpGrantDto {
  const ResultXpGrantDto({required this.reason, required this.xp});
  factory ResultXpGrantDto.fromJson(Map<String, dynamic> json) => _$ResultXpGrantDtoFromJson(json);
  final String reason;
  final int xp;
}

@JsonSerializable()
final class ResultLayersDto {
  const ResultLayersDto({required this.understanding, required this.applying, required this.remembering});
  factory ResultLayersDto.fromJson(Map<String, dynamic> json) => _$ResultLayersDtoFromJson(json);
  @JsonKey(required: true)
  final ResultScoreDto? understanding;
  @JsonKey(required: true)
  final ResultScoreDto? applying;
  @JsonKey(required: true)
  final ResultScoreDto? remembering;
}

@JsonSerializable()
final class ResultStreakDto {
  const ResultStreakDto({required this.current, required this.extendedToday});
  factory ResultStreakDto.fromJson(Map<String, dynamic> json) => _$ResultStreakDtoFromJson(json);
  final int current;
  final bool extendedToday;
}

@JsonSerializable()
final class ResultTermDto {
  const ResultTermDto({required this.termId, required this.text});
  factory ResultTermDto.fromJson(Map<String, dynamic> json) => _$ResultTermDtoFromJson(json);
  final String termId, text;
}

@JsonSerializable()
final class ResultMisconceptionDto {
  const ResultMisconceptionDto({required this.misconceptionId, required this.title});
  factory ResultMisconceptionDto.fromJson(Map<String, dynamic> json) => _$ResultMisconceptionDtoFromJson(json);
  final String misconceptionId, title;
}

@JsonSerializable()
final class ResultMisconceptionsDto {
  const ResultMisconceptionsDto({required this.activated, required this.resolved});
  factory ResultMisconceptionsDto.fromJson(Map<String, dynamic> json) => _$ResultMisconceptionsDtoFromJson(json);
  final List<ResultMisconceptionDto> activated, resolved;
}

@JsonSerializable()
final class ResultUnlockDto {
  const ResultUnlockDto({required this.type, required this.id, required this.title});
  factory ResultUnlockDto.fromJson(Map<String, dynamic> json) => _$ResultUnlockDtoFromJson(json);
  final String type, id, title;
}

@JsonSerializable()
final class FlashcardPayloadDto {
  const FlashcardPayloadDto({required this.front, required this.back});
  factory FlashcardPayloadDto.fromJson(Map<String, dynamic> json) => _$FlashcardPayloadDtoFromJson(json);
  final List<SpanDto> front, back;
}

@JsonSerializable()
final class BlankSegmentDto {
  const BlankSegmentDto({required this.type, this.text, this.blankId});
  factory BlankSegmentDto.fromJson(Map<String, dynamic> json) => _$BlankSegmentDtoFromJson(json);
  final String type;
  final String? text, blankId;
}

@JsonSerializable()
final class BankWordDto {
  const BankWordDto({required this.wordId, required this.text});
  factory BankWordDto.fromJson(Map<String, dynamic> json) => _$BankWordDtoFromJson(json);
  final String wordId, text;
}

@JsonSerializable()
final class FillPayloadDto {
  const FillPayloadDto({required this.segments, required this.wordBank});
  factory FillPayloadDto.fromJson(Map<String, dynamic> json) => _$FillPayloadDtoFromJson(json);
  final List<BlankSegmentDto> segments;
  final List<BankWordDto> wordBank;
}

@JsonSerializable()
final class EvidenceOptionDto {
  const EvidenceOptionDto({required this.optionId, required this.evidence});
  factory EvidenceOptionDto.fromJson(Map<String, dynamic> json) => _$EvidenceOptionDtoFromJson(json);
  final String optionId;
  final EvidenceDto evidence;
}

@JsonSerializable()
final class EvidenceChoicePayloadDto {
  const EvidenceChoicePayloadDto({required this.claim, required this.options});
  factory EvidenceChoicePayloadDto.fromJson(Map<String, dynamic> json) => _$EvidenceChoicePayloadDtoFromJson(json);
  final List<SpanDto> claim;
  final List<EvidenceOptionDto> options;
}

@JsonSerializable()
final class VerseMeaningPayloadDto {
  const VerseMeaningPayloadDto({required this.verse, required this.options});
  factory VerseMeaningPayloadDto.fromJson(Map<String, dynamic> json) => _$VerseMeaningPayloadDtoFromJson(json);
  final EvidenceDto verse;
  final List<ExerciseOptionDto> options;
}

@JsonSerializable()
final class TimelineEventDto {
  const TimelineEventDto({required this.eventId, required this.spans});
  factory TimelineEventDto.fromJson(Map<String, dynamic> json) => _$TimelineEventDtoFromJson(json);
  final String eventId;
  final List<SpanDto> spans;
}

@JsonSerializable()
final class TimelinePayloadDto {
  const TimelinePayloadDto({required this.events});
  factory TimelinePayloadDto.fromJson(Map<String, dynamic> json) => _$TimelinePayloadDtoFromJson(json);
  final List<TimelineEventDto> events;
}

@JsonSerializable()
final class AnswerReviewDto {
  const AnswerReviewDto({
    required this.exerciseId,
    required this.correct,
    required this.correctAnswer,
    required this.explanation,
    required this.sourceIds,
  });
  factory AnswerReviewDto.fromJson(Map<String, dynamic> json) => _$AnswerReviewDtoFromJson(json);
  final String exerciseId;
  @JsonKey(required: true)
  final bool? correct;
  @JsonKey(required: true)
  final Map<String, dynamic>? correctAnswer;
  final List<SpanDto> explanation;
  final List<String> sourceIds;
}
