import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/core/l10n/q_numbers.dart';
import 'package:qabas/core/network/backend_transport.dart';
import 'package:qabas/features/discover/presentation/bloc/discover_bloc.dart';
import 'package:qabas/features/discover/presentation/pages/discover_page.dart';
import 'package:qabas/features/journey/presentation/bloc/journey_bloc.dart';
import 'package:qabas/features/journey/presentation/pages/journey_page.dart';
import 'package:qabas/features/session/presentation/bloc/lesson_intro_bloc.dart';
import 'package:qabas/features/session/presentation/bloc/session_result_bloc.dart';
import 'package:qabas/features/session/presentation/pages/lesson_intro_page.dart';
import 'package:qabas/features/session/presentation/pages/session_player_page.dart';
import 'package:qabas/features/session/presentation/pages/session_result_page.dart';
import 'package:qabas/features/streak/presentation/bloc/streak_bloc.dart';
import 'package:qabas/features/streak/presentation/pages/streak_page.dart';
import 'package:qabas/mock_backend/mock_backend.dart';
import 'package:qabas/mock_backend/mock_router.dart';
import 'package:qabas/shared/domain/entities/journey.dart';
import '../../support/play_session.dart';
import '../journey/journey_responsive_test.dart' show mountJourney, pumpJourney, journeyUntil, journeySizes;

