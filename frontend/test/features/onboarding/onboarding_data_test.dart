import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:qabas/app/config/app_config.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/core/network/api_client.dart';
import 'package:qabas/core/network/api_exception.dart';
import 'package:qabas/core/network/auth_events.dart';
import 'package:qabas/core/storage/preferences_store.dart';
import 'package:qabas/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:qabas/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:qabas/features/onboarding/data/datasources/onboarding_remote_data_source.dart';
import 'package:qabas/features/onboarding/data/dtos/onboarding_dto.dart';
import 'package:qabas/features/onboarding/data/repositories/onboarding_repository_impl.dart';
import 'package:qabas/features/onboarding/domain/entities/onboarding_answers.dart';
import 'package:qabas/mock_backend/controls/mock_controls.dart';
import 'package:qabas/mock_backend/data/mock_state_store.dart';
import 'package:qabas/mock_backend/fixtures.dart';
import 'package:qabas/mock_backend/mock_backend.dart';
import 'package:qabas/shared/data/dtos/user_dto.dart';
import 'package:qabas/shared/domain/entities/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../support/fakes.dart';

class CopyBundle extends CachingAssetBundle {
  final values = <String, String>{};
  @override
  Future<ByteData> load(String key) async {
    final value = values[key];
    if (value == null) throw FlutterError('Missing asset');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(value)));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PreferencesStore store;
  late MemoryTokens tokens;
  late MockBackend backend;
  late ApiClient api;
  late AuthRepositoryImpl auth;
  late OnboardingRepositoryImpl onboarding;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = await PreferencesStore.open();
    tokens = MemoryTokens();
    backend = makeBackend(store);
    api = makeApi(tokens, backend);
    auth = AuthRepositoryImpl(AuthRemoteDataSource(api), tokens, timezone: () async => 'Asia/Muscat');
    onboarding = OnboardingRepositoryImpl(OnboardingRemoteDataSource(api), store);
  });
  tearDown(() => api.dispose());
  for (final choice in TrackChoice.values) {
    test('Guest and onboarding wire contract: ${choice.name}', () async {
      final guest = await auth.createGuest();
      expect(guest, isA<Ok<UserProfile>>());
      expect(tokens.value, isNotNull);
      expect((guest as Ok<UserProfile>).value.timezone, 'Asia/Muscat');
      expect(backend.lastRequest!.header('Authorization'), isNull);
      final result = await onboarding.complete(
        OnboardingAnswers(
          track: choice,
          language: 'en',
          familiarity: Familiarity.none,
          dailyGoal: 5,
          privateProfile: true,
          goalAnchor: null,
        ),
      );
      expect(result, isA<Ok<UserProfile>>());
      final user = (result as Ok<UserProfile>).value;
      expect(user.track, choice == TrackChoice.newMuslim ? UserTrack.newMuslim : UserTrack.explorer);
      expect(user.onboardingCompleted, true);
      expect(user.goalAnchor, isNull);
      expect(
        (backend.lastRequest!.body as Map).keys,
        unorderedEquals(['track_choice', 'language', 'familiarity', 'daily_goal_minutes', 'private_profile', 'goal_anchor']),
      );
      expect((backend.lastRequest!.body as Map).containsKey('goal_anchor'), true);
    });
  }
  test('Curiosity never changes entry; nullable request keys are required', () async {
    await auth.createGuest();
    for (final track in ['undisclosed', 'explorer', 'new_muslim']) {
      final result = await api.post(
        '/onboarding',
        body: OnboardingRequestDto(
          trackChoice: track,
          language: 'ar',
          familiarity: null,
          dailyGoalMinutes: 20,
          privateProfile: true,
          goalAnchor: 'who_was_muhammad',
        ).toJson(),
        decode: OnboardingResponseDto.fromJson,
      );
      expect(result.startUnitId, track == 'new_muslim' ? 'unit_1' : 'unit_0');
      expect(result.user.goalAnchor, 'who_was_muhammad');
      expect(result.nextStep.lessonId, track == 'new_muslim' ? 'les_u1_l1' : 'les_u0_l1');
    }
    final incomplete = const OnboardingRequestDto(
      trackChoice: 'explorer',
      language: 'en',
      familiarity: null,
      dailyGoalMinutes: 10,
      privateProfile: true,
      goalAnchor: null,
    ).toJson()..remove('goal_anchor');
    expect(() => OnboardingRequestDto.fromJson(incomplete), throwsA(isA<CheckedFromJsonException>()));
    await expectLater(api.post('/onboarding', body: incomplete, decode: OnboardingResponseDto.fromJson), throwsA(isA<ApiException>()));
  });
  test('Restart reuses secure token and mock profile; persistence contains no bearer credential', () async {
    await auth.createGuest();
    await onboarding.complete(
      const OnboardingAnswers(
        track: TrackChoice.explorer,
        language: 'en',
        familiarity: Familiarity.some,
        dailyGoal: 15,
        privateProfile: true,
        goalAnchor: null,
      ),
    );
    final token = tokens.value!;
    final saved = store.string('mock_server')!;
    expect(saved.contains(token), false);
    await store.setString('language', 'ar');
    await store.clearLocal();
    expect(store.string('language'), isNull);
    expect(store.string('mock_server'), saved);
    final restoredBackend = makeBackend(store);
    final restoredApi = makeApi(tokens, restoredBackend);
    final restored = AuthRepositoryImpl(AuthRemoteDataSource(restoredApi), tokens);
    expect((await restored.currentUser() as Ok<UserProfile>).value.onboardingCompleted, true);
    expect(tokens.value, token);
    expect(restoredBackend.db.tokens, isEmpty);
    expect(restoredBackend.db.tokenDigests, isNotEmpty);
    restoredBackend.db.tokenDigests.clear();
    await restoredBackend.persist();
    await expectLater(restoredApi.get('/me', decode: UserDto.fromJson), throwsA(isA<ApiException>()));
    expect(tokens.value, isNull);
    await restoredApi.dispose();
  });
  test('Guest 401 produces no expired-session notice and is not automatically retried', () async {
    final notices = <AuthEvent>[];
    final subscription = api.authEvents.listen(notices.add);
    backend.controls.nextStatus = 401;
    expect(await auth.createGuest(), isA<Err<UserProfile>>());
    await Future<void>.delayed(Duration.zero);
    expect(notices, isEmpty);
    expect(backend.controls.nextStatus, isNull);
    await subscription.cancel();
  });
  test('Bundled curiosity requires complete current-language labels and preserves reviewed bridge verbatim', () async {
    final bundle = CopyBundle();
    final encoded = File('assets/onboarding/curiosity.json').readAsStringSync();
    bundle.values['assets/onboarding/curiosity.json'] = encoded;
    final repo = OnboardingRepositoryImpl(OnboardingRemoteDataSource(api), store, bundle: bundle);
    final en = (await repo.curiosity('en'))!;
    expect(en.options.length, 6);
    expect(en.options[3].bridge(TrackChoice.undisclosed), contains('Muhammad ﷺ claimed'));
    expect(en.options[3].bridge(TrackChoice.newMuslim), isNull);
    expect(await repo.curiosity('ar'), isNull);
    final json = jsonDecode(encoded) as Map<String, dynamic>;
    final first = (json['anchors'] as List<dynamic>).first as Map<String, dynamic>;
    (first['label'] as Map<String, dynamic>)['en'] = null;
    bundle.values['assets/onboarding/curiosity.json'] = jsonEncode(json);
    bundle.evict('assets/onboarding/curiosity.json');
    expect(await repo.curiosity('en'), isNull);
    bundle.values.clear();
    bundle.evict('assets/onboarding/curiosity.json');
    expect(await repo.curiosity('en'), isNull);
  });
}

MockBackend makeBackend(PreferencesStore store) => MockBackend(
  fixtures: Fixtures(read: (path) => File(path).readAsString()),
  controls: MockControls()..fast = true,
  stateStore: MockStateStore(store),
);
ApiClient makeApi(MemoryTokens tokens, MockBackend backend) =>
    ApiClient.create(config: AppConfig(), tokens: tokens, platform: 'web', language: () => 'en', mock: backend, retryDelay: (_) async {});
