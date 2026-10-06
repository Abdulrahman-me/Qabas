import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qabas/core/audio/sensory_service.dart';
import 'package:qabas/core/design_system/components/download_banner.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/l10n/gen/app_localizations.dart';

void main() {
  const sizes = [Size(320, 568), Size(320, 400), Size(600, 400), Size(839, 600), Size(840, 600), Size(1440, 900), Size(1920, 1080)];
  for (final locale in ['en', 'ar']) {
    for (final reduced in [false, true]) {
      testWidgets('download remains reachable during resize: $locale / $reduced', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = sizes.first;
        tester.platformDispatcher.textScaleFactorTestValue = 1.35;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        var downloaded = 0;
        var dismissed = false;
        final input = TextEditingController(text: 'retained journey state');
        addTearDown(input.dispose);
        await tester.pumpWidget(
          SensoryScope(
            service: SensoryService(settings: () => const SensorySettings(sound: false, haptics: false)),
            child: QMotionScope(
              reduceMotion: reduced,
              child: MaterialApp(
                locale: Locale(locale),
                theme: QTheme.light(arabic: locale == 'ar'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: StatefulBuilder(
                    builder: (context, setState) => QDownloadBannerFrame(
                      visible: !dismissed,
                      eyebrow: context.l10n.journeyDownloadEyebrow,
                      title: context.l10n.journeyDownloadTitle,
                      body: context.l10n.journeyDownloadBody,
                      action: context.l10n.journeyDownloadAction,
                      dismissLabel: context.l10n.journeyDownloadDismiss,
                      onDownload: () => downloaded++,
                      onDismiss: () => setState(() => dismissed = true),
                      child: Center(child: TextField(controller: input)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        for (final size in sizes) {
          tester.view.physicalSize = size;
          await tester.pump();
          final button = find.byKey(const ValueKey('android-download-action'));
          await tester.ensureVisible(button);
          await tester.pump();
          await tester.tap(button);
          await tester.pump();
          expect(tester.takeException(), isNull, reason: '$size / $locale');
          expect(input.text, 'retained journey state');
        }
        expect(downloaded, sizes.length);
        final close = find.byKey(const ValueKey('android-download-dismiss'));
        await tester.ensureVisible(close);
        await tester.pump();
        await tester.tap(close);
        await tester.pump();
        expect(find.byKey(const ValueKey('android-download-action')), findsNothing);
        tester.view.physicalSize = sizes.first;
        await tester.pump();
        expect(find.byKey(const ValueKey('android-download-action')), findsNothing);
        expect(input.text, 'retained journey state');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
