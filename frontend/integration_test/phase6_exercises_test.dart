import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:qabas/app/app.dart';
import 'package:qabas/app/config/app_config.dart';
import 'package:qabas/app/di/injector.dart';
import 'package:qabas/core/design_system/components/journey_node.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/storage/preferences_store.dart';
import 'package:qabas/core/storage/token_store.dart';
import 'package:qabas/features/auth/domain/repositories/auth_repository.dart';
import 'package:qabas/features/auth/presentation/bloc/app_session_bloc.dart';
import 'package:qabas/features/dev_tools/presentation/pages/dev_tools_page.dart';
import 'package:qabas/features/journey/presentation/bloc/journey_bloc.dart';
import 'package:qabas/features/journey/presentation/pages/journey_page.dart';
import 'package:qabas/features/onboarding/domain/entities/onboarding_answers.dart';
import 'package:qabas/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:qabas/features/session/data/mappers/exercise_mappers.dart';
import 'package:qabas/features/session/domain/entities/exercise.dart';
import 'package:qabas/features/session/domain/entities/session.dart';
import 'package:qabas/features/session/domain/repositories/exercise_repository.dart';
import 'package:qabas/features/session/presentation/bloc/lesson_intro_bloc.dart';
import 'package:qabas/features/session/presentation/bloc/session_player_bloc.dart';
import 'package:qabas/features/session/presentation/exercises/exercise_views.dart';
import 'package:qabas/features/session/presentation/pages/lesson_intro_page.dart';
import 'package:qabas/features/session/presentation/pages/session_player_page.dart';
import 'package:qabas/features/session/presentation/steps/exercise_step_bloc.dart';
import 'package:qabas/mock_backend/mock_backend.dart';
import 'package:qabas/shared/presentation/visuals/builtin/scenes.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const focused = String.fromEnvironment('PHASE6_TOUR') == 'final';
  Future<void> until(WidgetTester t, bool Function() condition) async {
    for (var i = 0; i < 200 && !condition(); i++) {
      await t.pump(const Duration(milliseconds: 80));
    }
    expect(condition(), true);
    expect(t.takeException(), isNull);
    await t.pump(const Duration(milliseconds: 500));
  }

  Future<void> tap(WidgetTester t, Finder finder) async {
    final element = t.element(finder), scrollable = Scrollable.maybeOf(t.element(finder));
    final target = t.getRect(finder), render = scrollable?.context.findRenderObject();
    if (render is RenderBox) {
      final viewport = render.localToGlobal(Offset.zero) & render.size;
      if (target.top < viewport.top || target.bottom > viewport.bottom) {
        await Scrollable.ensureVisible(element, alignment: .5);
      }
    }
    await t.pump();
    await t.tap(finder);
    await t.pump(const Duration(milliseconds: 600));
    expect(t.takeException(), isNull);
  }

  Future<void> capture(WidgetTester t, String name) async {
    // Match the prototype's timeline screenshot pose after placing the last token.
    if (name.contains('_9_categorize_') && (name.endsWith('_selected') || name.endsWith('_feedback'))) {
      await Scrollable.ensureVisible(t.element(find.byType(DayArcScene)), alignment: 0);
      await t.pump();
    }
    for (var frame = 0; frame < 60; frame++) {
      await t.pump(const Duration(milliseconds: 16));
    }
    await binding.takeScreenshot('phase6/$name');
  }

  SessionPlayerBloc player(WidgetTester t) => t.element(find.byType(SessionPlayerPage)).read<SessionPlayerBloc>();
  ExerciseStepBloc exercise(WidgetTester t) => t.element(find.byType(ExerciseBody)).read<ExerciseStepBloc>();
  Future<void> start(WidgetTester t) async {
    await until(
      t,
      () =>
          find.byType(LessonIntroPage).evaluate().isNotEmpty &&
          t.element(find.byType(LessonIntroPage)).read<LessonIntroBloc>().state.status == LessonIntroStatus.ready,
    );
    await tap(t, find.byKey(const ValueKey('lesson-start')));
    await until(t, () => find.byType(SessionPlayerPage).evaluate().isNotEmpty && player(t).state.session != null);
  }

  Future<void> fill(WidgetTester t, Exercise ex, AnswerPayload answer, {String? capturePrefix}) async {
    switch (answer) {
      case RecitationAnswer() || FillsAnswer() || RatingAnswer() || TimeoutAnswer():
        throw StateError('This earlier-phase harness does not use Phase 12 answers');
      case OptionAnswer():
        await tap(t, find.byKey(ValueKey('option-${answer.optionId}')));
      case SegmentAnswer():
        await tap(t, find.byKey(ValueKey('segment-${answer.segmentId}')));
      case PinAnswer():
        await tap(t, find.byKey(ValueKey('pin-${answer.pinId}')));
      case ReasonAnswer():
        await tap(t, find.byKey(ValueKey('truth-${answer.value}')));
        await tap(t, find.byKey(ValueKey('reason-${answer.reasonOptionId}')));
      case PairsAnswer():
        for (final e in answer.pairs.entries) {
          await tap(t, find.byKey(ValueKey('left-${e.key}')));
          await tap(t, find.byKey(ValueKey('right-${e.value}')));
        }
      case AssignmentsAnswer():
        for (final e in answer.assignments.entries) {
          await tap(t, find.byKey(ValueKey('token-${e.key}')));
          if (capturePrefix != null && e.key == answer.assignments.entries.first.key) await capture(t, '${capturePrefix}_token_selected');
          final day = (ex.payload as CategorizePayload).presentation == 'day_arc';
          if (capturePrefix != null && !day && answer.assignments.length >= 3 && e.key == answer.assignments.entries.elementAt(2).key) {
            await capture(t, '${capturePrefix}_prototype_selected');
          }
          await tap(t, find.byKey(ValueKey('${day ? 'slot' : 'category'}-${e.value}')));
          if (capturePrefix != null && e.key == answer.assignments.entries.first.key) await capture(t, '${capturePrefix}_partial');
        }
      case OrderAnswer():
        for (final id in answer.order) {
          await tap(t, find.byKey(ValueKey('token-$id')));
        }
      case SkippedAnswer():
        await tap(t, find.byKey(const ValueKey('recite-meaning')));
        await tap(t, find.byKey(const ValueKey('recite-skip')));
      case UnavailableAnswer():
        throw StateError('Unexpected unavailable map in native fixtures');
    }
    expect(exercise(t).state.draft.isComplete, true, reason: '${ex.type} ${exercise(t).state.draft}');
  }

  Future<void> tour(
    WidgetTester t,
    AppDependencies d,
    String prefix, {
    bool wrongMyth = false,
    bool screenshots = true,
    bool failSubmit = false,
  }) async {
    final p = player(t), mock = d.services<MockBackend>(), id = p.state.session!.sessionId;
    var failed = false, wrong = 0;
    for (var n = 0; n < 200 && p.state.status != PlayerStatus.finished; n++) {
      if (p.state.status == PlayerStatus.retryRound) {
        expect(p.state.progress, 1);
        expect(p.state.retryQueue.length, wrong);
        if (screenshots) await capture(t, '${prefix}_retry_round');
        await tap(t, find.byType(QButton).last);
        continue;
      }
      if (p.state.status == PlayerStatus.finishing) {
        await until(t, () => p.state.status == PlayerStatus.finished);
        break;
      }
      final item = p.state.item!, index = p.state.inRetry ? 'retry${p.state.retryCursor}' : '${p.state.cursor}';
      if (item is! ExerciseItem) {
        if (item is PredictItem && p.state.status != PlayerStatus.feedback) {
          await tap(t, find.byKey(const ValueKey('predict-option-0')));
        }
        final key = p.state.status == PlayerStatus.feedback ? 'predict-continue' : 'step-cta';
        await tap(t, find.byKey(ValueKey(key)));
        continue;
      }
      final ex = item.exercise!;
      if (screenshots) await capture(t, '${prefix}_${index}_${ex.type.name}_empty');
      final key = mock.db.sessionKeys[id]![ex.id] as Map;
      var answer = ex.type == ExerciseType.reciteVerse
          ? const SkippedAnswer()
          : correctAnswer(ex.type, Map<String, dynamic>.from(key['answer_key'] as Map))!;
      final missed = wrongMyth && !p.state.inRetry && ex.framing != null;
      if (missed) {
        answer = OptionAnswer((ex.payload as ChoicePayload).options.firstWhere((o) => o.id != (answer as OptionAnswer).optionId).id);
        wrong++;
      }
      await fill(
        t,
        ex,
        answer,
        capturePrefix: screenshots && prefix.endsWith('_salah') && ex.payload is CategorizePayload
            ? '${prefix}_${index}_${ex.type.name}'
            : null,
      );
      if (screenshots) await capture(t, '${prefix}_${index}_${ex.type.name}_selected');
      if (failSubmit && !failed) mock.controls.offline = true;
      await tap(t, find.byKey(const ValueKey('exercise-cta')));
      if (failSubmit && !failed) {
        await until(t, () => p.state.failure != null);
        expect(exercise(t).state.draft.toPayload(), answer);
        expect(t.widget<ExerciseBody>(find.byType(ExerciseBody)).locked, true);
        if (screenshots) await capture(t, '${prefix}_submit_retry');
        mock.controls.offline = false;
        failed = true;
        await tap(t, find.byKey(const ValueKey('exercise-cta')));
      }
      await until(
        t,
        () => p.state.status == PlayerStatus.feedback || p.state.item?.blockId != item.blockId || p.state.status == PlayerStatus.finished,
      );
      if (p.state.status == PlayerStatus.feedback) {
        expect(p.state.evaluation!.correct, !missed);
        if (missed) expect(p.state.evaluation!.misconception, isNotNull);
        if (p.state.inRetry) expect(p.state.progress, 1);
        if (screenshots) await capture(t, '${prefix}_${index}_${ex.type.name}_feedback');
        await tap(t, find.byKey(const ValueKey('feedback-continue')));
      }
    }
    await until(t, () => p.state.status == PlayerStatus.finished && find.byType(SessionPlayerPage).evaluate().isEmpty);
    expect(d.services<ExerciseRepository>().result(id), isNotNull);
    if (screenshots) await capture(t, '${prefix}_result_placeholder');
    expect((mock.db.sessions[id]!['answers'] as List).cast<Map>().where((h) => h['is_retry'] == true).length, wrong);
    await tap(t, find.byType(QButton).last);
    await until(t, () => find.byType(JourneyPage).evaluate().isNotEmpty);
  }

  for (final language in ['en', 'ar']) {
    for (final reduced in [false, true]) {
      if (focused && reduced != (language == 'ar')) continue;
      testWidgets('Phase 6 full exercises and real entry: $language/$reduced', (t) async {
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
        final router = GoRouter.of(t.element(find.byType(JourneyPage)));
        if (focused) {
          await tap(t, find.byKey(const ValueKey('nav-4')));
          await t.longPress(find.byKey(const ValueKey('profile-avatar')));
          await until(t, () => find.byType(DevToolsPage).evaluate().isNotEmpty);
          await tap(t, find.byKey(ValueKey('dev-salah-$language-explorer')));
          await start(t);
          await tour(t, d, '${prefix}_explorer_salah', wrongMyth: true);
          await t.pumpWidget(const SizedBox.shrink());
          await d.dispose();
          return;
        }
        final node = find.byWidgetPredicate((w) => w is QJourneyNode && w.node.id == 'les_u0_l1');
        await tap(t, node);
        await tap(t, find.byKey(const ValueKey('node-start-les_u0_l1')));
        await start(t);
        await tour(t, d, '${prefix}_unit0_1', failSubmit: true);
        // Seed prerequisites only in the development backend to inspect later types;
        // entry still uses the ordinary intro/session routes and grader.
        mock.db.completedLessons.addAll(List.generate(12, (i) => 'les_u0_l${i + 1}'));
        for (final lesson in [2, 12]) {
          router.go('/lesson/les_u0_l$lesson/intro');
          await start(t);
          await tour(t, d, '${prefix}_unit0_$lesson');
        }
        for (final track in ['explorer', 'new_muslim']) {
          if (track == 'new_muslim') {
            await tap(t, find.byKey(const ValueKey('journey-path-switch')));
            await tap(t, find.byKey(const ValueKey('track-newMuslim')));
            await until(t, () => t.element(find.byType(JourneyPage)).read<JourneyBloc>().state.journey?.track.name == 'newMuslim');
          }
          await tap(t, find.byKey(const ValueKey('nav-1')));
          await tap(t, find.byKey(const ValueKey('discover-les_u1_l1')));
          await start(t);
          await tour(t, d, '${prefix}_${track}_1_1', screenshots: track == 'explorer');
          await tap(t, find.byKey(const ValueKey('nav-4')));
          await t.longPress(find.byKey(const ValueKey('profile-avatar')));
          await until(t, () => find.byType(DevToolsPage).evaluate().isNotEmpty);
          await tap(t, find.byKey(ValueKey('dev-salah-$language-$track')));
          await start(t);
          await tour(t, d, '${prefix}_${track}_salah', wrongMyth: track == 'explorer', screenshots: track == 'explorer');
        }
        await t.pumpWidget(const SizedBox.shrink());
        await d.dispose();
      });
    }
  }
}
