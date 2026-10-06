import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/features/session/domain/entities/session.dart';
import 'package:qabas/features/session/domain/repositories/session_repository.dart';

enum ReaderStatus { initial, loading, ready, failure }

final class ReaderState extends Equatable {
  const ReaderState({this.status = ReaderStatus.initial, this.lesson, this.cursor = 0, this.failure});
  final ReaderStatus status;
  final LessonReader? lesson;
  final int cursor;
  final Failure? failure;
  SessionItem? get item => lesson != null && cursor < lesson!.items.length ? lesson!.items[cursor] : null;
  @override
  List<Object?> get props => [status, lesson, cursor, failure];
}

sealed class ReaderEvent {
  const ReaderEvent();
}

final class ReaderOpened extends ReaderEvent {
  const ReaderOpened(this.id);
  final String id;
}

final class ReaderItemChanged extends ReaderEvent {
  const ReaderItemChanged(this.delta);
  final int delta;
}

final class LessonReaderBloc extends Bloc<ReaderEvent, ReaderState> {
  LessonReaderBloc(this.repository) : super(const ReaderState()) {
    on<ReaderOpened>((e, emit) async {
      emit(const ReaderState(status: ReaderStatus.loading));
      final r = await repository.reader(e.id);
      if (emit.isDone) return;
      switch (r) {
        case Ok(:final value):
          emit(ReaderState(status: ReaderStatus.ready, lesson: value));
        case Err(:final failure):
          emit(ReaderState(status: ReaderStatus.failure, failure: failure));
      }
    }, transformer: restartable());
    on<ReaderItemChanged>((e, emit) {
      if (state.lesson == null || state.lesson!.items.isEmpty) return;
      emit(
        ReaderState(
          status: ReaderStatus.ready,
          lesson: state.lesson,
          cursor: (state.cursor + e.delta).clamp(0, state.lesson!.items.length - 1),
        ),
      );
    });
  }
  final LessonReaderRepository repository;
}
