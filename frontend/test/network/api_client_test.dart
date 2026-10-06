import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:qabas/app/config/app_config.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/network/api_client.dart';
import 'package:qabas/core/network/api_exception.dart';
import 'package:qabas/core/network/auth_events.dart';
import 'package:qabas/core/network/backend_transport.dart';
import 'package:qabas/core/network/idempotency_key.dart';
import '../support/fakes.dart';

void main() {
  late MemoryTokens tokens;
  setUp(() {
    tokens = MemoryTokens()..value = 'secret-token';
  });
  for (final entry in <int?, Type>{
    null: NetworkFailure,
    400: ValidationFailure,
    401: UnauthorizedFailure,
    403: ForbiddenFailure,
    404: NotFoundFailure,
    409: ConflictFailure,
    413: PayloadTooLargeFailure,
    415: UnsupportedMediaFailure,
    426: ClientOutdatedFailure,
    429: RateLimitedFailure,
    500: ServerFailure,
    503: UpstreamUnavailableFailure,
  }.entries) {
    test('HTTP ${entry.key} maps to ${entry.value}', () {
      expect(
        ApiException(status: entry.key, code: 'future_code', message: 'Message', details: {'retry_after_ms': 1500}).toFailure().runtimeType,
        entry.value,
      );
    });
  }
  test('Prerequisite conflict keeps code and guidance', () {
    final failure =
        ApiException(
              status: 409,
              code: 'prerequisite_unmet',
              message: 'Locked',
              details: {
                'prerequisite_lesson_ids': ['les_u0_l1'],
                'start_with_lesson_id': 'les_u0_l1',
              },
            ).toFailure()
            as ConflictFailure;
    expect(failure.code, 'prerequisite_unmet');
    expect(failure.details['start_with_lesson_id'], 'les_u0_l1');
  });
  test('Headers use secure token and current locale; guest omits token', () async {
    var language = 'en';
    final transport = RecordingTransport((_) async => const BackendResponse(200, {'ok': true}));
    final api = ApiClient.create(
      config: AppConfig.fromEnvironment(appVersion: '2.3.4'),
      tokens: tokens,
      platform: 'web',
      language: () => language,
      mock: transport,
    );
    addTearDown(api.dispose);
    await api.get('/me', decode: (json) => json);
    language = 'ar';
    await api.post('/auth/guest', body: {'timezone': 'UTC'}, decode: (json) => json);
    expect(transport.requests.first.header('Authorization'), 'Bearer secret-token');
    expect(transport.requests.first.header('Qabas-Client'), 'web/2.3.4');
    expect(transport.requests.first.header('Qabas-Contract'), '10');
    expect(transport.requests.last.header('Accept-Language'), 'ar');
    expect(transport.requests.last.header('Authorization'), isNull);
    expect(api.serverContract, '10');
  });
  test('401 clears secure token and publishes once; 426 publishes update', () async {
    var status = 401;
    final notices = <AuthEvent>[];
    final transport = RecordingTransport((_) async => BackendResponse.error(status, 'future', 'Failure', {'min_app_version': '2.0.0'}));
    final api = ApiClient.create(config: AppConfig(), tokens: tokens, platform: 'ios', language: () => 'en', mock: transport);
    final subscription = api.authEvents.listen(notices.add);
    addTearDown(() async {
      await subscription.cancel();
      await api.dispose();
    });
    await expectLater(api.get('/me', decode: (json) => json), throwsA(isA<ApiException>()));
    await Future<void>.delayed(Duration.zero);
    expect(tokens.value, isNull);
    expect(tokens.clears, 1);
    expect(notices.single, isA<AuthExpired>());
    status = 426;
    await expectLater(api.get('/me', decode: (json) => json), throwsA(isA<ApiException>()));
    await Future<void>.delayed(Duration.zero);
    expect((notices.last as ClientOutdated).minimumVersion, '2.0.0');
  });
  test('Safe keyed POST retries unchanged action; honors retry-after', () async {
    final delays = <Duration>[];
    final transport = RecordingTransport((_) async => BackendResponse.error(429, 'rate_limited', 'Wait', {'retry_after_ms': 1700}));
    final api = ApiClient.create(
      config: AppConfig(),
      tokens: tokens,
      platform: 'android',
      language: () => 'en',
      mock: transport,
      retryDelay: (value) async {
        delays.add(value);
      },
    );
    addTearDown(api.dispose);
    final key = newIdempotencyKey();
    await expectLater(
      api.post('/raqeeb/conversations', body: {'text': 'learner-secret'}, idempotencyKey: key, decode: (json) => json),
      throwsA(isA<ApiException>()),
    );
    expect(transport.requests.length, 3);
    expect(delays, [const Duration(milliseconds: 1700), const Duration(milliseconds: 1700)]);
    expect(transport.requests.map((r) => r.header('Idempotency-Key')).toSet(), {key});
    expect(transport.requests.map((r) => r.body).toList(), everyElement({'text': 'learner-secret'}));
  });
  test('Unsafe POST and non-transient errors never replay', () async {
    final transport = RecordingTransport((_) async => BackendResponse.error(503, 'upstream_unavailable', 'Fail'));
    final api = ApiClient.create(
      config: AppConfig(),
      tokens: tokens,
      platform: 'web',
      language: () => 'en',
      mock: transport,
      retryDelay: (_) async {},
    );
    addTearDown(api.dispose);
    await expectLater(api.post('/auth/guest', body: {'timezone': 'UTC'}, decode: (json) => json), throwsA(isA<ApiException>()));
    expect(transport.requests.length, 1);
  });
  test('Debug logs omit body, query tickets, tokens and attachment URLs', () async {
    final messages = <String>[];
    Logger.root.level = Level.ALL;
    final subscription = Logger.root.onRecord.listen((record) => messages.add(record.message));
    final transport = RecordingTransport((_) async => const BackendResponse(200, {'ws_url': 'wss://secret-ticket'}));
    final api = ApiClient.create(config: AppConfig(), tokens: tokens, platform: 'web', language: () => 'en', mock: transport, debug: true);
    addTearDown(() async {
      await subscription.cancel();
      await api.dispose();
      Logger.root.level = Level.INFO;
    });
    await api.post('/sessions', body: {'text': 'learner-secret', 'attachment': 'https://secret-url'}, decode: (json) => json);
    await api.get('/me', query: {'ticket': 'ticket-secret'}, decode: (json) => json);
    final log = messages.join();
    expect(log, contains('POST /v1/sessions 200'));
    for (final secret in ['learner-secret', 'secret-token', 'secret-url', 'secret-ticket', 'ticket-secret']) {
      expect(log, isNot(contains(secret)));
    }
  });
}
