import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:qabas/core/design_system/tokens/tokens.dart';

class SplashPathPainter extends CustomPainter {
  SplashPathPainter(this.t, this.endY);
  final double t;

  /// Where the path arrives: just below the brand block, so the journey
  /// leads up to the light without crossing the wordmark.
  final double endY;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0) return;
    final w = size.width;
    final start = Offset(w * 0.5, size.height + 10);
    final end = Offset(w * 0.5, endY);
    final span = start.dy - end.dy;
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(w * 0.1, start.dy - span * 0.3, w * 0.9, start.dy - span * 0.45, w * 0.5, start.dy - span * 0.6)
      ..cubicTo(w * 0.22, start.dy - span * 0.72, w * 0.62, end.dy + span * 0.14, end.dx, end.dy);
    final metric = path.computeMetrics().first;
    final len = metric.length * t;
    for (double d = 0; d < len; d += 16) {
      final p = metric.getTangentForOffset(d)!.position;
      final near = 1 - (d / metric.length);
      final glowA = (0.25 + 0.75 * (1 - near)).clamp(0.0, 1.0);
      canvas.drawCircle(p, 2.6 + 1.2 * (1 - near), Paint()..color = QColors.softEmber.withValues(alpha: 0.25 + 0.55 * glowA));
    }
    // a faint travelling spark at the head of the path
    if (t < 1) {
      final head = metric.getTangentForOffset(len)!.position;
      canvas.drawCircle(head, 10, Paint()..color = QColors.flameGold.withValues(alpha: 0.25 + 0.2 * math.sin(t * 20)));
    }
  }

  @override
  bool shouldRepaint(SplashPathPainter old) => old.t != t || old.endY != endY;
}
