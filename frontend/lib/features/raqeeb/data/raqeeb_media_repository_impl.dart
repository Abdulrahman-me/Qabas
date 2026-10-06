import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/error/guard.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/core/network/api_client.dart';
import 'package:qabas/core/network/multipart_request.dart';
import 'package:qabas/features/raqeeb/data/raqeeb_dto.dart';
import 'package:qabas/features/raqeeb/data/raqeeb_mappers.dart';
import 'package:qabas/features/raqeeb/domain/raqeeb.dart';
import 'package:qabas/features/raqeeb/domain/raqeeb_media.dart';
import 'package:qabas/shared/domain/entities/media_file.dart';

final class RaqeebMediaRepositoryImpl implements RaqeebMediaRepository {
  const RaqeebMediaRepositoryImpl(this.api);
  final ApiClient api;
  @override
  Future<Result<PostMessageResponse>> send(String id, String text, List<MediaFile> files, String key) => guard(() async {
    if (text.runes.length > 2000) throw const _MediaFailure(RaqeebTextLimitFailure());
    for (final kind in MediaKind.values) {
      if (files.where((f) => f.kind == kind).length > (kind == MediaKind.image ? 3 : 1)) {
        throw _MediaFailure(MediaLimitFailure(kind, count: true));
      }
    }
    for (final f in files) {
      final failure = validateMedia(f);
      if (failure != null) return Future<PostMessageResponse>.error(_MediaFailure(failure));
    }
    final response = await api.postMultipart(
      '/raqeeb/conversations/${Uri.encodeComponent(id)}/messages',
      form: MultipartRequest(
        fields: {if (text.isNotEmpty) 'text': text},
        files: [
          for (final f in files)
            UploadPart(
              field: switch (f.kind) {
                MediaKind.image => 'images',
                MediaKind.document => 'document',
                MediaKind.audio => 'audio',
              },
              filename: f.name,
              mimeType: f.mime,
              bytes: f.bytes,
            ),
        ],
      ),
      idempotencyKey: key,
      decode: PostMessageResponseDto.fromJson,
    );
    return response.toEntity();
  });
  @override
  Future<Result<ConversationPage>> history(String? cursor) => guard(
    () => api.get(
      '/raqeeb/conversations',
      query: {'limit': 20, 'cursor': ?cursor},
      decode: (j) => ConversationPage(
        (j['items'] as List)
            .cast<Map<String, dynamic>>()
            .map(
              (c) => ConversationSummary(
                c['conversation_id'] as String,
                c['title'] as String?,
                c['last_message_preview'] as String?,
                DateTime.parse(c['updated_at'] as String),
              ),
            )
            .toList(),
        j['next_cursor'] as String?,
      ),
    ),
  );
}

final class _MediaFailure implements FailureSource {
  const _MediaFailure(this.failure);
  final Failure failure;
  @override
  Failure toFailure() => failure;
}
