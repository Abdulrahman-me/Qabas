import 'package:qabas/core/error/result.dart';
import 'package:qabas/core/network/auth_events.dart';
import 'package:qabas/features/auth/domain/repositories/auth_repository.dart';
import 'package:qabas/features/auth/domain/usecases/session_actions.dart';
import 'package:qabas/features/auth/presentation/bloc/app_session_bloc.dart';
import 'package:qabas/shared/domain/entities/user_profile.dart';

UserProfile learner({bool onboarded = false, UserTrack track = UserTrack.explorer, String? anchor}) => UserProfile(
  id: 'user',
  displayName: 'Traveler',
  role: UserRole.learner,
  language: UserLanguage.en,
  track: track,
  dailyGoalMinutes: 10,
  timezone: 'UTC',
  onboardingCompleted: onboarded,
  avatarKey: 'traveler_03',
  familiarity: Familiarity.some,
  privateProfile: true,
  goalAnchor: anchor,
  createdAt: DateTime.utc(2026, 10, 4),
);

class FakeAuth implements AuthRepository {
  bool stored = false;
  int creates = 0, loads = 0, clears = 0;
  Future<Result<UserProfile>> Function()? create;
  Future<Result<UserProfile>> Function()? load;
  @override
  Future<Result<bool>> hasSession() async => Ok(stored);
  @override
  Future<Result<UserProfile>> createGuest() async {
    creates++;
    return create == null ? Ok(learner()) : create!();
  }

  @override
  Future<Result<UserProfile>> currentUser() async {
    loads++;
    return load == null ? Ok(learner(onboarded: true)) : load!();
  }

  @override
  Future<Result<void>> clearSession() async {
    clears++;
    stored = false;
    return const Ok(null);
  }

  AppSessionBloc bloc(Stream<AuthEvent> notices, {AppSessionState initial = const AppSessionState()}) => AppSessionBloc(
    notices,
    createGuest: CreateGuestSession(this),
    loadUser: LoadCurrentUser(this),
    hasSession: HasStoredSession(this),
    clearSession: ClearSession(this),
    initialState: initial,
  );
}
