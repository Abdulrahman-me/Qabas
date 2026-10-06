import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:qabas/app/config/app_config.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/core/events/app_event_bus.dart';
import 'package:qabas/core/events/app_events.dart';
import 'package:qabas/core/network/api_client.dart';
import 'package:qabas/core/network/backend_transport.dart';
import 'package:qabas/core/storage/preferences_store.dart';
import 'package:qabas/features/dev_tools/data/repositories/dev_tools_repository_impl.dart';
import 'package:qabas/features/dev_tools/domain/repositories/dev_tools_repository.dart';
import 'package:qabas/mock_backend/handlers/journey_handlers.dart';
import 'package:qabas/shared/data/datasources/journey_remote_data_source.dart';
import 'package:qabas/shared/data/dtos/journey_dto.dart';
import 'package:qabas/shared/data/dtos/stats_dto.dart';
import 'package:qabas/shared/data/mappers/journey_mappers.dart';
import 'package:qabas/shared/data/mappers/stats_mappers.dart';
import 'package:qabas/shared/data/repositories/journey_repository_impl.dart';
import 'package:qabas/shared/domain/entities/journey.dart';
import 'package:qabas/shared/domain/entities/next_step.dart';
import 'package:qabas/shared/domain/entities/stats.dart';
import 'package:qabas/shared/domain/entities/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fakes.dart';
import '../onboarding/onboarding_data_test.dart' show makeBackend, makeApi;

