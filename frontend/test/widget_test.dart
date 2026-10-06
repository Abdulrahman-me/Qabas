import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qabas/features/dev_tools/presentation/component_gallery.dart';

void main() {
  testWidgets('gallery switches its language and reduced motion immediately', (tester) async {
    final settings = GallerySettings();
    await tester.pumpWidget(FoundationApp(settings: settings));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Component gallery'), findsOneWidget);
    settings.languageChanged('ar');
    settings.motionChanged(true);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('معرض المكوّنات'), findsOneWidget);
    expect(Directionality.of(tester.element(find.text('معرض المكوّنات'))), TextDirection.rtl);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    settings.dispose();
  });
  for (final locale in ['en', 'ar']) {
    for (final reduced in [false, true]) {
      testWidgets('every gallery group at scale 1.35: $locale / reduced=$reduced', (tester) async {
        tester.view.physicalSize = const Size(402, 874);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 1.35;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final settings = GallerySettings(locale: locale, reduceMotion: reduced);
        await tester.pumpWidget(FoundationApp(settings: settings));
        await tester.pump(const Duration(seconds: 2));
        for (var section = 0; section < 7; section++) {
          await tester.ensureVisible(find.byKey(ValueKey('gallery-section-$section')));
          await tester.pump();
          await tester.tap(find.byKey(ValueKey('gallery-section-$section')));
          await tester.pump(const Duration(seconds: 2));
          expect(tester.takeException(), isNull, reason: 'Gallery section $section');
        }
        await tester.pumpWidget(const SizedBox.shrink());
        settings.dispose();
      });
    }
  }
}
