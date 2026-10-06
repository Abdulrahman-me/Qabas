import 'package:json_annotation/json_annotation.dart';
import 'package:qabas/features/reviewer/domain/reviewer_models.dart';
import 'package:qabas/shared/data/dtos/content_dto.dart';
import 'package:qabas/shared/data/mappers/content_mappers.dart';
import 'package:qabas/shared/lesson/data/dtos/session_dto.dart';
import 'package:qabas/shared/lesson/data/mappers/exercise_mappers.dart';
import 'package:qabas/shared/lesson/data/mappers/session_mappers.dart';
import 'package:qabas/shared/lesson/domain/entities/session.dart';

part 'reviewer_dtos.g.dart';

@JsonSerializable()
final class ReviewAnimationPreviewDto {
  const ReviewAnimationPreviewDto({
    required this.url,
    required this.mimeType,
    required this.width,
    required this.height,
    required this.durationMs,
  });
  factory ReviewAnimationPreviewDto.fromJson(Map<String, dynamic> json) => _$ReviewAnimationPreviewDtoFromJson(json);
  final String url;
  final String mimeType;
  final int width;
  final int height;
  final int durationMs;
  ReviewAnimationPreview toEntity() =>
      ReviewAnimationPreview(url: url, mimeType: mimeType, width: width, height: height, durationMs: durationMs);
}

@JsonSerializable()
final class ReviewArcStepDto {
  const ReviewArcStepDto({required this.stepId, required this.technique, required this.experience, required this.interactive});
  factory ReviewArcStepDto.fromJson(Map<String, dynamic> json) => _$ReviewArcStepDtoFromJson(json);
  final String stepId;
  final String technique;
  final ReviewLocalizedTextDto experience;
  final bool interactive;
  ReviewArcStep toEntity() =>
      ReviewArcStep(stepId: stepId, technique: technique, experience: experience.toEntity(), interactive: interactive);
}

@JsonSerializable()
final class ReviewArcStepBlocksDto {
  const ReviewArcStepBlocksDto({required this.stepId, required this.blockIds});
  factory ReviewArcStepBlocksDto.fromJson(Map<String, dynamic> json) => _$ReviewArcStepBlocksDtoFromJson(json);
  final String stepId;
  final List<String> blockIds;
  ReviewArcStepBlocks toEntity() => ReviewArcStepBlocks(stepId: stepId, blockIds: blockIds.map((e) => e).toList());
}

@JsonSerializable()
final class ReviewBenchmarkClassDto {
  const ReviewBenchmarkClassDto({required this.questionClass, required this.raqeebAccuracyPercent, required this.baselineAccuracyPercent});
  factory ReviewBenchmarkClassDto.fromJson(Map<String, dynamic> json) => _$ReviewBenchmarkClassDtoFromJson(json);
  final String questionClass;
  final int raqeebAccuracyPercent;
  final int baselineAccuracyPercent;
  ReviewBenchmarkClass toEntity() => ReviewBenchmarkClass(
    questionClass: questionClass,
    raqeebAccuracyPercent: raqeebAccuracyPercent,
    baselineAccuracyPercent: baselineAccuracyPercent,
  );
}

@JsonSerializable()
final class ReviewBenchmarkMetricsDto {
  const ReviewBenchmarkMetricsDto({required this.runAt, required this.questionCount, required this.systems, required this.byClass});
  factory ReviewBenchmarkMetricsDto.fromJson(Map<String, dynamic> json) => _$ReviewBenchmarkMetricsDtoFromJson(json);
  final String runAt;
  final int questionCount;
  final List<ReviewBenchmarkSystemDto> systems;
  final List<ReviewBenchmarkClassDto> byClass;
  ReviewBenchmarkMetrics toEntity() => ReviewBenchmarkMetrics(
    runAt: runAt,
    questionCount: questionCount,
    systems: systems.map((e) => e.toEntity()).toList(),
    byClass: byClass.map((e) => e.toEntity()).toList(),
  );
}

@JsonSerializable()
final class ReviewBenchmarkSystemDto {
  const ReviewBenchmarkSystemDto({
    required this.name,
    required this.accuracyPercent,
    required this.unsupportedClaimRatePercent,
    required this.correctAbstentionPercent,
    required this.correctReferralPercent,
  });
  factory ReviewBenchmarkSystemDto.fromJson(Map<String, dynamic> json) => _$ReviewBenchmarkSystemDtoFromJson(json);
  final String name;
  final int accuracyPercent;
  final int unsupportedClaimRatePercent;
  final int correctAbstentionPercent;
  final int correctReferralPercent;
  ReviewBenchmarkSystem toEntity() => ReviewBenchmarkSystem(
    name: name,
    accuracyPercent: accuracyPercent,
    unsupportedClaimRatePercent: unsupportedClaimRatePercent,
    correctAbstentionPercent: correctAbstentionPercent,
    correctReferralPercent: correctReferralPercent,
  );
}

