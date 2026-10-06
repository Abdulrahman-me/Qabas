import 'package:qabas/core/network/backend_transport.dart';
import 'package:qabas/core/storage/token_store.dart';

class MemoryTokens implements TokenStore {
  String? value;
  int clears = 0;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String token) async {
    value = token;
  }

  @override
  Future<void> clear() async {
    value = null;
    clears++;
  }
}

class RecordingTransport implements BackendTransport {
  RecordingTransport(this.respond);
  final Future<BackendResponse> Function(BackendRequest) respond;
  final requests = <BackendRequest>[];
  @override
  Future<BackendResponse> handle(BackendRequest request) async {
    requests.add(request);
    return respond(request);
  }

  @override
  void close() {}
}
