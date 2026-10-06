import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qabas/app/config/app_config.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/core/events/app_event_bus.dart';
import 'package:qabas/core/events/app_events.dart';
import 'package:qabas/core/network/api_client.dart';
import 'package:qabas/core/network/backend_transport.dart';
import 'package:qabas/features/profile/data/profile_dto.dart';
import 'package:qabas/features/profile/data/profile_repository_impl.dart';
import 'package:qabas/features/profile/domain/profile.dart';
import 'package:qabas/mock_backend/controls/mock_controls.dart';
import 'package:qabas/mock_backend/fixtures.dart';
import 'package:qabas/mock_backend/mock_backend.dart';
import 'package:qabas/shared/domain/entities/user_profile.dart';

import '../../support/fakes.dart';

class CopyBundle extends CachingAssetBundle {
  CopyBundle(this.copy);
  final Map<String, dynamic> copy;
  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(Uint8List.fromList(utf8.encode(jsonEncode(copy))));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Real HTTP profile reads, changed-field PATCH, events, preview and retained progress', () async {
    final fixtures = Fixtures(read: (p) => File(p).readAsString());
    final mock = MockBackend(fixtures: fixtures, controls: MockControls()..fast = true);
    final tokens = MemoryTokens()..value = 'profile-tests';
    mock.db.tokens.add(tokens.value!);
    mock.db.user = await fixtures.example('User');
    mock.db.completedLessons.add('les_u0_l1');
    final bus = AppEventBus(), observed = <ProfileChanged>[];
    final subscription = bus.on<ProfileChanged>().listen(observed.add);
    final api = ApiClient.create(config: AppConfig(), tokens: tokens, platform: 'web', language: () => 'en', mock: mock);
    final repo = ProfileRepositoryImpl(api, bus);
    final snapshot = (await repo.load() as Ok<ProfileSnapshot>).value;
    expect(snapshot.words, isNotEmpty);
    expect(snapshot.achievements, isNotEmpty);
    expect(() => snapshot.words.clear(), throwsUnsupportedError);
    expect(() => snapshot.achievements.clear(), throwsUnsupportedError);
    for (final edit in [
      const ProfileEdit(language: UserLanguage.en),
      const ProfileEdit(track: UserTrack.newMuslim),
      const ProfileEdit(dailyGoal: 15),
      const ProfileEdit(privateProfile: false),
      const ProfileEdit(goalAnchor: 'why_pray'),
      const ProfileEdit(displayName: 'مسافر جديد'),
    ]) {
      expect(await repo.update(edit), isA<Ok<UserProfile>>());
      expect((mock.lastRequest!.body as Map).length, 1);
    }
    await Future<void>.delayed(Duration.zero);
    expect(observed.length, 6);
    expect(mock.db.completedLessons, contains('les_u0_l1'));
    expect((await repo.load() as Ok<ProfileSnapshot>).value.stats.dailyGoal.minutes, 15);
    expect(await repo.update(const ProfileEdit(displayName: 'x')), isA<Err<UserProfile>>());
    expect((await repo.user() as Ok<UserProfile>).value.displayName, 'مسافر جديد');
    // The active-session term state overrides the authored preview, with no invented strength field.
    final page = await fixtures.example('Page[TermCard]');
    final term = (page['items'] as List).first as Map<String, dynamic>;
    mock.db.sessions['sample'] = {
      'terms': {term['term_id']: term},
    };
    mock.db.termStates[term['term_id'] as String] = 'mastered';
    expect((await repo.load() as Ok<ProfileSnapshot>).value.words.first.state.name, 'mastered');
    await repo.dispose();
    await api.dispose();
    await subscription.cancel();
    await bus.dispose();
  });
  test('DTOs reject missing nullable keys and preserve unknown badge artwork keys and nullable pages', () async {
    final fixtures = Fixtures(read: (p) => File(p).readAsString());
    final json = await fixtures.example('Achievements');
    final item = (json['items'] as List).first as Map<String, dynamic>;
    item['achievement_key'] = 'future_badge';
    expect(AchievementsDto.fromJson(json).items.first.toEntity().key, 'future_badge');
    item.remove('unlocked_at');
    expect(() => AchievementsDto.fromJson(json), throwsA(anything));
    expect(() => WordsPreviewDto.fromJson({'items': []}), throwsA(anything));
    expect(WordsPreviewDto.fromJson({'items': [], 'next_cursor': null}).items, isEmpty);
  });
  test('Curiosity requires all six approved labels; Arabic absent; immutable labels', () async {
    final bus = AppEventBus();
    final api = ApiClient.create(config: AppConfig(), tokens: MemoryTokens(), platform: 'web', language: () => 'en');
    final copy = jsonDecode(File('assets/onboarding/curiosity.json').readAsStringSync()) as Map<String, dynamic>;
    final repo = ProfileRepositoryImpl(api, bus, bundle: CopyBundle(copy));
    final labels = await repo.curiosity('en');
    expect(labels!.labels.length, 6);
    expect(() => labels.labels.clear(), throwsUnsupportedError);
    expect(await repo.curiosity('ar'), isNull);
    final anchor = (copy['anchors'] as List).first as Map<String, dynamic>;
    (anchor['label'] as Map<String, dynamic>)['en'] = null;
    final broken = ProfileRepositoryImpl(api, bus, bundle: CopyBundle(copy));
    expect(await broken.curiosity('en'), isNull);
    await broken.dispose();
    await repo.dispose();
    await api.dispose();
    await bus.dispose();
  });
  test('Account reset discards a late PATCH and never republishes an old profile', () async {
    final fixtures = Fixtures(read: (p) => File(p).readAsString());
    final response = Completer<BackendResponse>();
    final transport = RecordingTransport((_) => response.future);
    final bus = AppEventBus(), observed = <ProfileChanged>[];
    final subscription = bus.on<ProfileChanged>().listen(observed.add);
    final api = ApiClient.create(config: AppConfig(), tokens: MemoryTokens(), platform: 'web', language: () => 'en', mock: transport);
    final repo = ProfileRepositoryImpl(api, bus);
    final pending = repo.update(const ProfileEdit(dailyGoal: 15));
    await Future<void>.delayed(Duration.zero);
    bus.publish(const GuestSessionCleared());
    await Future<void>.delayed(Duration.zero);
    response.complete(BackendResponse(200, await fixtures.example('User')));
    expect((await pending as Err<UserProfile>).failure, isA<UnauthorizedFailure>());
    expect(observed, isEmpty);
    await repo.dispose();
    await api.dispose();
    await subscription.cancel();
    await bus.dispose();
  });
}
