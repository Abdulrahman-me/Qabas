import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:qabas/app/app.dart';
import 'package:qabas/app/config/app_config.dart';
import 'package:qabas/app/di/injector.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/core/storage/preferences_store.dart';
import 'package:qabas/core/storage/token_store.dart';
import 'package:qabas/features/auth/presentation/bloc/app_session_bloc.dart';
import 'package:qabas/features/auth/presentation/pages/splash_page.dart';
import 'package:qabas/features/onboarding/domain/entities/onboarding_answers.dart';
import 'package:qabas/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:qabas/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:qabas/mock_backend/mock_backend.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  Future<void> capture(WidgetTester tester, String name) async {
    for (var frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await binding.takeScreenshot('phase3/$name');
  }

  Future<void> until(WidgetTester tester, bool Function() condition) async {
    for (var i = 0; i < 100 && !condition(); i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(condition(), true);
    expect(tester.takeException(), isNull);
  }

  OnboardingBloc onboarding(WidgetTester tester) => tester.element(find.byType(OnboardingPageView)).read<OnboardingBloc>();
  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
  }

  Finder action(OnboardingPage page, String key) => find.descendant(of: find.byKey(ValueKey(page)), matching: find.byKey(ValueKey(key)));
  Future<void> next(WidgetTester tester) async => tap(tester, action(onboarding(tester).state.page, 'onboarding-continue'));
  Future<AppDependencies> fresh(WidgetTester tester, {bool reduced = false, bool curiosity = false}) async {
    final store = await PreferencesStore.open();
    await store.clear();
    await store.setBoolean('reduce_motion', reduced);
    final d = await AppDependencies.create(
      config: AppConfig(curiosityOnboarding: curiosity),
      store: store,
    );
    await d.services<TokenStore>().clear();
    d.services<MockBackend>().controls.fast = true;
    await tester.pumpWidget(QabasApp(dependencies: d));
    await until(tester, () => find.byType(OnboardingPageView).evaluate().isNotEmpty);
    await tester.pump(const Duration(seconds: 1));
    return d;
  }

  if (const String.fromEnvironment('PHASE3_TOUR') == 'splash') {
    testWidgets('Splash waits for both its minimum and bootstrap completion', (tester) async {
      final store = await PreferencesStore.open();
      await store.clear();
      final d = await AppDependencies.create(
        config: AppConfig(curiosityOnboarding: false),
        store: store,
        initialSessionState: const AppSessionState(status: SessionStatus.authenticating),
      );
      await d.services<TokenStore>().clear();
      d.services<MockBackend>().controls.fast = true;
      await tester.pumpWidget(QabasApp(dependencies: d));
      await until(tester, () => d.session.state.splashElapsed);
      expect(find.byType(SplashPage), findsOneWidget);
      await capture(tester, 'splash');
      expect(d.session.state.status, SessionStatus.authenticating);
      d.session.add(const AppStarted());
      await until(tester, () => find.byType(OnboardingPageView).evaluate().isNotEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      await d.dispose();
    });
    return;
  }

  for (final language in const String.fromEnvironment('PHASE3_TOUR') == 'curiosity' ? <String>[] : ['en', 'ar']) {
    for (final reduced in [false, true]) {
      testWidgets('Fresh onboarding, retained submit, reopen: $language / $reduced', (tester) async {
        final prefix = '${language}_${reduced ? 'reduced' : 'motion'}';
        final d = await fresh(tester, reduced: reduced);
        await capture(tester, '${prefix}_01_onboarding_language');
        await tap(tester, find.text(language == 'en' ? 'English' : 'العربية'));
        await until(tester, () => onboarding(tester).state.page == OnboardingPage.welcome);
        await tester.pump(const Duration(seconds: 1));
        await capture(tester, '${prefix}_02_onboarding_welcome');
        var context = tester.element(find.byType(OnboardingPageView));
        await until(tester, () => find.byKey(const ValueKey('onboarding-get-started')).evaluate().isNotEmpty);
        await tap(tester, find.byKey(const ValueKey('onboarding-get-started')));
        await capture(tester, '${prefix}_03_onboarding_who');
        final choice = language == 'ar' && !reduced
            ? TrackChoice.explorer
            : language == 'en' && reduced
            ? TrackChoice.undisclosed
            : TrackChoice.newMuslim;
        context = tester.element(find.byType(OnboardingPageView));
        final title = switch (choice) {
          TrackChoice.explorer => context.l10n.onboardingExplorerTitle,
          TrackChoice.newMuslim => context.l10n.onboardingNewMuslimTitle,
          TrackChoice.undisclosed => context.l10n.onboardingPreferNotToSay,
        };
        await tap(tester, find.text(title));
        await capture(tester, '${prefix}_04_onboarding_who_selected');
        await next(tester);
        context = tester.element(find.byType(OnboardingPageView));
        await tap(tester, find.text(context.l10n.onboardingFamiliarSome));
        await capture(tester, '${prefix}_05_onboarding_familiar');
        await next(tester);
        await capture(tester, '${prefix}_06_onboarding_goal');
        await next(tester);
        await capture(tester, '${prefix}_07_onboarding_privacy');
        await next(tester);
        await capture(tester, '${prefix}_08_onboarding_ready');
        final bloc = onboarding(tester);
        expect(bloc.state.pages.length, 7);
        expect(bloc.state.language, language);
        if (language == 'en' && !reduced) {
          d.services<MockBackend>().controls.nextStatus = 503;
          await tap(tester, find.byKey(const ValueKey('onboarding-submit')));
          await until(tester, () => bloc.state.status == OnboardingStatus.failure);
          expect(bloc.state.track, choice);
          expect(bloc.state.familiarity, isNotNull);
          await capture(tester, '${prefix}_submit_retry');
        }
        await tap(tester, find.byKey(const ValueKey('onboarding-submit')));
        await until(tester, () => find.byKey(const ValueKey('nav-0')).evaluate().isNotEmpty);
        expect(d.session.state.status, SessionStatus.ready);
        expect(d.session.state.user!.goalAnchor, isNull);
        final tokens = d.services<TokenStore>();
        final original = await tokens.read();
        expect(original, isNotNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await d.dispose();
        final reopened = await AppDependencies.create(config: AppConfig(curiosityOnboarding: false));
        reopened.services<MockBackend>().controls.fast = true;
        await tester.pumpWidget(QabasApp(dependencies: reopened));
        await until(tester, () => find.byKey(const ValueKey('nav-0')).evaluate().isNotEmpty);
        expect(find.byType(OnboardingPageView), findsNothing);
        expect(await reopened.services<TokenStore>().read(), original);
        await capture(tester, '${prefix}_reopened_journey');
        if (language == 'en' && !reduced) {
          await tap(tester, find.byKey(const ValueKey('nav-4')));
          await tester.longPress(find.byKey(const ValueKey('profile-avatar')));
          await tester.pump(const Duration(seconds: 1));
          await tap(tester, find.text('Revoke token'));
          await until(tester, () => find.byKey(const ValueKey('session-ended-continue')).evaluate().isNotEmpty);
          await capture(tester, 'session_ended');
          await tap(tester, find.byKey(const ValueKey('session-ended-continue')));
          await until(tester, () => find.byType(OnboardingPageView).evaluate().isNotEmpty);
          expect(await reopened.services<TokenStore>().read(), isNot(original));
          expect(reopened.session.state.status, SessionStatus.needsOnboarding);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await reopened.dispose();
      });
    }
  }
  testWidgets('Curiosity choice and reviewed bridge; global update gate from developer tools', (tester) async {
    final d = await fresh(tester, curiosity: true);
    await tap(tester, find.text('English'));
    await until(tester, () => onboarding(tester).state.page == OnboardingPage.welcome);
    await until(tester, () => find.byKey(const ValueKey('onboarding-get-started')).evaluate().isNotEmpty);
    await tap(tester, find.byKey(const ValueKey('onboarding-get-started')));
    var context = tester.element(find.byType(OnboardingPageView));
    await tap(tester, find.text(context.l10n.onboardingExplorerTitle));
    await next(tester);
    final bloc = onboarding(tester);
    expect(bloc.state.page, OnboardingPage.curiosity);
    expect(bloc.state.pageIndex, 3);
    await capture(tester, 'curiosity_choices');
    await tap(tester, find.text('Who was Muhammad ﷺ?'));
    await next(tester);
    expect(bloc.state.bridgeVisible, true);
    await capture(tester, 'curiosity_bridge');
    await next(tester);
    context = tester.element(find.byType(OnboardingPageView));
    await tap(tester, find.text(context.l10n.onboardingFamiliarSome));
    await next(tester);
    await next(tester);
    await next(tester);
    await tap(tester, find.byKey(const ValueKey('onboarding-submit')));
    await until(tester, () => find.byKey(const ValueKey('nav-0')).evaluate().isNotEmpty);
    expect(d.session.state.user!.goalAnchor, 'who_was_muhammad');
    await tap(tester, find.byKey(const ValueKey('nav-4')));
    await tester.longPress(find.byKey(const ValueKey('profile-avatar')));
    await tester.pump(const Duration(seconds: 1));
    await tap(tester, find.text('Next HTTP 426'));
    await until(tester, () => find.byType(QBlockingScreen).evaluate().isNotEmpty);
    await capture(tester, 'update_required');
    expect(d.session.state.status, SessionStatus.outdated);
    await tester.pumpWidget(const SizedBox.shrink());
    await d.dispose();
  });
}
