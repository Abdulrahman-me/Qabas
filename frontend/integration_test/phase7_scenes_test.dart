import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:qabas/app/app.dart';
import 'package:qabas/app/config/app_config.dart';
import 'package:qabas/app/di/injector.dart';
import 'package:qabas/core/design_system/components/journey_node.dart';
import 'package:qabas/core/network/media_resolver.dart';
import 'package:qabas/core/network/scene_media_loader.dart';
import 'package:qabas/core/storage/preferences_store.dart';
import 'package:qabas/core/storage/token_store.dart';
import 'package:qabas/features/auth/domain/repositories/auth_repository.dart';
import 'package:qabas/features/auth/presentation/bloc/app_session_bloc.dart';
import 'package:qabas/features/journey/presentation/bloc/journey_bloc.dart';
import 'package:qabas/features/journey/presentation/pages/journey_page.dart';
import 'package:qabas/features/onboarding/domain/entities/onboarding_answers.dart';
import 'package:qabas/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:qabas/features/session/domain/entities/session.dart';
import 'package:qabas/features/session/presentation/bloc/lesson_intro_bloc.dart';
import 'package:qabas/features/session/presentation/bloc/session_player_bloc.dart';
import 'package:qabas/features/session/presentation/pages/lesson_intro_page.dart';
import 'package:qabas/features/session/presentation/pages/session_player_page.dart';
import 'package:qabas/features/session/presentation/steps/content_step_views.dart';
import 'package:qabas/mock_backend/mock_backend.dart';
import 'package:qabas_scene/qabas_scene.dart';

