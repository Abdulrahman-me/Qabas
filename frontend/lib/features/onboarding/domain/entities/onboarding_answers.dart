import 'package:equatable/equatable.dart';
import 'package:qabas/shared/domain/entities/user_profile.dart';

enum TrackChoice { explorer, newMuslim, undisclosed }

final class OnboardingAnswers extends Equatable {
  const OnboardingAnswers({
    required this.track,
    required this.language,
    required this.familiarity,
    required this.dailyGoal,
    required this.privateProfile,
    required this.goalAnchor,
  });
  final TrackChoice track;
  final String language;
  final Familiarity? familiarity;
  final int dailyGoal;
  final bool privateProfile;
  final String? goalAnchor;
  @override
  List<Object?> get props => [track, language, familiarity, dailyGoal, privateProfile, goalAnchor];
}
