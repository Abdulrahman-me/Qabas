import 'package:qabas/core/error/result.dart';
import 'package:qabas/features/session/domain/entities/session.dart';

abstract interface class SessionRepository {
  Future<Result<SessionStart>> startLesson(String lessonId);
  Future<Result<Session>> load(String sessionId);
}

abstract interface class SessionFlowRepository {
  Future<Result<Session>> startFlow({required SessionKind kind, String? mode, String? unitId});
  Future<Result<void>> abandon(String id);
}

abstract interface class LessonReaderRepository {
  Future<Result<LessonReader>> reader(String id);
}
