import 'package:flutter_test/flutter_test.dart';
import 'package:qabas_scene/qabas_scene.dart';

import 'fixtures.dart';

void main() {
  test('exact compiled capability list, frozen tokens and RGBA palette', () {
    expect(sceneCapabilities, {
      'scene/1',
      'shape.rect/1',
      'shape.ellipse/1',
      'shape.path/1',
      'paint.gradient/1',
      'track/1',
      'fx.sparkles/1',
    });
    final s = sampleScene();
    (s['palette'] as Map)['a'] = 'token:emerald';
    (s['palette'] as Map)['b'] = '#12345678';
    final m = manifest(s);
    expect(m.palette['a']!.argb, 0xff0b5a52);
    expect(m.palette['b']!.argb, 0x78123456);
  });
  test('path subset supports implicit/relative commands, exponents and subpath close', () {
    final p = ScenePath.parse('m 10 20 5 5 h 10 v -5 c 1 2 3 4 5 6 q 2 3 4 5 z m 1e1 2e1 L .5 1.5');
    expect(p.commands.map((c) => c.kind), ['M', 'L', 'L', 'L', 'C', 'Q', 'Z', 'M', 'L']);
    expect(p.commands[2].values, [25, 25]);
    expect(p.commands[3].values, [25, 20]);
    expect(p.commands[4].values, [26, 22, 28, 24, 30, 26]);
    expect(p.commands[5].values, [32, 29, 34, 31]);
    expect(p.commands[7].values, [20, 40]);
    expect(() => ScenePath.parse('M 0, ,0'), throwsFormatException);
    expect(() => ScenePath.parse('M 1e308 0 l 1e308 0'), throwsFormatException);
  });
  for (final path in [
    'L 0 0',
    'M 0',
    'M 0 0 A 1 1 0 0 0 2 2',
    'M 0 0 S 1 1 2 2',
    'M 0 0 Z 1',
    'M 0 0 rubbish',
    'M 0,,0',
    'M,0 0',
    'M 0 0,',
    'M 0 0 1e999 0',
    'M 0 0 ${List.filled(400, 'L 1 1').join(' ')}',
  ]) {
    test(
      'invalid or over-limit path rejects: ${path.substring(0, path.length.clamp(0, 40))}',
      () => expect(() => ScenePath.parse(path), throwsFormatException),
    );
  }
  final corruptions = <String, void Function(Map<String, dynamic>)>{
    'schema': (s) => s['schema_version'] = 'qabas.scene/2',
    'identity': (s) => s['scene_id'] = '../scene',
    'unknown root field': (s) => s['scripts'] = [],
    'unknown capability': (s) => (s['required_capabilities'] as List).add('clip/1'),
    'duplicate capability': (s) => (s['required_capabilities'] as List).add('scene/1'),
    'missing capability': (s) => (s['required_capabilities'] as List).remove('shape.rect/1'),
    'unused capability': (s) => (s['required_capabilities'] as List).add('shape.ellipse/1'),
    'assets unsupported': (s) => (s['assets'] as List).add({}),
    'anchors unsupported': (s) => (s['anchors'] as List).add({}),
    'view box too large': (s) => (s['view_box'] as Map)['width'] = 4097,
    'unknown token': (s) => (s['palette'] as Map)['a'] = 'token:unknown',
    'invalid palette': (s) => (s['palette'] as Map)['a'] = '#GG0000',
    'bad state default': (s) => (s['states'] as Map)['beat']['default'] = 4,
    'bad enum': (s) => (s['states'] as Map)['enum'] = {
      'type': 'enum',
      'default': 'x',
      'values': ['x', 'x'],
    },
    'state limit': (s) => s['states'] = {
      for (var i = 0; i < 7; i++) 's$i': {'type': 'bool', 'default': true},
    },
    'layer limit': (s) => s['layers'] = [
      for (var i = 0; i < 61; i++) {'id': 'box$i', 'type': 'rect', 'x': 0, 'y': 0, 'w': 100, 'h': 100, 'fill': 'a'},
    ],
    'duplicate ID': (s) => (s['layers'] as List).add(Map<String, Object?>.from((s['layers'] as List).first)),
    'undeclared condition': (s) => (s['layers'] as List).first['state_rules'] = [
      {
        'when': {
          'wrong': {'eq': 1},
        },
        'set': {'opacity': 0.5},
      },
    ],
    'invalid operator': (s) => (s['layers'] as List).first['state_rules'] = [
      {
        'when': {
          'beat': {'neq': 1},
        },
        'set': {'opacity': 0.5},
      },
    ],
    'rule scale': (s) => (s['layers'] as List).first['state_rules'] = [
      {
        'when': {
          'beat': {'eq': 1},
        },
        'set': {'scale': 0},
      },
    ],
    'rule fill': (s) => (s['layers'] as List).first['state_rules'] = [
      {
        'when': {
          'beat': {'eq': 1},
        },
        'set': {'fill': 'unknown'},
      },
    ],
    'clip hidden from capabilities': (s) => (s['layers'] as List).first['clip'] = 'box',
    'invalid geometry': (s) => (s['layers'] as List).first['w'] = 0,
    'unknown palette': (s) => (s['layers'] as List).first['fill'] = 'missing',
    'invalid preview state': (s) => s['preview'] = {
      'frames_ms': [0],
      'states': [
        {'beat': 9},
      ],
    },
  };
  for (final entry in corruptions.entries) {
    test('invalid manifest rejects completely: ${entry.key}', () {
      final s = sampleScene();
      entry.value(s);
      expect(() => manifest(s), throwsFormatException);
    });
  }
  test('malformed tracks reject duration, keyframe order/limits, activity and scale', () {
    for (final field in ['duration_ms', 'keyframes', 'active_when', 'property', 'scale']) {
      final s = sampleScene(capabilities: ['scene/1', 'shape.rect/1', 'track/1']);
      final t = <String, Object?>{
        'property': 'translate_x',
        'duration_ms': 1000,
        'easing': 'linear',
        'loop': 'none',
        'keyframes': [
          {'t': 0, 'v': 0},
          {'t': 1, 'v': 1},
        ],
      };
      switch (field) {
        case 'duration_ms':
          t[field] = 0;
        case 'keyframes':
          t[field] = [
            {'t': 0, 'v': 0},
            {'t': 0, 'v': 1},
          ];
        case 'active_when':
          t[field] = {
            'beat': {'eq': 9},
          };
        case 'property':
          t[field] = 'fill';
        case 'scale':
          t['property'] = 'scale';
      }
      (s['layers'] as List).first['tracks'] = [t];
      expect(() => manifest(s), throwsFormatException, reason: field);
    }
  });
  test('gradient definitions require ordered stops, valid colors and geometry', () {
    final s = sampleScene(capabilities: ['scene/1', 'shape.rect/1', 'paint.gradient/1']);
    for (final fill in [
      {
        'gradient': 'linear',
        'from': [0, 0],
        'to': [0, 0],
        'stops': [
          {'at': 0, 'color': 'a'},
          {'at': 1, 'color': 'b'},
        ],
      },
      {
        'gradient': 'radial',
        'center': [0, 0],
        'radius': -1,
        'stops': [
          {'at': 0, 'color': 'a'},
          {'at': 1, 'color': 'b'},
        ],
      },
      {
        'gradient': 'linear',
        'from': [0, 0],
        'to': [1, 1],
        'stops': [
          {'at': 1, 'color': 'a'},
          {'at': 0, 'color': 'b'},
        ],
      },
    ]) {
      (s['layers'] as List).first['fill'] = fill;
      expect(() => manifest(s), throwsFormatException);
    }
  });
}
