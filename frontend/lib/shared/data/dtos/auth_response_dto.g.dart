// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_response_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AuthResponseDto _$AuthResponseDtoFromJson(Map<String, dynamic> json) => $checkedCreate('AuthResponseDto', json, ($checkedConvert) {
  final val = AuthResponseDto(
    accessToken: $checkedConvert('access_token', (v) => v as String),
    user: $checkedConvert('user', (v) => UserDto.fromJson(v as Map<String, dynamic>)),
  );
  return val;
}, fieldKeyMap: const {'accessToken': 'access_token'});
