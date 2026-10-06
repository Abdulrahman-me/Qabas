import 'dart:convert';
import 'dart:typed_data';

import 'path.dart';

const sceneRendererVersion = 'qabas_scene/1.0.0';
const sceneCapabilities = <String>{
  'scene/1',
  'shape.rect/1',
  'shape.ellipse/1',
  'shape.path/1',
  'paint.gradient/1',
  'track/1',
  'fx.sparkles/1',
};

/// Frozen sRGB token table for this renderer build. Never reads a mutable theme.
const sceneTokens = <String, int>{
  'night_emerald': 0xff073c37,
  'emerald': 0xff0b5a52,
  'flame_gold': 0xffe0a526,
  'soft_ember': 0xfff6e3b4,
  'morning_mint': 0xffeef5f2,
  'deep_ink': 0xff16233a,
  'slate': 0xff566476,
  'surface': 0xffffffff,
  'surface_sunk': 0xfff5f9f7,
  'line': 0xffdce7e3,
  'line_strong': 0xffc5d6d0,
  'muted': 0xff8a97a6,
};

Map<String, Object?> object(Object? value) {
  if (value is! Map<String, dynamic>) throw const FormatException('Expected object');
  return value;
}

List<Object?> array(Object? value, int min, int max) {
  if (value is! List || value.length < min || value.length > max) throw const FormatException('Invalid array');
  return value.cast<Object?>();
}

String string(Object? value) {
  if (value is! String) throw const FormatException('Expected string');
  return value;
}

double number(Object? value, {double? min, double? max}) {
  if (value is! num || !value.isFinite || (min != null && value < min) || (max != null && value > max)) {
    throw const FormatException('Invalid number');
  }
  return value.toDouble();
}

int integer(Object? value, int min, int max) {
  if (value is! num || !value.isFinite || value < min || value > max || value != value.truncateToDouble()) {
    throw const FormatException('Invalid integer');
  }
  return value.toInt();
}

void fields(Map<String, Object?> json, Set<String> allowed, [Set<String> required = const {}]) {
  if (json.keys.any((k) => !allowed.contains(k)) || required.any((k) => !json.containsKey(k))) {
    throw const FormatException('Invalid object fields');
  }
}

String choice(Object? value, Set<String> options) {
  final text = string(value);
  if (!options.contains(text)) throw const FormatException('Unsupported value');
  return text;
}

sealed class ScenePaint {
  const ScenePaint();
}

final class SceneSolid extends ScenePaint {
  const SceneSolid(this.argb);
  final int argb;
  @override
  bool operator ==(Object other) => other is SceneSolid && other.argb == argb;
  @override
  int get hashCode => argb;
}

final class SceneGradient extends ScenePaint {
  SceneGradient(this.kind, List<double> start, List<double> end, this.radius, List<GradientStop> stops)
    : start = List.unmodifiable(start),
      end = List.unmodifiable(end),
      stops = List.unmodifiable(stops);
  final String kind;
  final List<double> start, end;
  final double radius;
  final List<GradientStop> stops;
}

final class GradientStop {
  const GradientStop(this.at, this.color);
  final double at;
  final SceneSolid color;
}

final class SceneStateSpec {
  SceneStateSpec(this.type, this.defaultValue, this.min, this.max, List<String> values) : values = List.unmodifiable(values) {
    validate(defaultValue);
  }
  final String type;
  final Object defaultValue;
  final int? min, max;
  final List<String> values;
  void validate(Object? value) {
    final valid = switch (type) {
      'int' => value is num && value.isFinite && value >= min! && value <= max! && value == value.truncateToDouble(),
      'bool' => value is bool,
      'enum' => value is String && values.contains(value),
      _ => false,
    };
    if (!valid) throw const FormatException('Invalid state value');
  }
}

final class SceneCondition {
  SceneCondition(Map<String, Map<String, Object?>> conditions)
    : conditions = Map.unmodifiable(conditions.map((k, v) => MapEntry(k, Map<String, Object?>.unmodifiable(v))));
  final Map<String, Map<String, Object?>> conditions;
  bool holds(Map<String, Object> state) => conditions.entries.every((entry) {
    final value = state[entry.key];
    return entry.value.entries.every(
      (op) => switch (op.key) {
        'eq' => value == op.value,
        'gte' => value is num && value >= (op.value as num),
        'lte' => value is num && value <= (op.value as num),
        'in' => (op.value as List).contains(value),
        _ => false,
      },
    );
  });
}

