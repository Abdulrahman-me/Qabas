import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/core/network/backend_transport.dart';
import 'package:qabas/features/glossary/presentation/glossary_bloc.dart';
import 'package:qabas/features/glossary/presentation/glossary_page.dart';
import 'package:qabas/features/journey/presentation/pages/journey_page.dart';
import 'package:qabas/features/session/data/mappers/exercise_mappers.dart';
import 'package:qabas/features/session/domain/entities/exercise.dart';
import 'package:qabas/features/session/domain/entities/session.dart';
import 'package:qabas/features/session/domain/entities/session_result.dart';
import 'package:qabas/features/session/domain/logic/answer_drafts.dart';
import 'package:qabas/features/session/domain/logic/session_recovery.dart';
import 'package:qabas/features/session/domain/usecases/session_actions.dart';
import 'package:qabas/features/session/presentation/bloc/lesson_reader_bloc.dart';
import 'package:qabas/features/session/presentation/bloc/session_player_bloc.dart';
import 'package:qabas/features/session/presentation/bloc/session_result_bloc.dart';
import 'package:qabas/features/session/presentation/bloc/session_start_bloc.dart';
import 'package:qabas/features/session/presentation/exercises/exercise_views.dart';
import 'package:qabas/features/session/presentation/pages/lesson_reader_page.dart';
import 'package:qabas/features/session/presentation/pages/session_player_page.dart';
import 'package:qabas/features/session/presentation/pages/session_result_page.dart';
import 'package:qabas/features/session/presentation/pages/session_start_page.dart';
import 'package:qabas/features/session/presentation/steps/exercise_step_bloc.dart';
import 'package:qabas/features/unit_guide/presentation/unit_guide_bloc.dart';
import 'package:qabas/features/unit_guide/presentation/unit_guide_sheet.dart';
import 'package:qabas/mock_backend/handlers/mock_learning_catalog.dart';
import 'package:qabas/mock_backend/mock_backend.dart';
import 'package:qabas/mock_backend/mock_router.dart';

import '../journey/journey_responsive_test.dart' show mountJourney, pumpJourney, journeyUntil, journeySizes;
import 'exercise_responsive_test.dart' show exerciseBloc, playerBloc, fillExercise;

