import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/shared/domain/entities/journey.dart';
import 'package:qabas/shared/domain/entities/next_step.dart';
import 'package:qabas/shared/domain/entities/stats.dart';
import 'package:qabas/shared/domain/entities/user_profile.dart';

/// Shared by Journey, Discover and later lesson entry surfaces.
abstract interface class JourneyRepository {
  Journey? get cachedJourney;
  SoftLock? prerequisiteLock(ConflictFailure failure);
  Future<Result<Journey>> loadJourney({bool refresh = false});
  Future<Result<NextStep>> loadNextStep();
  Future<Result<Stats>> loadStats();
  Future<Result<UserProfile>> updateTrack(UserTrack track);
}
