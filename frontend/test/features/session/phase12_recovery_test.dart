import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qabas/app/config/app_config.dart';
import 'package:qabas/app/di/injector.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/features/session/data/dtos/session_dto.dart';
import 'package:qabas/features/session/data/mappers/exercise_mappers.dart';
import 'package:qabas/features/session/data/mappers/session_mappers.dart';
import 'package:qabas/features/session/domain/entities/exercise.dart';
import 'package:qabas/features/session/domain/entities/session.dart';
import 'package:qabas/features/session/domain/logic/session_recovery.dart';
import 'package:qabas/features/session/domain/usecases/session_actions.dart';
import 'package:qabas/features/session/presentation/bloc/session_player_bloc.dart';
import 'package:qabas/mock_backend/fixtures.dart';
import 'package:qabas/mock_backend/mock_backend.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fakes.dart';
import 'exercise_flow_test.dart' show until;

void main() {
  late AppDependencies d;
  late Session session;
  Future<AppDependencies> create() async {
    final token = MemoryTokens()..value = 'recovery-token';
    final value = await AppDependencies.create(
      config: AppConfig(),
      tokens: token,
      mockFixtures: Fixtures(read: (p) => File(p).readAsString()),
    );
    final mock = value.services<MockBackend>();
    mock.controls.fast = true;
    if (mock.db.user == null) {
      mock.db.tokens.add(token.value!);
      mock.db.user = await mock.fixtures.example('User');
      mock.db.user!['language'] = 'en';
      mock.db.user!['track'] = 'explorer';
    }
    return value;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    d = await create();
    session = (await d.services<StartLessonSession>()('les_u0_l1') as Ok<SessionStart>).value.session;
  });
  tearDown(() => d.dispose());
  Future<SessionPlayerBloc> opened() async {
    final b = d.playerBloc()..add(SessionLoaded(session.sessionId));
    await until(b, () => b.state.session != null);
    return b;
  }

  Future<SessionPlayerBloc> restart(SessionPlayerBloc b) async {
    await b.close();
    await d.dispose();
    d = await create();
    return opened();
  }

  test('cold restart in content, prediction selection and neutral prediction feedback', () async {
    var b = await opened();
    final first = b.state.item!.blockId;
    b = await restart(b);
    expect(b.state.item!.blockId, first);
    while (b.state.item is! PredictItem) {
      final cursor = b.state.cursor;
      b.add(StepCompleted(b.state.item!.blockId));
      await until(b, () => b.state.cursor != cursor);
    }
    final predict = b.state.item as PredictItem;
    b.add(PredictionSelectionSaved(predict.blockId, predict.options.last.optionId));
    await until(b, () => b.state.predictions.isNotEmpty);
    b = await restart(b);
    expect(b.state.predictions[predict.blockId], predict.options.last.optionId);
    b.add(PredictionChecked(predict.blockId));
    await until(b, () => b.state.status == PlayerStatus.feedback);
    b = await restart(b);
    expect(b.state.status, PlayerStatus.feedback);
    expect(b.state.completedStepIds, contains(predict.blockId));
    await b.close();
  });
  test('cold incorrect panel restores exact original evaluation and answer, then interrupted retry is spent once', () async {
    var b = await opened();
    while (b.state.item is! ExerciseItem) {
      final cursor = b.state.cursor;
      b.add(StepCompleted(b.state.item!.blockId));
      await until(b, () => b.state.cursor != cursor);
    }
    final item = b.state.item as ExerciseItem;
    final options = (item.exercise!.payload as ChoicePayload).options;
    final key = d.services<MockBackend>().db.sessionKeys[session.sessionId]![item.exerciseId] as Map;
    final right = (key['answer_key'] as Map)['option_id'];
    final wrong = OptionAnswer(options.firstWhere((o) => o.id != right).id);
    b.add(AnswerChecked(item.exerciseId, wrong, const Duration(seconds: 1)));
    await until(b, () => b.state.status == PlayerStatus.feedback);
    final evaluation = b.state.evaluation;
    b = await restart(b);
    expect(b.state.evaluation, evaluation);
    expect(b.state.answer, wrong);
    expect(b.state.retryQueue.single.exerciseId, item.exerciseId);
    expect(d.services<MockBackend>().db.answers.length, 1);
    b.add(const FeedbackContinued());
    await until(b, () => b.state.status != PlayerStatus.feedback);
    while (b.state.status != PlayerStatus.retryRound) {
      final s = b.state;
      if (s.status == PlayerStatus.feedback) {
        b.add(const FeedbackContinued());
        await until(b, () => b.state.status != PlayerStatus.feedback);
      } else if (s.item is ExerciseItem) {
        final e = (s.item as ExerciseItem).exercise!, key = d.services<MockBackend>().db.sessionKeys[session.sessionId]![e.id] as Map;
        final answer = correctAnswer(e.type, (key['answer_key'] as Map).cast<String, dynamic>())!;
        b.add(AnswerChecked(e.id, answer, Duration.zero));
        await until(b, () => b.state.status == PlayerStatus.feedback);
      } else {
        b.add(StepCompleted(s.item!.blockId));
        await until(b, () => b.state.item != s.item);
      }
    }
    b = await restart(b);
    expect(b.state.status, PlayerStatus.retryRound);
    b.add(const RetryRoundStarted());
    await until(b, () => b.state.inRetry);
    b = await restart(b);
    expect(b.state.inRetry, true);
    expect((b.state.item as ExerciseItem).exerciseId, item.exerciseId);
    b.add(AnswerChecked(item.exerciseId, wrong, Duration.zero));
    await until(b, () => b.state.status == PlayerStatus.feedback);
    b = await restart(b);
    expect(b.state.inRetry, true);
    expect(b.state.evaluation!.correct, false);
    b.add(const FeedbackContinued());
    await until(b, () => b.state.status == PlayerStatus.finished);
    expect(
      (d.services<MockBackend>().db.sessions[session.sessionId]!['answers'] as List).cast<Map>().where((a) => a['is_retry'] == true).length,
      1,
    );
    await b.close();
  });
  test('server commit before feedback checkpoint adds the lost incorrect identity to retries', () async {
    final b = await opened();
    while (b.state.item is! ExerciseItem) {
      final cursor = b.state.cursor;
      b.add(StepCompleted(b.state.item!.blockId));
      await until(b, () => b.state.cursor != cursor);
    }
    final item = b.state.item as ExerciseItem;
    await b.close();
    final key = d.services<MockBackend>().db.sessionKeys[session.sessionId]![item.exerciseId] as Map;
    final right = (key['answer_key'] as Map)['option_id'];
    final wrong = OptionAnswer((item.exercise!.payload as ChoicePayload).options.firstWhere((o) => o.id != right).id);
    await d.services<SubmitAnswer>()(session.sessionId, item.exercise!, wrong, Duration.zero, isRetry: false, immediate: true);
    await d.dispose();
    d = await create();
    final recovered = await opened();
    expect(recovered.state.cursor, greaterThan(session.items.indexOf(item)));
    expect(recovered.state.retryQueue.map((i) => i.exerciseId), [item.exerciseId]);
    expect(d.services<MockBackend>().db.answers.length, 1);
    await recovered.close();
  });
  test('fresh-device algorithm matches all supplied recovery cases, excluding spent, neutral and hidden retries', () async {
    for (final filename in [
      'recovery_after_early_retry.json',
      'history_immediate_active.json',
      'history_end_active.json',
      'history_none_finished.json',
    ]) {
      final j = jsonDecode(await File('assets/mocks/contract/sessions/$filename').readAsString()) as Map<String, dynamic>;
      if (j['items'] == null) continue;
      final s = SessionDto.fromJson(j).toEntity(), r = recoverSession(SessionDto.fromJson(j).toEntity());
      expect(r.cursor, switch (filename) {
        'recovery_after_early_retry.json' => 18,
        'history_immediate_active.json' => 4,
        _ => 2,
      });
      expect(r.retries, isEmpty);
      final retried = s.answers.where((a) => a.isRetry).map((a) => a.exerciseId).toSet();
      expect(r.retries.every((e) => !retried.contains(e.exerciseId)), true);
      expect(r.retries.every((e) => ![ExerciseType.flashcard, ExerciseType.reciteVerse].contains(e.exercise!.type)), true);
      if (s.feedbackMode != FeedbackMode.immediate) expect(r.retries, isEmpty);
    }
  });
  test('version mismatch discards stale local cursor and uses history', () async {
    final store = d.services<SessionCheckpointStore>();
    await store.write(
      session.sessionId,
      (session.lessonVersion ?? 0) + 1,
      SessionCheckpoint(
        cursor: 999,
        stage: 'feedback',
        completed: {},
        retries: [],
        retryCursor: 0,
        inRetry: false,
        combo: 9,
        predictions: {},
      ),
    );
    final b = await opened();
    expect(b.state.cursor, 0);
    expect(b.state.combo, 0);
    await b.close();
  });
}
