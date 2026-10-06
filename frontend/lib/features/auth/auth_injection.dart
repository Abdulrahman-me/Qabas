import 'package:get_it/get_it.dart';
import 'package:qabas/core/events/app_event_bus.dart';
import 'package:qabas/core/events/app_events.dart';
import 'package:qabas/core/network/api_client.dart';
import 'package:qabas/core/storage/token_store.dart';
import 'package:qabas/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:qabas/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:qabas/features/auth/domain/repositories/auth_repository.dart';
import 'package:qabas/features/auth/domain/usecases/session_actions.dart';
import 'package:qabas/features/auth/presentation/bloc/app_session_bloc.dart';

void registerAuth(GetIt sl, {AppSessionState initialState = const AppSessionState()}) {
  sl.registerSingleton<AuthRepository>(AuthRepositoryImpl(AuthRemoteDataSource(sl<ApiClient>()), sl<TokenStore>()));
  final repository = sl<AuthRepository>();
  sl.registerSingleton<AppSessionBloc>(
    AppSessionBloc(
      sl<ApiClient>().authEvents,
      createGuest: CreateGuestSession(repository),
      loadUser: LoadCurrentUser(repository),
      hasSession: HasStoredSession(repository),
      clearSession: ClearSession(repository),
      profileEvents: sl<AppEventBus>().on<AppEvent>(),
      initialState: initialState,
    ),
    dispose: (bloc) => bloc.close(),
  );
}
