import 'dart:async';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/core/events/app_event_bus.dart';
import 'package:qabas/core/events/app_events.dart';
import 'package:qabas/shared/domain/entities/journey.dart';
import 'package:qabas/shared/domain/entities/next_step.dart';
import 'package:qabas/shared/domain/entities/stats.dart';
import 'package:qabas/shared/domain/entities/user_profile.dart';
import 'package:qabas/shared/domain/usecases/journey_actions.dart';

enum JourneyGreeting { morning, afternoon, evening }

enum JourneyStatus { initial, loading, ready, failure }

final class JourneyState extends Equatable {
  const JourneyState({
    this.status = JourneyStatus.initial,
    this.journey,
    this.nextStep,
    this.stats,
    this.selectedLessonId,
    this.selectedUnitId,
    this.unitToOpen,
    this.pretestUnitToOpen,
    this.refreshing = false,
    this.failure,
    this.softLock,
    this.lessonToOpen,
    this.openReview = false,
    this.downloadBannerDismissed = false,
    this.openAndroidDownload = false,
    this.actionSerial = 0,
  });
  final JourneyStatus status;
  final Journey? journey;
  final NextStep? nextStep;
  final Stats? stats;
  final String? selectedLessonId, lessonToOpen, selectedUnitId, unitToOpen, pretestUnitToOpen;
  final bool refreshing, openReview, downloadBannerDismissed, openAndroidDownload;
  final Failure? failure;
  final SoftLock? softLock;
  final int actionSerial;
  JourneyState copyWith({
    JourneyStatus? status,
    Journey? journey,
    NextStep? nextStep,
    Stats? stats,
    String? selectedLessonId,
    String? selectedUnitId,
    String? unitToOpen,
    String? pretestUnitToOpen,
    bool clearUnit = false,
    bool clearSelection = false,
    bool? refreshing,
    Failure? failure,
    SoftLock? softLock,
    String? lessonToOpen,
    bool openReview = false,
    bool? downloadBannerDismissed,
    bool openAndroidDownload = false,
    int? actionSerial,
  }) => JourneyState(
    status: status ?? this.status,
    journey: journey ?? this.journey,
    nextStep: nextStep ?? this.nextStep,
    stats: stats ?? this.stats,
    selectedLessonId: clearSelection ? null : selectedLessonId ?? this.selectedLessonId,
    selectedUnitId: selectedUnitId ?? (clearSelection || clearUnit ? null : this.selectedUnitId),
    unitToOpen: unitToOpen,
    pretestUnitToOpen: pretestUnitToOpen,
    refreshing: refreshing ?? this.refreshing,
    failure: failure,
    softLock: softLock,
    lessonToOpen: lessonToOpen,
    openReview: openReview,
    downloadBannerDismissed: downloadBannerDismissed ?? this.downloadBannerDismissed,
    openAndroidDownload: openAndroidDownload,
    actionSerial: actionSerial ?? this.actionSerial,
  );
  @override
  List<Object?> get props => [
    status,
    journey,
    nextStep,
    stats,
    selectedLessonId,
    selectedUnitId,
    unitToOpen,
    pretestUnitToOpen,
    refreshing,
    failure,
    softLock,
    lessonToOpen,
    openReview,
    downloadBannerDismissed,
    openAndroidDownload,
    actionSerial,
  ];
}

sealed class JourneyEvent {
  const JourneyEvent();
}

final class AndroidDownloadOpened extends JourneyEvent {
  const AndroidDownloadOpened();
}

final class DownloadBannerDismissed extends JourneyEvent {
  const DownloadBannerDismissed();
}

final class JourneyOpened extends JourneyEvent {
  const JourneyOpened();
}

final class JourneyRefreshed extends JourneyEvent {
  const JourneyRefreshed();
}

final class NodePicked extends JourneyEvent {
  const NodePicked(this.lessonId);
  final String lessonId;
}

