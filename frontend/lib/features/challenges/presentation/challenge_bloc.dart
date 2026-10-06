import 'dart:async';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qabas/core/design_system/tokens/tokens.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/core/events/app_event_bus.dart';
import 'package:qabas/core/events/app_events.dart';
import 'package:qabas/features/challenges/domain/challenge.dart';

enum ChallengeStatus { initial, loading, connected, reconnecting, failure }

final class ChallengeState extends Equatable {
  ChallengeState({
    this.status = ChallengeStatus.initial,
    this.phase = ChallengePhase.lobby,
    this.challenge,
    this.question,
    this.answer,
    this.locked = false,
    this.remainingMs = 0,
    this.deadline,
    this.offset = Duration.zero,
    this.reveal,
    this.result,
    List<ChallengeReveal> reveals = const [],
    List<ChallengeSummary> summary = const [],
    Set<String> answered = const {},
    Map<String, int> totals = const {},
    Map<String, DateTime> disconnected = const {},
    this.failure,
    Map<String, int> graceSeconds = const {},
  }) : graceSeconds = Map.unmodifiable(graceSeconds),
       reveals = List.unmodifiable(reveals),
       summary = List.unmodifiable(summary),
       answered = Set.unmodifiable(answered),
       totals = Map.unmodifiable(totals),
       disconnected = Map.unmodifiable(disconnected);
  final ChallengeStatus status;
  final ChallengePhase phase;
  final Challenge? challenge;
  final ChallengeQuestion? question;
  final ChallengeChoice? answer;
  final bool locked;
  final int remainingMs;
  final DateTime? deadline;
  final Duration offset;
  final ChallengeReveal? reveal;
  final ChallengeResult? result;
  final List<ChallengeReveal> reveals;
  final List<ChallengeSummary> summary;
  final Set<String> answered;
  final Map<String, int> totals;
  final Map<String, DateTime> disconnected;
  final Map<String, int> graceSeconds;
  final Failure? failure;
  ChallengeState changed({
    ChallengeStatus? status,
    ChallengePhase? phase,
    Challenge? challenge,
    ChallengeQuestion? question,
    ChallengeChoice? answer,
    bool? locked,
    int? remainingMs,
    DateTime? deadline,
    Duration? offset,
    ChallengeReveal? reveal,
    ChallengeResult? result,
    List<ChallengeReveal>? reveals,
    List<ChallengeSummary>? summary,
    Set<String>? answered,
    Map<String, int>? totals,
    Map<String, DateTime>? disconnected,
    Failure? failure,
    bool newQuestion = false,
    Map<String, int>? graceSeconds,
  }) => ChallengeState(
    status: status ?? this.status,
    phase: phase ?? this.phase,
    challenge: challenge ?? this.challenge,
    question: question ?? this.question,
    answer: newQuestion ? null : answer ?? this.answer,
    locked: locked ?? this.locked,
    remainingMs: remainingMs ?? this.remainingMs,
    deadline: deadline ?? this.deadline,
    offset: offset ?? this.offset,
    reveal: newQuestion ? null : reveal ?? this.reveal,
    result: result ?? this.result,
    reveals: reveals ?? this.reveals,
    summary: summary ?? this.summary,
    answered: answered ?? this.answered,
    totals: totals ?? this.totals,
    disconnected: disconnected ?? this.disconnected,
    graceSeconds: graceSeconds ?? this.graceSeconds,
    failure: failure,
  );
  @override
  List<Object?> get props => [
    status,
    phase,
    challenge,
    question,
    answer,
    locked,
    remainingMs,
    deadline,
    offset,
    reveal,
    result,
    reveals,
    summary,
    answered,
    totals,
    disconnected,
    graceSeconds,
    failure,
  ];
}

sealed class ChallengeEvent {
  const ChallengeEvent();
}

final class ChallengeStarted extends ChallengeEvent {
  ChallengeStarted({this.preset = ChallengePreset.duel, List<String> friends = const [], this.botFill = false})
    : friends = List.unmodifiable(friends);
  final ChallengePreset preset;
  final List<String> friends;
  final bool botFill;
}

final class ChallengeOpened extends ChallengeEvent {
  const ChallengeOpened(this.id, {this.accept = false});
  final String id;
  final bool accept;
}

