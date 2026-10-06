import 'package:equatable/equatable.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/shared/domain/entities/content.dart';

enum ChallengePreset { duel, group }

enum ChallengePhase { lobby, countdown, question, reveal, results }

final class ChallengeChoice extends Equatable {
  const ChallengeChoice({this.optionId, this.value});
  final String? optionId;
  final bool? value;
  @override
  List<Object?> get props => [optionId, value];
}

final class ChallengeOption extends Equatable {
  ChallengeOption(this.choice, List<ContentSpan> spans) : spans = List.unmodifiable(spans);
  final ChallengeChoice choice;
  final List<ContentSpan> spans;
  @override
  List<Object?> get props => [choice, spans];
}

final class ChallengeQuestion extends Equatable {
  ChallengeQuestion({
    required this.index,
    required this.total,
    required List<ContentSpan> prompt,
    required List<ContentSpan> statement,
    required List<ChallengeOption> options,
    required this.issuedAt,
    required this.deadline,
    this.verse,
  }) : prompt = List.unmodifiable(prompt),
       statement = List.unmodifiable(statement),
       options = List.unmodifiable(options);
  final int index, total;
  final List<ContentSpan> prompt, statement;
  final List<ChallengeOption> options;
  final DateTime issuedAt, deadline;
  final Evidence? verse;
  @override
  List<Object?> get props => [index, total, prompt, statement, options, issuedAt, deadline, verse];
}

final class ChallengePlayer extends Equatable {
  const ChallengePlayer(this.id, this.name, this.avatar, this.isMe, this.isBot, this.status);
  final String id, name, avatar, status;
  final bool isMe, isBot;
  ChallengePlayer changed(String status) => ChallengePlayer(id, name, avatar, isMe, isBot, status);
  @override
  List<Object?> get props => [id, name, avatar, isMe, isBot, status];
}

final class ChallengeConfig extends Equatable {
  const ChallengeConfig(this.count, this.timeLimit, this.revealMs);
  final int count, timeLimit, revealMs;
  @override
  List<Object?> get props => [count, timeLimit, revealMs];
}

final class ChallengeScore extends Equatable {
  const ChallengeScore(this.id, this.rank, this.points, this.correct);
  final String id;
  final int rank, points, correct;
  @override
  List<Object?> get props => [id, rank, points, correct];
}

final class ChallengeResult extends Equatable {
  ChallengeResult(List<String> winners, this.isDraw, List<ChallengeScore> scores, this.xp)
    : winners = List.unmodifiable(winners),
      scores = List.unmodifiable(scores);
  final List<String> winners;
  final bool isDraw;
  final List<ChallengeScore> scores;
  final int xp;
  @override
  List<Object?> get props => [winners, isDraw, scores, xp];
}

final class Challenge extends Equatable {
  Challenge({
    required this.id,
    required this.status,
    required this.mode,
    required this.preset,
    required List<ChallengePlayer> players,
    required this.config,
    required this.wsUrl,
    required this.createdAt,
    required this.expiresAt,
    this.result,
  }) : players = List.unmodifiable(players);
  final String id, status, mode;
  final ChallengePreset preset;
  final List<ChallengePlayer> players;
  final ChallengeConfig config;
  final Uri wsUrl;
  final DateTime createdAt, expiresAt;
  final ChallengeResult? result;
  @override
  bool get stringify => false;
  String get myId => players.firstWhere((p) => p.isMe).id;
  Challenge withPlayers(List<ChallengePlayer> players) => Challenge(
    id: id,
    status: status,
    mode: mode,
    preset: preset,
    players: players,
    config: config,
    wsUrl: wsUrl,
    createdAt: createdAt,
    expiresAt: expiresAt,
    result: result,
  );
  @override
  List<Object?> get props => [id, status, mode, preset, players, config, createdAt, expiresAt, result];
}

final class ChallengePlayerAnswer extends Equatable {
  const ChallengePlayerAnswer(this.id, this.correct, this.elapsedMs, this.points);
  final String id;
  final bool correct;
  final int elapsedMs, points;
  @override
  List<Object?> get props => [id, correct, elapsedMs, points];
}

final class ChallengeReveal extends Equatable {
  ChallengeReveal(
    this.index,
    this.correctAnswer,
    List<ContentSpan> explanation,
    List<ChallengePlayerAnswer> players,
    Map<String, int> totals,
  ) : explanation = List.unmodifiable(explanation),
      players = List.unmodifiable(players),
      totals = Map.unmodifiable(totals);
  final int index;
  final ChallengeChoice correctAnswer;
  final List<ContentSpan> explanation;
  final List<ChallengePlayerAnswer> players;
  final Map<String, int> totals;
  ChallengePlayerAnswer? get fastest =>
      (players.where((p) => p.correct).toList()..sort((a, b) => a.elapsedMs.compareTo(b.elapsedMs))).firstOrNull;
  @override
  List<Object?> get props => [index, correctAnswer, explanation, players, totals];
}