void main() {
  testWidgets('nothing_to_review returns to Journey and removes its stale deck', (t) async {
    final d = await mountJourney(t), mock = d.services<MockBackend>();
    final router = GoRouter.of(t.element(find.byType(JourneyPage)));
    mock.db.dueReviews = 0;
    router.go('/review/session?mode=cards');
    await pumpJourney(t);
    await journeyUntil(
      t,
      () => find.byType(JourneyPage).evaluate().isNotEmpty,
      diagnostic: () => find.byType(SessionStartPage).evaluate().isEmpty
          ? 'no start page'
          : '${t.element(find.byType(SessionStartPage)).read<SessionStartBloc>().state.status}/${t.element(find.byType(SessionStartPage)).read<SessionStartBloc>().state.failure}',
    );
    expect(find.byKey(const ValueKey('journey-review'), skipOffstage: false), findsNothing);
    mock.db.dueReviews = 3;
    router.go('/review/session?mode=cards');
    await pumpJourney(t);
    await journeyUntil(
      t,
      () => find.byType(ExerciseBody).evaluate().isNotEmpty,
      diagnostic: () => find.byType(SessionStartPage).evaluate().isEmpty
          ? 'no start page'
          : '${t.element(find.byType(SessionStartPage)).read<SessionStartBloc>().state.status}/${t.element(find.byType(SessionStartPage)).read<SessionStartBloc>().state.failure}',
    );
    final p = playerBloc(t);
    while (p.state.status != PlayerStatus.finished) {
      final b = exerciseBloc(t);
      b.add(const CardFlipped());
      await pumpJourney(t);
      b.add(const RecallRated('good'));
      await pumpJourney(t);
    }
    await journeyUntil(t, () => find.byType(SessionResultPage).evaluate().isNotEmpty);
    router.go('/review/session?mode=cards');
    await pumpJourney(t);
    await journeyUntil(
      t,
      () => find.byType(JourneyPage).evaluate().isNotEmpty,
      diagnostic: () => find.byType(SessionStartPage).evaluate().isEmpty
          ? 'no start page'
          : '${t.element(find.byType(SessionStartPage)).read<SessionStartBloc>().state.status}/${t.element(find.byType(SessionStartPage)).read<SessionStartBloc>().state.failure}',
    );
    await t.pumpWidget(const SizedBox.shrink());
    await pumpJourney(t);
    await t.runAsync(d.dispose);
  });
  testWidgets('glossary paging and glossary/guide/reader request failures recover in a short window', (t) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(320, 400);
    t.platformDispatcher.textScaleFactorTestValue = 1.35;
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    final d = await mountJourney(t), mock = d.services<MockBackend>();
    final router = GoRouter.of(t.element(find.byType(JourneyPage)));
    late Map<String, dynamic> page;
    await t.runAsync(() async {
      page = await mock.fixtures.example('Page[TermCard]');
      await mock.fixtures.example('Guide');
    });
    final rows = [
      for (var n = 0; n < 25; n++) {...(page['items'] as List).first as Map<String, dynamic>, 'term_id': 'paging_$n'},
    ];
    final paged = MockRoute(
      'GET',
      '/glossary',
      (r, _) async => BackendResponse(200, {
        'items': r.query['cursor'] == null ? rows.take(20).toList() : rows.skip(20).toList(),
        'next_cursor': r.query['cursor'] == null ? 'opaque-more' : null,
      }),
    );
    mock.router.routes.insert(0, paged);
    final pending = Completer<BackendResponse>();
    final blocked = MockRoute('GET', '/glossary', (r, _) => pending.future);
    mock.router.routes.insert(0, blocked);
    router.go('/glossary');
    await pumpJourney(t);
    expect(find.byType(QLoadingView), findsOneWidget);
    pending.complete(BackendResponse.error(503, 'internal_error', 'Unavailable'));
    await pumpJourney(t);
    expect(find.byType(QErrorView), findsOneWidget);
    mock.router.routes.remove(blocked);
    t.widget<QErrorView>(find.byType(QErrorView)).onRetry();
    await pumpJourney(t);
    final b = t.element(find.byType(GlossaryPage)).read<GlossaryBloc>();
    await journeyUntil(t, () => b.state.items.length == 20);
    final more = find.byKey(const ValueKey('glossary-more'));
    await t.scrollUntilVisible(more, 250, scrollable: find.byType(Scrollable).last);
    await t.pump();
    await t.tap(more);
    await journeyUntil(t, () => b.state.items.length == 25);
    expect(b.state.cursor, isNull);
    expect(t.takeException(), isNull);
    router.go('/journey');
    await pumpJourney(t);
    final brokenGuide = MockRoute('GET', '/units/{id}/guide', (r, _) async => BackendResponse.error(503, 'internal_error', 'Unavailable'));
    mock.router.routes.insert(0, brokenGuide);
    unawaited(router.push('/units/unit_1/guide'));
    await pumpJourney(t);
    expect(find.byType(QErrorView), findsOneWidget);
    expect(t.takeException(), isNull);
    mock.router.routes.remove(brokenGuide);
    t.widget<QErrorView>(find.byType(QErrorView)).onRetry();
    await journeyUntil(t, () => t.element(find.byType(UnitGuideSheetPage)).read<UnitGuideBloc>().state.guide != null);
    expect(t.takeException(), isNull);
    router.pop();
    await pumpJourney(t);
    final brokenReader = MockRoute('GET', '/lessons/{id}', (r, _) async => BackendResponse.error(503, 'internal_error', 'Unavailable'));
    mock.router.routes.insert(0, brokenReader);
    router.go('/reader/les_u0_l1');
    await pumpJourney(t);
    expect(find.byType(QErrorView), findsOneWidget);
    mock.router.routes.remove(brokenReader);
    t.widget<QErrorView>(find.byType(QErrorView)).onRetry();
    await journeyUntil(t, () => t.element(find.byType(LessonReaderPage)).read<LessonReaderBloc>().state.lesson != null);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
    await pumpJourney(t);
    await t.runAsync(d.dispose);
  });
  for (final language in ['en', 'ar']) {
    for (final reduced in [false, true]) {
      testWidgets('practice fixture renders, grades and retains every draft at all widths $language/$reduced', (t) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = const Size(402, 874);
        t.platformDispatcher.textScaleFactorTestValue = 1.35;
        addTearDown(t.view.resetDevicePixelRatio);
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        final d = await mountJourney(t, locale: language, reduced: reduced), mock = d.services<MockBackend>();
        final router = GoRouter.of(t.element(find.byType(JourneyPage)));
        late Map<String, dynamic> source, keys;
        await t.runAsync(() async {
          source = await mock.fixtures.object('contract/sessions/session_practice_all_types.json');
          keys = await MockLearningCatalog(mock.fixtures, mock.db).keys(source);
          await mock.fixtures.example('Page[TermCard]');
          await mock.fixtures.example('Guide');
        });
        var n = 0;
        for (final item in (source['items'] as List).cast<Map>().where((i) => i['type'] == 'exercise')) {
          final wire = jsonDecode(jsonEncode(source)) as Map<String, dynamic>, id = 'ses_practice_widget_${language}_${reduced}_${n++}';
          final ex = item['exercise'] as Map, key = keys[ex['exercise_id']] as Map;
          wire.addAll({
            'session_id': id,
            'items': [item],
            'total_exercises': 1,
            'counts': {'interactions': 1, 'exercises': 1, 'scored': ex['type'] == 'flashcard' || ex['type'] == 'recite_verse' ? 0 : 1},
          });
          mock.db.sessions[id] = wire;
          mock.db.sessionKeys[id] = {ex['exercise_id'] as String: key};
          router.go('/session/$id');
          await journeyUntil(
            t,
            () =>
                find.byType(ExerciseBody).evaluate().length == 1 &&
                find.byType(SessionPlayerPage).evaluate().length == 1 &&
                playerBloc(t).state.session?.sessionId == id,
          );
          await pumpJourney(t);
          final b = exerciseBloc(t), player = playerBloc(t);
          for (final size in journeySizes) {
            t.view.physicalSize = size;
            await t.pump(const Duration(milliseconds: 600));
            expect(t.takeException(), isNull, reason: '${b.exercise.type}/empty/$size');
            expect(exerciseBloc(t), same(b));
          }
          final AnswerPayload answer;
          if (b.exercise.type == ExerciseType.flashcard) {
            await t.ensureVisible(find.byKey(const ValueKey('card-front')));
            await t.tap(find.byKey(const ValueKey('card-front')));
            await pumpJourney(t);
            expect(find.byKey(const ValueKey('card-back')), findsOneWidget);
            expect((b.state.draft as RatingDraft).flipped, true);
            for (final size in journeySizes) {
              t.view.physicalSize = size;
              await t.pump(const Duration(milliseconds: 600));
              await t.ensureVisible(find.byKey(const ValueKey('rating-good')));
              await t.pump();
              expect(t.takeException(), isNull, reason: 'ratings/$size');
              expect((b.state.draft as RatingDraft).flipped, true);
            }
            await t.tap(find.byKey(const ValueKey('rating-good')));
            await journeyUntil(t, () => player.state.status == PlayerStatus.finished);
            expect(mock.db.answers['$id:${b.exercise.id}:false']!['correct'], true);
            expect(b.state.draft.toPayload(), const RatingAnswer('good'));
            continue;
          } else if (b.exercise.type == ExerciseType.reciteVerse) {
            answer = const SkippedAnswer();
          } else if (b.exercise.payload is MapPayload && !b.state.mapAvailable) {
            answer = const UnavailableAnswer();
          } else {
            answer = correctAnswer(b.exercise.type, (key['answer_key'] as Map).cast<String, dynamic>())!;
          }
          if (answer is FillsAnswer) {
            for (final e in answer.fills.entries) {
              await t.ensureVisible(find.byKey(ValueKey('blank-${e.key}')));
              await t.tap(find.byKey(ValueKey('blank-${e.key}')));
              await pumpJourney(t);
              await t.ensureVisible(find.byKey(ValueKey('word-${e.value}')));
              await t.tap(find.byKey(ValueKey('word-${e.value}')));
              await pumpJourney(t);
            }
          } else if (b.exercise.type == ExerciseType.whichEvidence) {
            final choice = find.byKey(ValueKey('evidence-${(answer as OptionAnswer).optionId}'));
            await t.ensureVisible(choice);
            await t.tap(choice);
            await pumpJourney(t);
          } else if (answer is PinAnswer) {
            if ((b.exercise.payload as MapPayload).presentation == 'map_pins') {
              for (final size in journeySizes) {
                t.view.physicalSize = size;
                await t.pump(QMotion.normal);
                for (final target in (b.exercise.payload as MapPayload).pins) {
                  final marker = find.byKey(ValueKey('pin-${target.id}'));
                  await t.ensureVisible(marker);
                  await t.pump();
                  await t.tapAt(t.getCenter(marker));
                  await t.pump(QMotion.normal);
                  expect((b.state.draft as PinDraft).selected, target.id, reason: 'Nearest geographic pin at $size');
                }
              }
            }
            final pin = find.byKey(ValueKey('pin-${answer.pinId}'));
            await t.ensureVisible(pin);
            await t.pump();
            await t.tapAt(t.getCenter(pin));
            await pumpJourney(t);
          } else {
            await fillExercise(t, answer);
          }
          for (final size in journeySizes) {
            t.view.physicalSize = size;
            await t.pump(const Duration(milliseconds: 600));
            expect(t.takeException(), isNull, reason: '${b.exercise.type}/selected/$size');
            expect(b.state.draft.toPayload(), answer);
            expect(t.getRect(find.byKey(const ValueKey('exercise-cta'))).bottom, lessThanOrEqualTo(size.height));
          }
          await t.tap(find.byKey(const ValueKey('exercise-cta')));
          await journeyUntil(t, () => player.state.status == PlayerStatus.feedback || player.state.status == PlayerStatus.finished);
          if (player.state.status == PlayerStatus.feedback) {
            expect(player.state.evaluation!.correct, answer is UnavailableAnswer ? isNull : true);
            for (final size in journeySizes) {
              t.view.physicalSize = size;
              await t.pump(const Duration(milliseconds: 600));
              expect(t.takeException(), isNull, reason: '${b.exercise.type}/feedback/$size');
              expect(t.getRect(find.byKey(const ValueKey('feedback-continue'))).bottom, lessThanOrEqualTo(size.height));
            }
          }
        }
        expect(n, 16);
        router.go('/glossary');
        await journeyUntil(
          t,
          () =>
              find.byType(GlossaryPage).evaluate().isNotEmpty &&
              t.element(find.byType(GlossaryPage)).read<GlossaryBloc>().state.status == GlossaryStatus.ready,
        );
        final glossary = t.element(find.byType(GlossaryPage)).read<GlossaryBloc>();
        for (final size in journeySizes) {
          t.view.physicalSize = size;
          await t.pump();
          expect(t.takeException(), isNull, reason: 'glossary/$size');
          expect(t.element(find.byType(GlossaryPage)).read<GlossaryBloc>(), same(glossary));
        }
        glossary.add(const GlossaryFilterSelected('mastered'));
        await journeyUntil(t, () => glossary.state.status != GlossaryStatus.loading);
        expect(glossary.state.filter, 'mastered');
        expect(glossary.state.items.every((v) => v.state.name == 'mastered'), true);
        router.go('/journey');
        await pumpJourney(t);
        final guidePush = router.push('/units/unit_1/guide');
        await journeyUntil(
          t,
          () =>
              find.byType(UnitGuideSheetPage).evaluate().isNotEmpty &&
              t.element(find.byType(UnitGuideSheetPage)).read<UnitGuideBloc>().state.guide != null,
        );
        await t.pump(QMotion.page);
        final journeyFades = find.ancestor(of: find.byType(JourneyPage), matching: find.byType(FadeTransition));
        expect(
          t.widgetList<FadeTransition>(journeyFades).every((fade) => fade.opacity.value > 0),
          true,
          reason: 'The modal guide must keep Journey painted behind its barrier',
        );
        for (final size in journeySizes) {
          t.view.physicalSize = size;
          await t.pump();
          expect(t.takeException(), isNull, reason: 'guide/$size');
        }
        router.pop();
        await guidePush;
        final count = mock.db.answers.length, xp = mock.db.stats!['xp_total'];
        await t.runAsync(() async => await mock.fixtures.object('unit0/sessions/session_u0_l01_${language}_explorer.json'));
        router.go('/reader/les_u0_l1');
        await journeyUntil(
          t,
          () =>
              find.byType(LessonReaderPage).evaluate().isNotEmpty &&
              t.element(find.byType(LessonReaderPage)).read<LessonReaderBloc>().state.lesson != null,
        );
        final reader = t.element(find.byType(LessonReaderPage)).read<LessonReaderBloc>();
        for (var cursor = 0; cursor < reader.state.lesson!.items.length; cursor++) {
          for (final size in journeySizes) {
            t.view.physicalSize = size;
            await t.pump();
            expect(t.takeException(), isNull, reason: 'reader/$cursor/$size');
            expect(reader.state.cursor, cursor);
          }
          reader.add(const ReaderItemChanged(1));
          await pumpJourney(t);
        }
        expect(mock.db.answers.length, count);
        expect(mock.db.stats!['xp_total'], xp);
        mock.db.contractCurriculum = true;
        for (final flow in const [
          (SessionKind.review, 'cards', false),
          (SessionKind.review, 'quick', false),
          (SessionKind.pretest, null, false),
          (SessionKind.unitTest, null, false),
          (SessionKind.unitTest, null, true),
        ]) {
          late Session finished;
          await t.runAsync(() async {
            mock.db.dueReviews = flow.$1 == SessionKind.review ? 3 : 0;
            final curriculum = await mock.fixtures.object('contract/curriculum_test/journey_${language}_explorer.json');
            final unitId = ((curriculum['units'] as List).first as Map)['unit_id'] as String;
            finished =
                (await d.services<StartSessionFlow>()(kind: flow.$1, mode: flow.$2, unitId: flow.$1 == SessionKind.review ? null : unitId)
                        as Ok<Session>)
                    .value;
            for (final item in finished.items.whereType<ExerciseItem>()) {
              final e = item.exercise!, key = mock.db.sessionKeys[finished.sessionId]![e.id] as Map;
              final right = e.type == ExerciseType.flashcard
                  ? const RatingAnswer('good')
                  : correctAnswer(e.type, (key['answer_key'] as Map).cast<String, dynamic>())!;
              final answer = flow.$3 && e.payload is ChoicePayload
                  ? OptionAnswer((e.payload as ChoicePayload).options.firstWhere((o) => o.id != (right as OptionAnswer).optionId).id)
                  : right;
              expect(
                await d.services<SubmitAnswer>()(
                  finished.sessionId,
                  e,
                  answer,
                  Duration.zero,
                  isRetry: false,
                  immediate: finished.feedbackMode == FeedbackMode.immediate,
                ),
                isA<Ok<AnswerResponse>>(),
              );
            }
            expect(await d.services<FinishSession>()(finished.sessionId, Duration.zero), isA<Ok<SessionResult>>());
          });
          router.go('/session/${finished.sessionId}/result');
          await pumpJourney(t);
          await journeyUntil(
            t,
            () =>
                find.byType(SessionResultPage).evaluate().isNotEmpty &&
                t.element(find.byType(SessionResultPage)).read<SessionResultBloc>().state.status == SessionResultStatus.ready &&
                t.element(find.byType(SessionResultPage)).read<SessionResultBloc>().state.result?.sessionId == finished.sessionId,
          );
          final resultBloc = t.element(find.byType(SessionResultPage)).read<SessionResultBloc>();
          expect(resultBloc.state.result!.reviewItems.length, flow.$1 == SessionKind.unitTest ? finished.totalExercises : 0);
          if (flow.$1 == SessionKind.unitTest) expect(resultBloc.state.result!.passed, !flow.$3);
          final resultXp = mock.db.stats!['xp_total'];
          for (final size in journeySizes) {
            t.view.physicalSize = size;
            await t.pump(QMotion.page);
            final action = find.byKey(const ValueKey('result-continue'));
            await t.ensureVisible(action);
            await t.pump();
            expect(t.takeException(), isNull, reason: '${flow.$1}/${flow.$3}/result/$size');
            expect(t.getRect(action).bottom, lessThanOrEqualTo(size.height));
            expect(t.element(find.byType(SessionResultPage)).read<SessionResultBloc>(), same(resultBloc));
            expect(mock.db.stats!['xp_total'], resultXp);
          }
        }
        await t.pumpWidget(const SizedBox.shrink());
        await pumpJourney(t);
        await t.runAsync(d.dispose);
      });
    }
  }
  testWidgets('expired persisted quick deadline submits null once and feedback pauses the draining clock', (t) async {
    final d = await mountJourney(t), mock = d.services<MockBackend>();
    mock.db.dueReviews = 3;
    late Session session;
    await t.runAsync(() async {
      session = (await d.services<StartSessionFlow>()(kind: SessionKind.review, mode: 'quick') as Ok<Session>).value;
      await d.services<SessionCheckpointStore>().write(
        session.sessionId,
        session.lessonVersion,
        SessionCheckpoint(
          cursor: 0,
          stage: 'playing',
          completed: {},
          retries: [],
          retryCursor: 0,
          inRetry: false,
          combo: 0,
          predictions: {},
          timerDeadline: DateTime.now().toUtc().subtract(const Duration(seconds: 1)),
        ),
      );
    });
    final router = GoRouter.of(t.element(find.byType(JourneyPage)));
    router.go('/session/${session.sessionId}');
    await journeyUntil(
      t,
      () => find.byType(SessionPlayerPage).evaluate().isNotEmpty && playerBloc(t).state.status == PlayerStatus.feedback,
    );
    final p = playerBloc(t), item = p.state.item as ExerciseItem;
    await t.pump(const Duration(seconds: 21));
    await journeyUntil(t, () => p.state.status == PlayerStatus.feedback);
    expect(p.state.evaluation!.correct, false);
    expect(p.state.answer, isA<TimeoutAnswer>());
    expect(t.widget<ProgressTrack>(find.byKey(const ValueKey('quick-review-timer'))).color, QColors.retry);
    await t.pump(const Duration(seconds: 25));
    await pumpJourney(t);
    expect(mock.db.answers.keys.where((k) => k.contains(item.exerciseId)), hasLength(1));
    expect(p.state.status, PlayerStatus.feedback);
    p.add(const FeedbackContinued());
    await journeyUntil(t, () => p.state.item != item);
    expect(p.state.remaining, greaterThan(const Duration(seconds: 18)));
    await t.pumpWidget(const SizedBox.shrink());
    await pumpJourney(t);
    await t.runAsync(d.dispose);
  });
}
