import 'package:qabas/core/error/guard.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/core/network/api_client.dart';
import 'package:qabas/features/streak/data/activity_dto.dart';
import 'package:qabas/features/streak/domain/activity.dart';

final class ActivityRepositoryImpl implements ActivityRepository {
  const ActivityRepositoryImpl(this.api);
  final ApiClient api;
  @override
  Future<Result<Activity>> load() => guard(() async => (await api.get('/me/activity', decode: ActivityDto.fromJson)).toEntity());
}
