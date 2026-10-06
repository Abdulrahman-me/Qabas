import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/features/dev_tools/presentation/component_gallery.dart';

void main() {
  const groupFilter = int.fromEnvironment('GALLERY_GROUP', defaultValue: -1);
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  Future<void> clearPointers(WidgetTester tester) async {
    // Live-test pointer overlays decay by frame count, even with reduced motion.
    for (var frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  testWidgets('Phase 1 gallery: English, Arabic, motion and sheets on iPhone', (tester) async {
    final settings = GallerySettings();
    await tester.pumpWidget(FoundationApp(settings: settings));
    await tester.pump(const Duration(seconds: 2));
    for (final locale in ['en', 'ar']) {
      settings.languageChanged(locale);
      for (final reduced in [false, true]) {
        settings.motionChanged(reduced);
        await tester.pump();
        final mode = reduced ? 'reduced' : 'motion';
        for (var section = 0; section < 7; section++) {
          if (groupFilter >= 0 && section != groupFilter) continue;
          await tester.ensureVisible(find.byKey(ValueKey('gallery-section-$section')));
          await tester.pump();
          await tester.tap(find.byKey(ValueKey('gallery-section-$section')));
          await tester.pump(const Duration(seconds: 2));
          expect(tester.takeException(), isNull, reason: '$locale / $mode / section $section');
          await clearPointers(tester);
          await binding.takeScreenshot('phase1/${locale}_${mode}_group${section}_top');
          final scroll = find.descendant(of: find.byKey(ValueKey('gallery-content-$section')), matching: find.byType(Scrollable)).first;
          final position = tester.state<ScrollableState>(scroll).position;
          var page = 1;
          while (position.pixels < position.maxScrollExtent - 1) {
            position.jumpTo((position.pixels + 450).clamp(0, position.maxScrollExtent));
            await tester.pump(const Duration(seconds: 1));
            expect(tester.takeException(), isNull, reason: 'Scrolled $locale / $mode / section $section');
            await clearPointers(tester);
            await binding.takeScreenshot('phase1/${locale}_${mode}_group${section}_page${page++}');
          }
        }
        if (groupFilter < 0 || groupFilter == 6) {
          await tester.tap(find.byType(QButton).first);
          await tester.pump(const Duration(seconds: 1));
          expect(tester.takeException(), isNull);
          await clearPointers(tester);
          await binding.takeScreenshot('phase1/${locale}_${mode}_sheet');
          await tester.tap(find.descendant(of: find.byType(QConfirmSheet), matching: find.byType(QButton)).first);
          await tester.pump(const Duration(seconds: 1));
        }
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
    settings.dispose();
  });
}
