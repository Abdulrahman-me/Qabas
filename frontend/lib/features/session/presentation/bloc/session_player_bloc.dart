import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qabas/core/design_system/tokens/tokens.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/features/session/domain/entities/exercise.dart';
import 'package:qabas/features/session/domain/entities/session.dart';
import 'package:qabas/features/session/domain/entities/session_result.dart';
import 'package:qabas/features/session/domain/logic/progress.dart';
import 'package:qabas/features/session/domain/logic/session_recovery.dart';
import 'package:qabas/features/session/domain/usecases/session_actions.dart';

enum PlayerStatus { initial, loading, playing, feedback, retryRound, finishing, finished, previewEnded, failure, left }

final class SessionPlayerState extends Equatable {
  SessionPlayerState({
    this.status = PlayerStatus.initial,
    this.session,
    this.cursor = 0,
    Set<String> completedStepIds = const {},
    this.failure,
    this.evaluation,
    this.combo = 0,
    List<ExerciseItem> retryQueue = const [],
    this.retryCursor = 0,
    this.inRetry = false,
    this.submitting = false,
    this.result,
    this.attempt = 0,
    Map<String, String> predictions = const {},
    this.timerDeadline,
    this.remaining = Duration.zero,
    this.answer,
    this.quitFailure,
  }) : completedStepIds = Set.unmodifiable(completedStepIds),
       retryQueue = List.unmodifiable(retryQueue),
       predictions = Map.unmodifiable(predictions);
  final PlayerStatus status;
  final Session? session;
  final int cursor;
  final Set<String> completedStepIds;
  final Failure? failure;
  final Failure? quitFailure;
  final AnswerEvaluation? evaluation;
  final int combo;
  final List<ExerciseItem> retryQueue;
  final int retryCursor;
  final bool inRetry, submitting;
  final SessionResult? result;
  final int attempt;
  final Map<String, String> predictions;
  final DateTime? timerDeadline;
  final Duration remaining;
  final AnswerPayload? answer;
  int get secondsRemaining => (remaining.inMilliseconds / Duration.millisecondsPerSecond).ceil().clamp(0, 20);
  SessionItem? get item => inRetry
      ? (retryCursor < retryQueue.length ? retryQueue[retryCursor] : null)
      : session != null && cursor < session!.items.length
      ? session!.items[cursor]
      : null;
  double get progress => session == null ? 0 : lessonProgress(session!, completedStepIds);
  SessionPlayerState copy({
    PlayerStatus? status,
    int? cursor,
    Set<String>? completed,
    Failure? failure,
    AnswerEvaluation? evaluation,
    int? combo,
    List<ExerciseItem>? queue,
    int? retryCursor,
    bool? inRetry,
    bool? submitting,
    SessionResult? result,
    int? attempt,
    Map<String, String>? predictions,
    DateTime? timerDeadline,
    Duration? remaining,
    AnswerPayload? answer,
    Failure? quitFailure,
  }) => SessionPlayerState(
    status: status ?? this.status,
    session: session,
    cursor: cursor ?? this.cursor,
    completedStepIds: completed ?? completedStepIds,
    failure: failure,
    evaluation: evaluation,
    combo: combo ?? this.combo,
    retryQueue: queue ?? retryQueue,
    retryCursor: retryCursor ?? this.retryCursor,
    inRetry: inRetry ?? this.inRetry,
    submitting: submitting ?? this.submitting,
    result: result ?? this.result,
    attempt: attempt ?? this.attempt,
    predictions: Map.unmodifiable(predictions ?? this.predictions),
    timerDeadline: timerDeadline ?? this.timerDeadline,
    remaining: remaining ?? this.remaining,
    answer: answer,
    quitFailure: quitFailure,
  );
  @override
  List<Object?> get props => [
    status,
    session,
    cursor,
    completedStepIds,
    failure,
    evaluation,
    combo,
    retryQueue,
    retryCursor,
    inRetry,
    submitting,
    result,
    attempt,
    predictions,
    timerDeadline,
    remaining,
    answer,
    quitFailure,
  ];
}

