// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reviewer_dtos.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReviewAnimationPreviewDto _$ReviewAnimationPreviewDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ReviewAnimationPreviewDto', json, ($checkedConvert) {
      final val = ReviewAnimationPreviewDto(
        url: $checkedConvert('url', (v) => v as String),
        mimeType: $checkedConvert('mime_type', (v) => v as String),
        width: $checkedConvert('width', (v) => (v as num).toInt()),
        height: $checkedConvert('height', (v) => (v as num).toInt()),
        durationMs: $checkedConvert('duration_ms', (v) => (v as num).toInt()),
      );
      return val;
    }, fieldKeyMap: const {'mimeType': 'mime_type', 'durationMs': 'duration_ms'});

ReviewArcStepDto _$ReviewArcStepDtoFromJson(Map<String, dynamic> json) => $checkedCreate('ReviewArcStepDto', json, ($checkedConvert) {
  final val = ReviewArcStepDto(
    stepId: $checkedConvert('step_id', (v) => v as String),
    technique: $checkedConvert('technique', (v) => v as String),
    experience: $checkedConvert('experience', (v) => ReviewLocalizedTextDto.fromJson(v as Map<String, dynamic>)),
    interactive: $checkedConvert('interactive', (v) => v as bool),
  );
  return val;
}, fieldKeyMap: const {'stepId': 'step_id'});

ReviewArcStepBlocksDto _$ReviewArcStepBlocksDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ReviewArcStepBlocksDto', json, ($checkedConvert) {
      final val = ReviewArcStepBlocksDto(
        stepId: $checkedConvert('step_id', (v) => v as String),
        blockIds: $checkedConvert('block_ids', (v) => (v as List<dynamic>).map((e) => e as String).toList()),
      );
      return val;
    }, fieldKeyMap: const {'stepId': 'step_id', 'blockIds': 'block_ids'});

ReviewBenchmarkClassDto _$ReviewBenchmarkClassDtoFromJson(Map<String, dynamic> json) => $checkedCreate(
  'ReviewBenchmarkClassDto',
  json,
  ($checkedConvert) {
    final val = ReviewBenchmarkClassDto(
      questionClass: $checkedConvert('question_class', (v) => v as String),
      raqeebAccuracyPercent: $checkedConvert('raqeeb_accuracy_percent', (v) => (v as num).toInt()),
      baselineAccuracyPercent: $checkedConvert('baseline_accuracy_percent', (v) => (v as num).toInt()),
    );
    return val;
  },
  fieldKeyMap: const {
    'questionClass': 'question_class',
    'raqeebAccuracyPercent': 'raqeeb_accuracy_percent',
    'baselineAccuracyPercent': 'baseline_accuracy_percent',
  },
);

ReviewBenchmarkMetricsDto _$ReviewBenchmarkMetricsDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ReviewBenchmarkMetricsDto', json, ($checkedConvert) {
      final val = ReviewBenchmarkMetricsDto(
        runAt: $checkedConvert('run_at', (v) => v as String),
        questionCount: $checkedConvert('question_count', (v) => (v as num).toInt()),
        systems: $checkedConvert(
          'systems',
          (v) => (v as List<dynamic>).map((e) => ReviewBenchmarkSystemDto.fromJson(e as Map<String, dynamic>)).toList(),
        ),
        byClass: $checkedConvert(
          'by_class',
          (v) => (v as List<dynamic>).map((e) => ReviewBenchmarkClassDto.fromJson(e as Map<String, dynamic>)).toList(),
        ),
      );
      return val;
    }, fieldKeyMap: const {'runAt': 'run_at', 'questionCount': 'question_count', 'byClass': 'by_class'});

ReviewBenchmarkSystemDto _$ReviewBenchmarkSystemDtoFromJson(Map<String, dynamic> json) => $checkedCreate(
  'ReviewBenchmarkSystemDto',
  json,
  ($checkedConvert) {
    final val = ReviewBenchmarkSystemDto(
      name: $checkedConvert('name', (v) => v as String),
      accuracyPercent: $checkedConvert('accuracy_percent', (v) => (v as num).toInt()),
      unsupportedClaimRatePercent: $checkedConvert('unsupported_claim_rate_percent', (v) => (v as num).toInt()),
      correctAbstentionPercent: $checkedConvert('correct_abstention_percent', (v) => (v as num).toInt()),
      correctReferralPercent: $checkedConvert('correct_referral_percent', (v) => (v as num).toInt()),
    );
    return val;
  },
  fieldKeyMap: const {
    'accuracyPercent': 'accuracy_percent',
    'unsupportedClaimRatePercent': 'unsupported_claim_rate_percent',
    'correctAbstentionPercent': 'correct_abstention_percent',
    'correctReferralPercent': 'correct_referral_percent',
  },
);

ReviewBlindAnswerDto _$ReviewBlindAnswerDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ReviewBlindAnswerDto', json, ($checkedConvert) {
      final val = ReviewBlindAnswerDto(
        clearer: $checkedConvert('clearer', (v) => v as String),
        moreAccurate: $checkedConvert('more_accurate', (v) => v as String),
        guessedHandwritten: $checkedConvert('guessed_handwritten', (v) => v as String),
      );
      return val;
    }, fieldKeyMap: const {'moreAccurate': 'more_accurate', 'guessedHandwritten': 'guessed_handwritten'});

