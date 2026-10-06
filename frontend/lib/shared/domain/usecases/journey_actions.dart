import 'package:qabas/core/error/result.dart';
import 'package:qabas/shared/domain/entities/journey.dart';
import 'package:qabas/shared/domain/entities/next_step.dart';
import 'package:qabas/shared/domain/entities/stats.dart';
import 'package:qabas/shared/domain/entities/user_profile.dart';
import 'package:qabas/shared/domain/repositories/journey_repository.dart';

final class GetJourney {
  const GetJourney(this.repository);
  final JourneyRepository repository;
  Future<Result<Journey>> call({bool refresh = false}) => repository.loadJourney(refresh: refresh);
}

final class GetNextStep {
  const GetNextStep(this.repository);
  final JourneyRepository repository;
  Future<Result<NextStep>> call() => repository.loadNextStep();
}

final class GetStats {
  const GetStats(this.repository);
  final JourneyRepository repository;
  Future<Result<Stats>> call() => repository.loadStats();
}

final class UpdateProfile {
  const UpdateProfile(this.repository);
  final JourneyRepository repository;
  Future<Result<UserProfile>> call(UserTrack track) => repository.updateTrack(track);
}
