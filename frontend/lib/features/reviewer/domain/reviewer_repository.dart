import 'package:equatable/equatable.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/features/reviewer/domain/reviewer_models.dart';
import 'package:qabas/shared/domain/entities/user_profile.dart';

final class ReviewerRunPage extends Equatable {
  ReviewerRunPage(List<ReviewRunRow> items, this.nextCursor) : items = List.unmodifiable(items);
  final List<ReviewRunRow> items;
  final String? nextCursor;
  @override
  List<Object?> get props => [items, nextCursor];
}

abstract interface class ReviewerRepository {
  Future<Result<UserProfile>> signIn(String email, String password);
  Future<Result<void>> signOut();
  Future<Result<ReviewerRunPage>> runs({String? status, String? cursor});
  Future<Result<ReviewFactoryRun>> run(String id);
  Future<Result<ReviewFactoryRun>> create(ReviewRunCreate request, String key);
  Future<Result<ReviewFactoryRun>> gate1(String id, ReviewGate1 request);
  Future<Result<ReviewFactoryRun>> gate2(String id, ReviewGate2 request);
  Future<Result<void>> regenerate(String id, String sceneId, String? reason);
  Future<Result<ReviewBlindPair?>> blindPair();
  Future<Result<void>> blindAnswer(String id, ReviewBlindAnswer answer);
  Future<Result<ReviewMetrics>> metrics();
  String newKey();
}