sealed class SessionPlayerEvent {
  const SessionPlayerEvent();
}

final class SessionLoaded extends SessionPlayerEvent {
  const SessionLoaded(this.id);
  final String id;
}

final class SessionLoadRetried extends SessionPlayerEvent {
  const SessionLoadRetried();
}

final class StepCompleted extends SessionPlayerEvent {
  const StepCompleted(this.id);
  final String id;
}

final class PredictionSelectionSaved extends SessionPlayerEvent {
  const PredictionSelectionSaved(this.id, this.option);
  final String id, option;
}

final class ReviewClockTicked extends SessionPlayerEvent {
  const ReviewClockTicked();
}

final class PredictionChecked extends SessionPlayerEvent {
  const PredictionChecked(this.id);
  final String id;
}

// Kept for isolated Phase 5 content tests; production always has answer/finish use cases.
final class ExercisePlaceholderContinued extends SessionPlayerEvent {
  const ExercisePlaceholderContinued(this.id);
  final String id;
}

final class AnswerChecked extends SessionPlayerEvent {
  const AnswerChecked(this.exerciseId, this.answer, this.elapsed);
  final String exerciseId;
  final AnswerPayload answer;
  final Duration elapsed;
}

final class AnswerSubmitRetried extends SessionPlayerEvent {
  const AnswerSubmitRetried();
}

final class FeedbackContinued extends SessionPlayerEvent {
  const FeedbackContinued();
}

final class RetryRoundStarted extends SessionPlayerEvent {
  const RetryRoundStarted();
}

final class FinishRequested extends SessionPlayerEvent {
  const FinishRequested();
}

final class QuitConfirmed extends SessionPlayerEvent {
  const QuitConfirmed();
}

