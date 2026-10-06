import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:qabas/core/network/backend_transport.dart';
import 'package:qabas/mock_backend/controls/mock_controls.dart';
import 'package:qabas/mock_backend/fixtures.dart';
import 'package:qabas/mock_backend/handlers/journey_handlers.dart';
import 'package:qabas/mock_backend/handlers/mock_activity.dart';
import 'package:qabas/mock_backend/handlers/mock_finisher.dart';
import 'package:qabas/mock_backend/handlers/mock_grader.dart';
import 'package:qabas/mock_backend/handlers/mock_learning_catalog.dart';
import 'package:qabas/mock_backend/mock_db.dart';
import 'package:qabas/mock_backend/mock_router.dart';
import 'package:uuid/uuid.dart';

void registerSessions(MockRouter router, MockDb db, Fixtures fixtures, MockControls controls) {
  Future<void> applyDraftVisibility(Map<String, dynamic> session) async {
    if (!controls.hideDraftNotices) return;
    final notices = await fixtures.object('unit0/DRAFT_NOTICES.json');
    final ids = ((notices['block_ids_by_lesson'] as Map)[session['lesson_id']] as List?) ?? [];
    session['items'] = (session['items'] as List).cast<Map>().where((b) => !ids.contains(b['block_id'])).toList();
  }

  // Serialize creates so concurrent retries get the same pinned snapshot.
  Future<void>? pending;
  Future<BackendResponse> create(BackendRequest request) async {
    final body = request.body;
    if (body is Map<String, dynamic> && body['kind'] != 'lesson') {
      final kind = body['kind'], mode = body['mode'], unit = body['unit_id'];
      if (kind is! String ||
          !['review', 'pretest', 'unit_test'].contains(kind) ||
          (kind == 'review' ? mode is! String || unit != null : unit is! String || mode != null)) {
        return BackendResponse.error(400, 'validation_error', 'Session request shape');
      }
      final active = db.sessions.values
          .where((s) => s['status'] == 'active' && s['kind'] == kind && s['mode'] == mode && s['unit_id'] == unit)
          .firstOrNull;
      if (active != null) return BackendResponse(200, jsonDecode(jsonEncode(active)));
      if (kind == 'review' && db.dueReviews == 0) return BackendResponse.error(409, 'nothing_to_review', 'No review is due');
      final language = request.header('Accept-Language') ?? db.user!['language'] as String;
      final catalog = MockLearningCatalog(fixtures, db);
      final session = await catalog.flow(kind, unit as String?, mode as String?, language, db.user!['track'] as String);
      if (session == null) return BackendResponse.error(404, 'not_found', 'Session is unavailable');
      session['session_id'] = 'ses_${const Uuid().v4()}';
      session['started_at'] = db.now().toUtc().toIso8601String();
      session['answers'] = <Object>[];
      session['answered_exercises'] = 0;
      final id = session['session_id'] as String;
      db.sessionKeys[id] = await catalog.keys(session);
      db.sessions[id] = session;
      return BackendResponse(201, jsonDecode(jsonEncode(session)));
    }
    if (body is! Map<String, dynamic> || body['kind'] != 'lesson' || body['lesson_id'] is! String) {
      return BackendResponse.error(400, 'validation_error', 'A lesson session request is required');
    }
    final id = body['lesson_id'] as String;
    final active = db.sessions.values.where((s) => s['kind'] == 'lesson' && s['lesson_id'] == id && s['status'] == 'active').firstOrNull;
    if (active != null) return BackendResponse(200, jsonDecode(jsonEncode(active)));
    final languageExtra = request.header('Accept-Language') ?? db.user!['language'] as String;
    final catalog = MockLearningCatalog(fixtures, db);
    final extra = await catalog.extraLesson(id, languageExtra, db.user!['track'] as String);
    if (extra != null) {
      if (db.contractCurriculum && id != 'les_test_all') {
        final journey = await mockContractJourney(fixtures, db, languageExtra, db.user!['track'] as String);
        final lesson = (journey['units'] as List)
            .cast<Map>()
            .expand((u) => (u['lessons'] as List).cast<Map>())
            .firstWhere((l) => l['lesson_id'] == id);
        if (lesson['state'] == 'locked' && lesson['soft_lock'] is Map) {
          final lock = lesson['soft_lock'] as Map;
          return BackendResponse.error(409, 'prerequisite_unmet', 'Complete the prerequisites first', {
            'prerequisite_lesson_ids': (lock['prerequisites'] as List).cast<Map>().map((p) => p['lesson_id']).toList(),
            'start_with_lesson_id': (lock['start_with'] as Map)['lesson_id'],
          });
        }
      }
      extra['session_id'] = 'ses_${const Uuid().v4()}';
      extra['started_at'] = db.now().toUtc().toIso8601String();
      extra['answers'] = <Object>[];
      extra['answered_exercises'] = 0;
      final sessionId = extra['session_id'] as String;
      db.sessionKeys[sessionId] = await catalog.keys(extra);
      db.sessions[sessionId] = extra;
      db.inProgressLessons.add(id);
      return BackendResponse(201, jsonDecode(jsonEncode(extra)));
    }
    final curriculum = await fixtures.object('demo_curriculum/curriculum.json');
    final language = request.header('Accept-Language') ?? db.user!['language'] as String;
    final track = db.user!['track'] as String;
    final journey = computeJourney(curriculum, language, track, completed: db.completedLessons, inProgress: db.inProgressLessons);
    final lessons = (journey['units'] as List).cast<Map>().expand((u) => (u['lessons'] as List).cast<Map>());
    final entry = lessons.where((l) => l['lesson_id'] == id).firstOrNull;
    if (entry?['state'] == 'locked') {
      final lock = entry!['soft_lock'] as Map;
      return BackendResponse.error(409, 'prerequisite_unmet', 'Complete the prerequisites first', {
        'prerequisite_lesson_ids': (lock['prerequisites'] as List).cast<Map>().map((r) => r['lesson_id']).toList(),
        'start_with_lesson_id': (lock['start_with'] as Map)['lesson_id'],
      });
    }
    final index = await fixtures.object('unit0/SESSION_INDEX.json');
    final row = (index['sessions'] as List)
        .cast<Map>()
        .where((r) => r['lesson_id'] == id && r['variant'] == '${language}_explorer')
        .firstOrNull;
    String? path;
    // Fixture catalog decisions A-21, A-23, A-30; IDs remain opaque.
    if (id == 'les_u1_l3') {
      path = 'salah/session_salah_${language}_$track.json';
    } else if (id == 'les_u1_l1') {
      path = 'test_lessons/u1l1_${language}_$track.json';
    } else if (row != null && entry != null) {
      path = 'unit0/${row['path']}';
    }
    if (path == null) return BackendResponse.error(404, 'not_found', 'Lesson is not available');
    final session = await fixtures.object(path);
    // A-22: only authored block IDs are filtered, never content wording.
    await applyDraftVisibility(session);
    if (controls.unknownVisual) {
      for (final item in (session['items'] as List).cast<Map>()) {
        if (item['visual'] case final Map visual) visual['kind'] = 'unreleased';
      }
    }
    session['session_id'] = 'ses_${const Uuid().v4()}';
    session['started_at'] = db.now().toUtc().toIso8601String();
    for (final term in (session['terms'] as Map).values.cast<Map>()) {
      if (db.termStates[term['term_id']] case final state?) term['state'] = state;
    }
    session['answers'] = <Object>[];
    session['answered_exercises'] = 0;
    final keyFile = id == 'les_u1_l3'
        ? 'private/salah_keys_${language}_$track.json'
        : id == 'les_u1_l1'
        ? 'private/test_lessons/u1l1_keys.json'
        : 'private/unit0/${path.split('/').last}';
    final keys = await fixtures.object(keyFile);
    final privateKeys = <String, dynamic>{};
    if (keys['exercises'] case final Map exercises) {
      privateKeys.addAll(Map<String, dynamic>.from(exercises));
    } else {
      final answers = keys['answers'] as Map;
      final feedback = keys['feedback'] as Map;
      for (final e in answers.entries) {
        privateKeys[e.key as String] = {'answer_key': e.value, ...Map<String, dynamic>.from(feedback[e.key] as Map)};
      }
    }
    db.sessionKeys[session['session_id'] as String] = privateKeys;
    db.sessions[session['session_id'] as String] = session;
    db.inProgressLessons.add(id);
    return BackendResponse(201, jsonDecode(jsonEncode(session)));
  }

  Future<BackendResponse> answer(BackendRequest request, Map<String, String> params) async {
    final session = db.sessions[params['id']];
    if (session == null) return BackendResponse.error(404, 'not_found', 'Session not found');
    final body = request.body;
    if (body is! Map<String, dynamic> || body['exercise_id'] is! String || body['is_retry'] is! bool) {
      return BackendResponse.error(400, 'validation_error', 'Answer identity required');
    }
    final exerciseId = body['exercise_id'] as String, retry = body['is_retry'] as bool;
    final identity = '${params['id']}:$exerciseId:$retry';
    BackendResponse response(Map<String, dynamic> evaluation) => BackendResponse(
      200,
      jsonDecode(jsonEncode(session['feedback_mode'] == 'immediate' ? evaluation : {'exercise_id': exerciseId, 'recorded': true})),
    );
    final saved = db.answers[identity];
    if (saved != null) return response(saved);
    if (session['status'] != 'active') {
      return BackendResponse.error(
        409,
        session['status'] == 'finished' ? 'session_finished' : 'session_not_active',
        'Session is not active',
      );
    }
    final exercises = (session['items'] as List)
        .cast<Map>()
        .where((b) => b['type'] == 'exercise')
        .map((b) => Map<String, dynamic>.from(b['exercise'] as Map))
        .toList();
    final ex = exercises.where((e) => e['exercise_id'] == exerciseId).firstOrNull;
    if (ex == null) return BackendResponse.error(400, 'validation_error', 'Exercise was not served');
    final first = db.answers['${params['id']}:$exerciseId:false'];
    if (retry) {
      if (session['kind'] != 'lesson' ||
          session['feedback_mode'] != 'immediate' ||
          first?['correct'] != false ||
          ['recite_verse', 'flashcard'].contains(ex['type'])) {
        return BackendResponse.error(409, 'retry_not_allowed', 'Retry is not allowed');
      }
    } else {
      for (final e in exercises) {
        if (e['exercise_id'] == exerciseId) break;
        if (!db.answers.containsKey('${params['id']}:${e['exercise_id']}:false')) {
          return BackendResponse.error(409, 'out_of_order', 'Answer the preceding exercise');
        }
      }
    }
    if (body['elapsed_ms'] is! int || (body['elapsed_ms'] as int) < 0 || body.length != 4 || !body.containsKey('answer')) {
      return BackendResponse.error(400, 'validation_error', 'Answer request shape');
    }
    final recitationId = (body['answer'] is Map) ? (body['answer'] as Map)['check_id'] : null;
    if (recitationId != null) {
      final check = db.checks[recitationId], p = ex['payload'] as Map;
      if (ex['type'] != 'recite_verse' ||
          check == null ||
          check['user_id'] != db.user!['user_id'] ||
          check['surah'] != p['surah'] ||
          check['ayah'] != p['ayah'] ||
          check['word_start'] != p['word_start'] ||
          check['word_end'] != p['word_end'] ||
          check['expected_digest'] != sha256.convert(utf8.encode(p['text_uthmani'] as String)).toString()) {
        return BackendResponse.error(409, 'recitation_check_mismatch', 'Record this verse again');
      }
    }
    try {
      const MockGrader().validate(ex, body['answer']);
    } on FormatException {
      return BackendResponse.error(400, 'validation_error', 'Answer does not match the served payload');
    }
    final key = Map<String, dynamic>.from(db.sessionKeys[params['id']]![exerciseId] as Map);
    final evaluation = const MockGrader().grade(ex, body['answer'], key);
    if (recitationId != null) {
      final checked = db.checks[recitationId]!['result'] as Map;
      evaluation['correct'] = checked['status'] == 'unclear' ? null : checked['passed'];
      evaluation['xp_awarded'] = checked['passed'] == true ? 3 : 0;
    }
    db.answers[identity] = evaluation;
    (session['answers'] as List).add({
      'exercise_id': exerciseId,
      'is_retry': retry,
      'result': session['feedback_mode'] == 'immediate'
          ? (evaluation['correct'] == null
                ? 'neutral'
                : evaluation['correct'] == true
                ? 'correct'
                : 'incorrect')
          : 'hidden',
      'recorded_at': DateTime.now().toUtc().toIso8601String(),
      'evaluation': session['feedback_mode'] == 'immediate' ? evaluation : null,
    });
    if (!retry) session['answered_exercises'] = (session['answered_exercises'] as int) + 1;
    return response(evaluation);
  }

  Future<BackendResponse> finish(BackendRequest request, Map<String, String> params) async {
    final id = params['id']!, session = db.sessions[id];
    if (session == null) return BackendResponse.error(404, 'not_found', 'Session not found');
    final stored = db.results[id];
    if (stored != null) return BackendResponse(200, jsonDecode(jsonEncode(stored)));
    if (session['status'] != 'active') return BackendResponse.error(409, 'session_not_active', 'Session is not active');
    final body = request.body;
    if (body is! Map || body.length != 1 || body['duration_ms'] is! int) {
      return BackendResponse.error(400, 'validation_error', 'Duration required');
    }
    final exercises = (session['items'] as List)
        .cast<Map>()
        .where((b) => b['type'] == 'exercise')
        .map((b) => b['exercise'] as Map)
        .toList();
    final missing = exercises.where((e) => !db.answers.containsKey('$id:${e['exercise_id']}:false')).map((e) => e['exercise_id']).toList();
    if (missing.isNotEmpty) {
      return BackendResponse.error(409, 'out_of_order', 'First attempts are incomplete', {'missing_exercise_ids': missing});
    }
    // Load all required assets before mutating the serialized learner transaction.
    await seedMockActivity(db, fixtures);
    final curriculum = await fixtures.object('demo_curriculum/curriculum.json');
    final language = request.header('Accept-Language') ?? db.user!['language'] as String;
    final track = db.user!['track'] as String;
    final synthetic = db.contractCurriculum ? await fixtures.object('contract/curriculum_test/journey_${language}_$track.json') : null;
    Map<String, dynamic> path() => synthetic != null
        ? projectContractJourney(jsonDecode(jsonEncode(synthetic)) as Map<String, dynamic>, db)
        : computeJourney(curriculum, language, track, completed: db.completedLessons, inProgress: db.inProgressLessons);
    List<Map> lessons(Map journey) => (journey['units'] as List).cast<Map>().expand((u) => (u['lessons'] as List).cast<Map>()).toList();
    final previousPath = path(), before = lessons(previousPath);
    final maximum = db.now().toUtc().difference(DateTime.parse(session['started_at'] as String)).inMilliseconds;
    final duration = (body['duration_ms'] as int).clamp(0, maximum < 0 ? 0 : maximum);
    final date = mockDate(mockDay(db)), extended = db.activity[date]?['qualifying'] != true;
    final day = db.activity.putIfAbsent(date, () => {'date': date, 'qualifying': false, 'minutes': 0, 'xp': 0, '_duration_ms': 0});
    day['_duration_ms'] = (day['_duration_ms'] as int) + duration.clamp(0, 1200000);
    day['minutes'] = (day['_duration_ms'] as int) ~/ 60000;
    day['qualifying'] = true;
    final goal = mockGoal(db), goalAwarded = goal['met'] == true && db.goalRewardDays.add(date);
    final lessonId = session['lesson_id'] as String?;
    final newCompletion = session['kind'] == 'lesson' && lessonId != null && db.completedLessons.add(lessonId);
    if (lessonId != null) db.inProgressLessons.remove(lessonId);
    final after = path();
    final opened = db.openedTerms[id] ?? <String>{};
    final terms = session['terms'] as Map;
    final promoted = <Map<String, dynamic>>[];
    for (final termId in opened) {
      if (db.termStates[termId] == 'learning' && terms[termId] is Map) {
        db.termStates[termId] = 'mastered';
        promoted.add({'term_id': termId, 'text': (terms[termId] as Map)['text']});
      }
    }
    final streak = mockStreak(db);
    final result = const MockFinisher().build(
      session: session,
      evaluations: db.answers,
      durationMs: duration,
      streak: {'current': streak['current'], 'extended_today': extended},
      dailyGoal: goal,
      dailyGoalAwarded: goalAwarded,
      nextStep: computeNextStep(after, db.dueReviews),
      passPercent:
          ((previousPath['units'] as List).cast<Map>().where((u) => u['unit_id'] == session['unit_id']).firstOrNull?['unit_test']
                  as Map?)?['pass_percent']
              as int? ??
          80,
      termsMastered: promoted,
      unlocked: [
        for (final l in lessons(after))
          if (l['state'] == 'available' && before.any((b) => b['lesson_id'] == l['lesson_id'] && b['state'] == 'locked'))
            {'type': 'lesson', 'id': l['lesson_id'], 'title': l['title']},
      ],
    );
    final xp = (result['xp'] as Map)['total'] as int;
    day['xp'] = (day['xp'] as int) + xp;
    db.stats!['xp_total'] = (db.stats!['xp_total'] as int) + xp;
    db.stats!['xp_this_week'] = (db.stats!['xp_this_week'] as int) + xp;
    db.stats!['streak'] = streak;
    if (newCompletion) db.stats!['lessons_completed'] = (db.stats!['lessons_completed'] as int) + 1;
    final newlyCompletedUnits = (after['units'] as List)
        .cast<Map>()
        .where(
          (u) =>
              u['state'] == 'completed' &&
              (previousPath['units'] as List).cast<Map>().any((old) => old['unit_id'] == u['unit_id'] && old['state'] != 'completed'),
        )
        .length;
    db.stats!['units_completed'] = (db.stats!['units_completed'] as int) + newlyCompletedUnits;
    final termCounts = db.stats!['terms'] as Map;
    termCounts['mastered'] = (termCounts['mastered'] as int) + promoted.length;
    session['status'] = 'finished';
    if (session['feedback_mode'] == 'end') {
      for (final answer in (session['answers'] as List).cast<Map>()) {
        final evaluation = db.answers['$id:${answer['exercise_id']}:${answer['is_retry']}']!;
        answer['evaluation'] = evaluation;
        answer['result'] = evaluation['correct'] == null
            ? 'neutral'
            : evaluation['correct'] == true
            ? 'correct'
            : 'incorrect';
      }
    }
    db.results[id] = result;
    if (session['kind'] == 'lesson') db.dueReviews = (db.dueReviews + 1).clamp(0, 12);
    if (session['kind'] == 'review') db.dueReviews = 0;
    if (session['kind'] == 'pretest') db.pretestedUnits.add(session['unit_id'] as String);
    if (session['kind'] == 'unit_test') {
      final unit = session['unit_id'] as String, score = (result['score'] as Map)['percent'] as int;
      db.unitBestScores[unit] = score > (db.unitBestScores[unit] ?? 0) ? score : db.unitBestScores[unit] ?? 0;
      if (result['passed'] == true) db.passedUnits.add(unit);
    }
    result['next_step'] = db.contractCurriculum ? computeContractNextStep(path(), db.dueReviews) : computeNextStep(path(), db.dueReviews);
    return BackendResponse(200, jsonDecode(jsonEncode(result)));
  }

  Future<BackendResponse> serial(Future<BackendResponse> Function() action) {
    final result = pending == null ? action() : pending!.then((_) => action());
    late final Future<void> next;
    next = result.then<void>((_) {}, onError: (Object _, StackTrace _) {}).whenComplete(() {
      if (identical(pending, next)) pending = null;
    });
    pending = next;
    return result;
  }

  router.routes.addAll([
    MockRoute('GET', '/lessons/{id}', (r, p) async {
      final language = r.header('Accept-Language') ?? db.user!['language'] as String,
          track = db.user!['track'] as String,
          lessonId = p['id']!;
      final session = await MockLearningCatalog(fixtures, db).readerSource(lessonId, language, track);
      if (session == null) return BackendResponse.error(404, 'not_found', 'Lesson unavailable');
      await applyDraftVisibility(session);
      return BackendResponse(200, {
        'lesson_id': session['lesson_id'],
        'unit_id': session['unit_id'],
        'title': session['title'],
        'subtitle': session['subtitle'],
        'lesson_type': session['lesson_type'],
        'reviewed_by': session['reviewed_by'],
        'version': session['lesson_version'],
        'source_count': session['source_count'],
        'objectives': session['objectives'],
        'blocks': (session['items'] as List).cast<Map>().where((i) => i['type'] != 'exercise').toList(),
        'completion': session['completion'],
        'sources': session['sources'],
        'terms': session['terms'],
      });
    }),
    MockRoute('POST', '/sessions', (request, _) => serial(() => create(request))),
    MockRoute('POST', '/sessions/{id}/answers', (r, p) => serial(() => answer(r, p))),
    MockRoute('POST', '/sessions/{id}/finish', (r, p) => serial(() => finish(r, p))),
    MockRoute(
      'POST',
      '/sessions/{id}/abandon',
      (r, p) => serial(() async {
        final session = db.sessions[p['id']];
        if (session == null) return BackendResponse.error(404, 'not_found', 'Session not found');
        if (session['status'] == 'finished') return BackendResponse.error(409, 'session_finished', 'Session finished');
        session['status'] = 'abandoned';
        db.inProgressLessons.remove(session['lesson_id']);
        return const BackendResponse(204, null);
      }),
    ),
    MockRoute('GET', '/sessions/{id}', (_, params) async {
      final session = db.sessions[params['id']];
      return session == null
          ? BackendResponse.error(404, 'not_found', 'Session not found')
          : BackendResponse(200, jsonDecode(jsonEncode(session)));
    }),
    MockRoute('POST', '/glossary/{id}/opened', (_, params) async {
      final termId = params['id']!;
      for (final session in db.sessions.values.where((s) => s['status'] == 'active')) {
        final term = (session['terms'] as Map)[termId];
        if (term is! Map) continue;
        db.termStates.putIfAbsent(termId, () => term['state'] as String);
        if (db.termStates[termId] == 'new') db.termStates[termId] = 'learning';
        db.openedTerms.putIfAbsent(session['session_id'] as String, () => {}).add(termId);
      }
      return const BackendResponse(204, null);
    }),
  ]);
}
