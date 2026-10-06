import 'package:get_it/get_it.dart';
import 'package:qabas/core/l10n/locale_cubit.dart';
import 'package:qabas/core/network/api_client.dart';
import 'package:qabas/core/storage/preferences_store.dart';
import 'package:qabas/features/onboarding/data/datasources/onboarding_remote_data_source.dart';
import 'package:qabas/features/onboarding/data/repositories/onboarding_repository_impl.dart';
import 'package:qabas/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:qabas/features/onboarding/domain/usecases/onboarding_actions.dart';
import 'package:qabas/features/onboarding/presentation/bloc/onboarding_bloc.dart';

void registerOnboarding(GetIt sl, {required bool Function() curiosityEnabled}) {
  sl.registerSingleton<OnboardingRepository>(OnboardingRepositoryImpl(OnboardingRemoteDataSource(sl<ApiClient>()), sl<PreferencesStore>()));
  sl.registerFactory<OnboardingBloc>(() {
    final repository = sl<OnboardingRepository>();
    final store = sl<PreferencesStore>();
    return OnboardingBloc(
      complete: CompleteOnboarding(repository),
      copy: LoadOnboardingCopy(repository),
      savePreferences: SaveOnboardingPreferences(repository),
      curiosityEnabled: curiosityEnabled,
      changeLanguage: sl<LocaleCubit>().languageChanged,
      language: sl<LocaleCubit>().state.language,
      discreetReminders: store.boolean('discreet_reminders', fallback: true),
      reminderHour: int.tryParse(store.string('reminder_hour') ?? '') ?? 19,
    )..add(const OnboardingOpened());
  });
}
