import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qabas/app/config/app_config.dart';
import 'package:qabas/app/di/injector.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/core/network/api_client.dart';
import 'package:qabas/features/session/data/dtos/session_dto.dart';
import 'package:qabas/features/session/domain/entities/session.dart';
import 'package:qabas/features/session/domain/usecases/session_actions.dart';
import 'package:qabas/features/session/presentation/bloc/lesson_intro_bloc.dart';
import 'package:qabas/mock_backend/fixtures.dart';
import 'package:qabas/mock_backend/mock_backend.dart';
import 'package:qabas/shared/domain/entities/journey.dart';
import 'package:qabas/shared/domain/repositories/journey_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fakes.dart';

void main() {
  late AppDependencies d;
  late MockBackend backend;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final token = MemoryTokens()..value = 'session-tests';
    d = await AppDependencies.create(
      config: AppConfig(),
      tokens: token,
      mockFixtures: Fixtures(read: (p) => File(p).readAsString()),
    );
    backend = d.services<MockBackend>();
    backend.controls.fast = true;
    backend.db.tokens.add(token.value!);
    backend.db.user = await backend.fixtures.example('User');
    backend.db.user!['track'] = 'explorer';
    backend.db.user!['language'] = 'en';
  });
  tearDown(() => d.dispose());
  test('start, concurrent replay, pinned language and cached load; exact request body', () async {
    final api = d.services<ApiClient>();
    final statuses = <int>[];
    final request = const SessionCreateDto(lessonId: 'les_u0_l1').toJson();
    final responses = await Future.wait([
      for (var i = 0; i < 3; i++) api.post('/sessions', body: request, decode: SessionDto.fromJson, onStatus: statuses.add),
    ]);
    expect(statuses.where((s) => s == 201).length, 1);
    expect(statuses.where((s) => s == 200).length, 2);
    expect(responses.map((s) => s.sessionId).toSet().length, 1);
    expect(backend.lastRequest!.body, request);
    final first = responses.first;
    await d.locale.languageChanged('ar');
    backend.db.user!['track'] = 'new_muslim';
    final replay = await api.post('/sessions', body: request, decode: SessionDto.fromJson);
    expect(replay.sessionId, first.sessionId);
    expect(replay.title, first.title);
    final saved = await api.get('/sessions/${first.sessionId}', decode: SessionDto.fromJson);
    expect(saved.title, first.title);
  });
  test('prerequisite_unmet becomes the real Soft Lock with cached/localized titles', () async {
    final bloc = d.lessonIntroBloc()..add(const LessonIntroOpened('les_u0_l2'));
    await bloc.stream.firstWhere((s) => s.status == LessonIntroStatus.locked);
    expect(bloc.state.softLock!.startWith.lessonId, 'les_u0_l1');
    expect(bloc.state.softLock!.prerequisites.single.title, isNotEmpty);
    expect(backend.db.sessions, isEmpty);
    await bloc.close();
  });
  test('new session invalidates the journey so its node becomes Continue', () async {
    final journey = d.services<JourneyRepository>();
    await journey.loadJourney();
    expect(journey.cachedJourney!.lesson('les_u0_l1')!.state, LessonState.available);
    expect(await d.services<StartLessonSession>()('les_u0_l1'), isA<Ok<SessionStart>>());
    await Future<void>.delayed(Duration.zero);
    expect(journey.cachedJourney, isNull);
    final updated = (await journey.loadJourney() as Ok<Journey>).value;
    expect(updated.lesson('les_u0_l1')!.state, LessonState.inProgress);
  });
  test('Unit 0 unavailable on New Muslim, 1.1 shared from both tracks, opaque unknown is 404', () async {
    backend.db.user!['track'] = 'new_muslim';
    final start = d.services<StartLessonSession>();
    final missing = await start('les_u0_l1');
    expect((missing as Err<SessionStart>).failure, isA<NotFoundFailure>());
    expect(await start('les_u1_l1'), isA<Ok<SessionStart>>());
    expect(await start('unknown'), isA<Err<SessionStart>>());
  });
  test('demo filters every listed notice ID and retains genuine callouts', () async {
    backend.controls.hideDraftNotices = true;
    final index = await backend.fixtures.object('unit0/SESSION_INDEX.json');
    final rows = (index['sessions'] as List).cast<Map>().where((r) => r['variant'] == 'en_explorer');
    final notices = (await backend.fixtures.object('unit0/DRAFT_NOTICES.json'))['block_ids_by_lesson'] as Map;
    backend.db.completedLessons.addAll(rows.map((r) => r['lesson_id'] as String));
    final api = d.services<ApiClient>();
    for (final row in rows) {
      final id = row['lesson_id'] as String;
      final response = await api.post(
        '/sessions',
        body: SessionCreateDto(lessonId: id).toJson(),
        decode: (j) => j,
      );
      final blocks = (response['items'] as List).cast<Map>();
      final authored = await backend.fixtures.object('unit0/${row['path']}');
      expect(blocks.map((b) => b['block_id']).toSet().intersection((notices[id] as List).cast<String>().toSet()), isEmpty);
      expect(blocks.length, (authored['items'] as List).length - (notices[id] as List).length);
    }
    expect(
      backend.db.sessions.values
          .where((s) => ['les_u0_l10', 'les_u0_l11'].contains(s['lesson_id']))
          .every((s) => (s['items'] as List).cast<Map>().any((b) => b['type'] == 'callout')),
      true,
    );
  });
  test('mock preserves notice and intro recognizes 200 as Continue', () async {
    final start = d.services<StartLessonSession>();
    final first = (await start('les_u0_l1') as Ok<SessionStart>).value;
    expect(first.resumed, false);
    expect(first.session.items.whereType<CalloutItem>(), isNotEmpty);
    expect(first.session.sourceCount, 0);
    expect(first.info.minutes, isNotNull);
    final second = (await start('les_u0_l1') as Ok<SessionStart>).value;
    expect(second.resumed, true);
    expect(second.session.sessionId, first.session.sessionId);
  });
}