ReviewBlindLessonDto _$ReviewBlindLessonDtoFromJson(Map<String, dynamic> json) => $checkedCreate('ReviewBlindLessonDto', json, (
  $checkedConvert,
) {
  final val = ReviewBlindLessonDto(
    title: $checkedConvert('title', (v) => v as String),
    objectives: $checkedConvert(
      'objectives',
      (v) =>
          (v as List<dynamic>).map((e) => (e as List<dynamic>).map((e) => SpanDto.fromJson(e as Map<String, dynamic>)).toList()).toList(),
    ),
    items: $checkedConvert('items', (v) => (v as List<dynamic>).map((e) => BlockDto.fromJson(e as Map<String, dynamic>)).toList()),
    completion: $checkedConvert('completion', (v) => v == null ? null : CompletionDto.fromJson(v as Map<String, dynamic>)),
  );
  return val;
});

ReviewBlindMetricsDto _$ReviewBlindMetricsDtoFromJson(Map<String, dynamic> json) => $checkedCreate(
  'ReviewBlindMetricsDto',
  json,
  ($checkedConvert) {
    final val = ReviewBlindMetricsDto(
      responses: $checkedConvert('responses', (v) => (v as num).toInt()),
      handwrittenIdentifiedPercent: $checkedConvert('handwritten_identified_percent', (v) => (v as num?)?.toInt()),
      generatedPreferredOrSamePercent: $checkedConvert('generated_preferred_or_same_percent', (v) => (v as num?)?.toInt()),
    );
    return val;
  },
  fieldKeyMap: const {
    'handwrittenIdentifiedPercent': 'handwritten_identified_percent',
    'generatedPreferredOrSamePercent': 'generated_preferred_or_same_percent',
  },
);

ReviewBlindPairDto _$ReviewBlindPairDtoFromJson(Map<String, dynamic> json) => $checkedCreate('ReviewBlindPairDto', json, ($checkedConvert) {
  final val = ReviewBlindPairDto(
    pairId: $checkedConvert('pair_id', (v) => v as String),
    lessonA: $checkedConvert('lesson_a', (v) => ReviewBlindLessonDto.fromJson(v as Map<String, dynamic>)),
    lessonB: $checkedConvert('lesson_b', (v) => ReviewBlindLessonDto.fromJson(v as Map<String, dynamic>)),
  );
  return val;
}, fieldKeyMap: const {'pairId': 'pair_id', 'lessonA': 'lesson_a', 'lessonB': 'lesson_b'});

ReviewClaimDto _$ReviewClaimDtoFromJson(Map<String, dynamic> json) => $checkedCreate('ReviewClaimDto', json, ($checkedConvert) {
  final val = ReviewClaimDto(
    claimId: $checkedConvert('claim_id', (v) => v as String),
    text: $checkedConvert('text', (v) => v as String),
    status: $checkedConvert('status', (v) => v as String),
    basis: $checkedConvert('basis', (v) => v as String),
    evidence: $checkedConvert(
      'evidence',
      (v) => (v as List<dynamic>).map((e) => ReviewClaimEvidenceDto.fromJson(e as Map<String, dynamic>)).toList(),
    ),
    reasoning: $checkedConvert('reasoning', (v) => v == null ? null : ReviewReasoningSupportDto.fromJson(v as Map<String, dynamic>)),
  );
  return val;
}, fieldKeyMap: const {'claimId': 'claim_id'});

ReviewClaimEvidenceDto _$ReviewClaimEvidenceDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ReviewClaimEvidenceDto', json, ($checkedConvert) {
      final val = ReviewClaimEvidenceDto(
        source: $checkedConvert('source', (v) => SourceDto.fromJson(v as Map<String, dynamic>)),
        supports: $checkedConvert('supports', (v) => v as bool),
        verifierNote: $checkedConvert('verifier_note', (v) => v as String),
        semanticReview: $checkedConvert(
          'semantic_review',
          (v) => v == null ? null : ReviewSemanticReviewDto.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    }, fieldKeyMap: const {'verifierNote': 'verifier_note', 'semanticReview': 'semantic_review'});

ReviewCompletionMetricsDto _$ReviewCompletionMetricsDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ReviewCompletionMetricsDto', json, ($checkedConvert) {
      final val = ReviewCompletionMetricsDto(
        unitsStarted: $checkedConvert('units_started', (v) => (v as num).toInt()),
        unitsCompleted: $checkedConvert('units_completed', (v) => (v as num).toInt()),
      );
      return val;
    }, fieldKeyMap: const {'unitsStarted': 'units_started', 'unitsCompleted': 'units_completed'});

