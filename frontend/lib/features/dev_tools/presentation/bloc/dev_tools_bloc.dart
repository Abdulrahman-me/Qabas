import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/features/dev_tools/domain/repositories/dev_tools_repository.dart';
import 'package:qabas/features/dev_tools/domain/usecases/dev_tools_actions.dart';

enum DevToolsStatus { initial, loading, ready, failure }

final class DevToolsState extends Equatable {
  const DevToolsState({this.status = DevToolsStatus.initial, this.snapshot, this.failure, this.lessonToOpen});
  final DevToolsStatus status;
  final DevSnapshot? snapshot;
  final Failure? failure;
  final String? lessonToOpen;
  @override
  List<Object?> get props => [status, snapshot, failure, lessonToOpen];
}

sealed class DevToolsEvent {
  const DevToolsEvent();
}

final class DevToolsOpened extends DevToolsEvent {
  const DevToolsOpened();
}

final class DevOptionChanged extends DevToolsEvent {
  const DevOptionChanged(this.option, this.value);
  final DevOption option;
  final Object? value;
}

final class DevProbeRequested extends DevToolsEvent {
  const DevProbeRequested();
}

final class DevLessonPreviewOpened extends DevToolsEvent {
  const DevLessonPreviewOpened(this.lessonId, {this.track});
  final String lessonId;
  final String? track;
}

final class DevToolsBloc extends Bloc<DevToolsEvent, DevToolsState> {
  DevToolsBloc(this._actions) : super(const DevToolsState()) {
    on<DevToolsEvent>(
      (event, emit) => switch (event) {
        DevToolsOpened() => _run(_actions.inspect, emit),
        DevOptionChanged(:final option, :final value) => _run(() => _actions.change(option, value), emit),
        DevProbeRequested() => _run(_actions.probe, emit),
        DevLessonPreviewOpened() => _preview(event, emit),
      },
      transformer: sequential(),
    );
  }
  Future<void> _preview(DevLessonPreviewOpened event, Emitter<DevToolsState> emit) async {
    if (event.track != null) {
      await _run(() => _actions.change(DevOption.track, event.track), emit);
      if (state.status == DevToolsStatus.failure || emit.isDone) return;
      await _run(() => _actions.change(DevOption.referencePreviewReset, null), emit);
      if (state.status == DevToolsStatus.failure || emit.isDone) return;
    }
    emit(DevToolsState(status: DevToolsStatus.ready, snapshot: state.snapshot, lessonToOpen: event.lessonId));
  }

  final DevToolsActions _actions;
  Future<void> _run(Future<Result<DevSnapshot>> Function() operation, Emitter<DevToolsState> emit) async {
    emit(DevToolsState(status: DevToolsStatus.loading, snapshot: state.snapshot));
    final result = await operation();
    switch (result) {
      case Ok(:final value):
        emit(DevToolsState(status: DevToolsStatus.ready, snapshot: value));
      case Err(:final failure):
        emit(DevToolsState(status: DevToolsStatus.failure, snapshot: state.snapshot, failure: failure));
    }
  }
}
