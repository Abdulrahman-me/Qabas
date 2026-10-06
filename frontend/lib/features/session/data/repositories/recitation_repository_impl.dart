import 'dart:async';
import 'package:qabas/core/design_system/tokens/tokens.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/error/guard.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/core/network/api_client.dart';
import 'package:qabas/core/network/idempotency_key.dart';
import 'package:qabas/core/network/multipart_request.dart';
import 'package:qabas/features/session/data/dtos/recitation_dto.dart';
import 'package:qabas/features/session/domain/entities/exercise.dart';
import 'package:qabas/features/session/domain/entities/recitation.dart';
import 'package:qabas/shared/domain/entities/media_file.dart';

final class RecitationRepositoryImpl implements RecitationRepository {
  const RecitationRepositoryImpl(this.api, {required this.enabled});
  final ApiClient api;
  @override
  final bool enabled;
  @override
  String newActionId() => newIdempotencyKey();
  @override
  Future<Result<RecitationCheck>> check(Exercise exercise, MediaFile audio, String key) async {
    final failure = validateMedia(audio, recitation: true);
    if (failure != null) return Err(failure);
    if (!enabled) return const Err(UpstreamUnavailableFailure());
    return guard(() async {
      final p = exercise.payload as RecitePayload;
      try {
        return (await api
                .postMultipart(
                  '/recitation/checks',
                  form: MultipartRequest(
                    fields: {
                      'surah': '${p.surah}',
                      'ayah': '${p.ayah}',
                      if (p.wordStart != null) 'word_start': '${p.wordStart}',
                      if (p.wordEnd != null) 'word_end': '${p.wordEnd}',
                      'exercise_id': exercise.id,
                    },
                    files: [UploadPart(field: 'audio', filename: audio.name, mimeType: audio.mime, bytes: audio.bytes)],
                  ),
                  idempotencyKey: key,
                  decode: RecitationCheckDto.fromJson,
                )
                .timeout(QMedia.checkTimeout))
            .toEntity();
      } on TimeoutException {
        throw const _CheckTimedOut();
      }
    });
  }
}

final class _CheckTimedOut implements FailureSource {
  const _CheckTimedOut();
  @override
  Failure toFailure() => const UpstreamUnavailableFailure();
}