Future<void> until(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 200 && !ready(); i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  if (!ready()) {
    final players = find.byType(SessionPlayerPage).evaluate();
    debugPrint(
      'Scene tour readiness: intro=${find.byType(LessonIntroPage).evaluate().length}, player=${players.length}, scenes=${find.byType(SceneView).evaluate().length}',
    );
    if (players.isNotEmpty) {
      final state = players.last.read<SessionPlayerBloc>().state;
      debugPrint('Scene tour player: ${state.status}, item=${state.item.runtimeType}, failure=${state.failure.runtimeType}');
    }
  }
  expect(ready(), true);
  expect(tester.takeException(), isNull);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const tour = String.fromEnvironment('PHASE7_TOUR', defaultValue: 'all');
  Future<void> capture(String name) async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Android 17's integration screenshot image conversion stalls with
      // external Rive textures. The host helper captures the actual adb surface.
      debugPrint('PHASE7_CAPTURE:$name');
      await Future<void>.delayed(const Duration(milliseconds: 700));
    } else {
      await binding.takeScreenshot(name);
    }
  }

  if (tour != 'flow') {
    testWidgets('All 20 native scenes: cold first frame and steady frame timings', (t) async {
      final previousPolicy = binding.framePolicy;
      binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
      addTearDown(() => binding.framePolicy = previousPolicy);
      final loader = SceneMediaLoader(MediaResolver(AppConfig())), cache = SceneCache(loadBytes: loader.load);
      final index = jsonDecode(await rootBundle.loadString('assets/mocks/unit0/MEDIA_INDEX.json')) as Map;
      final reports = <Map<String, Object>>[];
      // Exclude the empty application's engine/scaffold startup from the media
      // first-frame measurement; each manifest is still cold in the scene cache.
      await t.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox.shrink())));
      await Future<void>.delayed(const Duration(seconds: 1));
      for (final row in (index['scenes'] as List).cast<Map>()) {
        final raw = await rootBundle.load('assets/mocks/unit0/${row['path']}');
        final manifest = SceneManifest.decode(raw.buffer.asUint8List(raw.offsetInBytes, raw.lengthInBytes));
        final descriptor = SceneDescriptor(
          sceneId: manifest.sceneId,
          version: manifest.version,
          schemaVersion: 'qabas.scene/1',
          url: 'http://localhost:8765/${row['path']}',
          sha256: row['sha256'] as String,
          width: manifest.width,
          height: manifest.height,
          mimeType: 'application/json',
          requiredCapabilities: manifest.capabilities.toList(),
        );
        final watch = Stopwatch()..start();
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 360,
                  height: 225,
                  child: SceneView(
                    key: ValueKey(manifest.sceneId),
                    descriptor: descriptor,
                    cache: cache,
                    params: const {},
                    reducedMotion: false,
                    alt: manifest.sceneId,
                    fallback: const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
        );
        await until(t, () => t.state<SceneViewState>(find.byType(SceneView)).engine != null);
        await t.pump(const Duration(milliseconds: 16));
        watch.stop();
        final frames = <FrameTiming>[];
        void timings(List<FrameTiming> batch) => frames.addAll(batch);
        // Warm shaders/paint before measuring a steady scene. Debug emulator
        // timings are evidence about this environment, never a reference-device claim.
        await Future<void>.delayed(const Duration(milliseconds: 500));
        SchedulerBinding.instance.addTimingsCallback(timings);
        // Let the fully-live binding paint naturally. Forced test pumps can
        // delay a frame's build interval and distort native performance data.
        await Future<void>.delayed(const Duration(seconds: 2));
        await Future<void>.delayed(const Duration(milliseconds: 150));
        SchedulerBinding.instance.removeTimingsCallback(timings);
        expect(frames, isNotEmpty);
        final totals = frames.map((f) => (f.buildDuration.inMicroseconds + f.rasterDuration.inMicroseconds) / 1000).toList()..sort();
        final builds = frames.map((f) => f.buildDuration.inMicroseconds / 1000).toList()..sort();
        final rasters = frames.map((f) => f.rasterDuration.inMicroseconds / 1000).toList()..sort();
        reports.add({
          'scene_id': manifest.sceneId,
          'cold_load_to_first_frame_ms': watch.elapsedMicroseconds / 1000,
          'frames': frames.length,
          'p95_build_plus_raster_ms': totals[(totals.length * 0.95).ceil() - 1],
          'p95_build_ms': builds[(builds.length * 0.95).ceil() - 1],
          'p95_raster_ms': rasters[(rasters.length * 0.95).ceil() - 1],
          'max_build_plus_raster_ms': totals.last,
        });
      }
      binding.reportData ??= <String, dynamic>{};
      binding.reportData!['scene_benchmarks'] = {
        'renderer': sceneRendererVersion,
        'mode': kDebugMode
            ? 'debug'
            : kProfileMode
            ? 'profile'
            : 'release',
        'platform': defaultTargetPlatform.name,
        'scenes': reports,
      };
      debugPrint('Scene timing report: ${jsonEncode(binding.reportData!['scene_benchmarks'])}');
      await t.pumpWidget(const SizedBox.shrink());
      cache.clear();
      loader.dispose();
    });
  }
  if (tour == 'benchmark') return;
  for (final language in ['en', 'ar']) {
    for (final reduced in [false, true]) {
      testWidgets('Ordinary mock lesson 0.1: live hook and teach scenes $language/$reduced', (t) async {
        final store = await PreferencesStore.open();
        await store.clear();
        await store.setString('language', language);
        await store.setBoolean('reduce_motion', reduced);
        final d = await AppDependencies.create(
          config: AppConfig(),
          store: store,
          initialSessionState: const AppSessionState(status: SessionStatus.ready, splashElapsed: true),
        );
        addTearDown(() async {
          await t.pumpWidget(const SizedBox.shrink());
          await d.dispose();
        });
        await d.services<TokenStore>().clear();
        d.services<MockBackend>().controls.fast = true;
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
        await t.pumpWidget(QabasApp(dependencies: d));
        await until(
          t,
          () =>
              find.byType(JourneyPage).evaluate().isNotEmpty &&
              t.element(find.byType(JourneyPage)).read<JourneyBloc>().state.journey != null,
        );
        await t.pump(const Duration(milliseconds: 600));
        final node = find.byWidgetPredicate((w) => w is QJourneyNode && w.node.id == 'les_u0_l1');
        await Scrollable.ensureVisible(t.element(node), alignment: .42);
        await t.pump();
        await t.tap(node);
        await until(t, () => find.byKey(const ValueKey('node-start-les_u0_l1')).evaluate().isNotEmpty);
        await t.tap(find.byKey(const ValueKey('node-start-les_u0_l1')));
        await until(
          t,
          () =>
              find.byType(LessonIntroPage).evaluate().isNotEmpty &&
              t.element(find.byType(LessonIntroPage)).read<LessonIntroBloc>().state.status == LessonIntroStatus.ready,
        );
        await t.pump(const Duration(milliseconds: 600));
        await t.tap(find.byKey(const ValueKey('lesson-start')));
        await until(
          t,
          () =>
              find.byType(SessionPlayerPage).evaluate().isNotEmpty &&
              t.element(find.byType(SessionPlayerPage)).read<SessionPlayerBloc>().state.session != null,
        );
        final player = t.element(find.byType(SessionPlayerPage)).read<SessionPlayerBloc>();
        // Mock development mode prepends the authored draft-notice callout.
        while (player.state.item is CalloutItem) {
          await t.pump(const Duration(milliseconds: 600));
          final cursor = player.state.cursor;
          await t.tap(find.byKey(const ValueKey('step-cta')));
          await until(t, () => player.state.cursor != cursor);
        }
        await until(
          t,
          () => find.byType(SceneView).evaluate().isNotEmpty && t.state<SceneViewState>(find.byType(SceneView).last).engine != null,
        );
        final prefix = 'phase7/${defaultTargetPlatform.name}_${language}_${reduced ? 'reduced' : 'motion'}';
        for (var frame = 0; frame < 60; frame++) {
          await t.pump(const Duration(milliseconds: 16));
        }
        await capture('${prefix}_hook');
        var captures = 0;
        // The first authored exercise ends this content-only scene tour.
        for (var n = 0; n < 30 && captures < 8; n++) {
          if (find.byKey(const ValueKey('exercise-cta')).evaluate().isNotEmpty) break;
          if (find.byKey(const ValueKey('predict-option-1')).evaluate().isNotEmpty && player.state.status != PlayerStatus.feedback) {
            await t.tap(find.byKey(const ValueKey('predict-option-1')));
            await t.pump();
          }
          final action = find.byKey(ValueKey(player.state.status == PlayerStatus.feedback ? 'predict-continue' : 'step-cta'));
          await t.tap(action);
          await t.pump(const Duration(milliseconds: 600));
          if (find.byType(SceneView).evaluate().isNotEmpty) {
            final state = t.state<SceneViewState>(find.byType(SceneView).last);
            await until(t, () => state.engine != null);
            await Scrollable.ensureVisible(t.element(find.byType(SceneView).last));
            for (var frame = 0; frame < 60; frame++) {
              await t.pump(const Duration(milliseconds: 16));
            }
            expect(state.running, !reduced);
            if (reduced) expect(state.frame!.timeMs, state.engine!.manifest.stillTimeMs);
            if (find.byType(StoryStepView).evaluate().isNotEmpty || find.byType(TeachStepView).evaluate().isNotEmpty) {
              await capture('${prefix}_state${captures++}');
            }
          }
          expect(t.takeException(), isNull);
        }
        expect(captures, greaterThan(0));
      });
    }
  }
}