Map<String, dynamic> readJson(String path) => jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
final curriculum = readJson('assets/mocks/demo_curriculum/curriculum.json');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Dart matches full Python reference outputs for 76 progress/locale/track combinations', () async {
    final cases = <Map<String, Object>>[];
    for (final locale in ['en', 'ar']) {
      for (final track in ['explorer', 'new_muslim']) {
        for (var n = 0; n <= 13; n++) {
          cases.add({
            'locale': locale,
            'track': track,
            'completed': [for (var i = 1; i <= n && i <= 12; i++) 'les_u0_l$i', if (n == 13) 'les_u1_l1'],
            'progress': <String>[],
          });
        }
        for (final done in [
          <String>[],
          ['les_u1_l1'],
          ['les_u0_l3'],
          ['les_u0_l1', 'les_u0_l4'],
          ['les_u0_l1', 'les_u0_l2', 'les_u1_l1'],
        ]) {
          cases.add({
            'locale': locale,
            'track': track,
            'completed': done,
            'progress': ['les_u0_l1', 'les_u1_l1'],
          });
        }
      }
    }
    final result = await Process.run('python3', [
      '-c',
      '''
import json,sys
from tool.build_demo_curriculum import compute_journey
cur=json.load(open('assets/mocks/demo_curriculum/curriculum.json'))
out=[]
for c in json.loads(sys.argv[1]):
 j=compute_journey(cur,c['locale'],c['track'],set(c['completed']),set(c['progress']))
 if j['current'] is None: j['current']={'unit_id':None,'lesson_id':None}
 out.append(j)
print(json.dumps(out,ensure_ascii=False))
''',
      jsonEncode(cases),
    ]);
    expect(result.exitCode, 0, reason: result.stderr.toString());
    final reference = jsonDecode(result.stdout as String) as List;
    expect(cases.length, 76);
    for (var i = 0; i < cases.length; i++) {
      final c = cases[i];
      expect(
        computeJourney(
          curriculum,
          c['locale']! as String,
          c['track']! as String,
          completed: (c['completed']! as List<String>).toSet(),
          inProgress: (c['progress']! as List<String>).toSet(),
        ),
        reference[i],
        reason: 'case $i: $c',
      );
    }
  });
  for (final locale in ['en', 'ar']) {
    for (final track in ['explorer', 'new_muslim']) {
      test('Demo journey mapper: $locale / $track', () {
        final json = readJson('assets/mocks/demo_curriculum/journey_initial_${locale}_$track.json');
        expect(computeJourney(curriculum, locale, track), json);
        final entity = JourneyDto.fromJson(json).toEntity();
        expect(entity.current.lessonId, track == 'explorer' ? 'les_u0_l1' : 'les_u1_l1');
        expect(entity.units.length, track == 'explorer' ? 11 : 10);
        expect(entity.lesson('les_u1_l1')!.state, LessonState.available);
        expect(entity.lesson('les_u1_l1')!.standaloneEligible, true);
        expect(entity.units.where((u) => u.index >= 2).every((u) => u.comingSoon && u.lessons.isEmpty), true);
        expect(entity.units.every((u) => !u.unitTest.canSkip), true);
        expect(() => entity.units.clear(), throwsUnsupportedError);
        if (track == 'explorer') {
          expect(entity.lesson('les_u0_l2')!.softLock!.startWith.lessonId, 'les_u0_l1');
          expect(entity.units.first.lessons.skip(1).every((l) => l.state == LessonState.locked), true);
          expect(() => entity.units.first.lessons.clear(), throwsUnsupportedError);
        }
        if (locale == 'ar') expect(entity.units.firstWhere((u) => u.index == 3).title, 'Prayer: Your Daily Connection');
      });
    }
  }
  test('Unknown wire enums retain safe domain unknown; nullable keys are required', () {
    final json = computeJourney(curriculum, 'en', 'explorer');
    json['track'] = 'future_track';
    final unit = (json['units'] as List).first as Map<String, dynamic>;
    unit['state'] = 'future';
    final lesson = (unit['lessons'] as List).first as Map<String, dynamic>;
    lesson['state'] = 'future';
    lesson['lesson_type'] = 'future';
    final entity = JourneyDto.fromJson(json).toEntity();
    expect(entity.track, UserTrack.unknown);
    expect(entity.units.first.state, UnitState.unknown);
    expect(entity.units.first.lessons.first.state, LessonState.unknown);
    expect(entity.units.first.lessons.first.lessonType, LessonType.unknown);
    lesson.remove('soft_lock');
    expect(() => JourneyDto.fromJson(json), throwsA(isA<CheckedFromJsonException>()));
  });
  test('Stats maps the full nested wire shape and nullable league', () {
    final index = jsonDecode(File('assets/mocks/examples/INDEX.json').readAsStringSync()) as List;
    final row = index.cast<Map>().firstWhere((r) => r['model'] == 'Stats');
    final json = readJson('assets/mocks/examples/${row['file']}');
    final stats = StatsDto.fromJson(json).toEntity();
    expect(stats.xpTotal, json['xp_total']);
    expect(stats.dailyGoal.minutesToday, (json['daily_goal'] as Map)['minutes_today']);
    expect(stats.concepts.mastered, (json['concepts'] as Map)['mastered']);
    expect(stats.terms.seen, (json['terms'] as Map)['seen']);
    expect(stats.misconceptions.active, (json['misconceptions'] as Map)['active']);
    expect(stats.lessonsCompleted, json['lessons_completed']);
    expect(stats.unitsCompleted, json['units_completed']);
    json['league'] = null;
    expect(StatsDto.fromJson(json).toEntity().league, isNull);
  });
  test('Real mock HTTP: shared cache, track-only PATCH, goals, developer progression and retained restart', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await PreferencesStore.open();
    final backend = makeBackend(store);
    final tokens = MemoryTokens()..value = 'journey-test';
    backend.db.tokens.add(tokens.value!);
    backend.db.user = await backend.fixtures.example('User');
    backend.db.user!['track'] = 'explorer';
    backend.db.user!['daily_goal_minutes'] = 20;
    final api = makeApi(tokens, backend);
    final bus = AppEventBus();
    var locale = 'en';
    final repository = JourneyRepositoryImpl(JourneyRemoteDataSource(api), bus, () => locale);
    final first = (await repository.loadJourney() as Ok<Journey>).value;
    expect(first.current.lessonId, 'les_u0_l1');
    backend.controls.offline = true;
    expect((await repository.loadJourney() as Ok<Journey>).value, same(first));
    expect(await repository.loadJourney(refresh: true), isA<Err<Journey>>());
    expect(repository.cachedJourney, same(first));
    backend.controls.offline = false;
    final stats = (await repository.loadStats() as Ok<Stats>).value;
    expect(stats.dailyGoal.minutes, 20);
    final dev = DevToolsRepositoryImpl(config: AppConfig(), api: api, tokens: tokens, preferences: store, events: bus, mock: backend);
    await dev.change(DevOption.completedLesson, 'les_u0_l1');
    await Future<void>.delayed(Duration.zero);
    expect(repository.cachedJourney, isNull);
    final progressed = (await repository.loadJourney() as Ok<Journey>).value;
    expect(progressed.lesson('les_u0_l1')!.state, LessonState.completed);
    expect(progressed.lesson('les_u0_l2')!.state, LessonState.available);
    expect((await repository.loadNextStep() as Ok<NextStep>).value.lessonId, 'les_u0_l2');
    await repository.updateTrack(UserTrack.newMuslim);
    expect(backend.lastRequest!.body, {'track': 'new_muslim'});
    expect((await repository.loadJourney() as Ok<Journey>).value.lesson('les_u0_l1'), isNull);
    await repository.updateTrack(UserTrack.explorer);
    expect((await repository.loadJourney() as Ok<Journey>).value.lesson('les_u0_l1')!.state, LessonState.completed);
    locale = 'ar';
    expect(repository.cachedJourney, isNull);
    await repository.loadJourney();
    bus.publish(const SessionCompleted(sessionId: 'done', kind: 'lesson', streakExtended: false));
    await Future<void>.delayed(Duration.zero);
    expect(repository.cachedJourney, isNull);
    backend.db.dueReviews = 3;
    expect((await repository.loadNextStep() as Ok<NextStep>).value.type, NextStepType.review);
    final reopened = makeBackend(store);
    expect(reopened.db.completedLessons, contains('les_u0_l1'));
    expect(reopened.db.user!['track'], 'explorer');
    await repository.dispose();
    await bus.dispose();
    await api.dispose();
    reopened.close();
  });
  test('Older concurrent read and invalidated late result cannot replace cache', () async {
    final requests = <Completer<BackendResponse>>[];
    final transport = RecordingTransport((request) {
      final pending = Completer<BackendResponse>();
      requests.add(pending);
      return pending.future;
    });
    final tokens = MemoryTokens()..value = 'cache-session';
    var locale = 'en';
    final api = ApiClient.create(config: AppConfig(), tokens: tokens, platform: 'web', language: () => locale, mock: transport);
    final bus = AppEventBus();
    final repo = JourneyRepositoryImpl(JourneyRemoteDataSource(api), bus, () => locale);
    final old = repo.loadJourney(refresh: true);
    while (requests.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    locale = 'ar';
    final recent = repo.loadJourney(refresh: true);
    while (requests.length < 2) {
      await Future<void>.delayed(Duration.zero);
    }
    requests[1].complete(BackendResponse(200, computeJourney(curriculum, 'ar', 'explorer', completed: {'les_u0_l1'})));
    final newest = (await recent as Ok<Journey>).value;
    requests[0].complete(BackendResponse(200, computeJourney(curriculum, 'en', 'explorer')));
    await old;
    expect(repo.cachedJourney, same(newest));
    expect(newest.current.lessonId, 'les_u0_l2');
    final pending = repo.loadJourney(refresh: true);
    while (requests.length < 3) {
      await Future<void>.delayed(Duration.zero);
    }
    bus.publish(const GuestSessionCleared());
    await Future<void>.delayed(Duration.zero);
    requests[2].complete(BackendResponse(200, computeJourney(curriculum, 'ar', 'explorer')));
    await pending;
    expect(repo.cachedJourney, isNull);
    await repo.dispose();
    await bus.dispose();
    await api.dispose();
  });
  test('409 prerequisite resolver uses cached titles and rejects invalid or locked start refs', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await PreferencesStore.open();
    final backend = makeBackend(store);
    final tokens = MemoryTokens()..value = 'resolver';
    backend.db.tokens.add(tokens.value!);
    backend.db.user = await backend.fixtures.example('User');
    backend.db.user!['track'] = 'explorer';
    final api = makeApi(tokens, backend);
    final bus = AppEventBus();
    final repo = JourneyRepositoryImpl(JourneyRemoteDataSource(api), bus, () => 'en');
    ConflictFailure failure(String start, [List<Object> ids = const ['les_u0_l2']]) =>
        ConflictFailure('prerequisite_unmet', details: {'prerequisite_lesson_ids': ids, 'start_with_lesson_id': start});
    expect(repo.prerequisiteLock(failure('les_u0_l1')), isNull);
    final journey = (await repo.loadJourney() as Ok<Journey>).value;
    final lock = repo.prerequisiteLock(failure('les_u0_l1'))!;
    expect(lock.prerequisites.single.title, journey.lesson('les_u0_l2')!.title);
    expect(lock.startWith.title, journey.lesson('les_u0_l1')!.title);
    expect(repo.prerequisiteLock(failure('les_u0_l2')), isNull);
    expect(repo.prerequisiteLock(failure('les_u0_l1', ['missing'])), isNull);
    expect(repo.prerequisiteLock(failure('les_u0_l1', [4])), isNull);
    expect(repo.prerequisiteLock(ConflictFailure('other')), isNull);
    await repo.dispose();
    await bus.dispose();
    await api.dispose();
  });
}
