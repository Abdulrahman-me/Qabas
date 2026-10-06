import 'dart:async';

import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/error/guard.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/core/events/app_event_bus.dart';
import 'package:qabas/core/events/app_events.dart';
import 'package:qabas/features/session/data/datasources/session_remote_data_source.dart';
import 'package:qabas/features/session/data/dtos/exercise_dto.dart';
import 'package:qabas/features/session/data/dtos/session_dto.dart';
import 'package:qabas/features/session/data/mappers/exercise_mappers.dart';
import 'package:qabas/features/session/data/mappers/session_mappers.dart';
import 'package:qabas/features/session/domain/entities/exercise.dart';
import 'package:qabas/features/session/domain/entities/session.dart';
import 'package:qabas/features/session/domain/entities/session_result.dart';
import 'package:qabas/features/session/domain/repositories/exercise_repository.dart';
import 'package:qabas/features/session/domain/repositories/session_repository.dart';
import 'package:qabas/shared/data/mappers/content_mappers.dart';
import 'package:qabas/shared/domain/entities/content.dart';
import 'package:qabas/shared/domain/repositories/journey_repository.dart';
import 'package:qabas/shared/domain/term_state_store.dart';

final class SessionRepositoryImpl implements SessionRepository, ExerciseRepository, SessionFlowRepository, LessonReaderRepository {
  SessionRepositoryImpl(this.remote, this.journey, this.terms, this.events) {
    _subscription = events.on<GuestSessionCleared>().listen((_) {
      _epoch++;
      _cache.clear();
      _results.clear();
      _finishing.clear();
    });
  }
  final SessionRemoteDataSource remote;
  final JourneyRepository journey;
  final TermStateStore terms;
  final AppEventBus events;
  final _cache = <String, Session>{};
  late final StreamSubscription<GuestSessionCleared> _subscription;
  int _epoch = 0;
  @override
  Future<Result<SessionStart>> startLesson(String id) => guard(() async {
    final epoch = _epoch;
    final response = await remote.start(id);
    final session = response.session.toEntity();
    if (epoch == _epoch) {
      _cache[session.sessionId] = session;
      terms.merge(session.terms);
    }
    var path = journey.cachedJourney;
    if (path == null && id != 'les_u1_l3') {
      final result = await journey.loadJourney();
      if (result case Ok(:final value)) path = value;
    }
    final unit = path?.unitFor(id), entry = path?.lesson(id);
    // TODO(contract): A-36 — metadata for the developer-only legacy reference.
    final info = id == 'les_u1_l3'
        ? const LessonEntryInfo(unitIndex: 2, lessonIndex: 1, minutes: 5, xp: 20)
        : LessonEntryInfo(unitIndex: unit?.index, lessonIndex: entry?.index, minutes: entry?.estimatedMinutes, xp: entry?.xp);
    if (!response.resumed && epoch == _epoch) events.publish(const LearningProgressChanged());
    return SessionStart(session: session, resumed: response.resumed, info: info);
  });
  @override
  Future<Result<Session>> load(String id) => guard(() async {
    final saved = _cache[id];
    if (saved != null) return saved;
    final epoch = _epoch;
    final session = (await remote.load(id)).toEntity();
    if (epoch == _epoch) {
      _cache[id] = session;
      terms.merge(session.terms);
    }
    return session;
  });
  @override
  Future<Result<Session>> startFlow({required SessionKind kind, String? mode, String? unitId}) async {
    final result = await guard(() async {
      final epoch = _epoch;
      final wire = kind == SessionKind.unitTest ? 'unit_test' : kind.name;
      final dto = await remote.api.post('/sessions', body: {'kind': wire, 'mode': ?mode, 'unit_id': ?unitId}, decode: SessionDto.fromJson);
      final session = dto.toEntity();
      if (epoch == _epoch) {
        _cache[session.sessionId] = session;
        terms.merge(session.terms);
      }
      return session;
    });
    if (result case Err<Session>(failure: ConflictFailure(code: 'nothing_to_review'))) {
      events.publish(const LearningProgressChanged());
    }
    return result;
  }

  @override
  Future<Result<void>> abandon(String id) => guard(() async {
    await remote.api.postNoContent('/sessions/${Uri.encodeComponent(id)}/abandon');
    _cache.remove(id);
    events.publish(const LearningProgressChanged());
  });
  @override
  Future<Result<LessonReader>> reader(String id) => guard(() async {
    final d = await remote.api.get('/lessons/${Uri.encodeComponent(id)}', decode: LessonReaderDto.fromJson);
    return LessonReader(
      lessonId: d.lessonId,
      title: d.title,
      items: d.blocks.where((b) => b is! ExerciseBlockDto).map((b) => b.toEntity()).toList(),
      sources: d.sources.map((s) => s.toEntity()).toList(),
      terms: d.terms.map((k, v) => MapEntry(k, v.toEntity())),
    );
  });
  final _results = <String, SessionResult>{};
  final _finishing = <String, Future<Result<SessionResult>>>{};
  @override
  SessionResult? result(String id) => _results[id];
  @override
  Future<Result<AnswerResponse>> submit(
    String id,
    Exercise exercise,
    AnswerPayload answer,
    Duration elapsed, {
    required bool isRetry,
    required bool immediate,
  }) => guard(() async {
    final epoch = _epoch;
    final response = await remote.api.post(
      '/sessions/${Uri.encodeComponent(id)}/answers',
      body: AnswerSubmitDto(
        exerciseId: exercise.id,
        answer: answerJson(answer),
        elapsedMs: elapsed.inMilliseconds,
        isRetry: isRetry,
      ).toJson(),
      decode: (j) => decodeAnswerResponse(j, exercise.type, immediate: immediate),
    );
    if (epoch == _epoch) {
      _cache.remove(id);
      if (response is AnswerEvaluation) {
        final mastered = response.termChanges.where((c) => c.state == TermState.mastered).map((c) => c.id).toSet();
        if (mastered.isNotEmpty) events.publish(TermsMastered(mastered));
      }
    }
    return response;
  });
  @override
  Future<Result<SessionResult>> finish(String id, Duration duration) async {
    if (_results[id] case final saved?) return Ok(saved);
    if (_finishing[id] case final pending?) return pending;
    final epoch = _epoch;
    final pending = guard(() async {
      final value = (await remote.api.post(
        '/sessions/${Uri.encodeComponent(id)}/finish',
        body: FinishRequestDto(durationMs: duration.inMilliseconds).toJson(),
        decode: SessionResultDto.fromJson,
      )).toEntity();
      if (epoch == _epoch) {
        _results[id] = value;
        events.publish(SessionCompleted(sessionId: id, kind: value.kind, streakExtended: value.streakExtended));
        events.publish(TermsMastered(value.termsMastered.map((term) => term.id).toSet()));
        events.publish(const XpChanged());
      }
      return value;
    });
    _finishing[id] = pending;
    try {
      return await pending;
    } finally {
      if (identical(_finishing[id], pending)) {
        unawaited(_finishing.remove(id));
      }
    }
  }

  Future<void> dispose() => _subscription.cancel();
}
