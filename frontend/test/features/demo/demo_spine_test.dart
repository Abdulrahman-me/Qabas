import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qabas/app/config/app_config.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/features/journey/presentation/bloc/journey_bloc.dart';
import 'package:qabas/features/journey/presentation/pages/journey_page.dart';
import 'package:qabas/features/profile/presentation/bloc/settings_bloc.dart';
import 'package:qabas/features/profile/presentation/pages/settings_page.dart';
import 'package:qabas/features/raqeeb/domain/raqeeb.dart';
import 'package:qabas/features/raqeeb/presentation/bloc/raqeeb_chat_bloc.dart';
import 'package:qabas/features/raqeeb/presentation/pages/raqeeb_page.dart';
import 'package:qabas/features/raqeeb/presentation/widgets/chat_widgets.dart';
import 'package:qabas/features/session/presentation/bloc/lesson_intro_bloc.dart';
import 'package:qabas/features/session/presentation/bloc/session_player_bloc.dart';
import 'package:qabas/features/session/presentation/bloc/session_result_bloc.dart';
import 'package:qabas/features/session/presentation/pages/lesson_intro_page.dart';
import 'package:qabas/features/session/presentation/pages/session_player_page.dart';
import 'package:qabas/features/session/presentation/pages/session_result_page.dart';
import 'package:qabas/features/streak/presentation/pages/streak_page.dart';
import 'package:qabas/mock_backend/mock_backend.dart';
import 'package:qabas/shared/domain/entities/journey.dart';
import '../../support/play_session.dart';
import '../journey/journey_responsive_test.dart' show mountJourney, pumpJourney, journeyUntil, journeySizes, lessonNode, press;