ReviewDraftDto _$ReviewDraftDtoFromJson(Map<String, dynamic> json) => $checkedCreate('ReviewDraftDto', json, ($checkedConvert) {
  final val = ReviewDraftDto(
    languages: $checkedConvert('languages', (v) => (v as List<dynamic>).map((e) => e as String).toList()),
    variants: $checkedConvert('variants', (v) => (v as List<dynamic>).map((e) => e as String).toList()),
    previews: $checkedConvert(
      'previews',
      (v) => (v as List<dynamic>).map((e) => ReviewPreviewDto.fromJson(e as Map<String, dynamic>)).toList(),
    ),
    claims: $checkedConvert('claims', (v) => (v as List<dynamic>).map((e) => ReviewClaimDto.fromJson(e as Map<String, dynamic>)).toList()),
    sentenceMap: $checkedConvert(
      'sentence_map',
      (v) => (v as List<dynamic>).map((e) => ReviewSentenceClaimsDto.fromJson(e as Map<String, dynamic>)).toList(),
    ),
    arcMap: $checkedConvert(
      'arc_map',
      (v) => (v as List<dynamic>).map((e) => ReviewArcStepBlocksDto.fromJson(e as Map<String, dynamic>)).toList(),
    ),
    exercises: $checkedConvert(
      'exercises',
      (v) => (v as List<dynamic>).map((e) => ReviewReviewerExerciseDto.fromJson(e as Map<String, dynamic>)).toList(),
    ),
    glossary: $checkedConvert(
      'glossary',
      (v) => (v as List<dynamic>).map((e) => ReviewStoredGlossaryTermDto.fromJson(e as Map<String, dynamic>)).toList(),
    ),
    misconceptions: $checkedConvert(
      'misconceptions',
      (v) => (v as List<dynamic>).map((e) => ReviewMisconceptionDto.fromJson(e as Map<String, dynamic>)).toList(),
    ),
    visuals: $checkedConvert(
      'visuals',
      (v) => (v as List<dynamic>).map((e) => ReviewDraftVisualDto.fromJson(e as Map<String, dynamic>)).toList(),
    ),
  );
  return val;
}, fieldKeyMap: const {'sentenceMap': 'sentence_map', 'arcMap': 'arc_map'});

ReviewDraftFragmentDto _$ReviewDraftFragmentDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ReviewDraftFragmentDto', json, ($checkedConvert) {
      final val = ReviewDraftFragmentDto(
        draft: $checkedConvert('draft', (v) => ReviewDraftDto.fromJson(v as Map<String, dynamic>)),
        qaReport: $checkedConvert('qa_report', (v) => ReviewQAReportDto.fromJson(v as Map<String, dynamic>)),
      );
      return val;
    }, fieldKeyMap: const {'qaReport': 'qa_report'});

ReviewDraftVisualDto _$ReviewDraftVisualDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ReviewDraftVisualDto', json, ($checkedConvert) {
      final val = ReviewDraftVisualDto(
        sceneId: $checkedConvert('scene_id', (v) => v as String),
        origin: $checkedConvert('origin', (v) => v as String),
        visual: $checkedConvert('visual', (v) => VisualDto.fromJson(v as Map<String, dynamic>)),
        audit: $checkedConvert('audit', (v) => v == null ? null : ReviewVisualAuditDto.fromJson(v as Map<String, dynamic>)),
        attempts: $checkedConvert('attempts', (v) => (v as num).toInt()),
        previews: $checkedConvert('previews', (v) => v == null ? null : ReviewScenePreviewDto.fromJson(v as Map<String, dynamic>)),
      );
      return val;
    }, fieldKeyMap: const {'sceneId': 'scene_id'});

ReviewFactoryMetricsDto _$ReviewFactoryMetricsDtoFromJson(Map<String, dynamic> json) => $checkedCreate(
  'ReviewFactoryMetricsDto',
  json,
  ($checkedConvert) {
    final val = ReviewFactoryMetricsDto(
      lessonsPublished: $checkedConvert('lessons_published', (v) => (v as num).toInt()),
      avgGenerationMinutes: $checkedConvert('avg_generation_minutes', (v) => (v as num?)?.toInt()),
      avgReviewMinutes: $checkedConvert('avg_review_minutes', (v) => (v as num?)?.toInt()),
      blindTest: $checkedConvert('blind_test', (v) => ReviewBlindMetricsDto.fromJson(v as Map<String, dynamic>)),
    );
    return val;
  },
  fieldKeyMap: const {
    'lessonsPublished': 'lessons_published',
    'avgGenerationMinutes': 'avg_generation_minutes',
    'avgReviewMinutes': 'avg_review_minutes',
    'blindTest': 'blind_test',
  },
);

ReviewFactoryRunDto _$ReviewFactoryRunDtoFromJson(Map<String, dynamic> json) => $checkedCreate(
  'ReviewFactoryRunDto',
  json,
  ($checkedConvert) {
    final val = ReviewFactoryRunDto(
      runId: $checkedConvert('run_id', (v) => v as String),
      unitId: $checkedConvert('unit_id', (v) => v as String),
      lessonType: $checkedConvert('lesson_type', (v) => v as String),
      brief: $checkedConvert('brief', (v) => v as String),
      status: $checkedConvert('status', (v) => v as String),
      stage: $checkedConvert('stage', (v) => v as String),
      stages: $checkedConvert(
        'stages',
        (v) => (v as List<dynamic>).map((e) => ReviewStageStatusDto.fromJson(e as Map<String, dynamic>)).toList(),
      ),
      plan: $checkedConvert('plan', (v) => v == null ? null : ReviewLessonPlanDto.fromJson(v as Map<String, dynamic>)),
      draft: $checkedConvert('draft', (v) => v == null ? null : ReviewDraftDto.fromJson(v as Map<String, dynamic>)),
      qaReport: $checkedConvert('qa_report', (v) => v == null ? null : ReviewQAReportDto.fromJson(v as Map<String, dynamic>)),
      error: $checkedConvert('error', (v) => v == null ? null : ReviewRunErrorDto.fromJson(v as Map<String, dynamic>)),
      reviewDigest: $checkedConvert('review_digest', (v) => v as String?),
      published: $checkedConvert('published', (v) => v == null ? null : ReviewPublishedRefDto.fromJson(v as Map<String, dynamic>)),
    );
    return val;
  },
  fieldKeyMap: const {
    'runId': 'run_id',
    'unitId': 'unit_id',
    'lessonType': 'lesson_type',
    'qaReport': 'qa_report',
    'reviewDigest': 'review_digest',
  },
);

