import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/features/glossary/presentation/glossary_bloc.dart';
import 'package:qabas/features/glossary/presentation/glossary_page.dart';
import 'package:qabas/features/journey/presentation/bloc/journey_bloc.dart';
import 'package:qabas/features/journey/presentation/pages/journey_page.dart';
import 'package:qabas/features/session/data/mappers/exercise_mappers.dart';
import 'package:qabas/features/session/domain/entities/exercise.dart';
import 'package:qabas/features/session/domain/entities/session.dart';
import 'package:qabas/features/session/presentation/bloc/lesson_reader_bloc.dart';
import 'package:qabas/features/session/presentation/bloc/session_player_bloc.dart';
import 'package:qabas/features/session/presentation/bloc/session_result_bloc.dart';
import 'package:qabas/features/session/presentation/exercises/exercise_views.dart';
import 'package:qabas/features/session/presentation/pages/lesson_reader_page.dart';
import 'package:qabas/features/session/presentation/pages/session_player_page.dart';
import 'package:qabas/features/session/presentation/pages/session_result_page.dart';
import 'package:qabas/features/session/presentation/steps/exercise_step_bloc.dart';
import 'package:qabas/features/unit_guide/presentation/unit_guide_bloc.dart';
import 'package:qabas/features/unit_guide/presentation/unit_guide_sheet.dart';

import 'support/tour_harness.dart';

ExerciseStepBloc step(TourHarness h) => h.t.element(find.byType(ExerciseBody)).read<ExerciseStepBloc>();

Future<void> selectAnswer(TourHarness h, AnswerPayload answer) async {
  final b = step(h);
  if (answer is FillsAnswer) {
    for (final e in answer.fills.entries) {
      await h.tap('blank-${e.key}');
      await h.tap('word-${e.value}');
    }
  } else if (b.exercise.type == ExerciseType.whichEvidence) {
    await h.tap('evidence-${(answer as OptionAnswer).optionId}');
  } else if (answer is PinAnswer) {
    await h.tap('pin-${answer.pinId}');
  } else if (answer is RatingAnswer) {
    await h.tap('card-front');
    await h.tap('rating-${answer.rating}');
    return;
  } else {
    b.add(AnswerDraftRestored(answer));
    await h.wait();
  }
  expect(b.state.draft.isComplete, true);
  await h.tap('exercise-cta');
}

