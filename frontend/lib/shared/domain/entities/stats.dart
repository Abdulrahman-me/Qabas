import 'package:equatable/equatable.dart';

final class Streak extends Equatable {
  const Streak({required this.current, required this.longest, required this.todayCompleted});
  final int current;
  final int longest;
  final bool todayCompleted;
  @override
  List<Object?> get props => [current, longest, todayCompleted];
}

final class DailyGoal extends Equatable {
  const DailyGoal({required this.minutes, required this.minutesToday, required this.met});
  final int minutes;
  final int minutesToday;
  final bool met;
  @override
  List<Object?> get props => [minutes, minutesToday, met];
}

final class StatsLeague extends Equatable {
  const StatsLeague({required this.leagueId, required this.rank, required this.size});
  final String leagueId;
  final int rank;
  final int size;
  @override
  List<Object?> get props => [leagueId, rank, size];
}

final class ConceptCounts extends Equatable {
  const ConceptCounts({required this.mastered, required this.learning});
  final int mastered;
  final int learning;
  @override
  List<Object?> get props => [mastered, learning];
}

final class TermCounts extends Equatable {
  const TermCounts({required this.mastered, required this.seen});
  final int mastered;
  final int seen;
  @override
  List<Object?> get props => [mastered, seen];
}

final class MisconceptionCounts extends Equatable {
  const MisconceptionCounts({required this.resolved, required this.active});
  final int resolved;
  final int active;
  @override
  List<Object?> get props => [resolved, active];
}

final class Stats extends Equatable {
  const Stats({
    required this.xpTotal,
    required this.xpThisWeek,
    required this.streak,
    required this.dailyGoal,
    required this.league,
    required this.concepts,
    required this.terms,
    required this.misconceptions,
    required this.lessonsCompleted,
    required this.unitsCompleted,
  });
  final int xpTotal;
  final int xpThisWeek;
  final Streak streak;
  final DailyGoal dailyGoal;
  final StatsLeague? league;
  final ConceptCounts concepts;
  final TermCounts terms;
  final MisconceptionCounts misconceptions;
  final int lessonsCompleted;
  final int unitsCompleted;
  @override
  List<Object?> get props => [
    xpTotal,
    xpThisWeek,
    streak,
    dailyGoal,
    league,
    concepts,
    terms,
    misconceptions,
    lessonsCompleted,
    unitsCompleted,
  ];
}
