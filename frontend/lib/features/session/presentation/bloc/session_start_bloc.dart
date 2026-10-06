import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/features/session/domain/entities/session.dart';
import 'package:qabas/features/session/domain/usecases/session_actions.dart';

enum SessionStartStatus { initial, loading, ready, empty, failure }

final class SessionStartState extends Equatable {
  const SessionStartState({this.status = SessionStartStatus.initial, this.session, this.failure});
  final SessionStartStatus status;
  final Session? session;
  final Failure? failure;
  @override
  List<Object?> get props => [status, session, failure];
}

final class SessionStartRequested {
  const SessionStartRequested({required this.kind, this.mode, this.unitId});
  final SessionKind kind;
  final String? mode, unitId;
}

final class SessionStartBloc extends Bloc<SessionStartRequested, SessionStartState> {
  SessionStartBloc(this.start) : super(const SessionStartState()) {
    on<SessionStartRequested>((e, emit) async {
      emit(const SessionStartState(status: SessionStartStatus.loading));
      final r = await start(kind: e.kind, mode: e.mode, unitId: e.unitId);
      if (emit.isDone) return;
      switch (r) {
        case Ok(:final value):
          emit(SessionStartState(status: SessionStartStatus.ready, session: value));
        case Err(:final failure):
          emit(
            SessionStartState(
              status: failure is ConflictFailure && failure.code == 'nothing_to_review'
                  ? SessionStartStatus.empty
                  : SessionStartStatus.failure,
              failure: failure,
            ),
          );
      }
    }, transformer: droppable());
  }
  final StartSessionFlow start;
}
