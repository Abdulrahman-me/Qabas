import 'package:get_it/get_it.dart';
import 'package:qabas/core/events/app_event_bus.dart';
import 'package:qabas/core/network/api_client.dart';
import 'package:qabas/core/network/duel_socket.dart';
import 'package:qabas/features/challenges/data/challenge_repository_impl.dart';
import 'package:qabas/features/challenges/domain/challenge.dart';
import 'package:qabas/features/challenges/presentation/challenge_bloc.dart';
import 'package:qabas/features/challenges/presentation/challenge_lobby_bloc.dart';

void registerChallengesFeature(GetIt sl, DuelSocketFactory factory) {
  sl.registerSingleton<ChallengeRepository>(ChallengeRepositoryImpl(sl<ApiClient>(), factory));
  sl.registerSingleton<ChallengeActions>(ChallengeActions(sl()));
  sl.registerFactory<ChallengeBloc>(() => ChallengeBloc(sl(), sl<AppEventBus>()));
  sl.registerFactory<ChallengeLobbyBloc>(() => ChallengeLobbyBloc(sl(), events: sl<AppEventBus>()));
}
