import 'package:equatable/equatable.dart';
import 'package:qabas/shared/domain/entities/content.dart';
import 'package:qabas/shared/lesson/domain/entities/exercise.dart';
import 'package:qabas/shared/lesson/domain/entities/session.dart';

final class ReviewAnimationPreview extends Equatable {
  const ReviewAnimationPreview({
    required this.url,
    required this.mimeType,
    required this.width,
    required this.height,
    required this.durationMs,
  });
  final String url;
  final String mimeType;
  final int width;
  final int height;
  final int durationMs;
  ReviewAnimationPreview copyWith({String? url, String? mimeType, int? width, int? height, int? durationMs}) => ReviewAnimationPreview(
    url: url ?? this.url,
    mimeType: mimeType ?? this.mimeType,
    width: width ?? this.width,
    height: height ?? this.height,
    durationMs: durationMs ?? this.durationMs,
  );
  @override
  List<Object?> get props => [url, mimeType, width, height, durationMs];
}

final class ReviewArcStep extends Equatable {
  const ReviewArcStep({required this.stepId, required this.technique, required this.experience, required this.interactive});
  final String stepId;
  final String technique;
  final ReviewLocalizedText experience;
  final bool interactive;
  ReviewArcStep copyWith({String? stepId, String? technique, ReviewLocalizedText? experience, bool? interactive}) => ReviewArcStep(
    stepId: stepId ?? this.stepId,
    technique: technique ?? this.technique,
    experience: experience ?? this.experience,
    interactive: interactive ?? this.interactive,
  );
  @override
  List<Object?> get props => [stepId, technique, experience, interactive];
}

final class ReviewArcStepBlocks extends Equatable {
  ReviewArcStepBlocks({required this.stepId, required List<String> blockIds}) : blockIds = List.unmodifiable(blockIds);
  final String stepId;
  final List<String> blockIds;
  ReviewArcStepBlocks copyWith({String? stepId, List<String>? blockIds}) =>
      ReviewArcStepBlocks(stepId: stepId ?? this.stepId, blockIds: blockIds ?? this.blockIds);
  @override
  List<Object?> get props => [stepId, blockIds];
}

final class ReviewBenchmarkClass extends Equatable {
  const ReviewBenchmarkClass({required this.questionClass, required this.raqeebAccuracyPercent, required this.baselineAccuracyPercent});
  final String questionClass;
  final int raqeebAccuracyPercent;
  final int baselineAccuracyPercent;
  ReviewBenchmarkClass copyWith({String? questionClass, int? raqeebAccuracyPercent, int? baselineAccuracyPercent}) => ReviewBenchmarkClass(
    questionClass: questionClass ?? this.questionClass,
    raqeebAccuracyPercent: raqeebAccuracyPercent ?? this.raqeebAccuracyPercent,
    baselineAccuracyPercent: baselineAccuracyPercent ?? this.baselineAccuracyPercent,
  );
  @override
  List<Object?> get props => [questionClass, raqeebAccuracyPercent, baselineAccuracyPercent];
}

final class ReviewBenchmarkMetrics extends Equatable {
  ReviewBenchmarkMetrics({
    required this.runAt,
    required this.questionCount,
    required List<ReviewBenchmarkSystem> systems,
    required List<ReviewBenchmarkClass> byClass,
  }) : systems = List.unmodifiable(systems),
       byClass = List.unmodifiable(byClass);
  final String runAt;
  final int questionCount;
  final List<ReviewBenchmarkSystem> systems;
  final List<ReviewBenchmarkClass> byClass;
  ReviewBenchmarkMetrics copyWith({
    String? runAt,
    int? questionCount,
    List<ReviewBenchmarkSystem>? systems,
    List<ReviewBenchmarkClass>? byClass,
  }) => ReviewBenchmarkMetrics(
    runAt: runAt ?? this.runAt,
    questionCount: questionCount ?? this.questionCount,
    systems: systems ?? this.systems,
    byClass: byClass ?? this.byClass,
  );
  @override
  List<Object?> get props => [runAt, questionCount, systems, byClass];
}

final class ReviewBenchmarkSystem extends Equatable {
  const ReviewBenchmarkSystem({
    required this.name,
    required this.accuracyPercent,
    required this.unsupportedClaimRatePercent,
    required this.correctAbstentionPercent,
    required this.correctReferralPercent,
  });
  final String name;
  final int accuracyPercent;
  final int unsupportedClaimRatePercent;
  final int correctAbstentionPercent;
  final int correctReferralPercent;
  ReviewBenchmarkSystem copyWith({
    String? name,
    int? accuracyPercent,
    int? unsupportedClaimRatePercent,
    int? correctAbstentionPercent,
    int? correctReferralPercent,
  }) => ReviewBenchmarkSystem(
    name: name ?? this.name,
    accuracyPercent: accuracyPercent ?? this.accuracyPercent,
    unsupportedClaimRatePercent: unsupportedClaimRatePercent ?? this.unsupportedClaimRatePercent,
    correctAbstentionPercent: correctAbstentionPercent ?? this.correctAbstentionPercent,
    correctReferralPercent: correctReferralPercent ?? this.correctReferralPercent,
  );
  @override
  List<Object?> get props => [name, accuracyPercent, unsupportedClaimRatePercent, correctAbstentionPercent, correctReferralPercent];
}

final class ReviewBlindAnswer extends Equatable {
  const ReviewBlindAnswer({required this.clearer, required this.moreAccurate, required this.guessedHandwritten});
  final String clearer;
  final String moreAccurate;
  final String guessedHandwritten;
  ReviewBlindAnswer copyWith({String? clearer, String? moreAccurate, String? guessedHandwritten}) => ReviewBlindAnswer(
    clearer: clearer ?? this.clearer,
    moreAccurate: moreAccurate ?? this.moreAccurate,
    guessedHandwritten: guessedHandwritten ?? this.guessedHandwritten,
  );
  @override
  List<Object?> get props => [clearer, moreAccurate, guessedHandwritten];
}

