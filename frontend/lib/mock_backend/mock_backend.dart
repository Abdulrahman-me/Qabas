import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:qabas/core/network/backend_transport.dart';
import 'package:qabas/mock_backend/controls/mock_controls.dart';
import 'package:qabas/mock_backend/data/mock_state_store.dart';
import 'package:qabas/mock_backend/fake_duel_socket.dart';
import 'package:qabas/mock_backend/fixtures.dart';
import 'package:qabas/mock_backend/handlers/auth_profile_handlers.dart';
import 'package:qabas/mock_backend/handlers/community_handlers.dart';
import 'package:qabas/mock_backend/handlers/journey_handlers.dart';
import 'package:qabas/mock_backend/handlers/raqeeb_handlers.dart';
import 'package:qabas/mock_backend/handlers/recitation_handlers.dart';
import 'package:qabas/mock_backend/handlers/reviewer_handlers.dart';
import 'package:qabas/mock_backend/handlers/session_handlers.dart';
import 'package:qabas/mock_backend/mock_db.dart';
import 'package:qabas/mock_backend/mock_router.dart';

final class MockBackend implements BackendTransport {
  MockBackend({required this.fixtures, required this.controls, MockDb? db, this.stateStore}) : db = db ?? MockDb() {
    stateStore?.restore(this.db);
    registerAuthProfile(router, this.db, fixtures);
    registerReviewer(router, this.db, fixtures, controls);
    registerJourney(router, this.db, fixtures);
    registerSessions(router, this.db, fixtures, controls);
    registerRaqeeb(router, this.db, fixtures, controls);
    registerCommunity(router, this.db, fixtures);
    registerRecitation(router, this.db, fixtures, controls);
    challengeSockets = FakeDuelSocketFactory(this.db, fixtures, controls, onFinished: persist)..register(router);
  }
  late final FakeDuelSocketFactory challengeSockets;
  final Fixtures fixtures;
  final MockControls controls;
  final MockDb db;
  final MockStateStore? stateStore;
  Future<void> persist() async => stateStore?.save(db);
  Future<BackendResponse> _route(BackendRequest request) async {
    final response = await router.route(request);
    if (response.status >= 200 &&
        response.status < 300 &&
        (request.method == 'DELETE' && request.path == '/me' ||
            request.method == 'POST' && ['/auth/guest', '/auth/reviewer'].contains(request.path))) {
      challengeSockets.dispose();
    }
    if (response.status >= 200 && response.status < 300 && (request.method != 'GET' || request.path.startsWith('/raqeeb/'))) {
      await persist();
    }
    return response;
  }

  final MockRouter router = MockRouter();
  final Random _random = Random(10);
  bool _closed = false;
  BackendRequest? lastRequest;
  final _inFlight = <String, Future<void>>{};
  @override
  Future<BackendResponse> handle(BackendRequest request) async {
    if (_closed || controls.offline) throw const TransportUnavailable();
    if (!controls.fast) await Future<void>.delayed(Duration(milliseconds: 300 + _random.nextInt(501)));
    if (_closed || controls.offline) throw const TransportUnavailable();
    lastRequest = request;
    if (request.header('Qabas-Contract') == null || request.header('Qabas-Client') == null) {
      return BackendResponse.error(400, 'validation_error', 'Contract headers are required');
    }
    final injected = controls.nextStatus;
    controls.nextStatus = null;
    if (injected != null) {
      final code = switch (injected) {
        401 => 'unauthorized',
        426 => 'client_outdated',
        429 => 'rate_limited',
        _ => 'upstream_unavailable',
      };
      return BackendResponse.error(injected, code, 'Simulated request failure', {
        if (injected == 429 || injected == 503) 'retry_after_ms': 1000,
        if (injected == 426) ...{'min_contract': 10, 'min_app_version': '1.0.0'},
      });
    }
    final guest = request.method == 'POST' && ['/auth/guest', '/auth/reviewer'].contains(request.path);
    final authorization = request.header('Authorization');
    final token = authorization != null && authorization.startsWith('Bearer ') ? authorization.substring(7) : null;
    if (!guest && (token == null || !(db.tokens.contains(token) || db.tokenDigests.contains(MockStateStore.digest(token))))) {
      return BackendResponse.error(401, 'unauthorized', 'Session ended');
    }
    if (!guest && db.user?['role'] == 'reviewer' && db.reviewerExpiresAt?.isAfter(db.now()) != true) {
      return BackendResponse.error(401, 'unauthorized', 'Reviewer session ended');
    }
    if (request.path.startsWith('/admin/') && db.user?['role'] != 'reviewer') {
      return BackendResponse.error(403, 'forbidden', 'Reviewer role required');
    }
    final key = request.method == 'POST' ? request.header('Idempotency-Key') : null;
    final requiresKey =
        request.method == 'POST' &&
        (request.path == '/admin/factory/runs' ||
            request.path == '/recitation/checks' ||
            RegExp(r'^/raqeeb/conversations/[^/]+/messages$').hasMatch(request.path));
    if (requiresKey && key == null ||
        key != null && !RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$').hasMatch(key)) {
      return BackendResponse.error(400, 'validation_error', 'A UUID v4 Idempotency-Key is required', {'field': 'Idempotency-Key'});
    }
    final fingerprint = jsonEncode(_canonical([request.method, request.path, request.body]));
    final scopedKey = key == null ? null : '${db.user?['user_id'] ?? 'guest'}/$key';
    if (scopedKey == null) return _route(request);
    while (_inFlight.containsKey(scopedKey)) {
      final pending = _inFlight[scopedKey]!;
      await pending;
    }
    final saved = db.idempotency[scopedKey];
    if (saved != null && DateTime.now().difference(saved.created) < const Duration(hours: 24)) {
      if (saved.fingerprint != fingerprint) return BackendResponse.error(409, 'idempotency_conflict', 'Idempotency key already used');
      return BackendResponse(saved.status, jsonDecode(jsonEncode(saved.body)));
    }
    final completed = Completer<void>();
    _inFlight[scopedKey] = completed.future;
    try {
      final response = await _route(request);
      if (response.status >= 200 && response.status < 300) {
        db.idempotency[scopedKey] = (
          fingerprint: fingerprint,
          status: response.status,
          body: jsonDecode(jsonEncode(response.body)),
          created: DateTime.now(),
        );
      }
      return response;
    } finally {
      final removed = _inFlight.remove(scopedKey);
      if (removed != null) unawaited(removed);
      completed.complete();
    }
  }

  Object? _canonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: _canonical(value[key])};
    }
    if (value is List) return value.map(_canonical).toList();
    return value;
  }

  @override
  void close() {
    _closed = true;
    challengeSockets.dispose();
    lastRequest = null;
  }
}
