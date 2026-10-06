import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/shared/presentation/brand/brand.dart';

import 'components_test.dart' show pump;

void main() {
  for (final locale in ['en', 'ar']) {
    for (final reduced in [false, true]) {
      for (final tone in QTone.values) {
        testWidgets('$locale $reduced $tone loading stays bounded during resize', (tester) async {
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          tester.view.physicalSize = const Size(1440, 900);
          await pump(
            tester,
            (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.35)),
              child: QLoadingView(tone: tone),
            ),
            locale: locale,
            reduced: reduced,
          );
          final position = tester.getCenter(find.byType(FlameMark));
          await tester.pump(QMotion.loadingLabelDelay);
          await tester.pump(QMotion.normal);
          expect(tester.getCenter(find.byType(FlameMark)), position);
          for (final size in [
            const Size(320, 568),
            const Size(320, 400),
            const Size(600, 400),
            const Size(839, 600),
            const Size(840, 600),
            const Size(1440, 900),
            const Size(1920, 1080),
          ]) {
            tester.view.physicalSize = size;
            await tester.pump();
            expect(tester.takeException(), isNull);
            final flame = tester.getRect(find.byType(FlameMark));
            expect(flame.left, greaterThanOrEqualTo(0));
            expect(flame.right, lessThanOrEqualTo(size.width));
          }
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  }
}
