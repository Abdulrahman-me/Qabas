import 'package:get_it/get_it.dart';
import 'package:qabas/core/events/app_event_bus.dart';
import 'package:qabas/core/network/api_client.dart';
import 'package:qabas/features/raqeeb/data/raqeeb_media_repository_impl.dart';
import 'package:qabas/features/raqeeb/data/raqeeb_remote_data_source.dart';
import 'package:qabas/features/raqeeb/data/raqeeb_repository_impl.dart';
import 'package:qabas/features/raqeeb/domain/raqeeb_actions.dart';
import 'package:qabas/features/raqeeb/domain/raqeeb_media.dart';
import 'package:qabas/features/raqeeb/domain/raqeeb_repository.dart';
import 'package:qabas/features/raqeeb/presentation/bloc/raqeeb_chat_bloc.dart';
import 'package:qabas/features/raqeeb/presentation/bloc/raqeeb_history_bloc.dart';
import 'package:qabas/shared/domain/repositories/media_capture.dart';

void registerRaqeebFeature(GetIt sl) {
  sl.registerSingleton<RaqeebMediaActions>(RaqeebMediaActions(RaqeebMediaRepositoryImpl(sl<ApiClient>())));
  sl.registerFactory<RaqeebHistoryBloc>(() => RaqeebHistoryBloc(sl()));
  sl.registerLazySingleton(() => RaqeebRemoteDataSource(sl()));
  sl.registerLazySingleton<RaqeebRepository>(() => RaqeebRepositoryImpl(sl()));
  sl.registerFactory(() => StartConversation(sl()));
  sl.registerFactory(() => OpenConversation(sl()));
  sl.registerFactory(() => SendRaqeebMessage(sl()));
  sl.registerFactory(() => WatchAssistantMessage(sl()));
  sl.registerFactory(() => RateAnswer(sl()));
  sl.registerFactory(
    () => RaqeebChatBloc(
      start: sl(),
      open: sl(),
      send: sl(),
      watch: sl(),
      rate: sl(),
      events: sl<AppEventBus>(),
      capture: sl<MediaCapture>(),
      media: sl<RaqeebMediaActions>(),
    ),
  );
}
