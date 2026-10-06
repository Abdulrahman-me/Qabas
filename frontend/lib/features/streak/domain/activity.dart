import 'package:equatable/equatable.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/shared/domain/entities/stats.dart';

final class ActivityDay extends Equatable {
  const ActivityDay({required this.date, required this.qualifying, required this.minutes, required this.xp});
  final DateTime date;
  final bool qualifying;
  final int minutes, xp;
  @override
  List<Object?> get props => [date, qualifying, minutes, xp];
}

final class Activity extends Equatable {
  Activity({required this.timezone, required this.from, required this.to, required this.streak, required List<ActivityDay> days})
    : days = List.unmodifiable(days);
  final String timezone;
  final DateTime from, to;
  final Streak streak;
  final List<ActivityDay> days;
  List<DateTime> get week => [for (var i = 6; i >= 0; i--) DateTime(to.year, to.month, to.day - i)];
  bool qualifies(DateTime day) => days.any((d) => d.date == day && d.qualifying);
  @override
  List<Object?> get props => [timezone, from, to, streak, days];
}

abstract interface class ActivityRepository {
  Future<Result<Activity>> load();
}

final class GetActivity {
  const GetActivity(this.repository);
  final ActivityRepository repository;
  Future<Result<Activity>> call() => repository.load();
}
