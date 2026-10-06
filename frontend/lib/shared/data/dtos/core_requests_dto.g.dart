// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'core_requests_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GuestRequestDto _$GuestRequestDtoFromJson(Map<String, dynamic> json) => $checkedCreate('GuestRequestDto', json, ($checkedConvert) {
  final val = GuestRequestDto($checkedConvert('timezone', (v) => v as String));
  return val;
});

Map<String, dynamic> _$GuestRequestDtoToJson(GuestRequestDto instance) => <String, dynamic>{'timezone': instance.timezone};

MePatchDto _$MePatchDtoFromJson(Map<String, dynamic> json) => $checkedCreate(
  'MePatchDto',
  json,
  ($checkedConvert) {
    final val = MePatchDto(
      displayName: $checkedConvert('display_name', (v) => v as String?),
      language: $checkedConvert('language', (v) => v as String?),
      track: $checkedConvert('track', (v) => v as String?),
      dailyGoalMinutes: $checkedConvert('daily_goal_minutes', (v) => (v as num?)?.toInt()),
      timezone: $checkedConvert('timezone', (v) => v as String?),
      avatarKey: $checkedConvert('avatar_key', (v) => v as String?),
      privateProfile: $checkedConvert('private_profile', (v) => v as bool?),
      goalAnchor: $checkedConvert('goal_anchor', (v) => v as String?),
    );
    return val;
  },
  fieldKeyMap: const {
    'displayName': 'display_name',
    'dailyGoalMinutes': 'daily_goal_minutes',
    'avatarKey': 'avatar_key',
    'privateProfile': 'private_profile',
    'goalAnchor': 'goal_anchor',
  },
);

Map<String, dynamic> _$MePatchDtoToJson(MePatchDto instance) => <String, dynamic>{
  'display_name': ?instance.displayName,
  'language': ?instance.language,
  'track': ?instance.track,
  'timezone': ?instance.timezone,
  'avatar_key': ?instance.avatarKey,
  'goal_anchor': ?instance.goalAnchor,
  'daily_goal_minutes': ?instance.dailyGoalMinutes,
  'private_profile': ?instance.privateProfile,
};
