import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qabas/app/config/app_config.dart';
import 'package:qabas/core/network/api_client.dart';
import 'package:qabas/core/network/api_exception.dart';
import 'package:qabas/core/network/backend_transport.dart';
import 'package:qabas/core/network/idempotency_key.dart';
import 'package:qabas/core/network/multipart_request.dart';
import 'package:qabas/mock_backend/controls/mock_controls.dart';
import 'package:qabas/mock_backend/fixtures.dart';
import 'package:qabas/mock_backend/mock_backend.dart';
import 'package:qabas/mock_backend/mock_router.dart';
import 'package:qabas/shared/data/dtos/auth_response_dto.dart';
import 'package:qabas/shared/data/dtos/user_dto.dart';

import '../support/fakes.dart';

void main() {
  late MockBackend backend;
  late ApiClient api;
  late MemoryTokens tokens;
  setUp(() {
    tokens = MemoryTokens();
    backend = MockBackend(
      fixtures: Fixtures(read: (path) => File(path).readAsString()),
      controls: MockControls()..fast = true,
    );
    api = ApiClient.create(
      config: AppConfig(),
      tokens: tokens,
      platform: 'web',
      language: () => 'ar',
      mock: backend,
      retryDelay: (_) async {},
    );
  });
  tearDown(() => api.dispose());
  Future<void> guest() async {
    final auth = await api.post('/auth/guest', body: {'timezone': 'Asia/Muscat'}, decode: AuthResponseDto.fromJson);
    await tokens.write(auth.accessToken);
  }

  test('Auth, partial profile updates, stats fixtures and account deletion', () async {
    await guest();
    final initial = await api.get('/me', decode: UserDto.fromJson);
    expect(initial.language, LanguageDto.ar);
    expect(initial.timezone, 'Asia/Muscat');
    expect(initial.onboardingCompleted, false);
    final updated = await api.patch(
      '/me',
      body: {'display_name': 'نور', 'private_profile': false, 'goal_anchor': 'why_pray'},
      decode: UserDto.fromJson,
    );
    expect(updated.displayName, 'نور');
    expect(updated.privateProfile, false);
    expect(updated.track, initial.track);
    expect(updated.goalAnchor, 'why_pray');
    for (final path in ['/me/stats', '/me/achievements', '/me/activity', '/me/concepts']) {
      expect(await api.get(path, decode: (json) => json), isNotEmpty);
    }
    await api.delete('/me');
    expect(backend.db.user, isNull);
    expect(backend.db.tokens, isEmpty);
    await expectLater(api.get('/me', decode: UserDto.fromJson), throwsA(isA<ApiException>()));
    expect(tokens.value, isNull);
  });
  test('A new guest resets previous learner data', () async {
    await guest();
    final old = tokens.value;
    backend.db.completedLessons.add('les_u0_l1');
    await guest();
    expect(tokens.value, isNot(old));
    expect(backend.db.tokens, hasLength(1));
    expect(backend.db.completedLessons, isEmpty);
  });
  test('Profile rejects unsupported, null and invalid fields without mutation', () async {
    await guest();
    final initial = jsonEncode(backend.db.user);
    for (final body in [
      {'daily_goal_minutes': 7},
      {'private_profile': null},
      {'display_name': 'a'},
      {'role': 'reviewer'},
      {'goal_anchor': 'unregistered'},
    ]) {
      await expectLater(
        api.patch('/me', body: body, decode: UserDto.fromJson),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 400)),
      );
      expect(jsonEncode(backend.db.user), initial);
    }
  });
  test('Concurrent identical keys execute once, replay canonically, conflict and expire', () async {
    await guest();
    var calls = 0;
    backend.router.routes.insert(
      0,
      MockRoute('POST', '/raqeeb/conversations', (_, _) async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return BackendResponse(201, {'id': calls});
      }),
    );
    final key = newIdempotencyKey();
    final requests = await Future.wait([
      for (var i = 0; i < 5; i++) api.post('/raqeeb/conversations', body: {'a': 1, 'b': 2}, idempotencyKey: key, decode: (json) => json),
    ]);
    expect(calls, 1);
    expect(requests, everyElement({'id': 1}));
    expect(await api.post('/raqeeb/conversations', body: {'b': 2, 'a': 1}, idempotencyKey: key, decode: (json) => json), {'id': 1});
    await expectLater(
      api.post('/raqeeb/conversations', body: {'a': 3}, idempotencyKey: key, decode: (json) => json),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'idempotency_conflict')),
    );
    final entry = backend.db.idempotency.entries.single;
    final value = entry.value;
    backend.db.idempotency[entry.key] = (
      fingerprint: value.fingerprint,
      status: value.status,
      body: value.body,
      created: DateTime.now().subtract(const Duration(hours: 25)),
    );
    await api.post('/raqeeb/conversations', body: {'a': 1, 'b': 2}, idempotencyKey: key, decode: (json) => json);
    expect(calls, 2);
  });
  test('Multipart retries retain key and bytes; changed equal-length files conflict', () async {
    await guest();
    var calls = 0;
    backend.router.routes.insert(
      0,
      MockRoute('POST', '/recitation/checks', (_, _) async {
        calls++;
        if (calls == 1) return BackendResponse.error(503, 'upstream_unavailable', 'Unavailable');
        return const BackendResponse(201, {'check_id': 'chk_test'});
      }),
    );
    MultipartRequest upload(List<int> bytes) => MultipartRequest(
      fields: {'exercise_id': 'ex_test'},
      files: [UploadPart(field: 'audio', filename: 'recitation.m4a', mimeType: 'audio/mp4', bytes: bytes)],
    );
    final key = newIdempotencyKey();
    expect(await api.postMultipart('/recitation/checks', form: upload([1, 2, 3]), idempotencyKey: key, decode: (json) => json), {
      'check_id': 'chk_test',
    });
    expect(calls, 2);
    expect(await api.postMultipart('/recitation/checks', form: upload([1, 2, 3]), idempotencyKey: key, decode: (json) => json), {
      'check_id': 'chk_test',
    });
    expect(calls, 2);
    await expectLater(
      api.postMultipart('/recitation/checks', form: upload([3, 2, 1]), idempotencyKey: key, decode: (json) => json),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'idempotency_conflict')),
    );
  });
  test('Headers, offline, next status and unknown route use envelopes', () async {
    expect((await backend.handle(BackendRequest(method: 'GET', path: '/me', headers: const {}))).status, 400);
    await guest();
    backend.controls.nextStatus = 426;
    await expectLater(api.get('/me', decode: UserDto.fromJson), throwsA(isA<ApiException>().having((e) => e.status, 'status', 426)));
    expect(backend.controls.nextStatus, isNull);
    backend.controls.offline = true;
    await expectLater(api.get('/me', decode: UserDto.fromJson), throwsA(isA<ApiException>().having((e) => e.status, 'status', isNull)));
    backend.controls.offline = false;
    await expectLater(api.get('/me/unknown', decode: (json) => json), throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)));
  });
  test('Fixture callers cannot mutate cached contract examples', () async {
    final first = await backend.fixtures.example('User');
    first['display_name'] = 'changed';
    expect((await backend.fixtures.example('User'))['display_name'], isNot('changed'));
  });
}
