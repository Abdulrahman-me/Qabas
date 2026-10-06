import 'package:json_annotation/json_annotation.dart';
import 'package:qabas/shared/data/dtos/user_dto.dart';
part 'auth_response_dto.g.dart';

@JsonSerializable()
final class AuthResponseDto {
  const AuthResponseDto({required this.accessToken, required this.user});
  factory AuthResponseDto.fromJson(Map<String, dynamic> json) => _$AuthResponseDtoFromJson(json);
  final String accessToken;
  final UserDto user;
}
