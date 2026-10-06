import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:qabas/app/app.dart';
import 'package:qabas/app/config/app_config.dart';
import 'package:qabas/app/di/injector.dart';
import 'package:qabas/core/design_system/components/journey_node.dart';
import 'package:qabas/core/storage/preferences_store.dart';
import 'package:qabas/core/storage/token_store.dart';
import 'package:qabas/features/auth/domain/repositories/auth_repository.dart';
import 'package:qabas/features/auth/presentation/bloc/app_session_bloc.dart';
import 'package:qabas/features/dev_tools/presentation/pages/dev_tools_page.dart';
import 'package:qabas/features/journey/presentation/bloc/journey_bloc.dart';
import 'package:qabas/features/journey/presentation/pages/journey_page.dart';
import 'package:qabas/features/onboarding/domain/entities/onboarding_answers.dart';
import 'package:qabas/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:qabas/features/session/data/dtos/session_dto.dart';
import 'package:qabas/features/session/data/mappers/session_mappers.dart';
import 'package:qabas/features/session/domain/entities/session.dart';
import 'package:qabas/features/session/presentation/bloc/lesson_intro_bloc.dart';
import 'package:qabas/features/session/presentation/bloc/session_player_bloc.dart';
import 'package:qabas/features/session/presentation/pages/lesson_intro_page.dart';
import 'package:qabas/features/session/presentation/pages/session_player_page.dart';
import 'package:qabas/features/session/presentation/steps/content_step_bloc.dart';
import 'package:qabas/features/session/presentation/steps/content_step_views.dart';
import 'package:qabas/mock_backend/mock_backend.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const tourMode = String.fromEnvironment('PHASE5_TOUR');
  const focused = tourMode == 'fidelity' || tourMode == 'ar-fidelity' || tourMode == 'final';
  Future<void> until(WidgetTester t, bool Function() condition) async {
    for (var i = 0; i < 100 && !condition(); i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(condition(), true);
    expect(t.takeException(), isNull);
    await t.pump(const Duration(milliseconds: 600));
  }

  Future<void> tap(WidgetTester t, Finder finder) async {
    await t.ensureVisible(finder);
    await t.pump();
    await t.tap(finder);
    await t.pump(const Duration(milliseconds: 600));
    expect(t.takeException(), isNull);
  }

  Future<void> capture(WidgetTester t, String name) async {
    // Tick each animation frame so stagger timers and controller start times
    // settle before a still is taken on the live integration binding.
    for (var frame = 0; frame < 90; frame++) {
      await t.pump(const Duration(milliseconds: 16));
    }
    await binding.takeScreenshot('phase5/$name');
  }

  LessonIntroBloc intro(WidgetTester t) => t.element(find.byType(LessonIntroPage)).read<LessonIntroBloc>();
  SessionPlayerBloc player(WidgetTester t) => t.element(find.byType(SessionPlayerPage)).read<SessionPlayerBloc>();
  Future<void> entered(WidgetTester t) =>
      until(t, () => find.byType(LessonIntroPage).evaluate().isNotEmpty && intro(t).state.status == LessonIntroStatus.ready);
  Future<void> start(WidgetTester t) async {
    await tap(t, find.byKey(const ValueKey('lesson-start')));
    await until(t, () => find.byType(SessionPlayerPage).evaluate().isNotEmpty && player(t).state.session != null);
  }

  Future<void> leave(WidgetTester t) async {
    await tap(t, find.byKey(const ValueKey('player-close')));
    await tap(t, find.byKey(const ValueKey('leave-lesson')));
    await until(t, () => find.byType(JourneyPage).evaluate().isNotEmpty);
  }

  Future<void> tour(WidgetTester t, String prefix, {int? stopAfterCursor}) async {
    final p = player(t);
    for (var i = 0; i < 80 && p.state.status != PlayerStatus.previewEnded; i++) {
      final item = p.state.item!;
      if (stopAfterCursor != null && p.state.cursor >= stopAfterCursor) return;
      var suffix = '${p.state.cursor}_${item.runtimeType}';
      if (item is StoryItem) {
        final state = t.element(find.byType(StoryStepView)).read<ContentStepBloc>().state;
        suffix += '_beat${state.beat}';
        if (item.origin == null) expect(item.provenance, isNull);
      }
      if (item is TeachItem) suffix += '_shown${t.element(find.byType(TeachStepView)).read<ContentStepBloc>().state.shown}';
      if (p.state.status == PlayerStatus.feedback) {
        await capture(t, '${prefix}_${suffix}_feedback');
        await tap(t, find.byKey(const ValueKey('predict-continue')));
        continue;
      }
      await capture(t, '${prefix}_$suffix');
      if (item is PredictItem) {
        await tap(t, find.byKey(const ValueKey('predict-option-1')));
        await capture(t, '${prefix}_${suffix}_selected');
      }
      await tap(t, find.byKey(const ValueKey('step-cta')));
    }
    expect(p.state.status, PlayerStatus.previewEnded);
    expect(p.state.session!.answeredExercises, 0);
    expect(p.state.completedStepIds.length, p.state.session!.items.where((item) => item is! ExerciseItem).length);
  }

  for (final language in ['en', 'ar']) {
    for (final reduced in [false, true]) {
      if (tourMode == 'final' && reduced != (language == 'ar')) continue;
      if (focused &&
          tourMode != 'final' &&
          (language != (tourMode == 'ar-fidelity' ? 'ar' : 'en') || reduced != (tourMode == 'ar-fidelity'))) {
        continue;
      }
      testWidgets('Phase 5 actual entry and content: $language / $reduced', (t) async {
        final prefix = '${language}_${reduced ? 'reduced' : 'motion'}';
        final store = await PreferencesStore.open();
        await store.clear();
        await store.setString('language', language);
        await store.setBoolean('reduce_motion', reduced);
        final d = await AppDependencies.create(
          config: AppConfig(),
          store: store,
          initialSessionState: const AppSessionState(status: SessionStatus.ready, splashElapsed: true),
        );
        await d.services<TokenStore>().clear();
        final mock = d.services<MockBackend>()..controls.fast = true;
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
          t,
          () =>
              find.byType(JourneyPage).evaluate().isNotEmpty &&
              t.element(find.byType(JourneyPage)).read<JourneyBloc>().state.journey != null,
        );
        {
          final node = find.byWidgetPredicate((w) => w is QJourneyNode && w.node.id == 'les_u0_l1');
          await Scrollable.ensureVisible(t.element(node), alignment: .42);
          await tap(t, node);
          await tap(t, find.byKey(const ValueKey('node-start-les_u0_l1')));
          await entered(t);
          expect(intro(t).state.start!.session.sourceCount, 0);
          expect(intro(t).state.start!.session.reviewedBy, isNull);
          await capture(t, '${prefix}_unit0_intro');
          await start(t);
          await tour(t, '${prefix}_unit0', stopAfterCursor: 5);
          await leave(t);

          // Select the same real path switch used by learners before Discover.
          if (reduced) {
            await tap(t, find.byKey(const ValueKey('journey-path-switch')));
            await tap(t, find.byKey(const ValueKey('track-newMuslim')));
            await until(t, () => mock.db.user!['track'] == 'new_muslim');
          }
          await tap(t, find.byKey(const ValueKey('nav-1')));
          await until(t, () => find.byKey(const ValueKey('discover-les_u1_l1')).evaluate().isNotEmpty);
          await tap(t, find.byKey(const ValueKey('discover-les_u1_l1')));
          await entered(t);
          expect(mock.db.user!['track'], reduced ? 'new_muslim' : 'explorer');
          final u1Expected = SessionDto.fromJson(
            await mock.fixtures.object('test_lessons/u1l1_${language}_${reduced ? 'new_muslim' : 'explorer'}.json'),
          ).toEntity();
          expect(intro(t).state.start!.session.items, u1Expected.items);
          await capture(t, '${prefix}_u1l1_intro');
          await start(t);
          await tour(t, '${prefix}_u1l1');
          await leave(t);
        }
        for (final track in ['explorer', 'new_muslim']) {
          if (focused && track != 'explorer') continue;
          await tap(t, find.byKey(const ValueKey('nav-4')));
          await t.longPress(find.byKey(const ValueKey('profile-avatar')));
          await until(
            t,
            () =>
                find.byType(DevToolsPage).evaluate().isNotEmpty && find.byKey(ValueKey('dev-salah-$language-$track')).evaluate().isNotEmpty,
          );
          await tap(t, find.byKey(ValueKey('dev-salah-$language-$track')));
          await entered(t);
          expect(mock.db.user!['track'], track);
          final expected = SessionDto.fromJson(await mock.fixtures.object('salah/session_salah_${language}_$track.json')).toEntity();
          expect(intro(t).state.start!.session.items, expected.items);
          await capture(t, '${prefix}_${track}_salah_intro');
          await start(t);
          await tour(t, '${prefix}_${track}_salah');
          await leave(t);
        }
        await t.pumpWidget(const SizedBox.shrink());
        await d.dispose();
      });
    }
  }
}
