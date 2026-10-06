import 'dart:async';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/core/network/auth_events.dart';
import 'package:qabas/features/auth/presentation/bloc/app_session_bloc.dart';
import 'package:qabas/shared/domain/entities/user_profile.dart';
import '../../support/session_fakes.dart';

void main() {
  late FakeAuth auth;
  late StreamController<AuthEvent> notices;
  setUp(() {
    auth = FakeAuth();
    notices = StreamController<AuthEvent>.broadcast();
  });
  tearDown(() => notices.close());
  blocTest<AppSessionBloc, AppSessionState>(
    'Fresh install creates exactly one guest; splash gate is independent',
    build: () => auth.bloc(notices.stream),
    act: (bloc) {
      bloc.add(const AppStarted());
      bloc.add(const AppStarted());
    },
    expect: () => [
      isA<AppSessionState>().having((s) => s.status, 'status', SessionStatus.authenticating),
      isA<AppSessionState>()
          .having((s) => s.status, 'status', SessionStatus.needsOnboarding)
          .having((s) => s.splashElapsed, 'minimum', false),
    ],
    verify: (_) {
      expect(auth.creates, 1);
      expect(auth.loads, 0);
    },
  );
  blocTest<AppSessionBloc, AppSessionState>(
    'Stored completed user loads with no new guest',
    build: () {
      auth.stored = true;
      return auth.bloc(notices.stream);
    },
    act: (bloc) => bloc.add(const AppStarted()),
    expect: () => [
      isA<AppSessionState>().having((s) => s.status, 'status', SessionStatus.authenticating),
      isA<AppSessionState>().having((s) => s.status, 'status', SessionStatus.ready),
    ],
    verify: (_) {
      expect(auth.creates, 0);
      expect(auth.loads, 1);
    },
  );
  test('reviewer 403 reloads the current learner role without clearing its token', () async {
    auth.stored = true;
    auth.load = () async => Ok(learner(onboarded: true));
    final bloc = auth.bloc(notices.stream, initial: const AppSessionState(status: SessionStatus.ready, splashElapsed: true));
    notices.add(const ReviewerAccessForbidden());
    await tick();
    expect(bloc.state.status, SessionStatus.ready);
    expect(bloc.state.user!.role, UserRole.learner);
    expect(auth.loads, 1);
    expect(auth.creates, 0);
    expect(auth.stored, true);
    await bloc.close();
  });
  test('Stored incomplete user resumes onboarding; minimum duration retains user', () async {
    auth.stored = true;
    auth.load = () async => Ok(learner());
    final bloc = auth.bloc(notices.stream);
    bloc.add(const AppStarted());
    await tick();
    expect(bloc.state.status, SessionStatus.needsOnboarding);
    final user = bloc.state.user;
    bloc.add(const SplashMinimumElapsed());
    await tick();
    expect(bloc.state.splashElapsed, true);
    expect(bloc.state.user, user);
    await bloc.close();
  });
  for (final stored in [false, true]) {
    test('Bootstrap failure has manual retry, stored=$stored', () async {
      auth.stored = stored;
      var fails = true;
      Future<Result<UserProfile>> response() async => fails ? const Err(NetworkFailure()) : Ok(learner(onboarded: stored));
      auth.create = response;
      auth.load = response;
      final bloc = auth.bloc(notices.stream);
      bloc.add(const AppStarted());
      await tick();
      expect(bloc.state.status, SessionStatus.failure);
      expect(auth.creates + auth.loads, 1);
      fails = false;
      bloc.add(const BootstrapRetried());
      await tick();
      expect(bloc.state.status, stored ? SessionStatus.ready : SessionStatus.needsOnboarding);
      expect(auth.creates + auth.loads, 2);
      await bloc.close();
    });
  }
  test('Expired stored token waits for acknowledgement, then a failed guest stays on splash', () async {
    auth.stored = true;
    auth.load = () async => const Err(UnauthorizedFailure());
    auth.create = () async => const Err(UnauthorizedFailure());
    final bloc = auth.bloc(notices.stream);
    bloc.add(const AppStarted());
    await tick();
    expect(bloc.state.status, SessionStatus.sessionEnded);
    expect(auth.creates, 0);
    bloc.add(const SessionEndedAcknowledged());
    await tick();
    expect(bloc.state.status, SessionStatus.failure);
    expect(auth.creates, 1);
    await tick();
    expect(auth.creates, 1);
    auth.create = () async => Ok(learner());
    bloc.add(const BootstrapRetried());
    await tick();
    expect(bloc.state.status, SessionStatus.needsOnboarding);
    expect(auth.creates, 2);
    await bloc.close();
  });
  test('An in-flight bootstrap cannot overwrite a global 426 gate', () async {
    final pending = Completer<Result<UserProfile>>();
    auth.create = () => pending.future;
    final bloc = auth.bloc(notices.stream);
    bloc.add(const AppStarted());
    await tick();
    notices.add(const ClientOutdated('2.0.0'));
    await tick();
    pending.complete(Ok(learner()));
    await tick();
    expect(bloc.state.status, SessionStatus.outdated);
    expect(bloc.state.minimumVersion, '2.0.0');
    bloc.add(const BootstrapRetried());
    await tick();
    expect(auth.creates, 1);
    await bloc.close();
  });
  test('Late completion after revocation cannot restore an old user', () async {
    auth.stored = true;
    final pending = Completer<Result<UserProfile>>();
    auth.load = () => pending.future;
    final bloc = auth.bloc(notices.stream);
    bloc.add(const AppStarted());
    await tick();
    notices.add(const AuthExpired());
    await tick();
    pending.complete(Ok(learner(onboarded: true)));
    await tick();
    expect(bloc.state.status, SessionStatus.sessionEnded);
    expect(bloc.state.user, isNull);
    await bloc.close();
  });
}

Future<void> tick() => Future<void>.delayed(const Duration(milliseconds: 5));
