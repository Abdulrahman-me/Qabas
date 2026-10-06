import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:qabas/core/network/media_resolver.dart';

/// Public scene media uses the resolver, never the authenticated API client.
/// The renderer verifies the exact returned bytes before caching or painting.
final class SceneMediaLoader {
  SceneMediaLoader(this.resolver)
    : _client = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          responseType: ResponseType.bytes,
        ),
      );
  final MediaResolver resolver;
  final Dio _client;
  Future<Uint8List> load(String url) async {
    switch (resolver.resolve(url)) {
      case AssetMedia(:final path):
        final data = await rootBundle.load(path);
        return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      case RemoteMedia(:final uri):
        final response = await _client.get<List<int>>(uri.toString());
        final data = response.data;
        if (data == null || data.length > 262144) throw const FormatException('Invalid scene media');
        return Uint8List.fromList(data);
      case UnavailableMedia() || MemoryMedia():
        throw const FormatException('Scene media unavailable');
    }
  }

  void dispose() => _client.close(force: true);
}
