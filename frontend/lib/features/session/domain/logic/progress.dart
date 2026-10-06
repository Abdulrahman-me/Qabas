import 'package:qabas/features/session/domain/entities/session.dart';

double lessonProgress(Session session, Set<String> completedStepIds) => session.kind == SessionKind.lesson
    ? session.items.isEmpty
          ? 0
          : session.items.where((s) => completedStepIds.contains(s.blockId)).length / session.items.length
    : session.totalExercises == 0
    ? 0
    : session.items.whereType<ExerciseItem>().where((s) => completedStepIds.contains(s.blockId)).length / session.totalExercises;
