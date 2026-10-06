import 'package:equatable/equatable.dart';

enum UserRole { learner, reviewer, unknown }

enum UserLanguage { ar, en, unknown }

enum UserTrack { explorer, newMuslim, unknown }

enum Familiarity { none, some, good, unknown }

final class UserProfile extends Equatable {
  const UserProfile({
    required this.id,
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
  final String id, displayName, timezone, avatarKey;
  final UserRole role;
  final UserLanguage language;
  final UserTrack track;
  final int dailyGoalMinutes;
  final bool onboardingCompleted, privateProfile;
  final Familiarity? familiarity;
  final String? goalAnchor;
  final DateTime createdAt;
  @override
  List<Object?> get props => [
    id,
    displayName,
    role,
    language,
    track,
    dailyGoalMinutes,
    timezone,
    onboardingCompleted,
    avatarKey,
    familiarity,
    privateProfile,
    goalAnchor,
    createdAt,
  ];
}
