import 'package:qabas/features/reviewer/domain/reviewer_models.dart';

Map<String, Object?> encodeReviewLocalizedText(ReviewLocalizedText v) => {'ar': v.ar, 'en': v.en};
Map<String, Object?> encodeReviewTargetMisconception(ReviewTargetMisconception v) => {
  'misconception_id': v.misconceptionId,
  'title': encodeReviewLocalizedText(v.title),
  'description': encodeReviewLocalizedText(v.description),
};
Map<String, Object?> encodeReviewArcStep(ReviewArcStep v) => {
  'step_id': v.stepId,
  'technique': v.technique,
  'experience': encodeReviewLocalizedText(v.experience),
  'interactive': v.interactive,
};
Map<String, Object?> encodeReviewLessonArc(ReviewLessonArc v) => {
  'pattern': v.pattern,
  'rationale': encodeReviewLocalizedText(v.rationale),
  'steps': v.steps.map((e) => encodeReviewArcStep(e)).toList(),
};
Map<String, Object?> encodeReviewReasoningToolUse(ReviewReasoningToolUse v) => {
  'tool': v.tool,
  'justification': encodeReviewLocalizedText(v.justification),
};
Map<String, Object?> encodeReviewLessonPlan(ReviewLessonPlan v) => {
  'title': encodeReviewLocalizedText(v.title),
  'central_question': encodeReviewLocalizedText(v.centralQuestion),
  'primary_learning_outcome': encodeReviewLocalizedText(v.primaryLearningOutcome),
  'supporting_understandings': v.supportingUnderstandings.map((e) => encodeReviewLocalizedText(e)).toList(),
  'depth_profile': v.depthProfile,
  'objectives': v.objectives.map((e) => encodeReviewLocalizedText(e)).toList(),
  'prerequisite_concept_ids': v.prerequisiteConceptIds.map((e) => e).toList(),
  'introduced_concept_ids': v.introducedConceptIds.map((e) => e).toList(),
  'new_terms': v.newTerms.map((e) => encodeReviewLocalizedText(e)).toList(),
  'target_misconceptions': v.targetMisconceptions.map((e) => encodeReviewTargetMisconception(e)).toList(),
  'lesson_type': v.lessonType,
  'estimated_minutes': v.estimatedMinutes,
  'lesson_arc': encodeReviewLessonArc(v.lessonArc),
  'reasoning_tools': v.reasoningTools.map((e) => encodeReviewReasoningToolUse(e)).toList(),
  'standalone_eligible': v.standaloneEligible,
  'content_budget': v.contentBudget,
  'exercise_budget': v.exerciseBudget,
};
Map<String, Object?> encodeReviewGate1(ReviewGate1 v) => {
  'decision': v.decision,
  'plan': v.plan == null ? null : encodeReviewLessonPlan(v.plan!),
  'reason': v.reason,
  'review_digest': v.reviewDigest,
};
Map<String, Object?> encodeReviewSentenceEdit(ReviewSentenceEdit v) => {
  'sentence_id': v.sentenceId,
  'language': v.language,
  'variant': v.variant,
  'new_text': v.newText,
};
Map<String, Object?> encodeReviewGate2(ReviewGate2 v) => {
  'decision': v.decision,
  'sentence_edits': v.sentenceEdits.map((e) => encodeReviewSentenceEdit(e)).toList(),
  'exercise_removals': v.exerciseRemovals.map((e) => e).toList(),
  'reason': v.reason,
  'review_digest': v.reviewDigest,
};
Map<String, Object?> encodeReviewRunCreate(ReviewRunCreate v) => {
  'unit_id': v.unitId,
  'lesson_type': v.lessonType,
  'brief': v.brief,
  'position_index': v.positionIndex,
};
Map<String, Object?> encodeReviewBlindAnswer(ReviewBlindAnswer v) => {
  'clearer': v.clearer,
  'more_accurate': v.moreAccurate,
  'guessed_handwritten': v.guessedHandwritten,
};
