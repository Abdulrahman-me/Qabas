import 'package:qabas/core/network/api_client.dart';
import 'package:qabas/features/session/data/dtos/session_dto.dart';

final class SessionRemoteDataSource {
  const SessionRemoteDataSource(this.api);
  final ApiClient api;
  Future<({SessionDto session, bool resumed})> start(String id) async {
    var resumed = false;
    final session = await api.post(
      '/sessions',
      body: SessionCreateDto(lessonId: id).toJson(),
      decode: SessionDto.fromJson,
      onStatus: (status) => resumed = status == 200,
    );
    return (session: session, resumed: resumed);
  }

  Future<SessionDto> load(String id) => api.get('/sessions/${Uri.encodeComponent(id)}', decode: SessionDto.fromJson);
}
