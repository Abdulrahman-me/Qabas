import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qabas/app/config/app_config.dart';
import 'package:qabas/core/network/backend_transport.dart';
import 'package:qabas/core/network/media_resolver.dart';
import 'package:qabas/core/network/polling.dart';
import 'package:qabas/core/network/routing_adapter.dart';
import '../support/fakes.dart';

class LiveAdapter implements HttpClientAdapter {
  final paths = <String>[];
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream, Future<void>? cancel) async {
    paths.add(options.path);
    return ResponseBody.fromString('{}', 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('Production and hybrid reject inconsistent configuration', () {
    expect(() => AppConfig(flavor: AppFlavor.prod), throwsArgumentError);
    expect(() => AppConfig(flavor: AppFlavor.prod, mode: ApiMode.live, baseUrl: 'http://api.test/v1'), throwsArgumentError);
    expect(() => AppConfig(mode: ApiMode.hybrid, liveGroups: {LiveGroup.journey}), throwsArgumentError);
    final prod = AppConfig(flavor: AppFlavor.prod, mode: ApiMode.live, baseUrl: 'https://api.test/v1');
    expect(prod.allowsMocks, false);
    expect(prod.developerMenuEnabled(true), false);
    expect(AppConfig(flavor: AppFlavor.demo, demoDeveloper: true).developerMenuEnabled(false), true);
  });
  test('Hybrid adapter dispatches by contract group, including me quests', () async {
    final live = LiveAdapter();
    final mock = RecordingTransport((_) async => const BackendResponse(200, {}));
    final adapter = RoutingAdapter(
      config: AppConfig(mode: ApiMode.hybrid, liveGroups: {LiveGroup.auth, LiveGroup.profile}),
      live: live,
      mock: mock,
    );
    for (final path in ['/auth/guest', '/me', '/journey', '/me/quests']) {
      await adapter.fetch(RequestOptions(path: path, baseUrl: 'http://api.test/v1'), null, null);
    }
    expect(live.paths, ['/auth/guest', '/me']);
    expect(mock.requests.map((r) => r.path), ['/journey', '/me/quests']);
    expect(LiveGroup.of('/v1/duels'), LiveGroup.challenges);
    expect(LiveGroup.of('/admin/review'), LiveGroup.reviewer);
    expect(LiveGroup.of('/auth/reviewer'), LiveGroup.reviewer);
  });
  test('Mock media maps bundled paths, forbids traversal, stays remote in live', () {
    final resolver = MediaResolver(AppConfig());
    expect(
      (resolver.resolve('mock-asset://images/example.png') as AssetMedia).path,
      'assets/mocks/contract/mock_assets/images/example.png',
    );
    expect((resolver.resolve('http://localhost:8765/media/still.png') as AssetMedia).path, 'assets/mocks/unit0/media/still.png');
    expect(resolver.resolve('https://api.test/image'), isA<RemoteMedia>());
    expect(() => resolver.resolve('mock-asset://images/%2E%2E/key'), throwsFormatException);
    expect(() => MediaResolver(AppConfig(mode: ApiMode.live)).resolve('mock-asset://images/example.png'), throwsFormatException);
  });
  test('Polling emits processing and terminal, then stops', () async {
    var calls = 0;
    expect(await pollUntil(fetch: () async => ++calls, isDone: (v) => v == 3, interval: Duration.zero).toList(), [1, 2, 3]);
    expect(calls, 3);
  });
  test('Polling cancellation interrupts delay and drops late response', () async {
    final cancellation = PollCancellation();
    final fetched = Completer<int>();
    final result = pollUntil(fetch: () => fetched.future, isDone: (_) => false, cancellation: cancellation).toList();
    await Future<void>.delayed(Duration.zero);
    cancellation.cancel();
    fetched.complete(1);
    expect(await result, isEmpty);
  });
  test('Polling cancellation releases a stalled in-flight fetch immediately', () async {
    final cancellation = PollCancellation();
    final values = pollUntil(fetch: () => Completer<int>().future, isDone: (_) => false, cancellation: cancellation).toList();
    await Future<void>.delayed(Duration.zero);
    cancellation.cancel();
    expect(await values.timeout(const Duration(seconds: 1)), isEmpty);
  });
  test('Polling deadline stops before another network call', () async {
    var calls = 0;
    var time = DateTime.utc(2026);
    final stream = pollUntil(
      fetch: () async {
        calls++;
        time = time.add(const Duration(seconds: 91));
        return 1;
      },
      isDone: (_) => false,
      now: () => time,
    );
    await expectLater(stream, emitsInOrder([1, emitsError(isA<PollTimeout>())]));
    expect(calls, 1);
  });
}