Future<void> play(TourHarness h, {bool capture = false}) async {
  final p = h.player;
  var safety = 0;
  while (p.state.status != PlayerStatus.finished && safety++ < 120) {
    final s = p.state;
    if (s.status == PlayerStatus.finishing) {
      await h.until(() => p.state.status == PlayerStatus.finished);
    } else if (s.status == PlayerStatus.feedback) {
      if (capture && s.item is ExerciseItem && (s.item as ExerciseItem).exercise!.type == ExerciseType.timelineOrder) {
        await h.shot('timeline_dates');
      }
      await h.tap(s.item is PredictItem ? 'predict-continue' : 'feedback-continue');
    } else if (s.status == PlayerStatus.retryRound) {
      p.add(const RetryRoundStarted());
      await h.wait();
    } else if (s.item is ExerciseItem) {
      final e = (s.item as ExerciseItem).exercise!, key = h.mock.db.sessionKeys[s.session!.sessionId]![e.id] as Map;
      await h.until(() => find.byType(ExerciseBody).evaluate().length == 1 && step(h).exercise.id == e.id);
      final b = step(h);
      final answer = e.type == ExerciseType.flashcard
          ? const RatingAnswer('good')
          : e.type == ExerciseType.reciteVerse
          ? const SkippedAnswer()
          : e.payload is MapPayload && !b.state.mapAvailable
          ? const UnavailableAnswer()
          : correctAnswer(e.type, (key['answer_key'] as Map).cast<String, dynamic>())!;
      if (capture) await h.shot('practice_${e.type.name}_${e.id}');
      await selectAnswer(h, answer);
      await h.until(() => p.state.item != s.item || p.state.status != s.status);
    } else {
      // Content steps retain their real nested reveal/beat interaction.
      if (s.item is PredictItem && s.status != PlayerStatus.feedback) await h.tap('predict-option-0');
      await h.tap(s.item is PredictItem && s.status == PlayerStatus.feedback ? 'predict-continue' : 'step-cta');
    }
    expect(p.state.failure, isNull);
  }
  expect(p.state.status, PlayerStatus.finished);
  await h.until(
    () =>
        find.byType(SessionResultPage).evaluate().isNotEmpty &&
        h.t.element(find.byType(SessionResultPage)).read<SessionResultBloc>().state.result != null,
  );
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const selected = String.fromEnvironment('PHASE12_CASE');
  const referenceOnly = String.fromEnvironment('PHASE12_GROUP') == 'reference';
  for (final language in ['en', 'ar']) {
    for (final reduced in [false, true]) {
      final name = '${language}_${reduced ? 'reduced' : 'motion'}';
      if (selected.isNotEmpty && !selected.split(',').contains(name)) continue;
      testWidgets('practice, reviews, guide, glossary, reader and assessments $name', (t) async {
        final h = await TourHarness.fresh(t, binding, language, reduced, onboarded: true, group: 'learning', phase: 'phase12');
        await h.until(() => find.byType(JourneyPage).evaluate().isNotEmpty);
        final router = GoRouter.of(t.element(find.byType(JourneyPage)));
        if (!referenceOnly) {
          router.go('/lesson/les_test_all/intro');
          await h.until(() => find.byKey(const ValueKey('lesson-start')).evaluate().isNotEmpty);
          await h.tap('lesson-start');
          await h.until(() => find.byType(SessionPlayerPage).evaluate().isNotEmpty && h.player.state.session != null);
          await play(h, capture: language == 'en' && !reduced);
          await h.shot('practice_complete');
          router.go('/journey');
          await h.until(() => find.byType(JourneyPage).evaluate().isNotEmpty);
        }
        h.mock.db.dueReviews = 3;
        t.element(find.byType(JourneyPage)).read<JourneyBloc>().add(const JourneyRefreshed());
        await h.until(() => find.byKey(const ValueKey('journey-review'), skipOffstage: false).evaluate().isNotEmpty);
        final review = find.byKey(const ValueKey('journey-review'), skipOffstage: false);
        await Scrollable.ensureVisible(t.element(review));
        await h.wait();
        await h.tapFinder(find.descendant(of: review, matching: find.byType(QButton)));
        await h.until(() => find.byKey(const ValueKey('card-front')).evaluate().isNotEmpty);
        await h.shot('40_review_front');
        await h.tap('card-front');
        await h.shot('41_review_back');
        await h.tap('rating-good');
        await h.until(() => find.byKey(const ValueKey('card-front')).evaluate().isNotEmpty);
        await play(h);
        await h.shot('42_review_complete');
        expect(h.mock.db.dueReviews, 0);
        router.go('/review/session?mode=cards');
        await h.until(() => find.byType(JourneyPage).evaluate().isNotEmpty);
        expect(find.byKey(const ValueKey('journey-review'), skipOffstage: false), findsNothing);
        h.mock.db.dueReviews = 3;
        router.go('/review/session?mode=quick');
        await h.until(() => find.byType(SessionPlayerPage).evaluate().isNotEmpty && h.player.state.timerDeadline != null);
        await h.shot('quick_review');
        await play(h);
        await h.shot('quick_complete');
        router.go('/journey');
        await h.until(() => find.byType(JourneyPage).evaluate().isNotEmpty);
        unawaited(router.push('/units/unit_1/guide'));
        await h.until(
          () =>
              find.byType(UnitGuideSheetPage).evaluate().isNotEmpty &&
              t.element(find.byType(UnitGuideSheetPage)).read<UnitGuideBloc>().state.guide != null,
        );
        await h.shot('57_unit_guide');
        router.pop();
        await h.wait();
        router.go('/glossary');
        await h.until(
          () =>
              find.byType(GlossaryPage).evaluate().isNotEmpty &&
              t.element(find.byType(GlossaryPage)).read<GlossaryBloc>().state.status == GlossaryStatus.ready,
        );
        await h.shot('glossary');
        final glossary = t.element(find.byType(GlossaryPage)).read<GlossaryBloc>();
        glossary.add(const GlossaryFilterSelected('new'));
        await h.until(() => glossary.state.status == GlossaryStatus.ready);
        expect(glossary.state.items.every((i) => i.state.name == 'new'), true);
        router.go('/reader/les_u0_l1');
        await h.until(
          () =>
              find.byType(LessonReaderPage).evaluate().isNotEmpty &&
              t.element(find.byType(LessonReaderPage)).read<LessonReaderBloc>().state.lesson != null,
        );
        final answers = h.mock.db.answers.length, xp = h.mock.db.stats!['xp_total'];
        await h.shot('reader');
        final reader = t.element(find.byType(LessonReaderPage)).read<LessonReaderBloc>();
        while (reader.state.cursor + 1 < reader.state.lesson!.items.length) {
          await h.tap('reader-next');
        }
        expect(h.mock.db.answers.length, answers);
        expect(h.mock.db.stats!['xp_total'], xp);
        router.go('/journey');
        await h.until(() => find.byType(JourneyPage).evaluate().isNotEmpty);
        h.mock.db.contractCurriculum = true;
        final journey = t.element(find.byType(JourneyPage)).read<JourneyBloc>(),
            previous = t.element(find.byType(JourneyPage)).read<JourneyBloc>().state.journey;
        journey.add(const JourneyRefreshed());
        await h.until(() => journey.state.status == JourneyStatus.ready && !identical(journey.state.journey, previous));
        final unit = t.element(find.byType(JourneyPage)).read<JourneyBloc>().state.journey!.units.firstWhere((u) => !u.comingSoon);
        for (final kind in ['pretest', 'test']) {
          router.go('/units/${unit.unitId}/$kind');
          await h.until(() => find.byType(SessionPlayerPage).evaluate().isNotEmpty && h.player.state.session != null);
          await h.shot('${kind}_exercise');
          await play(h);
          await h.shot('${kind}_result');
          final result = t.element(find.byType(SessionResultPage)).read<SessionResultBloc>().state.result!;
          expect(result.reviewItems.length, kind == 'test' ? greaterThan(0) : 0);
        }
      });
    }
  }
}