final class ReviewBlindLesson extends Equatable {
  ReviewBlindLesson({
    required this.title,
    required List<List<ContentSpan>> objectives,
    required List<SessionItem> items,
    required this.completion,
  }) : objectives = List.unmodifiable(objectives),
       items = List.unmodifiable(items);
  final String title;
  final List<List<ContentSpan>> objectives;
  final List<SessionItem> items;
  final LessonCompletion? completion;
  ReviewBlindLesson copyWith({
    String? title,
    List<List<ContentSpan>>? objectives,
    List<SessionItem>? items,
    LessonCompletion? completion,
  }) => ReviewBlindLesson(
    title: title ?? this.title,
    objectives: objectives ?? this.objectives,
    items: items ?? this.items,
    completion: completion ?? this.completion,
  );
  @override
  List<Object?> get props => [title, objectives, items, completion];
}

final class ReviewBlindMetrics extends Equatable {
  const ReviewBlindMetrics({
    required this.responses,
    required this.handwrittenIdentifiedPercent,
    required this.generatedPreferredOrSamePercent,
  });
  final int responses;
  final int? handwrittenIdentifiedPercent;
  final int? generatedPreferredOrSamePercent;
  ReviewBlindMetrics copyWith({int? responses, int? handwrittenIdentifiedPercent, int? generatedPreferredOrSamePercent}) =>
      ReviewBlindMetrics(
        responses: responses ?? this.responses,
        handwrittenIdentifiedPercent: handwrittenIdentifiedPercent ?? this.handwrittenIdentifiedPercent,
        generatedPreferredOrSamePercent: generatedPreferredOrSamePercent ?? this.generatedPreferredOrSamePercent,
      );
  @override
  List<Object?> get props => [responses, handwrittenIdentifiedPercent, generatedPreferredOrSamePercent];
}

final class ReviewBlindPair extends Equatable {
  const ReviewBlindPair({required this.pairId, required this.lessonA, required this.lessonB});
  final String pairId;
  final ReviewBlindLesson lessonA;
  final ReviewBlindLesson lessonB;
  ReviewBlindPair copyWith({String? pairId, ReviewBlindLesson? lessonA, ReviewBlindLesson? lessonB}) =>
      ReviewBlindPair(pairId: pairId ?? this.pairId, lessonA: lessonA ?? this.lessonA, lessonB: lessonB ?? this.lessonB);
  @override
  List<Object?> get props => [pairId, lessonA, lessonB];
}

final class ReviewClaim extends Equatable {
  ReviewClaim({
    required this.claimId,
    required this.text,
    required this.status,
    required this.basis,
    required List<ReviewClaimEvidence> evidence,
    required this.reasoning,
  }) : evidence = List.unmodifiable(evidence);
  final String claimId;
  final String text;
  final String status;
  final String basis;
  final List<ReviewClaimEvidence> evidence;
  final ReviewReasoningSupport? reasoning;
  ReviewClaim copyWith({
    String? claimId,
    String? text,
    String? status,
    String? basis,
    List<ReviewClaimEvidence>? evidence,
    ReviewReasoningSupport? reasoning,
  }) => ReviewClaim(
    claimId: claimId ?? this.claimId,
    text: text ?? this.text,
    status: status ?? this.status,
    basis: basis ?? this.basis,
    evidence: evidence ?? this.evidence,
    reasoning: reasoning ?? this.reasoning,
  );
  @override
  List<Object?> get props => [claimId, text, status, basis, evidence, reasoning];
}

final class ReviewClaimEvidence extends Equatable {
  const ReviewClaimEvidence({required this.source, required this.supports, required this.verifierNote, required this.semanticReview});
  final Source source;
  final bool supports;
  final String verifierNote;
  final ReviewSemanticReview? semanticReview;
  ReviewClaimEvidence copyWith({Source? source, bool? supports, String? verifierNote, ReviewSemanticReview? semanticReview}) =>
      ReviewClaimEvidence(
        source: source ?? this.source,
        supports: supports ?? this.supports,
        verifierNote: verifierNote ?? this.verifierNote,
        semanticReview: semanticReview ?? this.semanticReview,
      );
  @override
  List<Object?> get props => [source, supports, verifierNote, semanticReview];
}

final class ReviewCompletionMetrics extends Equatable {
  const ReviewCompletionMetrics({required this.unitsStarted, required this.unitsCompleted});
  final int unitsStarted;
  final int unitsCompleted;
  ReviewCompletionMetrics copyWith({int? unitsStarted, int? unitsCompleted}) =>
      ReviewCompletionMetrics(unitsStarted: unitsStarted ?? this.unitsStarted, unitsCompleted: unitsCompleted ?? this.unitsCompleted);
  @override
  List<Object?> get props => [unitsStarted, unitsCompleted];
}