@JsonSerializable()
final class ReviewBlindAnswerDto {
  const ReviewBlindAnswerDto({required this.clearer, required this.moreAccurate, required this.guessedHandwritten});
  factory ReviewBlindAnswerDto.fromJson(Map<String, dynamic> json) => _$ReviewBlindAnswerDtoFromJson(json);
  final String clearer;
  final String moreAccurate;
  final String guessedHandwritten;
  ReviewBlindAnswer toEntity() => ReviewBlindAnswer(clearer: clearer, moreAccurate: moreAccurate, guessedHandwritten: guessedHandwritten);
}

@JsonSerializable()
final class ReviewBlindLessonDto {
  const ReviewBlindLessonDto({required this.title, required this.objectives, required this.items, required this.completion});
  factory ReviewBlindLessonDto.fromJson(Map<String, dynamic> json) => _$ReviewBlindLessonDtoFromJson(json);
  final String title;
  final List<List<SpanDto>> objectives;
  final List<BlockDto> items;
  final CompletionDto? completion;
  ReviewBlindLesson toEntity() => ReviewBlindLesson(
    title: title,
    objectives: objectives.map((e) => contentSpans(e)).toList(),
    items: items.map((e) => e.toEntity()).toList(),
    completion: completion?.reviewCompletion(),
  );
}

@JsonSerializable()
final class ReviewBlindMetricsDto {
  const ReviewBlindMetricsDto({
    required this.responses,
    required this.handwrittenIdentifiedPercent,
    required this.generatedPreferredOrSamePercent,
  });
  factory ReviewBlindMetricsDto.fromJson(Map<String, dynamic> json) => _$ReviewBlindMetricsDtoFromJson(json);
  final int responses;
  final int? handwrittenIdentifiedPercent;
  final int? generatedPreferredOrSamePercent;
  ReviewBlindMetrics toEntity() => ReviewBlindMetrics(
    responses: responses,
    handwrittenIdentifiedPercent: handwrittenIdentifiedPercent,
    generatedPreferredOrSamePercent: generatedPreferredOrSamePercent,
  );
}

@JsonSerializable()
final class ReviewBlindPairDto {
  const ReviewBlindPairDto({required this.pairId, required this.lessonA, required this.lessonB});
  factory ReviewBlindPairDto.fromJson(Map<String, dynamic> json) => _$ReviewBlindPairDtoFromJson(json);
  final String pairId;
  final ReviewBlindLessonDto lessonA;
  final ReviewBlindLessonDto lessonB;
  ReviewBlindPair toEntity() => ReviewBlindPair(pairId: pairId, lessonA: lessonA.toEntity(), lessonB: lessonB.toEntity());
}

@JsonSerializable()
final class ReviewClaimDto {
  const ReviewClaimDto({
    required this.claimId,
    required this.text,
    required this.status,
    required this.basis,
    required this.evidence,
    required this.reasoning,
  });
  factory ReviewClaimDto.fromJson(Map<String, dynamic> json) => _$ReviewClaimDtoFromJson(json);
  final String claimId;
  final String text;
  final String status;
  final String basis;
  final List<ReviewClaimEvidenceDto> evidence;
  final ReviewReasoningSupportDto? reasoning;
  ReviewClaim toEntity() => ReviewClaim(
    claimId: claimId,
    text: text,
    status: status,
    basis: basis,
    evidence: evidence.map((e) => e.toEntity()).toList(),
    reasoning: reasoning?.toEntity(),
  );
}

@JsonSerializable()
final class ReviewClaimEvidenceDto {
  const ReviewClaimEvidenceDto({required this.source, required this.supports, required this.verifierNote, required this.semanticReview});
  factory ReviewClaimEvidenceDto.fromJson(Map<String, dynamic> json) => _$ReviewClaimEvidenceDtoFromJson(json);
  final SourceDto source;
  final bool supports;
  final String verifierNote;
  final ReviewSemanticReviewDto? semanticReview;
  ReviewClaimEvidence toEntity() => ReviewClaimEvidence(
    source: source.toEntity(),
    supports: supports,
    verifierNote: verifierNote,
    semanticReview: semanticReview?.toEntity(),
  );
}

@JsonSerializable()
final class ReviewCompletionMetricsDto {
  const ReviewCompletionMetricsDto({required this.unitsStarted, required this.unitsCompleted});
  factory ReviewCompletionMetricsDto.fromJson(Map<String, dynamic> json) => _$ReviewCompletionMetricsDtoFromJson(json);
  final int unitsStarted;
  final int unitsCompleted;
  ReviewCompletionMetrics toEntity() => ReviewCompletionMetrics(unitsStarted: unitsStarted, unitsCompleted: unitsCompleted);
}

