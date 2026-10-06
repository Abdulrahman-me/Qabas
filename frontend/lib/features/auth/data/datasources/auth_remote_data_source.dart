import 'package:qabas/core/network/api_client.dart';
import 'package:qabas/shared/data/dtos/auth_response_dto.dart';
import 'package:qabas/shared/data/dtos/core_requests_dto.dart';
import 'package:qabas/shared/data/dtos/user_dto.dart';

final class AuthRemoteDataSource {
  const AuthRemoteDataSource(this.api);
  final ApiClient api;
  Future<AuthResponseDto> createGuest(String timezone) =>
      api.post('/auth/guest', body: GuestRequestDto(timezone).toJson(), decode: AuthResponseDto.fromJson);
  Future<UserDto> currentUser() => api.get('/me', decode: UserDto.fromJson);
}
