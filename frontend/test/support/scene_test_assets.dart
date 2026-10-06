import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:qabas_scene/qabas_scene.dart';

SceneCache sceneTestCache() => SceneCache(loadBytes: sceneTestBytes);
Future<Uint8List> sceneTestBytes(String url) async {
  final path = Uri.parse(url).path.substring(1);
  if (!path.startsWith('media/')) throw const FormatException('Invalid test media');
  if (kIsWeb) {
    final client = Dio();
    try {
      final response = await client.get<List<int>>(
        'http://localhost:8284/mock_media/unit0/$path',
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(response.data!);
    } finally {
      client.close();
    }
  }
  final data = await rootBundle.load('assets/mocks/unit0/$path');
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}
