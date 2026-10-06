import 'dart:async';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/core/events/app_event_bus.dart';
import 'package:qabas/features/journey/presentation/bloc/journey_bloc.dart';
import 'package:qabas/shared/domain/entities/journey.dart';
import 'package:qabas/shared/domain/entities/next_step.dart';
import 'package:qabas/shared/domain/entities/stats.dart';
import 'package:qabas/shared/domain/entities/user_profile.dart';
import 'package:qabas/shared/domain/repositories/journey_repository.dart';
import 'package:qabas/shared/domain/usecases/journey_actions.dart';
import 'session_fakes.dart';

class FakeJourney implements JourneyRepository {
  FakeJourney(this.journey, this.stats);
  Journey journey;
  Stats stats;
  int reads = 0, patches = 0;
  final refreshes = <bool>[];
  Future<Result<Journey>> Function()? response;
  Future<Result<UserProfile>> Function(UserTrack)? patch;
  SoftLock? lock;
  int reviews = 0;
  NextStep? next;
  @override
  Journey get cachedJourney => journey;
  @override
  SoftLock? prerequisiteLock(ConflictFailure failure) => failure.code == 'prerequisite_unmet' ? lock : null;
  @override
  Future<Result<Journey>> loadJourney({bool refresh = false}) async {
    reads++;
    refreshes.add(refresh);
    return response == null ? Ok(journey) : response!();
  }

  @override
  Future<Result<NextStep>> loadNextStep() async => Ok(
    next ??
        NextStep(
          type: reviews > 0 ? NextStepType.review : NextStepType.lesson,
          reason: reviews > 0 ? NextStepReason.dueReviews : NextStepReason.nextLesson,
          unitId: journey.current.unitId,
          lessonId: reviews > 0 ? null : journey.current.lessonId,
          title: null,
          dueReviewsCount: reviews,
        ),
  );
  @override
  Future<Result<Stats>> loadStats() async => Ok(stats);
  @override
  Future<Result<UserProfile>> updateTrack(UserTrack track) async {
    patches++;
    return patch == null ? Ok(learner(track: track)) : patch!(track);
  }

  JourneyBloc bloc(AppEventBus bus) => JourneyBloc(
    getJourney: GetJourney(this),
    getNextStep: GetNextStep(this),
    getStats: GetStats(this),
    updateProfile: UpdateProfile(this),
    resolveLock: prerequisiteLock,
    events: bus,
  );
}

Future<void> journeyTick() => Future<void>.delayed(const Duration(milliseconds: 10));