@JsonSerializable()
final class ReviewDraftDto {
  const ReviewDraftDto({
    required this.languages,
    required this.variants,
    required this.previews,
    required this.claims,
    required this.sentenceMap,
    required this.arcMap,
    required this.exercises,
    required this.glossary,
    required this.misconceptions,
    required this.visuals,
  });
  factory ReviewDraftDto.fromJson(Map<String, dynamic> json) => _$ReviewDraftDtoFromJson(json);
  final List<String> languages;
  final List<String> variants;
  final List<ReviewPreviewDto> previews;
  final List<ReviewClaimDto> claims;
  final List<ReviewSentenceClaimsDto> sentenceMap;
  final List<ReviewArcStepBlocksDto> arcMap;
  final List<ReviewReviewerExerciseDto> exercises;
  final List<ReviewStoredGlossaryTermDto> glossary;
  final List<ReviewMisconceptionDto> misconceptions;
  final List<ReviewDraftVisualDto> visuals;
  ReviewDraft toEntity() => ReviewDraft(
    languages: languages.map((e) => e).toList(),
    variants: variants.map((e) => e).toList(),
    previews: previews.map((e) => e.toEntity()).toList(),
    claims: claims.map((e) => e.toEntity()).toList(),
    sentenceMap: sentenceMap.map((e) => e.toEntity()).toList(),
    arcMap: arcMap.map((e) => e.toEntity()).toList(),
    exercises: exercises.map((e) => e.toEntity()).toList(),
    glossary: glossary.map((e) => e.toEntity()).toList(),
    misconceptions: misconceptions.map((e) => e.toEntity()).toList(),
    visuals: visuals.map((e) => e.toEntity()).toList(),
  );
}

@JsonSerializable()
final class ReviewDraftFragmentDto {
  const ReviewDraftFragmentDto({required this.draft, required this.qaReport});
  factory ReviewDraftFragmentDto.fromJson(Map<String, dynamic> json) => _$ReviewDraftFragmentDtoFromJson(json);
  final ReviewDraftDto draft;
  final ReviewQAReportDto qaReport;
  ReviewDraftFragment toEntity() => ReviewDraftFragment(draft: draft.toEntity(), qaReport: qaReport.toEntity());
}

@JsonSerializable()
final class ReviewDraftVisualDto {
  const ReviewDraftVisualDto({
    required this.sceneId,
    required this.origin,
    required this.visual,
    required this.audit,
    required this.attempts,
    required this.previews,
  });
  factory ReviewDraftVisualDto.fromJson(Map<String, dynamic> json) => _$ReviewDraftVisualDtoFromJson(json);
  final String sceneId;
  final String origin;
  final VisualDto visual;
  final ReviewVisualAuditDto? audit;
  final int attempts;
  final ReviewScenePreviewDto? previews;
  ReviewDraftVisual toEntity() => ReviewDraftVisual(
    sceneId: sceneId,
    origin: origin,
    visual: visual.toEntity(),
    audit: audit?.toEntity(),
    attempts: attempts,
    previews: previews?.toEntity(),
  );
}

@JsonSerializable()
final class ReviewFactoryMetricsDto {
  const ReviewFactoryMetricsDto({
    required this.lessonsPublished,
    required this.avgGenerationMinutes,
    required this.avgReviewMinutes,
    required this.blindTest,
  });
  factory ReviewFactoryMetricsDto.fromJson(Map<String, dynamic> json) => _$ReviewFactoryMetricsDtoFromJson(json);
  final int lessonsPublished;
  final int? avgGenerationMinutes;
  final int? avgReviewMinutes;
  final ReviewBlindMetricsDto blindTest;
  ReviewFactoryMetrics toEntity() => ReviewFactoryMetrics(
    lessonsPublished: lessonsPublished,
    avgGenerationMinutes: avgGenerationMinutes,
    avgReviewMinutes: avgReviewMinutes,
    blindTest: blindTest.toEntity(),
  );
}

@JsonSerializable()
final class ReviewFactoryRunDto {
  const ReviewFactoryRunDto({
    required this.runId,
    required this.unitId,
    required this.lessonType,
    required this.brief,
    required this.status,
    required this.stage,
    required this.stages,
    required this.plan,
    required this.draft,
    required this.qaReport,
    required this.error,
    required this.reviewDigest,
    required this.published,
  });
  factory ReviewFactoryRunDto.fromJson(Map<String, dynamic> json) => _$ReviewFactoryRunDtoFromJson(json);
  final String runId;
  final String unitId;
  final String lessonType;
  final String brief;
  final String status;
  final String stage;
  final List<ReviewStageStatusDto> stages;
  final ReviewLessonPlanDto? plan;
  final ReviewDraftDto? draft;
  final ReviewQAReportDto? qaReport;
  final ReviewRunErrorDto? error;
  final String? reviewDigest;
  final ReviewPublishedRefDto? published;
  ReviewFactoryRun toEntity() => ReviewFactoryRun(
    runId: runId,
    unitId: unitId,
    lessonType: lessonType,
    brief: brief,
    status: status,
    stage: stage,
    stages: stages.map((e) => e.toEntity()).toList(),
    plan: plan?.toEntity(),
    draft: draft?.toEntity(),
    qaReport: qaReport?.toEntity(),
    error: error?.toEntity(),
    reviewDigest: reviewDigest,
    published: published?.toEntity(),
  );
}

