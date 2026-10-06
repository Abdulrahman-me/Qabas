import 'package:qabas/shared/data/dtos/error_envelope_dto.dart';
import 'package:qabas/shared/data/dtos/next_step_dto.dart';
import 'package:qabas/shared/data/dtos/user_dto.dart';
import 'package:qabas/shared/domain/entities/api_error.dart';
import 'package:qabas/shared/domain/entities/next_step.dart';
import 'package:qabas/shared/domain/entities/user_profile.dart';

extension UserDtoMapper on UserDto {
  UserProfile toEntity() => UserProfile(
    id: userId,
    displayName: displayName,
    role: UserRole.values.byName(role.name),
    language: UserLanguage.values.byName(language.name),
    track: UserTrack.values.byName(track.name),
    dailyGoalMinutes: dailyGoalMinutes,
    timezone: timezone,
    onboardingCompleted: onboardingCompleted,
    avatarKey: avatarKey,
    familiarity: familiarity == null ? null : Familiarity.values.byName(familiarity!.name),
    privateProfile: privateProfile,
    goalAnchor: goalAnchor,
    createdAt: DateTime.parse(createdAt),
  );
}

extension NextStepDtoMapper on NextStepDto {
  NextStep toEntity() => NextStep(
    type: NextStepType.values.byName(type.name),
    reason: NextStepReason.values.byName(reason.name),
    unitId: unitId,
    lessonId: lessonId,
    title: title,
    dueReviewsCount: dueReviewsCount,
  );
}

extension ErrorBodyDtoMapper on ErrorBodyDto {
  ApiError toEntity() => ApiError(code: code, message: message, details: details);
}