final class ReviewDraft extends Equatable {
  ReviewDraft({
    required List<String> languages,
    required List<String> variants,
    required List<ReviewPreview> previews,
    required List<ReviewClaim> claims,
    required List<ReviewSentenceClaims> sentenceMap,
    required List<ReviewArcStepBlocks> arcMap,
    required List<ReviewReviewerExercise> exercises,
    required List<ReviewStoredGlossaryTerm> glossary,
    required List<ReviewMisconception> misconceptions,
    required List<ReviewDraftVisual> visuals,
  }) : languages = List.unmodifiable(languages),
       variants = List.unmodifiable(variants),
       previews = List.unmodifiable(previews),
       claims = List.unmodifiable(claims),
       sentenceMap = List.unmodifiable(sentenceMap),
       arcMap = List.unmodifiable(arcMap),
       exercises = List.unmodifiable(exercises),
       glossary = List.unmodifiable(glossary),
       misconceptions = List.unmodifiable(misconceptions),
       visuals = List.unmodifiable(visuals);
  final List<String> languages;
  final List<String> variants;
  final List<ReviewPreview> previews;
  final List<ReviewClaim> claims;
  final List<ReviewSentenceClaims> sentenceMap;
  final List<ReviewArcStepBlocks> arcMap;
  final List<ReviewReviewerExercise> exercises;
  final List<ReviewStoredGlossaryTerm> glossary;
  final List<ReviewMisconception> misconceptions;
  final List<ReviewDraftVisual> visuals;
  ReviewDraft copyWith({
    List<String>? languages,
    List<String>? variants,
    List<ReviewPreview>? previews,
    List<ReviewClaim>? claims,
    List<ReviewSentenceClaims>? sentenceMap,
    List<ReviewArcStepBlocks>? arcMap,
    List<ReviewReviewerExercise>? exercises,
    List<ReviewStoredGlossaryTerm>? glossary,
    List<ReviewMisconception>? misconceptions,
    List<ReviewDraftVisual>? visuals,
  }) => ReviewDraft(
    languages: languages ?? this.languages,
    variants: variants ?? this.variants,
    previews: previews ?? this.previews,
    claims: claims ?? this.claims,
    sentenceMap: sentenceMap ?? this.sentenceMap,
    arcMap: arcMap ?? this.arcMap,
    exercises: exercises ?? this.exercises,
    glossary: glossary ?? this.glossary,
    misconceptions: misconceptions ?? this.misconceptions,
    visuals: visuals ?? this.visuals,
  );
  @override
  List<Object?> get props => [languages, variants, previews, claims, sentenceMap, arcMap, exercises, glossary, misconceptions, visuals];
}

final class ReviewDraftFragment extends Equatable {
  const ReviewDraftFragment({required this.draft, required this.qaReport});
  final ReviewDraft draft;
  final ReviewQAReport qaReport;
  ReviewDraftFragment copyWith({ReviewDraft? draft, ReviewQAReport? qaReport}) =>
      ReviewDraftFragment(draft: draft ?? this.draft, qaReport: qaReport ?? this.qaReport);
  @override
  List<Object?> get props => [draft, qaReport];
}

final class ReviewDraftVisual extends Equatable {
  const ReviewDraftVisual({
    required this.sceneId,
    required this.origin,
    required this.visual,
    required this.audit,
    required this.attempts,
    required this.previews,
  });
  final String sceneId;
  final String origin;
  final Visual visual;
  final ReviewVisualAudit? audit;
  final int attempts;
  final ReviewScenePreview? previews;
  ReviewDraftVisual copyWith({
    String? sceneId,
    String? origin,
    Visual? visual,
    ReviewVisualAudit? audit,
    int? attempts,
    ReviewScenePreview? previews,
  }) => ReviewDraftVisual(
    sceneId: sceneId ?? this.sceneId,
    origin: origin ?? this.origin,
    visual: visual ?? this.visual,
    audit: audit ?? this.audit,
    attempts: attempts ?? this.attempts,
    previews: previews ?? this.previews,
  );
  @override
  List<Object?> get props => [sceneId, origin, visual, audit, attempts, previews];
}

final class ReviewFactoryMetrics extends Equatable {
  const ReviewFactoryMetrics({
    required this.lessonsPublished,
    required this.avgGenerationMinutes,
    required this.avgReviewMinutes,
    required this.blindTest,
  });
  final int lessonsPublished;
  final int? avgGenerationMinutes;
  final int? avgReviewMinutes;
  final ReviewBlindMetrics blindTest;
  ReviewFactoryMetrics copyWith({int? lessonsPublished, int? avgGenerationMinutes, int? avgReviewMinutes, ReviewBlindMetrics? blindTest}) =>
      ReviewFactoryMetrics(
        lessonsPublished: lessonsPublished ?? this.lessonsPublished,
        avgGenerationMinutes: avgGenerationMinutes ?? this.avgGenerationMinutes,
        avgReviewMinutes: avgReviewMinutes ?? this.avgReviewMinutes,
        blindTest: blindTest ?? this.blindTest,
      );
  @override
  List<Object?> get props => [lessonsPublished, avgGenerationMinutes, avgReviewMinutes, blindTest];
}

final class ReviewFactoryRun extends Equatable {
  ReviewFactoryRun({
    required this.runId,
    required this.unitId,
    required this.lessonType,
    required this.brief,
    required this.status,
    required this.stage,
    required List<ReviewStageStatus> stages,
    required this.plan,
    required this.draft,
    required this.qaReport,
    required this.error,
    required this.reviewDigest,
    required this.published,
  }) : stages = List.unmodifiable(stages);
  final String runId;
  final String unitId;
  final String lessonType;
  final String brief;
  final String status;
  final String stage;
  final List<ReviewStageStatus> stages;
  final ReviewLessonPlan? plan;
  final ReviewDraft? draft;
  final ReviewQAReport? qaReport;
  final ReviewRunError? error;
  final String? reviewDigest;
  final ReviewPublishedRef? published;
  ReviewFactoryRun copyWith({
    String? runId,
    String? unitId,
    String? lessonType,
    String? brief,
    String? status,
    String? stage,
    List<ReviewStageStatus>? stages,
    ReviewLessonPlan? plan,
    ReviewDraft? draft,
    ReviewQAReport? qaReport,
    ReviewRunError? error,
    String? reviewDigest,
    ReviewPublishedRef? published,
  }) => ReviewFactoryRun(
    runId: runId ?? this.runId,
    unitId: unitId ?? this.unitId,
    lessonType: lessonType ?? this.lessonType,
    brief: brief ?? this.brief,
    status: status ?? this.status,
    stage: stage ?? this.stage,
    stages: stages ?? this.stages,
    plan: plan ?? this.plan,
    draft: draft ?? this.draft,
    qaReport: qaReport ?? this.qaReport,
    error: error ?? this.error,
    reviewDigest: reviewDigest ?? this.reviewDigest,
    published: published ?? this.published,
  );
  @override
  List<Object?> get props => [
    runId,
    unitId,
    lessonType,
    brief,
    status,
    stage,
    stages,
    plan,
    draft,
    qaReport,
    error,
    reviewDigest,
    published,
  ];
}

