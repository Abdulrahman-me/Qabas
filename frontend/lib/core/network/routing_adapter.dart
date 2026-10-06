import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:qabas/app/config/app_config.dart';
import 'package:qabas/core/network/backend_transport.dart';

final class RoutingAdapter implements HttpClientAdapter {
  RoutingAdapter({required this.config, required this.live, this.mock});
  final AppConfig config;
  final HttpClientAdapter live;
  final BackendTransport? mock;
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (config.isLive(LiveGroup.of(options.uri.path))) return live.fetch(options, requestStream, cancelFuture);
    if (!config.allowsMocks || mock == null) throw StateError('Mock transport is unavailable');
    final path = options.uri.path.replaceFirst(RegExp(r'^/v1(?=/|$)'), '');
    Object? body = options.data;
    if (body is String) body = jsonDecode(body);
    if (body is FormData) body = options.extra['mockMultipartBody'];

    try {
      final response = await mock!.handle(
        BackendRequest(method: options.method, path: path, headers: options.headers, body: body, query: options.queryParameters),
      );
      return ResponseBody.fromString(
        response.status == 204 ? '' : jsonEncode(response.body),
        response.status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
          for (final header in response.headers.entries) header.key: [header.value],
        },
      );
    } on TransportUnavailable {
      throw DioException(requestOptions: options, type: DioExceptionType.connectionError);
    }
  }

  @override
  void close({bool force = false}) {
    live.close(force: force);
    mock?.close();
  }
}
