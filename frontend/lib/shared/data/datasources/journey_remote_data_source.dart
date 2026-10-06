import 'package:qabas/core/network/api_client.dart';
import 'package:qabas/shared/data/dtos/core_requests_dto.dart';
import 'package:qabas/shared/data/dtos/journey_dto.dart';
import 'package:qabas/shared/data/dtos/next_step_dto.dart';
import 'package:qabas/shared/data/dtos/stats_dto.dart';
import 'package:qabas/shared/data/dtos/user_dto.dart';

final class JourneyRemoteDataSource {
  const JourneyRemoteDataSource(this.api);
  final ApiClient api;
  Future<JourneyDto> journey() => api.get('/journey', decode: JourneyDto.fromJson);
  Future<NextStepDto> next() => api.get('/journey/next', decode: NextStepDto.fromJson);
  Future<StatsDto> stats() => api.get('/me/stats', decode: StatsDto.fromJson);
  Future<UserDto> updateTrack(String track) => api.patch(
    '/me',
    body: MePatchDto(track: track).toJson(),
    decode: UserDto.fromJson,
  );
}
