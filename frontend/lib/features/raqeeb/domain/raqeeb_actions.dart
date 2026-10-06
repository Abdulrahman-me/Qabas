import 'package:qabas/core/error/result.dart';
import 'package:qabas/features/raqeeb/domain/raqeeb.dart';
import 'package:qabas/features/raqeeb/domain/raqeeb_repository.dart';

final class StartConversation {
  const StartConversation(this.repository);
  final RaqeebRepository repository;
  String newActionId() => repository.newActionId();
  Future<Result<Conversation>> call(String actionId, {Map<String, String?>? context}) => repository.start(actionId, context: context);
}

final class OpenConversation {
  const OpenConversation(this.repository);
  final RaqeebRepository repository;
  Future<Result<ConversationDetail>> call(String id) => repository.open(id);
}

final class SendRaqeebMessage {
  const SendRaqeebMessage(this.repository);
  final RaqeebRepository repository;
  Future<Result<PostMessageResponse>> call(String id, String text, String actionId) => repository.send(id, text, actionId);
}

final class WatchAssistantMessage {
  const WatchAssistantMessage(this.repository);
  final RaqeebRepository repository;
  Stream<Result<AssistantMessage>> call(String id) => repository.watch(id);
}

final class RateAnswer {
  const RateAnswer(this.repository);
  final RaqeebRepository repository;
  Future<Result<void>> call(String id, AnswerRating rating) => repository.rate(id, rating);
}
