import 'package:flutter_test/flutter_test.dart';
import 'package:qabas_scene/qabas_scene.dart';

import 'fixtures.dart';

void main() {
  test('mulberry32 matches canonical uint32 vectors exactly', () {
    for (final sample in <int, List<double>>{
      1: [0.6270739405881613, 0.002735721180215478, 0.5274470399599522],
      42: [0.6011037519201636, 0.44829055899754167, 0.8524657934904099],
    }.entries) {
      final random = Mulberry32(sample.key);
      expect(List.generate(3, (_) => random.next()), sample.value);
    }
    expect(Mulberry32(-1).next(), Mulberry32(0xffffffff).next());
  });
  test('particles draw x/y/phase in order with the normative radius and alpha', () {
    final points = sparkleParticles(const SparkleGeometry(10, 20, 100, 200, 1, 1));
    expect(points.single.x, 72.70739405881613);
    expect(points.single.y, 20.547144236043096);
    expect(points.single.phase, 0.5274470399599522);
    expect(points.single.radius, 3.0548940799199045);
    expect(points.single.alpha(1000), closeTo(0.451672, 0.00001));
  });
  test('every easing and whole-cycle keyframe interpolation', () {
    expect(sceneEase('linear', 0.25), 0.25);
    expect(sceneEase('ease_in', 0.25), 0.0625);
    expect(sceneEase('ease_out', 0.25), 0.4375);
    expect(sceneEase('ease_in_out', 0.5), closeTo(0.5, 1e-14));
    final t = track(easing: 'ease_in', frames: const [SceneKeyframe(0, 0), SceneKeyframe(0.5, 20), SceneKeyframe(1, 10)]);
    expect(trackValue(t, 500), 10); // ease(0.5)=0.25, not per-segment easing.
  });
  test('negative delay position, finite tracks, repeat and ping-pong boundaries', () {
    final delayed = track(delay: 500, frames: const [SceneKeyframe(0, 5), SceneKeyframe(1, 10)]);
    expect(trackValue(delayed, 499), 5);
    expect(trackValue(delayed, 1000), 7.5);
    expect(trackValue(delayed, 99999), 10);
    expect(trackValue(track(loop: 'repeat'), 1000), 0);
    expect(trackValue(track(loop: 'repeat'), 1500), 5);
    expect(trackValue(track(loop: 'ping_pong'), 1000), 10);
    expect(trackValue(track(loop: 'ping_pong'), 1500), 5);
    expect(trackValue(track(loop: 'ping_pong'), 2000), 0);
  });
  test('conditions AND every state/operator; last matching rule wins per property', () {
    final s = sampleScene();
    (s['layers'] as List).first['state_rules'] = [
      {
        'when': {
          'beat': {
            'gte': 1,
            'lte': 3,
            'in': [1, 2],
          },
        },
        'set': {'x': 20, 'opacity': 0.4},
      },
      {
        'when': {
          'beat': {'eq': 2},
        },
        'set': {'x': 50},
      },
    ];
    final engine = SceneEngine(manifest(s), params: {'beat': 2});
    final values = engine.frame(0).layers['box']!;
    expect(values.x, 50);
    expect(values.opacity, 0.4);
    engine.setState({'beat': 3}, 0);
    expect(engine.frame(0).layers['box']!.x, 0);
  });
  SceneEngine transitionEngine() {
    final s = sampleScene();
    (s['layers'] as List).first['state_rules'] = [
      {
        'when': {
          'beat': {'eq': 1},
        },
        'set': {'x': 100, 'fill': 'b'},
        'transition_ms': 1000,
        'easing': 'linear',
      },
      {
        'when': {
          'beat': {'eq': 2},
        },
        'set': {'x': 200},
        'transition_ms': 2000,
        'easing': 'ease_in',
      },
    ];
    return SceneEngine(manifest(s));
  }

  test('transitions use the new rule, then previous rule when returning to base', () {
    final engine = transitionEngine();
    engine.setState({'beat': 1}, 100);
    expect(engine.frame(600).layers['box']!.x, 50);
    expect((engine.frame(600).layers['box']!.fill as SceneSolid).argb, 0xff808080);
    engine.setState({'beat': 0}, 1100);
    expect(engine.frame(1600).layers['box']!.x, 50);
    expect(engine.frame(2100).layers['box']!.x, 0);
  });
  test('interrupting a transition starts at its currently displayed value', () {
    final engine = transitionEngine();
    engine.setState({'beat': 1}, 0);
    engine.setState({'beat': 2}, 500);
    expect(engine.frame(500).layers['box']!.x, 50);
    expect(engine.frame(1500).layers['box']!.x, 87.5); // new rule's 2 s ease-in.
    expect(engine.frame(2500).layers['box']!.x, 200);
  });
  test('solid RGBA interpolation includes alpha; gradient changes are instant', () {
    final s = sampleScene(capabilities: ['scene/1', 'shape.rect/1', 'paint.gradient/1']);
    (s['layers'] as List).first['fill'] = {
      'gradient': 'linear',
      'from': [0, 0],
      'to': [100, 0],
      'stops': [
        {'at': 0, 'color': 'a'},
        {'at': 1, 'color': 'b'},
      ],
    };
    (s['layers'] as List).first['state_rules'] = [
      {
        'when': {
          'beat': {'eq': 1},
        },
        'set': {'fill': 'transparent'},
        'transition_ms': 1000,
      },
      {
        'when': {
          'beat': {'eq': 2},
        },
        'set': {'fill': 'a'},
        'transition_ms': 1000,
      },
    ];
    final engine = SceneEngine(manifest(s));
    engine.setState({'beat': 1}, 0);
    expect((engine.frame(0).layers['box']!.fill as SceneSolid).argb, 0x00ffffff);
    engine.setState({'beat': 2}, 0);
    expect((engine.frame(500).layers['box']!.fill as SceneSolid).argb, 0x80808080);
  });
  test('tracks add/multiply in order, clamp opacity and switch activity instantly', () {
    final s = sampleScene(capabilities: ['scene/1', 'shape.rect/1', 'track/1']);
    final l = (s['layers'] as List).first;
    l['transform'] = {'x': 10, 'scale': 2};
    l['tracks'] = [
      for (final pair in [('translate_x', 3), ('translate_x', 4), ('rotation', 90), ('scale', 3), ('scale', 2), ('opacity', 2)])
        {
          'property': pair.$1,
          'duration_ms': 1000,
          'easing': 'linear',
          'loop': 'none',
          'keyframes': [
            {'t': 0, 'v': pair.$2},
            {'t': 1, 'v': pair.$2},
          ],
          'active_when': {
            'beat': {'eq': 1},
          },
        },
    ];
    final engine = SceneEngine(manifest(s));
    expect(engine.frame(500).layers['box']!.x, 10);
    engine.setState({'beat': 1}, 500);
    final v = engine.frame(500).layers['box']!;
    expect(v.x, 17);
    expect(v.scale, 12);
    expect(v.rotation, 90);
    expect(v.opacity, 1);
  });
  test('reduced motion fixes track time, respects activity and has instant changes', () {
    final s = sampleScene(capabilities: ['scene/1', 'shape.rect/1', 'track/1']);
    (s['layers'] as List).first['tracks'] = [
      {
        'property': 'translate_x',
        'duration_ms': 1000,
        'easing': 'linear',
        'loop': 'none',
        'keyframes': [
          {'t': 0, 'v': 0},
          {'t': 1, 'v': 100},
        ],
        'active_when': {
          'beat': {'gte': 1},
        },
      },
    ];
    (s['layers'] as List).first['state_rules'] = [
      {
        'when': {
          'beat': {'eq': 1},
        },
        'set': {'opacity': 0.5},
        'transition_ms': 1000,
      },
    ];
    final engine = SceneEngine(manifest(s));
    expect(engine.frame(9999, reducedMotion: true).layers['box']!.x, 0);
    engine.setState({'beat': 1}, 9999, reducedMotion: true);
    expect(engine.frame(9999, reducedMotion: true).layers['box']!.x, 25);
    expect(engine.frame(9999, reducedMotion: true).layers['box']!.opacity, 0.5);
  });
  test('defaults, bool/enum states and immutable model/state collections', () {
    final s = sampleScene();
    (s['states'] as Map)['on'] = {'type': 'bool', 'default': true};
    (s['states'] as Map)['mode'] = {
      'type': 'enum',
      'values': ['a', 'b'],
      'default': 'a',
    };
    final m = manifest(s), engine = SceneEngine(m);
    expect(engine.state, {'beat': 0, 'on': true, 'mode': 'a'});
    expect(() => engine.setState({'on': 1}, 0), throwsFormatException);
    expect(() => engine.setState({'mode': 'c'}, 0), throwsFormatException);
    expect(() => engine.setState({'unknown': 1}, 0), throwsFormatException);
    expect(() => engine.state['beat'] = 1, throwsUnsupportedError);
    expect(() => m.layers.clear(), throwsUnsupportedError);
    // JSON Schema integers may be written as 1.0; JSON number classification
    // differs between the native VM and JavaScript. Canonicalize both paths.
    final numeric = sampleScene();
    numeric['version'] = 1.0;
    numeric['view_box'] = {'width': 100.0, 'height': 100.0};
    numeric['states'] = {
      'beat': {'type': 'int', 'default': 0.0, 'min': 0.0, 'max': 3.0},
    };
    numeric['reduced_motion'] = {'still_time_ms': 250.0};
    numeric['preview'] = {
      'frames_ms': [0.0, 250.0],
      'states': [
        {'beat': 1.0},
      ],
    };
    final decoded = manifest(numeric), canonical = SceneEngine(decoded, params: {'beat': 2.0});
    expect(decoded.version, 1);
    expect(decoded.previewStates.single['beat'], isA<int>());
    expect(canonical.state['beat'], 2);
    expect(canonical.state['beat'], isA<int>());
    expect(() => canonical.setState({'beat': 1.5}, 0), throwsFormatException);
  });
}
