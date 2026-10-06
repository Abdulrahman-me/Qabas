import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:qabas_scene/qabas_scene.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final root = Directory('assets/mocks/unit0');
  final index = jsonDecode(File('${root.path}/MEDIA_INDEX.json').readAsStringSync()) as Map;
  test('all 20 exact bundled scene manifests validate and every authored state paints', () async {
    for (final row in (index['scenes'] as List).cast<Map>()) {
      final m = SceneManifest.decode(File('${root.path}/${row['path']}').readAsBytesSync());
      expect(m.sceneId, row['scene_id']);
      for (final state in m.previewStates) {
        for (final time in m.previewTimes) {
          final bytes = await render(m, state, time.toDouble());
          expect(bytes.length, greaterThan(0));
        }
      }
    }
  });
  test('all 86 backend stills compare with normative reduced-motion frames', () async {
    final output = Directory('build/phase7/frames')..createSync(recursive: true), report = <Map<String, Object>>[];
    final scenes = {
      for (final row in (index['scenes'] as List).cast<Map>())
        row['scene_id']: SceneManifest.decode(File('${root.path}/${row['path']}').readAsBytesSync()),
    };
    for (final row in (index['fallbacks'] as List).cast<Map>()) {
      final m = scenes[row['scene_id']]!, state = Map<String, Object?>.from(row['params'] as Map);
      final png = await render(m, state, (row['still_time_ms'] as num).toDouble(), reduced: true);
      final actual = await rgba(png), expected = await rgba(File('${root.path}/${row['path']}').readAsBytesSync());
      expect(actual.length, expected.length);
      final histogram = List<int>.filled(256, 0);
      var sum = 0;
      for (var i = 0; i < actual.length; i++) {
        final delta = (actual[i] - expected[i]).abs();
        histogram[delta]++;
        sum += delta;
      }
      var count = 0, p99 = 0;
      for (; p99 < 255; p99++) {
        count += histogram[p99];
        if (count >= actual.length * 0.99) break;
      }
      final mean = sum / actual.length, name = (row['path'] as String).split('/').last.replaceAll('.webp', '.png');
      File('${output.path}/$name').writeAsBytesSync(png);
      report.add({
        'scene_id': m.sceneId,
        'params': state,
        'mean_absolute_channel_error': mean,
        'p99_channel_error': p99,
        'rendered': name,
        'reference': row['path'] as String,
      });
      expect(mean, lessThanOrEqualTo(0.5), reason: '${m.sceneId}/$state mean channel tolerance');
      expect(p99, lessThanOrEqualTo(8), reason: '${m.sceneId}/$state p99 channel tolerance');
    }
    File('build/phase7/backend_still_comparison.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
    // Despite their non-normative source, all supplied stills meet the contract's
    // strict channel tolerance. Sparkles retain the normative mulberry32 PRNG.
    expect(report.length, 86);
  });
}

Future<Uint8List> render(SceneManifest manifest, Map<String, Object?> state, double time, {bool reduced = false}) async {
  final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
  SceneProgram(manifest).paint(canvas, const ui.Size(800, 500), SceneEngine(manifest, params: state).frame(time, reducedMotion: reduced));
  final picture = recorder.endRecording(), image = await picture.toImage(800, 500);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

Future<Uint8List> rgba(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes), frame = await codec.getNextFrame();
  final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
  frame.image.dispose();
  codec.dispose();
  return data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}
