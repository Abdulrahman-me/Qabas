import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/core/events/app_event_bus.dart';
import 'package:qabas/core/events/app_events.dart';
import 'package:qabas/features/discover/presentation/bloc/discover_bloc.dart';
import 'package:qabas/features/journey/presentation/bloc/journey_bloc.dart';
import 'package:qabas/mock_backend/handlers/journey_handlers.dart';
import 'package:qabas/shared/data/dtos/journey_dto.dart';
import 'package:qabas/shared/data/dtos/stats_dto.dart';
import 'package:qabas/shared/data/mappers/journey_mappers.dart';
import 'package:qabas/shared/data/mappers/stats_mappers.dart';
import 'package:qabas/shared/domain/entities/journey.dart';
import 'package:qabas/shared/domain/entities/next_step.dart';
import 'package:qabas/shared/domain/entities/user_profile.dart';
import 'package:qabas/shared/domain/usecases/journey_actions.dart';
import '../../support/journey_fakes.dart';
import '../../support/session_fakes.dart';
import 'journey_data_test.dart' show curriculum, readJson;

void main() {
  late AppEventBus bus;
  late FakeJourney repo;
  late JourneyBloc bloc;
  setUp(() {
    bus = AppEventBus();
    repo = FakeJourney(
      JourneyDto.fromJson(computeJourney(curriculum, 'en', 'explorer')).toEntity(),
      StatsDto.fromJson(readJson('assets/mocks/examples/Stats__get_me_stats__0.json')).toEntity(),
    );
    bloc = repo.bloc(bus);
  });
  tearDown(() async {
    await bloc.close();
    await bus.dispose();
  });
  Future<void> open() async {
    bloc.add(const JourneyOpened());
    await journeyTick();
  }

  test('Download dismissal and selection survive refresh; download is a one-shot action', () async {
    await open();
    bloc.add(const NodePicked('les_u1_l1'));
    await journeyTick();
    final selected = bloc.state.selectedLessonId;
    bloc.add(const AndroidDownloadOpened());
    await journeyTick();
    expect(bloc.state.openAndroidDownload, true);
    final serial = bloc.state.actionSerial;
    bloc.add(const DownloadBannerDismissed());
    await journeyTick();
    expect(bloc.state.openAndroidDownload, false);
    expect(bloc.state.downloadBannerDismissed, true);
    expect(bloc.state.actionSerial, serial);
    bloc.add(const JourneyRefreshed());
    await journeyTick();
    expect(bloc.state.downloadBannerDismissed, true);
    expect(bloc.state.openAndroidDownload, false);
    expect(bloc.state.selectedLessonId, selected);
  });

  test('Failure retries; failed refresh retains prior content and recovers', () async {
    repo.response = () async => const Err(NetworkFailure());
    await open();
    expect(bloc.state.status, JourneyStatus.failure);
    expect(bloc.state.journey, isNull);
    repo.response = null;
    bloc.add(const JourneyRefreshed());
    await journeyTick();
    final prior = bloc.state.journey;
    expect(bloc.state.status, JourneyStatus.ready);
    repo.response = () async => const Err(ServerFailure());
    bloc.add(const JourneyRefreshed());
    await journeyTick();
    expect(bloc.state.journey, same(prior));
    expect(bloc.state.refreshing, false);
    expect(bloc.state.failure, isA<ServerFailure>());
    repo.response = null;
    bloc.add(const JourneyRefreshed());
    await journeyTick();
    expect(bloc.state.failure, isNull);
    expect(repo.refreshes, [false, true, true, true]);
  });
  test('Available later lesson opens; locked selection and 409 share Soft Lock', () async {
    await open();
    bloc.add(const NodePicked('les_u1_l1'));
    await journeyTick();
    expect(bloc.state.selectedLessonId, 'les_u1_l1');
    bloc.add(const LessonOpened('les_u1_l1'));
    await journeyTick();
    expect(bloc.state.lessonToOpen, 'les_u1_l1');
    bloc.add(const NodePicked('les_u0_l2'));
    await journeyTick();
    final lock = bloc.state.softLock!;
    expect(lock.startWith.lessonId, 'les_u0_l1');
    expect(bloc.state.selectedLessonId, isNull);
    repo.lock = lock;
    bloc.add(PrerequisiteFailureReceived(ConflictFailure('prerequisite_unmet')));
    await journeyTick();
    expect(bloc.state.softLock, lock);
    bloc.add(const SoftLockDismissed());
    await journeyTick();
    expect(bloc.state.softLock, isNull);
    bloc.add(const LessonOpened('les_u0_l2'));
    await journeyTick();
    expect(bloc.state.lessonToOpen, isNull);
    expect(bloc.state.softLock, lock);
    bloc.add(LessonOpened(lock.startWith.lessonId));
    await journeyTick();
    expect(bloc.state.lessonToOpen, 'les_u0_l1');
  });
  test('Review card navigation requires a positive due count', () async {
    await open();
    bloc.add(const ReviewOpened());
    await journeyTick();
    expect(bloc.state.openReview, false);
    repo.reviews = 3;
    bloc.add(const JourneyRefreshed());
    await journeyTick();
    bloc.add(const NextStepOpened());
    await journeyTick();
    expect(bloc.state.openReview, true);
  });
  test('Track patch is single in flight, preserves progress; failure retains data', () async {
    await open();
    final pending = Completer<Result<UserProfile>>();
    repo.patch = (_) => pending.future;
    bloc.add(const TrackPicked(UserTrack.newMuslim));
    bloc.add(const TrackPicked(UserTrack.newMuslim));
    await journeyTick();
    expect(repo.patches, 1);
    repo.journey = JourneyDto.fromJson(computeJourney(curriculum, 'en', 'new_muslim', completed: {'les_u0_l1'})).toEntity();
    pending.complete(Ok(learner(track: UserTrack.newMuslim)));
    await journeyTick();
    expect(bloc.state.journey!.track, UserTrack.newMuslim);
    expect(bloc.state.journey!.lesson('les_u0_l1'), isNull);
    repo.patch = (_) async => const Err(NetworkFailure());
    bloc.add(const TrackPicked(UserTrack.explorer));
    await journeyTick();
    expect(bloc.state.journey!.track, UserTrack.newMuslim);
    expect(bloc.state.failure, isA<NetworkFailure>());
  });
  test('Old refresh cannot overwrite newest progress and disposal cancels late emissions', () async {
    await open();
    final old = Completer<Result<Journey>>();
    repo.response = () => old.future;
    bloc.add(const JourneyRefreshed());
    await journeyTick();
    repo.response = null;
    repo.journey = JourneyDto.fromJson(computeJourney(curriculum, 'en', 'explorer', completed: {'les_u0_l1'})).toEntity();
    bus.publish(const LearningProgressChanged());
    await journeyTick();
    expect(bloc.state.journey!.current.lessonId, 'les_u0_l2');
    old.complete(Ok(JourneyDto.fromJson(computeJourney(curriculum, 'en', 'explorer')).toEntity()));
    await journeyTick();
    expect(bloc.state.journey!.current.lessonId, 'les_u0_l2');
    final pending = Completer<Result<Journey>>();
    repo.response = () => pending.future;
    bloc.add(const JourneyRefreshed());
    await journeyTick();
    final closing = bloc.close();
    pending.complete(Ok(repo.journey));
    await closing;
    expect(bloc.isClosed, true);
  });
  test('Discover uses only standalone lessons; marks completed and shares progress refresh', () async {
    final discover = DiscoverBloc(GetJourney(repo), bus);
    discover.add(const DiscoverOpened());
    await journeyTick();
    expect(discover.state.units.single.unitId, 'unit_1');
    discover.add(const LessonPicked('les_u0_l1'));
    await journeyTick();
    expect(discover.state.lessonToOpen, isNull);
    discover.add(const LessonPicked('les_u1_l1'));
    await journeyTick();
    expect(discover.state.lessonToOpen, 'les_u1_l1');
    repo.response = () async => const Err(NetworkFailure());
    discover.add(const DiscoverRefreshed());
    await journeyTick();
    expect(discover.state.journey, isNotNull);
    expect(discover.state.failure, isNotNull);
    repo.response = null;
    repo.journey = JourneyDto.fromJson(computeJourney(curriculum, 'en', 'explorer', completed: {'les_u1_l1'})).toEntity();
    bus.publish(const SessionCompleted(sessionId: 'done', kind: 'lesson', streakExtended: false));
    await journeyTick();
    expect(discover.state.journey!.lesson('les_u1_l1')!.state, LessonState.completed);
    await discover.close();
  });
  test('Today opens returned pretest/unit-test steps without creating a session', () async {
    await open();
    for (final type in [NextStepType.pretest, NextStepType.unitTest]) {
      repo.next = NextStep(
        type: type,
        reason: type == NextStepType.pretest ? NextStepReason.newUnitPretest : NextStepReason.unitReadyForTest,
        unitId: 'unit_1',
        lessonId: null,
        title: 'Server title',
        dueReviewsCount: 0,
      );
      bloc.add(const JourneyRefreshed());
      await journeyTick();
      bloc.add(const NextStepOpened());
      await journeyTick();
      expect(type == NextStepType.pretest ? bloc.state.pretestUnitToOpen : bloc.state.unitToOpen, 'unit_1');
    }
  });
  test('Demo cannot expose a unit test/skip; contract checkpoint can be selected', () async {
    await open();
    bloc.add(const CheckpointPicked('unit_0'));
    bloc.add(const UnitTestOpened('unit_0'));
    await journeyTick();
    expect(bloc.state.selectedUnitId, isNull);
    expect(bloc.state.unitToOpen, isNull);
    final json = computeJourney(curriculum, 'en', 'explorer');
    (((json['units'] as List).first as Map)['unit_test'] as Map)['can_skip'] = true;
    repo.journey = JourneyDto.fromJson(json).toEntity();
    bloc.add(const JourneyRefreshed());
    await journeyTick();
    bloc.add(const CheckpointPicked('unit_0'));
    await journeyTick();
    expect(bloc.state.selectedUnitId, 'unit_0');
    bloc.add(const NodePicked('les_u0_l1'));
    await journeyTick();
    expect(bloc.state.selectedUnitId, isNull);
    bloc.add(const UnitTestOpened('unit_0'));
    await journeyTick();
    expect(bloc.state.unitToOpen, 'unit_0');
  });
}
