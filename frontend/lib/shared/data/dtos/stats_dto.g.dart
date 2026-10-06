// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stats_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StreakDto _$StreakDtoFromJson(Map<String, dynamic> json) => $checkedCreate('StreakDto', json, ($checkedConvert) {
  final val = StreakDto(
    current: $checkedConvert('current', (v) => (v as num).toInt()),
    longest: $checkedConvert('longest', (v) => (v as num).toInt()),
    todayCompleted: $checkedConvert('today_completed', (v) => v as bool),
  );
  return val;
}, fieldKeyMap: const {'todayCompleted': 'today_completed'});

DailyGoalDto _$DailyGoalDtoFromJson(Map<String, dynamic> json) => $checkedCreate('DailyGoalDto', json, ($checkedConvert) {
  final val = DailyGoalDto(
    minutes: $checkedConvert('minutes', (v) => (v as num).toInt()),
    minutesToday: $checkedConvert('minutes_today', (v) => (v as num).toInt()),
    met: $checkedConvert('met', (v) => v as bool),
  );
  return val;
}, fieldKeyMap: const {'minutesToday': 'minutes_today'});

StatsLeagueDto _$StatsLeagueDtoFromJson(Map<String, dynamic> json) => $checkedCreate('StatsLeagueDto', json, ($checkedConvert) {
  final val = StatsLeagueDto(
    leagueId: $checkedConvert('league_id', (v) => v as String),
    rank: $checkedConvert('rank', (v) => (v as num).toInt()),
    size: $checkedConvert('size', (v) => (v as num).toInt()),
  );
  return val;
}, fieldKeyMap: const {'leagueId': 'league_id'});

ConceptCountsDto _$ConceptCountsDtoFromJson(Map<String, dynamic> json) => $checkedCreate('ConceptCountsDto', json, ($checkedConvert) {
  final val = ConceptCountsDto(
    mastered: $checkedConvert('mastered', (v) => (v as num).toInt()),
    learning: $checkedConvert('learning', (v) => (v as num).toInt()),
  );
  return val;
});

TermCountsDto _$TermCountsDtoFromJson(Map<String, dynamic> json) => $checkedCreate('TermCountsDto', json, ($checkedConvert) {
  final val = TermCountsDto(
    mastered: $checkedConvert('mastered', (v) => (v as num).toInt()),
    seen: $checkedConvert('seen', (v) => (v as num).toInt()),
  );
  return val;
});

MisconceptionCountsDto _$MisconceptionCountsDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('MisconceptionCountsDto', json, ($checkedConvert) {
      final val = MisconceptionCountsDto(
        resolved: $checkedConvert('resolved', (v) => (v as num).toInt()),
        active: $checkedConvert('active', (v) => (v as num).toInt()),
      );
      return val;
    });

StatsDto _$StatsDtoFromJson(Map<String, dynamic> json) => $checkedCreate(
  'StatsDto',
  json,
  ($checkedConvert) {
    $checkKeys(json, requiredKeys: const ['league']);
    final val = StatsDto(
      xpTotal: $checkedConvert('xp_total', (v) => (v as num).toInt()),
      xpThisWeek: $checkedConvert('xp_this_week', (v) => (v as num).toInt()),
      streak: $checkedConvert('streak', (v) => StreakDto.fromJson(v as Map<String, dynamic>)),
      dailyGoal: $checkedConvert('daily_goal', (v) => DailyGoalDto.fromJson(v as Map<String, dynamic>)),
      league: $checkedConvert('league', (v) => v == null ? null : StatsLeagueDto.fromJson(v as Map<String, dynamic>)),
      concepts: $checkedConvert('concepts', (v) => ConceptCountsDto.fromJson(v as Map<String, dynamic>)),
      terms: $checkedConvert('terms', (v) => TermCountsDto.fromJson(v as Map<String, dynamic>)),
      misconceptions: $checkedConvert('misconceptions', (v) => MisconceptionCountsDto.fromJson(v as Map<String, dynamic>)),
      lessonsCompleted: $checkedConvert('lessons_completed', (v) => (v as num).toInt()),
      unitsCompleted: $checkedConvert('units_completed', (v) => (v as num).toInt()),
    );
    return val;
  },
  fieldKeyMap: const {
    'xpTotal': 'xp_total',
    'xpThisWeek': 'xp_this_week',
    'dailyGoal': 'daily_goal',
    'lessonsCompleted': 'lessons_completed',
    'unitsCompleted': 'units_completed',
  },
);
