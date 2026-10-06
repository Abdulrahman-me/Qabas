import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qabas/core/audio/sensory_service.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/l10n/gen/app_localizations.dart';
import 'package:qabas/shared/presentation/brand/brand.dart';
import 'package:qabas/shared/presentation/brand/lantern.dart';
import 'package:qabas/shared/presentation/brand/unit_art.dart';
import 'package:qabas/shared/presentation/visuals/builtin/scenes.dart';

Future<void> pump(WidgetTester tester, WidgetBuilder builder, {String locale = 'en', bool reduced = false}) async {
  await tester.pumpWidget(
    SensoryScope(
      service: SensoryService(settings: () => const SensorySettings(sound: false, haptics: false)),
      child: QMotionScope(
        reduceMotion: reduced,
        child: MaterialApp(
          locale: Locale(locale),
          theme: QTheme.light(arabic: locale == 'ar'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(body: Builder(builder: builder)),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  for (final locale in ['en', 'ar']) {
    for (final tone in QButtonTone.values) {
      testWidgets('$locale ${tone.name} press depth, semantics and disabled state', (tester) async {
        var taps = 0;
        await pump(
          tester,
          (_) => Center(
            child: SizedBox(
              width: 300,
              child: QButton(label: 'Continue', tone: tone, onPressed: () => taps++),
            ),
          ),
          locale: locale,
        );
        final button = find.byType(QButton);
        final node = tester.getSemantics(button);
        expect(node.getSemanticsData().label, 'Continue');
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
        expect(tester.getSize(button).height, greaterThanOrEqualTo(QSizes.tapTarget));
        final press = await tester.startGesture(tester.getCenter(button));
        await tester.pump(const Duration(milliseconds: 150));
        expect(tester.widget<AnimatedPositioned>(find.byType(AnimatedPositioned)).top, tone == QButtonTone.ghost ? 0 : 4);
        await press.up();
        await tester.pump(const Duration(milliseconds: 150));
        expect(taps, 1);
        await pump(
          tester,
          (_) => Center(
            child: SizedBox(
              width: 300,
              child: QButton(label: 'Continue', tone: tone),
            ),
          ),
          locale: locale,
        );
        await tester.tap(find.byType(QButton));
        expect(taps, 1);
        expect(tester.getSemantics(find.byType(QButton)).getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
        expect(tester.widget<AnimatedPositioned>(find.byType(AnimatedPositioned)).top, 0);
      });
    }
    testWidgets('$locale surfaces and RTL progress', (tester) async {
      await pump(
        tester,
        (_) => SingleChildScrollView(
          child: Column(
            children: [
              const QCard(child: Text('Card')),
              SectionHeader('Section', action: 'Open', onAction: () {}),
              const Tag('Explorer', icon: Icons.explore_rounded),
              StatChip(leading: const StreakFlame(), value: '3', onTap: () {}),
              const ProgressTrack(value: 0.4),
              const RingProgress(value: 0.5),
              const SpeechBubble(child: Text('Hello')),
              const DottedLine(),
              QIconButton(icon: Icons.close_rounded, tooltip: 'Close', onTap: () {}),
            ],
          ),
        ),
        locale: locale,
        reduced: true,
      );
      await tester.pump(const Duration(seconds: 1));
      final transform = tester.widget<Transform>(find.descendant(of: find.byType(ProgressTrack), matching: find.byType(Transform)));
      expect(transform.transform.storage[0], locale == 'ar' ? -1 : 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('$locale brand and built-in scenes freeze with reduced motion', (tester) async {
      await pump(
        tester,
        (_) => SingleChildScrollView(
          child: Column(
            children: [
              const QabasLogo(onDark: false),
              const TravelerAvatar(hue: 0.43),
              const EmberIcon(),
              const LanternGlyph(color: QColors.emerald500),
              const UnitArtIcon(art: UnitArt.prayerRug),
              const PhaseIcon(phase: 2),
              const SizedBox(height: 150, child: RiverHouseScene()),
              const SizedBox(height: 150, child: WorkplaceScene()),
              const SizedBox(height: 150, child: DayArcScene()),
              const SizedBox(height: 150, child: PillarsScene()),
              const SizedBox(height: 100, child: NightSky()),
              const Breathe(child: Text('Still')),
              const Nudge(trigger: 1, child: Text('Calm')),
              const Reveal(child: Text('Visible')),
              const SizedBox(height: 100, child: EmberBurst(loop: true)),
              const Glow(size: 60),
              CountUp(value: 45, format: (value) => '$value'),
              const RollingNumber(from: 3, to: 4),
            ],
          ),
        ),
        locale: locale,
        reduced: true,
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('45'), findsOneWidget);
      expect(find.text(locale == 'ar' ? '٤' : '4'), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('$locale loading, empty and every error action', (tester) async {
      for (final kind in QErrorKind.values) {
        var retries = 0;
        await pump(
          tester,
          (_) => QErrorView(kind: kind, retryTime: '30', onRetry: () => retries++),
          locale: locale,
          reduced: true,
        );
        await tester.tap(find.byType(QButton));
        expect(retries, 1);
        expect(tester.takeException(), isNull);
      }
      await pump(
        tester,
        (_) => const SizedBox(
          height: 350,
          child: QLoadingView(tone: QTone.night, label: 'Preparing'),
        ),
        locale: locale,
        reduced: true,
      );
      expect(
        tester.widget<AnimatedOpacity>(find.ancestor(of: find.text('Preparing'), matching: find.byType(AnimatedOpacity)).first).opacity,
        0,
      );
      await tester.pump(QMotion.loadingLabelDelay);
      expect(find.text('Preparing'), findsOneWidget);
      await pump(
        tester,
        (_) => QEmptyView(title: 'Empty', body: 'Body', action: ('Continue', () {})),
        locale: locale,
        reduced: true,
      );
      expect(find.byType(QButton), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('cached content stays visible while refreshing or after failure', (tester) async {
    for (final status in [LoadStatus.loading, LoadStatus.refreshing, LoadStatus.failure]) {
      await pump(
        tester,
        (_) => StatusSwitcher(
          status: status,
          hasData: true,
          loading: () => const Text('Loading'),
          empty: () => const Text('Empty'),
          failure: () => const Text('Error'),
          builder: () => const Text('Cached'),
        ),
      );
      expect(find.text('Cached'), findsOneWidget);
      expect(find.text('Loading'), findsNothing);
      expect(find.text('Error'), findsNothing);
    }
  });
  testWidgets('loading delay is cancelled on early disposal', (tester) async {
    await pump(tester, (_) => const DelayedLoading(child: Text('Loading')));
    expect(find.text('Loading'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(QMotion.loadingDelay);
    expect(tester.takeException(), isNull);
  });
  testWidgets('motion toggles stop active animations immediately', (tester) async {
    var reduced = false;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return QMotionScope(
              reduceMotion: reduced,
              child: const Column(
                children: [
                  FlameMark(),
                  Breathe(child: Text('Breathe')),
                  SizedBox(height: 100, child: EmberBurst(loop: true)),
                ],
              ),
            );
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    update(() => reduced = true);
    await tester.pump();
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('OS reduced motion freezes brand and breathing animation', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Column(
            children: [
              FlameMark(),
              Breathe(child: Text('Still')),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  test('unknown presentation keys use existing artwork fallbacks', () {
    expect(UnitArtIcon.fromKey(artKey: 'unknown').art, UnitArt.book);
    expect(UnitArtIcon.fromKey(artKey: 'unit_big_questions').art, UnitArt.starrySky);
    expect(TravelerAvatar.fromKey(avatarKey: 'unknown').hue, 0.43);
  });
  testWidgets('composer changes from mic to send, keeps input and disables actions', (tester) async {
    final controller = TextEditingController();
    var recordings = 0;
    String? sent;
    await pump(
      tester,
      (_) =>
          QComposerBar(controller: controller, hint: 'Ask', onSend: (value) => sent = value, onAttach: () {}, onRecord: () => recordings++),
    );
    await tester.tap(find.byTooltip('Record a question'));
    expect(recordings, 1);
    await tester.enterText(find.byType(TextField), '  a question  ');
    await tester.pump();
    await tester.pump(QMotion.normal);
    await tester.tap(find.byTooltip('Send'));
    expect(sent, '  a question  ');
    expect(controller.text, '  a question  ');
    await pump(
      tester,
      (_) => QComposerBar(
        controller: controller,
        hint: 'Ask',
        enabled: false,
        onSend: (value) => sent = 'changed',
        onAttach: () {},
        onRecord: () => recordings++,
      ),
    );
    await tester.tap(find.byTooltip('Send'));
    expect(sent, '  a question  ');
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}
