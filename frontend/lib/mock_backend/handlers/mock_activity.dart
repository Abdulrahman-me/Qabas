import 'dart:convert';
import 'package:qabas/mock_backend/fixtures.dart';
import 'package:qabas/mock_backend/mock_db.dart';

String mockDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
DateTime mockDay(MockDb db) {
  final n = db.now();
  return DateTime(n.year, n.month, n.day);
}

Future<void> seedMockActivity(MockDb db, Fixtures fixtures) async {
  if (db.stats != null) return;
  final stats = await fixtures.example('Stats');
  if (db.stats != null) return;
  db.stats = stats;
  // A-40: anchor the example's streak to yesterday, leaving today's celebration open.
  final count = (stats['streak'] as Map)['current'] as int;
  for (var i = count; i > 0; i--) {
    final date = mockDate(mockDay(db).subtract(Duration(days: i)));
    db.activity.putIfAbsent(date, () => {'date': date, 'qualifying': true, 'minutes': 0, 'xp': 0, '_duration_ms': 0});
  }
}

Map<String, dynamic> mockStreak(MockDb db) {
  final day = mockDay(db);
  final today = db.activity[mockDate(day)]?['qualifying'] == true;
  var cursor = today ? day : day.subtract(const Duration(days: 1)), current = 0;
  while (db.activity[mockDate(cursor)]?['qualifying'] == true) {
    current++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  final longest = (db.stats!['streak'] as Map)['longest'] as int;
  return {'current': current, 'longest': current > longest ? current : longest, 'today_completed': today};
}

Map<String, dynamic> mockGoal(MockDb db) {
  final target = db.user!['daily_goal_minutes'] as int;
  final minutes = db.activity[mockDate(mockDay(db))]?['minutes'] as int? ?? 0;
  return {'minutes': target, 'minutes_today': minutes, 'met': minutes >= target};
}

Map<String, dynamic> mockStats(MockDb db) {
  final value = jsonDecode(jsonEncode(db.stats)) as Map<String, dynamic>;
  value['streak'] = mockStreak(db);
  value['daily_goal'] = mockGoal(db);
  return value;
}

Map<String, dynamic> mockActivity(MockDb db, {DateTime? from, DateTime? to}) {
  final end = to ?? mockDay(db), start = from ?? end.subtract(const Duration(days: 34));
  final first = mockDate(start), last = mockDate(end);
  final days = db.activity.entries.where((e) => e.key.compareTo(first) >= 0 && e.key.compareTo(last) <= 0).toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return {
    'timezone': db.user!['timezone'],
    'from': first,
    'to': last,
    'streak': mockStreak(db),
    'days': [
      for (final row in days)
        {
          for (final key in ['date', 'qualifying', 'minutes', 'xp']) key: row.value[key],
        },
    ],
  };
}
