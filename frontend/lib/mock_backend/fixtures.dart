import 'dart:convert';
import 'package:flutter/services.dart';

final class Fixtures {
  Fixtures({Future<String> Function(String)? read, this.recording = false}) : _read = read ?? rootBundle.loadString;
  final Future<String> Function(String) _read;
  final bool recording;
  Fixtures forRecording(bool enabled) => Fixtures(read: _read, recording: enabled);
  final Map<String, Future<Object?>> _cache = {};
  Future<Object?> load(String path) async {
    final value = await (_cache[path] ??= _read('assets/mocks/$path').then<Object?>(jsonDecode));
    // Callers mutate their server snapshot, never the cached authored fixture.
    final copy = jsonDecode(jsonEncode(value));
    if (recording) _projectRecording(copy);
    return copy;
  }

  // TODO(contract): A-55 — omit nonexistent pronunciation assets in the private recording demo.
  void _projectRecording(Object? value) {
    if (value is Map) {
      for (final key in value.keys.toList()) {
        if (key == 'pronunciation_audio_url' && value[key] is String && (value[key] as String).contains('cdn.example.com')) {
          value[key] = null;
        } else {
          _projectRecording(value[key]);
        }
      }
    } else if (value is List) {
      for (final child in value) {
        _projectRecording(child);
      }
    }
  }

  Future<Map<String, dynamic>> object(String path) async => (await load(path)) as Map<String, dynamic>;
  Future<Map<String, dynamic>> example(String model) async {
    final index = (await load('examples/INDEX.json')) as List<dynamic>;
    final row = index.cast<Map<String, dynamic>>().firstWhere((row) => row['model'] == model);
    return object('examples/${row['file']}');
  }
}