final class SessionPlayerBloc extends Bloc<SessionPlayerEvent, SessionPlayerState> {
  SessionPlayerBloc(this.loadSession, {this.submitAnswer, this.finishSession, this.checkpoints, this.abandonSession})
    : super(SessionPlayerState()) {
    on<SessionLoaded>((e, emit) {
      _id = e.id;
      return _load(emit);
    }, transformer: droppable());
    on<SessionLoadRetried>((e, emit) => _load(emit), transformer: droppable());
    on<PredictionSelectionSaved>(
      (e, emit) => emit(state.copy(predictions: {...state.predictions, e.id: e.option}, evaluation: state.evaluation)),
    );
    on<ReviewClockTicked>((e, emit) {
      if (state.session?.mode != 'quick' || state.status != PlayerStatus.playing || state.timerDeadline == null) return;
      final left = state.timerDeadline!.difference(DateTime.now().toUtc());
      emit(state.copy(remaining: left.isNegative ? Duration.zero : left, failure: state.failure, answer: state.answer));
      if (left <= Duration.zero && !state.submitting && state.failure == null && state.item is ExerciseItem) {
        add(
          AnswerChecked(
            (state.item as ExerciseItem).exerciseId,
            const TimeoutAnswer(),
            state.item is ExerciseItem ? (state.item as ExerciseItem).exercise!.timeLimit! : Duration.zero,
          ),
        );
      }
    });
    on<PredictionChecked>((e, emit) {
      if (state.item is PredictItem && state.item?.blockId == e.id && state.status == PlayerStatus.playing) {
        emit(state.copy(status: PlayerStatus.feedback, completed: {...state.completedStepIds, e.id}));
      }
    });
    on<StepCompleted>((e, emit) {
      if (state.item?.blockId == e.id &&
          state.item is! ExerciseItem &&
          [PlayerStatus.playing, PlayerStatus.feedback].contains(state.status)) {
        _advance(emit, {...state.completedStepIds, e.id});
      }
    });
    on<ExercisePlaceholderContinued>((e, emit) {
      if (submitAnswer == null && state.item?.blockId == e.id) _advance(emit, state.completedStepIds);
    });
    on<AnswerChecked>((e, emit) async {
      if (state.item case final ExerciseItem item) {
        if (item.exerciseId != e.exerciseId || state.submitting || state.evaluation != null || state.status != PlayerStatus.playing) return;
        _pending = e;
        await _submit(emit);
      }
    }, transformer: sequential());
    on<AnswerSubmitRetried>((e, emit) => _submit(emit), transformer: droppable());
    on<FeedbackContinued>((e, emit) {
      if (state.status == PlayerStatus.feedback && state.item is ExerciseItem) {
        _advance(emit, {...state.completedStepIds, state.item!.blockId});
      }
    });
    on<RetryRoundStarted>((e, emit) {
      if (state.status == PlayerStatus.retryRound) {
        emit(state.copy(status: PlayerStatus.playing, inRetry: true, retryCursor: 0, attempt: state.attempt + 1));
      }
    });
    on<FinishRequested>((e, emit) => _finish(emit), transformer: droppable());
    on<QuitConfirmed>((e, emit) async {
      if (state.session != null && abandonSession != null) {
        emit(state.copy(submitting: true, evaluation: state.evaluation, answer: state.answer));
        final result = await abandonSession!(state.session!.sessionId);
        if (result case Err(:final failure)) {
          emit(state.copy(quitFailure: failure, submitting: false, evaluation: state.evaluation, answer: state.answer));
          return;
        }
        if (_saving != null) await _saving!.catchError((Object _) {});
        await checkpoints?.remove(state.session!.sessionId);
      }
      emit(state.copy(status: PlayerStatus.left));
    }, transformer: droppable());
  }
  final LoadSession loadSession;
  final SessionCheckpointStore? checkpoints;
  final AbandonSession? abandonSession;
  Timer? _clock;
  Future<void>? _saving;
  final SubmitAnswer? submitAnswer;
  final FinishSession? finishSession;
  String? _id;
  bool _loading = false;
  bool _closing = false;
  AnswerChecked? _pending;
  Future<void> _load(Emitter<SessionPlayerState> emit) async {
    if (_id == null || _loading) return;
    _loading = true;
    emit(SessionPlayerState(status: PlayerStatus.loading));
    final r = await loadSession(_id!);
    _loading = false;
    if (_closing || emit.isDone || state.status == PlayerStatus.left) return;
    switch (r) {
      case Ok(:final value):
        final recovered = recoverSession(value);
        final local = await checkpoints?.read(value.sessionId, value.lessonVersion);
        if (_closing || emit.isDone) return;
        var cursor = recovered.cursor;
        var queue = recovered.retries;
        var retryCursor = 0;
        var inRetry = false;
        var status = PlayerStatus.playing;
        var completed = recovered.completed;
        AnswerEvaluation? evaluation;
        if (local != null && local.cursor >= 0 && local.cursor <= value.items.length) {
          cursor = local.cursor;
          completed = {...local.completed, ...recovered.completed};
          final retryIds = {...local.retries, ...recovered.retries.map((i) => i.exerciseId)};
          queue = value.items.whereType<ExerciseItem>().where((i) => retryIds.contains(i.exerciseId)).toList();
          inRetry = local.inRetry;
          retryCursor = local.retryCursor.clamp(0, queue.length);
          status = local.stage == 'feedback'
              ? PlayerStatus.feedback
              : local.stage == 'retryRound'
              ? PlayerStatus.retryRound
              : PlayerStatus.playing;
          evaluation = value.answers.where((a) => a.exerciseId == local.feedbackExercise && a.isRetry == inRetry).firstOrNull?.evaluation;
          if (status == PlayerStatus.feedback && local.feedbackExercise != null && evaluation == null) status = PlayerStatus.playing;
        }
        while (!inRetry && cursor < value.items.length) {
          final item = value.items[cursor];
          if (item is UnknownItem) {
            completed.add(item.blockId);
            cursor++;
            continue;
          }
          if (status != PlayerStatus.feedback &&
              item is ExerciseItem &&
              value.answers.any((a) => a.exerciseId == item.exerciseId && !a.isRetry)) {
            completed.add(item.blockId);
            cursor++;
            continue;
          }
          break;
        }
        // A response may have committed just before the app was killed.
        if (inRetry && status != PlayerStatus.feedback) {
          while (retryCursor < queue.length && value.answers.any((a) => a.exerciseId == queue[retryCursor].exerciseId && a.isRetry)) {
            retryCursor++;
          }
        }
        emit(
          SessionPlayerState(
            status: status,
            session: value,
            cursor: cursor,
            completedStepIds: completed,
            retryQueue: queue,
            retryCursor: retryCursor,
            inRetry: inRetry,
            evaluation: evaluation,
            combo: local?.combo ?? 0,
            predictions: Map.unmodifiable(local?.predictions ?? {}),
            timerDeadline: local?.timerDeadline,
            answer: local?.answer,
          ),
        );
        if (value.status == LessonSessionStatus.finished) {
          emit(state.copy(status: PlayerStatus.finishing));
          add(const FinishRequested());
        } else if (value.status != LessonSessionStatus.active) {
          emit(state.copy(status: PlayerStatus.left));
        } else if (state.item == null) {
          _end(emit);
        } else {
          _startClock(emit, restored: true);
        }
      case Err(:final failure):
        emit(SessionPlayerState(status: PlayerStatus.failure, failure: failure));
    }
  }

