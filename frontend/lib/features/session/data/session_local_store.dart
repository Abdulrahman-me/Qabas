import 'dart:async';
import 'dart:convert';

import 'package:qabas/core/events/app_event_bus.dart';
import 'package:qabas/core/events/app_events.dart';
import 'package:qabas/core/storage/preferences_store.dart';
import 'package:qabas/features/session/data/mappers/exercise_mappers.dart';
import 'package:qabas/features/session/domain/entities/exercise.dart';
import 'package:qabas/features/session/domain/logic/session_recovery.dart';

final class SessionLocalStore implements SessionCheckpointStore {
  // TODO(contract): A-46 — versioned local checkpoints; history remains authoritative.
  SessionLocalStore(this.preferences, AppEventBus events) {
    _subscription = events.on<GuestSessionCleared>().listen((_) {
      _epoch++;
      unawaited(_enqueue(() => preferences.setString('session_checkpoints', '{}')));
    });
  }
  final PreferencesStore preferences;
  late final StreamSubscription<GuestSessionCleared> _subscription;
  Future<void>? _pending;
  int _epoch = 0;
  Map<String, dynamic> _rows() {
    try {
      return Map<String, dynamic>.from(jsonDecode(preferences.string('session_checkpoints') ?? '{}') as Map);
    } catch (_) {
      return {};
    }
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final write = _pending == null ? operation() : _pending!.catchError((Object _) {}).then((_) => operation());
    late final Future<void> pending;
    pending = write.whenComplete(() {
      if (identical(_pending, pending)) _pending = null;
    });
    return _pending = pending;
  }

  @override
  Future<SessionCheckpoint?> read(String id, int? version) async {
    if (_pending != null) await _pending!.catchError((Object _) {});
    try {
      final j = _rows()[id] as Map?;
      if (j == null || j['version'] != version) return null;
      return SessionCheckpoint(
        cursor: j['cursor'] as int,
        stage: j['stage'] as String,
        completed: (j['completed'] as List).cast<String>().toSet(),
        retries: (j['retries'] as List).cast<String>(),
        retryCursor: j['retry_cursor'] as int,
        inRetry: j['in_retry'] as bool,
        combo: j['combo'] as int,
        predictions: (j['predictions'] as Map).cast<String, String>(),
        feedbackExercise: j['feedback_exercise'] as String?,
        answer: j['answer_timed_out'] == true ? const TimeoutAnswer() : decodeStoredAnswer((j['answer'] as Map?)?.cast<String, dynamic>()),
        timerDeadline: j['timer_deadline'] == null ? null : DateTime.parse(j['timer_deadline'] as String),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String id, int? version, SessionCheckpoint c) {
    final epoch = _epoch;
    return _enqueue(() async {
      if (epoch != _epoch) return;
      final rows = _rows();
      rows[id] = {
        'version': version, 'cursor': c.cursor, 'stage': c.stage, 'completed': c.completed.toList(), 'retries': c.retries,
        'retry_cursor': c.retryCursor, 'in_retry': c.inRetry, 'combo': c.combo, 'predictions': c.predictions,
        // The identity resolves to the original, immutable server evaluation on load.
        'feedback_exercise': c.feedbackExercise,
        'answer': c.answer == null ? null : answerJson(c.answer!),
        'answer_timed_out': c.answer is TimeoutAnswer,
        'timer_deadline': c.timerDeadline?.toUtc().toIso8601String(),
      };
      await preferences.setString('session_checkpoints', jsonEncode(rows));
    });
  }

  @override
  Future<void> remove(String id) => _enqueue(() async {
    final rows = _rows()..remove(id);
    await preferences.setString('session_checkpoints', jsonEncode(rows));
  });
  Future<void> dispose() async {
    await _subscription.cancel();
    if (_pending != null) await _pending;
  }
}
