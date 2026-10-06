import 'package:get_it/get_it.dart';
import 'package:qabas/app/config/app_config.dart';
import 'package:qabas/core/events/app_event_bus.dart';
import 'package:qabas/core/network/api_client.dart';
import 'package:qabas/core/storage/token_store.dart';
import 'package:qabas/features/reviewer/data/reviewer_repository_impl.dart';
import 'package:qabas/features/reviewer/domain/reviewer_actions.dart';
import 'package:qabas/features/reviewer/domain/reviewer_repository.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_auth_bloc.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_dashboard_bloc.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_detail_bloc.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_runs_bloc.dart';

void registerReviewerFeature(GetIt sl, {TokenStore? suspendedLearner}) {
  sl.registerSingleton<ReviewerRepository>(
    ReviewerRepositoryImpl(
      sl<ApiClient>(),
      sl<TokenStore>(),
      sampleEnabled: sl<AppConfig>().judgesDemo,
      suspendedLearner: sl<AppConfig>().isLive(LiveGroup.reviewer) ? suspendedLearner : null,
    ),
  );
  sl.registerSingleton<ReviewerActions>(ReviewerActions(sl<ReviewerRepository>()));
  sl.registerFactory<ReviewerAuthBloc>(() => ReviewerAuthBloc(sl<ReviewerActions>()));
  sl.registerFactory<ReviewerRunsBloc>(() => ReviewerRunsBloc(sl<ReviewerActions>(), events: sl<AppEventBus>()));
  sl.registerFactory<ReviewerDetailBloc>(() => ReviewerDetailBloc(sl<ReviewerActions>(), events: sl<AppEventBus>()));
  sl.registerFactory<ReviewerBlindBloc>(() => ReviewerBlindBloc(sl<ReviewerActions>(), events: sl<AppEventBus>()));
  sl.registerFactory<ReviewerMetricsBloc>(() => ReviewerMetricsBloc(sl<ReviewerActions>()));
}
