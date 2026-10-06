import 'package:qabas/core/error/result.dart';
import 'package:qabas/features/session/domain/entities/exercise.dart';
import 'package:qabas/features/session/domain/entities/session.dart';
import 'package:qabas/features/session/domain/entities/session_result.dart';
import 'package:qabas/features/session/domain/repositories/exercise_repository.dart';
import 'package:qabas/features/session/domain/repositories/session_repository.dart';

final class StartLessonSession {
  const StartLessonSession(this.repository);
  final SessionRepository repository;
  Future<Result<SessionStart>> call(String lessonId) => repository.startLesson(lessonId);
}

final class LoadSession {
  const LoadSession(this.repository);
  final SessionRepository repository;
  Future<Result<Session>> call(String id) => repository.load(id);
}

final class SubmitAnswer {
  const SubmitAnswer(this.repository);
  final ExerciseRepository repository;
  Future<Result<AnswerResponse>> call(
    String id,
    Exercise exercise,
    AnswerPayload answer,
    Duration elapsed, {
    required bool isRetry,
    required bool immediate,
  }) => repository.submit(id, exercise, answer, elapsed, isRetry: isRetry, immediate: immediate);
}

final class FinishSession {
  const FinishSession(this.repository);
  final ExerciseRepository repository;
  Future<Result<SessionResult>> call(String id, Duration duration) => repository.finish(id, duration);
}

final class StartSessionFlow {
  const StartSessionFlow(this.repository);
  final SessionFlowRepository repository;
  Future<Result<Session>> call({required SessionKind kind, String? mode, String? unitId}) =>
      repository.startFlow(kind: kind, mode: mode, unitId: unitId);
}

final class AbandonSession {
  const AbandonSession(this.repository);
  final SessionFlowRepository repository;
  Future<Result<void>> call(String id) => repository.abandon(id);
}
