import 'package:qabas/shared/data/dtos/stats_dto.dart';
import 'package:qabas/shared/domain/entities/stats.dart';

extension StreakMapping on StreakDto {
  Streak toEntity() => Streak(current: current, longest: longest, todayCompleted: todayCompleted);
}

extension DailyGoalMapping on DailyGoalDto {
  DailyGoal toEntity() => DailyGoal(minutes: minutes, minutesToday: minutesToday, met: met);
}

extension StatsLeagueMapping on StatsLeagueDto {
  StatsLeague toEntity() => StatsLeague(leagueId: leagueId, rank: rank, size: size);
}

extension ConceptCountsMapping on ConceptCountsDto {
  ConceptCounts toEntity() => ConceptCounts(mastered: mastered, learning: learning);
}

extension TermCountsMapping on TermCountsDto {
  TermCounts toEntity() => TermCounts(mastered: mastered, seen: seen);
}

extension MisconceptionCountsMapping on MisconceptionCountsDto {
  MisconceptionCounts toEntity() => MisconceptionCounts(resolved: resolved, active: active);
}

extension StatsMapping on StatsDto {
  Stats toEntity() => Stats(
    xpTotal: xpTotal,
    xpThisWeek: xpThisWeek,
    streak: streak.toEntity(),
    dailyGoal: dailyGoal.toEntity(),
    league: league?.toEntity(),
    concepts: concepts.toEntity(),
    terms: terms.toEntity(),
    misconceptions: misconceptions.toEntity(),
    lessonsCompleted: lessonsCompleted,
    unitsCompleted: unitsCompleted,
  );
}
