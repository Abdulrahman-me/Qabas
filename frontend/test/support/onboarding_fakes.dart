import 'dart:async';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/features/onboarding/domain/entities/onboarding_answers.dart';
import 'package:qabas/features/onboarding/domain/entities/onboarding_copy.dart';
import 'package:qabas/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:qabas/features/onboarding/domain/usecases/onboarding_actions.dart';
import 'package:qabas/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:qabas/shared/domain/entities/user_profile.dart';
import 'session_fakes.dart';

class FakeOnboarding implements OnboardingRepository {
  final submitted = <OnboardingAnswers>[];
  final languages = <String>[];
  final local = <(bool, int)>[];
  bool flag = false;
  Result<UserProfile>? result;
  Completer<Result<UserProfile>>? pending;
  CuriosityCopy? copy = CuriosityCopy(
    question: 'Question',
    options: [
      for (final key in ['does_god_exist', 'who_is_god', 'quran_special', 'who_was_muhammad', 'muslim_beliefs', 'why_pray'])
        CuriosityOption(anchor: key, label: key, explorerBridge: key == 'who_was_muhammad' ? 'Reviewed bridge' : null),
    ],
  );
  @override
  Future<CuriosityCopy?> curiosity(String language) async => language == 'en' ? copy : null;
  @override
  Future<List<PathPreview>> preview(String language, TrackChoice track) async => [
    PathPreview(number: track == TrackChoice.newMuslim ? 1 : 0, title: 'First unit', artKey: 'book'),
  ];
  @override
  Future<Result<UserProfile>> complete(OnboardingAnswers answers) async {
    submitted.add(answers);
    return pending?.future ??
        result ??
        Ok(
          learner(
            onboarded: true,
            anchor: answers.goalAnchor,
            track: answers.track == TrackChoice.newMuslim ? UserTrack.newMuslim : UserTrack.explorer,
          ),
        );
  }

  @override
  Future<Result<void>> saveLocalChoices({required bool discreetReminders, required int reminderHour}) async {
    local.add((discreetReminders, reminderHour));
    return const Ok(null);
  }

  OnboardingBloc bloc() => OnboardingBloc(
    complete: CompleteOnboarding(this),
    copy: LoadOnboardingCopy(this),
    savePreferences: SaveOnboardingPreferences(this),
    curiosityEnabled: () => flag,
    changeLanguage: (language) async {
      languages.add(language);
    },
    language: 'en',
  );
}
