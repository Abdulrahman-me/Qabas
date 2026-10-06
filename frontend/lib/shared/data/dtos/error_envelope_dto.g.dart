// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'error_envelope_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ErrorEnvelopeDto _$ErrorEnvelopeDtoFromJson(Map<String, dynamic> json) => $checkedCreate('ErrorEnvelopeDto', json, ($checkedConvert) {
  final val = ErrorEnvelopeDto($checkedConvert('error', (v) => ErrorBodyDto.fromJson(v as Map<String, dynamic>)));
  return val;
});

ErrorBodyDto _$ErrorBodyDtoFromJson(Map<String, dynamic> json) => $checkedCreate('ErrorBodyDto', json, ($checkedConvert) {
  final val = ErrorBodyDto(
    code: $checkedConvert('code', (v) => v as String),
    message: $checkedConvert('message', (v) => v as String),
    details: $checkedConvert('details', (v) => v as Map<String, dynamic>),
  );
  return val;
});
