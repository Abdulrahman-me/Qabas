import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:qabas/app/app.dart';
import 'package:qabas/app/config/app_config.dart';
import 'package:qabas/app/di/injector.dart';
import 'package:qabas/core/design_system/components/journey_node.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/core/storage/preferences_store.dart';
import 'package:qabas/core/storage/token_store.dart';
import 'package:qabas/features/auth/domain/repositories/auth_repository.dart';
import 'package:qabas/features/auth/presentation/bloc/app_session_bloc.dart';
import 'package:qabas/features/dev_tools/domain/repositories/dev_tools_repository.dart';
import 'package:qabas/features/dev_tools/domain/usecases/dev_tools_actions.dart';
import 'package:qabas/features/dev_tools/presentation/bloc/dev_tools_bloc.dart';
import 'package:qabas/features/dev_tools/presentation/pages/dev_tools_page.dart';
import 'package:qabas/features/journey/presentation/bloc/journey_bloc.dart';
import 'package:qabas/features/journey/presentation/pages/journey_page.dart';
import 'package:qabas/features/onboarding/domain/entities/onboarding_answers.dart';
import 'package:qabas/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:qabas/features/session/presentation/pages/lesson_intro_page.dart';
import 'package:qabas/mock_backend/mock_backend.dart';
import 'package:qabas/shared/domain/entities/journey.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  Future<void> until(WidgetTester tester, bool Function() condition) async {
    for (var i = 0; i < 100 && !condition(); i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(condition(), true);
    expect(tester.takeException(), isNull);
  }

  Future<void> capture(WidgetTester tester, String name) async {
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await binding.takeScreenshot('phase4/$name');
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
  }

  Finder node(String id) => find.byWidgetPredicate((w) => w is QJourneyNode && w.node.id == id, skipOffstage: false);
  JourneyBloc bloc(WidgetTester tester) => tester.element(find.byType(JourneyPage)).read<JourneyBloc>();
  Future<void> reveal(WidgetTester tester, String id) async {
    await Scrollable.ensureVisible(tester.element(node(id)), alignment: .42, duration: Duration.zero);
    await tester.pump();
  }

  for (final locale in ['en', 'ar']) {
    for (final reduced in [false, true]) {
      testWidgets('Journey, Soft Lock, Discover and preserved track progress: $locale / $reduced', (tester) async {
        final prefix = '${locale}_${reduced ? 'reduced' : 'motion'}';
        final store = await PreferencesStore.open();
        await store.clear();
        await store.setString('language', locale);
        await store.setBoolean('reduce_motion', reduced);
        final d = await AppDependencies.create(
          config: AppConfig(),
          store: store,
          initialSessionState: const AppSessionState(status: SessionStatus.ready, splashElapsed: true),
        );
        await d.services<TokenStore>().clear();
        final mock = d.services<MockBackend>();
        mock.controls.fast = true;
        await d.services<AuthRepository>().createGuest();
        await d.services<OnboardingRepository>().complete(
          OnboardingAnswers(
            track: TrackChoice.explorer,
            language: locale,
            familiarity: null,
            dailyGoal: 10,
            privateProfile: true,
            goalAnchor: null,
          ),
        );
        await tester.pumpWidget(QabasApp(dependencies: d));
        await until(tester, () => find.byType(JourneyPage).evaluate().isNotEmpty && bloc(tester).state.journey != null);
        await tester.pump(const Duration(seconds: 1));
        final journey = bloc(tester);
        expect(journey.state.journey!.lesson('les_u1_l1')!.state, LessonState.available);
        final scroll = tester.state<ScrollableState>(
          find.descendant(of: find.byKey(const PageStorageKey('journey-scroll')), matching: find.byType(Scrollable)).first,
        );
        scroll.position.jumpTo(0);
        await capture(tester, '${prefix}_journey_top');
        await reveal(tester, 'les_u0_l1');
        await capture(tester, '${prefix}_current');
        await tester.tap(node('les_u0_l1'));
        await tester.pump(const Duration(milliseconds: 600));
        await capture(tester, '${prefix}_popover');
        await tap(tester, find.byKey(const ValueKey('node-start-les_u0_l1')));
        await until(tester, () => find.byType(LessonIntroPage).evaluate().isNotEmpty);
        await capture(tester, '${prefix}_lesson_entry');
        final back = find.byWidgetPredicate(
          (w) => w is QIconButton && w.tooltip == tester.element(find.byType(LessonIntroPage)).l10n.commonClose,
        );
        await tap(tester, back);
        await reveal(tester, 'les_u0_l2');
        await tester.tap(node('les_u0_l2'));
        await tester.pump(const Duration(milliseconds: 600));
        await capture(tester, '${prefix}_soft_lock');
        await tap(tester, find.byKey(const ValueKey('soft-lock-start')));
        await until(tester, () => find.byType(LessonIntroPage).evaluate().isNotEmpty);
        expect(find.text(journey.state.journey!.lesson('les_u0_l1')!.title), findsOneWidget);
        await tap(tester, back);
        await tap(tester, find.byKey(const ValueKey('nav-1')));
        await until(tester, () => find.byKey(const ValueKey('discover-les_u1_l1')).evaluate().isNotEmpty);
        await capture(tester, '${prefix}_discover');
        await tap(tester, find.byKey(const ValueKey('discover-les_u1_l1')));
        expect(find.byType(LessonIntroPage), findsOneWidget);
        await tap(tester, back);
        await tap(tester, find.byKey(const ValueKey('nav-4')));
        await tester.longPress(find.byKey(const ValueKey('profile-avatar')));
        await until(tester, () => find.byType(DevToolsPage).evaluate().isNotEmpty);
        final dev = tester.element(find.byType(DevToolsPage)).read<DevToolsBloc>();
        dev.add(const DevOptionChanged(DevOption.completedLesson, 'les_u0_l1'));
        await until(tester, () => mock.db.completedLessons.contains('les_u0_l1'));
        await tap(tester, find.byKey(const ValueKey('developer-back')));
        await tap(tester, find.byKey(const ValueKey('nav-0')));
        await until(tester, () => journey.state.journey!.current.lessonId == 'les_u0_l2');
        await capture(tester, '${prefix}_progressed');
        await tap(tester, find.byKey(const ValueKey('journey-path-switch')));
        await capture(tester, '${prefix}_switch');
        await tap(tester, find.byKey(const ValueKey('track-newMuslim')));
        await until(tester, () => journey.state.journey!.lesson('les_u0_l1') == null);
        await capture(tester, '${prefix}_new_muslim');
        await tap(tester, find.byKey(const ValueKey('journey-path-switch')));
        await tap(tester, find.byKey(const ValueKey('track-explorer')));
        await until(tester, () => journey.state.journey!.lesson('les_u0_l1')?.state == LessonState.completed);
        await reveal(tester, 'les_u1_l1');
        await capture(tester, '${prefix}_unit1');
        scroll.position.jumpTo(scroll.position.maxScrollExtent);
        await capture(tester, '${prefix}_horizon');
        mock.db.dueReviews = 3;
        journey.add(const JourneyRefreshed());
        await until(tester, () => journey.state.nextStep!.dueReviewsCount == 3);
        scroll.position.jumpTo(0);
        await capture(tester, '${prefix}_review');
        await d.services<DevToolsActions>().change(DevOption.completedLesson, 'les_u1_l1');
        await tester.pump(const Duration(seconds: 1));
        await tap(tester, find.byKey(const ValueKey('nav-1')));
        await capture(tester, '${prefix}_discover_completed');
        await tap(tester, find.byKey(const ValueKey('nav-0')));
        await tester.pumpWidget(const SizedBox.shrink());
        await d.dispose();
      });
    }
  }
}