  Future<void> _submit(Emitter<SessionPlayerState> emit) async {
    if (_pending == null || state.submitting || state.status != PlayerStatus.playing || submitAnswer == null) return;
    final request = _pending!, item = state.item as ExerciseItem, exercise = item.exercise!;
    emit(state.copy(submitting: true, answer: request.answer));
    final r = await submitAnswer!(
      state.session!.sessionId,
      exercise,
      request.answer,
      request.elapsed,
      isRetry: state.inRetry,
      immediate: state.session!.feedbackMode == FeedbackMode.immediate,
    );
    if (_closing || emit.isDone || state.status == PlayerStatus.left) return;
    switch (r) {
      case Err(:final failure):
        emit(state.copy(failure: failure, submitting: false, answer: request.answer));
      case Ok(:final value):
        _pending = null;
        final evaluation = value is AnswerEvaluation ? value : null;
        var combo = state.combo;
        final queue = [...state.retryQueue];
        if (evaluation != null && evaluation.correct != null && exercise.scoring.combo && exercise.type != ExerciseType.reciteVerse) {
          combo = evaluation.correct! ? combo + 1 : 0;
        }
        if (!state.inRetry &&
            evaluation?.correct == false &&
            exercise.type != ExerciseType.reciteVerse &&
            exercise.type != ExerciseType.flashcard &&
            state.session!.kind == SessionKind.lesson) {
          queue.add(item);
        }
        final recite = exercise.type == ExerciseType.reciteVerse;
        final card = exercise.type == ExerciseType.flashcard;
        emit(
          state.copy(
            status: evaluation == null || recite || card ? PlayerStatus.playing : PlayerStatus.feedback,
            evaluation: evaluation,
            completed: !state.inRetry && !recite ? {...state.completedStepIds, item.blockId} : state.completedStepIds,
            combo: combo,
            queue: queue,
            submitting: false,
            answer: request.answer,
          ),
        );
        if (evaluation == null || recite || card) _advance(emit, {...state.completedStepIds, item.blockId});
    }
  }

  void _advance(Emitter<SessionPlayerState> emit, Set<String> completed) {
    if (state.inRetry) {
      final cursor = state.retryCursor + 1;
      emit(state.copy(status: PlayerStatus.playing, retryCursor: cursor, completed: completed, attempt: state.attempt + 1));
      if (cursor == state.retryQueue.length) _end(emit);
      return;
    }
    _clock?.cancel();
    var cursor = state.cursor + 1;
    final items = state.session!.items, done = {...completed};
    while (cursor < items.length && items[cursor] is UnknownItem) {
      done.add(items[cursor++].blockId);
    }
    emit(state.copy(status: PlayerStatus.playing, cursor: cursor, completed: done, attempt: state.attempt + 1));
    if (cursor == items.length) {
      _end(emit);
    } else {
      _startClock(emit);
    }
  }

