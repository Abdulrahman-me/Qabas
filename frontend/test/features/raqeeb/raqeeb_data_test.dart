import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:qabas/app/config/app_config.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/core/network/api_client.dart';
import 'package:qabas/core/network/backend_transport.dart';
import 'package:qabas/features/raqeeb/data/raqeeb_dto.dart';
import 'package:qabas/features/raqeeb/data/raqeeb_mappers.dart';
import 'package:qabas/features/raqeeb/data/raqeeb_remote_data_source.dart';
import 'package:qabas/features/raqeeb/data/raqeeb_repository_impl.dart';
import 'package:qabas/features/raqeeb/domain/raqeeb.dart';
import 'package:qabas/mock_backend/controls/mock_controls.dart';
import 'package:qabas/mock_backend/fixtures.dart';
import 'package:qabas/mock_backend/mock_backend.dart';
import 'package:qabas/mock_backend/mock_db.dart';
import '../../support/fakes.dart';

Map<String, dynamic> completedJson(String outcome) =>
    jsonDecode(
          File(
            'assets/mocks/examples/RaqeebCompleted__get_raqeeb_messages_message_id__${3 + 'ABCDEFGH'.indexOf(outcome)}.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;
CompletedMessage completed(String outcome) => CompletedMessageDto.fromJson(completedJson(outcome)).toEntity();

void main() {
  for (final outcome in 'ABCDEFGH'.split('')) {
    test('Completed $outcome maps every typed block, input, citation and term immutably', () {
      final json = completedJson(outcome), entity = CompletedMessageDto.fromJson(completedJson(outcome)).toEntity();
      expect(entity.blocks.length, (json['blocks'] as List).length);
      expect(
        entity.classification.questionClass,
        QuestionClass.values['ABCDEFGH'.indexOf(outcome) == 0 ? 0 : [0, 2, 4, 6, 3, 1, 5, 7]['ABCDEFGH'.indexOf(outcome)]],
      );
      expect(entity.citations.length, (json['citations'] as List).length);
      expect(() => entity.blocks.clear(), throwsUnsupportedError);
      expect(() => entity.terms.clear(), throwsUnsupportedError);
      expect(entity, completed(outcome));
    });
  }
  test('Unknown status/block rejects safely; unknown enums retain content; null keys are required', () {
    expect(() => AssistantMessageDto.fromJson({'status': 'future'}), throwsFormatException);
    expect(() => AnswerBlockDto.fromJson({'type': 'future'}), throwsFormatException);
    var json = completedJson('A');
    json['stage'] = 'writing';
    expect(() => CompletedMessageDto.fromJson(json), throwsFormatException);
    json = completedJson('A');
    (json['classification'] as Map)['question_class'] = 'future';
    expect(CompletedMessageDto.fromJson(json).toEntity().classification.questionClass, QuestionClass.unknown);
    json = completedJson('A');
    json.remove('feedback');
    expect(() => CompletedMessageDto.fromJson(json), throwsA(anything));
  });
  test('B preserves explicit fabricated grading and authentic alternative verbatim', () {
    final item = (completed('B').blocks.single as VerificationAnswer).items.single;
    expect(item.status, VerificationStatus.hadithGraded);
    expect(item.hadithGrade!.gradeCategory.name, 'fabricated');
    expect(item.hadithGrade!.gradeLabel, 'باطل');
    expect(item.alternative, isNotNull);
  });
  test('Polling includes an in-flight request in its deadline', () async {
    final transport = RecordingTransport((_) => Completer<BackendResponse>().future);
    final api = ApiClient.create(config: AppConfig(), tokens: MemoryTokens(), platform: 'web', language: () => 'en', mock: transport);
    final repo = RaqeebRepositoryImpl(RaqeebRemoteDataSource(api), timeout: const Duration(milliseconds: 25));
    final values = await repo.watch('slow').toList();
    expect((values.single as Err<AssistantMessage>).failure, isA<RaqeebTimeoutFailure>());
    await api.dispose();
  });
  for (final outcome in [...'ABCDEFGH'.split(''), 'failed']) {
    test('Real HTTP stack outcome $outcome, all stages, idempotent send and feedback', () async {
      final db = MockDb();
      final controls = MockControls()
        ..fast = true
        ..raqeebOutcome = outcome;
      final backend = MockBackend(
        fixtures: Fixtures(read: (p) => File(p).readAsString()),
        controls: controls,
        db: db,
      );
      final tokens = MemoryTokens()..value = 'test';
      db.tokens.add('test');
      final api = ApiClient.create(
        config: AppConfig(),
        tokens: tokens,
        platform: 'web',
        language: () => 'ar',
        mock: backend,
        retryDelay: (_) async {},
      );
      final repo = RaqeebRepositoryImpl(RaqeebRemoteDataSource(api), interval: Duration.zero);
      final key = repo.newActionId(), createKey = repo.newActionId();
      final conversation = (await repo.start(createKey) as Ok<Conversation>).value;
      expect((await repo.start(createKey) as Ok<Conversation>).value.conversationId, conversation.conversationId);
      final sent = (await repo.send(conversation.conversationId, 'سؤال محفوظ', key) as Ok<PostMessageResponse>).value;
      expect((await repo.send(conversation.conversationId, 'سؤال محفوظ', key) as Ok<PostMessageResponse>).value, sent);
      expect((await repo.send(conversation.conversationId, 'different', key) as Err<PostMessageResponse>).failure, isA<ConflictFailure>());
      final conflict =
          (await repo.send(conversation.conversationId, 'second', repo.newActionId()) as Err<PostMessageResponse>).failure
              as ConflictFailure;
      expect(conflict.code, 'answer_in_progress');
      final results = await repo.watch(sent.assistantMessage.messageId).toList();
      expect(
        results.whereType<Ok<AssistantMessage>>().map((r) => r.value).whereType<ProcessingMessage>().map((p) => p.stage),
        containsAll([
          AssistantStage.classifying,
          AssistantStage.retrieving,
          AssistantStage.verifying,
          AssistantStage.writing,
          AssistantStage.adapting,
        ]),
      );
      final terminal = (results.last as Ok<AssistantMessage>).value;
      expect(terminal, outcome == 'failed' ? isA<FailedMessage>() : isA<CompletedMessage>());
      if (terminal is CompletedMessage) {
        expect(await repo.rate(terminal.messageId, AnswerRating.down), isA<Ok<void>>());
        expect(backend.lastRequest!.body, {'rating': 'down', 'reason': null, 'comment': null});
        final detail = (await repo.open(conversation.conversationId) as Ok<ConversationDetail>).value;
        expect((detail.messages.last as CompletedMessage).feedback, AnswerRating.down);
      }
      db.reset();
      expect(await repo.open(conversation.conversationId), isA<Err<ConversationDetail>>());
      expect(db.raqeebMessages, isEmpty);
      await api.dispose();
    });
  }
}
