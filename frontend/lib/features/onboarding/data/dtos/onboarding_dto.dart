import 'package:json_annotation/json_annotation.dart';
import 'package:qabas/shared/data/dtos/next_step_dto.dart';
import 'package:qabas/shared/data/dtos/user_dto.dart';

part 'onboarding_dto.g.dart';

@JsonSerializable(createToJson: true, includeIfNull: true)
final class OnboardingRequestDto {
  const OnboardingRequestDto({
    required this.trackChoice,
    required this.language,
    required this.familiarity,
    required this.dailyGoalMinutes,
    required this.privateProfile,
    required this.goalAnchor,
  });
  factory OnboardingRequestDto.fromJson(Map<String, dynamic> json) => _$OnboardingRequestDtoFromJson(json);
  final String trackChoice, language;
  @JsonKey(required: true)
  final String? familiarity;
  @JsonKey(required: true)
  final String? goalAnchor;
  final int dailyGoalMinutes;
  final bool privateProfile;
  Map<String, dynamic> toJson() => _$OnboardingRequestDtoToJson(this);
}

@JsonSerializable()
final class OnboardingResponseDto {
  const OnboardingResponseDto({required this.user, required this.startUnitId, required this.nextStep});
  factory OnboardingResponseDto.fromJson(Map<String, dynamic> json) => _$OnboardingResponseDtoFromJson(json);
  final UserDto user;
  final String startUnitId;
  final NextStepDto nextStep;
}