void main() {
  for (final language in ['en', 'ar']) {
    for (final reduced in [false, true]) {
      testWidgets('demo spine, draft exclusion, language switch and resized state $language/$reduced', (t) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = const Size(402, 874);
        t.platformDispatcher.textScaleFactorTestValue = 1.35;
        addTearDown(t.view.resetDevicePixelRatio);
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        final d = await mountJourney(
          t,
          locale: language,
          reduced: reduced,
          config: AppConfig(flavor: AppFlavor.demo, hideDraftNotices: true, curiosityOnboarding: false),
        );
        addTearDown(() async {
          await t.pumpWidget(const SizedBox.shrink());
          await t.runAsync(d.dispose);
        });
        final mock = d.services<MockBackend>();
        await t.runAsync(() async {
          await mock.fixtures.example('Achievements');
          await mock.fixtures.example('Page[TermCard]');
          await mock.fixtures.object('examples/RaqeebCompleted__get_raqeeb_messages_message_id__3.json');
          // The post-switch lesson must arrive in its new server locale too.
          final other = language == 'en' ? 'ar' : 'en';
          await mock.fixtures.object('unit0/sessions/session_u0_l01_${other}_explorer.json');
        });
        final router = GoRouter.of(t.element(find.byType(JourneyPage)));
        final journey = t.element(find.byType(JourneyPage)).read<JourneyBloc>();
        Future<void> until(bool Function() ready) => journeyUntil(t, ready);
        Future<void> resize() async {
          final mountedJourney = find.byType(JourneyPage).evaluate().isEmpty
              ? null
              : t.element(find.byType(JourneyPage)).read<JourneyBloc>();
          for (final size in journeySizes) {
            t.view.physicalSize = size;
            await t.pump(const Duration(seconds: 1));
            expect(t.takeException(), isNull, reason: '$size');
            if (mountedJourney != null) expect(t.element(find.byType(JourneyPage)).read<JourneyBloc>(), same(mountedJourney));
            for (final text in t.widgetList<Text>(find.byType(Text))) {
              final content = (text.data ?? text.textSpan?.toPlainText() ?? '').toLowerCase();
              expect(content.contains('mock'), false);
              expect(content.contains('review draft only'), false);
            }
          }
          t.view.physicalSize = const Size(402, 874);
          await t.pump();
        }

        await resize();
        await press(t, lessonNode('les_u0_l3'));
        expect(find.byKey(const ValueKey('soft-lock-start')), findsOneWidget);
        await resize();
        await press(t, find.byKey(const ValueKey('soft-lock-start')));
        await until(
          () =>
              find.byType(LessonIntroPage).evaluate().isNotEmpty &&
              t.element(find.byType(LessonIntroPage)).read<LessonIntroBloc>().state.status == LessonIntroStatus.ready,
        );
        final session = t.element(find.byType(LessonIntroPage)).read<LessonIntroBloc>().state.start!.session;
        final notices = await t.runAsync(() => mock.fixtures.object('unit0/DRAFT_NOTICES.json'));
        final excluded = ((notices!['block_ids_by_lesson'] as Map)['les_u0_l1'] as List).cast<String>();
        expect(session.items.any((i) => excluded.contains(i.blockId)), false);
        await resize();
        await press(t, find.byKey(const ValueKey('lesson-start')));
        await until(() => find.byType(SessionPlayerPage).evaluate().isNotEmpty);
        final player = t.element(find.byType(SessionPlayerPage)).read<SessionPlayerBloc>();
        final block = player.state.item!.blockId;
        await resize();
        expect(player.state.item!.blockId, block);
        await playSession(t, d, until, wrongFirstUnderstanding: true);
        await until(() => t.element(find.byType(SessionResultPage)).read<SessionResultBloc>().state.status == SessionResultStatus.ready);
        await resize();
        await press(t, find.byKey(const ValueKey('result-continue')));
        await until(() => find.byType(StreakPage).evaluate().isNotEmpty);
        await resize();
        await press(t, find.byKey(const ValueKey('streak-continue')));
        await until(() => find.byType(JourneyPage).evaluate().isNotEmpty);
        expect(journey.state.journey!.lesson('les_u0_l1')!.state, LessonState.completed);
        expect(journey.state.journey!.lesson('les_u0_l2')!.state, LessonState.available);
        router.go('/discover');
        await pumpJourney(t);
        await resize();
        await press(t, find.byKey(const ValueKey('discover-les_u1_l1')));
        await until(
          () =>
              find.byType(LessonIntroPage).evaluate().isNotEmpty &&
              t.element(find.byType(LessonIntroPage)).read<LessonIntroBloc>().state.status == LessonIntroStatus.ready,
        );
        expect(t.element(find.byType(LessonIntroPage)).read<LessonIntroBloc>().state.start!.session.lessonId, 'les_u1_l1');
        router.go('/raqeeb');
        await pumpJourney(t);
        final c = t.element(find.byType(RaqeebPage)), chat = c.read<RaqeebChatBloc>();
        await t.enterText(find.byType(TextField), raqeebSuggestions(c).first);
        await t.pump();
        await t.pump(const Duration(milliseconds: 300));
        await t.tap(find.byTooltip(c.l10n.commonSendTooltip));
        await until(() => chat.state.turns.isNotEmpty && chat.state.turns.last.assistant is CompletedMessage);
        await resize();
        router.go('/settings');
        await pumpJourney(t);
        final settings = t.element(find.byType(SettingsPage)).read<SettingsBloc>();
        await until(() => settings.state.user != null);
        expect(find.byKey(const ValueKey('settings-curiosity')), findsNothing);
        await press(t, find.byKey(const ValueKey('settings-language')));
        final sc = t.element(find.byType(SettingsPage));
        await press(t, find.text(language == 'en' ? sc.l10n.settingsArabic : sc.l10n.settingsEnglish).last);
        await until(() => settings.state.status == SettingsStatus.ready && d.locale.state.language != language);
        expect(Directionality.of(t.element(find.byType(SettingsPage))), language == 'en' ? TextDirection.rtl : TextDirection.ltr);
        await resize();
        router.go('/journey');
        await pumpJourney(t);
        final refreshed = t.element(find.byType(JourneyPage)).read<JourneyBloc>();
        await until(() => refreshed.state.journey != null && !refreshed.state.refreshing);
        expect(refreshed.state.journey!.lesson('les_u0_l1')!.state, LessonState.completed);
        await resize();
        expect(d.locale.state.language, language == 'en' ? 'ar' : 'en');
        expect(d.preferences.state.value.reduceMotion, reduced);
      });
    }
  }
}
