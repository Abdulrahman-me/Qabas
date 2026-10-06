import 'package:json_annotation/json_annotation.dart';
part 'error_envelope_dto.g.dart';

@JsonSerializable()
final class ErrorEnvelopeDto {
  const ErrorEnvelopeDto(this.error);
  factory ErrorEnvelopeDto.fromJson(Map<String, dynamic> json) => _$ErrorEnvelopeDtoFromJson(json);
  final ErrorBodyDto error;
}

@JsonSerializable()
final class ErrorBodyDto {
  const ErrorBodyDto({required this.code, required this.message, required this.details});
  factory ErrorBodyDto.fromJson(Map<String, dynamic> json) => _$ErrorBodyDtoFromJson(json);
  final String code, message;
  final Map<String, dynamic> details;
}