@JsonSerializable()
final class ReviewGate1Dto {
  const ReviewGate1Dto({required this.decision, required this.plan, required this.reason, required this.reviewDigest});
  factory ReviewGate1Dto.fromJson(Map<String, dynamic> json) => _$ReviewGate1DtoFromJson(json);
  final String decision;
  final ReviewLessonPlanDto? plan;
  final String? reason;
  final String reviewDigest;
  ReviewGate1 toEntity() => ReviewGate1(decision: decision, plan: plan?.toEntity(), reason: reason, reviewDigest: reviewDigest);
}

@JsonSerializable()
final class ReviewGate2Dto {
  const ReviewGate2Dto({
    required this.decision,
    required this.sentenceEdits,
    required this.exerciseRemovals,
    required this.reason,
    required this.reviewDigest,
  });
  factory ReviewGate2Dto.fromJson(Map<String, dynamic> json) => _$ReviewGate2DtoFromJson(json);
  final String decision;
  final List<ReviewSentenceEditDto> sentenceEdits;
  final List<String> exerciseRemovals;
  final String? reason;
  final String reviewDigest;
  ReviewGate2 toEntity() => ReviewGate2(
    decision: decision,
    sentenceEdits: sentenceEdits.map((e) => e.toEntity()).toList(),
    exerciseRemovals: exerciseRemovals.map((e) => e).toList(),
    reason: reason,
    reviewDigest: reviewDigest,
  );
}

@JsonSerializable()
final class ReviewGlossaryDefinitionsDto {
  const ReviewGlossaryDefinitionsDto({required this.basic, required this.intermediate});
  factory ReviewGlossaryDefinitionsDto.fromJson(Map<String, dynamic> json) => _$ReviewGlossaryDefinitionsDtoFromJson(json);
  final ReviewLocalizedSpansDto basic;
  final ReviewLocalizedSpansDto? intermediate;
  ReviewGlossaryDefinitions toEntity() => ReviewGlossaryDefinitions(basic: basic.toEntity(), intermediate: intermediate?.toEntity());
}

@JsonSerializable()
final class ReviewImageDto {
  const ReviewImageDto({required this.url, required this.mimeType, required this.width, required this.height});
  factory ReviewImageDto.fromJson(Map<String, dynamic> json) => _$ReviewImageDtoFromJson(json);
  final String url;
  final String mimeType;
  final int width;
  final int height;
  ReviewImage toEntity() => ReviewImage(url: url, mimeType: mimeType, width: width, height: height);
}

@JsonSerializable()
final class ReviewLearningMetricsDto {
  const ReviewLearningMetricsDto({required this.prePost, required this.misconceptions, required this.completion});
  factory ReviewLearningMetricsDto.fromJson(Map<String, dynamic> json) => _$ReviewLearningMetricsDtoFromJson(json);
  final List<ReviewPrePostDto> prePost;
  final ReviewMisconceptionMetricsDto misconceptions;
  final ReviewCompletionMetricsDto completion;
  ReviewLearningMetrics toEntity() => ReviewLearningMetrics(
    prePost: prePost.map((e) => e.toEntity()).toList(),
    misconceptions: misconceptions.toEntity(),
    completion: completion.toEntity(),
  );
}

@JsonSerializable()
final class ReviewLessonArcDto {
  const ReviewLessonArcDto({required this.pattern, required this.rationale, required this.steps});
  factory ReviewLessonArcDto.fromJson(Map<String, dynamic> json) => _$ReviewLessonArcDtoFromJson(json);
  final String pattern;
  final ReviewLocalizedTextDto rationale;
  final List<ReviewArcStepDto> steps;
  ReviewLessonArc toEntity() =>
      ReviewLessonArc(pattern: pattern, rationale: rationale.toEntity(), steps: steps.map((e) => e.toEntity()).toList());
}

