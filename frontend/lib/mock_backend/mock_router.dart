import 'package:qabas/core/network/backend_transport.dart';

typedef MockHandler = Future<BackendResponse> Function(BackendRequest request, Map<String, String> params);

final class MockRoute {
  MockRoute(this.method, String pattern, this.handler) {
    final parts = pattern.split('/');
    final fragments = parts.map((part) {
      if (part.startsWith('{') && part.endsWith('}')) {
        _names.add(part.substring(1, part.length - 1));
        return '([^/]+)';
      }
      return RegExp.escape(part);
    });
    _pattern = RegExp('^${fragments.join('/')}\$');
  }
  final String method;
  final MockHandler handler;
  final List<String> _names = [];
  late final RegExp _pattern;
  Map<String, String>? match(BackendRequest request) {
    if (request.method != method) return null;
    final match = _pattern.firstMatch(request.path);
    return match == null ? null : {for (var i = 0; i < _names.length; i++) _names[i]: Uri.decodeComponent(match.group(i + 1)!)};
  }
}

final class MockRouter {
  final List<MockRoute> routes = [];
  Future<BackendResponse> route(BackendRequest request) async {
    for (final route in routes) {
      final params = route.match(request);
      if (params != null) return route.handler(request, params);
    }
    return BackendResponse.error(404, 'not_found', 'Resource not found');
  }
}
