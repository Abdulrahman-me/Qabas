import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:qabas/app/app.dart';
import 'package:qabas/app/config/app_config.dart';
import 'package:qabas/app/di/injector.dart';
import 'package:qabas/core/storage/preferences_store.dart';
import 'package:qabas/core/storage/token_store.dart';
import 'package:qabas/features/auth/domain/repositories/auth_repository.dart';
import 'package:qabas/features/auth/presentation/bloc/app_session_bloc.dart';
import 'package:qabas/features/dev_tools/presentation/pages/dev_tools_page.dart';
import 'package:qabas/features/onboarding/domain/entities/onboarding_answers.dart';
import 'package:qabas/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:qabas/features/session/presentation/bloc/session_player_bloc.dart';
import 'package:qabas/features/session/presentation/pages/session_player_page.dart';
import 'package:qabas/mock_backend/mock_backend.dart';

/// Test-only driver. All interactions use the mounted production widget/BLoC tree.
class TourHarness {
  TourHarness(this.t, this.binding, this.d, this.prefix, {this.phase = 'phase11'});
  final WidgetTester t;
  final IntegrationTestWidgetsFlutterBinding binding;
  final AppDependencies d;
  final String prefix;
  final String phase;
  MockBackend get mock => d.services<MockBackend>();
  SessionPlayerBloc get player => t.element(find.byType(SessionPlayerPage)).read<SessionPlayerBloc>();

  static Future<TourHarness> fresh(
    WidgetTester t,
    IntegrationTestWidgetsFlutterBinding binding,
    String language,
    bool reduced, {
    bool onboarded = false,
    String group = 'spine',
    String phase = 'phase11',
  }) async {
    final store = await PreferencesStore.open();
    await store.clear();
    await store.setString('language', language);
    await store.setBoolean('reduce_motion', reduced);
    // Use the actual --dart-define-from-file settings, never a test-only demo facsimile.
    final config = AppConfig.fromEnvironment(appVersion: '1.0.0');
    expect(config.flavor, AppFlavor.demo);
    expect(config.hideDraftNotices, true);
    expect(config.curiosityOnboarding, false);
    final d = await AppDependencies.create(
      config: config,
      store: store,
      initialSessionState: onboarded ? const AppSessionState(status: SessionStatus.ready, splashElapsed: true) : const AppSessionState(),
    );
    await d.services<TokenStore>().clear();
    d.services<MockBackend>().controls.fast = true;
    if (onboarded) {
      await d.services<AuthRepository>().createGuest();
      await d.services<OnboardingRepository>().complete(
        OnboardingAnswers(
          track: TrackChoice.explorer,
          language: language,
          familiarity: null,
          dailyGoal: 10,
          privateProfile: true,
          goalAnchor: null,
        ),
      );
    }
    addTearDown(() async {
      await t.pumpWidget(const SizedBox.shrink());
      await d.dispose();
    });
    final h = TourHarness(t, binding, d, '$group/${language}_${reduced ? 'reduced' : 'motion'}', phase: phase);
    await t.pumpWidget(QabasApp(dependencies: d));
    return h;
  }

  Future<void> wait([int ms = 600]) async {
    // Pump individual real native frames so Rive, staggered reveals and count-ups settle.
    for (var i = 0; i < ms; i += 16) {
      await t.pump(const Duration(milliseconds: 16));
    }
    expect(t.takeException(), isNull);
  }

  Future<void> until(bool Function() condition, {String? reason}) async {
    for (var i = 0; i < 400 && !condition(); i++) {
      await t.pump(const Duration(milliseconds: 80));
    }
    expect(condition(), true, reason: reason);
    expect(t.takeException(), isNull);
    await wait();
  }

  Finder key(String name) => find.byKey(ValueKey(name));
  Future<void> tap(String name) => tapFinder(key(name));
  Future<void> tapFinder(Finder finder) async {
    expect(finder, findsWidgets);
    final target = finder.first;
    final element = t.element(target), scrollable = Scrollable.maybeOf(t.element(target));
    final rect = t.getRect(target), render = scrollable?.context.findRenderObject();
    if (render is RenderBox) {
      final viewport = render.localToGlobal(Offset.zero) & render.size;
      if (rect.top < viewport.top || rect.bottom > viewport.bottom) {
        await Scrollable.ensureVisible(element, alignment: .5);
        await wait(150);
      }
    }
    await t.tap(target);
    await wait();
  }

  void assertDemoChrome() {
    if (find.byType(DevToolsPage).evaluate().isNotEmpty) return;
    // Check only painted product text; offstage branches are deliberately excluded.
    for (final text in t.widgetList<Text>(find.byType(Text))) {
      final value = (text.data ?? text.textSpan?.toPlainText() ?? '').toLowerCase();
      expect(value.contains('mock'), false, reason: 'Mock label in product UI');
      expect(value.contains('review draft only'), false, reason: 'Draft notice in demo');
      expect(value.contains('مسودة للمراجعة فقط'), false, reason: 'Arabic draft notice in demo');
    }
  }

  Future<void> shot(String name, {int settleMs = 1200}) async {
    if (settleMs > 0) {
      await wait(settleMs);
    } else {
      await t.pump();
    }
    assertDemoChrome();
    debugPrint('TOUR_CAPTURE:$prefix/$name');
    final capture = await binding.takeScreenshot('$phase/$prefix/$name');
    if (!kIsWeb) {
      // Keep each native capture even if the host drive stops before its final
      // screenshot callback. On a simulator this is also readable from the host.
      final file = File('${Directory.systemTemp.path}/qabas_tour/$phase/$prefix/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(capture);
    }
  }
}