  void _startClock(Emitter<SessionPlayerState> emit, {bool restored = false}) {
    _clock?.cancel();
    if (state.session?.mode != 'quick' || state.item is! ExerciseItem || state.status != PlayerStatus.playing) return;
    final limit = (state.item as ExerciseItem).exercise!.timeLimit;
    if (limit == null) return;
    final deadline = restored && state.timerDeadline != null ? state.timerDeadline! : DateTime.now().toUtc().add(limit);
    emit(state.copy(timerDeadline: deadline, remaining: deadline.difference(DateTime.now().toUtc())));
    _clock = Timer.periodic(QReview.clockTick, (_) {
      if (!isClosed) add(const ReviewClockTicked());
    }); // rules:allow — timer cadence, not visual motion
    add(const ReviewClockTicked());
  }

  @override
  void onChange(Change<SessionPlayerState> change) {
    super.onChange(change);
    final next = change.nextState, session = change.nextState.session;
    if (checkpoints == null || session == null || next.status == PlayerStatus.loading || next.status == PlayerStatus.initial) return;
    if (next.status == PlayerStatus.left) return;
    if (next.status == PlayerStatus.finished) {
      _save(() => checkpoints!.remove(session.sessionId));
      return;
    }
    if (next.remaining != change.currentState.remaining &&
        next.timerDeadline == change.currentState.timerDeadline &&
        next.status == change.currentState.status &&
        next.submitting == change.currentState.submitting &&
        next.failure == change.currentState.failure) {
      return;
    }
    final checkpoint = SessionCheckpoint(
      cursor: next.cursor,
      stage: next.status.name,
      completed: next.completedStepIds,
      retries: next.retryQueue.map((i) => i.exerciseId).toList(),
      retryCursor: next.retryCursor,
      inRetry: next.inRetry,
      combo: next.combo,
      predictions: next.predictions,
      feedbackExercise: next.evaluation?.exerciseId,
      timerDeadline: next.timerDeadline,
      answer: next.answer,
    );
    _save(() => checkpoints!.write(session.sessionId, session.lessonVersion, checkpoint));
  }

  void _save(Future<void> Function() operation) {
    final write = _saving == null ? operation() : _saving!.then((_) => operation());
    late final Future<void> saving;
    // A failed local write still permits conservative recovery from server history.
    saving = write.catchError((Object _) {}).whenComplete(() {
      if (identical(_saving, saving)) _saving = null;
    });
    _saving = saving;
  }

  void _end(Emitter<SessionPlayerState> emit) {
    if (!state.inRetry && state.retryQueue.isNotEmpty) {
      emit(state.copy(status: PlayerStatus.retryRound));
      return;
    }
    if (finishSession == null) {
      emit(state.copy(status: PlayerStatus.previewEnded));
      return;
    }
    emit(state.copy(status: PlayerStatus.finishing));
    add(const FinishRequested());
  }

  Future<void> _finish(Emitter<SessionPlayerState> emit) async {
    if (finishSession == null || ![PlayerStatus.finishing, PlayerStatus.failure].contains(state.status) || state.session == null) return;
    emit(state.copy(status: PlayerStatus.finishing));
    final r = await finishSession!(state.session!.sessionId, DateTime.now().toUtc().difference(state.session!.startedAt));
    if (_closing || emit.isDone || state.status == PlayerStatus.left) return;
    switch (r) {
      case Ok(:final value):
        emit(state.copy(status: PlayerStatus.finished, result: value));
      case Err(:final failure):
        emit(state.copy(status: PlayerStatus.failure, failure: failure));
    }
  }

  @override
  Future<void> close() {
    _closing = true;
    _clock?.cancel();
    return _saving == null ? super.close() : _saving!.catchError((Object _) {}).then((_) => super.close());
  }
}