final class ReviewGate1 extends Equatable {
  const ReviewGate1({required this.decision, required this.plan, required this.reason, required this.reviewDigest});
  final String decision;
  final ReviewLessonPlan? plan;
  final String? reason;
  final String reviewDigest;
  ReviewGate1 copyWith({String? decision, ReviewLessonPlan? plan, String? reason, String? reviewDigest}) => ReviewGate1(
    decision: decision ?? this.decision,
    plan: plan ?? this.plan,
    reason: reason ?? this.reason,
    reviewDigest: reviewDigest ?? this.reviewDigest,
  );
  @override
  List<Object?> get props => [decision, plan, reason, reviewDigest];
}

final class ReviewGate2 extends Equatable {
  ReviewGate2({
    required this.decision,
    required List<ReviewSentenceEdit> sentenceEdits,
    required List<String> exerciseRemovals,
    required this.reason,
    required this.reviewDigest,
  }) : sentenceEdits = List.unmodifiable(sentenceEdits),
       exerciseRemovals = List.unmodifiable(exerciseRemovals);
  final String decision;
  final List<ReviewSentenceEdit> sentenceEdits;
  final List<String> exerciseRemovals;
  final String? reason;
  final String reviewDigest;
  ReviewGate2 copyWith({
    String? decision,
    List<ReviewSentenceEdit>? sentenceEdits,
    List<String>? exerciseRemovals,
    String? reason,
    String? reviewDigest,
  }) => ReviewGate2(
    decision: decision ?? this.decision,
    sentenceEdits: sentenceEdits ?? this.sentenceEdits,
    exerciseRemovals: exerciseRemovals ?? this.exerciseRemovals,
    reason: reason ?? this.reason,
    reviewDigest: reviewDigest ?? this.reviewDigest,
  );
  @override
  List<Object?> get props => [decision, sentenceEdits, exerciseRemovals, reason, reviewDigest];
}

final class ReviewGlossaryDefinitions extends Equatable {
  const ReviewGlossaryDefinitions({required this.basic, required this.intermediate});
  final ReviewLocalizedSpans basic;
  final ReviewLocalizedSpans? intermediate;
  ReviewGlossaryDefinitions copyWith({ReviewLocalizedSpans? basic, ReviewLocalizedSpans? intermediate}) =>
      ReviewGlossaryDefinitions(basic: basic ?? this.basic, intermediate: intermediate ?? this.intermediate);
  @override
  List<Object?> get props => [basic, intermediate];
}

final class ReviewImage extends Equatable {
  const ReviewImage({required this.url, required this.mimeType, required this.width, required this.height});
  final String url;
  final String mimeType;
  final int width;
  final int height;
  ReviewImage copyWith({String? url, String? mimeType, int? width, int? height}) =>
      ReviewImage(url: url ?? this.url, mimeType: mimeType ?? this.mimeType, width: width ?? this.width, height: height ?? this.height);
  @override
  List<Object?> get props => [url, mimeType, width, height];
}

final class ReviewLearningMetrics extends Equatable {
  ReviewLearningMetrics({required List<ReviewPrePost> prePost, required this.misconceptions, required this.completion})
    : prePost = List.unmodifiable(prePost);
  final List<ReviewPrePost> prePost;
  final ReviewMisconceptionMetrics misconceptions;
  final ReviewCompletionMetrics completion;
  ReviewLearningMetrics copyWith({
    List<ReviewPrePost>? prePost,
    ReviewMisconceptionMetrics? misconceptions,
    ReviewCompletionMetrics? completion,
  }) => ReviewLearningMetrics(
    prePost: prePost ?? this.prePost,
    misconceptions: misconceptions ?? this.misconceptions,
    completion: completion ?? this.completion,
  );
  @override
  List<Object?> get props => [prePost, misconceptions, completion];
}

final class ReviewLessonArc extends Equatable {
  ReviewLessonArc({required this.pattern, required this.rationale, required List<ReviewArcStep> steps}) : steps = List.unmodifiable(steps);
  final String pattern;
  final ReviewLocalizedText rationale;
  final List<ReviewArcStep> steps;
  ReviewLessonArc copyWith({String? pattern, ReviewLocalizedText? rationale, List<ReviewArcStep>? steps}) =>
      ReviewLessonArc(pattern: pattern ?? this.pattern, rationale: rationale ?? this.rationale, steps: steps ?? this.steps);
  @override
  List<Object?> get props => [pattern, rationale, steps];
}

