import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/shared/presentation/brand/lantern.dart';

class SideDecoration extends StatelessWidget {
  const SideDecoration({super.key, required this.seed});
  final int seed;

  @override
  Widget build(BuildContext context) {
    final lantern = seed % 2 == 0;
    return SizedBox(
      width: 34,
      height: 46,
      child: lantern
          ? Column(
              children: [
                Container(width: 1.5, height: 10, color: QColors.softEmber.withValues(alpha: 0.4)),
                const LanternGlyph(color: QColors.softEmber, lit: true, size: 30),
              ],
            )
          : CustomPaint(painter: _TwinklePainter(seed)),
    );
  }
}

class _TwinklePainter extends CustomPainter {
  _TwinklePainter(this.seed);
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(seed);
    for (var i = 0; i < 3; i++) {
      final c = Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height);
      final r = 3.0 + rnd.nextDouble() * 4;
      final p = Path();
      for (var k = 0; k < 8; k++) {
        final a = k * math.pi / 4 - math.pi / 2;
        final rr = k.isEven ? r : r * 0.3;
        final pt = c + Offset(math.cos(a), math.sin(a)) * rr;
        k == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
      }
      canvas.drawPath(p..close(), Paint()..color = QColors.softEmber.withValues(alpha: 0.8));
    }
  }

  @override
  bool shouldRepaint(_TwinklePainter old) => false;
}
