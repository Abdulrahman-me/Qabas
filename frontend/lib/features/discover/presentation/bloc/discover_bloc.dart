import 'dart:async';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/core/events/app_event_bus.dart';
import 'package:qabas/core/events/app_events.dart';
import 'package:qabas/shared/domain/entities/journey.dart';
import 'package:qabas/shared/domain/usecases/journey_actions.dart';

enum DiscoverStatus { initial, loading, ready, failure }

final class DiscoverState extends Equatable {
  const DiscoverState({
    this.status = DiscoverStatus.initial,
    this.journey,
    this.refreshing = false,
    this.failure,
    this.lessonToOpen,
    this.actionSerial = 0,
  });
  final DiscoverStatus status;
  final Journey? journey;
  final bool refreshing;
  final Failure? failure;
  final String? lessonToOpen;
  final int actionSerial;
  List<JourneyUnit> get units => journey?.units.where((u) => u.lessons.any((l) => l.standaloneEligible)).toList() ?? [];
  @override
  List<Object?> get props => [status, journey, refreshing, failure, lessonToOpen, actionSerial];
}

sealed class DiscoverEvent {
  const DiscoverEvent();
}

final class DiscoverOpened extends DiscoverEvent {
  const DiscoverOpened();
}

final class DiscoverRefreshed extends DiscoverEvent {
  const DiscoverRefreshed();
}

final class LessonPicked extends DiscoverEvent {
  const LessonPicked(this.lessonId);
  final String lessonId;
}

final class DiscoverBloc extends Bloc<DiscoverEvent, DiscoverState> {
  DiscoverBloc(this.getJourney, AppEventBus events) : super(const DiscoverState()) {
    on<DiscoverOpened>((_, emit) => _load(emit, false));
    on<DiscoverRefreshed>((_, emit) => _load(emit, true), transformer: restartable());
    on<LessonPicked>((event, emit) {
      final lesson = state.journey?.lesson(event.lessonId);
      if (lesson == null ||
          !lesson.standaloneEligible ||
          ![LessonState.available, LessonState.inProgress, LessonState.completed].contains(lesson.state)) {
        return;
      }
      emit(
        DiscoverState(
          status: state.status,
          journey: state.journey,
          refreshing: state.refreshing,
          failure: state.failure,
          lessonToOpen: event.lessonId,
          actionSerial: state.actionSerial + 1,
        ),
      );
    });
    _subscription = events.on<AppEvent>().listen((event) {
      if (event is SessionCompleted || event is ProfileChanged || event is LearningProgressChanged) add(const DiscoverRefreshed());
    });
  }
  final GetJourney getJourney;
  late final StreamSubscription<AppEvent> _subscription;
  int _epoch = 0;
  Future<void> _load(Emitter<DiscoverState> emit, bool refresh) async {
    final epoch = ++_epoch;
    emit(
      DiscoverState(
        status: state.journey == null ? DiscoverStatus.loading : DiscoverStatus.ready,
        journey: state.journey,
        refreshing: state.journey != null,
        actionSerial: state.actionSerial,
      ),
    );
    final result = await getJourney(refresh: refresh);
    if (emit.isDone || epoch != _epoch) return;
    switch (result) {
      case Ok<Journey>(:final value):
        emit(DiscoverState(status: DiscoverStatus.ready, journey: value, actionSerial: state.actionSerial));
      case Err<Journey>(:final failure):
        emit(DiscoverState(status: DiscoverStatus.failure, journey: state.journey, failure: failure, actionSerial: state.actionSerial));
    }
  }

  @override
  Future<void> close() async {
    _epoch++;
    await _subscription.cancel();
    await super.close();
  }
}
