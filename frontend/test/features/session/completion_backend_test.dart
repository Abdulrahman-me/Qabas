import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:qabas/app/config/app_config.dart';
import 'package:qabas/app/di/injector.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/core/events/app_event_bus.dart';
import 'package:qabas/core/events/app_events.dart';
import 'package:qabas/core/network/api_client.dart';
import 'package:qabas/features/session/data/dtos/exercise_dto.dart';
import 'package:qabas/features/session/data/mappers/exercise_mappers.dart';
import 'package:qabas/features/session/domain/entities/session.dart';
import 'package:qabas/features/session/domain/entities/session_result.dart';
import 'package:qabas/features/session/domain/usecases/session_actions.dart';
import 'package:qabas/features/session/presentation/bloc/session_result_bloc.dart';
import 'package:qabas/features/streak/domain/activity.dart';
import 'package:qabas/mock_backend/fixtures.dart';
import 'package:qabas/mock_backend/handlers/mock_activity.dart';
import 'package:qabas/mock_backend/handlers/mock_finisher.dart';
import 'package:qabas/mock_backend/mock_backend.dart';
import 'package:qabas/mock_backend/mock_db.dart';
import 'package:qabas/shared/domain/entities/journey.dart';
import 'package:qabas/shared/domain/entities/stats.dart';
import 'package:qabas/shared/domain/repositories/journey_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../support/fakes.dart';

