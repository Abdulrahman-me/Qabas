/// Deterministic finish projection over authoritative evaluations, never drafts.
final class MockFinisher {
  const MockFinisher();
  Map<String, dynamic> build({
    required Map<String, dynamic> session,
    required Map<String, Map<String, dynamic>> evaluations,
    required int durationMs,
    required Map<String, dynamic> streak,
    required Map<String, dynamic> dailyGoal,
    required bool dailyGoalAwarded,
    required Map<String, dynamic> nextStep,
    int passPercent = 80,
    List<Map<String, dynamic>> termsMastered = const [],
    List<Map<String, dynamic>> unlocked = const [],
  }) {
    final id = session['session_id'];
    final exercises = (session['items'] as List)
        .cast<Map>()
        .where((b) => b['type'] == 'exercise')
        .map((b) => b['exercise'] as Map)
        .toList();
    final scored = exercises
        .where((e) => (e['scoring'] as Map)['accuracy'] == true && evaluations['$id:${e['exercise_id']}:false']?['correct'] != null)
        .toList();
    Map<String, dynamic>? score(List<Map> rows) {
      if (rows.isEmpty) return null;
      final correct = rows.where((e) => evaluations['$id:${e['exercise_id']}:false']!['correct'] == true).length;
      return {'correct': correct, 'total': rows.length, 'percent': (100 * correct / rows.length).round()};
    }

    final overall = score(scored) ?? {'correct': 0, 'total': 0, 'percent': 0};
    final perfect = scored.isNotEmpty && overall['correct'] == overall['total'];
    final kind = session['kind'];
    final passed = kind == 'unit_test' ? (overall['percent'] as int) >= passPercent : null;
    final breakdown = <Map<String, dynamic>>[
      if (kind == 'lesson') {'reason': 'lesson_complete', 'xp': 10},
      if (kind == 'lesson' && perfect) {'reason': 'lesson_perfect', 'xp': 3},
      if (kind == 'review') {'reason': 'review_complete', 'xp': 8},
      if (kind == 'pretest') {'reason': 'pretest_complete', 'xp': 5},
      if (passed == true) {'reason': 'unit_test_passed', 'xp': 20},
      for (final e in exercises)
        if (e['type'] == 'recite_verse' && evaluations['$id:${e['exercise_id']}:false']?['xp_awarded'] == 3)
          {'reason': 'recitation_passed', 'xp': 3},
      if (dailyGoalAwarded) {'reason': 'daily_goal_met', 'xp': 2},
    ];
    return {
      'session_id': id, 'kind': kind, 'score': overall, 'passed': passed,
      'xp': {'total': breakdown.fold<int>(0, (sum, grant) => sum + (grant['xp'] as int)), 'breakdown': breakdown},
      'duration_ms': durationMs,
      'layers': {
        'understanding': score(scored.where((e) => (e['scoring'] as Map)['layer'] == 'understand').toList()),
        'applying': score(scored.where((e) => (e['scoring'] as Map)['layer'] == 'apply').toList()),
        'remembering': null,
      },
      'streak': streak, 'daily_goal': dailyGoal,
      // A-21/A-38: the demo grader has no authoritative concept state.
      'mastery_summary': <Object>[], 'terms_mastered': termsMastered,
      'misconceptions': {'activated': <Object>[], 'resolved': <Object>[]},
      'unlocked': unlocked,
      'review_items': kind == 'unit_test' && session['feedback_mode'] == 'end'
          ? [
              for (final e in exercises)
                {
                  for (final key in ['exercise_id', 'correct', 'correct_answer', 'explanation', 'source_ids'])
                    key: evaluations['$id:${e['exercise_id']}:false']![key],
                },
            ]
          : null,
      'next_step': nextStep,
    };
  }
}
