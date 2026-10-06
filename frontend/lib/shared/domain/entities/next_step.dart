import 'package:equatable/equatable.dart';

enum NextStepType { pretest, lesson, review, unitTest, journeyComplete, unknown }

enum NextStepReason { newUnitPretest, dueReviews, nextLesson, unitReadyForTest, allDone, unknown }

final class NextStep extends Equatable {
  const NextStep({
    required this.type,
    required this.reason,
    required this.unitId,
    required this.lessonId,
    required this.title,
    required this.dueReviewsCount,
  });
  final NextStepType type;
  final NextStepReason reason;
  final String? unitId, lessonId, title;
  final int dueReviewsCount;
  @override
  List<Object?> get props => [type, reason, unitId, lessonId, title, dueReviewsCount];
}
