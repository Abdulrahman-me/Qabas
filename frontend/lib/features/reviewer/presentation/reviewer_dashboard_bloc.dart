import 'dart:async';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/core/events/app_event_bus.dart';
import 'package:qabas/core/events/app_events.dart';
import 'package:qabas/features/reviewer/domain/reviewer_actions.dart';
import 'package:qabas/features/reviewer/domain/reviewer_models.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_runs_bloc.dart';

final class MetricsState extends Equatable {
  const MetricsState({this.status = ReviewerStatus.initial, this.metrics, this.failure});
  final ReviewerStatus status;
  final ReviewMetrics? metrics;
  final Failure? failure;
  @override
  List<Object?> get props => [status, metrics, failure];
}

final class MetricsOpened {
  const MetricsOpened();
}

final class ReviewerMetricsBloc extends Bloc<MetricsOpened, MetricsState> {
  ReviewerMetricsBloc(ReviewerActions actions) : super(const MetricsState()) {
    on<MetricsOpened>((e, emit) async {
      emit(const MetricsState(status: ReviewerStatus.loading));
      final r = await actions.repository.metrics();
      if (emit.isDone) return;
      emit(switch (r) {
        Ok<ReviewMetrics>(:final value) => MetricsState(status: ReviewerStatus.ready, metrics: value),
        Err<ReviewMetrics>(:final failure) => MetricsState(status: ReviewerStatus.failure, failure: failure),
      });
    }, transformer: sequential());
  }
}

final class BlindState extends Equatable {
  const BlindState({
    this.status = ReviewerStatus.initial,
    this.pair,
    this.clearer,
    this.accurate,
    this.handwritten,
    this.failure,
    this.submitted = false,
  });
  final ReviewerStatus status;
  final ReviewBlindPair? pair;
  final String? clearer, accurate, handwritten;
  final Failure? failure;
  final bool submitted;
  bool get complete => clearer != null && accurate != null && handwritten != null;
  @override
  List<Object?> get props => [status, pair, clearer, accurate, handwritten, failure, submitted];
}

sealed class BlindEvent {
  const BlindEvent();
}

final class BlindOpened extends BlindEvent {
  const BlindOpened();
}

final class BlindChoicePicked extends BlindEvent {
  const BlindChoicePicked(this.question, this.choice);
  final int question;
  final String choice;
}

final class BlindAnswerSubmitted extends BlindEvent {
  const BlindAnswerSubmitted();
}

final class ReviewerBlindBloc extends Bloc<BlindEvent, BlindState> {
  ReviewerBlindBloc(this.actions, {AppEventBus? events}) : super(const BlindState()) {
    _resets = events?.on<ReviewerSamplesReset>().listen((_) => add(const BlindOpened()));
    on<BlindEvent>((e, emit) async {
      if (e is BlindChoicePicked) {
        emit(
          BlindState(
            status: state.status,
            pair: state.pair,
            clearer: e.question == 0 ? e.choice : state.clearer,
            accurate: e.question == 1 ? e.choice : state.accurate,
            handwritten: e.question == 2 ? e.choice : state.handwritten,
          ),
        );
        return;
      }
      if (e is BlindAnswerSubmitted) {
        if (!state.complete || state.pair == null || state.status != ReviewerStatus.ready) return;
        final before = state;
        emit(
          BlindState(
            status: ReviewerStatus.submitting,
            pair: before.pair,
            clearer: before.clearer,
            accurate: before.accurate,
            handwritten: before.handwritten,
          ),
        );
        final r = await actions.repository.blindAnswer(
          before.pair!.pairId,
          ReviewBlindAnswer(clearer: before.clearer!, moreAccurate: before.accurate!, guessedHandwritten: before.handwritten!),
        );
        if (emit.isDone) return;
        if (r is Err<void>) {
          emit(
            BlindState(
              status: ReviewerStatus.ready,
              pair: before.pair,
              clearer: before.clearer,
              accurate: before.accurate,
              handwritten: before.handwritten,
              failure: r.failure,
            ),
          );
          return;
        }
        emit(const BlindState(status: ReviewerStatus.loading, submitted: true));
      } else {
        emit(const BlindState(status: ReviewerStatus.loading));
      }
      final r = await actions.repository.blindPair();
      if (emit.isDone) return;
      emit(switch (r) {
        Ok<ReviewBlindPair?>(:final value) => BlindState(status: ReviewerStatus.ready, pair: value, submitted: state.submitted),
        Err<ReviewBlindPair?>(:final failure) => BlindState(status: ReviewerStatus.failure, failure: failure),
      });
    }, transformer: sequential());
  }
  StreamSubscription<ReviewerSamplesReset>? _resets;
  @override
  Future<void> close() async {
    await _resets?.cancel();
    return super.close();
  }

  final ReviewerActions actions;
}