final class ChallengeSummary extends Equatable {
  ChallengeSummary(this.index, List<ContentSpan> prompt, this.correctAnswer, List<ContentSpan> explanation)
    : prompt = List.unmodifiable(prompt),
      explanation = List.unmodifiable(explanation);
  final int index;
  final List<ContentSpan> prompt, explanation;
  final ChallengeChoice correctAnswer;
  @override
  List<Object?> get props => [index, prompt, correctAnswer, explanation];
}

final class ChallengeInvitation extends Equatable {
  const ChallengeInvitation(this.id, this.name, this.expiresAt);
  final String id, name;
  final DateTime expiresAt;
  @override
  List<Object?> get props => [id, name, expiresAt];
}

sealed class ChallengeUpdate extends Equatable {
  const ChallengeUpdate();
}

final class ChallengeSnapshot extends ChallengeUpdate {
  ChallengeSnapshot({
    required this.challenge,
    required this.serverTime,
    this.phase = ChallengePhase.lobby,
    this.question,
    this.deadline,
    this.answer,
    Set<String> answered = const {},
    Map<String, int> totals = const {},
    List<ChallengeReveal> reveals = const [],
  }) : answered = Set.unmodifiable(answered),
       totals = Map.unmodifiable(totals),
       reveals = List.unmodifiable(reveals);
  final Challenge challenge;
  final DateTime serverTime;
  final ChallengePhase phase;
  final ChallengeQuestion? question;
  final DateTime? deadline;
  final ChallengeChoice? answer;
  final Set<String> answered;
  final Map<String, int> totals;
  final List<ChallengeReveal> reveals;
  @override
  List<Object?> get props => [challenge, serverTime, phase, question, deadline, answer, answered, totals, reveals];
}

final class ChallengeCountdown extends ChallengeUpdate {
  const ChallengeCountdown(this.startsAt);
  final DateTime startsAt;
  @override
  List<Object?> get props => [startsAt];
}

final class ChallengeQuestionIssued extends ChallengeUpdate {
  const ChallengeQuestionIssued(this.question);
  final ChallengeQuestion question;
  @override
  List<Object?> get props => [question];
}

final class ChallengeAnswerLocked extends ChallengeUpdate {
  const ChallengeAnswerLocked(this.index);
  final int index;
  @override
  List<Object?> get props => [index];
}

final class ChallengeOpponentAnswered extends ChallengeUpdate {
  const ChallengeOpponentAnswered(this.index, this.id);
  final int index;
  final String id;
  @override
  List<Object?> get props => [index, id];
}

final class ChallengePlayerStatus extends ChallengeUpdate {
  const ChallengePlayerStatus(this.id, this.status);
  final String id, status;
  @override
  List<Object?> get props => [id, status];
}

final class ChallengeConnectionChanged extends ChallengeUpdate {
  const ChallengeConnectionChanged(this.id, this.grace);
  final String id;
  final Duration? grace;
  @override
  List<Object?> get props => [id, grace];
}

final class ChallengeRevealed extends ChallengeUpdate {
  const ChallengeRevealed(this.reveal);
  final ChallengeReveal reveal;
  @override
  List<Object?> get props => [reveal];
}

final class ChallengeFinished extends ChallengeUpdate {
  ChallengeFinished(this.result, List<ChallengeSummary> summary) : summary = List.unmodifiable(summary);
  final ChallengeResult result;
  final List<ChallengeSummary> summary;
  @override
  List<Object?> get props => [result, summary];
}

final class ChallengePong extends ChallengeUpdate {
  const ChallengePong();
  @override
  List<Object?> get props => [];
}

abstract interface class ChallengeConnection {
  Stream<Result<ChallengeUpdate>> get events;
  void ready();
  void ping();
  void answer(int index, ChallengeChoice choice);
  Future<void> close();
}

final class ChallengeInvitee extends Equatable {
  const ChallengeInvitee(this.id, this.name, this.avatar, this.online);
  final String id, name, avatar;
  final bool online;
  @override
  List<Object?> get props => [id, name, avatar, online];
}

abstract interface class ChallengeRepository {
  Future<Result<List<ChallengeInvitee>>> friends();
  Future<Result<Challenge>> create(ChallengePreset preset, List<String> friends, bool botFill);
  Future<Result<Challenge>> get(String id);
  Future<Result<List<ChallengeInvitation>>> invitations();
  Future<Result<Challenge>> accept(String id);
  Future<Result<void>> decline(String id);
  Future<Result<ChallengeConnection>> connect(Challenge challenge);
}

final class ChallengeActions {
  const ChallengeActions(this.repository);
  final ChallengeRepository repository;
  Future<Result<List<ChallengeInvitee>>> friends() => repository.friends();
  Future<Result<Challenge>> create(ChallengePreset preset, List<String> friends, bool botFill) =>
      repository.create(preset, friends, botFill);
  Future<Result<Challenge>> get(String id) => repository.get(id);
  Future<Result<List<ChallengeInvitation>>> invitations() => repository.invitations();
  Future<Result<Challenge>> accept(String id) => repository.accept(id);
  Future<Result<void>> decline(String id) => repository.decline(id);
  Future<Result<ChallengeConnection>> connect(Challenge challenge) => repository.connect(challenge);
}
