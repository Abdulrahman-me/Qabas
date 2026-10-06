import 'package:get_it/get_it.dart';
import 'package:qabas/core/events/app_event_bus.dart';
import 'package:qabas/features/discover/presentation/bloc/discover_bloc.dart';
import 'package:qabas/shared/domain/usecases/journey_actions.dart';

void registerDiscover(GetIt sl) => sl.registerFactory<DiscoverBloc>(() => DiscoverBloc(sl<GetJourney>(), sl<AppEventBus>()));
