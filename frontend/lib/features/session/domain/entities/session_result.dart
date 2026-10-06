import 'package:equatable/equatable.dart';
import 'package:qabas/features/session/domain/entities/exercise.dart';
import 'package:qabas/shared/domain/entities/content.dart';
import 'package:qabas/shared/domain/entities/next_step.dart';
import 'package:qabas/shared/domain/entities/stats.dart';

final class LayerScore extends Equatable {
  const LayerScore(this.correct, this.total, this.percent);
  final int correct, total, percent;
  @override
  List<Object?> get props => [correct, total, percent];
}

final class XpGrant extends Equatable {
  const XpGrant(this.reason, this.xp);
  final String reason;
  final int xp;
  @override
  List<Object?> get props => [reason, xp];
}

final class ResultReference extends Equatable {
  const ResultReference(this.id, this.title);
  final String id, title;
  @override
  List<Object?> get props => [id, title];
}

final class ResultUnlock extends Equatable {
  const ResultUnlock(this.type, this.id, this.title);
  final String type, id, title;
  @override
  List<Object?> get props => [type, id, title];
}

/// Complete immutable server snapshot. Remembering remains a review placeholder.
final class SessionResult extends Equatable {
  SessionResult({
    required this.sessionId,
    required this.kind,
    required this.correct,
    required this.total,
    required this.percent,
    required this.passed,
    required this.xp,
    required this.duration,
    this.understanding,
    this.applying,
    this.streakCurrent = 0,
    this.streakExtended = false,
    this.dailyGoal,
    this.nextStep,
    List<XpGrant> xpBreakdown = const [],
    List<MasteryChange> masterySummary = const [],
    List<ResultReference> termsMastered = const [],
    List<ResultReference> misconceptionsActivated = const [],
    List<ResultReference> misconceptionsResolved = const [],
    List<ResultUnlock> unlocked = const [],
    List<AnswerReview> reviewItems = const [],
  }) : xpBreakdown = List.unmodifiable(xpBreakdown),
       masterySummary = List.unmodifiable(masterySummary),
       termsMastered = List.unmodifiable(termsMastered),
       misconceptionsActivated = List.unmodifiable(misconceptionsActivated),
       misconceptionsResolved = List.unmodifiable(misconceptionsResolved),
       unlocked = List.unmodifiable(unlocked),
       reviewItems = List.unmodifiable(reviewItems);
  final String sessionId, kind;
  final int correct, total, percent, xp, streakCurrent;
  final bool? passed;
  final bool streakExtended;
  final Duration duration;
  final LayerScore? understanding, applying;
  final DailyGoal? dailyGoal;
  final NextStep? nextStep;
  final List<XpGrant> xpBreakdown;
  final List<MasteryChange> masterySummary;
  final List<ResultReference> termsMastered, misconceptionsActivated, misconceptionsResolved;
  final List<ResultUnlock> unlocked;
  final List<AnswerReview> reviewItems;
  bool get perfect => xpBreakdown.any((grant) => grant.reason == 'lesson_perfect');
  @override
  List<Object?> get props => [
    sessionId,
    kind,
    correct,
    total,
    percent,
    passed,
    xp,
    duration,
    understanding,
    applying,
    streakCurrent,
    streakExtended,
    dailyGoal,
    nextStep,
    xpBreakdown,
    masterySummary,
    termsMastered,
    misconceptionsActivated,
    misconceptionsResolved,
    unlocked,
    reviewItems,
  ];
}

final class AnswerReview extends Equatable {
  AnswerReview({
    required this.exerciseId,
    required this.correct,
    required this.correctAnswer,
    required List<ContentSpan> explanation,
    required List<String> sourceIds,
  }) : explanation = List.unmodifiable(explanation),
       sourceIds = List.unmodifiable(sourceIds);
  final String exerciseId;
  final bool? correct;
  final AnswerPayload? correctAnswer;
  final List<ContentSpan> explanation;
  final List<String> sourceIds;
  @override
  List<Object?> get props => [exerciseId, correct, correctAnswer, explanation, sourceIds];
}