@JsonSerializable()
final class ReviewLessonPlanDto {
  const ReviewLessonPlanDto({
    required this.title,
    required this.centralQuestion,
    required this.primaryLearningOutcome,
    required this.supportingUnderstandings,
    required this.depthProfile,
    required this.objectives,
    required this.prerequisiteConceptIds,
    required this.introducedConceptIds,
    required this.newTerms,
    required this.targetMisconceptions,
    required this.lessonType,
    required this.estimatedMinutes,
    required this.lessonArc,
    required this.reasoningTools,
    required this.standaloneEligible,
    required this.contentBudget,
    required this.exerciseBudget,
  });
  factory ReviewLessonPlanDto.fromJson(Map<String, dynamic> json) => _$ReviewLessonPlanDtoFromJson(json);
  final ReviewLocalizedTextDto title;
  final ReviewLocalizedTextDto centralQuestion;
  final ReviewLocalizedTextDto primaryLearningOutcome;
  final List<ReviewLocalizedTextDto> supportingUnderstandings;
  final String depthProfile;
  final List<ReviewLocalizedTextDto> objectives;
  final List<String> prerequisiteConceptIds;
  final List<String> introducedConceptIds;
  final List<ReviewLocalizedTextDto> newTerms;
  final List<ReviewTargetMisconceptionDto> targetMisconceptions;
  final String lessonType;
  final int estimatedMinutes;
  final ReviewLessonArcDto lessonArc;
  final List<ReviewReasoningToolUseDto> reasoningTools;
  final bool standaloneEligible;
  final int contentBudget;
  final int exerciseBudget;
  ReviewLessonPlan toEntity() => ReviewLessonPlan(
    title: title.toEntity(),
    centralQuestion: centralQuestion.toEntity(),
    primaryLearningOutcome: primaryLearningOutcome.toEntity(),
    supportingUnderstandings: supportingUnderstandings.map((e) => e.toEntity()).toList(),
    depthProfile: depthProfile,
    objectives: objectives.map((e) => e.toEntity()).toList(),
    prerequisiteConceptIds: prerequisiteConceptIds.map((e) => e).toList(),
    introducedConceptIds: introducedConceptIds.map((e) => e).toList(),
    newTerms: newTerms.map((e) => e.toEntity()).toList(),
    targetMisconceptions: targetMisconceptions.map((e) => e.toEntity()).toList(),
    lessonType: lessonType,
    estimatedMinutes: estimatedMinutes,
    lessonArc: lessonArc.toEntity(),
    reasoningTools: reasoningTools.map((e) => e.toEntity()).toList(),
    standaloneEligible: standaloneEligible,
    contentBudget: contentBudget,
    exerciseBudget: exerciseBudget,
  );
}

@JsonSerializable()
final class ReviewLocalizedSpansDto {
  const ReviewLocalizedSpansDto({required this.ar, required this.en});
  factory ReviewLocalizedSpansDto.fromJson(Map<String, dynamic> json) => _$ReviewLocalizedSpansDtoFromJson(json);
  final List<SpanDto> ar;
  final List<SpanDto> en;
  ReviewLocalizedSpans toEntity() => ReviewLocalizedSpans(ar: contentSpans(ar), en: contentSpans(en));
}

@JsonSerializable()
final class ReviewLocalizedTextDto {
  const ReviewLocalizedTextDto({required this.ar, required this.en});
  factory ReviewLocalizedTextDto.fromJson(Map<String, dynamic> json) => _$ReviewLocalizedTextDtoFromJson(json);
  final String ar;
  final String en;
  ReviewLocalizedText toEntity() => ReviewLocalizedText(ar: ar, en: en);
}

@JsonSerializable()
final class ReviewMetricsDto {
  const ReviewMetricsDto({required this.learning, required this.raqeebBenchmark, required this.factory});
  factory ReviewMetricsDto.fromJson(Map<String, dynamic> json) => _$ReviewMetricsDtoFromJson(json);
  final ReviewLearningMetricsDto learning;
  final ReviewBenchmarkMetricsDto? raqeebBenchmark;
  final ReviewFactoryMetricsDto factory;
  ReviewMetrics toEntity() =>
      ReviewMetrics(learning: learning.toEntity(), raqeebBenchmark: raqeebBenchmark?.toEntity(), factory: factory.toEntity());
}

@JsonSerializable()
final class ReviewMisconceptionDto {
  const ReviewMisconceptionDto({required this.misconceptionId, required this.title, required this.card, required this.sourceIds});
  factory ReviewMisconceptionDto.fromJson(Map<String, dynamic> json) => _$ReviewMisconceptionDtoFromJson(json);
  final String misconceptionId;
  final String title;
  final List<SpanDto> card;
  final List<String> sourceIds;
  ReviewMisconception toEntity() => ReviewMisconception(
    misconceptionId: misconceptionId,
    title: title,
    card: contentSpans(card),
    sourceIds: sourceIds.map((e) => e).toList(),
  );
}

@JsonSerializable()
final class ReviewMisconceptionMetricsDto {
  const ReviewMisconceptionMetricsDto({required this.activated, required this.resolved, required this.resolutionRatePercent});
  factory ReviewMisconceptionMetricsDto.fromJson(Map<String, dynamic> json) => _$ReviewMisconceptionMetricsDtoFromJson(json);
  final int activated;
  final int resolved;
  final int? resolutionRatePercent;
  ReviewMisconceptionMetrics toEntity() =>
      ReviewMisconceptionMetrics(activated: activated, resolved: resolved, resolutionRatePercent: resolutionRatePercent);
}