final class ReviewLessonPlan extends Equatable {
  ReviewLessonPlan({
    required this.title,
    required this.centralQuestion,
    required this.primaryLearningOutcome,
    required List<ReviewLocalizedText> supportingUnderstandings,
    required this.depthProfile,
    required List<ReviewLocalizedText> objectives,
    required List<String> prerequisiteConceptIds,
    required List<String> introducedConceptIds,
    required List<ReviewLocalizedText> newTerms,
    required List<ReviewTargetMisconception> targetMisconceptions,
    required this.lessonType,
    required this.estimatedMinutes,
    required this.lessonArc,
    required List<ReviewReasoningToolUse> reasoningTools,
    required this.standaloneEligible,
    required this.contentBudget,
    required this.exerciseBudget,
  }) : supportingUnderstandings = List.unmodifiable(supportingUnderstandings),
       objectives = List.unmodifiable(objectives),
       prerequisiteConceptIds = List.unmodifiable(prerequisiteConceptIds),
       introducedConceptIds = List.unmodifiable(introducedConceptIds),
       newTerms = List.unmodifiable(newTerms),
       targetMisconceptions = List.unmodifiable(targetMisconceptions),
       reasoningTools = List.unmodifiable(reasoningTools);
  final ReviewLocalizedText title;
  final ReviewLocalizedText centralQuestion;
  final ReviewLocalizedText primaryLearningOutcome;
  final List<ReviewLocalizedText> supportingUnderstandings;
  final String depthProfile;
  final List<ReviewLocalizedText> objectives;
  final List<String> prerequisiteConceptIds;
  final List<String> introducedConceptIds;
  final List<ReviewLocalizedText> newTerms;
  final List<ReviewTargetMisconception> targetMisconceptions;
  final String lessonType;
  final int estimatedMinutes;
  final ReviewLessonArc lessonArc;
  final List<ReviewReasoningToolUse> reasoningTools;
  final bool standaloneEligible;
  final int contentBudget;
  final int exerciseBudget;
  ReviewLessonPlan copyWith({
    ReviewLocalizedText? title,
    ReviewLocalizedText? centralQuestion,
    ReviewLocalizedText? primaryLearningOutcome,
    List<ReviewLocalizedText>? supportingUnderstandings,
    String? depthProfile,
    List<ReviewLocalizedText>? objectives,
    List<String>? prerequisiteConceptIds,
    List<String>? introducedConceptIds,
    List<ReviewLocalizedText>? newTerms,
    List<ReviewTargetMisconception>? targetMisconceptions,
    String? lessonType,
    int? estimatedMinutes,
    ReviewLessonArc? lessonArc,
    List<ReviewReasoningToolUse>? reasoningTools,
    bool? standaloneEligible,
    int? contentBudget,
    int? exerciseBudget,
  }) => ReviewLessonPlan(
    title: title ?? this.title,
    centralQuestion: centralQuestion ?? this.centralQuestion,
    primaryLearningOutcome: primaryLearningOutcome ?? this.primaryLearningOutcome,
    supportingUnderstandings: supportingUnderstandings ?? this.supportingUnderstandings,
    depthProfile: depthProfile ?? this.depthProfile,
    objectives: objectives ?? this.objectives,
    prerequisiteConceptIds: prerequisiteConceptIds ?? this.prerequisiteConceptIds,
    introducedConceptIds: introducedConceptIds ?? this.introducedConceptIds,
    newTerms: newTerms ?? this.newTerms,
    targetMisconceptions: targetMisconceptions ?? this.targetMisconceptions,
    lessonType: lessonType ?? this.lessonType,
    estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
    lessonArc: lessonArc ?? this.lessonArc,
    reasoningTools: reasoningTools ?? this.reasoningTools,
    standaloneEligible: standaloneEligible ?? this.standaloneEligible,
    contentBudget: contentBudget ?? this.contentBudget,
    exerciseBudget: exerciseBudget ?? this.exerciseBudget,
  );
  @override
  List<Object?> get props => [
    title,
    centralQuestion,
    primaryLearningOutcome,
    supportingUnderstandings,
    depthProfile,
    objectives,
    prerequisiteConceptIds,
    introducedConceptIds,
    newTerms,
    targetMisconceptions,
    lessonType,
    estimatedMinutes,
    lessonArc,
    reasoningTools,
    standaloneEligible,
    contentBudget,
    exerciseBudget,
  ];
}

final class ReviewLocalizedSpans extends Equatable {
  ReviewLocalizedSpans({required List<ContentSpan> ar, required List<ContentSpan> en})
    : ar = List.unmodifiable(ar),
      en = List.unmodifiable(en);
  final List<ContentSpan> ar;
  final List<ContentSpan> en;
  ReviewLocalizedSpans copyWith({List<ContentSpan>? ar, List<ContentSpan>? en}) =>
      ReviewLocalizedSpans(ar: ar ?? this.ar, en: en ?? this.en);
  @override
  List<Object?> get props => [ar, en];
}

final class ReviewLocalizedText extends Equatable {
  const ReviewLocalizedText({required this.ar, required this.en});
  final String ar;
  final String en;
  ReviewLocalizedText copyWith({String? ar, String? en}) => ReviewLocalizedText(ar: ar ?? this.ar, en: en ?? this.en);
  @override
  List<Object?> get props => [ar, en];
}

final class ReviewMetrics extends Equatable {
  const ReviewMetrics({required this.learning, required this.raqeebBenchmark, required this.factory});
  final ReviewLearningMetrics learning;
  final ReviewBenchmarkMetrics? raqeebBenchmark;
  final ReviewFactoryMetrics factory;
  ReviewMetrics copyWith({ReviewLearningMetrics? learning, ReviewBenchmarkMetrics? raqeebBenchmark, ReviewFactoryMetrics? factory}) =>
      ReviewMetrics(
        learning: learning ?? this.learning,
        raqeebBenchmark: raqeebBenchmark ?? this.raqeebBenchmark,
        factory: factory ?? this.factory,
      );
  @override
  List<Object?> get props => [learning, raqeebBenchmark, factory];
}

