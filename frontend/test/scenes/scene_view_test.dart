import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/network/media_resolver.dart';
import 'package:qabas/features/session/data/dtos/session_dto.dart';
import 'package:qabas/features/session/data/mappers/session_mappers.dart';
import 'package:qabas/features/session/domain/entities/session.dart';
import 'package:qabas/l10n/gen/app_localizations.dart';
import 'package:qabas/shared/domain/entities/content.dart';
import 'package:qabas/shared/presentation/visuals/visual_view.dart';
import 'package:qabas_scene/qabas_scene.dart';

import '../features/journey/journey_responsive_test.dart' show journeySizes;
import '../support/scene_test_assets.dart';

Future<Map<String, dynamic>> fixture(String path) async {
  if (!kIsWeb) return jsonDecode(await rootBundle.loadString('assets/mocks/$path')) as Map<String, dynamic>;
  final client = Dio();
  try {
    return (await client.get<Map<String, dynamic>>('http://localhost:8284/mock_fixture/$path')).data!;
  } finally {
    client.close();
  }
}

Future<SceneVisual> exampleVisual([String lesson = '01']) async =>
    (SessionDto.fromJson(
          await fixture('unit0/sessions/session_u0_l${lesson}_en_explorer.json'),
        ).toEntity().items.whereType<HookItem>().first.visual
        as SceneVisual);
Widget surface(
  SceneVisual visual,
  SceneCache cache, {
  String language = 'en',
  bool reduced = false,
  bool ticking = true,
  Map<String, Object?>? params,
  bool scrolling = false,
  bool allowOutgoing = true,
}) => MaterialApp(
  locale: Locale(language),
  theme: QTheme.light(arabic: language == 'ar'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: QMotionScope(
    reduceMotion: reduced,
    child: TickerMode(
      enabled: ticking,
      child: Scaffold(
        body: VisualMediaScope(
          scenes: cache,
          resolve: (url) => kIsWeb
              ? RemoteMedia(Uri.parse('http://localhost:8284/mock_media/unit0/${Uri.parse(url).path.substring(1)}'))
              : AssetMedia('assets/mocks/unit0/${Uri.parse(url).path.substring(1)}'),
          child: VisualCrossfadeScope(
            allowOutgoing: allowOutgoing,
            child: scrolling
                ? SingleChildScrollView(
                    child: Column(
                      children: [
                        VisualView(visual, use: VisualUse.hook, params: params),
                        const SizedBox(height: 1200),
                      ],
                    ),
                  )
                : Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: VisualView(visual, use: VisualUse.hook, params: params),
                    ),
                  ),
          ),
        ),
      ),
    ),
  ),
);
SceneViewState viewState(WidgetTester tester) => tester.state<SceneViewState>(find.byType(SceneView));
Future<void> loaded(WidgetTester tester) async {
  for (var i = 0; i < 100 && viewState(tester).engine == null; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
  }
  expect(viewState(tester).engine, isNotNull);
  await tester.pump();
}

