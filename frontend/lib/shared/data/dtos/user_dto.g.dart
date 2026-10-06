// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserDto _$UserDtoFromJson(Map<String, dynamic> json) => $checkedCreate(
  'UserDto',
  json,
  ($checkedConvert) {
    $checkKeys(json, requiredKeys: const ['familiarity', 'goal_anchor']);
    final val = UserDto(
      userId: $checkedConvert('user_id', (v) => v as String),
      displayName: $checkedConvert('display_name', (v) => v as String),
      role: $checkedConvert('role', (v) => $enumDecode(_$RoleDtoEnumMap, v, unknownValue: RoleDto.unknown)),
      language: $checkedConvert('language', (v) => $enumDecode(_$LanguageDtoEnumMap, v, unknownValue: LanguageDto.unknown)),
      track: $checkedConvert('track', (v) => $enumDecode(_$TrackDtoEnumMap, v, unknownValue: TrackDto.unknown)),
      dailyGoalMinutes: $checkedConvert('daily_goal_minutes', (v) => (v as num).toInt()),
      timezone: $checkedConvert('timezone', (v) => v as String),
      onboardingCompleted: $checkedConvert('onboarding_completed', (v) => v as bool),
      avatarKey: $checkedConvert('avatar_key', (v) => v as String),
      familiarity: $checkedConvert(
        'familiarity',
        (v) => $enumDecodeNullable(_$FamiliarityDtoEnumMap, v, unknownValue: FamiliarityDto.unknown),
      ),
      privateProfile: $checkedConvert('private_profile', (v) => v as bool),
      goalAnchor: $checkedConvert('goal_anchor', (v) => v as String?),
      createdAt: $checkedConvert('created_at', (v) => v as String),
    );
    return val;
  },
  fieldKeyMap: const {
    'userId': 'user_id',
    'displayName': 'display_name',
    'dailyGoalMinutes': 'daily_goal_minutes',
    'onboardingCompleted': 'onboarding_completed',
    'avatarKey': 'avatar_key',
    'privateProfile': 'private_profile',
    'goalAnchor': 'goal_anchor',
    'createdAt': 'created_at',
  },
);

const _$RoleDtoEnumMap = {RoleDto.learner: 'learner', RoleDto.reviewer: 'reviewer', RoleDto.unknown: 'unknown'};

const _$LanguageDtoEnumMap = {LanguageDto.ar: 'ar', LanguageDto.en: 'en', LanguageDto.unknown: 'unknown'};

const _$TrackDtoEnumMap = {TrackDto.explorer: 'explorer', TrackDto.newMuslim: 'new_muslim', TrackDto.unknown: 'unknown'};

const _$FamiliarityDtoEnumMap = {
  FamiliarityDto.none: 'none',
  FamiliarityDto.some: 'some',
  FamiliarityDto.good: 'good',
  FamiliarityDto.unknown: 'unknown',
};
