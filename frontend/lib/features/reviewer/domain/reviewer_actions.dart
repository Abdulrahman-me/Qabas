import 'package:qabas/features/reviewer/domain/reviewer_repository.dart';

/// Flow operations share one repository; credentials and wire shapes stay in data.
final class ReviewerActions {
  const ReviewerActions(this.repository);
  final ReviewerRepository repository;
}
