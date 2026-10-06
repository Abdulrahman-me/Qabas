import 'package:qabas/core/error/result.dart';
import 'package:qabas/features/onboarding/domain/entities/onboarding_answers.dart';
import 'package:qabas/features/onboarding/domain/entities/onboarding_copy.dart';
import 'package:qabas/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:qabas/shared/domain/entities/user_profile.dart';

final class CompleteOnboarding {
  const CompleteOnboarding(this.repository);
  final OnboardingRepository repository;
  Future<Result<UserProfile>> call(OnboardingAnswers answers) => repository.complete(answers);
}

final class LoadOnboardingCopy {
  const LoadOnboardingCopy(this.repository);
  final OnboardingRepository repository;
  Future<CuriosityCopy?> curiosity(String language) => repository.curiosity(language);
  Future<List<PathPreview>> preview(String language, TrackChoice track) => repository.preview(language, track);
}

final class SaveOnboardingPreferences {
  const SaveOnboardingPreferences(this.repository);
  final OnboardingRepository repository;
  Future<Result<void>> call({required bool discreetReminders, required int reminderHour}) =>
      repository.saveLocalChoices(discreetReminders: discreetReminders, reminderHour: reminderHour);
}
