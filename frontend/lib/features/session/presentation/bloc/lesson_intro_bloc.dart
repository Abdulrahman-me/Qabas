import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/features/session/domain/entities/session.dart';
import 'package:qabas/features/session/domain/usecases/session_actions.dart';
import 'package:qabas/shared/domain/entities/journey.dart';
import 'package:qabas/shared/domain/usecases/journey_actions.dart';

enum LessonIntroStatus { initial, loading, ready, locked, failure }

final class LessonIntroState extends Equatable {
  const LessonIntroState({this.status = LessonIntroStatus.initial, this.start, this.failure, this.softLock});
  final LessonIntroStatus status;
  final SessionStart? start;
  final Failure? failure;
  final SoftLock? softLock;
  @override
  List<Object?> get props => [status, start, failure, softLock];
}

sealed class LessonIntroEvent {
  const LessonIntroEvent();
}

final class LessonIntroOpened extends LessonIntroEvent {
  const LessonIntroOpened(this.lessonId);
  final String lessonId;
}

final class LessonIntroRetried extends LessonIntroEvent {
  const LessonIntroRetried();
}

final class LessonIntroBloc extends Bloc<LessonIntroEvent, LessonIntroState> {
  LessonIntroBloc(this.startLesson, this.getJourney, this.resolveLock) : super(const LessonIntroState()) {
    on<LessonIntroEvent>((e, emit) async {
      if (e is LessonIntroOpened) _lessonId = e.lessonId;
      final id = _lessonId;
      if (id == null) return;
      emit(const LessonIntroState(status: LessonIntroStatus.loading));
      final result = await startLesson(id);
      if (emit.isDone) return;
      switch (result) {
        case Ok(:final value):
          emit(LessonIntroState(status: LessonIntroStatus.ready, start: value));
        case Err(:final failure):
          SoftLock? lock;
          if (failure is ConflictFailure && failure.code == 'prerequisite_unmet') {
            await getJourney(refresh: true);
            if (emit.isDone) return;
            lock = resolveLock(failure);
          }
          emit(
            LessonIntroState(status: lock == null ? LessonIntroStatus.failure : LessonIntroStatus.locked, failure: failure, softLock: lock),
          );
      }
    }, transformer: droppable());
  }
  final StartLessonSession startLesson;
  final GetJourney getJourney;
  final SoftLock? Function(ConflictFailure) resolveLock;
  String? _lessonId;
}
