import 'package:get_it/get_it.dart';
import 'package:qabas/core/events/app_event_bus.dart';
import 'package:qabas/core/l10n/locale_cubit.dart';
import 'package:qabas/core/network/api_client.dart';
import 'package:qabas/features/journey/presentation/bloc/journey_bloc.dart';
import 'package:qabas/shared/data/datasources/journey_remote_data_source.dart';
import 'package:qabas/shared/data/repositories/journey_repository_impl.dart';
import 'package:qabas/shared/domain/repositories/journey_repository.dart';
import 'package:qabas/shared/domain/usecases/journey_actions.dart';

void registerJourneyFeature(GetIt sl) {
  final repository = JourneyRepositoryImpl(
    JourneyRemoteDataSource(sl<ApiClient>()),
    sl<AppEventBus>(),
    () => sl<LocaleCubit>().state.language,
  );
  sl.registerSingleton<JourneyRepository>(repository, dispose: (_) => repository.dispose());
  sl.registerSingleton<GetJourney>(GetJourney(repository));
  sl.registerSingleton<GetNextStep>(GetNextStep(repository));
  sl.registerSingleton<GetStats>(GetStats(repository));
  sl.registerSingleton<UpdateProfile>(UpdateProfile(repository));
  sl.registerFactory<JourneyBloc>(
    () => JourneyBloc(
      getJourney: sl<GetJourney>(),
      getNextStep: sl<GetNextStep>(),
      getStats: sl<GetStats>(),
      updateProfile: sl<UpdateProfile>(),
      resolveLock: repository.prerequisiteLock,
      events: sl<AppEventBus>(),
    ),
  );
}
