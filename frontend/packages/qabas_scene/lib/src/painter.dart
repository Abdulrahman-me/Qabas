import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'engine.dart';
import 'manifest.dart';

/// Compiles immutable paths, shaders and particles once for a mounted scene.
/// Both the application and explicit-frame previews use this exact painter.
final class SceneProgram {
  SceneProgram(this.manifest) {
    for (final layer in manifest.allLayers) {
      if (layer.geometry case final PathGeometry geometry) {
        final path = Path()..fillType = PathFillType.nonZero;
        for (final command in geometry.path.commands) {
          final v = command.values;
          switch (command.kind) {
            case 'M':
              path.moveTo(v[0], v[1]);
            case 'L':
              path.lineTo(v[0], v[1]);
            case 'C':
              path.cubicTo(v[0], v[1], v[2], v[3], v[4], v[5]);
            case 'Q':
              path.quadraticBezierTo(v[0], v[1], v[2], v[3]);
            case 'Z':
              path.close();
          }
        }
        _paths[layer.id] = path;
      }
      if (layer.geometry case final SparkleGeometry geometry) _particles[layer.id] = sparkleParticles(geometry);
      if (layer.base['fill'] case final SceneGradient gradient) {
        final colors = gradient.stops.map((s) => Color(s.color.argb)).toList(), stops = gradient.stops.map((s) => s.at).toList();
        final start = Offset(gradient.start[0], gradient.start[1]);
        _shaders[gradient] = gradient.kind == 'linear'
            ? ui.Gradient.linear(start, Offset(gradient.end[0], gradient.end[1]), colors, stops, TileMode.clamp)
            : ui.Gradient.radial(start, gradient.radius, colors, stops, TileMode.clamp);
      }
    }
  }
  final SceneManifest manifest;
  final _paths = <String, Path>{};
  final _particles = <String, List<SparkleParticle>>{};
  final _shaders = <SceneGradient, ui.Shader>{};

  Paint _paint(ScenePaint fill, double opacity) {
    final paint = Paint()..isAntiAlias = true;
    if (fill is SceneSolid) {
      final color = Color(fill.argb);
      paint.color = color.withValues(alpha: color.a * opacity);
    } else {
      paint.color = Color.fromRGBO(255, 255, 255, opacity);
      paint.shader = _shaders[fill];
    }
    return paint;
  }

  void paint(Canvas canvas, Size size, SceneFrame frame) {
    canvas.save();
    final scale = math.min(size.width / manifest.width, size.height / manifest.height);
    canvas.scale(scale);
    canvas.clipRect(Rect.fromLTWH(0, 0, manifest.width.toDouble(), manifest.height.toDouble()));
    for (final layer in manifest.layers) {
      _layer(canvas, layer, frame);
    }
    canvas.restore();
  }

  void _layer(Canvas canvas, SceneLayer layer, SceneFrame frame) {
    final values = frame.layers[layer.id]!;
    if (values.opacity <= 0) return;
    canvas.save();
    canvas.translate(values.x, values.y);
    canvas.translate(layer.originX, layer.originY);
    canvas.rotate(values.rotation * math.pi / 180);
    canvas.scale(values.scale);
    canvas.translate(-layer.originX, -layer.originY);
    final geometry = layer.geometry;
    if (geometry == null) {
      if (values.opacity < 1) canvas.saveLayer(null, Paint()..color = Color.fromRGBO(255, 255, 255, values.opacity));
      for (final child in layer.children) {
        _layer(canvas, child, frame);
      }
      if (values.opacity < 1) canvas.restore();
    } else {
      final paint = _paint(values.fill!, values.opacity);
      void draw(Paint p) {
        switch (geometry) {
          case RectGeometry():
            final radius = math.min(geometry.corner, math.min(geometry.width, geometry.height) / 2);
            canvas.drawRRect(
              RRect.fromRectAndRadius(Rect.fromLTWH(geometry.x, geometry.y, geometry.width, geometry.height), Radius.circular(radius)),
              p,
            );
          case EllipseGeometry():
            canvas.drawOval(Rect.fromCenter(center: Offset(geometry.x, geometry.y), width: 2 * geometry.rx, height: 2 * geometry.ry), p);
          case PathGeometry():
            canvas.drawPath(_paths[layer.id]!, p);
          case SparkleGeometry():
            final color = p.color;
            for (final particle in _particles[layer.id]!) {
              p.color = color.withValues(alpha: color.a * particle.alpha(frame.timeMs));
              canvas.drawCircle(Offset(particle.x, particle.y), particle.radius, p);
            }
        }
      }

      draw(paint);
      if (layer.stroke != null && layer.strokeWidth > 0) {
        final stroke = _paint(layer.stroke!, values.opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = layer.strokeWidth
          ..strokeCap = StrokeCap.butt
          ..strokeJoin = StrokeJoin.miter
          ..strokeMiterLimit = 4;
        draw(stroke);
      }
    }
    canvas.restore();
  }
}

class ScenePainter extends CustomPainter {
  ScenePainter({required this.program, required this.frame, super.repaint});
  final SceneProgram program;
  final SceneFrame Function() frame;
  @override
  void paint(Canvas canvas, Size size) => program.paint(canvas, size, frame());
  @override
  bool shouldRepaint(ScenePainter oldDelegate) => true;
}
