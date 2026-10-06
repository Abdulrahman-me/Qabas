import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qabas/core/audio/sensory_service.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/features/onboarding/domain/entities/onboarding_answers.dart';
import 'package:qabas/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:qabas/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:qabas/l10n/gen/app_localizations.dart';
import 'package:qabas/shared/domain/entities/user_profile.dart';
import '../../support/onboarding_fakes.dart';

const sizes = [Size(320, 568), Size(320, 400), Size(600, 400), Size(839, 600), Size(840, 600), Size(1440, 900), Size(1920, 1080)];
void main() {
  final sensory = SensoryService(settings: () => const SensorySettings(sound: false, haptics: false));
  tearDownAll(sensory.dispose);
  for (final language in ['en', 'ar']) {
    for (final reduced in [false, true]) {
      testWidgets('Every onboarding page resizes with retained answers: $language / $reduced', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = sizes.first;
        tester.platformDispatcher.textScaleFactorTestValue = 1.35;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final repo = FakeOnboarding();
        final bloc = repo.bloc();
        addTearDown(bloc.close);
        bloc.add(const OnboardingOpened());
        if (language == 'ar') bloc.add(const LanguagePicked('ar'));
        await tester.pumpWidget(
          BlocProvider.value(
            value: bloc,
            child: BlocBuilder<OnboardingBloc, OnboardingState>(
              builder: (_, state) => QMotionScope(
                reduceMotion: reduced,
                child: MaterialApp(
                  builder: (_, child) => SensoryScope(service: sensory, child: child!),
                  theme: QTheme.light(arabic: state.language == 'ar'),
                  locale: Locale(state.language),
                  localizationsDelegates: AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: OnboardingPageView(onCompleted: (_) {}),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        for (final page in [
          OnboardingPage.language,
          OnboardingPage.welcome,
          OnboardingPage.who,
          OnboardingPage.familiarity,
          OnboardingPage.goal,
          OnboardingPage.privacy,
          OnboardingPage.ready,
        ]) {
          expect(bloc.state.page, page);
          for (final size in sizes) {
            tester.view.physicalSize = size;
            await tester.pump(const Duration(seconds: 1));
            await tester.pump(const Duration(seconds: 1));
            expect(tester.takeException(), isNull, reason: '$page / $size / $language / $reduced');
            final content = tester.getRect(find.byKey(const ValueKey('onboarding-scroll')));
            expect(content.width, lessThanOrEqualTo(560));
            expect(
              Directionality.of(tester.element(find.byType(OnboardingPageView))),
              language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
            );
            if (!bloc.state.hero) {
              final action = find.descendant(
                of: find.byKey(ValueKey(page)),
                matching: find.byKey(ValueKey(page == OnboardingPage.ready ? 'onboarding-submit' : 'onboarding-continue')),
              );
              await tester.ensureVisible(action);
              await tester.pump();
              expect(tester.getRect(action).overlaps(Offset.zero & size), true);
            }
          }
          if (page == OnboardingPage.who) bloc.add(const TrackPicked(TrackChoice.undisclosed));
          if (page == OnboardingPage.familiarity) bloc.add(const FamiliarityPicked(Familiarity.good));
          if (page == OnboardingPage.goal) bloc.add(const GoalPicked(20));
          if (page == OnboardingPage.privacy) {
            bloc.add(const RemindersToggled(false));
            bloc.add(const ReminderTimePicked(21));
          }
          if (page != OnboardingPage.ready) {
            bloc.add(const PageAdvanced());
            await tester.pump(const Duration(milliseconds: 20));
            await tester.pump(const Duration(seconds: 1));
            await tester.pump(const Duration(seconds: 1));
          }
        }
        expect(bloc.state.track, TrackChoice.undisclosed);
        expect(bloc.state.dailyGoal, 20);
        expect(bloc.state.familiarity, Familiarity.good);
        expect(bloc.state.discreetReminders, false);
        expect(bloc.state.reminderHour, 21);
        final submit = find.byKey(const ValueKey('onboarding-submit'));
        await tester.ensureVisible(submit);
        await tester.pump();
        await tester.tap(submit);
        await tester.pump(const Duration(milliseconds: 20));
        expect(repo.submitted.length, 1);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(bloc.state.status, OnboardingStatus.complete);
      });
    }
  }
  testWidgets('Curiosity choices and bridge remain reachable at narrow/short widths', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 400);
    tester.platformDispatcher.textScaleFactorTestValue = 1.35;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final repo = FakeOnboarding()..flag = true;
    final bloc = repo.bloc();
    addTearDown(bloc.close);
    bloc.add(const OnboardingOpened());
    await tester.pumpWidget(
      BlocProvider.value(
        value: bloc,
        child: MaterialApp(
          builder: (_, child) => SensoryScope(service: sensory, child: child!),
          theme: QTheme.light(arabic: false),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: OnboardingPageView(onCompleted: (_) {}),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    bloc.add(const PageAdvanced());
    bloc.add(const PageAdvanced());
    bloc.add(const TrackPicked(TrackChoice.explorer));
    bloc.add(const PageAdvanced());
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    final choice = find.text('who_was_muhammad');
    await tester.ensureVisible(choice);
    await tester.pump();
    await tester.tap(choice);
    await tester.pump(const Duration(milliseconds: 20));
    final action = find.byKey(const ValueKey('onboarding-continue')).first;
    await tester.ensureVisible(action);
    await tester.pump();
    await tester.tap(action);
    await tester.pump(const Duration(milliseconds: 20));
    expect(bloc.state.bridgeVisible, true);
    expect(find.text('Reviewed bridge'), findsOneWidget);
    expect(tester.takeException(), isNull);
    for (final size in sizes) {
      tester.view.physicalSize = size;
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      final continueButton = find.descendant(
        of: find.byKey(const ValueKey(OnboardingPage.curiosity)),
        matching: find.byKey(const ValueKey('onboarding-continue')),
      );
      await tester.ensureVisible(continueButton);
      await tester.pump();
      expect(tester.getRect(continueButton).overlaps(Offset.zero & size), true);
    }
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey(OnboardingPage.curiosity)),
        matching: find.byKey(const ValueKey('onboarding-continue')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 20));
    expect(bloc.state.page, OnboardingPage.familiarity);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
