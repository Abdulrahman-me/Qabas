import 'package:equatable/equatable.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/media/media_limits.dart';
export 'package:qabas/core/error/failures.dart' show MediaKind, MediaLimitFailure, MicrophoneDeniedFailure, MediaCaptureFailure;

final class MediaFile extends Equatable {
  MediaFile({required this.name, required this.mime, required this.kind, required List<int> bytes, this.duration})
    : bytes = List.unmodifiable(bytes);
  final String name, mime;
  final MediaKind kind;
  final List<int> bytes;
  final Duration? duration;
  // Don't stringify learner media bytes.
  @override
  bool get stringify => false;
  @override
  List<Object?> get props => [name, mime, kind, bytes, duration];
}

Failure? validateMedia(MediaFile file, {bool recitation = false}) {
  final types = switch (file.kind) {
    MediaKind.image => ['image/jpeg', 'image/png', 'image/webp'],
    MediaKind.document => ['application/pdf', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'],
    MediaKind.audio => ['audio/mp4', 'audio/webm', 'audio/wav', 'audio/mpeg'],
  };
  if (!types.contains(file.mime) || recitation && file.kind != MediaKind.audio) return const UnsupportedMediaFailure();
  final limit = recitation
      ? 5
      : file.kind == MediaKind.image
      ? 8
      : 10;
  if (file.bytes.isEmpty) return const MediaCaptureFailure();
  if (file.bytes.length > limit * 1024 * 1024) return MediaLimitFailure(file.kind, recitation: recitation);
  if (file.kind == MediaKind.audio &&
      (file.duration == null ||
          file.duration! > (recitation ? MediaLimits.recitation : MediaLimits.voice) ||
          file.duration! <= Duration.zero)) {
    return MediaLimitFailure(file.kind, recitation: recitation);
  }
  return null;
}