@JsonSerializable()
final class ReviewPrePostDto {
  const ReviewPrePostDto({
    required this.unitId,
    required this.unitTitle,
    required this.participants,
    required this.preAvgPercent,
    required this.postAvgPercent,
    required this.delta,
  });
  factory ReviewPrePostDto.fromJson(Map<String, dynamic> json) => _$ReviewPrePostDtoFromJson(json);
  final String unitId;
  final String unitTitle;
  final int participants;
  final int preAvgPercent;
  final int postAvgPercent;
  final int delta;
  ReviewPrePost toEntity() => ReviewPrePost(
    unitId: unitId,
    unitTitle: unitTitle,
    participants: participants,
    preAvgPercent: preAvgPercent,
    postAvgPercent: postAvgPercent,
    delta: delta,
  );
}

@JsonSerializable()
final class ReviewPreviewDto {
  const ReviewPreviewDto({
    required this.language,
    required this.variant,
    required this.objectives,
    required this.items,
    required this.completion,
  });
  factory ReviewPreviewDto.fromJson(Map<String, dynamic> json) => _$ReviewPreviewDtoFromJson(json);
  final String language;
  final String variant;
  final List<List<SpanDto>> objectives;
  final List<BlockDto> items;
  final CompletionDto? completion;
  ReviewPreview toEntity() => ReviewPreview(
    language: language,
    variant: variant,
    objectives: objectives.map((e) => contentSpans(e)).toList(),
    items: items.map((e) => e.toEntity()).toList(),
    completion: completion?.reviewCompletion(),
  );
}

@JsonSerializable()
final class ReviewPreviewFrameDto {
  const ReviewPreviewFrameDto({required this.state, required this.timeMs, required this.reducedMotion, required this.image});
  factory ReviewPreviewFrameDto.fromJson(Map<String, dynamic> json) => _$ReviewPreviewFrameDtoFromJson(json);
  final Map<String, Object> state;
  final int timeMs;
  final bool reducedMotion;
  final ReviewImageDto image;
  ReviewPreviewFrame toEntity() =>
      ReviewPreviewFrame(state: state.map((k, e) => MapEntry(k, e)), timeMs: timeMs, reducedMotion: reducedMotion, image: image.toEntity());
}

@JsonSerializable()
final class ReviewPreviewTimingDto {
  const ReviewPreviewTimingDto({required this.buildRasterP95Ms, required this.firstFrameMs, required this.device});
  factory ReviewPreviewTimingDto.fromJson(Map<String, dynamic> json) => _$ReviewPreviewTimingDtoFromJson(json);
  final double buildRasterP95Ms;
  final double firstFrameMs;
  final String device;
  ReviewPreviewTiming toEntity() => ReviewPreviewTiming(buildRasterP95Ms: buildRasterP95Ms, firstFrameMs: firstFrameMs, device: device);
}

@JsonSerializable()
final class ReviewPublishedRefDto {
  const ReviewPublishedRefDto({required this.lessonId, required this.version});
  factory ReviewPublishedRefDto.fromJson(Map<String, dynamic> json) => _$ReviewPublishedRefDtoFromJson(json);
  final String lessonId;
  final int version;
  ReviewPublishedRef toEntity() => ReviewPublishedRef(lessonId: lessonId, version: version);
}

@JsonSerializable()
final class ReviewQAIssueDto {
  const ReviewQAIssueDto({required this.severity, required this.kind, required this.location, required this.message});
  factory ReviewQAIssueDto.fromJson(Map<String, dynamic> json) => _$ReviewQAIssueDtoFromJson(json);
  final String severity;
  final String kind;
  final ReviewQALocationDto location;
  final String message;
  ReviewQAIssue toEntity() => ReviewQAIssue(severity: severity, kind: kind, location: location.toEntity(), message: message);
}

@JsonSerializable()
final class ReviewQALocationDto {
  const ReviewQALocationDto({required this.sentenceId, required this.exerciseId, required this.sceneId});
  factory ReviewQALocationDto.fromJson(Map<String, dynamic> json) => _$ReviewQALocationDtoFromJson(json);
  final String? sentenceId;
  final String? exerciseId;
  final String? sceneId;
  ReviewQALocation toEntity() => ReviewQALocation(sentenceId: sentenceId, exerciseId: exerciseId, sceneId: sceneId);
}

@JsonSerializable()
final class ReviewQAReportDto {
  const ReviewQAReportDto({required this.issues});
  factory ReviewQAReportDto.fromJson(Map<String, dynamic> json) => _$ReviewQAReportDtoFromJson(json);
  final List<ReviewQAIssueDto> issues;
  ReviewQAReport toEntity() => ReviewQAReport(issues: issues.map((e) => e.toEntity()).toList());
}

