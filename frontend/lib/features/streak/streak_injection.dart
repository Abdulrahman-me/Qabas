import 'package:get_it/get_it.dart';
import 'package:qabas/core/network/api_client.dart';
import 'package:qabas/features/streak/data/activity_repository_impl.dart';
import 'package:qabas/features/streak/domain/activity.dart';
import 'package:qabas/features/streak/presentation/bloc/streak_bloc.dart';

void registerStreakFeature(GetIt sl) {
  sl.registerSingleton<ActivityRepository>(ActivityRepositoryImpl(sl<ApiClient>()));
  sl.registerSingleton<GetActivity>(GetActivity(sl<ActivityRepository>()));
  sl.registerFactory<StreakBloc>(() => StreakBloc(sl<GetActivity>()));
}