final class ChallengeAnswerSelected extends ChallengeEvent {
  const ChallengeAnswerSelected(this.choice);
  final ChallengeChoice choice;
}

final class ChallengeReplayed extends ChallengeEvent {
  const ChallengeReplayed();
}

final class ChallengeRetried extends ChallengeEvent {
  const ChallengeRetried();
}

final class _UpdateReceived extends ChallengeEvent {
  const _UpdateReceived(this.update, this.epoch);
  final Result<ChallengeUpdate> update;
  final int epoch;
}

final class _Disconnected extends ChallengeEvent {
  const _Disconnected(this.epoch);
  final int epoch;
}

final class _Ticked extends ChallengeEvent {
  const _Ticked();
}

final class _LobbyPolled extends ChallengeEvent {
  const _LobbyPolled(this.epoch);
  final int epoch;
}

final class _Cleared extends ChallengeEvent {
  const _Cleared();
}

final class ChallengeBloc extends Bloc<ChallengeEvent, ChallengeState> {
  ChallengeBloc(this.actions, this.events, {DateTime Function()? now, Future<void> Function(Duration)? delay})
    : now = now ?? DateTime.now,
      delay = delay ?? Future<void>.delayed,
      super(ChallengeState()) {
    on<_Ticked>((_, emit) {
      if (state.deadline == null || state.phase == ChallengePhase.reveal || state.phase == ChallengePhase.results) return;
      final remaining = state.deadline!
          .difference(this.now().add(state.offset))
          .inMilliseconds
          .clamp(0, state.challenge?.config.timeLimit ?? 3000);
      emit(
        state.changed(
          remainingMs: remaining,
          graceSeconds: {for (final e in state.disconnected.entries) e.key: e.value.difference(this.now()).inSeconds.clamp(0, 10)},
        ),
      );
    });
    on<ChallengeEvent>(_handle, transformer: sequential());
    _account = events.on<GuestSessionCleared>().listen((_) {
      _epoch++;
      add(const _Cleared());
    });
  }
  final ChallengeActions actions;
  final AppEventBus events;
  final DateTime Function() now;
  final Future<void> Function(Duration) delay;
  ChallengeConnection? _connection;
  StreamSubscription<Result<ChallengeUpdate>>? _updates;
  StreamSubscription<GuestSessionCleared>? _account;
  Timer? _tick, _ping, _lobbyPoll;
  int _epoch = 0;
  ChallengeStarted? _start;
  String? _open;
  bool _published = false;
  Future<void> _handle(ChallengeEvent event, Emitter<ChallengeState> emit) async {
    if (event is _Ticked) return;
    if (event is ChallengeReplayed) event = _start ?? ChallengeStarted();
    if (event is _LobbyPolled) {
      if (event.epoch != _epoch || state.challenge == null || state.status == ChallengeStatus.connected) return;
      if (now().isAfter(state.challenge!.expiresAt)) {
        _lobbyPoll?.cancel();
        emit(state.changed(status: ChallengeStatus.failure, failure: ConflictFailure('duel_not_joinable')));
        return;
      }
      final fresh = await actions.get(state.challenge!.id);
      if (emit.isDone || event.epoch != _epoch) return;
      if (fresh case Ok(:final value)) {
        if (value.status == 'expired' || value.status == 'cancelled') {
          _lobbyPoll?.cancel();
          emit(state.changed(status: ChallengeStatus.failure, failure: ConflictFailure('duel_not_joinable')));
        } else {
          await _connect(value, event.epoch, emit);
        }
      }
      return;
    }
    if (event is _Cleared) {
      await _closeConnection();
      emit(ChallengeState());
      return;
    }
    if (event is ChallengeAnswerSelected) {
      if (state.status != ChallengeStatus.connected ||
          state.phase != ChallengePhase.question ||
          state.locked ||
          state.answer != null ||
          state.remainingMs <= 0) {
        return;
      }
      emit(state.changed(answer: event.choice));
      try {
        _connection?.answer(state.question!.index, event.choice);
      } catch (_) {
        add(_Disconnected(_epoch));
      }
      return;
    }
    if (event is _UpdateReceived) {
      if (event.epoch != _epoch) return;
      _receive(event.update, emit);
      return;
    }
    if (event is _Disconnected) {
      if (event.epoch != _epoch || state.phase == ChallengePhase.results) return;
      await _reconnect(emit);
      return;
    }
    if (event is ChallengeRetried) {
      if (state.status == ChallengeStatus.reconnecting) return;
      if (state.challenge != null) {
        await _reconnect(emit);
        return;
      }
      event = _start ?? ChallengeOpened(_open!);
    }
    if (event is ChallengeStarted || event is ChallengeOpened) {
      if (state.status == ChallengeStatus.loading) return;
      _start = event is ChallengeStarted ? event : null;
      _open = event is ChallengeOpened ? event.id : null;
      final epoch = ++_epoch;
      _published = false;
      await _closeConnection();
      emit(ChallengeState(status: ChallengeStatus.loading));
      final result = event is ChallengeStarted
          ? await actions.create(event.preset, event.friends, event.botFill)
          : (event as ChallengeOpened).accept
          ? await actions.accept(event.id)
          : await actions.get(event.id);
      if (emit.isDone || epoch != _epoch) return;
      if (result case Err(:final failure)) {
        emit(state.changed(status: ChallengeStatus.failure, failure: failure));
        return;
      }
      if (event is ChallengeOpened && event.accept) events.publish(const ChallengeInvitationsChanged());
      final challenge = (result as Ok<Challenge>).value;
      emit(state.changed(challenge: challenge));
      if (challenge.result != null) {
        _finish(challenge.result!, const [], emit);
        return;
      }
      await _connect(challenge, epoch, emit);
    }
  }