@JsonSerializable()
final class ReviewReasoningSupportDto {
  const ReviewReasoningSupportDto({required this.tool, required this.premises, required this.inference});
  factory ReviewReasoningSupportDto.fromJson(Map<String, dynamic> json) => _$ReviewReasoningSupportDtoFromJson(json);
  final String tool;
  final List<String> premises;
  final String inference;
  ReviewReasoningSupport toEntity() => ReviewReasoningSupport(tool: tool, premises: premises.map((e) => e).toList(), inference: inference);
}

@JsonSerializable()
final class ReviewReasoningToolUseDto {
  const ReviewReasoningToolUseDto({required this.tool, required this.justification});
  factory ReviewReasoningToolUseDto.fromJson(Map<String, dynamic> json) => _$ReviewReasoningToolUseDtoFromJson(json);
  final String tool;
  final ReviewLocalizedTextDto justification;
  ReviewReasoningToolUse toEntity() => ReviewReasoningToolUse(tool: tool, justification: justification.toEntity());
}

@JsonSerializable()
final class ReviewReviewerReqDto {
  const ReviewReviewerReqDto({required this.email, required this.password});
  factory ReviewReviewerReqDto.fromJson(Map<String, dynamic> json) => _$ReviewReviewerReqDtoFromJson(json);
  final String email;
  final String password;
  ReviewReviewerReq toEntity() => ReviewReviewerReq(email: email, password: password);
}

@JsonSerializable()
final class ReviewRunCreateDto {
  const ReviewRunCreateDto({required this.unitId, required this.lessonType, required this.brief, required this.positionIndex});
  factory ReviewRunCreateDto.fromJson(Map<String, dynamic> json) => _$ReviewRunCreateDtoFromJson(json);
  final String unitId;
  final String lessonType;
  final String brief;
  final int positionIndex;
  ReviewRunCreate toEntity() => ReviewRunCreate(unitId: unitId, lessonType: lessonType, brief: brief, positionIndex: positionIndex);
}

@JsonSerializable()
final class ReviewRunErrorDto {
  const ReviewRunErrorDto({required this.code, required this.message});
  factory ReviewRunErrorDto.fromJson(Map<String, dynamic> json) => _$ReviewRunErrorDtoFromJson(json);
  final String code;
  final String message;
  ReviewRunError toEntity() => ReviewRunError(code: code, message: message);
}

@JsonSerializable()
final class ReviewRunRowDto {
  const ReviewRunRowDto({
    required this.runId,
    required this.unitId,
    required this.lessonType,
    required this.title,
    required this.status,
    required this.stage,
    required this.updatedAt,
  });
  factory ReviewRunRowDto.fromJson(Map<String, dynamic> json) => _$ReviewRunRowDtoFromJson(json);
  final String runId;
  final String unitId;
  final String lessonType;
  final String? title;
  final String status;
  final String stage;
  final String updatedAt;
  ReviewRunRow toEntity() =>
      ReviewRunRow(runId: runId, unitId: unitId, lessonType: lessonType, title: title, status: status, stage: stage, updatedAt: updatedAt);
}

@JsonSerializable()
final class ReviewScenePreviewDto {
  const ReviewScenePreviewDto({
    required this.frames,
    required this.animation,
    required this.reducedMotionStill,
    required this.fallbacks,
    required this.timing,
    required this.rendererVersion,
  });
  factory ReviewScenePreviewDto.fromJson(Map<String, dynamic> json) => _$ReviewScenePreviewDtoFromJson(json);
  final List<ReviewPreviewFrameDto> frames;
  final ReviewAnimationPreviewDto animation;
  final ReviewImageDto reducedMotionStill;
  final List<ReviewPreviewFrameDto> fallbacks;
  final ReviewPreviewTimingDto timing;
  final String rendererVersion;
  ReviewScenePreview toEntity() => ReviewScenePreview(
    frames: frames.map((e) => e.toEntity()).toList(),
    animation: animation.toEntity(),
    reducedMotionStill: reducedMotionStill.toEntity(),
    fallbacks: fallbacks.map((e) => e.toEntity()).toList(),
    timing: timing.toEntity(),
    rendererVersion: rendererVersion,
  );
}

@JsonSerializable()
final class ReviewSemanticReviewDto {
  const ReviewSemanticReviewDto({required this.fit, required this.concerns, required this.note});
  factory ReviewSemanticReviewDto.fromJson(Map<String, dynamic> json) => _$ReviewSemanticReviewDtoFromJson(json);
  final String fit;
  final List<String> concerns;
  final String note;
  ReviewSemanticReview toEntity() => ReviewSemanticReview(fit: fit, concerns: concerns.map((e) => e).toList(), note: note);
}

@JsonSerializable()
final class ReviewSentenceClaimsDto {
  const ReviewSentenceClaimsDto({required this.sentenceId, required this.role, required this.claimIds});
  factory ReviewSentenceClaimsDto.fromJson(Map<String, dynamic> json) => _$ReviewSentenceClaimsDtoFromJson(json);
  final String sentenceId;
  final String role;
  final List<String> claimIds;
  ReviewSentenceClaims toEntity() => ReviewSentenceClaims(sentenceId: sentenceId, role: role, claimIds: claimIds.map((e) => e).toList());
}