void main() {
  for (final lang in ['en', 'ar']) {
    for (final reduced in [false, true]) {
      testWidgets('0.1 completion/streak/Journey and Discover 1.1 survive resize: $lang/$reduced', (t) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = const Size(402, 874);
        t.platformDispatcher.textScaleFactorTestValue = 1.35;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        final d = await mountJourney(t, locale: lang, reduced: reduced);
        final router = GoRouter.of(t.element(find.byType(JourneyPage)));
        // Mount Discover before finishing to verify its event-bus subscription too.
        router.go('/discover');
        await pumpJourney(t);
        final discover = t.element(find.byType(DiscoverPage)).read<DiscoverBloc>();
        router.go('/journey');
        await pumpJourney(t);
        final journey = t.element(find.byType(JourneyPage)).read<JourneyBloc>();
        Future<void> until(bool Function() test) => journeyUntil(t, test);
        Future<void> start(String id) async {
          unawaited(router.push('/lesson/$id/intro'));
          await until(
            () =>
                find.byType(LessonIntroPage).evaluate().isNotEmpty &&
                t.element(find.byType(LessonIntroPage)).read<LessonIntroBloc>().state.status == LessonIntroStatus.ready,
          );
          await t.tap(find.byKey(const ValueKey('lesson-start')));
          await until(() => find.byType(SessionPlayerPage).evaluate().isNotEmpty);
          await playSession(t, d, until);
          await until(() => t.element(find.byType(SessionResultPage)).read<SessionResultBloc>().state.status == SessionResultStatus.ready);
          await pumpJourney(t);
        }

        await start('les_u0_l1');
        final bloc = t.element(find.byType(SessionResultPage)).read<SessionResultBloc>();
        final result = bloc.state.result!;
        expect(result.streakExtended, true);
        expect(result.percent, 100);
        expect(discover.state.journey!.lesson('les_u0_l1')!.state, LessonState.completed);
        final pageContext = t.element(find.byType(SessionResultPage));
        expect(find.text('+${pageContext.n(result.xp)}'), findsOneWidget);
        for (final size in journeySizes) {
          t.view.physicalSize = size;
          await t.pump(const Duration(seconds: 2));
          expect(t.takeException(), isNull, reason: 'result/$size');
          expect(t.element(find.byType(SessionResultPage)).read<SessionResultBloc>(), same(bloc));
          expect(bloc.state.result, same(result));
          expect(t.getRect(find.byKey(const ValueKey('result-continue'))).bottom, lessThanOrEqualTo(size.height));
          expect(find.text('+${pageContext.n(result.xp)}'), findsOneWidget);
        }
        // Server review/challenge/check-in and next step remain reachable by scrolling.
        final topic = find.text(bloc.state.session!.completion!.reviewTopics.last.title);
        await t.ensureVisible(topic);
        await t.pump();
        expect(t.takeException(), isNull);
        if (result.nextStep!.title != null) {
          expect(find.text(pageContext.l10n.sessionNextOnPath(result.nextStep!.title!)), findsOneWidget);
        } else {
          expect(result.nextStep!.dueReviewsCount, greaterThan(0));
        }
        await t.tap(find.byKey(const ValueKey('result-continue')));
        await until(
          () =>
              find.byType(StreakPage).evaluate().isNotEmpty &&
              t.element(find.byType(StreakPage)).read<StreakBloc>().state.status == StreakStatus.ready,
        );
        await pumpJourney(t);
        final streak = t.element(find.byType(StreakPage)).read<StreakBloc>();
        expect(streak.state.celebrate, true);
        expect(streak.state.activity!.streak.current, 4);
        for (final size in journeySizes) {
          t.view.physicalSize = size;
          await t.pump(const Duration(seconds: 2));
          expect(t.takeException(), isNull, reason: 'streak/$size');
          expect(t.element(find.byType(StreakPage)).read<StreakBloc>(), same(streak));
          expect(t.getRect(find.byKey(const ValueKey('streak-continue'))).bottom, lessThanOrEqualTo(size.height));
          expect(find.text(QNumbers.format(4, lang)), findsOneWidget);
        }
        await t.tap(find.byKey(const ValueKey('streak-continue')));
        await pumpJourney(t);
        expect(journey.state.journey!.lesson('les_u0_l1')!.state, LessonState.completed);
        expect(journey.state.journey!.lesson('les_u0_l2')!.state, LessonState.available);
        expect(journey.state.stats!.streak.current, 4);
        // Entry from the existing Discover row.
        router.go('/discover');
        await pumpJourney(t);
        final tile = find.text(discover.state.journey!.lesson('les_u1_l1')!.title);
        await t.ensureVisible(tile);
        await t.pump();
        await t.tap(tile);
        await pumpJourney(t);
        await until(
          () =>
              find.byType(LessonIntroPage).evaluate().isNotEmpty &&
              t.element(find.byType(LessonIntroPage)).read<LessonIntroBloc>().state.status == LessonIntroStatus.ready,
        );
        await t.tap(find.byKey(const ValueKey('lesson-start')));
        await until(() => find.byType(SessionPlayerPage).evaluate().isNotEmpty);
        await playSession(t, d, until);
        await until(() => t.element(find.byType(SessionResultPage)).read<SessionResultBloc>().state.status == SessionResultStatus.ready);
        await pumpJourney(t);
        expect(t.element(find.byType(SessionResultPage)).read<SessionResultBloc>().state.result!.streakExtended, false);
        await t.tap(find.byKey(const ValueKey('result-continue')));
        await pumpJourney(t);
        expect(find.byType(StreakPage), findsNothing);
        expect(t.element(find.byType(JourneyPage)).read<JourneyBloc>().state.journey!.lesson('les_u1_l1')!.state, LessonState.completed);
        router.go('/discover');
        await pumpJourney(t);
        expect(t.element(find.byType(DiscoverPage)).read<DiscoverBloc>().state.journey!.lesson('les_u1_l1')!.state, LessonState.completed);
        await t.pumpWidget(const SizedBox.shrink());
        await t.runAsync(d.dispose);
      });
    }
  }
  testWidgets('result and activity loading/failure/retry, no qualifying days, and direct result recovery', (t) async {
    final d = await mountJourney(t, reduced: true);
    final mock = d.services<MockBackend>();
    final router = GoRouter.of(t.element(find.byType(JourneyPage)));
    final response = Completer<BackendResponse>();
    mock.router.routes.insert(0, MockRoute('GET', '/me/activity', (_, _) => response.future));
    unawaited(router.push('/streak'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    expect(find.byType(QLoadingView), findsOneWidget);
    response.complete(BackendResponse.error(503, 'upstream_unavailable', 'Unavailable'));
    await journeyUntil(t, () => find.byType(QErrorView).evaluate().isNotEmpty);
    mock.router.routes.removeAt(0);
    mock.router.routes.insert(
      0,
      MockRoute(
        'GET',
        '/me/activity',
        (_, _) async => const BackendResponse(200, {
          'timezone': 'Asia/Muscat',
          'from': '2026-09-01',
          'to': '2026-10-05',
          'streak': {'current': 0, 'longest': 0, 'today_completed': false},
          'days': <Object>[],
        }),
      ),
    );
    await t.tap(find.byType(QButton));
    await pumpJourney(t);
    expect(find.byType(StreakView), findsOneWidget);
    expect(find.byKey(const ValueKey('streak-continue')), findsNothing);
    router.go('/session/unknown/result');
    await pumpJourney(t);
    expect(find.byType(QErrorView), findsOneWidget);
    await t.pumpWidget(const SizedBox.shrink());
    await t.runAsync(d.dispose);
  });
}
