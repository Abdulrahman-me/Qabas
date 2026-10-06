import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:qabas/app/app.dart';
import 'package:qabas/app/config/app_config.dart';
import 'package:qabas/app/di/injector.dart';
import 'package:qabas/core/characters/character_asset_cache.dart';
import 'package:qabas/core/characters/character_spec.dart';
import 'package:qabas/core/characters/character_view.dart';
import 'package:qabas/core/characters/character_vocabulary.dart';
import 'package:qabas/core/characters/rig/rive_character_rig.dart';
import 'package:qabas/core/characters/specs/guide_traveler.dart';
import 'package:qabas/core/storage/token_store.dart';
import 'package:qabas/features/auth/presentation/bloc/app_session_bloc.dart';
import 'package:qabas/features/dev_tools/presentation/bloc/dev_tools_bloc.dart';
import 'package:qabas/features/dev_tools/presentation/pages/dev_tools_page.dart';
import 'package:qabas/shared/domain/entities/local_preferences.dart';
import 'package:qabas/shared/presentation/brand/brand.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/support/fakes.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  Future<void> screenshot(WidgetTester tester, String name) async {
    // The live test runner's touch indicators fade by rendered frame count.
    for (var frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await binding.takeScreenshot(name);
  }

  testWidgets('Bundled companion contract: shared file, independent rigs, moods, seven cues, pause', (tester) async {
    final cache = CharacterAssetCache();
    final spec = guideTraveler.rig as RiveRigSpec;
    final file = await cache.load(spec);
    expect(file, isNotNull);
    expect(identical(file, await cache.load(spec)), true);
    final first = RiveCharacterRig(spec: guideTraveler, cache: cache), second = RiveCharacterRig(spec: guideTraveler, cache: cache);
    expect(await first.attach(), true);
    expect(await second.attach(), true);
    expect(first.contractValid, true);
    expect(second.contractValid, true);
    expect(first.availableCues, CharacterCue.values.toSet());
    first.setMood(CharacterMood.thinking);
    expect(first.currentMood, 'thinking');
    expect(second.currentMood, 'idle');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(width: 200, height: 200, child: Builder(builder: (context) => first.build(context, const CharacterLayout()))),
          ),
        ),
      ),
    );
    for (final cue in CharacterCue.values) {
      first.fire(cue);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    }
    first.setMood(CharacterMood.idle);
    expect(first.currentMood, 'idle');
    first.setPaused(true);
    expect(first.paused, true);
    await tester.pump(const Duration(seconds: 1));
    first.setPaused(false);
    expect(first.paused, false);
    await tester.pumpWidget(const SizedBox.shrink());
    first.dispose();
    second.dispose();
    await cache.dispose();
  });
  testWidgets('Mock shell, avatar gesture, English/Arabic developer cues, reduced motion and gallery', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final dependencies = await AppDependencies.create(
      config: AppConfig(),
      initialSessionState: const AppSessionState(status: SessionStatus.ready, splashElapsed: true),
    );
    await dependencies.services<TokenStore>().clear();
    await tester.pumpWidget(QabasApp(dependencies: dependencies));
    await tester.pump(const Duration(seconds: 2));
    for (final language in ['en', 'ar']) {
      await dependencies.locale.languageChanged(language);
      await dependencies.preferences.preferencesChanged(const LocalPreferences());
      await tester.pump(const Duration(seconds: 1));
      final nav = find.byKey(const ValueKey('nav-0'));
      await tester.ensureVisible(nav);
      await tester.pump();
      await tester.tap(nav);
      await tester.pump(const Duration(seconds: 1));
      await screenshot(tester, 'phase2/${language}_journey');
      await tester.tap(find.byKey(const ValueKey('nav-4')));
      await tester.pump(const Duration(seconds: 1));
      await screenshot(tester, 'phase2/${language}_profile');
      await tester.longPress(find.byKey(const ValueKey('profile-avatar')));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(DevToolsPage), findsOneWidget);
      final probe = find.byKey(const ValueKey('dev-probe'));
      await tester.ensureVisible(probe);
      await tester.pump();
      await tester.tap(probe);
      await tester.pump(const Duration(seconds: 3));
      final bloc = tester.element(find.byType(DevToolsPage));
      final state = BlocProvider.of<DevToolsBloc>(bloc).state;
      expect(state.status, DevToolsStatus.ready);
      expect(state.snapshot?.probeClient, 'ios/1.0.0');
      expect(state.snapshot?.probeContract, '10');
      expect(state.snapshot?.probeLanguage, language);
      expect(await dependencies.services<TokenStore>().read(), startsWith('mock_'));
      for (final cue in CharacterCue.values) {
        final button = find.byKey(ValueKey('character-cue-${cue.name}'));
        await tester.ensureVisible(button);
        await tester.pump();
        await tester.tap(button);
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
      }
      await screenshot(tester, 'phase2/${language}_developer_characters');
      await dependencies.preferences.preferencesChanged(const LocalPreferences(reduceMotion: true));
      await tester.pump(const Duration(seconds: 1));
      final cue = find.byKey(const ValueKey('character-cue-celebrate'));
      await tester.ensureVisible(cue);
      await tester.pump();
      await tester.tap(cue);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      final gallery = find.byKey(const ValueKey('dev-gallery'));
      await tester.ensureVisible(gallery);
      await tester.pump();
      await tester.tap(gallery);
      await tester.pump(const Duration(seconds: 1));
      await tester.ensureVisible(find.byKey(const ValueKey('gallery-section-3')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('gallery-section-3')));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(CharacterView), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('gallery-back')));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byKey(const ValueKey('developer-back')));
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await dependencies.services<TokenStore>().clear();
    await dependencies.dispose();
  });
  testWidgets('Missing character file falls back to a quiet flame', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final cache = CharacterAssetCache(loader: (_) async => null);
    final dependencies = await AppDependencies.create(
      config: AppConfig(),
      initialSessionState: const AppSessionState(status: SessionStatus.ready, splashElapsed: true),
      cache: cache,
      tokens: MemoryTokens(),
    );
    await tester.pumpWidget(QabasApp(dependencies: dependencies));
    await tester.pump(const Duration(seconds: 1));
    expect(find.descendant(of: find.byType(CharacterView), matching: find.byType(FlameMark)), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await dependencies.dispose();
  });
}