ReviewGate1Dto _$ReviewGate1DtoFromJson(Map<String, dynamic> json) => $checkedCreate('ReviewGate1Dto', json, ($checkedConvert) {
  final val = ReviewGate1Dto(
    decision: $checkedConvert('decision', (v) => v as String),
    plan: $checkedConvert('plan', (v) => v == null ? null : ReviewLessonPlanDto.fromJson(v as Map<String, dynamic>)),
    reason: $checkedConvert('reason', (v) => v as String?),
    reviewDigest: $checkedConvert('review_digest', (v) => v as String),
  );
  return val;
}, fieldKeyMap: const {'reviewDigest': 'review_digest'});

ReviewGate2Dto _$ReviewGate2DtoFromJson(Map<String, dynamic> json) => $checkedCreate(
  'ReviewGate2Dto',
  json,
  ($checkedConvert) {
    final val = ReviewGate2Dto(
      decision: $checkedConvert('decision', (v) => v as String),
      sentenceEdits: $checkedConvert(
        'sentence_edits',
        (v) => (v as List<dynamic>).map((e) => ReviewSentenceEditDto.fromJson(e as Map<String, dynamic>)).toList(),
      ),
      exerciseRemovals: $checkedConvert('exercise_removals', (v) => (v as List<dynamic>).map((e) => e as String).toList()),
      reason: $checkedConvert('reason', (v) => v as String?),
      reviewDigest: $checkedConvert('review_digest', (v) => v as String),
    );
    return val;
  },
  fieldKeyMap: const {'sentenceEdits': 'sentence_edits', 'exerciseRemovals': 'exercise_removals', 'reviewDigest': 'review_digest'},
);

ReviewGlossaryDefinitionsDto _$ReviewGlossaryDefinitionsDtoFromJson(Map<String, dynamic> json) => $checkedCreate(
  'ReviewGlossaryDefinitionsDto',
  json,
  ($checkedConvert) {
    final val = ReviewGlossaryDefinitionsDto(
      basic: $checkedConvert('basic', (v) => ReviewLocalizedSpansDto.fromJson(v as Map<String, dynamic>)),
      intermediate: $checkedConvert('intermediate', (v) => v == null ? null : ReviewLocalizedSpansDto.fromJson(v as Map<String, dynamic>)),
    );
    return val;
  },
);

ReviewImageDto _$ReviewImageDtoFromJson(Map<String, dynamic> json) => $checkedCreate('ReviewImageDto', json, ($checkedConvert) {
  final val = ReviewImageDto(
    url: $checkedConvert('url', (v) => v as String),
    mimeType: $checkedConvert('mime_type', (v) => v as String),
    width: $checkedConvert('width', (v) => (v as num).toInt()),
    height: $checkedConvert('height', (v) => (v as num).toInt()),
  );
  return val;
}, fieldKeyMap: const {'mimeType': 'mime_type'});

ReviewLearningMetricsDto _$ReviewLearningMetricsDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ReviewLearningMetricsDto', json, ($checkedConvert) {
      final val = ReviewLearningMetricsDto(
        prePost: $checkedConvert(
          'pre_post',
          (v) => (v as List<dynamic>).map((e) => ReviewPrePostDto.fromJson(e as Map<String, dynamic>)).toList(),
        ),
        misconceptions: $checkedConvert('misconceptions', (v) => ReviewMisconceptionMetricsDto.fromJson(v as Map<String, dynamic>)),
        completion: $checkedConvert('completion', (v) => ReviewCompletionMetricsDto.fromJson(v as Map<String, dynamic>)),
      );
      return val;
    }, fieldKeyMap: const {'prePost': 'pre_post'});

ReviewLessonArcDto _$ReviewLessonArcDtoFromJson(Map<String, dynamic> json) => $checkedCreate('ReviewLessonArcDto', json, ($checkedConvert) {
  final val = ReviewLessonArcDto(
    pattern: $checkedConvert('pattern', (v) => v as String),
    rationale: $checkedConvert('rationale', (v) => ReviewLocalizedTextDto.fromJson(v as Map<String, dynamic>)),
    steps: $checkedConvert('steps', (v) => (v as List<dynamic>).map((e) => ReviewArcStepDto.fromJson(e as Map<String, dynamic>)).toList()),
  );
  return val;
});

