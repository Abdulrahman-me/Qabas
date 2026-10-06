import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qabas/app/config/app_config.dart';
import 'package:qabas/app/di/injector.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/core/network/api_client.dart';
import 'package:qabas/features/session/data/dtos/exercise_dto.dart';
import 'package:qabas/features/session/data/dtos/session_dto.dart';
import 'package:qabas/features/session/data/mappers/exercise_mappers.dart';
import 'package:qabas/features/session/data/mappers/session_mappers.dart';
import 'package:qabas/features/session/domain/entities/exercise.dart';
import 'package:qabas/features/session/domain/entities/session.dart';
import 'package:qabas/features/session/domain/entities/session_result.dart';
import 'package:qabas/features/session/domain/logic/answer_drafts.dart';
import 'package:qabas/features/session/domain/repositories/exercise_repository.dart';
import 'package:qabas/features/session/domain/usecases/session_actions.dart';
import 'package:qabas/features/session/presentation/bloc/session_player_bloc.dart';
import 'package:qabas/features/session/presentation/steps/exercise_step_bloc.dart';
import 'package:qabas/mock_backend/fixtures.dart';
import 'package:qabas/mock_backend/handlers/mock_grader.dart';
import 'package:qabas/mock_backend/mock_backend.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fakes.dart';

Future<void> until(SessionPlayerBloc b, bool Function() condition) async {
  for (var n = 0; n < 2000 && !condition(); n++) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  expect(condition(), isTrue, reason: '${b.state.status} ${b.state.cursor} ${b.state.failure}');
}