final class CheckpointPicked extends JourneyEvent {
  const CheckpointPicked(this.unitId);
  final String unitId;
}

final class UnitTestOpened extends JourneyEvent {
  const UnitTestOpened(this.unitId);
  final String unitId;
}

final class PopoverDismissed extends JourneyEvent {
  const PopoverDismissed();
}

final class SoftLockDismissed extends JourneyEvent {
  const SoftLockDismissed();
}

final class LessonOpened extends JourneyEvent {
  const LessonOpened(this.lessonId);
  final String lessonId;
}

final class ReviewOpened extends JourneyEvent {
  const ReviewOpened();
}

final class NextStepOpened extends JourneyEvent {
  const NextStepOpened();
}

final class TrackPicked extends JourneyEvent {
  const TrackPicked(this.track);
  final UserTrack track;
}

final class PrerequisiteFailureReceived extends JourneyEvent {
  const PrerequisiteFailureReceived(this.failure);
  final ConflictFailure failure;
}

final class JourneyBloc extends Bloc<JourneyEvent, JourneyState> {
  JourneyBloc({
    required this.getJourney,
    required this.getNextStep,
    required this.getStats,
    required this.updateProfile,
    required this.resolveLock,
    required AppEventBus events,
  }) : super(const JourneyState()) {
    on<AndroidDownloadOpened>((_, emit) => emit(state.copyWith(openAndroidDownload: true, actionSerial: state.actionSerial + 1)));
    on<DownloadBannerDismissed>((_, emit) => emit(state.copyWith(downloadBannerDismissed: true)));
    on<JourneyOpened>((_, emit) => _load(emit, refresh: false));
    on<JourneyRefreshed>((_, emit) => _load(emit, refresh: true), transformer: restartable());
    on<NodePicked>((event, emit) {
      final lesson = state.journey?.lesson(event.lessonId);
      if (lesson == null || lesson.state == LessonState.unknown) return;
      if (lesson.state == LessonState.locked) {
        emit(state.copyWith(clearSelection: true, softLock: lesson.softLock, actionSerial: state.actionSerial + 1));
      } else {
        emit(state.copyWith(selectedLessonId: event.lessonId, clearUnit: true, clearSelection: state.selectedLessonId == event.lessonId));
      }
    });
    on<CheckpointPicked>((event, emit) {
      final unit = state.journey?.units.where((u) => u.unitId == event.unitId).firstOrNull;
      if (unit == null || !(unit.unitTest.canSkip || unit.unitTest.state == UnitTestState.passed)) return;
      emit(state.copyWith(clearSelection: true, selectedUnitId: state.selectedUnitId == event.unitId ? null : event.unitId));
    });
    on<UnitTestOpened>((event, emit) {
      final unit = state.journey?.units.where((u) => u.unitId == event.unitId).firstOrNull;
      if (unit == null || !(unit.unitTest.canSkip || unit.unitTest.state == UnitTestState.passed)) return;
      emit(state.copyWith(clearSelection: true, unitToOpen: event.unitId, actionSerial: state.actionSerial + 1));
    });
    on<PopoverDismissed>((_, emit) => emit(state.copyWith(clearSelection: true)));
    on<SoftLockDismissed>((_, emit) => emit(state.copyWith()));
    on<LessonOpened>((event, emit) => _open(event.lessonId, emit));
    on<ReviewOpened>((_, emit) {
      if ((state.nextStep?.dueReviewsCount ?? 0) > 0) {
        emit(state.copyWith(clearSelection: true, openReview: true, actionSerial: state.actionSerial + 1));
      }
    });
    on<NextStepOpened>((_, emit) {
      final next = state.nextStep;
      if (next?.type == NextStepType.review) {
        add(const ReviewOpened());
      } else if (next?.type == NextStepType.pretest && next?.unitId != null) {
        emit(state.copyWith(clearSelection: true, pretestUnitToOpen: next!.unitId, actionSerial: state.actionSerial + 1));
      } else if (next?.type == NextStepType.unitTest && next?.unitId != null) {
        emit(state.copyWith(clearSelection: true, unitToOpen: next!.unitId, actionSerial: state.actionSerial + 1));
      } else if (next?.lessonId case final String id) {
        _open(id, emit);
      }
    });
    on<PrerequisiteFailureReceived>((event, emit) {
      final lock = resolveLock(event.failure);
      if (lock != null) emit(state.copyWith(clearSelection: true, softLock: lock, actionSerial: state.actionSerial + 1));
    });
    on<TrackPicked>((event, emit) async {
      if (event.track == state.journey?.track || event.track == UserTrack.unknown) return;
      _switching = true;
      _epoch++;
      emit(state.copyWith(refreshing: true, clearSelection: true));
      final result = await updateProfile(event.track);
      _switching = false;
      if (emit.isDone) return;
      switch (result) {
        case Ok<UserProfile>():
          await _load(emit, refresh: true);
        case Err<UserProfile>(:final failure):
          emit(state.copyWith(status: JourneyStatus.failure, refreshing: false, failure: failure));
      }
    }, transformer: droppable());
    _subscription = events.on<AppEvent>().listen((event) {
      if (event is SessionCompleted ||
          event is LearningProgressChanged ||
          event is XpChanged ||
          event is TermsMastered ||
          event is ProfileChanged && !_switching) {
        add(const JourneyRefreshed());
      }
    });
  }
  final int localHour = DateTime.now().hour;
  JourneyGreeting get greeting => localHour < 12
      ? JourneyGreeting.morning
      : localHour < 18
      ? JourneyGreeting.afternoon
      : JourneyGreeting.evening;
  final GetJourney getJourney;
  final GetNextStep getNextStep;
  final GetStats getStats;
  final UpdateProfile updateProfile;
  final SoftLock? Function(ConflictFailure) resolveLock;
  late final StreamSubscription<AppEvent> _subscription;
  bool _switching = false;
  int _epoch = 0;
  void _open(String id, Emitter<JourneyState> emit) {
    final lesson = state.journey?.lesson(id);
    if (lesson == null || lesson.state == LessonState.unknown) return;
    if (lesson.state == LessonState.locked) {
      emit(state.copyWith(clearSelection: true, softLock: lesson.softLock, actionSerial: state.actionSerial + 1));
    } else {
      emit(state.copyWith(clearSelection: true, lessonToOpen: id, actionSerial: state.actionSerial + 1));
    }
  }