final class SceneRule {
  SceneRule(this.when, Map<String, Object> set, this.durationMs, this.easing) : set = Map.unmodifiable(set);
  final SceneCondition when;
  final Map<String, Object> set;
  final int durationMs;
  final String easing;
}

final class SceneKeyframe {
  const SceneKeyframe(this.t, this.value);
  final double t, value;
}

final class SceneTrack {
  SceneTrack(this.property, this.durationMs, this.delayMs, this.easing, this.loop, List<SceneKeyframe> keyframes, this.activeWhen)
    : keyframes = List.unmodifiable(keyframes);
  final String property, easing, loop;
  final int durationMs, delayMs;
  final List<SceneKeyframe> keyframes;
  final SceneCondition? activeWhen;
}

sealed class SceneGeometry {
  const SceneGeometry();
}

final class RectGeometry extends SceneGeometry {
  const RectGeometry(this.x, this.y, this.width, this.height, this.corner);
  final double x, y, width, height, corner;
}

final class EllipseGeometry extends SceneGeometry {
  const EllipseGeometry(this.x, this.y, this.rx, this.ry);
  final double x, y, rx, ry;
}

final class PathGeometry extends SceneGeometry {
  const PathGeometry(this.path);
  final ScenePath path;
}

final class SparkleGeometry extends SceneGeometry {
  const SparkleGeometry(this.x, this.y, this.width, this.height, this.count, this.seed);
  final double x, y, width, height;
  final int count, seed;
}

final class SceneLayer {
  SceneLayer(
    this.id,
    this.geometry,
    Map<String, Object> base,
    this.originX,
    this.originY,
    this.stroke,
    this.strokeWidth,
    List<SceneRule> rules,
    List<SceneTrack> tracks,
    List<SceneLayer> children,
  ) : base = Map.unmodifiable(base),
      rules = List.unmodifiable(rules),
      tracks = List.unmodifiable(tracks),
      children = List.unmodifiable(children);
  final String id;
  final SceneGeometry? geometry;
  final Map<String, Object> base;
  final double originX, originY, strokeWidth;
  final SceneSolid? stroke;
  final List<SceneRule> rules;
  final List<SceneTrack> tracks;
  final List<SceneLayer> children;
}

final class SceneManifest {
  SceneManifest._(
    this.sceneId,
    this.version,
    this.width,
    this.height,
    Set<String> capabilities,
    Map<String, SceneSolid> palette,
    Map<String, SceneStateSpec> states,
    List<SceneLayer> layers,
    this.stillTimeMs,
    List<int> previewTimes,
    List<Map<String, Object>> previewStates,
  ) : capabilities = Set.unmodifiable(capabilities),
      palette = Map.unmodifiable(palette),
      states = Map.unmodifiable(states),
      layers = List.unmodifiable(layers),
      previewTimes = List.unmodifiable(previewTimes),
      previewStates = List.unmodifiable(previewStates);
  final String sceneId;
  final int version, width, height, stillTimeMs;
  final Set<String> capabilities;
  final Map<String, SceneSolid> palette;
  final Map<String, SceneStateSpec> states;
  final List<SceneLayer> layers;
  final List<int> previewTimes;
  final List<Map<String, Object>> previewStates;
  Iterable<SceneLayer> get allLayers sync* {
    Iterable<SceneLayer> visit(SceneLayer layer) sync* {
      yield layer;
      for (final child in layer.children) {
        yield* visit(child);
      }
    }

    for (final layer in layers) {
      yield* visit(layer);
    }
  }

  Map<String, Object> resolveState(Map<String, Object?> values) {
    if (values.keys.any((k) => !states.containsKey(k))) throw const FormatException('Undeclared scene state');
    return Map.unmodifiable(
      states.map((k, spec) {
        final value = values.containsKey(k) ? values[k] : spec.defaultValue;
        spec.validate(value);
        return MapEntry(k, spec.type == 'int' ? (value as num).toInt() : value!);
      }),
    );
  }

