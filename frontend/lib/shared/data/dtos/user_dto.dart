import 'package:json_annotation/json_annotation.dart';
part 'user_dto.g.dart';

enum RoleDto { learner, reviewer, unknown }

enum LanguageDto { ar, en, unknown }

enum TrackDto {
  explorer,
  @JsonValue('new_muslim')
  newMuslim,
  unknown,
}

enum FamiliarityDto { none, some, good, unknown }

@JsonSerializable()
final class UserDto {
  const UserDto({
    required this.userId,
    required this.displayName,
    required this.role,
    required this.language,
    required this.track,
    required this.dailyGoalMinutes,
    required this.timezone,
    required this.onboardingCompleted,
    required this.avatarKey,
    required this.familiarity,
    required this.privateProfile,
    required this.goalAnchor,
    required this.createdAt,
  });
  factory UserDto.fromJson(Map<String, dynamic> json) => _$UserDtoFromJson(json);
  final String userId, displayName, timezone, avatarKey, createdAt;
  @JsonKey(unknownEnumValue: RoleDto.unknown)
  final RoleDto role;
  @JsonKey(unknownEnumValue: LanguageDto.unknown)
  final LanguageDto language;
  @JsonKey(unknownEnumValue: TrackDto.unknown)
  final TrackDto track;
  final int dailyGoalMinutes;
  final bool onboardingCompleted, privateProfile;
  @JsonKey(required: true, unknownEnumValue: FamiliarityDto.unknown)
  final FamiliarityDto? familiarity;
  @JsonKey(required: true)
  final String? goalAnchor;
}