  Future<void> _load(Emitter<JourneyState> emit, {required bool refresh}) async {
    final epoch = ++_epoch;
    emit(state.copyWith(status: state.journey == null ? JourneyStatus.loading : JourneyStatus.ready, refreshing: state.journey != null));
    final tasks = (getJourney(refresh: refresh), getNextStep(), getStats());
    final Result<Journey> journey = await tasks.$1;
    final Result<NextStep> next = await tasks.$2;
    final Result<Stats> stats = await tasks.$3;
    if (emit.isDone || epoch != _epoch) return;
    Failure? failure;
    for (final result in [journey, next, stats]) {
      if (result case Err(failure: final problem)) failure = problem;
    }
    final data = journey is Ok<Journey> ? journey.value : state.journey;
    emit(
      state.copyWith(
        status: failure == null ? JourneyStatus.ready : JourneyStatus.failure,
        journey: data,
        nextStep: next is Ok<NextStep> ? next.value : null,
        stats: stats is Ok<Stats> ? stats.value : null,
        refreshing: false,
        failure: failure,
        clearSelection: data?.lesson(state.selectedLessonId ?? '') == null,
      ),
    );
  }

  @override
  Future<void> close() async {
    _epoch++;
    await _subscription.cancel();
    await super.close();
  }
}