  static SceneManifest decode(Uint8List bytes) {
    if (bytes.length > 262144) throw const FormatException('Manifest byte limit');
    return _ManifestDecoder(object(jsonDecode(utf8.decode(bytes)))).decode();
  }
}

const _easings = {'linear', 'ease_in', 'ease_out', 'ease_in_out'};

final class _ManifestDecoder {
  _ManifestDecoder(this.json);
  final Map<String, Object?> json;
  final palette = <String, SceneSolid>{}, states = <String, SceneStateSpec>{}, used = <String>{'scene/1'}, ids = <String>{};
  var layerCount = 0, trackCount = 0, pathCount = 0;
  SceneManifest decode() {
    const root = {
      'schema_version',
      'scene_id',
      'version',
      'view_box',
      'required_capabilities',
      'palette',
      'assets',
      'states',
      'layers',
      'anchors',
      'reduced_motion',
      'preview',
    };
    fields(json, root, root);
    if (json['schema_version'] != 'qabas.scene/1' || !RegExp(r'^scn_[a-z0-9_]+$').hasMatch(string(json['scene_id']))) {
      throw const FormatException('Unsupported scene identity');
    }
    final capabilities = array(json['required_capabilities'], 1, sceneCapabilities.length).map(string).toSet();
    if (capabilities.length != (json['required_capabilities'] as List).length || !sceneCapabilities.containsAll(capabilities)) {
      throw const FormatException('Unsupported capabilities');
    }
    // Assets, clips and anchors have no released capability in this app build.
    array(json['assets'], 0, 0);
    array(json['anchors'], 0, 0);
    final box = object(json['view_box']);
    fields(box, {'width', 'height'}, {'width', 'height'});
    final width = integer(box['width'], 1, 4096), height = integer(box['height'], 1, 4096);
    for (final entry in object(json['palette']).entries) {
      final value = string(entry.value);
      int color;
      if (value.startsWith('token:')) {
        final frozen = sceneTokens[value.substring(6)];
        if (frozen == null) throw const FormatException('Unknown palette token');
        color = frozen;
      } else {
        if (!RegExp(r'^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$').hasMatch(value)) throw const FormatException('Invalid color');
        final rgba = int.parse(value.substring(1), radix: 16);
        color = value.length == 7 ? 0xff000000 | rgba : (rgba & 255) << 24 | rgba >> 8;
      }
      palette[entry.key] = SceneSolid(color);
    }
    final stateJson = object(json['states']);
    if (stateJson.length > 6) throw const FormatException('State limit');
    for (final entry in stateJson.entries) {
      final s = object(entry.value);
      fields(s, {'type', 'default', 'min', 'max', 'values'}, {'type', 'default'});
      final type = choice(s['type'], {'int', 'bool', 'enum'});
      final min = type == 'int' ? integer(s['min'], -9007199254740991, 9007199254740991) : null;
      final max = type == 'int' ? integer(s['max'], min!, 9007199254740991) : null;
      final values = type == 'enum' ? array(s['values'], 1, 262144).map(string).toList() : <String>[];
      if (values.toSet().length != values.length || s['default'] == null) throw const FormatException('Invalid state declaration');
      states[entry.key] = SceneStateSpec(type, s['default']!, min, max, values);
    }
    final layers = array(json['layers'], 1, 60).map(layer).toList();
    if (used.length != capabilities.length || !capabilities.containsAll(used)) {
      throw const FormatException('Capability declaration mismatch');
    }
    final reduced = object(json['reduced_motion']);
    fields(reduced, {'still_time_ms'}, {'still_time_ms'});
    final preview = object(json['preview']);
    fields(preview, {'frames_ms', 'states'}, {'frames_ms', 'states'});
    final manifest = SceneManifest._(
      string(json['scene_id']),
      integer(json['version'], 1, 9007199254740991),
      width,
      height,
      capabilities,
      palette,
      states,
      layers,
      integer(reduced['still_time_ms'], 0, 9007199254740991),
      array(preview['frames_ms'], 1, 6).map((v) => integer(v, 0, 9007199254740991)).toList(),
      const [],
    );
    final previews = array(preview['states'], 1, 8).map((v) => manifest.resolveState(object(v))).toList();
    return SceneManifest._(
      manifest.sceneId,
      manifest.version,
      width,
      height,
      capabilities,
      palette,
      states,
      layers,
      manifest.stillTimeMs,
      manifest.previewTimes,
      previews,
    );
  }

