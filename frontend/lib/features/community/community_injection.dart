import 'package:get_it/get_it.dart';
import 'package:qabas/core/events/app_event_bus.dart';
import 'package:qabas/core/network/api_client.dart';
import 'package:qabas/features/community/data/community_repository_impl.dart';
import 'package:qabas/features/community/domain/community.dart';
import 'package:qabas/features/community/presentation/community_bloc.dart';

void registerCommunityFeature(GetIt sl) {
  sl.registerSingleton<CommunityRepository>(CommunityRepositoryImpl(sl<ApiClient>()));
  sl.registerSingleton<CommunityActions>(CommunityActions(sl()));
  sl.registerFactory<CommunityBloc>(() => CommunityBloc(sl(), sl<AppEventBus>()));
  sl.registerFactory<FriendsBloc>(() => FriendsBloc(sl(), sl<AppEventBus>()));
}