ReviewLessonPlanDto _$ReviewLessonPlanDtoFromJson(Map<String, dynamic> json) => $checkedCreate(
  'ReviewLessonPlanDto',
  json,
  ($checkedConvert) {
    final val = ReviewLessonPlanDto(
      title: $checkedConvert('title', (v) => ReviewLocalizedTextDto.fromJson(v as Map<String, dynamic>)),
      centralQuestion: $checkedConvert('central_question', (v) => ReviewLocalizedTextDto.fromJson(v as Map<String, dynamic>)),
      primaryLearningOutcome: $checkedConvert(
        'primary_learning_outcome',
        (v) => ReviewLocalizedTextDto.fromJson(v as Map<String, dynamic>),
      ),
      supportingUnderstandings: $checkedConvert(
        'supporting_understandings',
        (v) => (v as List<dynamic>).map((e) => ReviewLocalizedTextDto.fromJson(e as Map<String, dynamic>)).toList(),
      ),
      depthProfile: $checkedConvert('depth_profile', (v) => v as String),
      objectives: $checkedConvert(
        'objectives',
        (v) => (v as List<dynamic>).map((e) => ReviewLocalizedTextDto.fromJson(e as Map<String, dynamic>)).toList(),
      ),
      prerequisiteConceptIds: $checkedConvert('prerequisite_concept_ids', (v) => (v as List<dynamic>).map((e) => e as String).toList()),
      introducedConceptIds: $checkedConvert('introduced_concept_ids', (v) => (v as List<dynamic>).map((e) => e as String).toList()),
      newTerms: $checkedConvert(
        'new_terms',
        (v) => (v as List<dynamic>).map((e) => ReviewLocalizedTextDto.fromJson(e as Map<String, dynamic>)).toList(),
      ),
      targetMisconceptions: $checkedConvert(
        'target_misconceptions',
        (v) => (v as List<dynamic>).map((e) => ReviewTargetMisconceptionDto.fromJson(e as Map<String, dynamic>)).toList(),
      ),
      lessonType: $checkedConvert('lesson_type', (v) => v as String),
      estimatedMinutes: $checkedConvert('estimated_minutes', (v) => (v as num).toInt()),
      lessonArc: $checkedConvert('lesson_arc', (v) => ReviewLessonArcDto.fromJson(v as Map<String, dynamic>)),
      reasoningTools: $checkedConvert(
        'reasoning_tools',
        (v) => (v as List<dynamic>).map((e) => ReviewReasoningToolUseDto.fromJson(e as Map<String, dynamic>)).toList(),
      ),
      standaloneEligible: $checkedConvert('standalone_eligible', (v) => v as bool),
      contentBudget: $checkedConvert('content_budget', (v) => (v as num).toInt()),
      exerciseBudget: $checkedConvert('exercise_budget', (v) => (v as num).toInt()),
    );
    return val;
  },
  fieldKeyMap: const {
    'centralQuestion': 'central_question',
    'primaryLearningOutcome': 'primary_learning_outcome',
    'supportingUnderstandings': 'supporting_understandings',
    'depthProfile': 'depth_profile',
    'prerequisiteConceptIds': 'prerequisite_concept_ids',
    'introducedConceptIds': 'introduced_concept_ids',
    'newTerms': 'new_terms',
    'targetMisconceptions': 'target_misconceptions',
    'lessonType': 'lesson_type',
    'estimatedMinutes': 'estimated_minutes',
    'lessonArc': 'lesson_arc',
    'reasoningTools': 'reasoning_tools',
    'standaloneEligible': 'standalone_eligible',
    'contentBudget': 'content_budget',
    'exerciseBudget': 'exercise_budget',
  },
);

ReviewLocalizedSpansDto _$ReviewLocalizedSpansDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ReviewLocalizedSpansDto', json, ($checkedConvert) {
      final val = ReviewLocalizedSpansDto(
        ar: $checkedConvert('ar', (v) => (v as List<dynamic>).map((e) => SpanDto.fromJson(e as Map<String, dynamic>)).toList()),
        en: $checkedConvert('en', (v) => (v as List<dynamic>).map((e) => SpanDto.fromJson(e as Map<String, dynamic>)).toList()),
      );
      return val;
    });

ReviewLocalizedTextDto _$ReviewLocalizedTextDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ReviewLocalizedTextDto', json, ($checkedConvert) {
      final val = ReviewLocalizedTextDto(ar: $checkedConvert('ar', (v) => v as String), en: $checkedConvert('en', (v) => v as String));
      return val;
    });

ReviewMetricsDto _$ReviewMetricsDtoFromJson(Map<String, dynamic> json) => $checkedCreate('ReviewMetricsDto', json, ($checkedConvert) {
  final val = ReviewMetricsDto(
    learning: $checkedConvert('learning', (v) => ReviewLearningMetricsDto.fromJson(v as Map<String, dynamic>)),
    raqeebBenchmark: $checkedConvert(
      'raqeeb_benchmark',
      (v) => v == null ? null : ReviewBenchmarkMetricsDto.fromJson(v as Map<String, dynamic>),
    ),
    factory: $checkedConvert('factory', (v) => ReviewFactoryMetricsDto.fromJson(v as Map<String, dynamic>)),
  );
  return val;
}, fieldKeyMap: const {'raqeebBenchmark': 'raqeeb_benchmark'});