  Future<void> _connect(Challenge challenge, int epoch, Emitter<ChallengeState> emit) async {
    final result = await actions.connect(challenge);
    if (emit.isDone || epoch != _epoch) {
      if (result case Ok(:final value)) {
        await value.close();
      }
      return;
    }
    if (result case Err(:final failure)) {
      if (challenge.status == 'pending') {
        emit(state.changed(status: ChallengeStatus.reconnecting, challenge: challenge));
        _lobbyPoll ??= Timer.periodic(QChallenge.lobbyPoll, (_) {
          if (!isClosed) add(_LobbyPolled(epoch));
        });
      } else {
        emit(state.changed(status: ChallengeStatus.failure, failure: failure));
      }
      return;
    }
    _lobbyPoll?.cancel();
    _lobbyPoll = null;
    _connection = (result as Ok<ChallengeConnection>).value;
    _updates = _connection!.events.listen(
      (update) {
        if (!isClosed) add(_UpdateReceived(update, epoch));
      },
      onError: (Object _) {
        if (!isClosed) add(_Disconnected(epoch));
      },
      onDone: () {
        if (!isClosed && epoch == _epoch) add(_Disconnected(epoch));
      },
    );
    emit(state.changed(status: ChallengeStatus.connected, challenge: challenge));
    try {
      _connection!.ready();
    } catch (_) {
      add(_Disconnected(epoch));
    }
    _ping = Timer.periodic(QChallenge.ping, (_) {
      try {
        _connection?.ping();
      } catch (_) {
        if (!isClosed) add(_Disconnected(epoch));
      }
    });
    _tick = Timer.periodic(QChallenge.tick, (_) {
      if (!isClosed) add(const _Ticked());
    });
  }

  Future<void> _reconnect(Emitter<ChallengeState> emit) async {
    if (state.challenge == null) return;
    final id = state.challenge!.id, epoch = ++_epoch;
    await _closeConnection();
    emit(state.changed(status: ChallengeStatus.reconnecting));
    for (final backoff in QChallenge.reconnect) {
      await delay(backoff);
      if (emit.isDone || epoch != _epoch) return;
      final fresh = await actions.get(id);
      if (emit.isDone || epoch != _epoch) return;
      if (fresh case Err(:final failure)) {
        if (failure is UnauthorizedFailure || failure is ForbiddenFailure || failure is ClientOutdatedFailure) {
          emit(state.changed(status: ChallengeStatus.failure, failure: failure));
          return;
        }
        continue;
      }
      final challenge = (fresh as Ok<Challenge>).value;
      if (challenge.result != null) {
        _finish(challenge.result!, state.summary, emit);
        return;
      }
      await _connect(challenge, epoch, emit);
      if (state.status == ChallengeStatus.connected) return;
    }
    emit(state.changed(status: ChallengeStatus.failure, failure: const NetworkFailure()));
  }

