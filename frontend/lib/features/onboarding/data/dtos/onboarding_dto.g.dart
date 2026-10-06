// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'onboarding_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OnboardingRequestDto _$OnboardingRequestDtoFromJson(Map<String, dynamic> json) => $checkedCreate(
  'OnboardingRequestDto',
  json,
  ($checkedConvert) {
    $checkKeys(json, requiredKeys: const ['familiarity', 'goal_anchor']);
    final val = OnboardingRequestDto(
      trackChoice: $checkedConvert('track_choice', (v) => v as String),
      language: $checkedConvert('language', (v) => v as String),
      familiarity: $checkedConvert('familiarity', (v) => v as String?),
      dailyGoalMinutes: $checkedConvert('daily_goal_minutes', (v) => (v as num).toInt()),
      privateProfile: $checkedConvert('private_profile', (v) => v as bool),
      goalAnchor: $checkedConvert('goal_anchor', (v) => v as String?),
    );
    return val;
  },
  fieldKeyMap: const {
    'trackChoice': 'track_choice',
    'dailyGoalMinutes': 'daily_goal_minutes',
    'privateProfile': 'private_profile',
    'goalAnchor': 'goal_anchor',
  },
);

Map<String, dynamic> _$OnboardingRequestDtoToJson(OnboardingRequestDto instance) => <String, dynamic>{
  'track_choice': instance.trackChoice,
  'language': instance.language,
  'familiarity': instance.familiarity,
  'goal_anchor': instance.goalAnchor,
  'daily_goal_minutes': instance.dailyGoalMinutes,
  'private_profile': instance.privateProfile,
};

OnboardingResponseDto _$OnboardingResponseDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('OnboardingResponseDto', json, ($checkedConvert) {
      final val = OnboardingResponseDto(
        user: $checkedConvert('user', (v) => UserDto.fromJson(v as Map<String, dynamic>)),
        startUnitId: $checkedConvert('start_unit_id', (v) => v as String),
        nextStep: $checkedConvert('next_step', (v) => NextStepDto.fromJson(v as Map<String, dynamic>)),
      );
      return val;
    }, fieldKeyMap: const {'startUnitId': 'start_unit_id', 'nextStep': 'next_step'});
