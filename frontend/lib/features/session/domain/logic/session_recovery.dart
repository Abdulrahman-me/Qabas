import 'package:equatable/equatable.dart';
import 'package:qabas/features/session/domain/entities/exercise.dart';
import 'package:qabas/features/session/domain/entities/session.dart';

/// Contract §6.5.5: first attempts in authored order, never retry timestamps.
({int cursor, List<ExerciseItem> retries, Set<String> completed}) recoverSession(Session session) {
  final first = {
    for (final a in session.answers)
      if (!a.isRetry) a.exerciseId: a,
  };
  final retried = session.answers.where((a) => a.isRetry).map((a) => a.exerciseId).toSet();
  var prefix = -1;
  var gap = false;
  final queue = <ExerciseItem>[];
  for (var i = 0; i < session.items.length; i++) {
    final item = session.items[i];
    if (item is! ExerciseItem) continue;
    final answer = first[item.exerciseId];
    if (answer == null) {
      gap = true;
    } else if (!gap) {
      prefix = i;
    }
    if (session.kind == SessionKind.lesson &&
        session.feedbackMode == FeedbackMode.immediate &&
        answer?.result == 'incorrect' &&
        !retried.contains(item.exerciseId) &&
        ![ExerciseType.reciteVerse, ExerciseType.flashcard].contains(item.exercise?.type)) {
      queue.add(item);
    }
  }
  return (
    cursor: prefix + 1,
    retries: queue,
    completed: {
      for (var i = 0; i <= prefix; i++) session.items[i].blockId,
      for (final item in session.items.whereType<ExerciseItem>())
        if (first.containsKey(item.exerciseId)) item.blockId,
    },
  );
}

final class SessionCheckpoint extends Equatable {
  SessionCheckpoint({
    required this.cursor,
    required this.stage,
    required Set<String> completed,
    required List<String> retries,
    required this.retryCursor,
    required this.inRetry,
    required this.combo,
    required Map<String, String> predictions,
    this.feedbackExercise,
    this.timerDeadline,
    this.answer,
  }) : completed = Set.unmodifiable(completed),
       retries = List.unmodifiable(retries),
       predictions = Map.unmodifiable(predictions);
  final int cursor, retryCursor, combo;
  final String stage;
  final Set<String> completed;
  final List<String> retries;
  final bool inRetry;
  final Map<String, String> predictions;
  final String? feedbackExercise;
  final DateTime? timerDeadline;
  final AnswerPayload? answer;
  @override
  List<Object?> get props => [
    cursor,
    stage,
    completed,
    retries,
    retryCursor,
    inRetry,
    combo,
    predictions,
    feedbackExercise,
    timerDeadline,
    answer,
  ];
}

abstract interface class SessionCheckpointStore {
  Future<SessionCheckpoint?> read(String id, int? version);
  Future<void> write(String id, int? version, SessionCheckpoint checkpoint);
  Future<void> remove(String id);
}
