import 'package:equatable/equatable.dart';
import 'package:qabas/shared/domain/entities/content.dart';
import 'package:qabas/shared/domain/entities/local_preferences.dart';
import 'package:qabas/shared/domain/entities/stats.dart';
import 'package:qabas/shared/domain/entities/user_profile.dart';

final class Achievement extends Equatable {
  const Achievement({
    required this.key,
    required this.title,
    required this.description,
    required this.unlocked,
    required this.unlockedAt,
    required this.current,
    required this.target,
  });
  final String key, title, description;
  final bool unlocked;
  final DateTime? unlockedAt;
  final int current, target;
  @override
  List<Object?> get props => [key, title, description, unlocked, unlockedAt, current, target];
}

final class ProfileSnapshot extends Equatable {
  ProfileSnapshot({required this.user, required this.stats, required List<Achievement> achievements, required List<TermCard> words})
    : achievements = List.unmodifiable(achievements),
      words = List.unmodifiable(words);
  final UserProfile user;
  final Stats stats;
  final List<Achievement> achievements;
  final List<TermCard> words;
  @override
  List<Object?> get props => [user, stats, achievements, words];
}

final class ProfileEdit extends Equatable {
  const ProfileEdit({this.displayName, this.language, this.track, this.dailyGoal, this.privateProfile, this.goalAnchor});
  final String? displayName, goalAnchor;
  final UserLanguage? language;
  final UserTrack? track;
  final int? dailyGoal;
  final bool? privateProfile;
  UserProfile apply(UserProfile user) => UserProfile(
    id: user.id,
    displayName: displayName ?? user.displayName,
    role: user.role,
    language: language ?? user.language,
    track: track ?? user.track,
    dailyGoalMinutes: dailyGoal ?? user.dailyGoalMinutes,
    timezone: user.timezone,
    onboardingCompleted: user.onboardingCompleted,
    avatarKey: user.avatarKey,
    familiarity: user.familiarity,
    privateProfile: privateProfile ?? user.privateProfile,
    goalAnchor: goalAnchor ?? user.goalAnchor,
    createdAt: user.createdAt,
  );
  @override
  List<Object?> get props => [displayName, language, track, dailyGoal, privateProfile, goalAnchor];
}

final class SettingsCuriosity extends Equatable {
  SettingsCuriosity(this.question, Map<String, String> labels) : labels = Map.unmodifiable(labels);
  final String question;
  final Map<String, String> labels;
  @override
  List<Object?> get props => [question, labels];
}

/// One changed local setting; applying it at handling time preserves queued edits.
final class LocalPreferencesEdit extends Equatable {
  const LocalPreferencesEdit({
    this.sound,
    this.haptics,
    this.reduceMotion,
    this.discreetReminders,
    this.companionEnabled,
    this.reminderHour,
  });
  final bool? sound, haptics, reduceMotion, discreetReminders, companionEnabled;
  final int? reminderHour;
  LocalPreferences apply(LocalPreferences previous) => previous.copyWith(
    sound: sound,
    haptics: haptics,
    reduceMotion: reduceMotion,
    discreetReminders: discreetReminders,
    companionEnabled: companionEnabled,
    reminderHour: reminderHour,
  );
  @override
  List<Object?> get props => [sound, haptics, reduceMotion, discreetReminders, companionEnabled, reminderHour];
}
