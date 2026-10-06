import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:qabas/core/characters/character_settings_cubit.dart';
import 'package:qabas/core/events/app_event_bus.dart';
import 'package:qabas/core/l10n/locale_cubit.dart';
import 'package:qabas/core/network/api_client.dart';
import 'package:qabas/core/storage/preferences_store.dart';
import 'package:qabas/core/storage/token_store.dart';
import 'package:qabas/features/profile/data/profile_extras_repository_impl.dart';
import 'package:qabas/features/profile/data/profile_repository_impl.dart';
import 'package:qabas/features/profile/domain/profile_extras.dart';
import 'package:qabas/features/profile/domain/profile_repository.dart';
import 'package:qabas/features/profile/presentation/bloc/preferences_cubit.dart';
import 'package:qabas/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:qabas/features/profile/presentation/bloc/profile_extras_bloc.dart';
import 'package:qabas/features/profile/presentation/bloc/settings_bloc.dart';

void registerProfileFeature(GetIt sl, {required bool Function() curiosityEnabled, AssetBundle? bundle}) {
  sl.registerFactory<ProfileExtrasActions>(
    () => ProfileExtrasActions(
      ProfileExtrasRepositoryImpl(
        sl<ApiClient>(),
        sl<TokenStore>(),
        sl<PreferencesStore>(),
        sl<AppEventBus>(),
        resetPreferences: () async {
          await sl<PreferencesCubit>().localPreferencesCleared();
          await sl<LocaleCubit>().languageChanged('en');
          await sl<CharacterSettingsCubit>().settingsChanged(enabled: true, overrides: {});
        },
      ),
    ),
  );
  sl.registerFactory<AchievementsBloc>(() => AchievementsBloc(sl()));
  sl.registerFactory<AccountDeletionBloc>(() => AccountDeletionBloc(sl()));
  sl.registerSingleton<ProfileRepository>(
    ProfileRepositoryImpl(sl<ApiClient>(), sl<AppEventBus>(), bundle: bundle),
    dispose: (r) => (r as ProfileRepositoryImpl).dispose(),
  );
  sl.registerSingleton<ProfileActions>(ProfileActions(sl<ProfileRepository>()));
  sl.registerFactory<ProfileBloc>(() => ProfileBloc(sl<ProfileActions>(), sl<AppEventBus>()));
  sl.registerFactory<SettingsBloc>(
    () => SettingsBloc(
      sl<ProfileActions>(),
      language: () => sl<LocaleCubit>().state.language,
      changeLanguage: sl<LocaleCubit>().languageChanged,
      curiosityEnabled: curiosityEnabled,
      events: sl<AppEventBus>(),
      changePreferences: (edit) async {
        final preferences = sl<PreferencesCubit>();
        await preferences.preferencesChanged(edit.apply(preferences.state.value));
        return preferences.state.status != PreferencesStatus.failure;
      },
    ),
  );
}
