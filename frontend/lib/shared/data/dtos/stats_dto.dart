import 'package:json_annotation/json_annotation.dart';
part 'stats_dto.g.dart';

@JsonSerializable()
final class StreakDto {
  const StreakDto({required this.current, required this.longest, required this.todayCompleted});
  factory StreakDto.fromJson(Map<String, dynamic> json) => _$StreakDtoFromJson(json);
  final int current;
  final int longest;
  final bool todayCompleted;
}

@JsonSerializable()
final class DailyGoalDto {
  const DailyGoalDto({required this.minutes, required this.minutesToday, required this.met});
  factory DailyGoalDto.fromJson(Map<String, dynamic> json) => _$DailyGoalDtoFromJson(json);
  final int minutes;
  final int minutesToday;
  final bool met;
}

@JsonSerializable()
final class StatsLeagueDto {
  const StatsLeagueDto({required this.leagueId, required this.rank, required this.size});
  factory StatsLeagueDto.fromJson(Map<String, dynamic> json) => _$StatsLeagueDtoFromJson(json);
  final String leagueId;
  final int rank;
  final int size;
}

@JsonSerializable()
final class ConceptCountsDto {
  const ConceptCountsDto({required this.mastered, required this.learning});
  factory ConceptCountsDto.fromJson(Map<String, dynamic> json) => _$ConceptCountsDtoFromJson(json);
  final int mastered;
  final int learning;
}

@JsonSerializable()
final class TermCountsDto {
  const TermCountsDto({required this.mastered, required this.seen});
  factory TermCountsDto.fromJson(Map<String, dynamic> json) => _$TermCountsDtoFromJson(json);
  final int mastered;
  final int seen;
}

@JsonSerializable()
final class MisconceptionCountsDto {
  const MisconceptionCountsDto({required this.resolved, required this.active});
  factory MisconceptionCountsDto.fromJson(Map<String, dynamic> json) => _$MisconceptionCountsDtoFromJson(json);
  final int resolved;
  final int active;
}

@JsonSerializable()
final class StatsDto {
  const StatsDto({
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
  factory StatsDto.fromJson(Map<String, dynamic> json) => _$StatsDtoFromJson(json);
  final int xpTotal;
  final int xpThisWeek;
  final StreakDto streak;
  final DailyGoalDto dailyGoal;
  @JsonKey(required: true)
  final StatsLeagueDto? league;
  final ConceptCountsDto concepts;
  final TermCountsDto terms;
  final MisconceptionCountsDto misconceptions;
  final int lessonsCompleted;
  final int unitsCompleted;
}
