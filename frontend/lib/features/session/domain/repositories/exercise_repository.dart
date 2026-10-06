import 'package:qabas/core/error/result.dart';
import 'package:qabas/features/session/domain/entities/exercise.dart';
import 'package:qabas/features/session/domain/entities/session_result.dart';

abstract interface class ExerciseRepository {
  Future<Result<AnswerResponse>> submit(
    String sessionId,
    Exercise exercise,
    AnswerPayload answer,
    Duration elapsed, {
    required bool isRetry,
    required bool immediate,
  });
  Future<Result<SessionResult>> finish(String sessionId, Duration duration);
  SessionResult? result(String sessionId);
}
