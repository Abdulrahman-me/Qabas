import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:qabas/core/storage/preferences_store.dart';
import 'package:qabas/mock_backend/mock_db.dart';

/// Demo server persistence. Credentials are never written to preferences.
final class MockStateStore {
  MockStateStore(this.preferences);
  final PreferencesStore preferences;
  Future<void>? _writes;
  static String digest(String token) => sha256.convert(utf8.encode(token)).toString();
  void restore(MockDb db) {
    // TODO(contract): A-33 — persist the mock server across app restarts.
    try {
      final encoded = preferences.string('mock_server');
      if (encoded == null) return;
      final json = jsonDecode(encoded) as Map<String, dynamic>;
      restoreSnapshot(db, json);
    } catch (_) {
      db.reset();
    }
  }

  static void restoreSnapshot(MockDb db, Map<String, dynamic> json) {
    db.user = json['user'] as Map<String, dynamic>?;
    db.reviewerExpiresAt = DateTime.tryParse(json['reviewer_expires_at'] as String? ?? '');
    db.tokenDigests.addAll((json['token_digests'] as List<dynamic>).cast<String>());
    db.completedLessons.addAll((json['completed_lessons'] as List<dynamic>).cast<String>());
    db.stats = json['stats'] as Map<String, dynamic>?;
    void restoreRows(String name, Map<String, Map<String, dynamic>> table) {
      final rows = json[name] as Map<String, dynamic>? ?? {};
      table.addAll(rows.map((key, value) => MapEntry(key, Map<String, dynamic>.from(value as Map))));
    }

    restoreRows('activity', db.activity);
    restoreRows('results', db.results);
    restoreRows('finished_sessions', db.sessions);
    restoreRows('active_sessions', db.sessions);
    // TODO(contract): A-46 — dev/demo active-session and grading persistence.
    restoreRows('session_keys', db.sessionKeys);
    restoreRows('answers', db.answers);
    restoreRows('checks', db.checks);
    restoreRows('conversations', db.conversations);
    restoreRows('raqeeb_messages', db.raqeebMessages);
    restoreRows('raqeeb_work', db.raqeebWork);
    restoreRows('friends', db.friends);
    db.friendsSeeded = json['friends_seeded'] == true;
    restoreRows('finished_duels', db.duels);
    db.inProgressLessons.addAll((json['in_progress_lessons'] as List? ?? []).cast<String>());
    db.openedTerms.addAll((json['opened_terms'] as Map? ?? {}).map((k, v) => MapEntry(k as String, (v as List).cast<String>().toSet())));
    db.dueReviews = json['due_reviews'] as int? ?? 0;
    db.contractCurriculum = json['contract_curriculum'] == true;
    db.pretestedUnits.addAll((json['pretested_units'] as List? ?? []).cast<String>());
    db.passedUnits.addAll((json['passed_units'] as List? ?? []).cast<String>());
    db.unitBestScores.addAll((json['unit_best_scores'] as Map? ?? {}).cast<String, int>());
    db.goalRewardDays.addAll((json['goal_reward_days'] as List? ?? []).cast<String>());
    db.termStates.addAll((json['term_states'] as Map? ?? {}).cast<String, String>());
    db.suspendedLearner = json['suspended_learner'] as Map<String, dynamic>?;
  }

  Future<void> save(MockDb db) {
    final snapshot = jsonEncode(snapshotOf(db));
    final write = _writes == null
        ? preferences.setString('mock_server', snapshot)
        : _writes!.catchError((Object _) {}).then((_) => preferences.setString('mock_server', snapshot));
    late final Future<void> next;
    next = write.whenComplete(() {
      if (identical(_writes, next)) _writes = null;
    });
    return _writes = next;
  }

  static Map<String, dynamic> snapshotOf(MockDb db) => {
    'suspended_learner': db.suspendedLearner,
    'user': db.user,
    'reviewer_expires_at': db.reviewerExpiresAt?.toUtc().toIso8601String(),
    'token_digests': {...db.tokenDigests, ...db.tokens.map(digest)}.toList(),
    'completed_lessons': db.completedLessons.toList(),
    'stats': db.stats,
    'activity': db.activity,
    'results': db.results,
    'finished_sessions': {
      for (final entry in db.sessions.entries)
        if (entry.value['status'] == 'finished') entry.key: entry.value,
    },
    'active_sessions': {
      for (final e in db.sessions.entries)
        if (e.value['status'] != 'finished') e.key: e.value,
    },
    'session_keys': db.sessionKeys,
    'answers': db.answers,
    'checks': db.checks,
    'conversations': db.conversations,
    'raqeeb_messages': db.raqeebMessages,
    'raqeeb_work': db.raqeebWork,
    'friends': db.friends,
    'friends_seeded': db.friendsSeeded,
    'finished_duels': {
      for (final e in db.duels.entries)
        if (e.value['status'] == 'finished' || e.key == 'invitation_consumed') e.key: e.value,
    },
    'in_progress_lessons': db.inProgressLessons.toList(),
    'opened_terms': {for (final e in db.openedTerms.entries) e.key: e.value.toList()},
    'due_reviews': db.dueReviews,
    'contract_curriculum': db.contractCurriculum,
    'pretested_units': db.pretestedUnits.toList(),
    'passed_units': db.passedUnits.toList(),
    'unit_best_scores': db.unitBestScores,
    'goal_reward_days': db.goalRewardDays.toList(),
    'term_states': db.termStates,
  };
}
