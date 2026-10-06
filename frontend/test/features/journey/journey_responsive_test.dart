import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qabas/app/app.dart';
import 'package:qabas/app/config/app_config.dart';
import 'package:qabas/app/di/injector.dart';
import 'package:qabas/core/characters/character_asset_cache.dart';
import 'package:qabas/core/design_system/components/journey_node.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/core/network/backend_transport.dart';
import 'package:qabas/features/auth/presentation/bloc/app_session_bloc.dart';
import 'package:qabas/features/dev_tools/domain/repositories/dev_tools_repository.dart';
import 'package:qabas/features/dev_tools/domain/usecases/dev_tools_actions.dart';
import 'package:qabas/features/discover/presentation/pages/discover_page.dart';
import 'package:qabas/features/journey/presentation/bloc/journey_bloc.dart';
import 'package:qabas/features/journey/presentation/pages/journey_page.dart';
import 'package:qabas/features/session/presentation/bloc/lesson_intro_bloc.dart';
import 'package:qabas/features/session/presentation/bloc/session_player_bloc.dart';
import 'package:qabas/features/session/presentation/pages/lesson_intro_page.dart';
import 'package:qabas/features/session/presentation/pages/session_player_page.dart';
import 'package:qabas/mock_backend/mock_backend.dart';
import 'package:qabas/mock_backend/mock_router.dart';
import 'package:qabas/shared/domain/entities/journey.dart';
import 'package:qabas/shared/domain/entities/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fakes.dart';
import '../../support/journey_test_assets.dart';
import '../../support/scene_test_assets.dart';

Future<void> pumpJourney(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 2)));
  }
}

Future<void> journeyUntil(WidgetTester tester, bool Function() ready, {String Function()? diagnostic}) async {
  for (var i = 0; i < 100 && !ready(); i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
  }
  expect(ready(), true, reason: diagnostic?.call());
  await tester.pump();
}

const journeySizes = [Size(320, 568), Size(320, 400), Size(600, 400), Size(839, 600), Size(840, 600), Size(1440, 900), Size(1920, 1080)];
Future<AppDependencies> mountJourney(
  WidgetTester tester, {
  String locale = 'en',
  bool reduced = false,
  bool pump = true,
  AppSessionState? initialSessionState,
  AssetBundle? profileCopyBundle,
  AppConfig? config,
}) async {
  SharedPreferences.setMockInitialValues({'qabas_language': locale, 'qabas_reduce_motion': reduced});
  final tokens = MemoryTokens()..value = 'journey-widget';
  final d = await AppDependencies.create(
    config: config ?? AppConfig(),
    tokens: tokens,
    mockFixtures: journeyTestAssets(),
    profileCopyBundle: profileCopyBundle,
    cache: CharacterAssetCache(loader: (_) async => null),
    scenes: sceneTestCache(),
    initialSessionState: initialSessionState ?? const AppSessionState(status: SessionStatus.ready, splashElapsed: true),
  );
  final mock = d.services<MockBackend>();
  mock.controls.fast = true;
  mock.db.tokens.add(tokens.value!);
  await tester.runAsync(() async {
    mock.db.user = await mock.fixtures.example('User');
    await mock.fixtures.example('Stats');
    await mock.fixtures.object('demo_curriculum/curriculum.json');
    // Decode asynchronous assets outside the widget test's simulated clock.
    // Each fixture remains a fresh server snapshot.
    await mock.fixtures.object('unit0/SESSION_INDEX.json');
    await mock.fixtures.object('unit0/DRAFT_NOTICES.json');
    await mock.fixtures.object('unit0/sessions/session_u0_l01_${locale}_explorer.json');
    await mock.fixtures.object('test_lessons/u1l1_${locale}_explorer.json');
    await mock.fixtures.object('private/unit0/session_u0_l01_${locale}_explorer.json');
    await mock.fixtures.object('private/test_lessons/u1l1_keys.json');
    await mock.fixtures.object('contract/sessions/review_cards.json');
    await mock.fixtures.object('contract/curriculum_test/PRIVATE_GRADING_KEYS.json');
  });
  mock.db.user!['track'] = 'explorer';
  mock.db.user!['language'] = locale;
  if (pump) {
    await tester.pumpWidget(QabasApp(dependencies: d));
    await pumpJourney(tester);
    await tester.pump();
  }
  return d;
}

Finder learningButton(String label) => find.byWidgetPredicate((w) => w is QButton && w.label == label);
Finder lessonNode(String id) => find.byWidgetPredicate((w) => w is QJourneyNode && w.node.id == id);
Future<void> revealNode(WidgetTester tester, String id) async {
  await Scrollable.ensureVisible(tester.element(lessonNode(id)), alignment: .42, duration: Duration.zero);
  await tester.pump();
}

Future<void> press(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
  await pumpJourney(tester);
  await tester.pump();
}

