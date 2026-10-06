import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/features/streak/domain/activity.dart';

enum StreakStatus { initial, loading, ready, failure }

final class StreakState extends Equatable {
  const StreakState({this.status = StreakStatus.initial, this.activity, this.celebrate = false, this.failure});
  final StreakStatus status;
  final Activity? activity;
  final bool celebrate;
  final Failure? failure;
  @override
  List<Object?> get props => [status, activity, celebrate, failure];
}

sealed class StreakEvent {
  const StreakEvent();
}

final class StreakOpened extends StreakEvent {
  const StreakOpened({this.celebrate = false});
  final bool celebrate;
}

final class StreakRetried extends StreakEvent {
  const StreakRetried();
}

final class StreakBloc extends Bloc<StreakEvent, StreakState> {
  StreakBloc(this.getActivity) : super(const StreakState()) {
    on<StreakEvent>((event, emit) async {
      final celebrate = event is StreakOpened ? event.celebrate : state.celebrate;
      emit(StreakState(status: StreakStatus.loading, celebrate: celebrate, activity: state.activity));
      final result = await getActivity();
      if (emit.isDone) return;
      switch (result) {
        case Ok(:final value):
          emit(StreakState(status: StreakStatus.ready, celebrate: celebrate && value.streak.todayCompleted, activity: value));
        case Err(:final failure):
          emit(StreakState(status: StreakStatus.failure, celebrate: celebrate, activity: state.activity, failure: failure));
      }
    }, transformer: restartable());
  }
  final GetActivity getActivity;
}
