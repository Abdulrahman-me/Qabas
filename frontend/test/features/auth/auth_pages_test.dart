import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qabas/core/audio/sensory_service.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/core/network/auth_events.dart';
import 'package:qabas/features/auth/presentation/bloc/app_session_bloc.dart';
import 'package:qabas/features/auth/presentation/pages/session_ended_page.dart';
import 'package:qabas/features/auth/presentation/pages/splash_page.dart';
import 'package:qabas/l10n/gen/app_localizations.dart';
import '../../support/session_fakes.dart';

const sizes = [Size(320, 568), Size(320, 400), Size(600, 400), Size(839, 600), Size(840, 600), Size(1440, 900), Size(1920, 1080)];
void main() {
  for (final language in ['en', 'ar']) {
    for (final reduced in [false, true]) {
      testWidgets('Splash retry, expired-session sheet and update screen: $language / $reduced', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = sizes.first;
        tester.platformDispatcher.textScaleFactorTestValue = 1.35;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final auth = FakeAuth();
        final notices = StreamController<AuthEvent>.broadcast();
        final bloc = auth.bloc(
          notices.stream,
          initial: const AppSessionState(status: SessionStatus.failure, failure: NetworkFailure()),
        );
        final sensory = SensoryService(settings: () => const SensorySettings(sound: false, haptics: false));
        addTearDown(bloc.close);
        addTearDown(notices.close);
        Widget app(Widget page) => BlocProvider.value(
          value: bloc,
          child: QMotionScope(
            reduceMotion: reduced,
            child: SensoryScope(
              service: sensory,
              child: MaterialApp(
                theme: QTheme.light(arabic: language == 'ar'),
                locale: Locale(language),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: page,
              ),
            ),
          ),
        );
        await tester.pumpWidget(app(SplashPage(warmup: Future.value())));
        for (final size in sizes) {
          tester.view.physicalSize = size;
          await tester.pump(const Duration(seconds: 1));
          expect(tester.takeException(), isNull);
        }
        expect(auth.creates, 0);
        expect(bloc.state.splashElapsed, true);
        final retry = find.byType(TextButton);
        await tester.ensureVisible(retry);
        await tester.pump();
        await tester.tap(retry);
        await tester.pump();
        expect(auth.creates, 1);
        expect(bloc.state.status, SessionStatus.needsOnboarding);
        await tester.pumpWidget(app(const SessionEndedPage()));
        await tester.pump(const Duration(seconds: 1));
        for (final size in sizes) {
          tester.view.physicalSize = size;
          await tester.pump(const Duration(seconds: 1));
          expect(tester.takeException(), isNull);
          final action = find.byKey(const ValueKey('session-ended-continue'));
          await tester.ensureVisible(action);
          await tester.pump();
          expect(tester.getRect(action).overlaps(Offset.zero & size), true);
        }
        final context = tester.element(find.byType(SessionEndedPage));
        expect(find.text(context.l10n.commonSessionEndedTitle), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('session-ended-continue')));
        await tester.pump(const Duration(seconds: 1));
        var updates = 0;
        await tester.pumpWidget(app(Scaffold(body: QBlockingScreen(onUpdate: () => updates++))));
        for (final size in sizes) {
          tester.view.physicalSize = size;
          await tester.pump(const Duration(seconds: 1));
          expect(tester.takeException(), isNull);
        }
        await tester.tap(find.byType(QButton));
        expect(updates, 1);
        await tester.pumpWidget(const SizedBox.shrink());
        await sensory.dispose();
      });
    }
  }
}
