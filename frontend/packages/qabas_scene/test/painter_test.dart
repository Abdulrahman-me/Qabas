import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:qabas_scene/qabas_scene.dart';

import 'fixtures.dart';

Future<Uint8List> pixels(SceneManifest m, {double time = 0, bool reduced = false}) async {
  final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
  SceneProgram(m).paint(canvas, const ui.Size(100, 100), SceneEngine(m).frame(time, reducedMotion: reduced));
  final picture = recorder.endRecording(),
      image = await picture.toImage(100, 100),
      data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

List<int> pixel(Uint8List bytes, int x, int y) => bytes.sublist((y * 100 + x) * 4, (y * 100 + x) * 4 + 4);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('group opacity composites overlapping children once; depth-first ordering', () async {
    final s = sampleScene(
      layers: [
        {'id': 'background', 'type': 'rect', 'x': 0, 'y': 0, 'w': 100, 'h': 100, 'fill': 'a'},
        {
          'id': 'group',
          'type': 'group',
          'opacity': 0.5,
          'children': [
            {'id': 'left', 'type': 'rect', 'x': 0, 'y': 0, 'w': 70, 'h': 100, 'fill': 'b'},
            {'id': 'right', 'type': 'rect', 'x': 30, 'y': 0, 'w': 70, 'h': 100, 'fill': 'b'},
          ],
        },
      ],
    );
    final data = await pixels(manifest(s));
    expect(pixel(data, 10, 50), pixel(data, 50, 50));
    expect(pixel(data, 50, 50), [128, 128, 128, 255]);
  });
  test('rect clamps corners; ellipse coordinates are centers; paths use non-zero fill', () async {
    final s = sampleScene(
      capabilities: ['scene/1', 'shape.rect/1', 'shape.ellipse/1', 'shape.path/1'],
      layers: [
        {'id': 'rounded', 'type': 'rect', 'x': 0, 'y': 0, 'w': 20, 'h': 20, 'corner': 99, 'fill': 'b'},
        {'id': 'oval', 'type': 'ellipse', 'x': 50, 'y': 10, 'rx': 5, 'ry': 10, 'fill': 'b'},
        {'id': 'path', 'type': 'path', 'd': 'M 0 40 L 40 40 L 40 80 L 0 80 Z M 10 50 L 30 50 L 30 70 L 10 70 Z', 'fill': 'b'},
      ],
    );
    final data = await pixels(manifest(s));
    expect(pixel(data, 0, 0).last, 0);
    expect(pixel(data, 10, 10), [255, 255, 255, 255]);
    expect(pixel(data, 50, 10), [255, 255, 255, 255]);
    expect(pixel(data, 60, 10).last, 0);
    expect(pixel(data, 20, 60), [255, 255, 255, 255]); // overlapping same winding stays filled.
  });
  test('linear/radial gradients use local user space and pad stops, RGBA alpha', () async {
    final s = sampleScene(
      capabilities: ['scene/1', 'shape.rect/1', 'paint.gradient/1'],
      layers: [
        {
          'id': 'linear',
          'type': 'rect',
          'x': 0,
          'y': 0,
          'w': 100,
          'h': 50,
          'fill': {
            'gradient': 'linear',
            'from': [20, 0],
            'to': [80, 0],
            'stops': [
              {'at': 0, 'color': 'a'},
              {'at': 1, 'color': 'b'},
            ],
          },
        },
        {
          'id': 'radial',
          'type': 'rect',
          'x': 0,
          'y': 50,
          'w': 100,
          'h': 50,
          'fill': {
            'gradient': 'radial',
            'center': [50, 75],
            'radius': 20,
            'stops': [
              {'at': 0, 'color': 'b'},
              {'at': 1, 'color': 'transparent'},
            ],
          },
        },
      ],
    );
    final data = await pixels(manifest(s));
    expect(pixel(data, 10, 25), [0, 0, 0, 255]);
    expect(pixel(data, 90, 25), [255, 255, 255, 255]);
    expect(pixel(data, 49, 25).first, closeTo(125, 3));
    expect(pixel(data, 50, 75).last, greaterThan(240));
    expect(pixel(data, 80, 75).last, 0);
  });
  test('parent/local transform order and strokes painted after fill', () async {
    final s = sampleScene(
      layers: [
        {
          'id': 'group',
          'type': 'group',
          'transform': {'x': 10},
          'children': [
            {
              'id': 'rotated',
              'type': 'rect',
              'x': 20,
              'y': 20,
              'w': 5,
              'h': 5,
              'fill': 'b',
              'stroke': 'a',
              'stroke_width': 2,
              'transform': {'origin_x': 20, 'origin_y': 20, 'rotation': 90, 'scale': 2},
            },
          ],
        },
      ],
    );
    final data = await pixels(manifest(s));
    expect(pixel(data, 25, 25), [255, 255, 255, 255]);
    expect(pixel(data, 30, 25), [0, 0, 0, 255]);
    expect(pixel(data, 15, 15).last, 0);
  });
  test('sparkle frames are deterministic and reduced motion fixes the declared time', () async {
    final s = sampleScene(
      capabilities: ['scene/1', 'fx.sparkles/1'],
      layers: [
        {'id': 'field', 'type': 'sparkles', 'x': 0, 'y': 0, 'w': 100, 'h': 100, 'count': 10, 'seed': 42, 'fill': 'b', 'opacity': 0.5},
      ],
    );
    final m = manifest(s);
    expect(await pixels(m, time: 1000, reduced: true), await pixels(m, time: 250));
    expect(await pixels(m, time: 250), await pixels(m, time: 250));
    expect(await pixels(m, time: 0), isNot(await pixels(m, time: 1000)));
  });
}
