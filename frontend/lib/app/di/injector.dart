import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:qabas/app/config/app_config.dart';
import 'package:qabas/core/audio/sensory_service.dart';
import 'package:qabas/core/characters/character_asset_cache.dart';
import 'package:qabas/core/characters/character_registry.dart';
import 'package:qabas/core/characters/character_settings_cubit.dart';
import 'package:qabas/core/characters/character_spec.dart';
import 'package:qabas/core/design_system/tokens/tokens.dart';
import 'package:qabas/core/events/app_event_bus.dart';
import 'package:qabas/core/l10n/locale_cubit.dart';
import 'package:qabas/core/media/plugin_media_capture.dart';
import 'package:qabas/core/network/api_client.dart';
import 'package:qabas/core/network/media_resolver.dart';
import 'package:qabas/core/network/scene_media_loader.dart';
import 'package:qabas/core/network/web_socket_duel_socket.dart';
import 'package:qabas/core/storage/preferences_store.dart';
import 'package:qabas/core/storage/token_store.dart';
import 'package:qabas/features/auth/auth_injection.dart';
import 'package:qabas/features/auth/presentation/bloc/app_session_bloc.dart';
import 'package:qabas/features/challenges/challenges_injection.dart';
import 'package:qabas/features/challenges/presentation/challenge_bloc.dart';
import 'package:qabas/features/challenges/presentation/challenge_lobby_bloc.dart';
import 'package:qabas/features/community/community_injection.dart';
import 'package:qabas/features/community/presentation/community_bloc.dart';
import 'package:qabas/features/dev_tools/data/repositories/dev_tools_repository_impl.dart';
import 'package:qabas/features/dev_tools/domain/repositories/dev_tools_repository.dart';
import 'package:qabas/features/dev_tools/domain/usecases/dev_tools_actions.dart';
import 'package:qabas/features/dev_tools/presentation/bloc/dev_tools_bloc.dart';
import 'package:qabas/features/discover/discover_injection.dart';
import 'package:qabas/features/discover/presentation/bloc/discover_bloc.dart';
import 'package:qabas/features/glossary/data/glossary_repository_impl.dart';
import 'package:qabas/features/glossary/domain/glossary.dart';
import 'package:qabas/features/glossary/presentation/glossary_bloc.dart';
import 'package:qabas/features/journey/journey_injection.dart';
import 'package:qabas/features/journey/presentation/bloc/journey_bloc.dart';
import 'package:qabas/features/onboarding/onboarding_injection.dart';
import 'package:qabas/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:qabas/features/profile/presentation/bloc/preferences_cubit.dart';
import 'package:qabas/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:qabas/features/profile/presentation/bloc/profile_extras_bloc.dart';
import 'package:qabas/features/profile/presentation/bloc/settings_bloc.dart';
import 'package:qabas/features/profile/profile_injection.dart';
import 'package:qabas/features/raqeeb/presentation/bloc/raqeeb_chat_bloc.dart';
import 'package:qabas/features/raqeeb/presentation/bloc/raqeeb_history_bloc.dart';
import 'package:qabas/features/raqeeb/raqeeb_injection.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_auth_bloc.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_dashboard_bloc.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_detail_bloc.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_runs_bloc.dart';
import 'package:qabas/features/reviewer/reviewer_injection.dart';
import 'package:qabas/features/session/data/repositories/recitation_playback_impl.dart';
import 'package:qabas/features/session/data/repositories/recitation_repository_impl.dart';
import 'package:qabas/features/session/domain/entities/exercise.dart';
import 'package:qabas/features/session/presentation/bloc/lesson_intro_bloc.dart';
import 'package:qabas/features/session/presentation/bloc/lesson_reader_bloc.dart';
import 'package:qabas/features/session/presentation/bloc/session_player_bloc.dart';
import 'package:qabas/features/session/presentation/bloc/session_result_bloc.dart';
import 'package:qabas/features/session/presentation/bloc/session_start_bloc.dart';
import 'package:qabas/features/session/presentation/steps/exercise_step_bloc.dart';
import 'package:qabas/features/session/session_injection.dart';
import 'package:qabas/features/streak/presentation/bloc/streak_bloc.dart';
import 'package:qabas/features/streak/streak_injection.dart';
import 'package:qabas/features/unit_guide/data/unit_guide_repository_impl.dart';
import 'package:qabas/features/unit_guide/domain/unit_guide.dart';
import 'package:qabas/features/unit_guide/presentation/unit_guide_bloc.dart';
import 'package:qabas/mock_backend/controls/mock_controls.dart';
import 'package:qabas/mock_backend/data/mock_state_store.dart';
import 'package:qabas/mock_backend/fixtures.dart';
import 'package:qabas/mock_backend/mock_backend.dart';
import 'package:qabas/shared/data/repositories/content_repository_impl.dart';
import 'package:qabas/shared/domain/repositories/journey_repository.dart';
import 'package:qabas/shared/domain/repositories/media_capture.dart';
import 'package:qabas/shared/domain/term_state_store.dart';
import 'package:qabas/shared/presentation/content/content_bloc.dart';
import 'package:qabas_scene/qabas_scene.dart';

