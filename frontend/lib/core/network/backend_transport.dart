final class BackendRequest {
  BackendRequest({required this.method, required this.path, required Map<String, Object?> headers, this.body, this.query = const {}})
    : headers = Map.unmodifiable({for (final entry in headers.entries) entry.key.toLowerCase(): entry.value});
  final String method, path;
  final Map<String, Object?> headers, query;
  final Object? body;
  String? header(String name) => headers[name.toLowerCase()]?.toString();
}

final class BackendResponse {
  const BackendResponse(this.status, this.body, {this.headers = const {'Qabas-Contract': '10'}});
  final int status;
  final Object? body;
  final Map<String, String> headers;
  factory BackendResponse.error(int status, String code, String message, [Map<String, Object?> details = const {}]) =>
      BackendResponse(status, {
        'error': {'code': code, 'message': message, 'details': details},
      });
}

abstract interface class BackendTransport {
  Future<BackendResponse> handle(BackendRequest request);
  void close();
}

final class TransportUnavailable implements Exception {
  const TransportUnavailable();
}
