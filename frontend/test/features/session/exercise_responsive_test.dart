import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/features/journey/presentation/pages/journey_page.dart';
import 'package:qabas/features/session/data/dtos/session_dto.dart';
import 'package:qabas/features/session/data/mappers/exercise_mappers.dart';
import 'package:qabas/features/session/domain/entities/exercise.dart';
import 'package:qabas/features/session/domain/logic/answer_drafts.dart';
import 'package:qabas/features/session/presentation/bloc/session_player_bloc.dart';
import 'package:qabas/features/session/presentation/exercises/exercise_views.dart';
import 'package:qabas/features/session/presentation/pages/session_player_page.dart';
import 'package:qabas/features/session/presentation/steps/exercise_step_bloc.dart';
import 'package:qabas/features/session/presentation/widgets/feedback_panel.dart';
import 'package:qabas/l10n/gen/app_localizations.dart';
import 'package:qabas/mock_backend/mock_backend.dart';

import '../journey/journey_responsive_test.dart' show mountJourney, pumpJourney, journeyUntil, journeySizes;
import 'exercise_flow_test.dart' show PositionPlayback;

ExerciseStepBloc exerciseBloc(WidgetTester t) => t.element(find.byType(ExerciseBody)).read<ExerciseStepBloc>();
SessionPlayerBloc playerBloc(WidgetTester t) => t.element(find.byType(SessionPlayerPage)).read<SessionPlayerBloc>();
Future<void> fillExercise(WidgetTester t, AnswerPayload answer) async {
  final b = exerciseBloc(t);
  switch (answer) {
    case RecitationAnswer() || FillsAnswer() || RatingAnswer() || TimeoutAnswer():
      throw StateError('This earlier-phase harness does not use Phase 12 answers');
    case OptionAnswer():
      b.add(ExerciseOptionSelected(answer.optionId));
    case SegmentAnswer():
      b.add(ExerciseOptionSelected(answer.segmentId));
    case PinAnswer():
      b.add(ExerciseOptionSelected(answer.pinId));
    case ReasonAnswer():
      b.add(TruthSelected(answer.value));
      b.add(ReasonSelected(answer.reasonOptionId));
    case AssignmentsAnswer():
      for (final e in answer.assignments.entries) {
        b.add(TokenPlaced(e.key, e.value));
      }
    case PairsAnswer():
      for (final e in answer.pairs.entries) {
        b.add(TokenSelected(e.key));
        b.add(PairRightSelected(e.value));
      }
    case OrderAnswer():
      for (final id in answer.order) {
        b.add(OrderTokenSelected(id));
      }
    case SkippedAnswer():
      b.add(const RecitationSkipped());
    case UnavailableAnswer():
      b.add(const MapAvailabilityChanged(false));
  }
  await pumpJourney(t);
  expect(b.state.draft.isComplete, true);
}