final class ReviewMisconception extends Equatable {
  ReviewMisconception({
    required this.misconceptionId,
    required this.title,
    required List<ContentSpan> card,
    required List<String> sourceIds,
  }) : card = List.unmodifiable(card),
       sourceIds = List.unmodifiable(sourceIds);
  final String misconceptionId;
  final String title;
  final List<ContentSpan> card;
  final List<String> sourceIds;
  ReviewMisconception copyWith({String? misconceptionId, String? title, List<ContentSpan>? card, List<String>? sourceIds}) =>
      ReviewMisconception(
        misconceptionId: misconceptionId ?? this.misconceptionId,
        title: title ?? this.title,
        card: card ?? this.card,
        sourceIds: sourceIds ?? this.sourceIds,
      );
  @override
  List<Object?> get props => [misconceptionId, title, card, sourceIds];
}

final class ReviewMisconceptionMetrics extends Equatable {
  const ReviewMisconceptionMetrics({required this.activated, required this.resolved, required this.resolutionRatePercent});
  final int activated;
  final int resolved;
  final int? resolutionRatePercent;
  ReviewMisconceptionMetrics copyWith({int? activated, int? resolved, int? resolutionRatePercent}) => ReviewMisconceptionMetrics(
    activated: activated ?? this.activated,
    resolved: resolved ?? this.resolved,
    resolutionRatePercent: resolutionRatePercent ?? this.resolutionRatePercent,
  );
  @override
  List<Object?> get props => [activated, resolved, resolutionRatePercent];
}

final class ReviewPrePost extends Equatable {
  const ReviewPrePost({
    required this.unitId,
    required this.unitTitle,
    required this.participants,
    required this.preAvgPercent,
    required this.postAvgPercent,
    required this.delta,
  });
  final String unitId;
  final String unitTitle;
  final int participants;
  final int preAvgPercent;
  final int postAvgPercent;
  final int delta;
  ReviewPrePost copyWith({String? unitId, String? unitTitle, int? participants, int? preAvgPercent, int? postAvgPercent, int? delta}) =>
      ReviewPrePost(
        unitId: unitId ?? this.unitId,
        unitTitle: unitTitle ?? this.unitTitle,
        participants: participants ?? this.participants,
        preAvgPercent: preAvgPercent ?? this.preAvgPercent,
        postAvgPercent: postAvgPercent ?? this.postAvgPercent,
        delta: delta ?? this.delta,
      );
  @override
  List<Object?> get props => [unitId, unitTitle, participants, preAvgPercent, postAvgPercent, delta];
}

final class ReviewPreview extends Equatable {
  ReviewPreview({
    required this.language,
    required this.variant,
    required List<List<ContentSpan>> objectives,
    required List<SessionItem> items,
    required this.completion,
  }) : objectives = List.unmodifiable(objectives),
       items = List.unmodifiable(items);
  final String language;
  final String variant;
  final List<List<ContentSpan>> objectives;
  final List<SessionItem> items;
  final LessonCompletion? completion;
  ReviewPreview copyWith({
    String? language,
    String? variant,
    List<List<ContentSpan>>? objectives,
    List<SessionItem>? items,
    LessonCompletion? completion,
  }) => ReviewPreview(
    language: language ?? this.language,
    variant: variant ?? this.variant,
    objectives: objectives ?? this.objectives,
    items: items ?? this.items,
    completion: completion ?? this.completion,
  );
  @override
  List<Object?> get props => [language, variant, objectives, items, completion];
}

final class ReviewPreviewFrame extends Equatable {
  ReviewPreviewFrame({required Map<String, Object> state, required this.timeMs, required this.reducedMotion, required this.image})
    : state = Map.unmodifiable(state);
  final Map<String, Object> state;
  final int timeMs;
  final bool reducedMotion;
  final ReviewImage image;
  ReviewPreviewFrame copyWith({Map<String, Object>? state, int? timeMs, bool? reducedMotion, ReviewImage? image}) => ReviewPreviewFrame(
    state: state ?? this.state,
    timeMs: timeMs ?? this.timeMs,
    reducedMotion: reducedMotion ?? this.reducedMotion,
    image: image ?? this.image,
  );
  @override
  List<Object?> get props => [state, timeMs, reducedMotion, image];
}

final class ReviewPreviewTiming extends Equatable {
  const ReviewPreviewTiming({required this.buildRasterP95Ms, required this.firstFrameMs, required this.device});
  final double buildRasterP95Ms;
  final double firstFrameMs;
  final String device;
  ReviewPreviewTiming copyWith({double? buildRasterP95Ms, double? firstFrameMs, String? device}) => ReviewPreviewTiming(
    buildRasterP95Ms: buildRasterP95Ms ?? this.buildRasterP95Ms,
    firstFrameMs: firstFrameMs ?? this.firstFrameMs,
    device: device ?? this.device,
  );
  @override
  List<Object?> get props => [buildRasterP95Ms, firstFrameMs, device];
}

final class ReviewPublishedRef extends Equatable {
  const ReviewPublishedRef({required this.lessonId, required this.version});
  final String lessonId;
  final int version;
  ReviewPublishedRef copyWith({String? lessonId, int? version}) =>
      ReviewPublishedRef(lessonId: lessonId ?? this.lessonId, version: version ?? this.version);
  @override
  List<Object?> get props => [lessonId, version];
}

final class ReviewQAIssue extends Equatable {
  const ReviewQAIssue({required this.severity, required this.kind, required this.location, required this.message});
  final String severity;
  final String kind;
  final ReviewQALocation location;
  final String message;
  ReviewQAIssue copyWith({String? severity, String? kind, ReviewQALocation? location, String? message}) => ReviewQAIssue(
    severity: severity ?? this.severity,
    kind: kind ?? this.kind,
    location: location ?? this.location,
    message: message ?? this.message,
  );
  @override
  List<Object?> get props => [severity, kind, location, message];
}

