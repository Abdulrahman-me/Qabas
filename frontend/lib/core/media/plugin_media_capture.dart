import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/core/media/temporary_file.dart';
import 'package:qabas/shared/domain/entities/media_file.dart';
import 'package:qabas/shared/domain/repositories/media_capture.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

final class PluginMediaCapture implements MediaCapture {
  AudioRecorder? _recorder;
  String? _path;
  bool _disposed = false;
  @override
  Future<Result<MediaFile?>> image({bool camera = false}) async {
    try {
      final file = await ImagePicker().pickImage(source: camera ? ImageSource.camera : ImageSource.gallery);
      if (file == null || _disposed) return const Ok(null);
      final bytes = await file.readAsBytes();
      final mime = _imageMime(bytes);
      return Ok(MediaFile(name: file.name, mime: mime, kind: MediaKind.image, bytes: bytes));
    } catch (_) {
      return const Err(MediaCaptureFailure());
    }
  }

  String _imageMime(List<int> b) {
    if (b.length > 12) {
      if (b[0] == 0xff && b[1] == 0xd8) return 'image/jpeg';
      if (b[0] == 0x89 && b[1] == 0x50) return 'image/png';
      if (String.fromCharCodes(b.take(4)) == 'RIFF' && String.fromCharCodes(b.sublist(8, 12)) == 'WEBP') return 'image/webp';
    }
    return 'application/octet-stream';
  }

  @override
  Future<Result<MediaFile?>> document() async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'docx']);
      if (result.isEmpty || _disposed) return const Ok(null);
      final file = result.single;
      final bytes = await file.readAsBytes();
      return Ok(
        MediaFile(
          name: file.name,
          mime: file.extension?.toLowerCase() == 'pdf'
              ? 'application/pdf'
              : 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
          kind: MediaKind.document,
          bytes: bytes,
        ),
      );
    } catch (_) {
      return const Err(MediaCaptureFailure());
    }
  }

  @override
  Future<Result<void>> startRecording() async {
    try {
      final recorder = _recorder ??= AudioRecorder();
      if (!await recorder.hasPermission()) return const Err(MicrophoneDeniedFailure());
      if (_disposed) return const Err(MediaCaptureFailure());
      final name = 'qabas_${const Uuid().v4()}.${kIsWeb ? 'webm' : 'm4a'}';
      _path = kIsWeb ? name : '${(await getTemporaryDirectory()).path}/$name';
      await recorder.start(const RecordConfig(encoder: kIsWeb ? AudioEncoder.opus : AudioEncoder.aacLc), path: _path!);
      return const Ok(null);
    } catch (_) {
      await cancelRecording();
      return const Err(MediaCaptureFailure());
    }
  }

  @override
  Future<Result<MediaFile>> stopRecording(Duration duration) async {
    String? saved;
    try {
      saved = await _recorder?.stop();
      if (saved == null) return const Err(MediaCaptureFailure());
      final bytes = await XFile(saved).readAsBytes();
      return Ok(
        MediaFile(
          name: kIsWeb ? 'voice.webm' : 'voice.m4a',
          mime: kIsWeb ? 'audio/webm' : 'audio/mp4',
          kind: MediaKind.audio,
          bytes: bytes,
          duration: duration,
        ),
      );
    } catch (_) {
      return const Err(MediaCaptureFailure());
    } finally {
      for (final path in {?saved, ?_path}) {
        try {
          await removeCaptureFile(path);
        } catch (_) {}
      }
      _path = null;
    }
  }

  @override
  Future<void> cancelRecording() async {
    try {
      await _recorder?.cancel();
    } catch (_) {}
    final path = _path;
    _path = null;
    if (path != null) {
      try {
        await removeCaptureFile(path);
      } catch (_) {}
    }
  }

  @override
  Future<void> openSettings() async {
    if (!kIsWeb) {
      try {
        await openAppSettings();
      } catch (_) {}
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await cancelRecording();
    await _recorder?.dispose();
  }
}
