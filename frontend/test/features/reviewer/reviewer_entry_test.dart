import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qabas/app/app.dart';
import 'package:qabas/app/config/app_config.dart';
import 'package:qabas/features/auth/presentation/bloc/app_session_bloc.dart';
import 'package:qabas/features/auth/presentation/pages/splash_page.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_runs_page.dart';
import 'package:qabas/mock_backend/mock_backend.dart';
import '../journey/journey_responsive_test.dart' show mountJourney, pumpJourney, journeyUntil, press;

void main() {
  for (final sample in [false, true]) {
    testWidgets('Reviewer direct sign-in bypasses learner onboarding sample=$sample', (t) async {
      final d = await mountJourney(
        t,
        pump: false,
        initialSessionState: const AppSessionState(status: SessionStatus.ready),
        config: sample ? AppConfig(flavor: AppFlavor.demo, recordingDemo: true, demoDeveloper: true, judgesDemo: true) : null,
      );
      final mock = d.services<MockBackend>();
      await t.runAsync(() async {
        await mock.fixtures.object('examples/AuthResp__post_auth_reviewer__1.json');
        await mock.fixtures.example('FactoryRun');
      });
      await t.runAsync(d.sensory.dispose);
      await t.pumpWidget(QabasApp(dependencies: d));
      final router = GoRouter.of(t.element(find.byType(SplashPage)));
      router.go('/reviewer/login');
      await pumpJourney(t);
      expect(d.session.state.splashElapsed, false);
      if (sample) {
        await press(t, find.byKey(const ValueKey('reviewer-sample-open')));
      } else {
        expect(find.byKey(const ValueKey('reviewer-sample-open')), findsNothing);
        await t.enterText(find.byKey(const ValueKey('reviewer-email')), 'reviewer@qabas.app');
        await t.enterText(find.byKey(const ValueKey('reviewer-password')), 'qabas-review');
        FocusManager.instance.primaryFocus?.unfocus();
        await press(t, find.byKey(const ValueKey('reviewer-sign-in')));
      }
      await journeyUntil(t, () => find.byType(ReviewerRunsPage).evaluate().isNotEmpty);
      expect(d.session.state.splashElapsed, false);
      expect(t.takeException(), isNull);
      await t.runAsync(d.sensory.dispose);
      await t.pumpWidget(const SizedBox());
      await pumpJourney(t);
      await t.runAsync(d.dispose);
    });
  }
}
