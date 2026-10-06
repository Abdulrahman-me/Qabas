import 'package:qabas/core/network/api_client.dart';
import 'package:qabas/core/network/multipart_request.dart';
import 'package:qabas/features/raqeeb/data/raqeeb_dto.dart';

final class RaqeebRemoteDataSource {
  const RaqeebRemoteDataSource(this.api);
  final ApiClient api;
  Future<ConversationDto> start(String key, Map<String, String?>? context) =>
      api.post('/raqeeb/conversations', body: {'context': context}, idempotencyKey: key, decode: ConversationDto.fromJson);
  Future<ConversationDetailDto> open(String id) =>
      api.get('/raqeeb/conversations/${Uri.encodeComponent(id)}', decode: ConversationDetailDto.fromJson);
  Future<PostMessageResponseDto> send(String id, String text, String key) => api.postMultipart(
    '/raqeeb/conversations/${Uri.encodeComponent(id)}/messages',
    form: MultipartRequest(fields: {'text': text}, files: const []),
    idempotencyKey: key,
    decode: PostMessageResponseDto.fromJson,
  );
  Future<AssistantMessageDto> message(String id) =>
      api.get('/raqeeb/messages/${Uri.encodeComponent(id)}', decode: AssistantMessageDto.fromJson);
  Future<void> rate(String id, String rating) =>
      api.postNoContent('/raqeeb/messages/${Uri.encodeComponent(id)}/feedback', body: {'rating': rating, 'reason': null, 'comment': null});
}