JourneyBloc journeyBloc(WidgetTester tester) => tester.element(find.byType(JourneyPage)).read<JourneyBloc>();
void main() {
  for (final locale in ['en', 'ar']) {
    for (final reduced in [false, true]) {
      testWidgets('Journey/Discover retain selections and actions during resize: $locale / $reduced', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = journeySizes.first;
        tester.platformDispatcher.textScaleFactorTestValue = 1.35;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final d = await mountJourney(tester, locale: locale, reduced: reduced);
        final bloc = journeyBloc(tester);
        expect(
          bloc.state.journey,
          isNotNull,
          reason: '${bloc.state.status} / ${bloc.state.failure} / ${d.services<MockBackend>().lastRequest?.path}',
        );
        expect(bloc.state.journey!.current.lessonId, 'les_u0_l1');
        expect(find.byKey(const ValueKey('journey-review')), findsNothing);
        expect(find.byWidgetPredicate((w) => w is QJourneyNode && w.node.kind == QNodeKind.checkpoint), findsNothing);
        await revealNode(tester, 'les_u0_l1');
        await tester.tap(lessonNode('les_u0_l1'));
        await pumpJourney(tester);
        await tester.pump();
        for (final size in journeySizes) {
          tester.view.physicalSize = size;
          await pumpJourney(tester);
          await tester.pump();
          expect(bloc.state.selectedLessonId, 'les_u0_l1');
          final popover = find.byKey(const ValueKey('popover-les_u0_l1'));
          expect(popover, findsOneWidget);
          final rect = tester.getRect(popover);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(size.width));
          expect(rect.bottom, lessThanOrEqualTo(size.height), reason: '$size anchor ${tester.getRect(lessonNode("les_u0_l1"))} card $rect');
          expect(rect.top, greaterThanOrEqualTo(0));
          final issue = tester.takeException();
          expect(issue, isNull, reason: 'Popover $size/$locale/$reduced');
        }
        await press(tester, find.byKey(const ValueKey('node-start-les_u0_l1')));
        await journeyUntil(
          tester,
          () =>
              find.byType(LessonIntroPage).evaluate().isNotEmpty &&
              [
                LessonIntroStatus.ready,
                LessonIntroStatus.failure,
                LessonIntroStatus.locked,
              ].contains(tester.element(find.byType(LessonIntroPage)).read<LessonIntroBloc>().state.status),
          diagnostic: () =>
              "intro=${find.byType(LessonIntroPage).evaluate().isEmpty ? 'absent' : tester.element(find.byType(LessonIntroPage)).read<LessonIntroBloc>().state.status}, path=${d.services<MockBackend>().lastRequest?.path}, sessions=${d.services<MockBackend>().db.sessions.length}",
        );
        expect(
          tester.element(find.byType(LessonIntroPage)).read<LessonIntroBloc>().state.status,
          LessonIntroStatus.ready,
          reason: '${tester.element(find.byType(LessonIntroPage)).read<LessonIntroBloc>().state.failure}',
        );
        expect(find.byType(LessonIntroPage), findsOneWidget);
        final title = bloc.state.journey!.lesson('les_u0_l1')!.title;
        expect(find.text(title), findsOneWidget);
        final back = find.byWidgetPredicate(
          (w) => w is QIconButton && w.tooltip == tester.element(find.byType(LessonIntroPage)).l10n.commonClose,
        );
        await press(tester, back);
        await revealNode(tester, 'les_u0_l2');
        await tester.tap(lessonNode('les_u0_l2'));
        await pumpJourney(tester);
        expect(find.text(bloc.state.journey!.lesson('les_u0_l1')!.title), findsWidgets);
        await press(tester, find.byKey(const ValueKey('soft-lock-start')));
        await journeyUntil(
          tester,
          () =>
              find.byType(LessonIntroPage).evaluate().isNotEmpty &&
              [
                LessonIntroStatus.ready,
                LessonIntroStatus.failure,
                LessonIntroStatus.locked,
              ].contains(tester.element(find.byType(LessonIntroPage)).read<LessonIntroBloc>().state.status),
          diagnostic: () =>
              "intro=${find.byType(LessonIntroPage).evaluate().isEmpty ? 'absent' : tester.element(find.byType(LessonIntroPage)).read<LessonIntroBloc>().state.status}, path=${d.services<MockBackend>().lastRequest?.path}, sessions=${d.services<MockBackend>().db.sessions.length}",
        );
        expect(
          tester.element(find.byType(LessonIntroPage)).read<LessonIntroBloc>().state.status,
          LessonIntroStatus.ready,
          reason: '${tester.element(find.byType(LessonIntroPage)).read<LessonIntroBloc>().state.failure}',
        );
        expect(find.text(title), findsOneWidget);
        await press(tester, back);
        await press(tester, find.byKey(const ValueKey('nav-1')));
        expect(find.byType(DiscoverPage), findsOneWidget);
        expect(find.byKey(const ValueKey('discover-notice')), findsOneWidget);
        for (final size in journeySizes) {
          tester.view.physicalSize = size;
          await tester.pump();
          final issue = tester.takeException();
          expect(issue, isNull, reason: 'Discover $size/$locale');
        }
        await press(tester, find.byKey(const ValueKey('discover-les_u1_l1')));
        await journeyUntil(
          tester,
          () =>
              find.byType(LessonIntroPage).evaluate().isNotEmpty &&
              [
                LessonIntroStatus.ready,
                LessonIntroStatus.failure,
                LessonIntroStatus.locked,
              ].contains(tester.element(find.byType(LessonIntroPage)).read<LessonIntroBloc>().state.status),
          diagnostic: () =>
              "intro=${find.byType(LessonIntroPage).evaluate().isEmpty ? 'absent' : tester.element(find.byType(LessonIntroPage)).read<LessonIntroBloc>().state.status}, path=${d.services<MockBackend>().lastRequest?.path}, sessions=${d.services<MockBackend>().db.sessions.length}",
        );
        expect(
          tester.element(find.byType(LessonIntroPage)).read<LessonIntroBloc>().state.status,
          LessonIntroStatus.ready,
          reason: '${tester.element(find.byType(LessonIntroPage)).read<LessonIntroBloc>().state.failure}',
        );
        expect(find.text(bloc.state.journey!.lesson('les_u1_l1')!.title), findsOneWidget);
        await press(tester, back);
        await tester.runAsync(() => d.services<DevToolsActions>().change(DevOption.completedLesson, 'les_u0_l1'));
        await pumpJourney(tester);
        await tester.pump();
        await press(tester, find.byKey(const ValueKey('nav-0')));
        expect(bloc.state.journey!.lesson('les_u0_l2')!.state, LessonState.available);
        await press(tester, find.byKey(const ValueKey('journey-path-switch')));
        await press(tester, find.byKey(const ValueKey('track-newMuslim')));
        await journeyUntil(tester, () => bloc.state.journey?.track == UserTrack.newMuslim);
        expect(bloc.state.journey!.lesson('les_u0_l1'), isNull);
        await press(tester, find.byKey(const ValueKey('journey-path-switch')));
        await press(tester, find.byKey(const ValueKey('track-explorer')));
        await journeyUntil(tester, () => bloc.state.journey?.track == UserTrack.explorer);
        expect(bloc.state.journey!.lesson('les_u0_l1')!.state, LessonState.completed);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(d.dispose);
        await pumpJourney(tester);
      });
    }
  }
  testWidgets('Journey pending/error/retry/empty and due review states are reachable', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final d = await mountJourney(tester, pump: false);
    final mock = d.services<MockBackend>();
    final pending = Completer<BackendResponse>();
    mock.router.routes.insert(0, MockRoute('GET', '/journey', (r, p) => pending.future));
    await tester.pumpWidget(QabasApp(dependencies: d));
    await pumpJourney(tester);
    expect(find.byType(QLoadingView), findsOneWidget);
    pending.complete(BackendResponse.error(500, 'internal_error', 'Unavailable'));
    await pumpJourney(tester);
    await tester.pump();
    expect(find.byType(QErrorView), findsOneWidget);
    mock.router.routes.removeAt(0);
    mock.db.dueReviews = 3;
    final retry = tester.element(find.byType(QErrorView)).l10n.commonRetry;
    await press(tester, learningButton(retry));
    expect(journeyBloc(tester).state.journey, isNotNull);
    expect(journeyBloc(tester).state.nextStep?.dueReviewsCount, 3);
    final review = find.byKey(const ValueKey('journey-review'), skipOffstage: false);
    await Scrollable.ensureVisible(tester.element(review), alignment: .42);
    await tester.pump();
    final label = tester.element(review).l10n.journeyStartReview;
    await press(tester, find.descendant(of: review, matching: learningButton(label)));
    await journeyUntil(tester, () => find.byType(SessionPlayerPage).evaluate().isNotEmpty);
    final player = tester.element(find.byType(SessionPlayerPage)).read<SessionPlayerBloc>();
    await journeyUntil(tester, () => player.state.session != null);
    expect(player.state.session!.mode, 'cards');
    player.add(const QuitConfirmed());
    await journeyUntil(tester, () => find.byType(JourneyPage).evaluate().isNotEmpty);
    mock.router.routes.insert(
      0,
      MockRoute(
        'GET',
        '/journey',
        (r, p) async => const BackendResponse(200, {
          'track': 'explorer',
          'current': {'unit_id': null, 'lesson_id': null},
          'units': [],
        }),
      ),
    );
    journeyBloc(tester).add(const JourneyRefreshed());
    await pumpJourney(tester);
    await tester.pump();
    expect(find.byType(QEmptyView), findsOneWidget);
    expect(tester.takeException(), isNull);
    await press(tester, find.byKey(const ValueKey('nav-1')));
    expect(find.byType(QEmptyView), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(d.dispose);
    await pumpJourney(tester);
  });
}
