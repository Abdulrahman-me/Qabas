import 'package:qabas/core/error/result.dart';
import 'package:qabas/features/onboarding/domain/entities/onboarding_answers.dart';
import 'package:qabas/features/onboarding/domain/entities/onboarding_copy.dart';
import 'package:qabas/shared/domain/entities/user_profile.dart';

abstract interface class OnboardingRepository {
  Future<CuriosityCopy?> curiosity(String language);
  Future<List<PathPreview>> preview(String language, TrackChoice track);
  Future<Result<UserProfile>> complete(OnboardingAnswers answers);
  Future<Result<void>> saveLocalChoices({required bool discreetReminders, required int reminderHour});
}