ReviewMisconceptionDto _$ReviewMisconceptionDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ReviewMisconceptionDto', json, ($checkedConvert) {
      final val = ReviewMisconceptionDto(
        misconceptionId: $checkedConvert('misconception_id', (v) => v as String),
        title: $checkedConvert('title', (v) => v as String),
        card: $checkedConvert('card', (v) => (v as List<dynamic>).map((e) => SpanDto.fromJson(e as Map<String, dynamic>)).toList()),
        sourceIds: $checkedConvert('source_ids', (v) => (v as List<dynamic>).map((e) => e as String).toList()),
      );
      return val;
    }, fieldKeyMap: const {'misconceptionId': 'misconception_id', 'sourceIds': 'source_ids'});

ReviewMisconceptionMetricsDto _$ReviewMisconceptionMetricsDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ReviewMisconceptionMetricsDto', json, ($checkedConvert) {
      final val = ReviewMisconceptionMetricsDto(
        activated: $checkedConvert('activated', (v) => (v as num).toInt()),
        resolved: $checkedConvert('resolved', (v) => (v as num).toInt()),
        resolutionRatePercent: $checkedConvert('resolution_rate_percent', (v) => (v as num?)?.toInt()),
      );
      return val;
    }, fieldKeyMap: const {'resolutionRatePercent': 'resolution_rate_percent'});

ReviewPrePostDto _$ReviewPrePostDtoFromJson(Map<String, dynamic> json) => $checkedCreate(
  'ReviewPrePostDto',
  json,
  ($checkedConvert) {
    final val = ReviewPrePostDto(
      unitId: $checkedConvert('unit_id', (v) => v as String),
      unitTitle: $checkedConvert('unit_title', (v) => v as String),
      participants: $checkedConvert('participants', (v) => (v as num).toInt()),
      preAvgPercent: $checkedConvert('pre_avg_percent', (v) => (v as num).toInt()),
      postAvgPercent: $checkedConvert('post_avg_percent', (v) => (v as num).toInt()),
      delta: $checkedConvert('delta', (v) => (v as num).toInt()),
    );
    return val;
  },
  fieldKeyMap: const {
    'unitId': 'unit_id',
    'unitTitle': 'unit_title',
    'preAvgPercent': 'pre_avg_percent',
    'postAvgPercent': 'post_avg_percent',
  },
);

ReviewPreviewDto _$ReviewPreviewDtoFromJson(Map<String, dynamic> json) => $checkedCreate('ReviewPreviewDto', json, ($checkedConvert) {
  final val = ReviewPreviewDto(
    language: $checkedConvert('language', (v) => v as String),
    variant: $checkedConvert('variant', (v) => v as String),
    objectives: $checkedConvert(
      'objectives',
      (v) =>
          (v as List<dynamic>).map((e) => (e as List<dynamic>).map((e) => SpanDto.fromJson(e as Map<String, dynamic>)).toList()).toList(),
    ),
    items: $checkedConvert('items', (v) => (v as List<dynamic>).map((e) => BlockDto.fromJson(e as Map<String, dynamic>)).toList()),
    completion: $checkedConvert('completion', (v) => v == null ? null : CompletionDto.fromJson(v as Map<String, dynamic>)),
  );
  return val;
});

ReviewPreviewFrameDto _$ReviewPreviewFrameDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ReviewPreviewFrameDto', json, ($checkedConvert) {
      final val = ReviewPreviewFrameDto(
        state: $checkedConvert('state', (v) => (v as Map<String, dynamic>).map((k, e) => MapEntry(k, e as Object))),
        timeMs: $checkedConvert('time_ms', (v) => (v as num).toInt()),
        reducedMotion: $checkedConvert('reduced_motion', (v) => v as bool),
        image: $checkedConvert('image', (v) => ReviewImageDto.fromJson(v as Map<String, dynamic>)),
      );
      return val;
    }, fieldKeyMap: const {'timeMs': 'time_ms', 'reducedMotion': 'reduced_motion'});

ReviewPreviewTimingDto _$ReviewPreviewTimingDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ReviewPreviewTimingDto', json, ($checkedConvert) {
      final val = ReviewPreviewTimingDto(
        buildRasterP95Ms: $checkedConvert('build_raster_p95_ms', (v) => (v as num).toDouble()),
        firstFrameMs: $checkedConvert('first_frame_ms', (v) => (v as num).toDouble()),
        device: $checkedConvert('device', (v) => v as String),
      );
      return val;
    }, fieldKeyMap: const {'buildRasterP95Ms': 'build_raster_p95_ms', 'firstFrameMs': 'first_frame_ms'});

ReviewPublishedRefDto _$ReviewPublishedRefDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ReviewPublishedRefDto', json, ($checkedConvert) {
      final val = ReviewPublishedRefDto(
        lessonId: $checkedConvert('lesson_id', (v) => v as String),
        version: $checkedConvert('version', (v) => (v as num).toInt()),
      );
      return val;
    }, fieldKeyMap: const {'lessonId': 'lesson_id'});

