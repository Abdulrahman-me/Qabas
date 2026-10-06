import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qabas/app/app.dart';
import 'package:qabas/app/config/app_config.dart';
import 'package:qabas/app/di/injector.dart';
import 'package:qabas/app/presentation/home_shell.dart';
import 'package:qabas/core/characters/character_asset_cache.dart';
import 'package:qabas/core/characters/character_view.dart';
import 'package:qabas/features/auth/presentation/bloc/app_session_bloc.dart';
import 'package:qabas/features/community/presentation/community_page.dart';
import 'package:qabas/features/dev_tools/presentation/pages/dev_tools_page.dart';
import 'package:qabas/features/discover/presentation/pages/discover_page.dart';
import 'package:qabas/features/journey/presentation/pages/journey_page.dart';
import 'package:qabas/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:qabas/features/profile/presentation/pages/profile_page.dart';
import 'package:qabas/features/raqeeb/presentation/pages/raqeeb_page.dart';
import 'package:qabas/mock_backend/mock_backend.dart';
import 'package:qabas/shared/domain/entities/local_preferences.dart';
import 'package:qabas/shared/presentation/brand/brand.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/journey/journey_responsive_test.dart' show pumpJourney;
import '../support/fakes.dart';
import '../support/journey_test_assets.dart';

void main() {
  const sizes = [Size(320, 568), Size(320, 400), Size(600, 400), Size(839, 600), Size(840, 600), Size(1440, 900), Size(1920, 1080)];
  Future<AppDependencies> mount(WidgetTester tester, {String locale = 'en', bool reduced = false}) async {
    SharedPreferences.setMockInitialValues({'qabas_language': locale, 'qabas_reduce_motion': reduced});
    final tokens = MemoryTokens()..value = 'test-session';
    final d = await AppDependencies.create(
      config: AppConfig(),
      initialSessionState: const AppSessionState(status: SessionStatus.ready, splashElapsed: true),
      tokens: tokens,
      mockFixtures: journeyTestAssets(),
      cache: CharacterAssetCache(loader: (_) async => null),
    );
    final mock = d.services<MockBackend>();
    mock.controls.fast = true;
    mock.db.tokens.add(tokens.value!);
    await tester.runAsync(() async {
      mock.db.user = await mock.fixtures.example('User');
      await mock.fixtures.example('Stats');
      await mock.fixtures.example('Achievements');
      await mock.fixtures.example('Page[TermCard]');
      await mock.fixtures.object('demo_curriculum/curriculum.json');
    });
    mock.db.user!['language'] = locale;
    await tester.pumpWidget(QabasApp(dependencies: d));
    await pumpJourney(tester);
    return d;
  }

  for (final locale in ['en', 'ar']) {
    for (final reduced in [false, true]) {
      testWidgets('Responsive shell retains branch state: $locale / $reduced', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = sizes.first;
        tester.platformDispatcher.textScaleFactorTestValue = 1.35;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final d = await mount(tester, locale: locale, reduced: reduced);
        for (final size in sizes) {
          tester.view.physicalSize = size;
          await tester.pump();
          for (var index = 0; index < 5; index++) {
            final nav = find.byKey(ValueKey('nav-$index'));
            await tester.ensureVisible(nav);
            await tester.pump();
            await tester.tap(nav);
            await pumpJourney(tester);
            expect(
              index == 0
                  ? find.byType(JourneyPage)
                  : index == 1
                  ? find.byType(DiscoverPage)
                  : index == 2
                  ? find.byType(RaqeebPage)
                  : index == 4
                  ? find.byType(ProfilePage)
                  : find.byType(CommunityPage),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull, reason: '$size / $locale / $index');
            final scaffold = tester.widget<Scaffold>(find.descendant(of: find.byType(HomeShell), matching: find.byType(Scaffold)).first);
            expect(scaffold.bottomNavigationBar == null, size.width >= 840);
            final shellRect = tester.getRect(find.byType(HomeShell));
            expect(shellRect.width, size.width);
          }
        }
        final element = tester.element(find.byType(ProfilePage));
        expect(Directionality.of(element), locale == 'ar' ? TextDirection.rtl : TextDirection.ltr);
        final preserved = tester.state(find.byType(ProfilePage));
        tester.view.physicalSize = sizes.first;
        await pumpJourney(tester);
        expect(identical(preserved, tester.state(find.byType(ProfilePage))), true);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(d.dispose);
        await pumpJourney(tester);
      });
    }
  }
  testWidgets('Profile long press opens menu; language and companion settings apply globally', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final d = await mount(tester);
    await tester.tap(find.byKey(const ValueKey('nav-4')));
    await pumpJourney(tester);
    expect(
      tester.element(find.byType(ProfilePage)).read<ProfileBloc>().state.snapshot,
      isNotNull,
      reason: '${tester.element(find.byType(ProfilePage)).read<ProfileBloc>().state.failure}',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('profile-avatar')));
    await tester.longPress(find.byKey(const ValueKey('profile-avatar')));
    await pumpJourney(tester);
    expect(find.byType(DevToolsPage), findsOneWidget);
    final ar = find.text('العربية');
    await tester.ensureVisible(ar);
    await tester.pump();
    await tester.tap(ar);
    await pumpJourney(tester);
    expect(d.locale.state.language, 'ar');
    expect(Directionality.of(tester.element(find.byType(DevToolsPage))), TextDirection.rtl);
    expect(tester.takeException(), isNull);
    for (final size in sizes) {
      tester.view.physicalSize = size;
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'Dev menu $size');
    }
    await d.preferences.preferencesChanged(const LocalPreferences(companionEnabled: false, reduceMotion: true));
    await tester.pump();
    expect(d.characters.state.enabled, false);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(d.dispose);
    await pumpJourney(tester);
  });
  testWidgets('Missing Rive asset shows flame, disabled character removes it', (tester) async {
    final d = await mount(tester);
    expect(find.byType(CharacterView), findsWidgets);
    expect(find.byType(FlameMark), findsWidgets);
    await d.preferences.preferencesChanged(const LocalPreferences(companionEnabled: false));
    await pumpJourney(tester);
    expect(find.descendant(of: find.byType(CharacterView), matching: find.byType(FlameMark)), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(d.dispose);
    await pumpJourney(tester);
  });
}
