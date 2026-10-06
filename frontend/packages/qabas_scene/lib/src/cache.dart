import 'dart:async';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'manifest.dart';

final class SceneDescriptor {
  SceneDescriptor({
    required this.sceneId,
    required this.version,
    required this.schemaVersion,
    required this.url,
    required this.sha256,
    required this.width,
    required this.height,
    required this.mimeType,
    required List<String> requiredCapabilities,
  }) : requiredCapabilities = List.unmodifiable(requiredCapabilities);
  final String sceneId, schemaVersion, url, sha256, mimeType;
  final int version, width, height;
  final List<String> requiredCapabilities;
  String get cacheKey => '$sceneId/$version/$sha256';
  void validate() {
    if (schemaVersion != 'qabas.scene/1' ||
        mimeType != 'application/json' ||
        version < 1 ||
        width < 1 ||
        width > 4096 ||
        height < 1 ||
        height > 4096 ||
        !RegExp(r'^scn_[a-z0-9_]+$').hasMatch(sceneId) ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(sha256) ||
        requiredCapabilities.toSet().length != requiredCapabilities.length ||
        !sceneCapabilities.containsAll(requiredCapabilities)) {
      throw const FormatException('Unsupported scene reference');
    }
  }
}

/// Coalesced LRU cache. Failures are evicted, including timed-out loads, so the
/// next display retries. Only verified bytes may enter the completed cache.
final class SceneCache {
  SceneCache({required this.loadBytes, this.capacity = 24, this.timeout = const Duration(seconds: 10)}) {
    if (capacity < 1) throw ArgumentError.value(capacity);
  }
  final Future<Uint8List> Function(String url) loadBytes;
  final int capacity;
  final Duration timeout;
  final _completed = <String, SceneManifest>{};
  final _pending = <String, Future<SceneManifest>>{};
  int _generation = 0;
  int get length => _completed.length;
  Future<SceneManifest> load(SceneDescriptor descriptor) async {
    descriptor.validate();
    final key = descriptor.cacheKey, cached = _completed.remove(key);
    if (cached != null) {
      _completed[key] = cached;
      _checkReference(descriptor, cached);
      return cached;
    }
    final generation = _generation;
    final pending = _pending[key] ??= _decode(descriptor).timeout(timeout);
    try {
      final manifest = await pending;
      _checkReference(descriptor, manifest);
      if (generation == _generation) {
        _completed.remove(key);
        _completed[key] = manifest;
        while (_completed.length > capacity) {
          _completed.remove(_completed.keys.first);
        }
      }
      return manifest;
    } finally {
      if (identical(_pending[key], pending)) _pending.remove(key);
    }
  }

  Future<SceneManifest> _decode(SceneDescriptor descriptor) async {
    final bytes = await loadBytes(descriptor.url);
    if (bytes.length > 262144 || sha256.convert(bytes).toString() != descriptor.sha256) {
      throw const FormatException('Manifest integrity failure');
    }
    final manifest = SceneManifest.decode(bytes);
    _checkReference(descriptor, manifest);
    return manifest;
  }

  void _checkReference(SceneDescriptor ref, SceneManifest manifest) {
    if (manifest.sceneId != ref.sceneId ||
        manifest.version != ref.version ||
        manifest.width != ref.width ||
        manifest.height != ref.height ||
        manifest.capabilities.length != ref.requiredCapabilities.length ||
        !manifest.capabilities.containsAll(ref.requiredCapabilities)) {
      throw const FormatException('Scene reference differs from manifest');
    }
  }

  void clear() {
    _generation++;
    _completed.clear();
    _pending.clear();
  }
}
