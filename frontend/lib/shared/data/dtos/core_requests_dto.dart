import 'package:json_annotation/json_annotation.dart';
part 'core_requests_dto.g.dart';

@JsonSerializable(createToJson: true)
final class GuestRequestDto {
  const GuestRequestDto(this.timezone);
  factory GuestRequestDto.fromJson(Map<String, dynamic> json) => _$GuestRequestDtoFromJson(json);
  final String timezone;
  Map<String, dynamic> toJson() => _$GuestRequestDtoToJson(this);
}

@JsonSerializable(createToJson: true, includeIfNull: false)
final class MePatchDto {
  const MePatchDto({
    this.displayName,
    this.language,
    this.track,
    this.dailyGoalMinutes,
    this.timezone,
    this.avatarKey,
    this.privateProfile,
    this.goalAnchor,
  });
  factory MePatchDto.fromJson(Map<String, dynamic> json) => _$MePatchDtoFromJson(json);
  final String? displayName, language, track, timezone, avatarKey, goalAnchor;
  final int? dailyGoalMinutes;
  final bool? privateProfile;
  Map<String, dynamic> toJson() => _$MePatchDtoToJson(this);
}
