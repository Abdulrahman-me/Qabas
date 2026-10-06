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
import 'package:qabas/features/reviewer/domain/reviewer_repository.dart';

enum ReviewerStatus { initial, loading, ready, submitting, failure }

final class ReviewerRunsState extends Equatable {
  ReviewerRunsState({
    this.status = ReviewerStatus.initial,
    List<ReviewRunRow> items = const [],
    this.filter,
    this.cursor,
    this.failure,
    this.openedRun,
    this.createKey,
  }) : items = List.unmodifiable(items);
  final ReviewerStatus status;
  final List<ReviewRunRow> items;
  final String? filter, cursor, openedRun, createKey;
  final Failure? failure;
  @override
  List<Object?> get props => [status, items, filter, cursor, failure, openedRun, createKey];
}

sealed class ReviewerRunsEvent {
  const ReviewerRunsEvent();
}

final class RunsOpened extends ReviewerRunsEvent {
  const RunsOpened([this.filter]);
  final String? filter;
}

final class MoreRunsRequested extends ReviewerRunsEvent {
  const MoreRunsRequested();
}

final class NewRunSubmitted extends ReviewerRunsEvent {
  const NewRunSubmitted(this.request);
  final ReviewRunCreate request;
}

final class ReviewerRunsBloc extends Bloc<ReviewerRunsEvent, ReviewerRunsState> {
  ReviewerRunsBloc(this.actions, {AppEventBus? events}) : super(ReviewerRunsState()) {
    _resets = events?.on<ReviewerSamplesReset>().listen((_) => add(RunsOpened(state.filter)));
    on<ReviewerRunsEvent>((e, emit) async {
      if (e is NewRunSubmitted) {
        if (_createRequest != e.request) {
          _createRequest = e.request;
          _createKey = actions.repository.newKey();
        }
        emit(
          ReviewerRunsState(
            status: ReviewerStatus.submitting,
            items: state.items,
            filter: state.filter,
            cursor: state.cursor,
            createKey: _createKey,
          ),
        );
        final r = await actions.repository.create(e.request, _createKey!);
        if (emit.isDone) return;
        if (r case Ok<ReviewFactoryRun>(:final value)) {
          _createKey = null;
          _createRequest = null;
          emit(
            ReviewerRunsState(
              status: ReviewerStatus.ready,
              items: state.items,
              filter: state.filter,
              cursor: state.cursor,
              openedRun: value.runId,
            ),
          );
        } else {
          emit(
            ReviewerRunsState(
              status: ReviewerStatus.ready,
              items: state.items,
              filter: state.filter,
              cursor: state.cursor,
              failure: (r as Err<ReviewFactoryRun>).failure,
              createKey: _createKey,
            ),
          );
        }
        return;
      }
      final more = e is MoreRunsRequested;
      if (more && state.cursor == null) return;
      final filter = e is RunsOpened ? e.filter : state.filter;
      final old = more ? state.items : <ReviewRunRow>[];
      final cursor = more ? state.cursor : null;
      emit(ReviewerRunsState(status: ReviewerStatus.loading, items: old, filter: filter, cursor: cursor));
      final result = await actions.repository.runs(status: filter, cursor: cursor);
      if (emit.isDone) return;
      emit(switch (result) {
        Ok<ReviewerRunPage>(:final value) => ReviewerRunsState(
          status: ReviewerStatus.ready,
          items: [...old, ...value.items.where((v) => !old.any((o) => o.runId == v.runId))],
          filter: filter,
          cursor: value.nextCursor,
        ),
        Err<ReviewerRunPage>(:final failure) => ReviewerRunsState(
          status: ReviewerStatus.failure,
          items: old,
          filter: filter,
          cursor: cursor,
          failure: failure,
        ),
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
  String? _createKey;
  ReviewRunCreate? _createRequest;
}
