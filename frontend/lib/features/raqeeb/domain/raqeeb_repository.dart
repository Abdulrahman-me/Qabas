import 'package:qabas/core/error/result.dart';
import 'package:qabas/features/raqeeb/domain/raqeeb.dart';

abstract interface class RaqeebRepository {
  String newActionId();
  Future<Result<Conversation>> start(String actionId, {Map<String, String?>? context});
  Future<Result<ConversationDetail>> open(String id);
  Future<Result<PostMessageResponse>> send(String conversationId, String text, String actionId);
  Stream<Result<AssistantMessage>> watch(String id);
  Future<Result<void>> rate(String id, AnswerRating rating);
}