void main() {
  final fixtures = Fixtures(read: (p) => File(p).readAsString());
  test('MockFinisher matches normative ses_91ab score, layers, XP and retry exclusion', () async {
    final session = await fixtures.example('Session'), expected = await fixtures.example('SessionResult');
    final history = await fixtures.object('contract/workflows/ses_91ab.json');
    final id = session['session_id'];
    final evaluations = {
      for (final a in (history['answers'] as List).cast<Map>())
        '$id:${a['exercise_id']}:${a['is_retry']}': <String, dynamic>{
          'correct':
              (session['items'] as List).cast<Map>().any(
                (item) =>
                    item['type'] == 'exercise' &&
                    (item['exercise'] as Map)['type'] == 'recite_verse' &&
                    (item['exercise'] as Map)['exercise_id'] == a['exercise_id'],
              )
              ? null
              : a['result'] == 'correct',
          if ((session['items'] as List).cast<Map>().any(
                (item) =>
                    item['type'] == 'exercise' &&
                    (item['exercise'] as Map)['type'] == 'recite_verse' &&
                    (item['exercise'] as Map)['exercise_id'] == a['exercise_id'],
              ) &&
              a['result'] == 'correct')
            'xp_awarded': 3,
        },
    };
    final actual = const MockFinisher().build(
      session: session,
      evaluations: evaluations,
      durationMs: 312000,
      streak: Map<String, dynamic>.from(expected['streak'] as Map),
      dailyGoal: Map<String, dynamic>.from(expected['daily_goal'] as Map),
      dailyGoalAwarded: history['daily_goal_met'] == true,
      nextStep: Map<String, dynamic>.from(expected['next_step'] as Map),
    );
    for (final field in ['score', 'layers', 'xp', 'duration_ms', 'streak', 'daily_goal', 'next_step']) {
      expect(actual[field], expected[field], reason: field);
    }
    final result = SessionResultDto.fromJson(actual).toEntity();
    expect(result.xp, 15);
    expect(result.understanding!.percent, 50);
    expect(result.perfect, false);
    expect(() => result.xpBreakdown.clear(), throwsUnsupportedError);
  });
  for (final language in ['en', 'ar']) {
    for (final track in ['explorer', 'new_muslim']) {
      test('Salah $language/$track uses 6 accuracy, 3 Understanding, 2 Applying, neutral recitation', () async {
        final s = await fixtures.object('salah/session_salah_${language}_$track.json'), id = s['session_id'];
        final exercises = (s['items'] as List).cast<Map>().where((b) => b['type'] == 'exercise').map((b) => b['exercise'] as Map).toList();
        final evaluations = {
          for (final e in exercises)
            '$id:${e['exercise_id']}:false': <String, dynamic>{'correct': e['type'] == 'recite_verse' ? null : true},
        };
        final first = exercises.firstWhere((e) => (e['scoring'] as Map)['layer'] == 'understand');
        evaluations['$id:${first['exercise_id']}:false']!['correct'] = false;
        evaluations['$id:${first['exercise_id']}:true'] = {'correct': true};
        final r = const MockFinisher().build(
          session: s,
          evaluations: evaluations,
          durationMs: 98000,
          streak: {'current': 4, 'extended_today': true},
          dailyGoal: {'minutes': 10, 'minutes_today': 1, 'met': false},
          dailyGoalAwarded: false,
          nextStep: Map<String, dynamic>.from((await fixtures.example('SessionResult'))['next_step'] as Map),
        );
        expect(r['score'], {'correct': 5, 'total': 6, 'percent': 83});
        expect(r['layers'], {
          'understanding': {'correct': 2, 'total': 3, 'percent': 67},
          'applying': {'correct': 2, 'total': 2, 'percent': 100},
          'remembering': null,
        });
        expect((r['xp'] as Map)['total'], 10);
      });
    }
  }
  test('activity follows mock server dates, drops gaps and keeps historical longest', () async {
    var date = DateTime(2026, 10, 5);
    final db = MockDb(now: () => date)..user = await fixtures.example('User');
    await seedMockActivity(db, fixtures);
    expect(mockStreak(db), {'current': 3, 'longest': 5, 'today_completed': false});
    date = DateTime(2026, 10, 6);
    expect(mockStreak(db)['current'], 0);
    final range = mockActivity(db);
    expect(range['to'], '2026-10-06');
    expect(range['from'], '2026-09-02');
  });
  group('real mock endpoint and result cache', () {
    late AppDependencies d;
    late MockBackend backend;
    final token = MemoryTokens()..value = 'phase8-tests';
    Future<AppDependencies> create() => AppDependencies.create(config: AppConfig(), tokens: token, mockFixtures: fixtures);
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      d = await create();
      backend = d.services<MockBackend>();
      backend.controls.fast = true;
      backend.db.tokens.add(token.value!);
      backend.db.user = await fixtures.example('User');
      backend.db.user!['language'] = 'en';
      backend.db.user!['track'] = 'explorer';
    });
    tearDown(() => d.dispose());
    Future<Session> completed(String lessonId, {bool openTerm = false}) async {
      final start = (await d.services<StartLessonSession>()(lessonId) as Ok<SessionStart>).value;
      final session = start.session, raw = backend.db.sessions[session.sessionId]!;
      raw['started_at'] = DateTime.now().subtract(const Duration(minutes: 20)).toUtc().toIso8601String();
      for (final item in session.items.whereType<ExerciseItem>()) {
        backend.db.answers['${session.sessionId}:${item.exerciseId}:false'] = {
          'correct': item.exerciseType == 'recite_verse' ? null : true,
        };
      }
      if (openTerm) {
        final id = session.terms.keys.first;
        await d.services<ApiClient>().postNoContent('/glossary/$id/opened');
      }
      return session;
    }

    test('0.1 updates locked 0.2, stats, activity, terms; concurrent finish and malformed replay commit once', () async {
      final repo = d.services<JourneyRepository>();
      await repo.loadJourney();
      expect(repo.cachedJourney!.lesson('les_u0_l2')!.state, LessonState.locked);
      final session = await completed('les_u0_l1', openTerm: true), id = session.sessionId;
      final events = <AppEvent>[];
      final sub = d.services<AppEventBus>().on<AppEvent>().listen(events.add);
      final results = await Future.wait([for (var i = 0; i < 3; i++) d.services<FinishSession>()(id, const Duration(minutes: 12))]);
      await Future<void>.delayed(Duration.zero);
      final result = (results.first as Ok<SessionResult>).value;
      expect(results.every((r) => (r as Ok<SessionResult>).value == result), true);
      expect(result.xp, 15);
      expect(result.streakCurrent, 4);
      expect(result.streakExtended, true);
      expect(result.nextStep!.dueReviewsCount, 1);
      expect(result.unlocked.map((u) => u.id), contains('les_u0_l2'));
      expect(result.termsMastered, isNotEmpty);
      expect(events.whereType<SessionCompleted>().length, 1);
      expect(events.whereType<TermsMastered>().length, 1);
      expect(events.whereType<XpChanged>().length, 1);
      final fresh = (await repo.loadJourney(refresh: true) as Ok<Journey>).value;
      expect(fresh.lesson('les_u0_l1')!.state, LessonState.completed);
      expect(fresh.lesson('les_u0_l2')!.state, LessonState.available);
      final stats = (await repo.loadStats() as Ok<Stats>).value;
      expect(stats.xpTotal, 355);
      expect(stats.streak.current, 4);
      expect(stats.dailyGoal.minutesToday, 12);
      expect(stats.lessonsCompleted, 8);
      final replay = await d.services<ApiClient>().post('/sessions/$id/finish', body: {'malformed': true}, decode: (j) => j);
      expect(replay, backend.db.results[id]);
      expect((await repo.loadStats() as Ok<Stats>).value, stats);
      expect((await d.services<GetActivity>()() as Ok<Activity>).value.days.last.minutes, 12);
      await sub.cancel();
    });
    test('Discover 1.1 completion counts everywhere; second daily finish has no streak or goal bonus', () async {
      final a = await completed('les_u0_l1');
      final first = (await d.services<FinishSession>()(a.sessionId, const Duration(minutes: 12)) as Ok<SessionResult>).value;
      final b = await completed('les_u1_l1');
      final second = (await d.services<FinishSession>()(b.sessionId, const Duration(minutes: 25)) as Ok<SessionResult>).value;
      expect(first.streakExtended, true);
      expect(second.streakExtended, false);
      expect(second.streakCurrent, 4);
      expect(second.xp, 13);
      expect(second.duration.inMilliseconds, inInclusiveRange(1200000, 1202000));
      expect(second.dailyGoal!.minutesToday, 32);
      final journey = (await d.services<JourneyRepository>().loadJourney(refresh: true) as Ok<Journey>).value;
      expect(journey.lesson('les_u1_l1')!.state, LessonState.completed);
      expect(journey.lesson('les_u0_l2')!.state, LessonState.available);
    });
    test('stored finish survives process restart; result BLoC recovers by idempotent re-finish', () async {
      final s = await completed('les_u0_l1');
      final expected = (await d.services<FinishSession>()(s.sessionId, const Duration(minutes: 12)) as Ok<SessionResult>).value;
      await d.dispose();
      d = await create();
      backend = d.services<MockBackend>();
      backend.controls.fast = true;
      final bloc = d.resultBloc()..add(SessionResultOpened(s.sessionId));
      await bloc.stream.firstWhere((s) => s.status == SessionResultStatus.ready);
      expect(bloc.state.result, expected);
      expect(bloc.state.session!.completion, isNotNull);
      final stats = (await d.services<JourneyRepository>().loadStats() as Ok<Stats>).value;
      expect(stats.xpTotal, 355);
      await bloc.close();
    });
    test('failed fetch retries without changing finish awards; unknown session is a failure', () async {
      final s = await completed('les_u0_l1');
      backend.controls.offline = true;
      final bloc = d.resultBloc()..add(SessionResultOpened(s.sessionId));
      await bloc.stream.firstWhere((s) => s.status == SessionResultStatus.failure);
      backend.controls.offline = false;
      bloc.add(const SessionResultRetried());
      await bloc.stream.firstWhere((s) => s.status == SessionResultStatus.ready);
      expect(backend.db.results.length, 1);
      bloc.add(const SessionResultOpened('does-not-exist'));
      await bloc.stream.firstWhere((s) => s.status == SessionResultStatus.failure);
      await bloc.close();
    });
  });
}
