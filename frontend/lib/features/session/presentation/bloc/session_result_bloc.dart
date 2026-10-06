import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/features/session/domain/entities/session.dart';
import 'package:qabas/features/session/domain/entities/session_result.dart';
import 'package:qabas/features/session/domain/usecases/session_actions.dart';

enum SessionResultStatus { initial, loading, ready, failure }

final class SessionResultState extends Equatable {
  const SessionResultState({this.status = SessionResultStatus.initial, this.result, this.session, this.failure});
  final SessionResultStatus status;
  final SessionResult? result;
  final Session? session;
  final Failure? failure;
  @override
  List<Object?> get props => [status, result, session, failure];
}

sealed class SessionResultEvent {
  const SessionResultEvent();
}

final class SessionResultOpened extends SessionResultEvent {
  const SessionResultOpened(this.sessionId);
  final String sessionId;
}

final class SessionResultRetried extends SessionResultEvent {
  const SessionResultRetried();
}

final class SessionResultBloc extends Bloc<SessionResultEvent, SessionResultState> {
  SessionResultBloc(this.loadSession, this.finishSession) : super(const SessionResultState()) {
    on<SessionResultEvent>((event, emit) async {
      if (event is SessionResultOpened) _id = event.sessionId;
      if (_id == null) return;
      emit(SessionResultState(status: SessionResultStatus.loading, result: state.result, session: state.session));
      final tasks = (finishSession(_id!, Duration.zero), loadSession(_id!));
      final result = await tasks.$1, session = await tasks.$2;
      if (emit.isDone) return;
      final failure = result is Err<SessionResult>
          ? result.failure
          : session is Err<Session>
          ? session.failure
          : null;
      emit(
        SessionResultState(
          status: failure == null ? SessionResultStatus.ready : SessionResultStatus.failure,
          result: result is Ok<SessionResult> ? result.value : state.result,
          session: session is Ok<Session> ? session.value : state.session,
          failure: failure,
        ),
      );
    }, transformer: restartable());
  }
  final LoadSession loadSession;
  final FinishSession finishSession;
  String? _id;
}