void main() {
  late AppDependencies d;
  late MockBackend backend;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final token = MemoryTokens()..value = 'exercises-tests';
    d = await AppDependencies.create(
      config: AppConfig(),
      tokens: token,
      mockFixtures: Fixtures(read: (p) => File(p).readAsString()),
    );
    backend = d.services<MockBackend>();
    backend.controls.fast = true;
    backend.db.tokens.add(token.value!);
    backend.db.user = await backend.fixtures.example('User');
    backend.db.user!['language'] = 'en';
    backend.db.user!['track'] = 'explorer';
    backend.db.completedLessons.addAll(List.generate(12, (i) => 'les_u0_l${i + 1}'));
  });
  tearDown(() => d.dispose());
  Future<void> tour(Session session, {bool wrongMyth = false, bool emptyExplanation = false}) async {
    final b = d.playerBloc()..add(SessionLoaded(session.sessionId));
    await until(b, () => b.state.status == PlayerStatus.playing);
    final missed = <String>{};
    for (var n = 0; n < 150 && b.state.status != PlayerStatus.finished; n++) {
      final state = b.state;
      if (state.status == PlayerStatus.retryRound) {
        expect(state.retryQueue.length, missed.length);
        expect(state.progress, 1);
        b.add(const RetryRoundStarted());
        await until(b, () => b.state.status == PlayerStatus.playing);
        continue;
      }
      if (state.status == PlayerStatus.finishing) {
        await until(b, () => b.state.status == PlayerStatus.finished);
        break;
      }
      final item = state.item!;
      if (item is ExerciseItem) {
        final ex = item.exercise!;
        final key = backend.db.sessionKeys[session.sessionId]![ex.id] as Map;
        var answer = ex.type == ExerciseType.reciteVerse
            ? const SkippedAnswer()
            : correctAnswer(ex.type, Map<String, dynamic>.from(key['answer_key'] as Map))!;
        if (wrongMyth && !state.inRetry && ex.framing != null) {
          answer = OptionAnswer((ex.payload as ChoicePayload).options.firstWhere((o) => o.id != (answer as OptionAnswer).optionId).id);
          missed.add(ex.id);
        }
        final progress = state.progress;
        b.add(AnswerChecked(ex.id, answer, const Duration(seconds: 1)));
        await until(
          b,
          () =>
              b.state.status == PlayerStatus.feedback ||
              b.state.item?.blockId != item.blockId ||
              b.state.status == PlayerStatus.finishing ||
              b.state.status == PlayerStatus.finished,
        );
        if (b.state.status == PlayerStatus.feedback) {
          expect(b.state.progress, state.inRetry ? progress : greaterThan(progress));
          if (emptyExplanation) expect(b.state.evaluation!.explanation, isEmpty);
          if (missed.contains(ex.id) && !state.inRetry) {
            expect(b.state.evaluation!.correct, false);
            expect(b.state.evaluation!.misconception, isNotNull);
            expect(b.state.combo, 0);
          }
          if (state.inRetry) {
            expect(b.state.evaluation!.correct, true);
            expect(b.state.progress, 1);
          }
          b.add(const FeedbackContinued());
          await until(b, () => b.state.status != PlayerStatus.feedback);
        }
      } else {
        if (item is PredictItem) {
          final combo = state.combo;
          b.add(PredictionChecked(item.blockId));
          await until(b, () => b.state.status == PlayerStatus.feedback);
          expect(b.state.combo, combo);
        }
        b.add(StepCompleted(item.blockId));
        await until(b, () => b.state.item?.blockId != item.blockId);
      }
    }
    await until(b, () => b.state.status == PlayerStatus.finished);
    expect(b.state.progress, 1);
    if (session.feedbackMode != FeedbackMode.immediate) {
      expect(b.state.combo, 0);
      expect(b.state.retryQueue, isEmpty);
    }
    expect(b.state.result!.total, session.counts.scored);
    expect(d.services<ExerciseRepository>().result(session.sessionId), b.state.result);
    final histories = (backend.db.sessions[session.sessionId]!['answers'] as List).cast<Map>();
    expect(histories.where((h) => h['is_retry'] == true).length, missed.length);
    await b.close();
  }

  for (final lang in ['en', 'ar']) {
    for (final track in ['explorer', 'new_muslim']) {
      test('Salah all 14 steps, clay myth/remediation, once retry and cached finish: $lang/$track', () async {
        await d.locale.languageChanged(lang);
        backend.db.user!['track'] = track;
        final start = (await d.services<StartLessonSession>()('les_u1_l3') as Ok<SessionStart>).value;
        await tour(start.session, wrongMyth: true);
      });
    }
  }
  for (final lang in ['en', 'ar']) {
    for (var lesson = 1; lesson <= 12; lesson++) {
      test('Unit 0.$lesson $lang grades every exercise and finishes', () async {
        await d.locale.languageChanged(lang);
        final start = (await d.services<StartLessonSession>()('les_u0_l$lesson') as Ok<SessionStart>).value;
        await tour(start.session);
      });
    }
  }
  for (final lang in ['en', 'ar']) {
    for (final track in ['explorer', 'new_muslim']) {
      test('1.1 $lang/$track has empty explanation and finishes', () async {
        await d.locale.languageChanged(lang);
        backend.db.user!['track'] = track;
        final start = (await d.services<StartLessonSession>()('les_u1_l1') as Ok<SessionStart>).value;
        await tour(start.session, emptyExplanation: true);
      });
    }
  }
  test('payload drafts serialize exactly, capacity replacement, pairs replace and ordering removes', () async {
    final start = (await d.services<StartLessonSession>()('les_u1_l3') as Ok<SessionStart>).value;
    final types = <ExerciseType>{};
    for (final id in ['les_u1_l3', ...List.generate(12, (i) => 'les_u0_l${i + 1}'), 'les_u1_l1']) {
      final s = (await d.services<StartLessonSession>()(id) as Ok<SessionStart>).value.session;
      for (final item in s.items.whereType<ExerciseItem>()) {
        final ex = item.exercise!;
        types.add(ex.type);
        var draft = AnswerDraft.forPayload(ex.payload);
        expect(draft.isComplete, isFalse);
        final expected = ex.type == ExerciseType.reciteVerse
            ? const SkippedAnswer()
            : correctAnswer(ex.type, Map<String, dynamic>.from((backend.db.sessionKeys[s.sessionId]![ex.id] as Map)['answer_key'] as Map))!;
        draft = completeDraft(draft, expected);
        expect(draft.isComplete, isTrue);
        expect(correctAnswer(ex.type, answerJson(draft.toPayload())), ex.type == ExerciseType.reciteVerse ? isNull : expected);
      }
    }
    expect(types, {
      ExerciseType.mapPlace,
      ExerciseType.multipleChoice,
      ExerciseType.categorize,
      ExerciseType.scenario,
      ExerciseType.reciteVerse,
      ExerciseType.orderSteps,
      ExerciseType.spotError,
      ExerciseType.trueFalseReason,
      ExerciseType.matchPairs,
    });
    final day = start.session.items
        .whereType<ExerciseItem>()
        .map((i) => i.exercise!.payload)
        .whereType<CategorizePayload>()
        .firstWhere((p) => p.presentation == 'day_arc');
    final draft = AssignmentsDraft(day).place(day.items[0].id, day.categories[0].id).place(day.items[1].id, day.categories[0].id);
    expect(draft.assignments.keys, [day.items[1].id]);
    final order = OrderDraft(['a', 'b', 'c']).add('a').add('a').add('x').add('c').remove('a');
    expect(order.order, ['c']);
    final pairs = PairsDraft(['a', 'b']).pair('a', 'x').pair('b', 'x');
    expect(pairs.pairs, {'b': 'x'});
    expect(() => pairs.pairs['a'] = 'y', throwsUnsupportedError);
  });
  test('every grader type accepts its key and reports incorrect/neutral typed details', () async {
    final seen = <String>{};
    for (final lesson in ['les_u1_l3', ...List.generate(12, (i) => 'les_u0_l${i + 1}')]) {
      final session = (await d.services<StartLessonSession>()(lesson) as Ok<SessionStart>).value.session;
      final wire = backend.db.sessions[session.sessionId]!;
      for (final item in (wire['items'] as List).cast<Map>().where((i) => i['type'] == 'exercise')) {
        final ex = Map<String, dynamic>.from(item['exercise'] as Map), type = ex['type'] as String;
        if (!seen.add(type)) continue;
        final key = Map<String, dynamic>.from(backend.db.sessionKeys[session.sessionId]![ex['exercise_id']] as Map);
        final expected = type == 'recite_verse' ? <String, dynamic>{'skipped': true} : Map<String, dynamic>.from(key['answer_key'] as Map);
        final p = ex['payload'] as Map;
        final wrong = switch (type) {
          'multiple_choice' || 'scenario' => {
            'option_id': (p['options'] as List).cast<Map>().firstWhere((o) => o['option_id'] != expected['option_id'])['option_id'],
          },
          'spot_error' => {
            'segment_id': (p['segments'] as List).cast<Map>().firstWhere((o) => o['segment_id'] != expected['segment_id'])['segment_id'],
          },
          'map_place' => {'pin_id': (p['pins'] as List).cast<Map>().firstWhere((o) => o['pin_id'] != expected['pin_id'])['pin_id']},
          'true_false_reason' => {...expected, 'value': !(expected['value'] as bool)},
          'order_steps' => {'order': (expected['order'] as List).reversed.toList()},
          'categorize' => {'assignments': _swapped(expected['assignments'] as List, 'category_id')},
          'match_pairs' => {'pairs': _swapped(expected['pairs'] as List, 'right_id')},
          'recite_verse' => {'skipped': true},
          _ => throw StateError('Unsupported grader test'),
        };
        const grader = MockGrader();
        final correctInput = type == 'recite_verse' ? {'skipped': true} : expected;
        grader.validate(ex, correctInput);
        expect(grader.grade(ex, correctInput, key)['correct'], type == 'recite_verse' ? isNull : true);
        grader.validate(ex, wrong);
        final evaluation = grader.grade(ex, wrong, key);
        expect(evaluation['correct'], type == 'recite_verse' ? isNull : false, reason: type);
        final typed = decodeAnswerResponse(evaluation, ExerciseHeaderDto.fromJson(ex).toEntity().type, immediate: true) as AnswerEvaluation;
        expect(typed.correct, evaluation['correct']);
        expect(typed.masteryChanges, isEmpty);
        expect(typed.termChanges, isEmpty);
        if (type == 'map_place') {
          expect(grader.grade(ex, {'unavailable': true}, key)['correct'], isNull);
        }
      }
    }
    expect(seen.length, 9);
  });
  test('mock validation rejects invalid shapes/IDs and mapping duplicates', () async {
    final s = (await d.services<StartLessonSession>()('les_u1_l3') as Ok<SessionStart>).value.session;
    final wire = backend.db.sessions[s.sessionId]!;
    for (final b in (wire['items'] as List).cast<Map>().where((b) => b['type'] == 'exercise')) {
      final ex = Map<String, dynamic>.from(b['exercise'] as Map);
      expect(() => const MockGrader().validate(ex, {'made_up': 'x'}), throwsFormatException);
      expect(() => const MockGrader().validate(ex, null), throwsFormatException);
    }
  });
  test('concurrent submit replay, changed body replay after finish, rejected order/retries, finish replay', () async {
    final s = (await d.services<StartLessonSession>()('les_u1_l3') as Ok<SessionStart>).value.session, api = d.services<ApiClient>();
    final exercises = s.items.whereType<ExerciseItem>().toList();
    Future<Map<String, dynamic>> submit(ExerciseItem item, Map<String, dynamic> a, {bool retry = false}) => api.post(
      '/sessions/${s.sessionId}/answers',
      body: AnswerSubmitDto(exerciseId: item.exerciseId, answer: a, elapsedMs: 200, isRetry: retry).toJson(),
      decode: (j) => j,
    );
    final second = exercises[1];
    expect(() => submit(second, {'option_id': 'x'}), throwsA(anything));
    final first = exercises.first,
        ex = first.exercise!,
        key = Map<String, dynamic>.from((backend.db.sessionKeys[s.sessionId]![ex.id] as Map)['answer_key'] as Map);
    final responses = await Future.wait([submit(first, key), submit(first, key)]);
    expect(responses[0], responses[1]);
    expect((backend.db.sessions[s.sessionId]!['answers'] as List).length, 1);
    expect(await submit(first, {'wrong': 'body'}), responses[0]);
    expect(() => submit(first, key, retry: true), throwsA(anything));
    for (final item in exercises.skip(1)) {
      final key = backend.db.sessionKeys[s.sessionId]![item.exerciseId] as Map;
      await submit(
        item,
        item.exercise!.type == ExerciseType.reciteVerse ? {'skipped': true} : Map<String, dynamic>.from(key['answer_key'] as Map),
      );
    }
    final result = (await d.services<FinishSession>()(s.sessionId, const Duration(hours: 5)) as Ok<SessionResult>).value;
    expect(result.correct, 6);
    expect(result.total, 6);
    expect(result.duration.inHours, 0);
    expect(await submit(first, {'ignored': 'after finish'}), responses[0]);
    final replay = await api.post('/sessions/${s.sessionId}/finish', body: {'duration_ms': 0}, decode: SessionResultDto.fromJson);
    expect(replay.toEntity(), result);
  });
  for (final mode in ['none', 'end']) {
    test('$mode returns recorded-only, advances without combo/feedback/retries', () async {
      final fixture = await backend.fixtures.object('salah/session_salah_en_explorer.json');
      fixture['session_id'] = 'ses_hidden_$mode';
      fixture['feedback_mode'] = mode;
      backend.db.sessions[fixture['session_id'] as String] = fixture;
      backend.db.sessionKeys[fixture['session_id'] as String] = Map<String, dynamic>.from(
        (await backend.fixtures.object('private/salah_keys_en_explorer.json'))['exercises'] as Map,
      );
      await tour(SessionDto.fromJson(fixture).toEntity());
      final histories = (fixture['answers'] as List).cast<Map>();
      for (final h in histories) {
        expect(h['evaluation'], mode == 'none' ? isNull : isNotNull);
        expect(h['is_retry'], false);
      }
    });
  }
  test('neutral unavailable map completes without accuracy, combo or retry', () async {
    final fixture = await backend.fixtures.object('salah/session_salah_en_explorer.json');
    final item = (fixture['items'] as List).cast<Map>().firstWhere((i) => i['type'] == 'exercise');
    fixture['session_id'] = 'ses_neutral';
    fixture['items'] = [item];
    backend.db.sessions['ses_neutral'] = fixture;
    backend.db.sessionKeys['ses_neutral'] = Map<String, dynamic>.from(
      (await backend.fixtures.object('private/salah_keys_en_explorer.json'))['exercises'] as Map,
    );
    final b = d.playerBloc()..add(const SessionLoaded('ses_neutral'));
    await until(b, () => b.state.status == PlayerStatus.playing);
    b.add(AnswerChecked((item['exercise'] as Map)['exercise_id'] as String, const UnavailableAnswer(), Duration.zero));
    await until(b, () => b.state.status == PlayerStatus.feedback);
    expect(b.state.evaluation!.correct, isNull);
    expect(b.state.combo, 0);
    expect(b.state.retryQueue, isEmpty);
    b.add(const FeedbackContinued());
    await until(b, () => b.state.status == PlayerStatus.finished);
    expect(b.state.result!.total, 0);
    await b.close();
  });
  test('finish failure preserves completion and retries the server finish', () async {
    final fixture = await backend.fixtures.object('salah/session_salah_en_explorer.json');
    fixture['session_id'] = 'ses_finish_failure';
    fixture['items'] = [(fixture['items'] as List).first]; // content hook
    backend.db.sessions['ses_finish_failure'] = fixture;
    final b = d.playerBloc()..add(const SessionLoaded('ses_finish_failure'));
    await until(b, () => b.state.status == PlayerStatus.playing);
    backend.controls.offline = true;
    b.add(StepCompleted(b.state.item!.blockId));
    await until(b, () => b.state.status == PlayerStatus.failure);
    expect(b.state.progress, 1);
    expect(backend.db.results, isEmpty);
    backend.controls.offline = false;
    b.add(const FinishRequested());
    b.add(const FinishRequested());
    await until(b, () => b.state.status == PlayerStatus.finished);
    expect(backend.db.results.length, 1);
    await b.close();
  });
  test('quit and disposal ignore a late answer response', () async {
    final fixture = await backend.fixtures.object('salah/session_salah_en_explorer.json');
    fixture['session_id'] = 'ses_late';
    fixture['items'] = [(fixture['items'] as List).cast<Map>().firstWhere((i) => i['type'] == 'exercise')];
    backend.db.sessions['ses_late'] = fixture;
    for (final dispose in [false, true]) {
      final repo = PendingExercises();
      final b = SessionPlayerBloc(d.services<LoadSession>(), submitAnswer: SubmitAnswer(repo));
      b.add(const SessionLoaded('ses_late'));
      await until(b, () => b.state.status == PlayerStatus.playing);
      final ex = (b.state.item as ExerciseItem).exercise!;
      b.add(AnswerChecked(ex.id, const PinAnswer('pin_river'), Duration.zero));
      await until(b, () => b.state.submitting);
      Future<void>? close;
      if (dispose) {
        close = b.close();
      } else {
        b.add(const QuitConfirmed());
        await until(b, () => b.state.status == PlayerStatus.left);
      }
      repo.pending.complete(Ok(AnswerRecorded(ex.id)));
      if (close != null) await close;
      await Future<void>.delayed(Duration.zero);
      expect(b.state.result, isNull);
      expect(b.state.completedStepIds, isEmpty);
      if (!dispose) {
        expect(b.state.status, PlayerStatus.left);
        await b.close();
      }
    }
  });
  test('map bindings reset or retain exactly the declared state and immutable drafts', () async {
    final fixture = await backend.fixtures.object('salah/session_salah_en_explorer.json');
    final wire = Map<String, dynamic>.from(
      ((fixture['items'] as List).cast<Map>().firstWhere((i) => i['type'] == 'exercise'))['exercise'] as Map,
    );
    final pins = (wire['payload'] as Map)['pins'] as List;
    final first = (pins[0] as Map)['pin_id'] as String, second = (pins[1] as Map)['pin_id'] as String;
    for (final reset in [false, true]) {
      (wire['payload'] as Map)['interaction'] = {
        'bindings': [
          {
            'pin_id': first,
            'set': {'beat': 2},
          },
          {
            'pin_id': second,
            'set': {'focus': 1},
          },
        ],
        'reset_on_deselect': reset,
        'after_evaluation': null,
      };
      final ex = ExerciseHeaderDto.fromJson(wire).toEntity();
      final b = ExerciseStepBloc(ex);
      b.add(const MapAvailabilityChanged(true));
      b.add(ExerciseOptionSelected(first));
      await Future<void>.delayed(Duration.zero);
      expect(b.state.visualParams, {'beat': 2});
      b.add(ExerciseOptionSelected(second));
      await Future<void>.delayed(Duration.zero);
      expect(b.state.visualParams, reset ? {'focus': 1} : {'beat': 2, 'focus': 1});
      b.add(ExerciseOptionSelected(second));
      await Future<void>.delayed(Duration.zero);
      expect(b.state.visualParams, reset ? {} : {'beat': 2, 'focus': 1});
      expect(() => b.state.visualParams['focus'] = 3, throwsUnsupportedError);
      await b.close();
    }
  });
  test('recitation follows player positions, prevents overlapping play and disposes', () async {
    final fixture = await backend.fixtures.object('salah/session_salah_en_explorer.json');
    final wire = Map<String, dynamic>.from(
      ((fixture['items'] as List).cast<Map>().firstWhere(
            (i) => i['type'] == 'exercise' && (i['exercise'] as Map)['type'] == 'recite_verse',
          ))['exercise']
          as Map,
    );
    final playback = PositionPlayback();
    final b = ExerciseStepBloc(ExerciseHeaderDto.fromJson(wire).toEntity(), playback: playback);
    expect(b.state.audioStatus, RecitationPlaybackStatus.idle);
    b.add(const AudioListenPressed());
    b.add(const AudioListenPressed());
    await Future<void>.delayed(Duration.zero);
    expect(playback.plays, 1);
    playback.position!(const Duration(milliseconds: 987));
    await Future<void>.delayed(Duration.zero);
    expect(b.state.position.inMilliseconds, 987);
    expect(b.state.draft.isComplete, false);
    playback.status!(RecitationPlaybackStatus.idle);
    b.add(const RecitationSkipped());
    await Future<void>.delayed(Duration.zero);
    expect(b.state.draft.toPayload(), const SkippedAnswer());
    await b.close();
    expect(playback.disposed, true);
  });
  test('submit failure retains answer and retries safely', () async {
    final s = (await d.services<StartLessonSession>()('les_u1_l3') as Ok<SessionStart>).value.session;
    final b = d.playerBloc()..add(SessionLoaded(s.sessionId));
    await until(b, () => b.state.status == PlayerStatus.playing);
    while (b.state.item is! ExerciseItem) {
      final item = b.state.item!;
      if (item is PredictItem) {
        b.add(PredictionChecked(item.blockId));
        await until(b, () => b.state.status == PlayerStatus.feedback);
      }
      b.add(StepCompleted(item.blockId));
      await until(b, () => b.state.item?.blockId != item.blockId);
    }
    final item = b.state.item as ExerciseItem, key = backend.db.sessionKeys[s.sessionId]![item.exerciseId] as Map;
    final answer = correctAnswer(item.exercise!.type, Map<String, dynamic>.from(key['answer_key'] as Map))!;
    backend.controls.offline = true;
    b.add(AnswerChecked(item.exerciseId, answer, Duration.zero));
    await until(b, () => b.state.failure != null);
    expect(b.state.completedStepIds.contains(item.blockId), isFalse);
    expect(b.state.item, item);
    backend.controls.offline = false;
    b.add(const AnswerSubmitRetried());
    await until(b, () => b.state.status == PlayerStatus.feedback);
    expect(b.state.evaluation!.correct, true);
    expect((backend.db.sessions[s.sessionId]!['answers'] as List).length, 1);
    await b.close();
  });
}

