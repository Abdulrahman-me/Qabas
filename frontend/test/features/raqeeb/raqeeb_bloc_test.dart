import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/core/events/app_event_bus.dart';
import 'package:qabas/core/events/app_events.dart';
import 'package:qabas/features/raqeeb/domain/raqeeb.dart';
import 'package:qabas/features/raqeeb/domain/raqeeb_actions.dart';
import 'package:qabas/features/raqeeb/domain/raqeeb_repository.dart';
import 'package:qabas/features/raqeeb/presentation/bloc/raqeeb_chat_bloc.dart';
import 'raqeeb_data_test.dart' show completed;

class FakeRaqeeb implements RaqeebRepository {
  int keys = 0, creates = 0, cancels = 0;
  final sent = <({String text, String key})>[];
  final controllers = <StreamController<Result<AssistantMessage>>>[];
  Failure? sendFailure, createFailure, rateFailure;
  Completer<Result<PostMessageResponse>>? delayed;
  Completer<void>? cancelGate;
  final conversation = Conversation(
    conversationId: 'c',
    title: null,
    context: null,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
  final processing = ProcessingMessage(messageId: 'a', stage: AssistantStage.received, createdAt: DateTime.utc(2026));
  @override
  String newActionId() => 'key${++keys}';
  @override
  Future<Result<Conversation>> start(String key, {Map<String, String?>? context}) async {
    creates++;
    return createFailure == null ? Ok(conversation) : Err(createFailure!);
  }

  @override
  Future<Result<ConversationDetail>> open(String id) async => Ok(ConversationDetail(conversation: conversation, messages: []));
  @override
  Future<Result<PostMessageResponse>> send(String id, String text, String actionId) async {
    sent.add((text: text, key: actionId));
    return delayed?.future ??
        (sendFailure == null
            ? Ok(
                PostMessageResponse(
                  userMessage: UserMessage(messageId: 'u', text: text, attachments: [], createdAt: DateTime.utc(2026)),
                  assistantMessage: processing,
                ),
              )
            : Err(sendFailure!));
  }

  @override
  Stream<Result<AssistantMessage>> watch(String id) {
    final c = StreamController<Result<AssistantMessage>>(onCancel: () {
      cancels++;
      return cancelGate?.future;
    });
    controllers.add(c);
    return c.stream;
  }

  @override
  Future<Result<void>> rate(String id, AnswerRating rating) async => rateFailure == null ? const Ok(null) : Err(rateFailure!);
  RaqeebChatBloc bloc({AppEventBus? events}) => RaqeebChatBloc(
    start: StartConversation(this),
    open: OpenConversation(this),
    send: SendRaqeebMessage(this),
    watch: WatchAssistantMessage(this),
    rate: RateAnswer(this),
    events: events,
  );
  Future<void> dispose() async {
    for (final c in controllers) {
      unawaited(c.close());
    }
  }
}

Future<void> settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test(
    'Immediate user bubble; composer blocked; stages/completion; send ignored while processing; rating failure retains answer',
    () async {
      final r = FakeRaqeeb();
      final bloc = r.bloc();
      r.delayed = Completer();
      bloc.add(const MessageSent('  question  '));
      await settle();
      expect(bloc.state.status, ChatStatus.sending);
      expect(bloc.state.turns.single.text, 'question');
      expect(bloc.state.busy, true);
      r.delayed!.complete(
        Ok(
          PostMessageResponse(
            userMessage: UserMessage(messageId: 'u', text: 'question', attachments: [], createdAt: DateTime.utc(2026)),
            assistantMessage: r.processing,
          ),
        ),
      );
      await settle();
      bloc.add(const MessageSent('ignored'));
      await settle();
      expect(r.sent.length, 1);
      r.controllers.single.add(Ok(ProcessingMessage(messageId: 'a', stage: AssistantStage.verifying, createdAt: DateTime.utc(2026))));
      await settle();
      expect((bloc.state.turns.single.assistant as ProcessingMessage).stage, AssistantStage.verifying);
      final answer = completed('A');
      r.controllers.single.add(Ok(answer));
      await settle();
      expect(bloc.state.busy, false);
      expect(bloc.state.turns.single.assistant, answer);
      r.rateFailure = const NetworkFailure();
      bloc.add(AnswerRated(answer.messageId, AnswerRating.up));
      await settle();
      expect(bloc.state.ratingFailure, isA<NetworkFailure>());
      expect(bloc.state.turns.single.assistant, answer);
      r.rateFailure = null;
      bloc.add(AnswerRated(answer.messageId, AnswerRating.up));
      await settle();
      expect(bloc.state.ratings[answer.messageId], AnswerRating.up);
      await bloc.close();
      await r.dispose();
    },
  );
  for (final creation in [true, false]) {
    test('Unsent retry preserves bubble/text and action key (creation=$creation)', () async {
      final r = FakeRaqeeb();
      if (creation) {
        r.createFailure = const NetworkFailure();
      } else {
        r.sendFailure = const NetworkFailure();
      }
      final bloc = r.bloc();
      bloc.add(const MessageSent('saved'));
      await settle();
      final turn = bloc.state.turns.single;
      expect(turn.sendFailed, true);
      r.createFailure = null;
      r.sendFailure = null;
      bloc.add(RetryRequested(turn.key));
      await settle();
      expect(bloc.state.turns.length, 1);
      expect(bloc.state.turns.single.text, 'saved');
      expect(r.sent.last.key, turn.key);
      expect(bloc.state.status, ChatStatus.processing);
      await bloc.close();
      await r.dispose();
    });
  }
  for (final timeout in [true, false]) {
    test('Failed/timeout retries post a new message and key (timeout=$timeout)', () async {
      final r = FakeRaqeeb();
      final b = r.bloc();
      b.add(const MessageSent('same question'));
      await settle();
      if (timeout) {
        r.controllers.last.add(const Err(RaqeebTimeoutFailure()));
      } else {
        r.controllers.last.add(
          Ok(
            FailedMessage(
              messageId: 'a',
              stage: AssistantStage.retrieving,
              createdAt: DateTime.utc(2026),
              error: const MessageError(code: MessageErrorCode.upstreamUnavailable, message: 'internal details'),
            ),
          ),
        );
      }
      await settle();
      final key = b.state.turns.single.key;
      b.add(RetryRequested(key));
      await settle();
      expect(r.sent.length, 2);
      expect(r.sent.first.text, r.sent.last.text);
      expect(r.sent.first.key, isNot(r.sent.last.key));
      expect(b.state.turns.length, 2);
      await b.close();
      await r.dispose();
    });
  }
  test('Network poll failure retries polling existing identity; close cancels', () async {
    final r = FakeRaqeeb();
    final bloc = r.bloc();
    bloc.add(const MessageSent('question'));
    await settle();
    r.controllers.last.add(const Err(NetworkFailure()));
    await settle();
    bloc.add(RetryRequested(bloc.state.turns.single.key));
    await settle();
    expect(r.sent.length, 1);
    expect(r.controllers.length, 2);
    await bloc.close();
    expect(r.cancels, 2);
    await r.dispose();
  });
  test('Guest reset discards late send, all learner text and pending polling', () async {
    final bus = AppEventBus(), r = FakeRaqeeb();
    final bloc = r.bloc(events: bus);
    r.delayed = Completer();
    bloc.add(const MessageSent('private text'));
    await settle();
    bus.publish(const GuestSessionCleared());
    await settle();
    r.delayed!.complete(const Err(NetworkFailure()));
    await settle();
    expect(bloc.state.status, ChatStatus.welcome);
    expect(bloc.state.turns, isEmpty);
    expect(bloc.state.draft, isEmpty);
    await bloc.close();
    await bus.dispose();
    await r.dispose();
  });
  test('New question clears immediately and retains typing while old polling cancels', () async {
    final r = FakeRaqeeb();
    final bloc = r.bloc();
    bloc.add(const MessageSent('previous question'));
    await settle();
    r.controllers.last.add(Ok(completed('A')));
    await settle();
    r.cancelGate = Completer<void>();
    bloc.add(const NewConversationRequested());
    await settle();
    expect(bloc.state.status, ChatStatus.welcome);
    expect(bloc.state.turns, isEmpty);
    bloc.add(const ComposerChanged('next question'));
    r.cancelGate!.complete();
    await settle();
    expect(bloc.state.draft, 'next question');
    await bloc.close();
    await r.dispose();
  });
  test('Text limit and empty input never call the API', () async {
    final r = FakeRaqeeb();
    final b = r.bloc();
    b.add(const MessageSent(' '));
    b.add(MessageSent('x' * 2001));
    await settle();
    expect(r.creates, 0);
    expect(r.sent, isEmpty);
    expect(b.state.failure, isA<RaqeebTextLimitFailure>());
    await b.close();
    await r.dispose();
  });
}