final class ReviewQALocation extends Equatable {
  const ReviewQALocation({required this.sentenceId, required this.exerciseId, required this.sceneId});
  final String? sentenceId;
  final String? exerciseId;
  final String? sceneId;
  ReviewQALocation copyWith({String? sentenceId, String? exerciseId, String? sceneId}) => ReviewQALocation(
    sentenceId: sentenceId ?? this.sentenceId,
    exerciseId: exerciseId ?? this.exerciseId,
    sceneId: sceneId ?? this.sceneId,
  );
  @override
  List<Object?> get props => [sentenceId, exerciseId, sceneId];
}

final class ReviewQAReport extends Equatable {
  ReviewQAReport({required List<ReviewQAIssue> issues}) : issues = List.unmodifiable(issues);
  final List<ReviewQAIssue> issues;
  ReviewQAReport copyWith({List<ReviewQAIssue>? issues}) => ReviewQAReport(issues: issues ?? this.issues);
  @override
  List<Object?> get props => [issues];
}

final class ReviewReasoningSupport extends Equatable {
  ReviewReasoningSupport({required this.tool, required List<String> premises, required this.inference})
    : premises = List.unmodifiable(premises);
  final String tool;
  final List<String> premises;
  final String inference;
  ReviewReasoningSupport copyWith({String? tool, List<String>? premises, String? inference}) =>
      ReviewReasoningSupport(tool: tool ?? this.tool, premises: premises ?? this.premises, inference: inference ?? this.inference);
  @override
  List<Object?> get props => [tool, premises, inference];
}

final class ReviewReasoningToolUse extends Equatable {
  const ReviewReasoningToolUse({required this.tool, required this.justification});
  final String tool;
  final ReviewLocalizedText justification;
  ReviewReasoningToolUse copyWith({String? tool, ReviewLocalizedText? justification}) =>
      ReviewReasoningToolUse(tool: tool ?? this.tool, justification: justification ?? this.justification);
  @override
  List<Object?> get props => [tool, justification];
}

final class ReviewReviewerReq extends Equatable {
  const ReviewReviewerReq({required this.email, required this.password});
  final String email;
  final String password;
  ReviewReviewerReq copyWith({String? email, String? password}) =>
      ReviewReviewerReq(email: email ?? this.email, password: password ?? this.password);
  @override
  List<Object?> get props => [email, password];
}

final class ReviewRunCreate extends Equatable {
  const ReviewRunCreate({required this.unitId, required this.lessonType, required this.brief, required this.positionIndex});
  final String unitId;
  final String lessonType;
  final String brief;
  final int positionIndex;
  ReviewRunCreate copyWith({String? unitId, String? lessonType, String? brief, int? positionIndex}) => ReviewRunCreate(
    unitId: unitId ?? this.unitId,
    lessonType: lessonType ?? this.lessonType,
    brief: brief ?? this.brief,
    positionIndex: positionIndex ?? this.positionIndex,
  );
  @override
  List<Object?> get props => [unitId, lessonType, brief, positionIndex];
}

final class ReviewRunError extends Equatable {
  const ReviewRunError({required this.code, required this.message});
  final String code;
  final String message;
  ReviewRunError copyWith({String? code, String? message}) => ReviewRunError(code: code ?? this.code, message: message ?? this.message);
  @override
  List<Object?> get props => [code, message];
}