  SceneSolid color(Object? name) => palette[string(name)] ?? (throw const FormatException('Unknown palette color'));
  ScenePaint paint(Object? raw) {
    if (raw is String) return color(raw);
    used.add('paint.gradient/1');
    final p = object(raw);
    fields(p, {'gradient', 'stops', 'from', 'to', 'center', 'radius'}, {'gradient', 'stops'});
    final kind = choice(p['gradient'], {'linear', 'radial'});
    List<double> point(Object? v) => array(v, 2, 2).map((n) => number(n)).toList();
    final stops = array(p['stops'], 2, 4).map((v) {
      final s = object(v);
      fields(s, {'at', 'color'}, {'at', 'color'});
      return GradientStop(number(s['at'], min: 0, max: 1), color(s['color']));
    }).toList();
    for (var i = 1; i < stops.length; i++) {
      if (stops[i].at < stops[i - 1].at) throw const FormatException('Unordered gradient stops');
    }
    final start = point(p[kind == 'linear' ? 'from' : 'center']);
    final end = kind == 'linear' ? point(p['to']) : const <double>[];
    if (kind == 'linear' && start[0] == end[0] && start[1] == end[1]) throw const FormatException('Degenerate gradient');
    final radius = kind == 'radial' ? number(p['radius'], min: double.minPositive) : 0.0;
    return SceneGradient(kind, start, end, radius, stops);
  }

  SceneCondition condition(Object? raw) {
    final c = object(raw), result = <String, Map<String, Object?>>{};
    if (c.isEmpty) throw const FormatException('Empty condition');
    for (final entry in c.entries) {
      final spec = states[entry.key];
      if (spec == null) throw const FormatException('Unknown condition state');
      final ops = object(entry.value);
      fields(ops, {'eq', 'gte', 'lte', 'in'});
      if (ops.isEmpty) throw const FormatException('Empty operators');
      final validated = <String, Object?>{};
      for (final op in ops.entries) {
        if (op.key == 'gte' || op.key == 'lte') {
          if (spec.type != 'int') throw const FormatException('Numeric condition on noninteger state');
          validated[op.key] = number(op.value);
        } else if (op.key == 'in') {
          final values = array(op.value, 0, 262144);
          for (final v in values) {
            spec.validate(v);
          }
          validated[op.key] = List<Object?>.unmodifiable(values);
        } else {
          spec.validate(op.value);
          validated[op.key] = op.value;
        }
      }
      result[entry.key] = validated;
    }
    return SceneCondition(result);
  }