/// Composition root. Widgets receive dependencies through providers and scopes.
final class AppDependencies {
  AppDependencies._(this.services);
  final GetIt services;
  AppConfig get config => services<AppConfig>();
  LocaleCubit get locale => services<LocaleCubit>();
  PreferencesCubit get preferences => services<PreferencesCubit>();
  CharacterSettingsCubit get characters => services<CharacterSettingsCubit>();
  CharacterRegistry get registry => services<CharacterRegistry>();
  CharacterAssetCache get cache => services<CharacterAssetCache>();
  AppSessionBloc get session => services<AppSessionBloc>();
  SensoryService get sensory => services<SensoryService>();
  ReviewerAuthBloc reviewerAuthBloc() => services<ReviewerAuthBloc>();
  ReviewerRunsBloc reviewerRunsBloc() => services<ReviewerRunsBloc>();
  ReviewerDetailBloc reviewerDetailBloc() => services<ReviewerDetailBloc>();
  ReviewerBlindBloc reviewerBlindBloc() => services<ReviewerBlindBloc>();
  ReviewerMetricsBloc reviewerMetricsBloc() => services<ReviewerMetricsBloc>();
  DevToolsBloc developerBloc() => services<DevToolsBloc>();
  OnboardingBloc onboardingBloc() => services<OnboardingBloc>();
  JourneyBloc journeyBloc() => services<JourneyBloc>();
  MediaResolver get media => services<MediaResolver>();
  SceneCache get scenes => services<SceneCache>();
  ContentBloc contentBloc() => services<ContentBloc>();
  ContentBloc reviewerContentBloc() =>
      ContentBloc(services<TermStateStore>(), ContentRepositoryImpl(services<ApiClient>(), services<MediaResolver>()), readOnly: true);
  LessonIntroBloc lessonIntroBloc() => services<LessonIntroBloc>();
  ExerciseStepBloc exerciseBloc(Exercise exercise) => ExerciseStepBloc(
    exercise,
    capture: exercise.payload is RecitePayload ? services<MediaCapture>() : null,
    recitation: exercise.payload is RecitePayload
        ? RecitationRepositoryImpl(services<ApiClient>(), enabled: config.flavor != AppFlavor.demo)
        : null,
    playback: exercise.payload is RecitePayload ? RecitationPlaybackImpl((exercise.payload as RecitePayload).audio, media) : null,
  );
  LessonReaderBloc readerBloc() => services<LessonReaderBloc>();
  SessionStartBloc sessionStartBloc() => services<SessionStartBloc>();
  GlossaryBloc glossaryBloc() => services<GlossaryBloc>();
  UnitGuideBloc unitGuideBloc() => services<UnitGuideBloc>();
  SessionPlayerBloc playerBloc() => services<SessionPlayerBloc>();
  SessionResultBloc resultBloc() => services<SessionResultBloc>();
  ProfileBloc profileBloc() => services<ProfileBloc>();
  AchievementsBloc achievementsBloc() => services<AchievementsBloc>();
  AccountDeletionBloc accountDeletionBloc() => services<AccountDeletionBloc>();
  SettingsBloc settingsBloc() => services<SettingsBloc>();
  RaqeebChatBloc raqeebBloc() => services<RaqeebChatBloc>();
  RaqeebHistoryBloc raqeebHistoryBloc() => services<RaqeebHistoryBloc>();
  StreakBloc streakBloc() => services<StreakBloc>();
  CommunityBloc communityBloc() => services<CommunityBloc>();
  FriendsBloc friendsBloc() => services<FriendsBloc>();
  ChallengeBloc challengeBloc() => services<ChallengeBloc>();
  ChallengeLobbyBloc challengeLobbyBloc() => services<ChallengeLobbyBloc>();
  DiscoverBloc discoverBloc() => services<DiscoverBloc>();
  Future<void>? _warmup;
  Future<void> warmUp() => _warmup ??= Future.wait([
    sensory.warmUp(),
    Future.wait(
      registry.specs.values.map((spec) async {
        if (spec.rig case final RiveRigSpec rig) await cache.load(rig);
      }),
    ),
  ]).then<void>((_) {}).timeout(QMotion.splashAssetTimeout, onTimeout: () {});
  Future<void> dispose() => services.reset();

