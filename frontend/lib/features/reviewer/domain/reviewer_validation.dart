import 'package:qabas/features/reviewer/domain/reviewer_models.dart';

bool validReviewPlan(ReviewLessonPlan p) {
  bool filled(ReviewLocalizedText t) => t.ar.trim().isNotEmpty && t.en.trim().isNotEmpty;
  return filled(p.title) &&
      filled(p.centralQuestion) &&
      filled(p.primaryLearningOutcome) &&
      p.supportingUnderstandings.every(filled) &&
      p.objectives.isNotEmpty &&
      p.objectives.length <= 3 &&
      p.objectives.every(filled) &&
      p.estimatedMinutes >= 1 &&
      p.contentBudget >= 1 &&
      p.exerciseBudget >= 2 &&
      p.exerciseBudget <= 6 &&
      (!p.standaloneEligible || p.prerequisiteConceptIds.isEmpty) &&
      !p.prerequisiteConceptIds.any(p.introducedConceptIds.contains) &&
      p.lessonArc.steps.length >= 2 &&
      p.lessonArc.steps.any((s) => s.interactive) &&
      p.lessonArc.steps.where((s) => s.technique == 'takeaway').length <= 1 &&
      p.lessonArc.steps.map((s) => s.stepId).toSet().length == p.lessonArc.steps.length &&
      p.lessonArc.steps.every((s) => filled(s.experience)) &&
      p.reasoningTools.every((s) => filled(s.justification)) &&
      p.reasoningTools.map((s) => s.tool).toSet().length == p.reasoningTools.length &&
      (!['story', 'practice'].contains(p.lessonType) || p.lessonArc.steps.any((s) => s.technique == p.lessonType));
}
