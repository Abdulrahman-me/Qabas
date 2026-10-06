import 'dart:math' as math;

import 'manifest.dart';

double sceneEase(String easing, double position) => switch (easing) {
  'ease_in' => position * position,
  'ease_out' => 1 - (1 - position) * (1 - position),
  'ease_in_out' => 0.5 - 0.5 * math.cos(math.pi * position),
  _ => position,
};

double trackValue(SceneTrack track, double timeMs) {
  final elapsed = timeMs - track.delayMs;
  if (elapsed < 0) return track.keyframes.first.value;
  final duration = track.durationMs.toDouble();
  final phase = switch (track.loop) {
    'repeat' => (elapsed % duration) / duration,
    'ping_pong' => (elapsed % (2 * duration)) / duration,
    _ => (elapsed / duration).clamp(0.0, 1.0),
  };
  final position = sceneEase(track.easing, phase <= 1 ? phase : 2 - phase);
  for (var i = 1; i < track.keyframes.length; i++) {
    final a = track.keyframes[i - 1], b = track.keyframes[i];
    if (position <= b.t) return a.value + (b.value - a.value) * (position - a.t) / (b.t - a.t);
  }
  return track.keyframes.last.value;
}

/// Multiplication is split into 16-bit limbs so JavaScript never loses uint32
/// low bits to a floating point product. Native and web match the same vectors.
int _multiply32(int a, int b) =>
    ((a & 65535) * (b & 65535) + (((a >>> 16) * (b & 65535) + (a & 65535) * (b >>> 16)) & 65535) * 65536) & 0xffffffff;

final class Mulberry32 {
  Mulberry32(int seed) : _state = seed & 0xffffffff;
  int _state;
  double next() {
    _state = (_state + 0x6d2b79f5) & 0xffffffff;
    var z = _multiply32(_state ^ (_state >>> 15), _state | 1);
    z = (z ^ ((z + _multiply32(z ^ (z >>> 7), z | 61)) & 0xffffffff)) & 0xffffffff;
    return ((z ^ (z >>> 14)) & 0xffffffff) / 4294967296;
  }
}

final class SparkleParticle {
  const SparkleParticle(this.x, this.y, this.phase);
  final double x, y, phase;
  double get radius => 2 + 2 * phase;
  double alpha(double timeMs) => 0.4 + 0.6 * math.sin(math.pi * (timeMs / 2000 + phase)).abs();
}

List<SparkleParticle> sparkleParticles(SparkleGeometry geometry) {
  final random = Mulberry32(geometry.seed);
  return List.unmodifiable(
    List.generate(
      geometry.count,
      (_) => SparkleParticle(geometry.x + random.next() * geometry.width, geometry.y + random.next() * geometry.height, random.next()),
    ),
  );
}

final class SceneValues {
  SceneValues(Map<String, Object> values)
    : x = values['x'] as double,
      y = values['y'] as double,
      rotation = values['rotation'] as double,
      scale = values['scale'] as double,
      opacity = (values['opacity'] as double).clamp(0.0, 1.0),
      fill = values['fill'] as ScenePaint?;
  final double x, y, rotation, scale, opacity;
  final ScenePaint? fill;
}

final class SceneFrame {
  SceneFrame(this.timeMs, Map<String, SceneValues> layers) : layers = Map.unmodifiable(layers);
  final double timeMs;
  final Map<String, SceneValues> layers;
}

final class _Tween {
  const _Tween(this.from, this.to, this.startedAt, this.rule);
  final Object from, to;
  final double startedAt;
  final SceneRule rule;
  Object sample(double timeMs) {
    final position = sceneEase(rule.easing, ((timeMs - startedAt) / rule.durationMs).clamp(0.0, 1.0));
    if (from is double && to is double) return (from as double) + ((to as double) - (from as double)) * position;
    final a = (from as SceneSolid).argb, b = (to as SceneSolid).argb;
    var color = 0;
    for (final shift in [0, 8, 16, 24]) {
      final av = (a >>> shift) & 255, bv = (b >>> shift) & 255;
      color |= (av + (bv - av) * position).round() << shift;
    }
    return SceneSolid(color);
  }
}

