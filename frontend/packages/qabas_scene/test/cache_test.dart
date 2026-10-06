import 'dart:async';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qabas_scene/qabas_scene.dart';

import 'fixtures.dart';

SceneDescriptor descriptor(Uint8List bytes, {String? checksum, int width = 100, List<String>? capabilities}) => SceneDescriptor(
  sceneId: 'scn_test',
  version: 1,
  schemaVersion: 'qabas.scene/1',
  url: 'https://media.test/scene.json',
  sha256: checksum ?? sha256.convert(bytes).toString(),
  width: width,
  height: 100,
  mimeType: 'application/json',
  requiredCapabilities: capabilities ?? ['scene/1', 'shape.rect/1'],
);
void main() {
  test('coalesces concurrent loads and caches verified identity, never URL alone', () async {
    final bytes = sceneBytes(sampleScene()), pending = Completer<Uint8List>();
    var requests = 0;
    final cache = SceneCache(
      loadBytes: (_) {
        requests++;
        return pending.future;
      },
    );
    final a = cache.load(descriptor(bytes)), b = cache.load(descriptor(bytes));
    pending.complete(bytes);
    expect(identical(await a, await b), true);
    expect(identical(await a, await cache.load(descriptor(bytes))), true);
    expect(requests, 1);
    final changed = sceneBytes(sampleScene(still: 500));
    await expectLater(cache.load(descriptor(changed)), throwsFormatException);
    expect(requests, 2);
  });
  test('checksum, reference mismatch and unsupported capability fail before painting', () async {
    final bytes = sceneBytes(sampleScene());
    var requests = 0;
    final cache = SceneCache(
      loadBytes: (_) async {
        requests++;
        return bytes;
      },
    );
    await expectLater(cache.load(descriptor(bytes, checksum: List.filled(64, '0').join())), throwsFormatException);
    await expectLater(cache.load(descriptor(bytes, width: 101)), throwsFormatException);
    await expectLater(cache.load(descriptor(bytes, capabilities: ['scene/1', 'clip/1'])), throwsFormatException);
    expect(requests, 2);
    expect(cache.length, 0);
    await cache.load(descriptor(bytes));
    await expectLater(cache.load(descriptor(bytes, width: 101)), throwsFormatException); // also validate cache hits.
  });
  test('missing and timed-out loads are evicted; next display can retry', () async {
    final bytes = sceneBytes(sampleScene());
    var attempt = 0;
    final cache = SceneCache(
      timeout: const Duration(milliseconds: 10),
      loadBytes: (_) {
        attempt++;
        return attempt == 1
            ? Future<Uint8List>.error(StateError('Missing'))
            : attempt == 2
            ? Completer<Uint8List>().future
            : Future.value(bytes);
      },
    );
    await expectLater(cache.load(descriptor(bytes)), throwsStateError);
    await expectLater(cache.load(descriptor(bytes)), throwsA(isA<TimeoutException>()));
    expect((await cache.load(descriptor(bytes))).sceneId, 'scn_test');
    expect(attempt, 3);
  });
  test('LRU eviction, clear during download and stale completion never repopulate', () async {
    final first = sceneBytes(sampleScene()), second = sceneBytes(sampleScene(still: 100)), third = sceneBytes(sampleScene(still: 200));
    final downloads = [first, second, third, second];
    var requests = 0;
    final lru = SceneCache(capacity: 2, loadBytes: (_) async => downloads[requests++]);
    await lru.load(descriptor(first));
    await lru.load(descriptor(second));
    await lru.load(descriptor(first)); // Promote first; second becomes oldest.
    await lru.load(descriptor(third));
    await lru.load(descriptor(first));
    expect(requests, 3);
    await lru.load(descriptor(second)); // Evicted identity must download again.
    expect(requests, 4);
    expect(lru.length, 2);
    final pending = Completer<Uint8List>(), bytes = sceneBytes(sampleScene());
    final cache = SceneCache(capacity: 1, loadBytes: (_) => pending.future);
    final result = cache.load(descriptor(bytes));
    cache.clear();
    pending.complete(bytes);
    await result;
    expect(cache.length, 0);
    await cache.load(descriptor(bytes));
    expect(cache.length, 1);
    cache.clear();
    expect(cache.length, 0);
  });
}
