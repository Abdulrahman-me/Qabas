import 'dart:convert';
import 'dart:typed_data';

import 'package:qabas_scene/qabas_scene.dart';

Map<String, dynamic> sampleScene({List<Map<String, Object?>>? layers, List<String>? capabilities, int still = 250}) => {
  'schema_version': 'qabas.scene/1',
  'scene_id': 'scn_test',
  'version': 1,
  'view_box': {'width': 100, 'height': 100},
  'required_capabilities': capabilities ?? ['scene/1', 'shape.rect/1'],
  'palette': {'a': '#000000', 'b': '#FFFFFF', 'transparent': '#FFFFFF00'},
  'assets': <Object>[],
  'anchors': <Object>[],
  'states': {
    'beat': {'type': 'int', 'default': 0, 'min': 0, 'max': 3},
  },
  'layers':
      layers ??
      [
        {'id': 'box', 'type': 'rect', 'x': 0, 'y': 0, 'w': 100, 'h': 100, 'fill': 'a'},
      ],
  'reduced_motion': {'still_time_ms': still},
  'preview': {
    'frames_ms': [0, 250],
    'states': [
      {'beat': 0},
    ],
  },
};
Uint8List sceneBytes(Map<String, dynamic> scene) => Uint8List.fromList(utf8.encode(jsonEncode(scene)));
SceneManifest manifest(Map<String, dynamic> scene) => SceneManifest.decode(sceneBytes(scene));
SceneTrack track({
  String property = 'translate_x',
  int duration = 1000,
  int delay = 0,
  String easing = 'linear',
  String loop = 'none',
  List<SceneKeyframe> frames = const [SceneKeyframe(0, 0), SceneKeyframe(1, 10)],
  SceneCondition? active,
}) => SceneTrack(property, duration, delay, easing, loop, frames, active);
