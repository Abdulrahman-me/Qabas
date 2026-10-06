import 'package:get_it/get_it.dart';
import 'package:qabas/app/config/app_config.dart';
import 'package:qabas/core/events/app_event_bus.dart';
import 'package:qabas/core/network/api_client.dart';
import 'package:qabas/core/network/media_resolver.dart';
import 'package:qabas/core/storage/preferences_store.dart';
import 'package:qabas/features/session/data/datasources/session_remote_data_source.dart';
import 'package:qabas/features/session/data/repositories/session_repository_impl.dart';
import 'package:qabas/features/session/data/session_local_store.dart';
import 'package:qabas/features/session/domain/logic/session_recovery.dart';
import 'package:qabas/features/session/domain/repositories/exercise_repository.dart';
import 'package:qabas/features/session/domain/repositories/session_repository.dart';
import 'package:qabas/features/session/domain/usecases/session_actions.dart';
import 'package:qabas/features/session/presentation/bloc/lesson_intro_bloc.dart';
import 'package:qabas/features/session/presentation/bloc/lesson_reader_bloc.dart';
import 'package:qabas/features/session/presentation/bloc/session_player_bloc.dart';
import 'package:qabas/features/session/presentation/bloc/session_result_bloc.dart';
import 'package:qabas/features/session/presentation/bloc/session_start_bloc.dart';
import 'package:qabas/shared/data/repositories/content_repository_impl.dart';
import 'package:qabas/shared/data/repositories/term_state_store_impl.dart';
import 'package:qabas/shared/domain/repositories/journey_repository.dart';
import 'package:qabas/shared/domain/term_state_store.dart';
import 'package:qabas/shared/domain/usecases/journey_actions.dart';
import 'package:qabas/shared/presentation/content/content_bloc.dart';

void registerSessionsFeature(GetIt sl) {
  sl.registerSingleton<MediaResolver>(MediaResolver(sl<AppConfig>()));
  sl.registerSingleton<TermStateStore>(TermStateStoreImpl(sl<AppEventBus>()), dispose: (store) => (store as TermStateStoreImpl).dispose());
  sl.registerSingleton<SessionRepository>(
    SessionRepositoryImpl(SessionRemoteDataSource(sl<ApiClient>()), sl<JourneyRepository>(), sl<TermStateStore>(), sl<AppEventBus>()),
    dispose: (repo) => (repo as SessionRepositoryImpl).dispose(),
  );
  sl.registerSingleton<SessionCheckpointStore>(
    SessionLocalStore(sl<PreferencesStore>(), sl<AppEventBus>()),
    dispose: (store) => (store as SessionLocalStore).dispose(),
  );
  sl.registerSingleton<LessonReaderRepository>(sl<SessionRepository>() as LessonReaderRepository);
  sl.registerFactory<LessonReaderBloc>(() => LessonReaderBloc(sl<LessonReaderRepository>()));
  sl.registerSingleton<SessionFlowRepository>(sl<SessionRepository>() as SessionFlowRepository);
  sl.registerSingleton<StartSessionFlow>(StartSessionFlow(sl<SessionFlowRepository>()));
  sl.registerSingleton<AbandonSession>(AbandonSession(sl<SessionFlowRepository>()));
  sl.registerFactory<SessionStartBloc>(() => SessionStartBloc(sl<StartSessionFlow>()));
  sl.registerSingleton<StartLessonSession>(StartLessonSession(sl<SessionRepository>()));
  sl.registerSingleton<ExerciseRepository>(sl<SessionRepository>() as ExerciseRepository);
  sl.registerSingleton<SubmitAnswer>(SubmitAnswer(sl<ExerciseRepository>()));
  sl.registerSingleton<FinishSession>(FinishSession(sl<ExerciseRepository>()));
  sl.registerSingleton<LoadSession>(LoadSession(sl<SessionRepository>()));
  sl.registerFactory<LessonIntroBloc>(
    () => LessonIntroBloc(sl<StartLessonSession>(), sl<GetJourney>(), sl<JourneyRepository>().prerequisiteLock),
  );
  sl.registerFactory<SessionPlayerBloc>(
    () => SessionPlayerBloc(
      sl<LoadSession>(),
      submitAnswer: sl<SubmitAnswer>(),
      finishSession: sl<FinishSession>(),
      checkpoints: sl<SessionCheckpointStore>(),
      abandonSession: sl<AbandonSession>(),
    ),
  );
  sl.registerFactory<SessionResultBloc>(() => SessionResultBloc(sl<LoadSession>(), sl<FinishSession>()));
  sl.registerFactory<ContentBloc>(() => ContentBloc(sl<TermStateStore>(), ContentRepositoryImpl(sl<ApiClient>(), sl<MediaResolver>())));
}
