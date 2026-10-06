import 'package:flutter/material.dart';
import 'package:qabas/core/design_system/components/journey_node.dart';
import 'package:qabas/core/design_system/design_system.dart';

class JourneyPathPainter extends CustomPainter {
  JourneyPathPainter({required this.centers, required this.statuses});
  final List<Offset> centers;
  final List<QNodeStatus> statuses;

  @override
  void paint(Canvas canvas, Size size) {
    final lit = Paint()..color = QColors.flameGold;
    final litGlow = Paint()..color = QColors.flameGold.withValues(alpha: 0.18);
    final dim = Paint()..color = QColors.softEmber.withValues(alpha: 0.22);

    void dots(Path path, bool on) {
      for (final m in path.computeMetrics()) {
        for (double d = 6; d < m.length - 4; d += 15) {
          final p = m.getTangentForOffset(d)!.position;
          if (on) canvas.drawCircle(p, 6, litGlow);
          canvas.drawCircle(p, on ? 3.2 : 2.8, on ? lit : dim);
        }
      }
    }

    // lead-in from the unit banner
    final first = centers.first;
    dots(
      Path()
        ..moveTo(size.width / 2, -18)
        ..cubicTo(size.width / 2, first.dy * 0.4, first.dx, first.dy * 0.2, first.dx, first.dy - 40),
      statuses.first != QNodeStatus.locked,
    );

    for (var i = 0; i < centers.length - 1; i++) {
      final a = centers[i], b = centers[i + 1];
      final d = b.dy - a.dy;
      final path = Path()
        ..moveTo(a.dx, a.dy + 40)
        ..cubicTo(a.dx, a.dy + d * 0.55, b.dx, b.dy - d * 0.55, b.dx, b.dy - 40);
      dots(path, statuses[i] == QNodeStatus.done && statuses[i + 1] != QNodeStatus.locked);
    }
    final last = centers.last;
    dots(
      Path()
        ..moveTo(last.dx, last.dy + 46)
        ..cubicTo(last.dx, last.dy + 80, size.width / 2, last.dy + 70, size.width / 2, size.height + 6),
      statuses.last == QNodeStatus.done,
    );
  }

  @override
  bool shouldRepaint(JourneyPathPainter old) => old.centers != centers || old.statuses != statuses;
}
