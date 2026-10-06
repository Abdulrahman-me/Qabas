import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/network/media_resolver.dart';
import 'package:qabas/l10n/gen/app_localizations.dart';
import 'package:qabas/shared/domain/entities/content.dart';
import 'package:qabas/shared/presentation/visuals/builtin/scenes.dart';
import 'package:qabas/shared/presentation/visuals/visual_view.dart';

class MedallionBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(
    Uint8List.fromList(
      utf8.encode('<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100"><circle cx="50" cy="50" r="45" fill="#d6a33e"/></svg>'),
    ),
  );
}

BuiltinVisual builtin(String key, {int version = 1, int beat = 0, List<VisualOverlay> overlays = const []}) => BuiltinVisual(
  key: key,
  version: version,
  params: {'beat': beat, 'highlight': 1},
  fallbackImage: null,
  alt: 'Visual unavailable',
  overlays: overlays,
);
Widget surface(Visual visual, {String language = 'en', bool reduced = false, VisualUse use = VisualUse.story}) => MaterialApp(
  locale: Locale(language),
  theme: QTheme.light(arabic: language == 'ar'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: QMotionScope(
    reduceMotion: reduced,
    child: Scaffold(
      body: Center(
        child: SizedBox(
          width: 300,
          child: DefaultAssetBundle(
            bundle: MedallionBundle(),
            child: VisualMediaScope(
              resolve: (url) => const AssetMedia('test.svg'),
              child: VisualView(visual, use: use),
            ),
          ),
        ),
      ),
    ),
  ),
);
void main() {
  testWidgets('same river keeps its renderer through beat changes; loops and reduced motion toggle', (t) async {
    await t.pumpWidget(surface(builtin('river_house')));
    await t.pump(const Duration(milliseconds: 100));
    final state = t.state(find.byType(RiverHouseScene));
    expect(t.binding.transientCallbackCount, greaterThan(0));
    await t.pumpWidget(surface(builtin('river_house', beat: 3)));
    await t.pump();
    expect(identical(t.state(find.byType(RiverHouseScene)), state), true);
    expect(t.widget<RiverHouseScene>(find.byType(RiverHouseScene)).beat, 3);
    await t.pumpWidget(surface(builtin('river_house', beat: 3), reduced: true));
    await t.pump(const Duration(seconds: 1));
    await t.pump();
    expect(t.binding.transientCallbackCount, 0);
    await t.pumpWidget(surface(builtin('river_house', beat: 3)));
    await t.pump();
    expect(t.binding.transientCallbackCount, greaterThan(0));
    await t.pumpWidget(const SizedBox.shrink());
  });
  for (final language in ['en', 'ar']) {
    testWidgets('SVG medallion follows directional anchor/percentage; pillar labels align $language', (t) async {
      const overlay = VisualOverlay(
        type: 'medallion',
        assetUrl: 'test.svg',
        label: 'Medallion',
        anchor: OverlayAnchor.topStart,
        sizePct: 20,
      );
      await t.pumpWidget(
        surface(
          builtin('pillars', overlays: [overlay]),
          language: language,
          reduced: true,
          use: VisualUse.teach,
        ),
      );
      await t.pump(const Duration(milliseconds: 100));
      expect(find.byType(SvgPicture), findsOneWidget);
      final svg = t.getRect(find.byType(SvgPicture));
      final art = t.getRect(find.byType(AspectRatio));
      expect(svg.width, 60);
      expect(svg.height, 60);
      expect(svg.top, art.top);
      expect(language == 'ar' ? svg.right : svg.left, language == 'ar' ? art.right : art.left);
      final flip = t.widget<Transform>(find.ancestor(of: find.byType(PillarsScene), matching: find.byType(Transform)).first);
      expect(flip.transform.entry(0, 0), language == 'ar' ? -1 : 1);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('per-use ratios and unknown builtin/version keep an accessible alt fallback', (t) async {
    for (final row in [
      (VisualUse.hook, 1.75, 'workplace'),
      (VisualUse.story, 1.5, 'river_house'),
      (VisualUse.teach, 1.9, 'pillars'),
      (VisualUse.teach, 2.1, 'day_arc'),
      (VisualUse.hotspots, 1.15, 'river_house'),
      (VisualUse.dayArc, 2.8, 'day_arc'),
      (VisualUse.block, 1.75, 'unreleased'),
    ]) {
      await t.pumpWidget(surface(builtin(row.$3), reduced: true, use: row.$1));
      await t.pump();
      expect(t.widget<AspectRatio>(find.byType(AspectRatio).first).aspectRatio, row.$2);
      expect(t.takeException(), isNull);
    }
    expect(find.text('Visual unavailable'), findsOneWidget);
    await t.pumpWidget(surface(builtin('river_house', version: 99), reduced: true));
    await t.pump();
    expect(find.byType(RiverHouseScene), findsNothing);
    expect(find.text('Visual unavailable'), findsOneWidget);
    await t.pumpWidget(const SizedBox.shrink());
  });
}