  SceneLayer layer(Object? raw) {
    if (++layerCount > 60) throw const FormatException('Layer limit');
    final l = object(raw);
    fields(
      l,
      {
        'id',
        'type',
        'children',
        'x',
        'y',
        'w',
        'h',
        'rx',
        'ry',
        'corner',
        'd',
        'count',
        'seed',
        'fill',
        'stroke',
        'stroke_width',
        'opacity',
        'transform',
        'state_rules',
        'tracks',
      },
      {'id', 'type'},
    );
    final id = string(l['id']);
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(id) || !ids.add(id)) throw const FormatException('Invalid or duplicate layer ID');
    final type = choice(l['type'], {'group', 'rect', 'ellipse', 'path', 'sparkles'});
    used.add(switch (type) {
      'rect' => 'shape.rect/1',
      'ellipse' => 'shape.ellipse/1',
      'path' => 'shape.path/1',
      'sparkles' => 'fx.sparkles/1',
      _ => 'scene/1',
    });
    final transform = l.containsKey('transform') ? object(l['transform']) : <String, Object?>{};
    fields(transform, {'x', 'y', 'rotation', 'scale', 'origin_x', 'origin_y'});
    final base = <String, Object>{
      'x': number(transform['x'] ?? 0),
      'y': number(transform['y'] ?? 0),
      'rotation': number(transform['rotation'] ?? 0),
      'scale': number(transform['scale'] ?? 1, min: double.minPositive),
      'opacity': number(l['opacity'] ?? 1, min: 0, max: 1),
      if (l.containsKey('fill')) 'fill': paint(l['fill']),
    };
    if (type != 'group' && !base.containsKey('fill')) throw const FormatException('Missing geometry fill');
    SceneGeometry? geometry;
    switch (type) {
      case 'rect':
        geometry = RectGeometry(
          number(l['x']),
          number(l['y']),
          number(l['w'], min: double.minPositive),
          number(l['h'], min: double.minPositive),
          number(l['corner'] ?? 0, min: 0),
        );
      case 'ellipse':
        geometry = EllipseGeometry(
          number(l['x']),
          number(l['y']),
          number(l['rx'], min: double.minPositive),
          number(l['ry'], min: double.minPositive),
        );
      case 'path':
        final path = ScenePath.parse(string(l['d']));
        pathCount += path.commands.length;
        if (pathCount > 6000) throw const FormatException('Total path command limit');
        geometry = PathGeometry(path);
      case 'sparkles':
        if (base['fill'] is! SceneSolid) throw const FormatException('Sparkles require solid fill');
        geometry = SparkleGeometry(
          number(l['x']),
          number(l['y']),
          number(l['w'], min: double.minPositive),
          number(l['h'], min: double.minPositive),
          integer(l['count'], 1, 40),
          integer(l['seed'], -9007199254740991, 9007199254740991),
        );
      case 'group':
        break;
    }
    final rules = array(l['state_rules'] ?? [], 0, 8).map((v) {
      final r = object(v);
      fields(r, {'when', 'set', 'transition_ms', 'easing'}, {'when', 'set'});
      final set = object(r['set']);
      fields(set, {'x', 'y', 'rotation', 'scale', 'opacity', 'fill'});
      if (set.isEmpty) throw const FormatException('Empty rule');
      return SceneRule(
        condition(r['when']),
        set.map(
          (k, v) => MapEntry(
            k,
            k == 'fill'
                ? color(v)
                : number(
                    v,
                    min: k == 'scale'
                        ? double.minPositive
                        : k == 'opacity'
                        ? 0
                        : null,
                    max: k == 'opacity' ? 1 : null,
                  ),
          ),
        ),
        integer(r['transition_ms'] ?? 0, 0, 3000),
        choice(r['easing'] ?? 'linear', _easings),
      );
    }).toList();
    final tracks = array(l['tracks'] ?? [], 0, 10).map((v) {
      if (++trackCount > 120) throw const FormatException('Track limit');
      used.add('track/1');
      final t = object(v);
      fields(
        t,
        {'property', 'duration_ms', 'delay_ms', 'easing', 'loop', 'keyframes', 'active_when'},
        {'property', 'duration_ms', 'easing', 'loop', 'keyframes'},
      );
      final property = choice(t['property'], {'translate_x', 'translate_y', 'rotation', 'scale', 'opacity'});
      final frames = array(t['keyframes'], 2, 12).map((v) {
        final k = object(v);
        fields(k, {'t', 'v'}, {'t', 'v'});
        return SceneKeyframe(number(k['t'], min: 0, max: 1), number(k['v'], min: property == 'scale' ? double.minPositive : null));
      }).toList();
      if (frames.first.t != 0 || frames.last.t != 1) throw const FormatException('Keyframe endpoints');
      for (var i = 1; i < frames.length; i++) {
        if (frames[i].t <= frames[i - 1].t) throw const FormatException('Unordered keyframes');
      }
      return SceneTrack(
        property,
        integer(t['duration_ms'], 200, 60000),
        integer(t['delay_ms'] ?? 0, 0, 60000),
        choice(t['easing'], _easings),
        choice(t['loop'], {'none', 'repeat', 'ping_pong'}),
        frames,
        t.containsKey('active_when') ? condition(t['active_when']) : null,
      );
    }).toList();
    final children = type == 'group' ? array(l['children'], 0, 60).map(layer).toList() : <SceneLayer>[];
    if (type != 'group' && l.containsKey('children')) throw const FormatException('Children on leaf geometry');
    return SceneLayer(
      id,
      geometry,
      base,
      number(transform['origin_x'] ?? 0),
      number(transform['origin_y'] ?? 0),
      l.containsKey('stroke') ? color(l['stroke']) : null,
      number(l['stroke_width'] ?? 0, min: 0),
      rules,
      tracks,
      children,
    );
  }
}
