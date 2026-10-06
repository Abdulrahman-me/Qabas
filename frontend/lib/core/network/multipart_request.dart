import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

/// Upload input for data sources; Dio types stay inside core/network.
final class UploadPart {
  UploadPart({required this.field, required this.filename, required this.mimeType, required List<int> bytes})
    : bytes = Uint8List.fromList(bytes).asUnmodifiableView();
  final String field, filename, mimeType;
  final Uint8List bytes;
}

final class MultipartRequest {
  MultipartRequest({Map<String, String> fields = const {}, required List<UploadPart> files})
    : fields = Map.unmodifiable(fields),
      files = List.unmodifiable(files);
  final Map<String, String> fields;
  final List<UploadPart> files;
  FormData toFormData() => FormData()
    ..fields.addAll(fields.entries)
    ..files.addAll(
      files.map(
        (file) => MapEntry(
          file.field,
          MultipartFile.fromBytes(file.bytes, filename: file.filename, contentType: DioMediaType.parse(file.mimeType)),
        ),
      ),
    );
  // Internal mock transport metadata, never sent as JSON to the API. File
  // hashes distinguish different bytes with the same filename and length.
  Map<String, Object?> get mockBody => {
    'fields': fields,
    'files': [
      for (final file in files)
        {
          'field': file.field,
          'filename': file.filename,
          'mime_type': file.mimeType,
          'length': file.bytes.length,
          'sha256': sha256.convert(file.bytes).toString(),
        },
    ],
  };
  Map<String, Object?> get recordingMockBody => {
    'fields': fields,
    'files': [
      for (var i = 0; i < files.length; i++)
        {...(mockBody['files'] as List)[i] as Map<String, Object?>, if (files[i].field == 'images') 'bytes': files[i].bytes},
    ],
  };
}
