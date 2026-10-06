import 'package:qabas/shared/domain/entities/user_profile.dart';

sealed class AppEvent {
  const AppEvent();
}

final class GuestSessionCleared extends AppEvent {
  const GuestSessionCleared();
}

final class SessionCompleted extends AppEvent {
  const SessionCompleted({required this.sessionId, required this.kind, required this.streakExtended});
  final String sessionId, kind;
  final bool streakExtended;
}

final class TermsMastered extends AppEvent {
  TermsMastered(Set<String> termIds) : termIds = Set.unmodifiable(termIds);
  final Set<String> termIds;
}

final class ProfileChanged extends AppEvent {
  const ProfileChanged(this.profile);
  final UserProfile profile;
}

final class XpChanged extends AppEvent {
  const XpChanged();
}

/// Learning state changed before finish (session creation or developer changes).
final class LearningProgressChanged extends AppEvent {
  const LearningProgressChanged();
}

final class ChallengeInvitationsChanged extends AppEvent {
  const ChallengeInvitationsChanged();
}

/// Private recording samples were reset; mounted reviewer flows must reload.
final class ReviewerSamplesReset extends AppEvent {
  const ReviewerSamplesReset();
}
