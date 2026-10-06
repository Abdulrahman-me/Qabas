import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/features/onboarding/domain/entities/onboarding_answers.dart';
import 'package:qabas/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:qabas/shared/domain/entities/user_profile.dart';
import '../../support/onboarding_fakes.dart';
import '../../support/session_fakes.dart';

void main() {
  test('Flag off has seven pages, immediate language, retained selections and explicit null anchor', () async {
    final repo = FakeOnboarding();
    final bloc = repo.bloc();
    bloc.add(const OnboardingOpened());
    await tick();
    expect(bloc.state.pages.length, 7);
    bloc.add(const LanguagePicked('ar'));
    await tick();
    expect(repo.languages, ['ar']);
    await ready(bloc);
    bloc.add(const PrivacyToggled(false));
    bloc.add(const RemindersToggled(false));
    bloc.add(const ReminderTimePicked(21));
    await tick();
    bloc.add(const OnboardingSubmitted());
    await tick();
    expect(bloc.state.status, OnboardingStatus.complete);
    expect(repo.submitted.single.goalAnchor, isNull);
    expect(repo.submitted.single.language, 'ar');
    expect(repo.submitted.single.privateProfile, false);
    expect(repo.local.single, (false, 21));
    await bloc.close();
  });
  for (final skip in [false, true]) {
    test('Curiosity page is fourth; bridge/skip, skip=$skip', () async {
      final repo = FakeOnboarding()..flag = true;
      final bloc = repo.bloc();
      bloc.add(const OnboardingOpened());
      await tick();
      expect(bloc.state.pages[3], OnboardingPage.curiosity);
      expect(bloc.state.pages.length, 8);
      bloc.add(const PageAdvanced());
      bloc.add(const PageAdvanced());
      bloc.add(const TrackPicked(TrackChoice.undisclosed));
      bloc.add(const PageAdvanced());
      await tick();
      expect(bloc.state.page, OnboardingPage.curiosity);
      if (skip) {
        bloc.add(const CuriosityPicked('who_was_muhammad'));
        bloc.add(const CuriositySkipped());
      } else {
        bloc.add(const CuriosityPicked('who_was_muhammad'));
        bloc.add(const PageAdvanced());
        await tick();
        expect(bloc.state.bridgeVisible, true);
        expect(bloc.state.bridge, 'Reviewed bridge');
        bloc.add(const PageAdvanced());
      }
      await tick();
      expect(bloc.state.page, OnboardingPage.familiarity);
      bloc.add(const FamiliarityPicked(Familiarity.some));
      for (var i = 0; i < 3; i++) {
        bloc.add(const PageAdvanced());
      }
      await tick();
      bloc.add(const OnboardingSubmitted());
      await tick();
      expect(repo.submitted.single.goalAnchor, skip ? isNull : 'who_was_muhammad');
      expect(bloc.state.user!.track, UserTrack.explorer);
      await bloc.close();
    });
  }
  test('Incomplete current-language curiosity copy skips the page and clears an old anchor', () async {
    final repo = FakeOnboarding()..flag = true;
    final bloc = repo.bloc();
    bloc.add(const OnboardingOpened());
    bloc.add(const CuriosityPicked('why_pray'));
    await tick();
    bloc.add(const LanguagePicked('ar'));
    await tick();
    expect(bloc.state.pages.length, 7);
    expect(bloc.state.goalAnchor, isNull);
    expect(bloc.state.curiosity, isNull);
    await bloc.close();
  });
  test('Missing bridge advances directly and New Muslim entry stays Unit 1', () async {
    final repo = FakeOnboarding()..flag = true;
    final bloc = repo.bloc();
    bloc.add(const OnboardingOpened());
    bloc.add(const PageAdvanced());
    bloc.add(const PageAdvanced());
    bloc.add(const TrackPicked(TrackChoice.newMuslim));
    bloc.add(const PageAdvanced());
    bloc.add(const CuriosityPicked('why_pray'));
    bloc.add(const PageAdvanced());
    await tick();
    expect(bloc.state.page, OnboardingPage.familiarity);
    expect(bloc.state.bridgeVisible, false);
    expect(bloc.state.preview.single.number, 1);
    await bloc.close();
  });
  test('Failure retains all answers and retry sends the same choices', () async {
    final repo = FakeOnboarding()..result = const Err(NetworkFailure());
    final bloc = repo.bloc();
    bloc.add(const OnboardingOpened());
    await ready(bloc);
    bloc.add(const GoalPicked(20));
    await tick();
    bloc.add(const OnboardingSubmitted());
    await tick();
    expect(bloc.state.status, OnboardingStatus.failure);
    expect(bloc.state.dailyGoal, 20);
    final first = repo.submitted.single;
    repo.result = Ok(learner(onboarded: true));
    bloc.add(const OnboardingSubmitted());
    await tick();
    expect(bloc.state.status, OnboardingStatus.complete);
    expect(repo.submitted.last, first);
    await bloc.close();
  });
  test('Repeated submit is coalesced; disposal does not wait for a stalled post', () async {
    final repo = FakeOnboarding()..pending = Completer<Result<UserProfile>>();
    final bloc = repo.bloc();
    bloc.add(const OnboardingOpened());
    await ready(bloc);
    bloc.add(const OnboardingSubmitted());
    bloc.add(const OnboardingSubmitted());
    await tick();
    expect(repo.submitted.length, 1);
    expect(bloc.state.status, OnboardingStatus.submitting);
    await bloc.close().timeout(const Duration(seconds: 1));
    repo.pending!.complete(Ok(learner(onboarded: true)));
    await tick();
    expect(bloc.state.status, OnboardingStatus.submitting);
  });
  test('Back navigation retains answers, selections never skip required pages', () async {
    final repo = FakeOnboarding();
    final bloc = repo.bloc();
    bloc.add(const OnboardingOpened());
    bloc.add(const PageAdvanced());
    bloc.add(const PageAdvanced());
    bloc.add(const PageAdvanced());
    await tick();
    expect(bloc.state.page, OnboardingPage.who);
    bloc.add(const TrackPicked(TrackChoice.explorer));
    bloc.add(const PageAdvanced());
    bloc.add(const PageAdvanced());
    await tick();
    expect(bloc.state.page, OnboardingPage.familiarity);
    bloc.add(const FamiliarityPicked(Familiarity.good));
    bloc.add(const PageAdvanced());
    bloc.add(const GoalPicked(15));
    bloc.add(const PageBacked());
    await tick();
    expect(bloc.state.familiarity, Familiarity.good);
    expect(bloc.state.dailyGoal, 15);
    expect(bloc.state.track, TrackChoice.explorer);
    await bloc.close();
  });
}

Future<void> tick() => Future<void>.delayed(const Duration(milliseconds: 15));
Future<void> ready(OnboardingBloc bloc) async {
  bloc.add(const PageAdvanced());
  bloc.add(const PageAdvanced());
  bloc.add(const TrackPicked(TrackChoice.explorer));
  bloc.add(const PageAdvanced());
  bloc.add(const FamiliarityPicked(Familiarity.some));
  for (var i = 0; i < 3; i++) {
    bloc.add(const PageAdvanced());
  }
  await tick();
  expect(bloc.state.page, OnboardingPage.ready);
}
