import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qabas/core/audio/sensory_service.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/features/dev_tools/presentation/component_gallery.dart';
import 'package:qabas/l10n/gen/app_localizations.dart';

void main() {
  const viewports = [Size(320, 568), Size(320, 400), Size(600, 400), Size(839, 600), Size(840, 600), Size(1440, 900), Size(1920, 1080)];
  for (final locale in ['en', 'ar']) {
    for (final reduced in [false, true]) {
      testWidgets('gallery resizes across web viewports: $locale / reduced=$reduced', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = viewports.first;
        tester.platformDispatcher.textScaleFactorTestValue = 1.35;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final settings = GallerySettings(locale: locale, reduceMotion: reduced);
        await tester.pumpWidget(FoundationApp(settings: settings));
        await tester.pump(const Duration(seconds: 2));
        var selectedSection = 0;
        for (final viewport in viewports) {
          tester.view.physicalSize = viewport;
          await tester.pump();
          expect(find.byKey(ValueKey('gallery-content-$selectedSection')), findsOneWidget);
          for (var section = 0; section < 7; section++) {
            final tab = find.byKey(ValueKey('gallery-section-$section'));
            await tester.ensureVisible(tab);
            await tester.pump();
            await tester.tap(tab);
            await tester.pump(const Duration(seconds: 2));
            selectedSection = section;
            final exception = tester.takeException();
            expect(
              exception,
              isNull,
              reason: '$viewport / section $section / ${exception is FlutterError ? exception.toStringDeep() : exception}',
            );
            if (section == 0) {
              final button = tester.getRect(find.byKey(const ValueKey('button-emerald')));
              expect(button.width, lessThanOrEqualTo(QBreakpoints.readingWidth));
              expect(button.center.dx, closeTo(viewport.width / 2, 0.1));
            }
            if (section == 6) {
              await tester.ensureVisible(find.byType(QButton).first);
              await tester.pump();
              await tester.tap(find.byType(QButton).first);
              await tester.pump();
              await tester.pump(const Duration(seconds: 1));
              expect(tester.takeException(), isNull, reason: '$viewport / sheet');
              final sheet = tester.getRect(find.byType(QConfirmSheet));
              expect(sheet.width, lessThanOrEqualTo(QBreakpoints.readingWidth));
              expect(sheet.center.dx, closeTo(viewport.width / 2, 0.1));
              final dismiss = find.descendant(of: find.byType(QConfirmSheet), matching: find.byType(QButton)).first;
              await tester.ensureVisible(dismiss);
              await tester.pump();
              await tester.tap(dismiss);
              await tester.pump();
              await tester.pump(const Duration(seconds: 1));
              expect(find.byType(QConfirmSheet), findsNothing);
            }
          }
        }
        await tester.pumpWidget(const SizedBox.shrink());
        settings.dispose();
      });
    }
    testWidgets('composer retains text and focus during web resize: $locale', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.35;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final controller = TextEditingController();
      var sent = '';
      await tester.pumpWidget(
        _harness(
          locale: locale,
          builder: (context) => Align(
            alignment: Alignment.bottomCenter,
            child: QComposerBar(
              controller: controller,
              hint: context.l10n.raqeebAskAnything,
              onSend: (text) => sent = text,
              onAttach: () {},
              onRecord: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      final message = locale == 'ar' ? 'سؤال يبقى محفوظًا عند تغيير حجم النافذة' : 'A question that stays while the window is resized';
      await tester.enterText(find.byType(TextField), message);
      for (final viewport in viewports.reversed) {
        tester.view.physicalSize = viewport;
        await tester.pump();
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.controller?.text, message);
        expect(field.controller?.selection, TextSelection.collapsed(offset: message.length));
        expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus, isTrue);
        final row = find.descendant(of: find.byType(QComposerBar), matching: find.byType(Row)).first;
        final rect = tester.getRect(row);
        expect(rect.width, lessThanOrEqualTo(QBreakpoints.composerMax));
        expect(rect.center.dx, closeTo(viewport.width / 2, 0.1));
        expect(tester.takeException(), isNull, reason: '$viewport / composer');
      }
      final send = find.widgetWithIcon(QIconButton, Icons.arrow_upward_rounded);
      await tester.tap(send);
      expect(sent, message);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    });
    testWidgets('sheet actions stay reachable above the web keyboard: $locale', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      var actionTaken = false;
      await tester.pumpWidget(
        _harness(
          locale: locale,
          builder: (context) => QButton(
            label: context.l10n.commonContinue,
            onPressed: () => showQSheet<void>(
              context,
              builder: (context) => QConfirmSheet(
                title: context.l10n.commonSessionEndedTitle,
                body: context.l10n.commonSessionEndedBody,
                primaryLabel: context.l10n.commonContinue,
                onPrimary: () {
                  actionTaken = true;
                  Navigator.pop(context);
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(QButton));
      await tester.pump();
      final action = find.descendant(of: find.byType(QConfirmSheet), matching: find.byType(QButton));
      await tester.ensureVisible(action);
      await tester.pump();
      expect(tester.getRect(action).bottom, lessThanOrEqualTo(368));
      await tester.tap(action);
      await tester.pump();
      expect(actionTaken, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

Widget _harness({required String locale, required WidgetBuilder builder}) => SensoryScope(
  service: SensoryService(settings: () => const SensorySettings(sound: false, haptics: false)),
  child: QMotionScope(
    reduceMotion: true,
    child: MaterialApp(
      locale: Locale(locale),
      theme: QTheme.light(arabic: locale == 'ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.35)),
        child: child!,
      ),
      home: Scaffold(body: Builder(builder: builder)),
    ),
  ),
);