void main() {
  for (final language in ['en', 'ar']) {
    for (final reduced in [false, true]) {
      testWidgets('all exercise forms retain drafts and feedback across resize: $language/$reduced', (t) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = const Size(402, 874);
        t.platformDispatcher.textScaleFactorTestValue = 1.35;
        addTearDown(t.view.resetDevicePixelRatio);
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        final d = await mountJourney(t, locale: language, reduced: reduced), mock = d.services<MockBackend>();
        final router = GoRouter.of(t.element(find.byType(JourneyPage)));
        final samples = <(Map<String, dynamic>, Map<String, dynamic>, Map<String, dynamic>)>[];
        await t.runAsync(() async {
          final salah = await mock.fixtures.object('salah/session_salah_${language}_explorer.json'),
              keys = await mock.fixtures.object('private/salah_keys_${language}_explorer.json');
          for (final item in (salah['items'] as List).cast<Map>().where((b) => b['type'] == 'exercise')) {
            samples.add((
              salah,
              Map<String, dynamic>.from(item),
              Map<String, dynamic>.from((keys['exercises'] as Map)[(item['exercise'] as Map)['exercise_id']] as Map),
            ));
          }
          final seen = <String>{};
          for (var n = 1; n <= 12; n++) {
            final name = 'session_u0_l${n.toString().padLeft(2, '0')}_${language}_explorer.json';
            final s = await mock.fixtures.object('unit0/sessions/$name'), k = await mock.fixtures.object('private/unit0/$name');
            for (final item in (s['items'] as List).cast<Map>().where((b) => b['type'] == 'exercise')) {
              final ex = item['exercise'] as Map, type = ex['type'] as String, p = ex['payload'] as Map;
              final target = ['true_false_reason', 'match_pairs', 'spot_error', 'order_steps'].contains(type)
                  ? type
                  : type == 'categorize' && (p['categories'] as List).length == 3
                  ? 'three_buckets'
                  : null;
              if (target == null || !seen.add(target)) continue;
              final id = ex['exercise_id'];
              samples.add((
                s,
                Map<String, dynamic>.from(item),
                {'answer_key': (k['answers'] as Map)[id], ...Map<String, dynamic>.from((k['feedback'] as Map)[id] as Map)},
              ));
            }
          }
        });
        var index = 0;
        for (final (source, item, key) in samples) {
          final fixture = jsonDecode(jsonEncode(source)) as Map<String, dynamic>;
          final id = 'ses_widget_${language}_${reduced}_${index++}';
          fixture['session_id'] = id;
          fixture['items'] = [item];
          fixture['counts'] = {'interactions': 1, 'exercises': 1, 'scored': (item['exercise'] as Map)['type'] == 'recite_verse' ? 0 : 1};
          fixture['total_exercises'] = 1;
          fixture['answered_exercises'] = 0;
          fixture['answers'] = <Object>[];
          mock.db.sessions[id] = fixture;
          mock.db.sessionKeys[id] = {(item['exercise'] as Map)['exercise_id'] as String: key};
          router.go('/session/$id');
          await journeyUntil(t, () => find.byType(ExerciseBody).evaluate().isNotEmpty && playerBloc(t).state.session?.sessionId == id);
          final b = exerciseBloc(t), p = playerBloc(t), ex = b.exercise;
          for (final size in journeySizes) {
            t.view.physicalSize = size;
            await t.pump(const Duration(milliseconds: 600));
            expect(t.takeException(), isNull, reason: 'empty/${ex.type}/$size');
            expect(t.getRect(find.byKey(const ValueKey('exercise-cta'))).bottom, lessThanOrEqualTo(size.height));
          }
          var expected = ex.type == ExerciseType.reciteVerse
              ? const SkippedAnswer()
              : correctAnswer(ex.type, Map<String, dynamic>.from(key['answer_key'] as Map))!;
          if (ex.framing != null) {
            expected = OptionAnswer(
              (ex.payload as ChoicePayload).options.firstWhere((o) => o.id != (expected as OptionAnswer).optionId).id,
            );
          }
          await fillExercise(t, expected);
          for (final size in journeySizes) {
            t.view.physicalSize = size;
            await t.pump(const Duration(milliseconds: 600));
            expect(t.takeException(), isNull, reason: 'selected/${ex.type}/$size');
            expect(b.state.draft.toPayload(), expected);
            expect(t.getRect(find.byKey(const ValueKey('exercise-cta'))).bottom, lessThanOrEqualTo(size.height));
          }
          await t.tap(find.byKey(const ValueKey('exercise-cta')));
          await pumpJourney(t);
          if (ex.type == ExerciseType.reciteVerse) {
            expect(p.state.status, PlayerStatus.finished);
            expect(p.state.progress, 1);
            expect(find.byType(FeedbackPanel), findsNothing);
          } else {
            expect(p.state.status, PlayerStatus.feedback);
            expect(p.state.evaluation!.correct, ex.framing == null);
            for (final size in journeySizes) {
              t.view.physicalSize = size;
              await t.pump(const Duration(milliseconds: 600));
              expect(t.takeException(), isNull, reason: 'feedback/${ex.type}/$size');
              expect(t.getRect(find.byKey(const ValueKey('feedback-continue'))).bottom, lessThanOrEqualTo(size.height));
              expect(b.state.draft.toPayload(), expected);
            }
          }
        }
        await t.pumpWidget(const SizedBox.shrink());
        await t.runAsync(d.dispose);
        await pumpJourney(t);
      });
    }
  }
  testWidgets('available recitation highlights only the actual playing word and clears on completion', (t) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(402, 874);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetPhysicalSize);
    final d = await mountJourney(t, pump: false), mock = d.services<MockBackend>();
    final content = d.contentBloc();
    final source = (await t.runAsync(() => mock.fixtures.object('salah/session_salah_en_explorer.json')))!;
    final wire = Map<String, dynamic>.from(
      ((source['items'] as List).cast<Map>().firstWhere(
            (item) => item['type'] == 'exercise' && (item['exercise'] as Map)['type'] == 'recite_verse',
          ))['exercise']
          as Map,
    );
    final payload = wire['payload'] as Map, words = (payload['text_uthmani'] as String).split(RegExp(r'\s+'));
    (payload['audio'] as Map)['words'] = [
      for (var i = 0; i < 2; i++)
        {
          'ayah': payload['ayah'],
          'position': (payload['word_start'] as int) + i,
          'text': words[i],
          'start_ms': i * 400,
          'end_ms': (i + 1) * 400,
        },
    ];
    final ex = ExerciseHeaderDto.fromJson(wire).toEntity();
    for (final reduced in [false, true]) {
      final playback = PositionPlayback();
      // The same callback surface used by the real audio adapter; no clock-driven word changes.
      final bloc = ExerciseStepBloc(ex, playback: playback);
      await t.pumpWidget(
        MaterialApp(
          theme: QTheme.light(arabic: false),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: MediaQueryData(size: const Size(402, 874), disableAnimations: reduced),
            child: BlocProvider.value(
              value: content,
              child: BlocProvider.value(
                value: bloc,
                child: Scaffold(
                  body: BlocBuilder<ExerciseStepBloc, ExerciseStepState>(
                    builder: (c, state) => ExerciseBody(exercise: ex, state: state, evaluation: null, locked: false),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await pumpJourney(t);
      Text word(int i) => t.widget<Text>(find.byKey(ValueKey('recite-word-$i')));
      expect(word(0).style!.color, QColors.deepInk);
      bloc.add(const AudioListenPressed());
      await pumpJourney(t);
      playback.position!(const Duration(milliseconds: 550));
      await pumpJourney(t);
      expect(word(0).style!.color, QColors.deepInk);
      expect(word(1).style!.color, QColors.gold800);
      final scale = t.widget<AnimatedScale>(
        find.ancestor(of: find.byKey(const ValueKey('recite-word-1')), matching: find.byType(AnimatedScale)).first,
      );
      expect(scale.scale, reduced ? 1 : QExercise.reciteScale);
      expect(bloc.state.draft.isComplete, false);
      playback.status!(RecitationPlaybackStatus.idle);
      await pumpJourney(t);
      expect(word(1).style!.color, QColors.deepInk);
      await t.pumpWidget(const SizedBox.shrink());
      await t.runAsync(bloc.close);
      expect(playback.disposed, true);
    }
    await t.runAsync(content.close);
    await t.runAsync(d.dispose);
    await pumpJourney(t);
  });
  testWidgets('outgoing exercise actions stay hidden and never receive the next evaluation', (t) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(402, 874);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetPhysicalSize);
    final d = await mountJourney(t), mock = d.services<MockBackend>();
    final router = GoRouter.of(t.element(find.byType(JourneyPage)));
    late Map<String, dynamic> source, template;
    await t.runAsync(() async {
      source = await mock.fixtures.object('salah/session_salah_en_explorer.json');
      template = Map<String, dynamic>.from(
        (source['items'] as List).cast<Map>().firstWhere(
          (item) => item['type'] == 'exercise' && (item['exercise'] as Map)['type'] == 'multiple_choice',
        ),
      );
    });
    final items = <Map<String, dynamic>>[], keys = <String, dynamic>{};
    for (var n = 0; n < 2; n++) {
      final item = jsonDecode(jsonEncode(template)) as Map<String, dynamic>, ex = item['exercise'] as Map;
      item['block_id'] = 'transition_block_$n';
      ex['exercise_id'] = 'transition_exercise_$n';
      ex['framing'] = null;
      final options = ((ex['payload'] as Map)['options'] as List).cast<Map>();
      for (var i = 0; i < options.length; i++) {
        options[i]['option_id'] = 'transition_option_${n}_$i';
      }
      items.add(item);
      keys[ex['exercise_id'] as String] = {
        'answer_key': {'option_id': options.first['option_id']},
        'explanation': <Object>[],
      };
    }
    const id = 'ses_transition';
    source.addAll({
      'session_id': id,
      'items': items,
      'counts': {'interactions': 2, 'exercises': 2, 'scored': 2},
      'total_exercises': 2,
      'answered_exercises': 0,
      'answers': <Object>[],
    });
    mock.db.sessions[id] = source;
    mock.db.sessionKeys[id] = keys;
    router.go('/session/$id');
    await journeyUntil(t, () => find.byType(ExerciseBody).evaluate().isNotEmpty);
    await pumpJourney(t);
    final p = playerBloc(t);
    p.add(const AnswerChecked('transition_exercise_0', OptionAnswer('transition_option_0_1'), Duration.zero));
    await journeyUntil(t, () => p.state.status == PlayerStatus.feedback);
    await pumpJourney(t);
    p.add(const FeedbackContinued());
    await journeyUntil(t, () => p.state.item?.blockId == 'transition_block_1');
    // Submit without allowing the outgoing step's 520 ms transition to finish.
    p.add(const AnswerChecked('transition_exercise_1', OptionAnswer('transition_option_1_1'), Duration.zero));
    await journeyUntil(t, () => p.state.status == PlayerStatus.feedback);
    expect(find.byType(ExerciseBody), findsNWidgets(2));
    for (final body in t.widgetList<ExerciseBody>(find.byType(ExerciseBody))) {
      expect(body.evaluation?.exerciseId, body.exercise.id == 'transition_exercise_1' ? body.exercise.id : isNull);
    }
    expect(t.takeException(), isNull);
    await t.pump(const Duration(milliseconds: 100));
    expect(
      find
          .descendant(of: find.byKey(const ValueKey('transition_block_0/false')), matching: find.byKey(const ValueKey('exercise-cta')))
          .hitTestable(),
      findsNothing,
    );
    await pumpJourney(t);
    expect(find.byKey(const ValueKey('feedback-continue')).hitTestable(), findsOneWidget);
    expect(find.byType(ExerciseBody), findsOneWidget);
    await t.pumpWidget(const SizedBox.shrink());
    await t.runAsync(d.dispose);
    await pumpJourney(t);
  });
  testWidgets('true/false two-stage taps and three-bucket tap, drag, replace, remove', (t) async {
    // The complete matrix above covers every draft; this pass uses physical taps
    // and a drag on the same public widgets instead of dispatching draft events.
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(402, 874);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetPhysicalSize);
    final d = await mountJourney(t, reduced: true), mock = d.services<MockBackend>();
    final router = GoRouter.of(t.element(find.byType(JourneyPage)));
    final fixture = (await t.runAsync(() => mock.fixtures.object('unit0/sessions/session_u0_l01_en_explorer.json')))!;
    final item = (fixture['items'] as List).cast<Map>().firstWhere(
      (b) => b['type'] == 'exercise' && (b['exercise'] as Map)['type'] == 'categorize',
    );
    fixture['items'] = [item];
    mock.db.sessions[fixture['session_id'] as String] = fixture;
    router.go('/session/${fixture['session_id']}');
    await journeyUntil(t, () => find.byType(ExerciseBody).evaluate().isNotEmpty);
    final b = exerciseBloc(t), payload = b.exercise.payload as CategorizePayload;
    await t.tap(find.byKey(ValueKey('token-${payload.items[0].id}')));
    await pumpJourney(t);
    expect(b.state.selected, payload.items[0].id);
    final bucket = find.byKey(ValueKey('category-${payload.categories[0].id}'));
    await t.tap(bucket);
    await pumpJourney(t);
    expect((b.state.draft as AssignmentsDraft).assignments[payload.items[0].id], payload.categories[0].id);
    final token = find.byKey(ValueKey('token-${payload.items[1].id}'));
    await Scrollable.ensureVisible(t.element(token), alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd);
    await t.pump();
    final gesture = await t.startGesture(t.getCenter(token));
    await gesture.moveBy(const Offset(-24, 0));
    await t.pump();
    await gesture.moveTo(t.getCenter(find.byKey(ValueKey('category-${payload.categories[1].id}'))));
    await t.pump();
    await gesture.up();
    await pumpJourney(t);
    expect((b.state.draft as AssignmentsDraft).assignments[payload.items[1].id], payload.categories[1].id);
    await Scrollable.ensureVisible(t.element(find.byKey(ValueKey('token-${payload.items[2].id}'))), alignment: .5);
    await t.pump();
    await t.tap(find.byKey(ValueKey('token-${payload.items[2].id}')));
    await pumpJourney(t);
    // Tap the filled group's centre, including its placed-token surface.
    await Scrollable.ensureVisible(t.element(bucket), alignment: .5);
    await t.pump();
    await t.tap(bucket);
    await pumpJourney(t);
    expect((b.state.draft as AssignmentsDraft).assignments[payload.items[2].id], payload.categories[0].id);
    expect((b.state.draft as AssignmentsDraft).assignments[payload.items[0].id], payload.categories[0].id);
    await Scrollable.ensureVisible(t.element(find.byKey(ValueKey('token-${payload.items[0].id}')).first), alignment: .5);
    await t.pump();
    await t.tap(find.byKey(ValueKey('token-${payload.items[0].id}')).first);
    await pumpJourney(t);
    expect((b.state.draft as AssignmentsDraft).assignments.containsKey(payload.items[0].id), false);
    final reasonFixture = (await t.runAsync(() => mock.fixtures.object('unit0/sessions/session_u0_l02_en_explorer.json')))!;
    final reasonItem = (reasonFixture['items'] as List).cast<Map>().firstWhere(
      (i) => i['type'] == 'exercise' && (i['exercise'] as Map)['type'] == 'true_false_reason',
    );
    reasonFixture['items'] = [reasonItem];
    mock.db.sessions[reasonFixture['session_id'] as String] = reasonFixture;
    router.go('/session/${reasonFixture['session_id']}');
    await journeyUntil(
      t,
      () => find.byType(ExerciseBody).evaluate().isNotEmpty && playerBloc(t).state.session?.sessionId == reasonFixture['session_id'],
    );
    final reasonBloc = exerciseBloc(t), reason = reasonBloc.exercise.payload as ReasonPayload;
    await t.tap(find.byKey(const ValueKey('truth-false')));
    await pumpJourney(t);
    expect((reasonBloc.state.draft as ReasonDraft).value, false);
    expect(reasonBloc.state.draft.isComplete, false);
    final reasonTile = find.byKey(ValueKey('reason-${reason.reasons.first.id}'));
    await Scrollable.ensureVisible(t.element(reasonTile), alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd);
    final focusChild = find.descendant(of: reasonTile, matching: find.byType(GestureDetector)).first;
    Focus.of(t.element(focusChild)).requestFocus();
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await pumpJourney(t);
    expect(reasonBloc.state.draft.isComplete, true);
    await t.tap(find.byKey(const ValueKey('truth-true')));
    await pumpJourney(t);
    expect((reasonBloc.state.draft as ReasonDraft).value, true);
    expect((reasonBloc.state.draft as ReasonDraft).reason, isNull);
    expect(reasonBloc.state.draft.isComplete, false);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
    await t.runAsync(d.dispose);
    await pumpJourney(t);
  });
}
