import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qabas/core/design_system/tokens/tokens.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/core/events/app_event_bus.dart';
import 'package:qabas/core/events/app_events.dart';
import 'package:qabas/features/reviewer/domain/reviewer_actions.dart';
import 'package:qabas/features/reviewer/domain/reviewer_models.dart';
import 'package:qabas/features/reviewer/domain/reviewer_validation.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_runs_bloc.dart';

enum ReviewActionIssue { pairedEnglish, blockers, reasonRequired, invalidPlan }

final class ReviewerDetailState extends Equatable {
  ReviewerDetailState({
    this.status = ReviewerStatus.initial,
    this.run,
    this.plan,
    List<ReviewSentenceEdit> edits = const [],
    List<String> removals = const [],
    this.variant = 'explorer',
    this.reason = '',
    this.failure,
    this.issue,
    this.stale = false,
    this.regenerationAccepted = false,
  }) : edits = List.unmodifiable(edits),
       removals = List.unmodifiable(removals);
  final ReviewerStatus status;
  final ReviewFactoryRun? run;
  final ReviewLessonPlan? plan;
  final List<ReviewSentenceEdit> edits;
  final List<String> removals;
  final String variant, reason;
  final Failure? failure;
  final ReviewActionIssue? issue;
  final bool stale, regenerationAccepted;
  bool get hasBlockers => run?.qaReport?.issues.any((i) => i.severity == 'blocker') ?? false;
  bool get canApprove => status == ReviewerStatus.ready && !stale && !hasBlockers && run?.reviewDigest != null;
  ReviewerDetailState copy({
    ReviewerStatus? status,
    ReviewFactoryRun? run,
    ReviewLessonPlan? plan,
    List<ReviewSentenceEdit>? edits,
    List<String>? removals,
    String? variant,
    String? reason,
    Failure? failure,
    ReviewActionIssue? issue,
    bool? stale,
    bool? regenerationAccepted,
  }) => ReviewerDetailState(
    status: status ?? this.status,
    run: run ?? this.run,
    plan: plan ?? this.plan,
    edits: edits ?? this.edits,
    removals: removals ?? this.removals,
    variant: variant ?? this.variant,
    reason: reason ?? this.reason,
    failure: failure,
    issue: issue,
    stale: stale ?? this.stale,
    regenerationAccepted: regenerationAccepted ?? this.regenerationAccepted,
  );
  @override
  List<Object?> get props => [status, run, plan, edits, removals, variant, reason, failure, issue, stale, regenerationAccepted];
}

sealed class ReviewerDetailEvent {
  const ReviewerDetailEvent();
}

final class RunOpened extends ReviewerDetailEvent {
  const RunOpened(this.id);
  final String id;
}

final class RunPolled extends ReviewerDetailEvent {
  const RunPolled();
}

final class ReviewVariantPicked extends ReviewerDetailEvent {
  const ReviewVariantPicked(this.variant);
  final String variant;
}

final class PlanEdited extends ReviewerDetailEvent {
  const PlanEdited(this.plan);
  final ReviewLessonPlan plan;
}

final class SentencePairEdited extends ReviewerDetailEvent {
  const SentencePairEdited(this.id, this.ar, this.en);
  final String id, ar, en;
}

final class ExerciseRemovalChanged extends ReviewerDetailEvent {
  const ExerciseRemovalChanged(this.id, this.removed);
  final String id;
  final bool removed;
}

final class ReviewReasonEdited extends ReviewerDetailEvent {
  const ReviewReasonEdited(this.reason);
  final String reason;
}

final class ReviewReconfirmed extends ReviewerDetailEvent {
  const ReviewReconfirmed();
}

final class GateDecisionSubmitted extends ReviewerDetailEvent {
  const GateDecisionSubmitted(this.decision);
  final String decision;
}

final class ImageRegenerationRequested extends ReviewerDetailEvent {
  const ImageRegenerationRequested(this.sceneId);
  final String sceneId;
}

final class ReviewerDetailBloc extends Bloc<ReviewerDetailEvent, ReviewerDetailState> {
  ReviewerDetailBloc(this.actions, {this.pollInterval = QReviewer.pollInterval, AppEventBus? events}) : super(ReviewerDetailState()) {
    _resets = events?.on<ReviewerSamplesReset>().listen((_) {
      final id = state.run?.runId;
      if (id != null) add(RunOpened(id));
    });
    on<ReviewerDetailEvent>(_handle, transformer: sequential());
  }
  final ReviewerActions actions;
  final Duration pollInterval;
  Timer? _poll;
  StreamSubscription<ReviewerSamplesReset>? _resets;
  String? _id;
  Future<void> _load(Emitter<ReviewerDetailState> emit, {bool stale = false, bool background = false}) async {
    _poll?.cancel();
    if (_id == null) return;
    if (!background) emit(state.copy(status: ReviewerStatus.loading, stale: stale));
    final r = await actions.repository.run(_id!);
    if (emit.isDone) return;
    if (r case Ok<ReviewFactoryRun>(:final value)) {
      final variants = value.draft?.variants ?? const ['explorer'];
      emit(
        ReviewerDetailState(
          status: ReviewerStatus.ready,
          run: value,
          plan: value.plan,
          variant: variants.contains(state.variant) ? state.variant : variants.first,
          stale: stale,
          regenerationAccepted: state.regenerationAccepted,
        ),
      );
      if (value.status == 'running') _poll = Timer(pollInterval, () => add(const RunPolled()));
    } else {
      emit(state.copy(status: ReviewerStatus.failure, failure: (r as Err<ReviewFactoryRun>).failure));
    }
  }