final class ReviewRunRow extends Equatable {
  const ReviewRunRow({
    required this.runId,
    required this.unitId,
    required this.lessonType,
    required this.title,
    required this.status,
    required this.stage,
    required this.updatedAt,
  });
  final String runId;
  final String unitId;
  final String lessonType;
  final String? title;
  final String status;
  final String stage;
  final String updatedAt;
  ReviewRunRow copyWith({
    String? runId,
    String? unitId,
    String? lessonType,
    String? title,
    String? status,
    String? stage,
    String? updatedAt,
  }) => ReviewRunRow(
    runId: runId ?? this.runId,
    unitId: unitId ?? this.unitId,
    lessonType: lessonType ?? this.lessonType,
    title: title ?? this.title,
    status: status ?? this.status,
    stage: stage ?? this.stage,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  @override
  List<Object?> get props => [runId, unitId, lessonType, title, status, stage, updatedAt];
}

final class ReviewScenePreview extends Equatable {
  ReviewScenePreview({
    required List<ReviewPreviewFrame> frames,
    required this.animation,
    required this.reducedMotionStill,
    required List<ReviewPreviewFrame> fallbacks,
    required this.timing,
    required this.rendererVersion,
  }) : frames = List.unmodifiable(frames),
       fallbacks = List.unmodifiable(fallbacks);
  final List<ReviewPreviewFrame> frames;
  final ReviewAnimationPreview animation;
  final ReviewImage reducedMotionStill;
  final List<ReviewPreviewFrame> fallbacks;
  final ReviewPreviewTiming timing;
  final String rendererVersion;
  ReviewScenePreview copyWith({
    List<ReviewPreviewFrame>? frames,
    ReviewAnimationPreview? animation,
    ReviewImage? reducedMotionStill,
    List<ReviewPreviewFrame>? fallbacks,
    ReviewPreviewTiming? timing,
    String? rendererVersion,
  }) => ReviewScenePreview(
    frames: frames ?? this.frames,
    animation: animation ?? this.animation,
    reducedMotionStill: reducedMotionStill ?? this.reducedMotionStill,
    fallbacks: fallbacks ?? this.fallbacks,
    timing: timing ?? this.timing,
    rendererVersion: rendererVersion ?? this.rendererVersion,
  );
  @override
  List<Object?> get props => [frames, animation, reducedMotionStill, fallbacks, timing, rendererVersion];
}

final class ReviewSemanticReview extends Equatable {
  ReviewSemanticReview({required this.fit, required List<String> concerns, required this.note}) : concerns = List.unmodifiable(concerns);
  final String fit;
  final List<String> concerns;
  final String note;
  ReviewSemanticReview copyWith({String? fit, List<String>? concerns, String? note}) =>
      ReviewSemanticReview(fit: fit ?? this.fit, concerns: concerns ?? this.concerns, note: note ?? this.note);
  @override
  List<Object?> get props => [fit, concerns, note];
}

final class ReviewSentenceClaims extends Equatable {
  ReviewSentenceClaims({required this.sentenceId, required this.role, required List<String> claimIds})
    : claimIds = List.unmodifiable(claimIds);
  final String sentenceId;
  final String role;
  final List<String> claimIds;
  ReviewSentenceClaims copyWith({String? sentenceId, String? role, List<String>? claimIds}) =>
      ReviewSentenceClaims(sentenceId: sentenceId ?? this.sentenceId, role: role ?? this.role, claimIds: claimIds ?? this.claimIds);
  @override
  List<Object?> get props => [sentenceId, role, claimIds];
}

final class ReviewSentenceEdit extends Equatable {
  const ReviewSentenceEdit({required this.sentenceId, required this.language, required this.variant, required this.newText});
  final String sentenceId;
  final String language;
  final String variant;
  final String newText;
  ReviewSentenceEdit copyWith({String? sentenceId, String? language, String? variant, String? newText}) => ReviewSentenceEdit(
    sentenceId: sentenceId ?? this.sentenceId,
    language: language ?? this.language,
    variant: variant ?? this.variant,
    newText: newText ?? this.newText,
  );
  @override
  List<Object?> get props => [sentenceId, language, variant, newText];
}

final class ReviewStageStatus extends Equatable {
  const ReviewStageStatus({required this.stage, required this.status, required this.startedAt, required this.finishedAt});
  final String stage;
  final String status;
  final String? startedAt;
  final String? finishedAt;
  ReviewStageStatus copyWith({String? stage, String? status, String? startedAt, String? finishedAt}) => ReviewStageStatus(
    stage: stage ?? this.stage,
    status: status ?? this.status,
    startedAt: startedAt ?? this.startedAt,
    finishedAt: finishedAt ?? this.finishedAt,
  );
  @override
  List<Object?> get props => [stage, status, startedAt, finishedAt];
}

final class ReviewStoredGlossaryTerm extends Equatable {
  const ReviewStoredGlossaryTerm({
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
  final String termId;
  final ReviewLocalizedText text;
  final String? arabic;
  final String transliteration;
  final ReviewGlossaryDefinitions definition;
  final ReviewLocalizedSpans example;
  final String? conceptId;
  final String? lessonId;
  final String? sourceId;
  final String? pronunciationAudioUrl;
  ReviewStoredGlossaryTerm copyWith({
    String? termId,
    ReviewLocalizedText? text,
    String? arabic,
    String? transliteration,
    ReviewGlossaryDefinitions? definition,
    ReviewLocalizedSpans? example,
    String? conceptId,
    String? lessonId,
    String? sourceId,
    String? pronunciationAudioUrl,
  }) => ReviewStoredGlossaryTerm(
    termId: termId ?? this.termId,
    text: text ?? this.text,
    arabic: arabic ?? this.arabic,
    transliteration: transliteration ?? this.transliteration,
    definition: definition ?? this.definition,
    example: example ?? this.example,
    conceptId: conceptId ?? this.conceptId,
    lessonId: lessonId ?? this.lessonId,
    sourceId: sourceId ?? this.sourceId,
    pronunciationAudioUrl: pronunciationAudioUrl ?? this.pronunciationAudioUrl,
  );
  @override
  List<Object?> get props => [
    termId,
    text,
    arabic,
    transliteration,
    definition,
    example,
    conceptId,
    lessonId,
    sourceId,
    pronunciationAudioUrl,
  ];
}

final class ReviewTargetMisconception extends Equatable {
  const ReviewTargetMisconception({required this.misconceptionId, required this.title, required this.description});
  final String? misconceptionId;
  final ReviewLocalizedText title;
  final ReviewLocalizedText description;
  ReviewTargetMisconception copyWith({String? misconceptionId, ReviewLocalizedText? title, ReviewLocalizedText? description}) =>
      ReviewTargetMisconception(
        misconceptionId: misconceptionId ?? this.misconceptionId,
        title: title ?? this.title,
        description: description ?? this.description,
      );
  @override
  List<Object?> get props => [misconceptionId, title, description];
}

final class ReviewVisualAudit extends Equatable {
  ReviewVisualAudit({required this.passed, required List<String> issues}) : issues = List.unmodifiable(issues);
  final bool passed;
  final List<String> issues;
  ReviewVisualAudit copyWith({bool? passed, List<String>? issues}) =>
      ReviewVisualAudit(passed: passed ?? this.passed, issues: issues ?? this.issues);
  @override
  List<Object?> get props => [passed, issues];
}

final class ReviewReviewerExercise extends Equatable {
  ReviewReviewerExercise(this.exercise, this.answerKey, Map<String, String> optionMisconceptions, this.duelEligible)
    : optionMisconceptions = Map.unmodifiable(optionMisconceptions);
  final Exercise exercise;
  final AnswerPayload? answerKey;
  final Map<String, String> optionMisconceptions;
  final bool duelEligible;
  @override
  List<Object?> get props => [exercise, answerKey, optionMisconceptions, duelEligible];
}