ReviewQAIssueDto _$ReviewQAIssueDtoFromJson(Map<String, dynamic> json) => $checkedCreate('ReviewQAIssueDto', json, ($checkedConvert) {
  final val = ReviewQAIssueDto(
    severity: $checkedConvert('severity', (v) => v as String),
    kind: $checkedConvert('kind', (v) => v as String),
    location: $checkedConvert('location', (v) => ReviewQALocationDto.fromJson(v as Map<String, dynamic>)),
    message: $checkedConvert('message', (v) => v as String),
  );
  return val;
});

ReviewQALocationDto _$ReviewQALocationDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ReviewQALocationDto', json, ($checkedConvert) {
      final val = ReviewQALocationDto(
        sentenceId: $checkedConvert('sentence_id', (v) => v as String?),
        exerciseId: $checkedConvert('exercise_id', (v) => v as String?),
        sceneId: $checkedConvert('scene_id', (v) => v as String?),
      );
      return val;
    }, fieldKeyMap: const {'sentenceId': 'sentence_id', 'exerciseId': 'exercise_id', 'sceneId': 'scene_id'});

ReviewQAReportDto _$ReviewQAReportDtoFromJson(Map<String, dynamic> json) => $checkedCreate('ReviewQAReportDto', json, ($checkedConvert) {
  final val = ReviewQAReportDto(
    issues: $checkedConvert(
      'issues',
      (v) => (v as List<dynamic>).map((e) => ReviewQAIssueDto.fromJson(e as Map<String, dynamic>)).toList(),
    ),
  );
  return val;
});

ReviewReasoningSupportDto _$ReviewReasoningSupportDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ReviewReasoningSupportDto', json, ($checkedConvert) {
      final val = ReviewReasoningSupportDto(
        tool: $checkedConvert('tool', (v) => v as String),
        premises: $checkedConvert('premises', (v) => (v as List<dynamic>).map((e) => e as String).toList()),
        inference: $checkedConvert('inference', (v) => v as String),
      );
      return val;
    });

ReviewReasoningToolUseDto _$ReviewReasoningToolUseDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ReviewReasoningToolUseDto', json, ($checkedConvert) {
      final val = ReviewReasoningToolUseDto(
        tool: $checkedConvert('tool', (v) => v as String),
        justification: $checkedConvert('justification', (v) => ReviewLocalizedTextDto.fromJson(v as Map<String, dynamic>)),
      );
      return val;
    });

ReviewReviewerReqDto _$ReviewReviewerReqDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ReviewReviewerReqDto', json, ($checkedConvert) {
      final val = ReviewReviewerReqDto(
        email: $checkedConvert('email', (v) => v as String),
        password: $checkedConvert('password', (v) => v as String),
      );
      return val;
    });

ReviewRunCreateDto _$ReviewRunCreateDtoFromJson(Map<String, dynamic> json) => $checkedCreate('ReviewRunCreateDto', json, ($checkedConvert) {
  final val = ReviewRunCreateDto(
    unitId: $checkedConvert('unit_id', (v) => v as String),
    lessonType: $checkedConvert('lesson_type', (v) => v as String),
    brief: $checkedConvert('brief', (v) => v as String),
    positionIndex: $checkedConvert('position_index', (v) => (v as num).toInt()),
  );
  return val;
}, fieldKeyMap: const {'unitId': 'unit_id', 'lessonType': 'lesson_type', 'positionIndex': 'position_index'});

ReviewRunErrorDto _$ReviewRunErrorDtoFromJson(Map<String, dynamic> json) => $checkedCreate('ReviewRunErrorDto', json, ($checkedConvert) {
  final val = ReviewRunErrorDto(code: $checkedConvert('code', (v) => v as String), message: $checkedConvert('message', (v) => v as String));
  return val;
});

ReviewRunRowDto _$ReviewRunRowDtoFromJson(Map<String, dynamic> json) => $checkedCreate('ReviewRunRowDto', json, ($checkedConvert) {
  final val = ReviewRunRowDto(
    runId: $checkedConvert('run_id', (v) => v as String),
    unitId: $checkedConvert('unit_id', (v) => v as String),
    lessonType: $checkedConvert('lesson_type', (v) => v as String),
    title: $checkedConvert('title', (v) => v as String?),
    status: $checkedConvert('status', (v) => v as String),
    stage: $checkedConvert('stage', (v) => v as String),
    updatedAt: $checkedConvert('updated_at', (v) => v as String),
  );
  return val;
}, fieldKeyMap: const {'runId': 'run_id', 'unitId': 'unit_id', 'lessonType': 'lesson_type', 'updatedAt': 'updated_at'});

ReviewScenePreviewDto _$ReviewScenePreviewDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ReviewScenePreviewDto', json, ($checkedConvert) {
      final val = ReviewScenePreviewDto(
        frames: $checkedConvert(
          'frames',
          (v) => (v as List<dynamic>).map((e) => ReviewPreviewFrameDto.fromJson(e as Map<String, dynamic>)).toList(),
        ),
        animation: $checkedConvert('animation', (v) => ReviewAnimationPreviewDto.fromJson(v as Map<String, dynamic>)),
        reducedMotionStill: $checkedConvert('reduced_motion_still', (v) => ReviewImageDto.fromJson(v as Map<String, dynamic>)),
        fallbacks: $checkedConvert(
          'fallbacks',
          (v) => (v as List<dynamic>).map((e) => ReviewPreviewFrameDto.fromJson(e as Map<String, dynamic>)).toList(),
        ),
        timing: $checkedConvert('timing', (v) => ReviewPreviewTimingDto.fromJson(v as Map<String, dynamic>)),
        rendererVersion: $checkedConvert('renderer_version', (v) => v as String),
      );
      return val;
    }, fieldKeyMap: const {'reducedMotionStill': 'reduced_motion_still', 'rendererVersion': 'renderer_version'});

