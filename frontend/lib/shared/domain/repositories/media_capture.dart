import 'package:qabas/core/error/result.dart';
import 'package:qabas/shared/domain/entities/media_file.dart';

abstract interface class MediaCapture {
  Future<Result<MediaFile?>> image({bool camera = false});
  Future<Result<MediaFile?>> document();
  Future<Result<void>> startRecording();
  Future<Result<MediaFile>> stopRecording(Duration duration);
  Future<void> cancelRecording();
  Future<void> openSettings();
  Future<void> dispose();
}
