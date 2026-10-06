import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/core/events/app_events.dart';
import 'package:qabas/core/network/auth_events.dart';
import 'package:qabas/features/auth/domain/usecases/session_actions.dart';
import 'package:qabas/shared/domain/entities/user_profile.dart';

enum SessionStatus { unknown, authenticating, needsOnboarding, ready, sessionEnded, outdated, failure }

final class AppSessionState extends Equatable {
  const AppSessionState({this.status = SessionStatus.unknown, this.user, this.minimumVersion, this.failure, this.splashElapsed = false});
  final SessionStatus status;
  final UserProfile? user;
  final String? minimumVersion;
  final Failure? failure;
  final bool splashElapsed;
  AppSessionState withSplashElapsed() =>
      AppSessionState(status: status, user: user, minimumVersion: minimumVersion, failure: failure, splashElapsed: true);
  @override
  List<Object?> get props => [status, user, minimumVersion, failure, splashElapsed];
}

sealed class AppSessionEvent {
  const AppSessionEvent();
}

final class AppStarted extends AppSessionEvent {
  const AppStarted();
}

final class BootstrapRetried extends AppSessionEvent {
  const BootstrapRetried();
}

final class SessionEndedAcknowledged extends AppSessionEvent {
  const SessionEndedAcknowledged();
}

final class SplashMinimumElapsed extends AppSessionEvent {
  const SplashMinimumElapsed();
}

final class UserProfileReceived extends AppSessionEvent {
  const UserProfileReceived(this.user);
  final UserProfile user;
}

final class AuthNoticeReceived extends AppSessionEvent {
  const AuthNoticeReceived(this.notice);
  final AuthEvent notice;
}

final class AppSessionBloc extends Bloc<AppSessionEvent, AppSessionState> {
  AppSessionBloc(
    Stream<AuthEvent> authEvents, {
    required this.createGuest,
    required this.loadUser,
    required this.hasSession,
    required this.clearSession,
    Stream<AppEvent>? profileEvents,
    AppSessionState initialState = const AppSessionState(),
  }) : super(initialState) {
    on<AppStarted>((event, emit) => _bootstrap(emit));
    on<BootstrapRetried>((event, emit) => _bootstrap(emit));
    on<SessionEndedAcknowledged>((event, emit) async {
      if (state.status != SessionStatus.sessionEnded) return;
      // The interceptor already cleared the expired token. Never retry it.
      await _bootstrap(emit, newGuest: true);
    });
    on<SplashMinimumElapsed>((event, emit) => emit(state.withSplashElapsed()));
    on<UserProfileReceived>((event, emit) {
      if ([SessionStatus.outdated, SessionStatus.sessionEnded, SessionStatus.authenticating].contains(state.status)) return;
      emit(
        AppSessionState(
          status: event.user.onboardingCompleted ? SessionStatus.ready : SessionStatus.needsOnboarding,
          user: event.user,
          splashElapsed: state.splashElapsed,
        ),
      );
    });
    on<AuthNoticeReceived>((event, emit) async {
      switch (event.notice) {
        case ReviewerAccessForbidden():
          if (_busy || state.status == SessionStatus.outdated) return;
          await _bootstrap(emit);
        case AuthExpired():
          // A rejected guest request is a manual-retry failure on splash, not
          // another expired-session sheet. There is no automatic auth loop.
          if (_creatingGuest || state.status == SessionStatus.outdated) return;
          _epoch++;
          _busy = false;
          emit(AppSessionState(status: SessionStatus.sessionEnded, splashElapsed: state.splashElapsed));
        case ClientOutdated(:final minimumVersion):
          _epoch++;
          _busy = false;
          emit(AppSessionState(status: SessionStatus.outdated, minimumVersion: minimumVersion, splashElapsed: state.splashElapsed));
      }
    });
    _subscriptions.add(authEvents.listen((notice) => add(AuthNoticeReceived(notice))));
    if (profileEvents != null) {
      _subscriptions.add(
        profileEvents.listen((event) {
          if (event is ProfileChanged) add(UserProfileReceived(event.profile));
          if (event is GuestSessionCleared) add(const AppStarted());
        }),
      );
    }
  }
  final CreateGuestSession createGuest;
  final LoadCurrentUser loadUser;
  final HasStoredSession hasSession;
  final ClearSession clearSession;
  final _subscriptions = <StreamSubscription<Object?>>[];
  bool _busy = false, _creatingGuest = false;
  int _epoch = 0;
  Future<void> _bootstrap(Emitter<AppSessionState> emit, {bool newGuest = false}) async {
    if (_busy || state.status == SessionStatus.outdated) return;
    _busy = true;
    final epoch = ++_epoch;
    emit(AppSessionState(status: SessionStatus.authenticating, splashElapsed: state.splashElapsed));
    Result<UserProfile> result;
    var usedStoredToken = false;
    if (newGuest) {
      final cleared = await clearSession();
      if (cleared case Err<void>(:final failure)) {
        result = Err(failure);
      } else {
        _creatingGuest = true;
        result = await createGuest();
      }
    } else {
      final stored = await hasSession();
      usedStoredToken = stored is Ok<bool> && stored.value;
      result = switch (stored) {
        Err<bool>(:final failure) => Err(failure),
        Ok<bool>(value: true) => await loadUser(),
        Ok<bool>() => await _newGuest(),
      };
    }
    _creatingGuest = false;
    if (emit.isDone || epoch != _epoch) return;
    _busy = false;
    switch (result) {
      case Ok<UserProfile>(:final value):
        emit(
          AppSessionState(
            status: value.onboardingCompleted ? SessionStatus.ready : SessionStatus.needsOnboarding,
            user: value,
            splashElapsed: state.splashElapsed,
          ),
        );
      case Err<UserProfile>(:final failure):
        if (failure is UnauthorizedFailure && usedStoredToken) await clearSession();
        if (emit.isDone || epoch != _epoch) return;
        final status = failure is ClientOutdatedFailure
            ? SessionStatus.outdated
            : failure is UnauthorizedFailure && usedStoredToken
            ? SessionStatus.sessionEnded
            : SessionStatus.failure;
        // Unauthorized stored-token failures normally arrive via AuthExpired;
        // repositories used without that stream still get the same recovery.
        emit(AppSessionState(status: status, failure: failure, splashElapsed: state.splashElapsed));
    }
  }

  Future<Result<UserProfile>> _newGuest() async {
    _creatingGuest = true;
    return createGuest();
  }

  @override
  Future<void> close() async {
    _epoch++;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await super.close();
  }
}