  void _receive(Result<ChallengeUpdate> result, Emitter<ChallengeState> emit) {
    if (result case Err(:final failure)) {
      emit(state.changed(status: ChallengeStatus.failure, failure: failure));
      return;
    }
    switch ((result as Ok<ChallengeUpdate>).value) {
      case ChallengeSnapshot(
        :final challenge,
        :final serverTime,
        :final phase,
        :final question,
        :final deadline,
        :final answer,
        :final answered,
        :final totals,
        :final reveals,
      ):
        final offset = serverTime.difference(now());
        emit(
          ChallengeState(
            status: ChallengeStatus.connected,
            challenge: challenge,
            phase: phase,
            question: question,
            deadline: deadline,
            answer: answer,
            locked: answer != null,
            answered: answered,
            totals: totals,
            reveals: reveals,
            reveal: phase == ChallengePhase.reveal ? reveals.lastOrNull : null,
            result: challenge.result,
            offset: offset,
            remainingMs: deadline?.difference(now().add(offset)).inMilliseconds.clamp(0, challenge.config.timeLimit) ?? 0,
          ),
        );
        if (challenge.result != null) _finish(challenge.result!, state.summary, emit);
      case ChallengeCountdown(:final startsAt):
        emit(
          state.changed(
            phase: ChallengePhase.countdown,
            deadline: startsAt,
            remainingMs: startsAt.difference(now().add(state.offset)).inMilliseconds.clamp(0, 3000),
          ),
        );
      case ChallengeQuestionIssued(:final question):
        emit(
          state.changed(
            phase: ChallengePhase.question,
            question: question,
            deadline: question.deadline,
            remainingMs: question.deadline.difference(now().add(state.offset)).inMilliseconds.clamp(0, state.challenge!.config.timeLimit),
            locked: false,
            answered: {},
            newQuestion: true,
          ),
        );
      case ChallengeAnswerLocked(:final index):
        if (index == state.question?.index) emit(state.changed(locked: true, answered: {...state.answered, state.challenge!.myId}));
      case ChallengeOpponentAnswered(:final index, :final id):
        if (index == state.question?.index) emit(state.changed(answered: {...state.answered, id}));
      case ChallengePlayerStatus(:final id, :final status):
        emit(
          state.changed(
            challenge: state.challenge!.withPlayers([for (final p in state.challenge!.players) p.id == id ? p.changed(status) : p]),
          ),
        );
      case ChallengeConnectionChanged(:final id, :final grace):
        emit(
          state.changed(
            graceSeconds: {
              for (final e in state.graceSeconds.entries)
                if (e.key != id) e.key: e.value,
              if (grace != null) id: grace.inSeconds,
            },
            disconnected: {
              for (final e in state.disconnected.entries)
                if (e.key != id) e.key: e.value,
              if (grace != null) id: now().add(grace),
            },
          ),
        );
      case ChallengeRevealed(:final reveal):
        emit(
          state.changed(
            phase: ChallengePhase.reveal,
            reveal: reveal,
            totals: reveal.totals,
            reveals: [...state.reveals.where((r) => r.index != reveal.index), reveal],
          ),
        );
      case ChallengeFinished(:final result, :final summary):
        _finish(result, summary, emit);
      case ChallengePong():
        break;
    }
  }

  void _finish(ChallengeResult result, List<ChallengeSummary> summary, Emitter<ChallengeState> emit) {
    _tick?.cancel();
    _ping?.cancel();
    emit(state.changed(status: ChallengeStatus.connected, phase: ChallengePhase.results, result: result, summary: summary));
    if (!_published) {
      _published = true;
      events.publish(const XpChanged());
    }
  }

  Future<void> _closeConnection() async {
    _tick?.cancel();
    _ping?.cancel();
    _lobbyPoll?.cancel();
    _lobbyPoll = null;
    await _updates?.cancel();
    _updates = null;
    await _connection?.close();
    _connection = null;
  }

  @override
  Future<void> close() async {
    _epoch++;
    await _account?.cancel();
    await _closeConnection();
    await super.close();
  }
}