AnswerDraft completeDraft(AnswerDraft d, AnswerPayload a) => switch ((d, a)) {
  (OptionDraft(), final OptionAnswer a) => OptionDraft(a.optionId),
  (ReasonDraft(), final ReasonAnswer a) => ReasonDraft(value: a.value, reason: a.reasonOptionId),
  (SegmentDraft(), final SegmentAnswer a) => SegmentDraft(a.segmentId),
  (PinDraft(), final PinAnswer a) => PinDraft(a.pinId),
  (RecitationDraft(), SkippedAnswer()) => const RecitationDraft(skipped: true),
  (final PairsDraft p, final PairsAnswer a) => PairsDraft(p.ids, pairs: a.pairs),
  (final AssignmentsDraft p, final AssignmentsAnswer a) => AssignmentsDraft(p.payload, assignments: a.assignments),
  (final OrderDraft p, final OrderAnswer a) => OrderDraft(p.ids, order: a.order),
  _ => throw StateError('Draft mismatch'),
};

class PendingExercises implements ExerciseRepository {
  final pending = Completer<Result<AnswerResponse>>();
  @override
  Future<Result<AnswerResponse>> submit(
    String id,
    Exercise exercise,
    AnswerPayload answer,
    Duration elapsed, {
    required bool isRetry,
    required bool immediate,
  }) => pending.future;
  @override
  Future<Result<SessionResult>> finish(String id, Duration duration) => throw UnimplementedError();
  @override
  SessionResult? result(String id) => null;
}

class PositionPlayback implements RecitationPlayback {
  int plays = 0;
  bool disposed = false;
  void Function(Duration)? position;
  void Function(RecitationPlaybackStatus)? status;
  @override
  bool get available => true;
  @override
  Future<void> play(void Function(Duration) position, void Function(RecitationPlaybackStatus) status) async {
    plays++;
    this.position = position;
    this.status = status;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

List<Map<String, dynamic>> _swapped(List rows, String value) {
  final copy = rows.map((r) => Map<String, dynamic>.from(r as Map)).toList();
  final first = copy.first[value], other = copy.indexWhere((r) => r[value] != first);
  final second = copy[other][value];
  copy.first[value] = second;
  copy[other][value] = first;
  return copy;
}