ReviewSemanticReviewDto _$ReviewSemanticReviewDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ReviewSemanticReviewDto', json, ($checkedConvert) {
      final val = ReviewSemanticReviewDto(
        fit: $checkedConvert('fit', (v) => v as String),
        concerns: $checkedConvert('concerns', (v) => (v as List<dynamic>).map((e) => e as String).toList()),
        note: $checkedConvert('note', (v) => v as String),
      );
      return val;
    });

ReviewSentenceClaimsDto _$ReviewSentenceClaimsDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ReviewSentenceClaimsDto', json, ($checkedConvert) {
      final val = ReviewSentenceClaimsDto(
        sentenceId: $checkedConvert('sentence_id', (v) => v as String),
        role: $checkedConvert('role', (v) => v as String),
        claimIds: $checkedConvert('claim_ids', (v) => (v as List<dynamic>).map((e) => e as String).toList()),
      );
      return val;
    }, fieldKeyMap: const {'sentenceId': 'sentence_id', 'claimIds': 'claim_ids'});

ReviewSentenceEditDto _$ReviewSentenceEditDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ReviewSentenceEditDto', json, ($checkedConvert) {
      final val = ReviewSentenceEditDto(
        sentenceId: $checkedConvert('sentence_id', (v) => v as String),
        language: $checkedConvert('language', (v) => v as String),
        variant: $checkedConvert('variant', (v) => v as String),
        newText: $checkedConvert('new_text', (v) => v as String),
      );
      return val;
    }, fieldKeyMap: const {'sentenceId': 'sentence_id', 'newText': 'new_text'});

ReviewStageStatusDto _$ReviewStageStatusDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ReviewStageStatusDto', json, ($checkedConvert) {
      final val = ReviewStageStatusDto(
        stage: $checkedConvert('stage', (v) => v as String),
        status: $checkedConvert('status', (v) => v as String),
        startedAt: $checkedConvert('started_at', (v) => v as String?),
        finishedAt: $checkedConvert('finished_at', (v) => v as String?),
      );
      return val;
    }, fieldKeyMap: const {'startedAt': 'started_at', 'finishedAt': 'finished_at'});

ReviewStoredGlossaryTermDto _$ReviewStoredGlossaryTermDtoFromJson(Map<String, dynamic> json) => $checkedCreate(
  'ReviewStoredGlossaryTermDto',
  json,
  ($checkedConvert) {
    final val = ReviewStoredGlossaryTermDto(
      termId: $checkedConvert('term_id', (v) => v as String),
      text: $checkedConvert('text', (v) => ReviewLocalizedTextDto.fromJson(v as Map<String, dynamic>)),
      arabic: $checkedConvert('arabic', (v) => v as String?),
      transliteration: $checkedConvert('transliteration', (v) => v as String),
      definition: $checkedConvert('definition', (v) => ReviewGlossaryDefinitionsDto.fromJson(v as Map<String, dynamic>)),
      example: $checkedConvert('example', (v) => ReviewLocalizedSpansDto.fromJson(v as Map<String, dynamic>)),
      conceptId: $checkedConvert('concept_id', (v) => v as String?),
      lessonId: $checkedConvert('lesson_id', (v) => v as String?),
      sourceId: $checkedConvert('source_id', (v) => v as String?),
      pronunciationAudioUrl: $checkedConvert('pronunciation_audio_url', (v) => v as String?),
    );
    return val;
  },
  fieldKeyMap: const {
    'termId': 'term_id',
    'conceptId': 'concept_id',
    'lessonId': 'lesson_id',
    'sourceId': 'source_id',
    'pronunciationAudioUrl': 'pronunciation_audio_url',
  },
);

ReviewTargetMisconceptionDto _$ReviewTargetMisconceptionDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ReviewTargetMisconceptionDto', json, ($checkedConvert) {
      final val = ReviewTargetMisconceptionDto(
        misconceptionId: $checkedConvert('misconception_id', (v) => v as String?),
        title: $checkedConvert('title', (v) => ReviewLocalizedTextDto.fromJson(v as Map<String, dynamic>)),
        description: $checkedConvert('description', (v) => ReviewLocalizedTextDto.fromJson(v as Map<String, dynamic>)),
      );
      return val;
    }, fieldKeyMap: const {'misconceptionId': 'misconception_id'});

ReviewVisualAuditDto _$ReviewVisualAuditDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ReviewVisualAuditDto', json, ($checkedConvert) {
      final val = ReviewVisualAuditDto(
        passed: $checkedConvert('passed', (v) => v as bool),
        issues: $checkedConvert('issues', (v) => (v as List<dynamic>).map((e) => e as String).toList()),
      );
      return val;
    });
