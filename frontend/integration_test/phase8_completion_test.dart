import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:qabas/app/app.dart';
import 'package:qabas/app/config/app_config.dart';
import 'package:qabas/app/di/injector.dart';
import 'package:qabas/core/design_system/components/journey_node.dart';
import 'package:qabas/core/storage/preferences_store.dart';
import 'package:qabas/core/storage/token_store.dart';
import 'package:qabas/features/auth/domain/repositories/auth_repository.dart';
import 'package:qabas/features/auth/presentation/bloc/app_session_bloc.dart';
import 'package:qabas/features/journey/presentation/bloc/journey_bloc.dart';
import 'package:qabas/features/journey/presentation/pages/journey_page.dart';
import 'package:qabas/features/onboarding/domain/entities/onboarding_answers.dart';
import 'package:qabas/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:qabas/features/session/presentation/bloc/lesson_intro_bloc.dart';
import 'package:qabas/features/session/presentation/bloc/session_result_bloc.dart';
import 'package:qabas/features/session/presentation/pages/lesson_intro_page.dart';
import 'package:qabas/features/session/presentation/pages/session_player_page.dart';
import 'package:qabas/features/session/presentation/pages/session_result_page.dart';
import 'package:qabas/features/streak/presentation/bloc/streak_bloc.dart';
import 'package:qabas/features/streak/presentation/pages/streak_page.dart';
import 'package:qabas/mock_backend/mock_backend.dart';
import 'package:qabas/shared/domain/entities/journey.dart';
import '../test/support/play_session.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final language in ['en', 'ar']) {
    for (final reduced in [false, true]) {
      testWidgets('mock completion, streak and refreshed Journey/Discover $language/$reduced', (t) async {
        Future<void> until(bool Function() condition) async {
          for (var i = 0; i < 200 && !condition(); i++) {
            await t.pump(const Duration(milliseconds: 80));
          }
          expect(condition(), true);
          expect(t.takeException(), isNull);
          await t.pump(const Duration(milliseconds: 600));
        }

        Future<void> capture(String name) async {
          for (var i = 0; i < 100; i++) {
            await t.pump(const Duration(milliseconds: 16));
          }
          expect(t.takeException(), isNull);
          if (defaultTargetPlatform == TargetPlatform.android) {
            debugPrint('PHASE8_CAPTURE:$name');
            await Future<void>.delayed(const Duration(milliseconds: 900));
          } else {
            await binding.takeScreenshot(name);
          }
        }

        final store = await PreferencesStore.open();
        await store.clear();
        await store.setString('language', language);
        await store.setBoolean('reduce_motion', reduced);
        final d = await AppDependencies.create(
          config: AppConfig(),
          store: store,
          initialSessionState: const AppSessionState(status: SessionStatus.ready, splashElapsed: true),
        );
        addTearDown(() async {
          await t.pumpWidget(const SizedBox.shrink());
          await d.dispose();
        });
        await d.services<TokenStore>().clear();
        d.services<MockBackend>().controls.fast = true;
        await d.services<AuthRepository>().createGuest();
        await d.services<OnboardingRepository>().complete(
          OnboardingAnswers(
            track: TrackChoice.explorer,
            language: language,
            familiarity: null,
            dailyGoal: 10,
            privateProfile: true,
            goalAnchor: null,
          ),
        );
        await t.pumpWidget(QabasApp(dependencies: d));
        await until(
          () =>
              find.byType(JourneyPage).evaluate().isNotEmpty &&
              t.element(find.byType(JourneyPage)).read<JourneyBloc>().state.journey != null,
        );
        final router = GoRouter.of(t.element(find.byType(JourneyPage)));
        final prefix = 'phase8/${defaultTargetPlatform.name}_${language}_${reduced ? 'reduced' : 'motion'}';
        Future<void> start({bool wrong = false}) async {
          await until(
            () =>
                find.byType(LessonIntroPage).evaluate().isNotEmpty &&
                t.element(find.byType(LessonIntroPage)).read<LessonIntroBloc>().state.status == LessonIntroStatus.ready,
          );
          await t.tap(find.byKey(const ValueKey('lesson-start')));
          await until(() => find.byType(SessionPlayerPage).evaluate().isNotEmpty);
          await playSession(t, d, until, wrongFirstUnderstanding: wrong);
          await until(() => t.element(find.byType(SessionResultPage)).read<SessionResultBloc>().state.status == SessionResultStatus.ready);
        }

        final node = find.byWidgetPredicate((w) => w is QJourneyNode && w.node.id == 'les_u0_l1');
        await Scrollable.ensureVisible(t.element(node), alignment: .42);
        await t.pump();
        await t.tap(node);
        await until(() => find.byKey(const ValueKey('node-start-les_u0_l1')).evaluate().isNotEmpty);
        await t.tap(find.byKey(const ValueKey('node-start-les_u0_l1')));
        await start();
        await capture('${prefix}_36_unit0_complete');
        final result = t.element(find.byType(SessionResultPage)).read<SessionResultBloc>().state;
        expect(result.result!.streakExtended, true);
        final next = find.text(result.session!.completion!.reviewTopics.last.title);
        await Scrollable.ensureVisible(t.element(next), alignment: 0);
        await t.pump();
        await capture('${prefix}_complete_details');
        await t.tap(find.byKey(const ValueKey('result-continue')));
        await until(
          () =>
              find.byType(StreakPage).evaluate().isNotEmpty &&
              t.element(find.byType(StreakPage)).read<StreakBloc>().state.status == StreakStatus.ready,
        );
        expect(t.element(find.byType(StreakPage)).read<StreakBloc>().state.activity!.streak.current, 4);
        await capture('${prefix}_37_streak');
        await t.tap(find.byKey(const ValueKey('streak-continue')));
        await until(() => find.byType(JourneyPage).evaluate().isNotEmpty);
        final journey = t.element(find.byType(JourneyPage)).read<JourneyBloc>();
        expect(journey.state.journey!.lesson('les_u0_l1')!.state, LessonState.completed);
        expect(journey.state.journey!.lesson('les_u0_l2')!.state, LessonState.available);
        final completed = find.byWidgetPredicate((w) => w is QJourneyNode && w.node.id == 'les_u0_l1');
        await Scrollable.ensureVisible(t.element(completed), alignment: .25);
        await t.pump();
        await capture('${prefix}_38_journey_after');
        await t.tap(find.byKey(const ValueKey('nav-1')));
        await t.pump(const Duration(milliseconds: 800));
        final discover = find.byKey(const ValueKey('discover-les_u1_l1'));
        await Scrollable.ensureVisible(t.element(discover));
        await t.pump();
        await t.tap(discover);
        await start();
        expect(t.element(find.byType(SessionResultPage)).read<SessionResultBloc>().state.result!.streakExtended, false);
        await capture('${prefix}_1_1_complete');
        await t.tap(find.byKey(const ValueKey('result-continue')));
        await until(() => find.byType(JourneyPage).evaluate().isNotEmpty);
        expect(t.element(find.byType(JourneyPage)).read<JourneyBloc>().state.journey!.lesson('les_u1_l1')!.state, LessonState.completed);
        // Reference fixture remains developer-only; use its existing route for comparison.
        router.go('/lesson/les_u1_l3/intro');
        await start(wrong: true);
        final salah = t.element(find.byType(SessionResultPage)).read<SessionResultBloc>().state.result!;
        expect(salah.total, 6);
        expect(salah.percent, 83);
        expect(salah.understanding!.percent, 67);
        expect(salah.applying!.percent, 100);
        await capture('${prefix}_36_salah_complete');
      });
    }
  }
}