void main() {
  for (final language in ['en', 'ar']) {
    for (final reduced in [false, true]) {
      testWidgets('live scene keeps state, clock and unmirrored geometry across all resizes: $language/$reduced', (t) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = const Size(402, 874);
        t.platformDispatcher.textScaleFactorTestValue = 1.35;
        addTearDown(t.view.resetDevicePixelRatio);
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        final visual = (await t.runAsync(exampleVisual))!, cache = sceneTestCache();
        await t.pumpWidget(surface(visual, cache, language: language, reduced: reduced));
        await loaded(t);
        final state = viewState(t), initialTime = state.clockMs;
        await t.pump(const Duration(milliseconds: 300));
        expect(state.clockMs, reduced ? initialTime : greaterThan(initialTime));
        await t.pumpWidget(surface(visual, cache, language: language, reduced: reduced, params: {'beat': 2}));
        expect(identical(viewState(t), state), true);
        expect(state.engine!.state['beat'], 2);
        for (final size in journeySizes) {
          t.view.physicalSize = size;
          await t.pump(const Duration(milliseconds: 600));
          expect(identical(viewState(t), state), true);
          expect(state.engine!.state['beat'], 2);
          expect(t.takeException(), isNull);
          expect(find.ancestor(of: find.byType(SceneView), matching: find.byType(Transform)), findsNothing);
          expect(t.getRect(find.byType(SceneView)).width, lessThanOrEqualTo(560));
        }
        expect(state.frame!.timeMs, reduced ? state.engine!.manifest.stillTimeMs : state.clockMs);
        await t.pumpWidget(const SizedBox.shrink());
        cache.clear();
      });
    }
  }
  testWidgets('same scene retargets authored transitions; reduced motion applies targets instantly', (t) async {
    final visual = (await t.runAsync(exampleVisual))!, cache = sceneTestCache();
    await t.pumpWidget(surface(visual, cache));
    await loaded(t);
    final state = viewState(t), manifest = state.engine!.manifest;
    final changing = manifest.allLayers.firstWhere((l) => l.rules.any((r) => r.durationMs > 0 && r.set.containsKey('opacity')));
    await t.pumpWidget(surface(visual, cache, params: {'beat': 3}));
    await t.pump(const Duration(milliseconds: 150));
    expect(identical(viewState(t), state), true);
    final after = state.frame!.layers[changing.id]!.opacity;
    expect(after, greaterThan(0));
    expect(after, lessThan(1));
    await t.pumpWidget(surface(visual, cache, reduced: true, params: {'beat': 1}));
    expect(state.running, false);
    expect(state.frame!.timeMs, manifest.stillTimeMs);
    final expected = SceneEngine(manifest, params: {'beat': 1}).frame(0, reducedMotion: true);
    for (final entry in expected.layers.entries) {
      expect(state.frame!.layers[entry.key]!.opacity, entry.value.opacity);
    }
    await t.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('rapid scene replacement bounds mounted renderers and yields the outgoing slot to an outer fade', (t) async {
    final visuals = (await t.runAsync(() => Future.wait(['01', '02', '03'].map(exampleVisual))))!, cache = sceneTestCache();
    // Warm the same verified cache used by the real media widget.
    for (final visual in visuals) {
      await t.pumpWidget(surface(visual, cache));
      await t.pump(const Duration(seconds: 1));
      await loaded(t);
    }
    await t.pumpWidget(surface(visuals[0], cache));
    await t.pump(const Duration(seconds: 1));
    await t.pumpWidget(surface(visuals[1], cache));
    await t.pump(const Duration(milliseconds: 30));
    expect(find.byType(SceneView), findsNWidgets(2));
    await t.pumpWidget(surface(visuals[2], cache));
    await t.pump(const Duration(milliseconds: 30));
    expect(find.byType(SceneView), findsNWidgets(2));
    final current = t.state<SceneViewState>(find.byType(SceneView).last);
    await t.pumpWidget(surface(visuals[2], cache, allowOutgoing: false));
    await t.pump();
    expect(find.byType(SceneView), findsOneWidget);
    expect(identical(viewState(t), current), true);
    await t.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('TickerMode, lifecycle and scroll visibility pause/resume the scene clock', (t) async {
    final visual = (await t.runAsync(exampleVisual))!, cache = sceneTestCache();
    await t.pumpWidget(surface(visual, cache));
    await loaded(t);
    final state = viewState(t);
    await t.pump(const Duration(milliseconds: 300));
    await t.pumpWidget(surface(visual, cache, ticking: false));
    final paused = state.clockMs;
    await t.pump(const Duration(seconds: 5));
    expect(state.clockMs, paused);
    expect(state.running, false);
    await t.pumpWidget(surface(visual, cache));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(state.clockMs, closeTo(paused + 100, 1));
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    final suspended = state.clockMs;
    await t.pump(const Duration(seconds: 5));
    expect(state.clockMs, suspended);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pump();
    await t.pumpWidget(surface(visual, cache, scrolling: true));
    await loaded(t);
    await t.drag(find.byType(SingleChildScrollView), const Offset(0, -900));
    await t.pump(const Duration(seconds: 1));
    await t.pump();
    final offscreen = viewState(t).clockMs;
    expect(viewState(t).running, false);
    await t.pump(const Duration(seconds: 2));
    expect(viewState(t).clockMs, offscreen);
    await t.drag(find.byType(SingleChildScrollView), const Offset(0, 1200));
    await t.pump(const Duration(seconds: 1));
    await t.pump();
    expect(viewState(t).running, true);
    await t.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('unknown capability, checksum, missing/invalid manifest and invalid params show fallback', (t) async {
    final visual = (await t.runAsync(exampleVisual))!;
    for (final mode in ['capability', 'checksum', 'missing', 'invalid', 'params']) {
      final ref = visual.scene;
      final descriptor = SceneDescriptor(
        sceneId: ref.sceneId,
        version: ref.version,
        schemaVersion: ref.schemaVersion,
        url: ref.url,
        sha256: mode == 'checksum' ? List.filled(64, '0').join() : ref.sha256,
        width: ref.width,
        height: ref.height,
        mimeType: ref.mimeType,
        requiredCapabilities: mode == 'capability' ? [...ref.requiredCapabilities, 'clip/1'] : ref.requiredCapabilities,
      );
      final cache = SceneCache(
        loadBytes: (url) => mode == 'missing'
            ? Future.error(StateError('Missing'))
            : mode == 'invalid'
            ? Future.value(Uint8List.fromList([1]))
            : sceneTestBytes(url),
      );
      await t.pumpWidget(
        MaterialApp(
          home: SceneView(
            key: ValueKey(mode),
            descriptor: descriptor,
            cache: cache,
            params: mode == 'params' ? {'unknown': 1} : {},
            reducedMotion: false,
            alt: visual.alt,
            fallback: const Text('Fallback image'),
          ),
        ),
      );
      for (var i = 0; i < 30; i++) {
        await t.pump();
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 2)));
      }
      expect(find.text('Fallback image'), findsOneWidget);
      expect(viewState(t).running, false);
      expect(t.takeException(), isNull);
      if (mode == 'params') {
        await t.pumpWidget(
          MaterialApp(
            home: SceneView(
              key: ValueKey(mode),
              descriptor: descriptor,
              cache: cache,
              params: const {},
              reducedMotion: false,
              alt: visual.alt,
              fallback: const Text('Fallback image'),
            ),
          ),
        );
        await loaded(t);
        expect(find.text('Fallback image'), findsNothing);
      }
    }
    await t.pumpWidget(const SizedBox.shrink());
  });
}
