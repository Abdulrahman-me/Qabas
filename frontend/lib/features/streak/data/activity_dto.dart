import 'package:json_annotation/json_annotation.dart';
import 'package:qabas/features/streak/domain/activity.dart';
import 'package:qabas/shared/data/dtos/stats_dto.dart';
import 'package:qabas/shared/domain/entities/stats.dart';
part 'activity_dto.g.dart';

@JsonSerializable()
final class ActivityDayDto {
  const ActivityDayDto({required this.date, required this.qualifying, required this.minutes, required this.xp});
  factory ActivityDayDto.fromJson(Map<String, dynamic> json) => _$ActivityDayDtoFromJson(json);
  final String date;
  final bool qualifying;
  final int minutes, xp;
}

@JsonSerializable()
final class ActivityDto {
  const ActivityDto({required this.timezone, required this.from, required this.to, required this.streak, required this.days});
  factory ActivityDto.fromJson(Map<String, dynamic> json) => _$ActivityDtoFromJson(json);
  final String timezone, from, to;
  final StreakDto streak;
  final List<ActivityDayDto> days;
  Activity toEntity() => Activity(
    timezone: timezone,
    from: DateTime.parse(from),
    to: DateTime.parse(to),
    streak: Streak(current: streak.current, longest: streak.longest, todayCompleted: streak.todayCompleted),
    days: days.map((d) => ActivityDay(date: DateTime.parse(d.date), qualifying: d.qualifying, minutes: d.minutes, xp: d.xp)).toList(),
  );
}