final class _LayerTimeline {
  _LayerTimeline(this.layer, Map<String, Object> state) {
    resolve(state);
  }
  final SceneLayer layer;
  Map<String, Object> targets = {};
  Map<String, SceneRule> rules = {};
  final tweens = <String, _Tween>{};
  void resolve(Map<String, Object> state) {
    targets = {...layer.base};
    rules = {};
    for (final rule in layer.rules) {
      if (!rule.when.holds(state)) continue;
      targets.addAll(rule.set);
      for (final property in rule.set.keys) {
        rules[property] = rule;
      }
    }
  }

  Object displayed(String key, double timeMs, bool reduced) => reduced ? targets[key]! : tweens[key]?.sample(timeMs) ?? targets[key]!;
  void change(Map<String, Object> state, double timeMs, bool reduced) {
    final previous = targets, previousRules = rules;
    final displayedValues = {for (final key in previous.keys) key: displayed(key, timeMs, reduced)};
    resolve(state);
    for (final entry in targets.entries) {
      final key = entry.key, target = entry.value;
      if (previous[key] == target) continue;
      final rule = rules[key] ?? previousRules[key], from = displayedValues[key];
      tweens.remove(key);
      final interpolates = (from is double && target is double) || (from is SceneSolid && target is SceneSolid);
      if (!reduced && from != null && interpolates && rule != null && rule.durationMs > 0) {
        tweens[key] = _Tween(from, target, timeMs, rule);
      }
    }
    if (reduced) tweens.clear();
  }

  SceneValues frame(Map<String, Object> state, double transitionTimeMs, double trackTimeMs, bool reduced) {
    // Sample the state-rule display before composing independent tracks, so a
    // retargeted transition never counts a track contribution twice.
    final values = {for (final key in targets.keys) key: displayed(key, transitionTimeMs, reduced)};
    for (final track in layer.tracks) {
      if (track.activeWhen != null && !track.activeWhen!.holds(state)) continue;
      final value = trackValue(track, trackTimeMs);
      final key = switch (track.property) {
        'translate_x' => 'x',
        'translate_y' => 'y',
        _ => track.property,
      };
      final previous = values[key] as double;
      values[key] = track.property == 'opacity' || track.property == 'scale' ? previous * value : previous + value;
    }
    return SceneValues(values);
  }
}

/// Deterministic state history. Time is supplied by a paused scene clock or by
/// a preview/test; wall clocks, locales and frame counts are never consulted.
final class SceneEngine {
  SceneEngine(this.manifest, {Map<String, Object?> params = const {}}) : state = manifest.resolveState(params) {
    _layers = [for (final layer in manifest.allLayers) _LayerTimeline(layer, state)];
  }
  final SceneManifest manifest;
  Map<String, Object> state;
  late final List<_LayerTimeline> _layers;
  void setState(Map<String, Object?> params, double timeMs, {bool reducedMotion = false}) {
    final next = manifest.resolveState(params);
    if (next.length == state.length && next.entries.every((entry) => state[entry.key] == entry.value)) return;
    for (final layer in _layers) {
      layer.change(next, timeMs, reducedMotion);
    }
    state = next;
  }

  void finishTransitions() {
    for (final layer in _layers) {
      layer.tweens.clear();
    }
  }

  SceneFrame frame(double timeMs, {bool reducedMotion = false}) {
    final trackTime = reducedMotion ? manifest.stillTimeMs.toDouble() : timeMs;
    return SceneFrame(trackTime, {for (final layer in _layers) layer.layer.id: layer.frame(state, timeMs, trackTime, reducedMotion)});
  }
}