@JsonSerializable()
final class ReviewSentenceEditDto {
  const ReviewSentenceEditDto({required this.sentenceId, required this.language, required this.variant, required this.newText});
  factory ReviewSentenceEditDto.fromJson(Map<String, dynamic> json) => _$ReviewSentenceEditDtoFromJson(json);
  final String sentenceId;
  final String language;
  final String variant;
  final String newText;
  ReviewSentenceEdit toEntity() => ReviewSentenceEdit(sentenceId: sentenceId, language: language, variant: variant, newText: newText);
}

@JsonSerializable()
final class ReviewStageStatusDto {
  const ReviewStageStatusDto({required this.stage, required this.status, required this.startedAt, required this.finishedAt});
  factory ReviewStageStatusDto.fromJson(Map<String, dynamic> json) => _$ReviewStageStatusDtoFromJson(json);
  final String stage;
  final String status;
  final String? startedAt;
  final String? finishedAt;
  ReviewStageStatus toEntity() => ReviewStageStatus(stage: stage, status: status, startedAt: startedAt, finishedAt: finishedAt);
}

@JsonSerializable()
final class ReviewStoredGlossaryTermDto {
  const ReviewStoredGlossaryTermDto({
    required this.termId,
    required this.text,
    required this.arabic,
    required this.transliteration,
    required this.definition,
    required this.example,
    required this.conceptId,
    required this.lessonId,
    required this.sourceId,
    required this.pronunciationAudioUrl,
  });
  factory ReviewStoredGlossaryTermDto.fromJson(Map<String, dynamic> json) => _$ReviewStoredGlossaryTermDtoFromJson(json);
  final String termId;
  final ReviewLocalizedTextDto text;
  final String? arabic;
  final String transliteration;
  final ReviewGlossaryDefinitionsDto definition;
  final ReviewLocalizedSpansDto example;
  final String? conceptId;
  final String? lessonId;
  final String? sourceId;
  final String? pronunciationAudioUrl;
  ReviewStoredGlossaryTerm toEntity() => ReviewStoredGlossaryTerm(
    termId: termId,
    text: text.toEntity(),
    arabic: arabic,
    transliteration: transliteration,
    definition: definition.toEntity(),
    example: example.toEntity(),
    conceptId: conceptId,
    lessonId: lessonId,
    sourceId: sourceId,
    pronunciationAudioUrl: pronunciationAudioUrl,
  );
}

@JsonSerializable()
final class ReviewTargetMisconceptionDto {
  const ReviewTargetMisconceptionDto({required this.misconceptionId, required this.title, required this.description});
  factory ReviewTargetMisconceptionDto.fromJson(Map<String, dynamic> json) => _$ReviewTargetMisconceptionDtoFromJson(json);
  final String? misconceptionId;
  final ReviewLocalizedTextDto title;
  final ReviewLocalizedTextDto description;
  ReviewTargetMisconception toEntity() =>
      ReviewTargetMisconception(misconceptionId: misconceptionId, title: title.toEntity(), description: description.toEntity());
}

@JsonSerializable()
final class ReviewVisualAuditDto {
  const ReviewVisualAuditDto({required this.passed, required this.issues});
  factory ReviewVisualAuditDto.fromJson(Map<String, dynamic> json) => _$ReviewVisualAuditDtoFromJson(json);
  final bool passed;
  final List<String> issues;
  ReviewVisualAudit toEntity() => ReviewVisualAudit(passed: passed, issues: issues.map((e) => e).toList());
}

final class ReviewReviewerExerciseDto {
  ReviewReviewerExerciseDto(this.exercise, this.key, this.misconceptions, this.eligible);
  factory ReviewReviewerExerciseDto.fromJson(Map<String, dynamic> j) => ReviewReviewerExerciseDto(
    ExerciseHeaderDto.fromJson(j),
    j['answer_key'] as Map<String, dynamic>?,
    Map<String, String>.from(j['option_misconceptions'] as Map),
    j['duel_eligible'] as bool,
  );
  final ExerciseHeaderDto exercise;
  final Map<String, dynamic>? key;
  final Map<String, String> misconceptions;
  final bool eligible;
  ReviewReviewerExercise toEntity() {
    final e = exercise.toEntity();
    return ReviewReviewerExercise(e, correctAnswer(e.type, key), misconceptions, eligible);
  }
}

extension ReviewerCompletionMapping on CompletionDto {
  LessonCompletion reviewCompletion() => LessonCompletion(
    challenge: contentSpans(challenge),
    reviewTopics: reviewTopics.map((e) => ReviewTopic(topicId: e.topicId, title: e.title, conceptIds: e.conceptIds)).toList(),
    checkIn: contentSpans(checkIn),
  );
}