  Future<void> _handle(ReviewerDetailEvent e, Emitter<ReviewerDetailState> emit) async {
    switch (e) {
      case RunOpened(:final id):
        _id = id;
        await _load(emit);
      case RunPolled():
        await _load(emit, background: true);
      case ReviewVariantPicked(:final variant):
        if (state.run?.draft?.variants.contains(variant) == true) emit(state.copy(variant: variant));
      case PlanEdited(:final plan):
        emit(state.copy(plan: plan));
      case ReviewReasonEdited(:final reason):
        emit(state.copy(reason: reason));
      case ReviewReconfirmed():
        emit(state.copy(stale: false));
      case ExerciseRemovalChanged(:final id, :final removed):
        emit(state.copy(removals: [...state.removals.where((v) => v != id), if (removed) id]));
      case SentencePairEdited(:final id, :final ar, :final en):
        if (ar.trim().isNotEmpty && en.trim().isEmpty) {
          emit(state.copy(issue: ReviewActionIssue.pairedEnglish));
          return;
        }
        emit(
          state.copy(
            edits: [
              ...state.edits.where((v) => v.sentenceId != id || v.variant != state.variant),
              if (ar.trim().isNotEmpty) ReviewSentenceEdit(sentenceId: id, language: 'ar', variant: state.variant, newText: ar),
              if (en.trim().isNotEmpty) ReviewSentenceEdit(sentenceId: id, language: 'en', variant: state.variant, newText: en),
            ],
          ),
        );
      case ImageRegenerationRequested(:final sceneId):
        final run = state.run;
        if (run == null || state.status != ReviewerStatus.ready || state.stale) return;
        emit(state.copy(status: ReviewerStatus.submitting));
        final r = await actions.repository.regenerate(run.runId, sceneId, state.reason.isEmpty ? null : state.reason);
        if (emit.isDone) return;
        if (r is Ok<void>) {
          emit(state.copy(regenerationAccepted: true));
          await _load(emit);
        } else {
          emit(state.copy(status: ReviewerStatus.ready, failure: (r as Err<void>).failure));
        }
      case GateDecisionSubmitted(:final decision):
        final run = state.run;
        if (run == null || state.status != ReviewerStatus.ready || state.stale || run.reviewDigest == null) return;
        if (decision == 'approve' && state.hasBlockers) {
          emit(state.copy(issue: ReviewActionIssue.blockers));
          return;
        }
        if (decision == 'request_changes' && state.reason.trim().isEmpty) {
          emit(state.copy(issue: ReviewActionIssue.reasonRequired));
          return;
        }
        if (decision == 'approve' && run.status == 'awaiting_gate1' && !validReviewPlan(state.plan!)) {
          emit(state.copy(issue: ReviewActionIssue.invalidPlan));
          return;
        }
        emit(state.copy(status: ReviewerStatus.submitting));
        final reason = state.reason.trim().isEmpty ? null : state.reason;
        final r = run.status == 'awaiting_gate1'
            ? await actions.repository.gate1(
                run.runId,
                ReviewGate1(
                  decision: decision,
                  plan: decision == 'approve' ? state.plan : null,
                  reason: reason,
                  reviewDigest: run.reviewDigest!,
                ),
              )
            : await actions.repository.gate2(
                run.runId,
                ReviewGate2(
                  decision: decision,
                  sentenceEdits: decision == 'approve' ? state.edits : [],
                  exerciseRemovals: decision == 'approve' ? state.removals : [],
                  reason: reason,
                  reviewDigest: run.reviewDigest!,
                ),
              );
        if (emit.isDone) return;
        if (r case Ok<ReviewFactoryRun>(:final value)) {
          emit(ReviewerDetailState(status: ReviewerStatus.ready, run: value, plan: value.plan, variant: state.variant));
          if (value.status == 'running') _poll = Timer(pollInterval, () => add(const RunPolled()));
        } else {
          final failure = (r as Err<ReviewFactoryRun>).failure;
          if (failure is ConflictFailure && ['review_stale', 'run_not_at_gate'].contains(failure.code)) {
            await _load(emit, stale: true);
          } else {
            emit(state.copy(status: ReviewerStatus.ready, failure: failure));
          }
        }
    }
  }

  @override
  Future<void> close() async {
    _poll?.cancel();
    await _resets?.cancel();
    return super.close();
  }
}