  static Future<AppDependencies> create({
    required AppConfig config,
    TokenStore? tokens,
    TokenStore? suspendedLearnerTokens,
    Fixtures? mockFixtures,
    AssetBundle? profileCopyBundle,
    PreferencesStore? store,
    CharacterAssetCache? cache,
    SceneCache? scenes,
    bool debug = kDebugMode,
    AppSessionState initialSessionState = const AppSessionState(),
  }) async {
    final sl = GetIt.asNewInstance();
    sl.registerSingleton<AppConfig>(config);
    sl.registerFactory<MediaCapture>(() => PluginMediaCapture());
    sl.registerSingleton<TokenStore>(tokens ?? const SecureTokenStore(FlutterSecureStorage()));
    sl.registerSingleton<PreferencesStore>(store ?? await PreferencesStore.open());
    final locale = LocaleCubit(sl<PreferencesStore>());
    final preferences = PreferencesCubit(sl<PreferencesStore>());
    sl.registerSingleton<LocaleCubit>(locale, dispose: (cubit) => cubit.close());
    sl.registerSingleton<PreferencesCubit>(preferences, dispose: (cubit) => cubit.close());
    sl.registerSingleton<CharacterSettingsCubit>(CharacterSettingsCubit(sl<PreferencesStore>()), dispose: (cubit) => cubit.close());
    sl.registerSingleton<CharacterRegistry>(CharacterRegistry.bundled());
    sl.registerSingleton<CharacterAssetCache>(cache ?? CharacterAssetCache(), dispose: (cache) => cache.dispose());
    sl.registerSingleton<AppEventBus>(AppEventBus(), dispose: (bus) => bus.dispose());
    MockBackend? mock;
    if (config.allowsMocks) {
      final controls = MockControls()
        ..raqeebOutcome = config.recordingDemo ? 'auto' : 'A'
        ..recitationUnavailable = config.flavor == AppFlavor.demo
        ..hideDraftNotices = config.hideDraftNotices
        ..curiosityOnboarding = config.curiosityOnboarding;
      mock = MockBackend(
        fixtures: (mockFixtures ?? Fixtures()).forRecording(config.recordingDemo),
        controls: controls,
        stateStore: MockStateStore(sl<PreferencesStore>()),
      );
      sl.registerSingleton<MockBackend>(mock);
    }
    // TODO(contract): A-58 — Qabas-Client accepts only android, ios and web; desktop builds identify as web.
    final platform = !kIsWeb && [TargetPlatform.android, TargetPlatform.iOS].contains(defaultTargetPlatform)
        ? defaultTargetPlatform.name.toLowerCase()
        : 'web';
    final api = ApiClient.create(
      config: config,
      tokens: sl<TokenStore>(),
      mock: mock,
      platform: platform,
      language: () => locale.state.language,
      debug: debug,
    );
    sl.registerSingleton<ApiClient>(api, dispose: (api) => api.dispose());
    registerAuth(sl, initialState: initialSessionState);
    registerReviewerFeature(
      sl,
      suspendedLearner:
          suspendedLearnerTokens ?? const SecureTokenStore(FlutterSecureStorage(), key: SecureTokenStore.suspendedLearnerKey),
    );
    registerOnboarding(sl, curiosityEnabled: () => mock?.controls.curiosityOnboarding ?? config.curiosityOnboarding);
    registerJourneyFeature(sl);
    registerDiscover(sl);
    registerSessionsFeature(sl);
    sl.registerSingleton<GlossaryRepository>(GlossaryRepositoryImpl(api));
    sl.registerFactory<GlossaryBloc>(() => GlossaryBloc(GetGlossary(sl<GlossaryRepository>())));
    sl.registerSingleton<UnitGuideRepository>(UnitGuideRepositoryImpl(api, sl<JourneyRepository>()));
    sl.registerFactory<UnitGuideBloc>(() => UnitGuideBloc(GetUnitGuide(sl<UnitGuideRepository>())));
    registerStreakFeature(sl);
    registerRaqeebFeature(sl);
    registerCommunityFeature(sl);
    registerChallengesFeature(sl, config.isLive(LiveGroup.challenges) ? const WebSocketDuelSocketFactory() : mock!.challengeSockets);
    registerProfileFeature(
      sl,
      bundle: profileCopyBundle,
      curiosityEnabled: () => mock?.controls.curiosityOnboarding ?? config.curiosityOnboarding,
    );
    final sceneMedia = SceneMediaLoader(sl<MediaResolver>());
    sl.registerSingleton<SceneMediaLoader>(sceneMedia, dispose: (loader) => loader.dispose());
    sl.registerSingleton<SceneCache>(scenes ?? SceneCache(loadBytes: sceneMedia.load), dispose: (cache) => cache.clear());
    sl.registerSingleton<SensoryService>(
      SensoryService(
        settings: () => SensorySettings(sound: preferences.state.value.sound, haptics: preferences.state.value.haptics),
      ),
      dispose: (service) => service.dispose(),
    );
    if (config.developerMenuEnabled(debug)) {
      sl.registerSingleton<DevToolsRepository>(
        DevToolsRepositoryImpl(
          config: config,
          api: api,
          tokens: sl<TokenStore>(),
          preferences: sl<PreferencesStore>(),
          events: sl<AppEventBus>(),
          mock: mock,
        ),
      );
      sl.registerSingleton<DevToolsActions>(DevToolsActions(sl<DevToolsRepository>()));
      sl.registerFactory<DevToolsBloc>(() => DevToolsBloc(sl<DevToolsActions>()));
    }
    return AppDependencies._(sl);
  }
}
