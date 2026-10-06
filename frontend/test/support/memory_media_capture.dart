import 'package:qabas/core/error/result.dart';
import 'package:qabas/shared/domain/entities/media_file.dart';
import 'package:qabas/shared/domain/repositories/media_capture.dart';

final class MemoryCapture implements MediaCapture {
  Result<void> permission = const Ok(null);
  int starts = 0, stops = 0, cancelled = 0;
  @override
  Future<Result<MediaFile?>> image({bool camera = false}) async =>
      Ok(MediaFile(name: 'photo.png', mime: 'image/png', kind: MediaKind.image, bytes: [1, 2, 3]));
  @override
  Future<Result<MediaFile?>> document() async =>
      Ok(MediaFile(name: 'book.pdf', mime: 'application/pdf', kind: MediaKind.document, bytes: [1, 2, 3]));
  @override
  Future<Result<void>> startRecording() async {
    starts++;
    return permission;
  }

  @override
  Future<Result<MediaFile>> stopRecording(Duration duration) async {
    stops++;
    return Ok(MediaFile(name: 'voice.m4a', mime: 'audio/mp4', kind: MediaKind.audio, bytes: [1, 2, 3], duration: duration));
  }

  @override
  Future<void> cancelRecording() async {
    cancelled++;
  }

  @override
  Future<void> openSettings() async {}
  @override
  Future<void> dispose() async {
    await cancelRecording();
  }
}
